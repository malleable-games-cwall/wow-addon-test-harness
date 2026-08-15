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

--- Connect (or with nil, disconnect) a simulated gamepad.
-- @param device table|nil e.g. { name = "DualSense", labelStyle = "playstation" }
function Session:setGamePad(device)
  self.context.state.gamePad = device
  self:fire("GAMEPAD_CONNECTED", 1)
  return device
end

--- Press a gamepad button on a frame, as the client would deliver it.
function Session:gamePadButton(frame, button, down)
  if type(frame) == "string" then
    frame = self.env[frame]
  end
  if type(frame) ~= "table" or not frame.RunScript then
    self.context:addWarning(string.format("cannot send '%s' to an unknown frame", tostring(button)))
    return false
  end
  frame:RunScript(down == false and "OnGamePadButtonUp" or "OnGamePadButtonDown", button)
  self:log("gamepad", button)
  return true
end

--- Move a gamepad stick, as the client would deliver it while it is held.
function Session:gamePadStick(frame, stick, x, y)
  if type(frame) == "string" then
    frame = self.env[frame]
  end
  if type(frame) ~= "table" or not frame.RunScript then
    self.context:addWarning(string.format("cannot send stick '%s' to an unknown frame", tostring(stick)))
    return false
  end
  frame:RunScript("OnGamePadStick", stick or "Left", x or 0, y or 0)
  self:log("stick", string.format("%s %.2f,%.2f", stick or "Left", x or 0, y or 0))
  return true
end

--- The bindings the addon has written through SetBinding.
function Session:bindings()
  return self.context.state.bindings
end

--- Start a gossip conversation and fire GOSSIP_SHOW.
-- @param data table { text = "...", options = {...}, availableQuests = {...}, activeQuests = {...} }
function Session:setGossip(data)
  self.context.state.gossip = data
  if data then self:fire("GOSSIP_SHOW") end
  return data
end

--- Stage quest giver text. `event` names the quest event to fire, e.g.
-- "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" or "QUEST_GREETING".
function Session:setQuest(data, event)
  self.context.state.quest = data
  if event then self:fire(event) end
  return data
end

--- Open a merchant and fire MERCHANT_SHOW.
function Session:setMerchant(data)
  self.context.state.merchant = data
  self.context.state.buyback = (data and data.buyback) or {}
  if data then self:fire("MERCHANT_SHOW") end
  return data
end

function Session:setMoney(amount)
  self.context.state.money = amount or 0
end

--- Everything the addon asked the server to do while interacting with an NPC.
function Session:interactions()
  return self.context.state.interactions
end

function Session:purchases()
  return self.context.state.purchases
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
