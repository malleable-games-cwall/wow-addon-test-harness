local environment = require("wowharness.environment")
local loader = require("wowharness.loader")

describe("addon loader", function()
  local context

  before_each(function()
    context = environment.create()
    context.savedVariables = {}
  end)

  it("loads every file listed in the toc", function()
    local addon = assert(loader.prepare(context, "spec/fixtures/SampleAddon"))
    assert.is_true(loader.load(context, addon))
    assert.are.same({ "Core.lua", "UI.lua" }, addon.loadedFiles)
    assert.are.equal(0, #context.errors)
    assert.is_truthy(context.env.SampleAddonFrame)
  end)

  it("passes the addon name and private table to each file", function()
    local addon = assert(loader.prepare(context, "spec/fixtures/SampleAddon"))
    loader.load(context, addon)
    assert.are.equal(addon.privateTable.frame, context.env.SampleAddonFrame)
  end)

  it("reports files that are missing from disk", function()
    local addon = assert(loader.prepare(context, "spec/fixtures/BrokenAddon"))
    loader.load(context, addon)
    assert.are.equal(1, #context.errors)
    assert.are.equal("Missing.lua", context.errors[1].label)
  end)

  it("follows Script includes in xml files", function()
    local addon = assert(loader.prepare(context, "spec/fixtures/XmlAddon"))
    loader.load(context, addon)
    assert.is_true(context.env.XmlAddonLoaded)
    assert.are.same({ "Bindings.xml", "Loaded.lua" }, addon.loadedFiles)
  end)

  it("warns that xml frame definitions are not simulated", function()
    local addon = assert(loader.prepare(context, "spec/fixtures/XmlAddon"))
    loader.load(context, addon)
    local warnings = table.concat((function()
      local messages = {}
      for _, warning in ipairs(context.warnings) do
        table.insert(messages, warning.message)
      end
      return messages
    end)(), "\n")
    assert.is_truthy(string.find(warnings, "XmlAddonFrame", 1, true))
  end)

  it("fails cleanly when no toc exists", function()
    local addon, err = loader.prepare(context, "spec/fixtures")
    assert.is_nil(addon)
    assert.is_truthy(string.find(err, "no .toc file found", 1, true))
  end)

  it("parses script and include references out of xml", function()
    local includes, frameNames = loader.parseXml([[
      <Ui>
        <Include file="Sub/Other.xml"/>
        <Script file="Main.lua"/>
        <Frame name="SomeFrame"/>
      </Ui>
    ]])
    assert.are.same({ "Sub/Other.xml", "Main.lua" }, includes)
    assert.are.same({ "SomeFrame" }, frameNames)
  end)

  describe("dependency ordering", function()
    local function fakeAddon(name, dependencies)
      return {
        name = name,
        dependencies = dependencies or {},
        optionalDependencies = {},
      }
    end

    it("loads dependencies first", function()
      local ordered = loader.resolveOrder({
        fakeAddon("Consumer", { "Library" }),
        fakeAddon("Library"),
      })
      assert.are.same({ "Library", "Consumer" }, { ordered[1].name, ordered[2].name })
    end)

    it("survives dependency cycles", function()
      local ordered = loader.resolveOrder({
        fakeAddon("A", { "B" }),
        fakeAddon("B", { "A" }),
      })
      assert.are.equal(2, #ordered)
    end)

    it("reports dependencies that are absent", function()
      local consumer = fakeAddon("Consumer", { "Library" })
      consumer.optionalDependencies = { "Extras" }
      local missing = loader.missingDependencies({ consumer })
      assert.are.same({
        { addon = "Consumer", dependency = "Library", optional = false },
        { addon = "Consumer", dependency = "Extras", optional = true },
      }, missing)
    end)
  end)
end)
