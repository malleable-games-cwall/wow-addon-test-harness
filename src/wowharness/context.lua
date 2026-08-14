--- Shared state for one simulated WoW client session.
--
-- The context owns the sandbox globals, the error/warning ledger, and the
-- helpers every mocked API uses to report what an addon did.
local Events = require("wowharness.api.events")
local profileModule = require("wowharness.profile")

local Context = {}
Context.__index = Context

function Context.new(options)
  options = options or {}
  local context = setmetatable({
    errors = {},
    warnings = {},
    output = {},
    missingApi = {},
    missingApiOrder = {},
    templates = {},
    templateOrder = {},
    unknownGlobals = {},
    frames = {},
    addons = {},
    savedVariables = {},
    addonMessagePrefixes = {},
    profile = options.profile or profileModule.new(),
    strict = options.strict or false,
    state = {
      inCombat = false,
      inInstance = false,
      instanceType = "none",
      loggedIn = false,
      cvars = {},
      spells = {},
      items = {},
    },
  }, Context)
  context.events = Events.new(context)
  return context
end

local unpack = unpack or table.unpack -- luacheck: ignore 121 143

--- Call `func` trapping any error so a broken addon cannot abort the run.
-- @param label string human readable description used in the report
-- @return boolean ok, ... results of the call
function Context:protectedCall(label, func, ...)
  if type(func) ~= "function" then
    self:recordError(label, "attempt to call a non-function value")
    return false
  end
  local traceback
  local arguments = { ... }
  local count = select("#", ...)
  local results = {
    xpcall(function()
      return func(unpack(arguments, 1, count))
    end, function(err)
      traceback = debug.traceback("", 2)
      return err
    end),
  }
  if not results[1] then
    self:recordError(label, results[2], traceback)
    return false
  end
  return true, unpack(results, 2, #results)
end

function Context:recordError(label, err, traceback)
  table.insert(self.errors, {
    label = label,
    message = tostring(err),
    traceback = traceback,
    time = self.clock and self.clock:GetTime() or 0,
  })
end

function Context:addWarning(message)
  table.insert(self.warnings, { message = message })
end

function Context:addOutput(channel, message, color)
  table.insert(self.output, { channel = channel, message = message, color = color })
end

function Context:noteMissingApi(name)
  if not self.missingApi[name] then
    self.missingApi[name] = 0
    table.insert(self.missingApiOrder, name)
  end
  self.missingApi[name] = self.missingApi[name] + 1
  if self.strict then
    error(string.format("unmocked API used: %s", name), 2)
  end
end

function Context:noteTemplate(name)
  if not self.templates[name] then
    self.templates[name] = 0
    table.insert(self.templateOrder, name)
  end
  self.templates[name] = self.templates[name] + 1
end

function Context:trackFrame(frame)
  table.insert(self.frames, frame)
end

function Context:setGlobal(name, value)
  rawset(self.env, name, value)
end

function Context:findAddon(name)
  local lowered = string.lower(tostring(name))
  for _, addon in ipairs(self.addons) do
    if string.lower(addon.name) == lowered then
      return addon
    end
  end
  return nil
end

function Context:hasErrors()
  return #self.errors > 0
end

return Context
