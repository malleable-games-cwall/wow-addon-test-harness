local runner = require("wowharness.runner")

describe("runner", function()
  it("passes a healthy addon", function()
    local result = runner.run({ addons = { "spec/fixtures/SampleAddon" } })
    assert.is_true(result.passed)
    assert.are.equal(0, #result.errors)
    assert.are.equal("SampleAddon", result.addons[1].name)
    assert.are.equal("1.2.3", result.addons[1].version)
    assert.is_true(result.frames > 0)
    assert.are.same({ { command = "/sample", key = "SAMPLEADDON" } }, result.slashCommands)
  end)

  it("fails an addon that errors during login", function()
    local result = runner.run({ addons = { "spec/fixtures/BrokenAddon" } })
    assert.is_false(result.passed)
    local messages = {}
    for _, err in ipairs(result.errors) do
      table.insert(messages, err.message)
    end
    local joined = table.concat(messages, "\n")
    assert.is_truthy(string.find(joined, "does not exist", 1, true))
    assert.is_truthy(string.find(joined, "nil value", 1, true))
  end)

  it("fails when no addon path is given", function()
    local result = runner.run({ addons = {} })
    assert.is_false(result.passed)
    assert.are.equal("configuration", result.errors[1].label)
  end)

  it("warns about dependencies that are not loaded", function()
    local result = runner.run({ addons = { "spec/fixtures/SampleAddon" } })
    local joined = ""
    for _, warning in ipairs(result.warnings) do
      joined = joined .. warning.message .. "\n"
    end
    assert.is_truthy(string.find(joined, "MissingLibrary", 1, true))
  end)

  it("runs only the slash commands that were requested", function()
    local result = runner.run({
      addons = { "spec/fixtures/SampleAddon" },
      slashCommands = { "/sample hello" },
    })
    local outputs = {}
    for _, entry in ipairs(result.output) do
      table.insert(outputs, entry.message)
    end
    assert.is_truthy(string.find(table.concat(outputs, "\n"), "sample: hello", 1, true))
  end)

  it("runs a scenario file expressed as steps", function()
    local result = runner.run({
      addons = { "spec/fixtures/SampleAddon" },
      scenario = "spec/fixtures/scenario_steps.lua",
    })
    assert.is_true(result.passed)
    local joined = ""
    for _, entry in ipairs(result.output) do
      joined = joined .. entry.message .. "\n"
    end
    assert.is_truthy(string.find(joined, "sample: from scenario", 1, true))
  end)

  it("runs a scenario file expressed as a function", function()
    local result = runner.run({
      addons = { "spec/fixtures/SampleAddon" },
      scenario = "spec/fixtures/scenario_function.lua",
    })
    assert.is_true(result.passed)
    local joined = ""
    for _, entry in ipairs(result.output) do
      joined = joined .. entry.message .. "\n"
    end
    assert.is_truthy(string.find(joined, "sample: scripted", 1, true))
  end)

  it("reports scenario failures without crashing", function()
    local result = runner.run({
      addons = { "spec/fixtures/SampleAddon" },
      scenario = "spec/fixtures/does_not_exist.lua",
    })
    assert.is_false(result.passed)
    assert.are.equal("scenario", result.errors[#result.errors].label)
  end)

  it("simulates the documented login sequence", function()
    local result = runner.run({ addons = { "spec/fixtures/SampleAddon" } })
    local fired = {}
    for _, entry in ipairs(result.steps) do
      if entry.step == "event" then
        table.insert(fired, (string.match(entry.detail, "^(%S+)")))
      end
    end
    local joined = table.concat(fired, ",")
    assert.is_truthy(string.find(joined, "ADDON_LOADED", 1, true))
    assert.is_truthy(string.find(joined, "PLAYER_LOGIN", 1, true))
    assert.is_truthy(string.find(joined, "PLAYER_ENTERING_WORLD", 1, true))
    assert.is_truthy(string.find(joined, "PLAYER_LOGOUT", 1, true))
  end)
end)
