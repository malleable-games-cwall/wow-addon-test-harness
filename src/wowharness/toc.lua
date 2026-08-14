--- Parser for WoW addon table-of-contents (.toc) manifests.
local util = require("wowharness.util")

local toc = {}

local BOM = "\239\187\191"

local function stripBom(text)
  if util.startsWith(text, BOM) then
    return string.sub(text, #BOM + 1)
  end
  return text
end

--- Parse the contents of a .toc file.
-- @param text string raw file contents
-- @return table { metadata = {}, files = {}, warnings = {} }
function toc.parse(text)
  local manifest = { metadata = {}, files = {}, warnings = {} }
  local lineNumber = 0
  for line in string.gmatch(stripBom(text) .. "\n", "(.-)\r?\n") do
    lineNumber = lineNumber + 1
    local trimmed = util.trim(line)
    if trimmed == "" then -- luacheck: ignore 542
      -- blank line
    elseif util.startsWith(trimmed, "##") then
      local key, value = string.match(trimmed, "^##%s*([^:]-)%s*:%s*(.-)%s*$")
      if key then
        manifest.metadata[key] = value
      else
        table.insert(manifest.warnings, {
          line = lineNumber,
          message = "malformed directive: " .. trimmed,
        })
      end
    elseif util.startsWith(trimmed, "#") then -- luacheck: ignore 542
      -- comment
    else
      table.insert(manifest.files, trimmed)
    end
  end
  return manifest
end

--- Read and parse a .toc file from disk.
function toc.parseFile(path)
  local contents, err = util.readFile(path)
  if not contents then
    return nil, string.format("unable to read toc file '%s': %s", path, tostring(err))
  end
  local manifest = toc.parse(contents)
  manifest.path = util.normalizePath(path)
  manifest.directory = util.dirname(path)
  manifest.name = string.gsub(util.basename(path), "%.toc$", "")
  return manifest
end

--- Split a "##  Dependencies: A, B" style value into a list.
function toc.parseList(value)
  local entries = {}
  if not value then
    return entries
  end
  for piece in string.gmatch(value, "[^,]+") do
    local trimmed = util.trim(piece)
    if trimmed ~= "" then
      table.insert(entries, trimmed)
    end
  end
  return entries
end

local function metadataValue(manifest, ...)
  for index = 1, select("#", ...) do
    local key = select(index, ...)
    local value = manifest.metadata[key]
    if value and value ~= "" then
      return value
    end
  end
  return nil
end

--- Dependencies that must load before the addon (required + optional).
function toc.dependencies(manifest)
  local required = toc.parseList(metadataValue(manifest, "Dependencies", "RequiredDeps"))
  local optional = toc.parseList(metadataValue(manifest, "OptionalDeps"))
  return required, optional
end

--- SavedVariables declared by the addon.
function toc.savedVariables(manifest)
  return toc.parseList(metadataValue(manifest, "SavedVariables")),
    toc.parseList(metadataValue(manifest, "SavedVariablesPerCharacter"))
end

--- Locate the .toc file(s) inside an addon directory.
-- Flavour suffixed manifests (Foo_Mainline.toc) are returned alongside the
-- base manifest so callers can pick the flavour they want to smoke test.
-- @return table list of { path = ..., flavor = ... }
function toc.discover(directory)
  local found = {}
  local addonName = util.basename(directory)
  for _, entry in ipairs(util.listDirectory(directory)) do
    local base = string.match(entry, "^(.+)%.[Tt][Oo][Cc]$")
    if base then
      local flavor = string.match(base, "^" .. addonName:gsub("%p", "%%%0") .. "[-_](.+)$")
      table.insert(found, {
        path = util.joinPath(directory, entry),
        flavor = flavor and string.lower(flavor) or nil,
      })
    end
  end
  table.sort(found, function(left, right)
    return left.path < right.path
  end)
  return found
end

return toc
