--- High level driver around a sandbox context.
--
-- A session is what scenario scripts talk to: load addons, fire events, run
-- slash commands and advance the virtual clock.
local environment = require("wowharness.environment")
local loader = require("wowharness.loader")
local chat = require("wowharness.api.chat")
local savedvariablesModule = require("wowharness.api.savedvariables")

local Session = {}
Session.__index = Session

--- @param options table|nil { profile = ..., strict = bool, savedVariables = table }
function Session.new(options)
  options = options or {}
  local context = environment.create(options)
  context.savedVariables = options.savedVariables or {}
  return setmetatable({
    context = context,
    env = context.env,
    steps = {},
  }, Session)
end

function Session:log(step, detail)
  table.insert(self.steps, { step = step, detail = detail })
end

--- Register an addon directory (or .toc path) with the session.
function Session:addAddon(path, options)
  local addon, err = loader.prepare(self.context, path, options)
  if not addon then
    self.context:recordError("addon discovery", err)
    return nil, err
  end
  self:log("discovered", string.format("%s (%s)", addon.name, addon.manifest.path))
  return addon
end

--- Load every registered addon in dependency order.
function Session:loadAddons()
  local ordered = loader.resolveOrder(self.context.addons)
  for _, entry in ipairs(loader.missingDependencies(self.context.addons)) do
    self.context:addWarning(string.format(
      "%s declares %sdependency '%s' which is not loaded",
      entry.addon,
      entry.optional and "optional " or "",
      entry.dependency
    ))
  end
  for _, addon in ipairs(ordered) do
    loader.load(self.context, addon)
    self:log("loaded", string.format("%s (%d files)", addon.name, #addon.loadedFiles))
    self:fire("ADDON_LOADED", addon.name)
  end
  return ordered
end

--- Fire a game event at every frame listening for it.
function Session:fire(event, ...)
  local invoked = self.context.events:fire(event, ...)
  self:log("event", string.format("%s -> %d handler(s)", event, invoked))
  return invoked
end

--- Advance the virtual clock, running timers and OnUpdate scripts.
function Session:advance(seconds, step)
  local executed = self.context.clock:advance(seconds or 0, step)
  self:log("advance", string.format("%.2fs -> %d timer callback(s)", seconds or 0, executed))
  return executed
end

--- Run a slash command, e.g. session:slash("/myaddon config").
-- @return boolean true when a handler was registered for the command
function Session:slash(input)
  local command, arguments = string.match(input, "^(%S+)%s*(.*)$")
  if not command then
    return false
  end
  local handlerKey = chat.resolveSlashCommand(self.env, command)
  if not handlerKey then
    self.context:addWarning(string.format("no slash handler registered for '%s'", command))
    self:log("slash", string.format("%s (unhandled)", input))
    return false
  end
  self.context:protectedCall(
    string.format("SlashCmdList[%s]", handlerKey),
    self.env.SlashCmdList[handlerKey],
    arguments,
    self.env.ChatFrame1
  )
  self:log("slash", input)
  return true
end

function Session:slashCommands()
  return chat.listSlashCommands(self.env)
end

--- Simulate entering or leaving combat, including the paired events.
function Session:setCombat(inCombat)
  self.context.state.inCombat = inCombat and true or false
  self:fire(inCombat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

--- Click a named button/frame created by the addon.
function Session:click(frameName, button)
  local frame = self.env[frameName]
  if type(frame) ~= "table" or not frame.RunScript then
    self.context:addWarning(string.format("cannot click unknown frame '%s'", frameName))
    return false
  end
  frame:RunScript("OnClick", button or "LeftButton", false)
  self:log("click", frameName)
  return true
end

--- Collect the SavedVariables declared by loaded addons.
function Session:collectSavedVariables()
  local collected = {}
  for _, addon in ipairs(self.context.addons) do
    for _, name in ipairs(addon.savedVariables) do
      collected[name] = rawget(self.env, name)
    end
    for _, name in ipairs(addon.savedVariablesPerCharacter) do
      collected[name] = rawget(self.env, name)
    end
  end
  return collected
end

function Session:writeSavedVariables(path)
  return savedvariablesModule.write(path, self:collectSavedVariables())
end

function Session:errors()
  return self.context.errors
end

function Session:warnings()
  return self.context.warnings
end

function Session:output()
  return self.context.output
end

return Session
