local environment = require("wowharness.environment")

describe("widget system", function()
  local context, env

  before_each(function()
    context = environment.create()
    env = context.env
  end)

  it("creates named frames and publishes them as globals", function()
    local frame = env.CreateFrame("Frame", "MyFrame", env.UIParent)
    assert.are.equal(frame, env.MyFrame)
    assert.are.equal("Frame", frame:GetObjectType())
    assert.are.equal("MyFrame", frame:GetName())
    assert.are.equal(env.UIParent, frame:GetParent())
  end)

  it("runs OnLoad when the frame is created", function()
    local frame = env.CreateFrame("Frame")
    assert.is_nil(frame:GetScript("OnLoad"))
  end)

  it("dispatches registered events only to registered frames", function()
    local received = {}
    local listening = env.CreateFrame("Frame")
    listening:RegisterEvent("PLAYER_LOGIN")
    listening:SetScript("OnEvent", function(_, event, argument)
      table.insert(received, event .. ":" .. tostring(argument))
    end)

    local silent = env.CreateFrame("Frame")
    silent:SetScript("OnEvent", function()
      table.insert(received, "should not happen")
    end)

    context.events:fire("PLAYER_LOGIN", "arg")
    context.events:fire("PLAYER_LOGOUT")

    assert.are.same({ "PLAYER_LOGIN:arg" }, received)
    assert.is_true(listening:IsEventRegistered("PLAYER_LOGIN"))
    listening:UnregisterEvent("PLAYER_LOGIN")
    assert.is_false(listening:IsEventRegistered("PLAYER_LOGIN"))
  end)

  it("keeps running after a handler raises an error", function()
    local calls = 0
    local broken = env.CreateFrame("Frame")
    broken:RegisterEvent("PLAYER_LOGIN")
    broken:SetScript("OnEvent", function()
      error("handler exploded")
    end)
    local healthy = env.CreateFrame("Frame")
    healthy:RegisterEvent("PLAYER_LOGIN")
    healthy:SetScript("OnEvent", function()
      calls = calls + 1
    end)

    context.events:fire("PLAYER_LOGIN")

    assert.are.equal(1, calls)
    assert.are.equal(1, #context.errors)
    assert.is_truthy(string.find(context.errors[1].message, "handler exploded", 1, true))
  end)

  it("fires OnShow and OnHide only on transitions", function()
    local events = {}
    local frame = env.CreateFrame("Frame")
    frame:SetScript("OnShow", function()
      table.insert(events, "show")
    end)
    frame:SetScript("OnHide", function()
      table.insert(events, "hide")
    end)

    frame:Show()
    frame:Hide()
    frame:Hide()
    frame:SetShown(true)

    assert.are.same({ "hide", "show" }, events)
    assert.is_true(frame:IsShown())
  end)

  it("treats a hidden ancestor as not visible", function()
    local parent = env.CreateFrame("Frame")
    local child = env.CreateFrame("Frame", nil, parent)
    assert.is_true(child:IsVisible())
    parent:Hide()
    assert.is_false(child:IsVisible())
    assert.is_true(child:IsShown())
  end)

  it("chains hooked scripts", function()
    local calls = {}
    local frame = env.CreateFrame("Button")
    frame:SetScript("OnClick", function()
      table.insert(calls, "first")
    end)
    frame:HookScript("OnClick", function()
      table.insert(calls, "second")
    end)
    frame:Click()
    assert.are.same({ "first", "second" }, calls)
  end)

  it("creates font strings and textures as regions", function()
    local frame = env.CreateFrame("Frame")
    local text = frame:CreateFontString("MyText", "OVERLAY")
    text:SetText("hello")
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    assert.are.equal("hello", env.MyText:GetText())
    assert.are.equal("FontString", text:GetObjectType())
    assert.are.equal("Interface\\Icons\\INV_Misc_QuestionMark", texture:GetTexture())
  end)

  it("records unmocked widget methods instead of erroring", function()
    local frame = env.CreateFrame("Frame")
    frame:SetSomethingBlizzardAddedLater(1)
    assert.are.equal(1, context.missingApi["Frame:SetSomethingBlizzardAddedLater"])
  end)

  it("errors on unmocked widget methods in strict mode", function()
    local strictContext = environment.create({ strict = true })
    local frame = strictContext.env.CreateFrame("Frame")
    assert.has_error(function()
      frame:TotallyNewApi()
    end)
  end)

  it("warns about invalid anchor points", function()
    local frame = env.CreateFrame("Frame")
    frame:SetPoint("MIDDLE")
    assert.are.equal(1, #context.warnings)
    assert.are.equal(1, frame:GetNumPoints())
  end)

  it("notes templates referenced by CreateFrame", function()
    env.CreateFrame("Button", "TemplatedButton", env.UIParent, "UIPanelButtonTemplate")
    assert.are.equal(1, context.templates.UIPanelButtonTemplate)
  end)
end)
