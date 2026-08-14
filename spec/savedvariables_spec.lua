local savedvariables = require("wowharness.api.savedvariables")

describe("saved variables", function()
  it("serializes nested tables deterministically", function()
    local text = savedvariables.serialize({
      MyDB = { enabled = true, name = "Bob", nested = { 1, 2 } },
    })
    assert.is_truthy(string.find(text, "MyDB = {", 1, true))
    assert.is_truthy(string.find(text, 'name = "Bob"', 1, true))
    assert.are.equal(text, savedvariables.serialize({
      MyDB = { name = "Bob", nested = { 1, 2 }, enabled = true },
    }))
  end)

  it("quotes keys that are not identifiers", function()
    local text = savedvariables.serialize({ MyDB = { ["with space"] = 1 } })
    assert.is_truthy(string.find(text, '["with space"] = 1', 1, true))
  end)

  it("breaks reference cycles", function()
    local cyclic = {}
    cyclic.self = cyclic
    local text = savedvariables.serialize({ MyDB = cyclic })
    assert.is_truthy(string.find(text, "cycle", 1, true))
  end)

  it("round trips through a file", function()
    local path = os.tmpname()
    assert(savedvariables.write(path, { MyDB = { count = 3, list = { "a", "b" } } }))
    local loaded = assert(savedvariables.load(path))
    os.remove(path)
    assert.are.equal(3, loaded.MyDB.count)
    assert.are.same({ "a", "b" }, loaded.MyDB.list)
  end)

  it("reports unreadable files", function()
    local loaded, err = savedvariables.load("spec/fixtures/definitely-missing.lua")
    assert.is_nil(loaded)
    assert.is_truthy(err)
  end)

  it("reports syntax errors in a saved variables file", function()
    local path = os.tmpname()
    local handle = assert(io.open(path, "w"))
    handle:write("MyDB = {")
    handle:close()
    local loaded, err = savedvariables.load(path)
    os.remove(path)
    assert.is_nil(loaded)
    assert.is_truthy(err)
  end)
end)
