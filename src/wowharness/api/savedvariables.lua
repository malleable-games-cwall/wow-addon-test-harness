--- SavedVariables persistence between simulated sessions.
local util = require("wowharness.util")

local savedvariables = {}

local function serializeValue(value, indent, seen)
  local valueType = type(value)
  if valueType == "string" then
    return string.format("%q", value)
  elseif valueType == "number" or valueType == "boolean" then
    return tostring(value)
  elseif valueType ~= "table" then
    return "nil --[[" .. valueType .. "]]"
  end
  if seen[value] then
    return "nil --[[cycle]]"
  end
  seen[value] = true
  local pieces = { "{\n" }
  local nextIndent = indent .. "\t"
  local keys = {}
  for key in pairs(value) do
    table.insert(keys, key)
  end
  table.sort(keys, function(left, right)
    return tostring(left) < tostring(right)
  end)
  for _, key in ipairs(keys) do
    local keyText
    if type(key) == "string" and string.match(key, "^[%a_][%w_]*$") then
      keyText = key
    else
      keyText = "[" .. serializeValue(key, nextIndent, seen) .. "]"
    end
    table.insert(pieces, nextIndent .. keyText .. " = " ..
      serializeValue(value[key], nextIndent, seen) .. ",\n")
  end
  table.insert(pieces, indent .. "}")
  seen[value] = nil
  return table.concat(pieces)
end

--- Render a SavedVariables.lua file body for the given globals.
-- @param variables table map of global name -> value
function savedvariables.serialize(variables)
  local names = {}
  for name in pairs(variables) do
    table.insert(names, name)
  end
  table.sort(names)
  local pieces = {}
  for _, name in ipairs(names) do
    table.insert(pieces, name .. " = " .. serializeValue(variables[name], "", {}) .. "\n")
  end
  return table.concat(pieces)
end

--- Load a SavedVariables.lua file into a table of globals.
function savedvariables.load(path)
  local contents, err = util.readFile(path)
  if not contents then
    return nil, err
  end
  local sandbox = {}
  local chunk, compileError
  if setfenv then -- Lua 5.1
    chunk, compileError = loadstring(contents, "@" .. path) -- luacheck: ignore 113
    if chunk then
      setfenv(chunk, sandbox) -- luacheck: ignore 113
    end
  else
    chunk, compileError = load(contents, "@" .. path, "t", sandbox)
  end
  if not chunk then
    return nil, compileError
  end
  local ok, runError = pcall(chunk)
  if not ok then
    return nil, runError
  end
  return sandbox
end

--- Write the SavedVariables declared by an addon to `path`.
function savedvariables.write(path, variables)
  local handle, err = io.open(path, "w")
  if not handle then
    return false, err
  end
  handle:write(savedvariables.serialize(variables))
  handle:close()
  return true
end

return savedvariables
