local Session = require("wowharness.session")

describe("key bindings", function()
  local session, env

  before_each(function()
    session = Session.new()
    env = session.env
  end)

  it("records what SetBinding wrote", function()
    assert.is_true(env.SetBinding("PAD1", "JUMP"))
    assert.are.equal("JUMP", env.GetBindingAction("PAD1"))
    assert.are.equal("JUMP", session:bindings()["PAD1"])
  end)

  it("reports an empty action for an unbound key", function()
    assert.are.equal("", env.GetBindingAction("CTRL-PAD4"))
  end)

  it("clears a binding when the command is nil", function()
    env.SetBinding("PAD2", "TOGGLEGAMEMENU")
    env.SetBinding("PAD2", nil)
    assert.are.equal("", env.GetBindingAction("PAD2"))
  end)

  it("looks keys up by command", function()
    env.SetBinding("PADRSHOULDER", "TARGETNEARESTENEMY")
    assert.are.equal("PADRSHOULDER", env.GetBindingKey("TARGETNEARESTENEMY"))
  end)

  it("expands SetBindingClick into a CLICK command", function()
    env.SetBindingClick("PADSOCIAL", "MyButton", "LeftButton")
    assert.are.equal("CLICK MyButton:LeftButton", env.GetBindingAction("PADSOCIAL"))
  end)

  it("counts the bindings in place", function()
    env.SetBinding("PAD1", "JUMP")
    env.SetBinding("PAD3", "SITORSTAND")
    assert.are.equal(2, env.GetNumBindings())
  end)
end)

describe("gamepad", function()
  local session, env

  before_each(function()
    session = Session.new()
    env = session.env
  end)

  it("reports no device until one is connected", function()
    assert.is_false(env.C_GamePad.IsEnabled())
    assert.are.same({}, env.C_GamePad.GetAllDeviceIDs())
    assert.is_nil(env.C_GamePad.GetDeviceMappedState(1))
  end)

  it("exposes a connected device", function()
    session:setGamePad({ name = "DualSense", labelStyle = "playstation" })
    assert.is_true(env.C_GamePad.IsEnabled())
    assert.are.same({ 1 }, env.C_GamePad.GetAllDeviceIDs())
    assert.are.equal("DualSense", env.C_GamePad.GetDeviceMappedState(1).name)
  end)

  it("delivers button presses to a frame's handlers", function()
    local frame = env.CreateFrame("Frame", "PadFrame")
    local seen = {}
    frame:SetScript("OnGamePadButtonDown", function(_, button)
      table.insert(seen, "down:" .. button)
    end)
    frame:SetScript("OnGamePadButtonUp", function(_, button)
      table.insert(seen, "up:" .. button)
    end)

    assert.is_true(session:gamePadButton("PadFrame", "PAD1"))
    assert.is_true(session:gamePadButton(frame, "PAD1", false))
    assert.are.same({ "down:PAD1", "up:PAD1" }, seen)
  end)

  it("warns instead of erroring on an unknown frame", function()
    assert.is_false(session:gamePadButton("NoSuchFrame", "PAD1"))
    assert.are.equal(1, #session:warnings())
  end)

  it("tracks gamepad input toggles on frames", function()
    local frame = env.CreateFrame("Frame")
    frame:EnableGamePadButton(true)
    frame:EnableGamePadStick(true)
    assert.is_true(frame:IsGamePadButtonEnabled())
    assert.is_true(frame:IsGamePadStickEnabled())
  end)
end)

describe("UISpecialFrames", function()
  it("is a table addons can append to", function()
    local session = Session.new()
    table.insert(session.env.UISpecialFrames, "MyFrame")
    assert.are.same({ "MyFrame" }, session.env.UISpecialFrames)
  end)
end)
