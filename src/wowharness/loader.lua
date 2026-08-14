--- Loads addon files listed in a .toc into a sandbox context.
local util = require("wowharness.util")
local tocModule = require("wowharness.toc")

local loader = {}

local function compileChunk(source, chunkName, env)
  if setfenv then -- Lua 5.1 / LuaJIT
    local chunk, err = loadstring(source, chunkName) -- luacheck: ignore 113
    if not chunk then
      return nil, err
    end
    setfenv(chunk, env) -- luacheck: ignore 113
    return chunk
  end
  return load(source, chunkName, "t", env)
end

--- Pull `Script`/`Include` references out of an addon XML file.
-- Frame definitions are not interpreted; they are reported as warnings.
-- @return table list of relative file paths, table list of frame names
function loader.parseXml(source)
  local includes = {}
  local frameNames = {}
  for tag, attributes in string.gmatch(source, "<%s*(%a+)([^>]*)>") do
    local lowered = string.lower(tag)
    if lowered == "script" or lowered == "include" then
      local file = string.match(attributes, "[Ff]ile%s*=%s*[\"']([^\"']+)[\"']")
      if file then
        table.insert(includes, file)
      end
    elseif lowered == "frame" or lowered == "button" or lowered == "gametooltip" then
      local name = string.match(attributes, "[Nn]ame%s*=%s*[\"']([^\"']+)[\"']")
      if name then
        table.insert(frameNames, name)
      end
    end
  end
  return includes, frameNames
end

local function loadLuaFile(context, addon, path, relativePath)
  local source, readError = util.readFile(path)
  if not source then
    context:recordError(relativePath, "unable to read file: " .. tostring(readError))
    return false
  end
  local chunk, compileError = compileChunk(source, "@" .. relativePath, context.env)
  if not chunk then
    context:recordError(relativePath, "syntax error: " .. tostring(compileError))
    return false
  end
  table.insert(addon.loadedFiles, relativePath)
  return context:protectedCall(relativePath, chunk, addon.name, addon.privateTable)
end

local loadFile

local function loadXmlFile(context, addon, path, relativePath, depth)
  local source, readError = util.readFile(path)
  if not source then
    context:recordError(relativePath, "unable to read file: " .. tostring(readError))
    return false
  end
  table.insert(addon.loadedFiles, relativePath)
  local includes, frameNames = loader.parseXml(source)
  for _, name in ipairs(frameNames) do
    context:addWarning(string.format(
      "%s declares frame '%s' in XML; XML frame definitions are not simulated",
      relativePath,
      name
    ))
  end
  local directory = util.dirname(relativePath)
  local ok = true
  for _, include in ipairs(includes) do
    local childRelative = util.joinPath(directory, include)
    ok = loadFile(context, addon, childRelative, depth + 1) and ok
  end
  return ok
end

--- Load one file referenced by a .toc (or by an XML include).
function loadFile(context, addon, relativePath, depth)
  depth = depth or 0
  if depth > 16 then
    context:recordError(relativePath, "include depth exceeded; circular XML include?")
    return false
  end
  local path = util.resolveCaseInsensitive(addon.directory, relativePath)
  if not path then
    context:recordError(relativePath, string.format(
      "file listed in %s.toc does not exist",
      addon.name
    ))
    return false
  end
  local extension = string.lower(string.match(relativePath, "%.([%w]+)$") or "")
  if extension == "lua" then
    return loadLuaFile(context, addon, path, relativePath)
  elseif extension == "xml" then
    return loadXmlFile(context, addon, path, relativePath, depth)
  end
  context:addWarning(string.format("skipping unsupported file type: %s", relativePath))
  return true
end

loader.loadFile = loadFile

--- Prepare (but do not execute) an addon from a directory or .toc path.
-- @param context table sandbox context
-- @param path string addon directory or explicit .toc file
-- @param options table|nil { flavor = "mainline" }
-- @return table|nil addon record, string|nil error
function loader.prepare(context, path, options)
  options = options or {}
  path = util.normalizePath(path)
  local tocPath
  if string.lower(string.sub(path, -4)) == ".toc" then
    tocPath = path
  else
    local candidates = tocModule.discover(path)
    if #candidates == 0 then
      return nil, string.format("no .toc file found in '%s'", path)
    end
    for _, candidate in ipairs(candidates) do
      if options.flavor and candidate.flavor == string.lower(options.flavor) then
        tocPath = candidate.path
        break
      elseif not options.flavor and not candidate.flavor then
        tocPath = candidate.path
        break
      end
    end
    tocPath = tocPath or candidates[1].path
  end

  local manifest, parseError = tocModule.parseFile(tocPath)
  if not manifest then
    return nil, parseError
  end

  local requiredDeps, optionalDeps = tocModule.dependencies(manifest)
  local savedVariables, savedVariablesPerCharacter = tocModule.savedVariables(manifest)

  local addon = {
    name = manifest.name,
    directory = manifest.directory,
    manifest = manifest,
    privateTable = {},
    loadedFiles = {},
    loaded = false,
    dependencies = requiredDeps,
    optionalDependencies = optionalDeps,
    savedVariables = savedVariables,
    savedVariablesPerCharacter = savedVariablesPerCharacter,
  }
  table.insert(context.addons, addon)
  return addon
end

--- Execute every file listed in the addon manifest.
-- @return boolean true when no file failed to load
function loader.load(context, addon)
  local ok = true
  for _, name in ipairs(addon.savedVariables) do
    if context.env[name] == nil then
      context:setGlobal(name, context.savedVariables[name])
    end
  end
  for _, name in ipairs(addon.savedVariablesPerCharacter) do
    if context.env[name] == nil then
      context:setGlobal(name, context.savedVariables[name])
    end
  end
  for _, relativePath in ipairs(addon.manifest.files) do
    ok = loadFile(context, addon, relativePath) and ok
  end
  addon.loaded = true
  return ok
end

--- Order addons so dependencies load first (stable, cycle tolerant).
function loader.resolveOrder(addons)
  local byName = {}
  for _, addon in ipairs(addons) do
    byName[string.lower(addon.name)] = addon
  end
  local ordered, visiting, visited = {}, {}, {}
  local function visit(addon)
    local key = string.lower(addon.name)
    if visited[key] or visiting[key] then
      return
    end
    visiting[key] = true
    for _, dependency in ipairs(addon.dependencies) do
      local target = byName[string.lower(dependency)]
      if target then
        visit(target)
      end
    end
    for _, dependency in ipairs(addon.optionalDependencies) do
      local target = byName[string.lower(dependency)]
      if target then
        visit(target)
      end
    end
    visiting[key] = nil
    visited[key] = true
    table.insert(ordered, addon)
  end
  for _, addon in ipairs(addons) do
    visit(addon)
  end
  return ordered
end

--- Report dependencies that are not present in the loaded set.
-- Optional dependencies are included and flagged, because code paths behind
-- them stay untested when the dependency is absent.
function loader.missingDependencies(addons)
  local present = {}
  for _, addon in ipairs(addons) do
    present[string.lower(addon.name)] = true
  end
  local missing = {}
  for _, addon in ipairs(addons) do
    for _, dependency in ipairs(addon.dependencies) do
      if not present[string.lower(dependency)] then
        table.insert(missing, { addon = addon.name, dependency = dependency, optional = false })
      end
    end
    for _, dependency in ipairs(addon.optionalDependencies) do
      if not present[string.lower(dependency)] then
        table.insert(missing, { addon = addon.name, dependency = dependency, optional = true })
      end
    end
  end
  return missing
end

return loader
