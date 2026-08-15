-- The portable bundle lists its modules by hand, so a new source file is easy
-- to forget; only the packaging job notices, and only after the tests pass.
describe("portable bundle", function()
  local function sourceModules()
    local pipe = assert(io.popen("find src -name '*.lua'"))
    local found = {}
    for path in pipe:lines() do
      local name = path:gsub("^src/", ""):gsub("%.lua$", ""):gsub("/init$", ""):gsub("/", ".")
      found[name] = path
    end
    pipe:close()
    return found
  end

  it("bundles every module under src", function()
    local script = assert(io.open("scripts/build-bundle.lua")):read("*a")
    local listed = {}
    for name in script:gmatch('"(wowharness[%w%.]*)"') do
      listed[name] = true
    end

    for name, path in pairs(sourceModules()) do
      assert.is_true(listed[name] == true,
        path .. " is not in the MODULES list in scripts/build-bundle.lua")
    end
  end)
end)
