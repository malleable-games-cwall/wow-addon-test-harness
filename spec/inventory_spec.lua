local Session = require("wowharness.session")

describe("inventory", function()
  local session, env

  before_each(function()
    session = Session.new()
    env = session.env
    session:setItems({
      ["Crown of Ash"] = {
        quality = 4, level = 480, equipLocation = "INVTYPE_HEAD", texture = 133071, id = 11,
      },
      ["Bright Blade"] = {
        quality = 3, level = 460, equipLocation = "INVTYPE_WEAPON", texture = 135328, id = 12,
      },
      ["Dull Blade"] = {
        quality = 2, level = 400, equipLocation = "INVTYPE_WEAPON", texture = 135274, id = 13,
      },
    })
  end)

  it("reports the item worn in an inventory slot", function()
    session:setEquipment({ [1] = "Crown of Ash", [16] = "Bright Blade" })

    assert.are.equal("Crown of Ash", env.GetInventoryItemLink("player", 1))
    assert.are.equal(4, env.GetInventoryItemQuality("player", 1))
    assert.are.equal(133071, env.GetInventoryItemTexture("player", 1))
    assert.is_nil(env.GetInventoryItemLink("player", 5))
  end)

  it("returns the equip location from GetItemInfo", function()
    local name, _, quality, level, _, _, _, _, equipLocation, texture =
      env.GetItemInfo("Bright Blade")

    assert.are.equal("Bright Blade", name)
    assert.are.equal(3, quality)
    assert.are.equal(460, level)
    assert.are.equal("INVTYPE_WEAPON", equipLocation)
    assert.are.equal(135328, texture)
  end)

  it("averages the item level of what is worn", function()
    session:setEquipment({ [1] = "Crown of Ash", [16] = "Bright Blade" })

    local equipped, total = env.GetAverageItemLevel()
    assert.are.equal(470, equipped)
    assert.are.equal(470, total)
  end)

  it("walks bag contents", function()
    session:setBags({ [0] = { "Bright Blade", "Dull Blade" } })

    assert.are.equal(2, env.C_Container.GetContainerNumSlots(0))
    assert.are.equal(0, env.C_Container.GetContainerNumSlots(1))
    assert.are.equal("Dull Blade", env.C_Container.GetContainerItemLink(0, 2))
    assert.are.equal(3, env.C_Container.GetContainerItemInfo(0, 1).quality)
  end)

  it("equips an item and fires PLAYER_EQUIPMENT_CHANGED", function()
    local changedSlot
    local frame = env.CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:SetScript("OnEvent", function(_, _, slot) changedSlot = slot end)

    assert.is_true(env.EquipItemByName("Bright Blade", 16))

    assert.are.equal(16, changedSlot)
    assert.are.equal("Bright Blade", session:equipped(16))
    assert.are.same({ action = "equip", detail = "Bright Blade", slot = 16 },
      session:interactions()[1])
  end)

  it("refuses to equip in combat, like the client", function()
    session:setCombat(true)

    assert.is_false(env.EquipItemByName("Bright Blade", 16))
    assert.is_nil(session:equipped(16))
  end)

  it("gives an addon a character frame to take over", function()
    assert.is_not_nil(env.CharacterFrame)
    assert.is_false(env.CharacterFrame:IsShown())

    env.ShowUIPanel(env.CharacterFrame)
    assert.is_true(env.CharacterFrame:IsShown())
  end)

  it("reports the specialisation a scenario staged", function()
    session:setSpecialization({ index = 2, id = 63, name = "Fire" })

    assert.are.equal(2, env.GetSpecialization())
    local id, name = env.GetSpecializationInfo(2)
    assert.are.equal(63, id)
    assert.are.equal("Fire", name)
  end)
end)
