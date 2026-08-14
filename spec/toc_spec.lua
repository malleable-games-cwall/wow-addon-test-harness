local toc = require("wowharness.toc")

describe("toc parser", function()
  it("reads directives, files and comments", function()
    local manifest = toc.parse(table.concat({
      "## Interface: 110002",
      "## Title: Sample Addon",
      "# a plain comment",
      "",
      "Core.lua",
      "UI\\Widgets.lua",
    }, "\n"))

    assert.are.equal("110002", manifest.metadata.Interface)
    assert.are.equal("Sample Addon", manifest.metadata.Title)
    assert.are.same({ "Core.lua", "UI\\Widgets.lua" }, manifest.files)
    assert.are.equal(0, #manifest.warnings)
  end)

  it("tolerates CRLF line endings and a BOM", function()
    local manifest = toc.parse("\239\187\191## Title: Windows\r\nCore.lua\r\n")
    assert.are.equal("Windows", manifest.metadata.Title)
    assert.are.same({ "Core.lua" }, manifest.files)
  end)

  it("records malformed directives as warnings", function()
    local manifest = toc.parse("## NotADirective\nCore.lua")
    assert.are.equal(1, #manifest.warnings)
    assert.are.equal(1, manifest.warnings[1].line)
  end)

  it("splits dependency and saved variable lists", function()
    local manifest = toc.parse(table.concat({
      "## Dependencies: Ace3, LibStub",
      "## OptionalDeps: Details",
      "## SavedVariables: FooDB , FooGlobal",
      "## SavedVariablesPerCharacter: FooChar",
    }, "\n"))

    local required, optional = toc.dependencies(manifest)
    assert.are.same({ "Ace3", "LibStub" }, required)
    assert.are.same({ "Details" }, optional)

    local saved, perCharacter = toc.savedVariables(manifest)
    assert.are.same({ "FooDB", "FooGlobal" }, saved)
    assert.are.same({ "FooChar" }, perCharacter)
  end)

  it("parses a toc file from disk", function()
    local manifest = assert(toc.parseFile("spec/fixtures/SampleAddon/SampleAddon.toc"))
    assert.are.equal("SampleAddon", manifest.name)
    assert.are.equal("1.2.3", manifest.metadata.Version)
    assert.are.same({ "Core.lua", "UI.lua" }, manifest.files)
  end)

  it("discovers toc files in an addon directory", function()
    local found = toc.discover("spec/fixtures/SampleAddon")
    assert.are.equal(1, #found)
    assert.are.equal("spec/fixtures/SampleAddon/SampleAddon.toc", found[1].path)
    assert.is_nil(found[1].flavor)
  end)
end)
