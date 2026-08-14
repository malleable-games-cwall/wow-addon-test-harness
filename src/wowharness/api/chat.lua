--- Chat output, error frames and the slash command dispatcher.
local chat = {}

local function makeChatFrame(context, name)
  local frame = context.newWidget("Frame", name, nil)
  frame.messages = context.output
  function frame:AddMessage(message, r, g, b)
    context:addOutput(name, message, { r = r, g = g, b = b })
    return true
  end
  function frame:Clear()
    return true
  end
  function frame:GetNumMessages()
    return #context.output
  end
  context:setGlobal(name, frame)
  return frame
end

--- Find the SlashCmdList key registered for `command` (e.g. "/foo").
-- @return string|nil handler key, string|nil matched token
function chat.resolveSlashCommand(env, command)
  local token = string.lower(command)
  for key, value in pairs(env) do
    local handlerKey = string.match(key, "^SLASH_(.+)%d+$")
    if handlerKey and type(value) == "string" and string.lower(value) == token then
      if env.SlashCmdList and env.SlashCmdList[handlerKey] then
        return handlerKey, value
      end
    end
  end
  return nil
end

--- List every registered slash command as { command = "/foo", key = "MYADDON" }.
function chat.listSlashCommands(env)
  local commands = {}
  for key, value in pairs(env) do
    local handlerKey = string.match(key, "^SLASH_(.+)%d+$")
    if handlerKey and type(value) == "string" then
      if env.SlashCmdList and env.SlashCmdList[handlerKey] then
        table.insert(commands, { command = value, key = handlerKey })
      end
    end
  end
  table.sort(commands, function(left, right)
    return left.command < right.command
  end)
  return commands
end

function chat.install(context)
  local env = context.env

  env.SlashCmdList = {}
  env.hash_SlashCmdList = {}

  env.print = function(...)
    local pieces = {}
    for index = 1, select("#", ...) do
      table.insert(pieces, tostring((select(index, ...))))
    end
    context:addOutput("print", table.concat(pieces, " "))
  end

  env.message = function(text)
    context:addOutput("message", tostring(text))
  end

  env.SendChatMessage = function(text, channel, _, target)
    context:addOutput("chat", string.format(
      "[%s%s] %s",
      tostring(channel or "SAY"),
      target and (" -> " .. tostring(target)) or "",
      tostring(text)
    ))
  end

  env.SendSystemMessage = function(text)
    context:addOutput("system", tostring(text))
  end

  local defaultChatFrame = makeChatFrame(context, "ChatFrame1")
  env.DEFAULT_CHAT_FRAME = defaultChatFrame
  context:setGlobal("DEFAULT_CHAT_FRAME", defaultChatFrame)
  makeChatFrame(context, "ChatFrame2")

  local errorsFrame = makeChatFrame(context, "UIErrorsFrame")
  env.UIErrorsFrame = errorsFrame

  env.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix)
      context.addonMessagePrefixes[prefix] = true
      return true
    end,
    SendAddonMessage = function(prefix, text, channel, target)
      context:addOutput("addonmessage", string.format(
        "%s|%s|%s%s",
        tostring(prefix),
        tostring(text),
        tostring(channel or "PARTY"),
        target and ("|" .. tostring(target)) or ""
      ))
      return true
    end,
    IsAddonMessagePrefixRegistered = function(prefix)
      return context.addonMessagePrefixes[prefix] == true
    end,
  }
  env.RegisterAddonMessagePrefix = env.C_ChatInfo.RegisterAddonMessagePrefix
  env.SendAddonMessage = env.C_ChatInfo.SendAddonMessage
end

return chat
