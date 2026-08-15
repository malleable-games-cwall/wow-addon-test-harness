--- Non widget game APIs: units, addon metadata, locale, combat state, and the
-- Lua "extensions" that Blizzard adds to the global namespace.
local game = {}

local DEFAULT_CLASS_COLORS = {
  WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
  PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
  HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
  ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
  PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
  DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
  SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
  MAGE = { r = 0.25, g = 0.78, b = 0.92 },
  WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
  MONK = { r = 0.00, g = 1.00, b = 0.59 },
  DRUID = { r = 1.00, g = 0.49, b = 0.04 },
  DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },
  EVOKER = { r = 0.20, g = 0.58, b = 0.50 },
}

local function installStringHelpers(env)
  env.strsplit = function(separators, text, limit)
    local results = {}
    local pattern = "[^" .. separators:gsub("(%W)", "%%%1") .. "]*"
    local position = 1
    while position <= #text + 1 do
      if limit and #results == limit - 1 then
        table.insert(results, string.sub(text, position))
        break
      end
      local from, to = string.find(text, pattern, position)
      table.insert(results, string.sub(text, from, to))
      position = to + 2
    end
    return (table.unpack or unpack)(results) -- luacheck: ignore 143
  end
  env.string.split = function(separators, text, limit)
    return env.strsplit(separators, text, limit)
  end

  env.strjoin = function(delimiter, ...)
    local pieces = {}
    for index = 1, select("#", ...) do
      table.insert(pieces, tostring((select(index, ...))))
    end
    return table.concat(pieces, delimiter)
  end
  env.string.join = env.strjoin

  env.strtrim = function(text, characters)
    characters = characters or " \t\r\n"
    local class = "[" .. characters:gsub("(%W)", "%%%1") .. "]"
    return (text:gsub("^" .. class .. "*(.-)" .. class .. "*$", "%1"))
  end
  env.string.trim = env.strtrim

  env.strlower = string.lower
  env.strupper = string.upper
  env.strlen = string.len
  env.strsub = string.sub
  env.strrep = string.rep
  env.strfind = string.find
  env.strmatch = string.match
  env.gsub = string.gsub
  env.format = string.format
  env.strconcat = function(...)
    return env.strjoin("", ...)
  end
  env.strbyte = string.byte
  env.strchar = string.char
end

local function installTableHelpers(env)
  env.tinsert = table.insert
  env.tremove = table.remove
  env.sort = table.sort
  env.tsort = table.sort
  env.wipe = function(target)
    for key in pairs(target) do
      target[key] = nil
    end
    return target
  end
  env.table.wipe = env.wipe
  env.tContains = function(list, value)
    for index = 1, #list do
      if list[index] == value then
        return true
      end
    end
    return false
  end
  env.tIndexOf = function(list, value)
    for index = 1, #list do
      if list[index] == value then
        return index
      end
    end
    return nil
  end
  env.CopyTable = function(source)
    local copy = {}
    for key, value in pairs(source) do
      if type(value) == "table" then
        copy[key] = env.CopyTable(value)
      else
        copy[key] = value
      end
    end
    return copy
  end
  env.max = math.max
  env.min = math.min
  env.abs = math.abs
  env.ceil = math.ceil
  env.floor = math.floor
  env.sqrt = math.sqrt
  env.random = math.random
  env.mod = math.fmod
end

function game.install(context)
  local env = context.env
  local profile = context.profile

  installStringHelpers(env)
  installTableHelpers(env)

  env.GetLocale = function()
    return profile.locale
  end
  env.GetRealmName = function()
    return profile.realm
  end
  env.GetBuildInfo = function()
    return profile.build.version, profile.build.build, profile.build.date, profile.build.tocVersion
  end
  env.GetCurrentRegion = function()
    return 1
  end
  env.IsWindowsClient = function()
    return true
  end
  env.IsMacClient = function()
    return false
  end

  local function unitData(unit)
    return profile.units[string.lower(tostring(unit))]
  end

  env.UnitExists = function(unit)
    return unitData(unit) ~= nil
  end
  env.UnitName = function(unit)
    local data = unitData(unit)
    if not data then
      return nil
    end
    return data.name, data.realm
  end
  env.UnitFullName = env.UnitName
  env.UnitClass = function(unit)
    local data = unitData(unit)
    if not data then
      return nil
    end
    return data.className, data.class, data.classId
  end
  env.UnitClassBase = function(unit)
    local data = unitData(unit)
    return data and data.class or nil
  end
  env.UnitRace = function(unit)
    local data = unitData(unit)
    if not data then
      return nil
    end
    return data.raceName, data.race, data.raceId
  end
  env.UnitLevel = function(unit)
    local data = unitData(unit)
    return data and data.level or 0
  end
  env.UnitFactionGroup = function(unit)
    local data = unitData(unit)
    if not data then
      return nil
    end
    return data.faction, data.faction
  end
  env.UnitSex = function(unit)
    local data = unitData(unit)
    return data and data.sex or 1
  end
  env.UnitGUID = function(unit)
    local data = unitData(unit)
    return data and data.guid or nil
  end
  env.UnitHealth = function(unit)
    local data = unitData(unit)
    return data and data.health or 0
  end
  env.UnitHealthMax = function(unit)
    local data = unitData(unit)
    return data and data.maxHealth or 0
  end
  env.UnitPower = function(unit)
    local data = unitData(unit)
    return data and data.power or 0
  end
  env.UnitPowerMax = function(unit)
    local data = unitData(unit)
    return data and data.maxPower or 0
  end
  env.UnitIsPlayer = function(unit)
    return string.lower(tostring(unit)) == "player"
  end
  env.UnitIsUnit = function(left, right)
    return string.lower(tostring(left)) == string.lower(tostring(right))
  end
  env.UnitAffectingCombat = function()
    return context.state.inCombat
  end
  env.UnitIsDeadOrGhost = function()
    return false
  end
  env.UnitInParty = function()
    return false
  end
  env.UnitInRaid = function()
    return nil
  end

  env.InCombatLockdown = function()
    return context.state.inCombat
  end
  env.IsInInstance = function()
    return context.state.inInstance, context.state.instanceType
  end
  env.IsInGroup = function()
    return false
  end
  env.IsInRaid = function()
    return false
  end
  env.GetNumGroupMembers = function()
    return 0
  end
  env.IsShiftKeyDown = function()
    return false
  end
  env.IsControlKeyDown = function()
    return false
  end
  env.IsAltKeyDown = function()
    return false
  end
  env.IsModifierKeyDown = function()
    return false
  end
  env.IsLoggedIn = function()
    return context.state.loggedIn
  end
  env.GetServerTime = function()
    return profile.serverTime + math.floor(context.clock:GetTime())
  end
  env.GetFramerate = function()
    return 60
  end

  env.RAID_CLASS_COLORS = {}
  for class, color in pairs(DEFAULT_CLASS_COLORS) do
    local entry = {
      r = color.r,
      g = color.g,
      b = color.b,
      colorStr = string.format(
        "ff%02x%02x%02x",
        math.floor(color.r * 255),
        math.floor(color.g * 255),
        math.floor(color.b * 255)
      ),
    }
    function entry:GenerateHexColor()
      return self.colorStr
    end
    env.RAID_CLASS_COLORS[class] = entry
  end
  env.CUSTOM_CLASS_COLORS = nil
  env.GetClassColor = function(class)
    local color = env.RAID_CLASS_COLORS[class]
    if not color then
      return 1, 1, 1, "ffffffff"
    end
    return color.r, color.g, color.b, color.colorStr
  end

  -- Addon metadata -----------------------------------------------------------
  local function getAddOnMetadata(addonName, field)
    local addon = context:findAddon(addonName)
    if not addon then
      return nil
    end
    return addon.manifest.metadata[field]
  end

  local function getAddOnInfo(addonName)
    local addon = context:findAddon(addonName)
    if not addon then
      return nil
    end
    return addon.name,
      addon.manifest.metadata.Title or addon.name,
      addon.manifest.metadata.Notes,
      true,
      "SECURE"
  end

  env.GetAddOnMetadata = getAddOnMetadata
  env.GetAddOnInfo = getAddOnInfo
  env.IsAddOnLoaded = function(addonName)
    local addon = context:findAddon(addonName)
    return addon ~= nil and addon.loaded == true
  end
  env.GetNumAddOns = function()
    return #context.addons
  end
  env.C_AddOns = {
    GetAddOnMetadata = getAddOnMetadata,
    GetAddOnInfo = getAddOnInfo,
    IsAddOnLoaded = env.IsAddOnLoaded,
    GetNumAddOns = env.GetNumAddOns,
    LoadAddOn = function()
      return true
    end,
    EnableAddOn = function() end,
    DisableAddOn = function() end,
  }
  env.LoadAddOn = env.C_AddOns.LoadAddOn

  env.C_CVar = {
    GetCVar = function(name)
      return context.state.cvars[name]
    end,
    SetCVar = function(name, value)
      context.state.cvars[name] = tostring(value)
      return true
    end,
    GetCVarBool = function(name)
      return context.state.cvars[name] == "1"
    end,
  }
  env.GetCVar = env.C_CVar.GetCVar
  env.SetCVar = env.C_CVar.SetCVar
  env.GetCVarBool = env.C_CVar.GetCVarBool

  -- Key bindings. Everything is kept in context.state.bindings so a scenario
  -- can assert what the addon asked the client to bind.
  env.GetCurrentBindingSet = function()
    return context.state.bindingSet
  end
  env.LoadBindings = function(set)
    context.state.bindingSet = set or context.state.bindingSet
    return true
  end
  env.SaveBindings = function(set)
    context.state.bindingSet = set or context.state.bindingSet
    return true
  end
  env.SetBinding = function(key, command)
    if type(key) ~= "string" then
      return false
    end
    context.state.bindings[key] = command
    return true
  end
  env.SetBindingClick = function(key, buttonName, mouseButton)
    return env.SetBinding(key, "CLICK " .. tostring(buttonName) .. ":" ..
      tostring(mouseButton or "LeftButton"))
  end
  env.GetBindingAction = function(key)
    return context.state.bindings[key] or ""
  end
  env.GetBindingKey = function(command)
    local keys = {}
    for key, bound in pairs(context.state.bindings) do
      if bound == command then
        table.insert(keys, key)
      end
    end
    table.sort(keys)
    return (table.unpack or unpack)(keys) -- luacheck: ignore 143
  end
  env.GetNumBindings = function()
    local count = 0
    for _ in pairs(context.state.bindings) do
      count = count + 1
    end
    return count
  end

  -- Gamepad. No device is connected unless a scenario adds one via
  -- session:setGamePad{...}.
  env.C_GamePad = {
    IsEnabled = function()
      return context.state.gamePad ~= nil
    end,
    GetAllDeviceIDs = function()
      return context.state.gamePad and { 1 } or {}
    end,
    GetActiveDeviceID = function()
      return context.state.gamePad and 1 or nil
    end,
    GetDeviceMappedState = function()
      return context.state.gamePad
    end,
    GetPowerLevel = function()
      return context.state.gamePad and context.state.gamePad.powerLevel or nil
    end,
    SetVibration = function() end,
    ApplyConfigs = function() end,
  }

  env.GetSpellInfo = function(spell)
    local entry = context.state.spells[spell]
    if not entry then
      return nil
    end
    return entry.name, nil, entry.icon, entry.castTime or 0, entry.minRange or 0,
      entry.maxRange or 40, entry.id
  end
  -- GetItemInfo lives in api/inventory.lua, next to the bags that use it.

  env.securecall = function(func, ...)
    if type(func) == "string" then
      func = env[func]
    end
    return func(...)
  end
  env.hooksecurefunc = function(target, name, hook)
    if hook == nil then
      target, name, hook = env, target, name
    end
    local original = target[name]
    if type(original) ~= "function" then
      context:addWarning(string.format("hooksecurefunc: '%s' is not a function", tostring(name)))
      return
    end
    target[name] = function(...)
      local results = { original(...) }
      hook(...)
      return (table.unpack or unpack)(results) -- luacheck: ignore 143
    end
  end
  env.issecurevariable = function()
    return true
  end
  env.geterrorhandler = function()
    return function(err)
      context:recordError("error handler", err)
    end
  end
  env.seterrorhandler = function() end

  env.date = os.date
  env.time = os.time
  env.difftime = os.difftime

  env.PlaySound = function() end
  env.PlaySoundFile = function() end
  env.RequestTimePlayed = function() end
  env.ReloadUI = function()
    context:addOutput("system", "ReloadUI() requested")
  end
  env.CreateColor = function(r, g, b, a)
    local color = { r = r, g = g, b = b, a = a }
    function color:GetRGB()
      return self.r, self.g, self.b
    end
    function color:GetRGBA()
      return self.r, self.g, self.b, self.a
    end
    function color:WrapTextInColorCode(text)
      return string.format(
        "|cff%02x%02x%02x%s|r",
        math.floor((self.r or 1) * 255),
        math.floor((self.g or 1) * 255),
        math.floor((self.b or 1) * 255),
        text
      )
    end
    return color
  end
  env.Mixin = function(target, ...)
    for index = 1, select("#", ...) do
      for key, value in pairs((select(index, ...))) do
        target[key] = value
      end
    end
    return target
  end
  env.CreateFromMixins = function(...)
    return env.Mixin({}, ...)
  end
end

game.DEFAULT_CLASS_COLORS = DEFAULT_CLASS_COLORS

return game
