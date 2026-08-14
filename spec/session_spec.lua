local Session = require("wowharness.session")

describe("session", function()
  local session

  before_each(function()
    session = Session.new()
    session:addAddon("spec/fixtures/SampleAddon")
    session:loadAddons()
  end)

  it("fires ADDON_LOADED with the addon name while loading", function()
    assert.are.equal(1, session.env.SampleAddonDB.launches)
  end)

  it("discovers registered slash commands", function()
    assert.are.same({ { command = "/sample", key = "SAMPLEADDON" } }, session:slashCommands())
  end)

  it("runs a slash command and captures its output", function()
    assert.is_true(session:slash("/sample status"))
    local output = session:output()
    assert.are.equal("sample: status", output[#output].message)
  end)

  it("warns when a slash command has no handler", function()
    local before = #session:warnings()
    assert.is_false(session:slash("/unknown"))
    local warnings = session:warnings()
    assert.are.equal(before + 1, #warnings)
    assert.is_truthy(string.find(warnings[#warnings].message, "/unknown", 1, true))
  end)

  it("clicks named frames", function()
    assert.is_true(session:click("SampleAddonButton"))
    local output = session:output()
    assert.are.equal("sample: button clicked 1 time(s)", output[#output].message)
  end)

  it("simulates combat with the paired events", function()
    session:setCombat(true)
    local addon = session.context.addons[1]
    assert.is_true(addon.privateTable.enteredCombat)
    assert.is_true(session.context.state.inCombat)
    session:setCombat(false)
    assert.is_false(session.context.state.inCombat)
  end)

  it("advances timers and OnUpdate handlers", function()
    session:advance(2)
    local addon = session.context.addons[1]
    assert.is_true(addon.privateTable.timerFired)
    assert.are.equal(4, addon.privateTable.ticks)
    assert.is_true(addon.privateTable.elapsed > 0)
  end)

  it("collects declared saved variables", function()
    session:fire("PLAYER_LOGOUT")
    local saved = session:collectSavedVariables()
    assert.are.equal(1, saved.SampleAddonDB.launches)
  end)

  it("carries saved variables into a later session", function()
    local next_ = Session.new({ savedVariables = session:collectSavedVariables() })
    next_:addAddon("spec/fixtures/SampleAddon")
    next_:loadAddons()
    assert.are.equal(2, next_.env.SampleAddonDB.launches)
  end)

  it("records a step log of everything it did", function()
    local kinds = {}
    for _, entry in ipairs(session.steps) do
      kinds[entry.step] = true
    end
    assert.is_true(kinds.discovered)
    assert.is_true(kinds.loaded)
    assert.is_true(kinds.event)
  end)
end)
