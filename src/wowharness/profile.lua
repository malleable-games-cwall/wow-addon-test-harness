--- Default simulated character / client profile.
--
-- Everything the mock game APIs report about the world lives here so callers
-- can override it from the CLI or from their own scenario scripts.
local profile = {}

local function defaultUnit(overrides)
  local unit = {
    name = "Testdummy",
    realm = "Harness",
    class = "MAGE",
    className = "Mage",
    classId = 8,
    race = "Gnome",
    raceName = "Gnome",
    raceId = 7,
    faction = "Alliance",
    level = 70,
    sex = 2,
    guid = "Player-0000-00000001",
    health = 100,
    maxHealth = 100,
    power = 50,
    maxPower = 100,
  }
  for key, value in pairs(overrides or {}) do
    unit[key] = value
  end
  return unit
end

--- Build a fresh profile table.
-- @param overrides table|nil shallow overrides applied to the top level
function profile.new(overrides)
  local player = defaultUnit()
  local built = {
    locale = "enUS",
    realm = player.realm,
    serverTime = 1700000000,
    build = {
      version = "11.0.2",
      build = "56000",
      date = "Aug 14 2024",
      tocVersion = 110002,
    },
    units = {
      player = player,
      target = nil,
      focus = nil,
      pet = nil,
    },
  }
  for key, value in pairs(overrides or {}) do
    built[key] = value
  end
  built.units.player = built.units.player or player
  return built
end

profile.defaultUnit = defaultUnit

return profile
