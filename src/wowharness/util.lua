--- Assorted helpers shared by the harness modules.
local util = {}

--- Split a string on a Lua pattern.
-- @param text string
-- @param pattern string Lua pattern describing the separator.
-- @return table list of pieces
function util.split(text, pattern)
  local pieces = {}
  local position = 1
  while true do
    local from, to = string.find(text, pattern, position)
    if not from then
      break
    end
    table.insert(pieces, string.sub(text, position, from - 1))
    position = to + 1
  end
  table.insert(pieces, string.sub(text, position))
  return pieces
end

function util.trim(text)
  return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

function util.startsWith(text, prefix)
  return string.sub(text, 1, #prefix) == prefix
end

--- Normalise a path: convert backslashes, collapse "." and "..".
function util.normalizePath(path)
  path = string.gsub(path, "\\", "/")
  local absolute = util.startsWith(path, "/")
  local parts = {}
  for piece in string.gmatch(path, "[^/]+") do
    if piece == ".." and #parts > 0 and parts[#parts] ~= ".." then
      table.remove(parts)
    elseif piece ~= "." then
      table.insert(parts, piece)
    end
  end
  return (absolute and "/" or "") .. table.concat(parts, "/")
end

function util.joinPath(base, relative)
  if base == nil or base == "" then
    return util.normalizePath(relative)
  end
  return util.normalizePath(base .. "/" .. relative)
end

function util.dirname(path)
  path = util.normalizePath(path)
  local parent = string.match(path, "^(.*)/[^/]*$")
  return parent or "."
end

function util.basename(path)
  path = util.normalizePath(path)
  return string.match(path, "([^/]*)$")
end

function util.fileExists(path)
  local handle = io.open(path, "r")
  if handle then
    handle:close()
    return true
  end
  return false
end

function util.readFile(path)
  local handle, err = io.open(path, "rb")
  if not handle then
    return nil, err
  end
  local contents = handle:read("*a")
  handle:close()
  return contents
end

local lfsOk, lfs = pcall(require, "lfs")

local isWindows = string.sub(package.config or "/", 1, 1) == "\\"

--- Directory listing for builds without LuaFileSystem (the static binary).
local function listDirectoryViaShell(directory)
  local entries = {}
  if not io.popen then
    return entries
  end
  local command
  if isWindows then
    command = string.format('dir /b "%s" 2>nul', string.gsub(directory, "/", "\\"))
  else
    command = string.format("ls -1 '%s' 2>/dev/null", string.gsub(directory, "'", "'\\''"))
  end
  local pipe = io.popen(command)
  if not pipe then
    return entries
  end
  for line in pipe:lines() do
    if line ~= "" then
      table.insert(entries, line)
    end
  end
  pipe:close()
  return entries
end

--- Find an entry in `directory` whose name matches `name` ignoring case.
function util.findEntry(directory, name)
  local lowered = string.lower(name)
  for _, entry in ipairs(util.listDirectory(directory)) do
    if string.lower(entry) == lowered then
      return entry
    end
  end
  return nil
end

function util.listDirectory(directory)
  if not lfsOk then
    local entries = listDirectoryViaShell(directory)
    table.sort(entries)
    return entries
  end
  local entries = {}
  local iterOk, iterator, state = pcall(lfs.dir, directory)
  if not iterOk then
    return entries
  end
  for entry in iterator, state do
    if entry ~= "." and entry ~= ".." then
      table.insert(entries, entry)
    end
  end
  table.sort(entries)
  return entries
end

function util.isDirectory(path)
  if lfsOk then
    local attributes = lfs.attributes(path)
    return attributes ~= nil and attributes.mode == "directory"
  end
  -- Without LuaFileSystem: a directory opens but cannot be read from.
  local handle = io.open(path, "r")
  if not handle then
    return false
  end
  local readable = handle:read(0)
  handle:close()
  return readable == nil
end

--- Resolve a .toc relative path against a directory, ignoring case the way the
-- WoW client does on case sensitive filesystems.
-- @return string|nil absolute-ish path to the file, or nil when unresolvable
function util.resolveCaseInsensitive(basePath, relativePath)
  local direct = util.joinPath(basePath, relativePath)
  if util.fileExists(direct) then
    return direct
  end
  local current = basePath
  for piece in string.gmatch(util.normalizePath(relativePath), "[^/]+") do
    local matched = util.findEntry(current, piece)
    if not matched then
      return nil
    end
    current = util.joinPath(current, matched)
  end
  if util.fileExists(current) then
    return current
  end
  return nil
end

function util.shallowCopy(source)
  local copy = {}
  for key, value in pairs(source) do
    copy[key] = value
  end
  return copy
end

return util
