--- The default smoke test: log in, load, play a bit, log out.
local Session = require("wowharness.session")
local util = require("wowharness.util")
local profileModule = require("wowharness.profile")

local runner = {}

--- The login/logout event sequence the client produces for a fresh session.
local LOGIN_EVENTS = {
  { "VARIABLES_LOADED" },
  { "PLAYER_LOGIN" },
  { "PLAYER_ENTERING_WORLD", true, false },
  { "SPELLS_CHANGED" },
  { "PLAYER_ALIVE" },
  { "UPDATE_BINDINGS" },
}

local LOGOUT_EVENTS = {
  { "PLAYER_LEAVING_WORLD" },
  { "PLAYER_LOGOUT" },
}

local COMBAT_EVENTS = {
  { "PLAYER_TARGET_CHANGED" },
  { "UNIT_HEALTH", "player" },
  { "UNIT_AURA", "player" },
}

--- Run a full smoke test.
-- @param options table {
--   addons = { "path/to/Addon", ... },
--   flavor = "mainline",
--   profile = table,
--   strict = bool,
--   advance = number seconds of virtual time to simulate,
--   slashCommands = { "/foo" } or nil to auto-discover,
--   scenario = "path/to/scenario.lua",
--   savedVariables = "path/to/SavedVariables.lua",
-- }
-- @return table result summary consumed by the reporter
function runner.run(options)
  options = options or {}
  local savedVariables = {}
  if options.savedVariables and util.fileExists(options.savedVariables) then
    local loaded, err = require("wowharness.api.savedvariables").load(options.savedVariables)
    if loaded then
      savedVariables = loaded
    else
      savedVariables = {}
      io.stderr:write("warning: could not load saved variables: " .. tostring(err) .. "\n")
    end
  end

  local session = Session.new({
    profile = options.profile or profileModule.new(),
    strict = options.strict,
    savedVariables = savedVariables,
  })
  local context = session.context

  local requested = options.addons or {}
  if #requested == 0 then
    context:recordError("configuration", "no addon paths supplied")
  end
  for _, path in ipairs(requested) do
    session:addAddon(path, { flavor = options.flavor })
  end

  session:loadAddons()

  for _, event in ipairs(LOGIN_EVENTS) do
    session:fire((table.unpack or unpack)(event)) -- luacheck: ignore 143
    if event[1] == "PLAYER_LOGIN" then
      context.state.loggedIn = true
    end
  end

  session:advance(options.advance or 1)

  local commands = options.slashCommands
  if not commands then
    commands = {}
    for _, entry in ipairs(session:slashCommands()) do
      table.insert(commands, entry.command)
    end
  end
  for _, command in ipairs(commands) do
    session:slash(command)
    session:advance(0.5)
  end

  if options.combat ~= false then
    session:setCombat(true)
    for _, event in ipairs(COMBAT_EVENTS) do
      session:fire((table.unpack or unpack)(event)) -- luacheck: ignore 143
    end
    session:advance(1)
    session:setCombat(false)
  end

  if options.scenario then
    runner.runScenario(session, options.scenario)
  end

  for _, event in ipairs(LOGOUT_EVENTS) do
    session:fire((table.unpack or unpack)(event)) -- luacheck: ignore 143
  end

  if options.saveVariablesTo then
    local ok, err = session:writeSavedVariables(options.saveVariablesTo)
    if not ok then
      context:recordError("saved variables", err)
    end
  end

  return runner.summarize(session, options)
end

--- Execute a user supplied scenario file.
-- The file may return a function(session) or a list of { command, args... }.
function runner.runScenario(session, path)
  local chunk, err = loadfile(path)
  if not chunk then
    session.context:recordError("scenario", "could not load scenario: " .. tostring(err))
    return false
  end
  local ok, scenario = pcall(chunk)
  if not ok then
    session.context:recordError("scenario", scenario)
    return false
  end
  if type(scenario) == "function" then
    return session.context:protectedCall("scenario", scenario, session)
  end
  if type(scenario) ~= "table" then
    session.context:recordError("scenario", "scenario file must return a function or a table")
    return false
  end
  for index, step in ipairs(scenario) do
    local action = step[1] or step.action
    local method = Session[action]
    if type(method) ~= "function" then
      session.context:recordError("scenario", string.format(
        "step %d uses unknown action '%s'",
        index,
        tostring(action)
      ))
    else
      session.context:protectedCall(
        string.format("scenario step %d (%s)", index, action),
        method,
        session,
        (table.unpack or unpack)(step, 2, #step) -- luacheck: ignore 143
      )
    end
  end
  return true
end

--- Turn a finished session into a plain result table.
function runner.summarize(session, options)
  local context = session.context
  local addons = {}
  for _, addon in ipairs(context.addons) do
    table.insert(addons, {
      name = addon.name,
      title = addon.manifest.metadata.Title,
      version = addon.manifest.metadata.Version,
      interface = addon.manifest.metadata.Interface,
      path = addon.manifest.path,
      files = addon.loadedFiles,
      declaredFiles = addon.manifest.files,
      savedVariables = addon.savedVariables,
    })
  end

  local missingApi = {}
  for _, name in ipairs(context.missingApiOrder) do
    table.insert(missingApi, { name = name, count = context.missingApi[name] })
  end

  -- A global read before the addon assigns it (saved variables, lazily built
  -- tables) is normal, so only report names that stayed undefined all run.
  local unknownGlobals = {}
  for _, name in ipairs(context.unknownGlobalOrder) do
    if rawget(context.env, name) == nil then
      table.insert(unknownGlobals, { name = name, count = context.unknownGlobals[name] })
    end
  end

  local templates = {}
  for _, name in ipairs(context.templateOrder) do
    table.insert(templates, { name = name, count = context.templates[name] })
  end

  return {
    passed = #context.errors == 0,
    addons = addons,
    errors = context.errors,
    warnings = context.warnings,
    output = context.output,
    steps = session.steps,
    missingApi = missingApi,
    unknownGlobals = unknownGlobals,
    templates = templates,
    frames = #context.frames,
    slashCommands = session:slashCommands(),
    pendingTimers = context.clock:pendingCount(),
    simulatedTime = context.clock:GetTime(),
    strict = options and options.strict or false,
  }
end

runner.LOGIN_EVENTS = LOGIN_EVENTS
runner.LOGOUT_EVENTS = LOGOUT_EVENTS
runner.COMBAT_EVENTS = COMBAT_EVENTS

return runner
