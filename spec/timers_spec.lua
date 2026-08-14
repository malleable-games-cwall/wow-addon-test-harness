local environment = require("wowharness.environment")

describe("virtual clock", function()
  local context, env

  before_each(function()
    context = environment.create()
    env = context.env
  end)

  it("does not advance on its own", function()
    local fired = false
    env.C_Timer.After(1, function()
      fired = true
    end)
    assert.is_false(fired)
    assert.are.equal(0, env.GetTime())
  end)

  it("runs C_Timer.After callbacks when time passes", function()
    local order = {}
    env.C_Timer.After(2, function()
      table.insert(order, "late")
    end)
    env.C_Timer.After(0.5, function()
      table.insert(order, "early")
    end)

    context.clock:advance(1)
    assert.are.same({ "early" }, order)

    context.clock:advance(2)
    assert.are.same({ "early", "late" }, order)
    assert.are.equal(3, env.GetTime())
  end)

  it("repeats tickers for the requested number of iterations", function()
    local ticks = 0
    env.C_Timer.NewTicker(0.25, function()
      ticks = ticks + 1
    end, 3)
    context.clock:advance(5)
    assert.are.equal(3, ticks)
    assert.are.equal(0, context.clock:pendingCount())
  end)

  it("stops a ticker that is cancelled from its own callback", function()
    local ticks = 0
    local ticker
    ticker = env.C_Timer.NewTicker(0.1, function()
      ticks = ticks + 1
      if ticks == 2 then
        ticker:Cancel()
      end
    end)
    context.clock:advance(1)
    assert.are.equal(2, ticks)
  end)

  it("drives OnUpdate for visible frames only", function()
    local shownElapsed, hiddenElapsed = 0, 0
    local shown = env.CreateFrame("Frame")
    shown:SetScript("OnUpdate", function(_, elapsed)
      shownElapsed = shownElapsed + elapsed
    end)
    local hidden = env.CreateFrame("Frame")
    hidden:Hide()
    hidden:SetScript("OnUpdate", function(_, elapsed)
      hiddenElapsed = hiddenElapsed + elapsed
    end)

    context.clock:advance(1, 0.1)

    assert.is_true(math.abs(shownElapsed - 1) < 1e-9)
    assert.are.equal(0, hiddenElapsed)
  end)

  it("captures errors thrown by timer callbacks", function()
    env.C_Timer.After(0.1, function()
      error("timer exploded")
    end)
    context.clock:advance(1)
    assert.are.equal(1, #context.errors)
    assert.is_truthy(string.find(context.errors[1].message, "timer exploded", 1, true))
  end)
end)
