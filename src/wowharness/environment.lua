--- Builds the sandboxed global table an addon sees while under test.
local Context = require("wowharness.context")
local frames = require("wowharness.api.frames")
local timers = require("wowharness.api.timers")
local chat = require("wowharness.api.chat")
local gameApi = require("wowharness.api.game")
local interaction = require("wowharness.api.interaction")

local environment = {}

--- Lua standard library members the WoW client exposes to addons.
-- Deliberately omits io/os/require/dofile so an addon that reaches for them
-- fails here the same way it would fail in the client.
local SAFE_LIBRARIES = {
  "assert", "error", "ipairs", "next", "pairs", "pcall", "print", "select",
  "tonumber", "tostring", "type", "unpack", "xpcall", "rawget", "rawset",
  "rawequal", "rawlen", "setmetatable", "getmetatable", "collectgarbage",
  "loadstring", "load",
}

local ALLOWED_OS_FIELDS = { "time", "date", "clock", "difftime" }

local function copyLibrary(source, fields)
  local copy = {}
  if fields then
    for _, field in ipairs(fields) do
      copy[field] = source[field]
    end
  else
    for key, value in pairs(source) do
      copy[key] = value
    end
  end
  return copy
end

--- Create a sandbox context with all mocked APIs installed.
-- @param options table|nil { profile = ..., strict = bool, trackUnknownGlobals = bool }
function environment.create(options)
  options = options or {}
  local context = Context.new(options)
  local env = {}
  context.env = env

  for _, name in ipairs(SAFE_LIBRARIES) do
    env[name] = _G[name]
  end
  env.string = copyLibrary(string)
  env.table = copyLibrary(table)
  env.math = copyLibrary(math)
  env.os = copyLibrary(os, ALLOWED_OS_FIELDS)
  env.coroutine = copyLibrary(coroutine)
  env.bit = _G.bit or _G.bit32
  env.unpack = env.unpack or table.unpack
  env.table.unpack = env.table.unpack or unpack -- luacheck: ignore 143
  env._G = env
  env.getfenv = getfenv
  env.setfenv = setfenv

  timers.install(context)
  frames.install(context)
  chat.install(context)
  gameApi.install(context)
  interaction.install(context)

  -- Reading an undefined global is legal in Lua and common in addon code
  -- (feature detection), so record it as information rather than failing.
  setmetatable(env, {
    __index = function(_, key)
      if type(key) == "string" then
        context:noteUnknownGlobal(key)
      end
      return nil
    end,
  })

  return context
end

environment.SAFE_LIBRARIES = SAFE_LIBRARIES

return environment
