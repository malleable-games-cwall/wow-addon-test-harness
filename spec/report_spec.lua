local report = require("wowharness.report")
local runner = require("wowharness.runner")

describe("report", function()
  local passing, failing

  setup(function()
    passing = runner.run({ addons = { "spec/fixtures/SampleAddon" } })
    failing = runner.run({ addons = { "spec/fixtures/BrokenAddon" } })
  end)

  describe("json encoder", function()
    it("encodes scalars", function()
      assert.are.equal("null", report.toJson(nil))
      assert.are.equal("true", report.toJson(true))
      assert.are.equal("12.5", report.toJson(12.5))
      assert.are.equal('"hi"', report.toJson("hi"))
    end)

    it("escapes control characters", function()
      assert.are.equal('"a\\nb\\"c"', report.toJson('a\nb"c'))
    end)

    it("encodes arrays and objects with stable key order", function()
      assert.are.equal("[1,2]", report.toJson({ 1, 2 }))
      assert.are.equal('{"a":1,"b":2}', report.toJson({ b = 2, a = 1 }))
    end)
  end)

  describe("text output", function()
    it("summarises a passing run", function()
      local text = report.text(passing, { color = false })
      assert.is_truthy(string.find(text, "SampleAddon", 1, true))
      assert.is_truthy(string.find(text, "PASS", 1, true))
      assert.is_falsy(string.find(text, "\27[", 1, true))
    end)

    it("lists globals the harness does not provide", function()
      local result = runner.run({ addons = { "spec/fixtures/UnmockedAddon" } })
      local text = report.text(result, { color = false })
      assert.is_truthy(string.find(text, "Globals the harness does not provide (1)", 1, true))
      assert.is_truthy(string.find(text, "GetRealZoneText", 1, true))
    end)

    it("lists errors for a failing run", function()
      local text = report.text(failing, { color = false })
      assert.is_truthy(string.find(text, "FAIL", 1, true))
      assert.is_truthy(string.find(text, "Errors", 1, true))
    end)

    it("adds ANSI colour when asked", function()
      local text = report.text(passing, { color = true })
      assert.is_truthy(string.find(text, "\27[", 1, true))
    end)

    it("includes addon output only in verbose mode", function()
      assert.is_falsy(string.find(report.text(passing, {}), "[print]", 1, true))
      assert.is_truthy(string.find(report.text(passing, { verbose = true }), "[print]", 1, true))
    end)
  end)

  describe("junit output", function()
    it("reports zero failures for a passing run", function()
      local xml = report.junit(passing)
      assert.is_truthy(string.find(xml, 'failures="0"', 1, true))
      assert.is_truthy(string.find(xml, 'name="SampleAddon"', 1, true))
    end)

    it("emits failure elements for a failing run", function()
      local xml = report.junit(failing)
      assert.is_truthy(string.find(xml, "<failure", 1, true))
    end)

    it("escapes xml special characters", function()
      local xml = report.junit({
        addons = { { name = "A&B" } },
        errors = {},
      })
      assert.is_truthy(string.find(xml, "A&amp;B", 1, true))
    end)
  end)

  it("dispatches on format", function()
    assert.is_truthy(string.find(report.render(passing, "json"), '"passed":true', 1, true))
    assert.is_truthy(string.find(report.render(passing, "junit"), "<testsuite", 1, true))
    assert.is_truthy(string.find(report.render(passing, "text", { color = false }), "PASS", 1, true))
  end)
end)
