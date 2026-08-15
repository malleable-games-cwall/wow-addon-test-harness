local Session = require("wowharness.session")

describe("npc interaction", function()
  local session, env

  before_each(function()
    session = Session.new()
    env = session.env
  end)

  it("exposes the staged gossip conversation", function()
    session:setGossip({
      text = "Well met.",
      options = { { name = "Tell me about the town", gossipOptionID = 7 } },
      availableQuests = { { title = "Lost Cargo", questID = 100 } },
      activeQuests = { { title = "Rat Problem", questID = 99, isComplete = true } },
    })

    assert.are.equal("Well met.", env.C_GossipInfo.GetText())
    assert.are.equal(1, #env.C_GossipInfo.GetOptions())
    assert.are.equal(100, env.C_GossipInfo.GetAvailableQuests()[1].questID)
    assert.is_true(env.C_GossipInfo.GetActiveQuests()[1].isComplete)
  end)

  it("fires GOSSIP_SHOW when a conversation starts", function()
    local seen = 0
    local frame = env.CreateFrame("Frame")
    frame:RegisterEvent("GOSSIP_SHOW")
    frame:SetScript("OnEvent", function() seen = seen + 1 end)

    session:setGossip({ text = "Hello." })
    assert.are.equal(1, seen)
  end)

  it("records the option an addon selected", function()
    session:setGossip({ text = "Hello.", options = { { name = "Trade", gossipOptionID = 3 } } })
    env.C_GossipInfo.SelectOption(3)

    assert.are.same({ action = "gossipOption", detail = 3 }, session:interactions()[1])
  end)

  it("closes the conversation and fires GOSSIP_CLOSED", function()
    local closed = false
    local frame = env.CreateFrame("Frame")
    frame:RegisterEvent("GOSSIP_CLOSED")
    frame:SetScript("OnEvent", function() closed = true end)

    session:setGossip({ text = "Hello." })
    env.C_GossipInfo.CloseGossip()

    assert.is_true(closed)
    assert.are.equal("", env.C_GossipInfo.GetText())
  end)

  it("serves quest detail text and reward choices", function()
    session:setQuest({
      title = "Lost Cargo",
      detail = "My cart broke.",
      objective = "Recover three crates.",
      choices = {
        { name = "Sturdy Boots", texture = "boots", count = 1, quality = 2 },
        { name = "Worn Cloak", texture = "cloak", count = 1, quality = 1 },
      },
    }, "QUEST_DETAIL")

    assert.are.equal("Lost Cargo", env.GetTitleText())
    assert.are.equal("My cart broke.", env.GetQuestText())
    assert.are.equal("Recover three crates.", env.GetObjectiveText())
    assert.are.equal(2, env.GetNumQuestChoices())

    local name, texture, count, quality = env.GetQuestItemInfo("choice", 1)
    assert.are.equal("Sturdy Boots", name)
    assert.are.equal("boots", texture)
    assert.are.equal(1, count)
    assert.are.equal(2, quality)
  end)

  it("records accepting and turning in a quest", function()
    session:setQuest({ title = "Lost Cargo", completable = true }, "QUEST_DETAIL")
    env.AcceptQuest()
    env.GetQuestReward(2)

    assert.are.equal("acceptQuest", session:interactions()[1].action)
    assert.are.same({ action = "questReward", detail = 2 }, session:interactions()[2])
  end)

  it("lists merchant items and spends money on a purchase", function()
    session:setMoney(50000)
    session:setMerchant({
      items = {
        { name = "Health Potion", texture = "potion", price = 10000, quantity = 1, available = 5 },
        { name = "Iron Sword", texture = "sword", price = 90000, quantity = 1, available = -1 },
      },
    })

    assert.are.equal(2, env.GetMerchantNumItems())
    local name, texture, price, quantity, available = env.GetMerchantItemInfo(1)
    assert.are.equal("Health Potion", name)
    assert.are.equal("potion", texture)
    assert.are.equal(10000, price)
    assert.are.equal(1, quantity)
    assert.are.equal(5, available)

    env.BuyMerchantItem(1, 1)
    assert.are.equal(40000, env.GetMoney())
    assert.are.equal("Health Potion", session:purchases()[1].name)
  end)

  it("repurchases from the buyback list", function()
    session:setMerchant({ items = {}, buyback = { { name = "Old Dagger", price = 500 } } })

    assert.are.equal(1, env.GetNumBuybackItems())
    env.BuybackItem(1)
    assert.are.equal(0, env.GetNumBuybackItems())
    assert.is_true(session:purchases()[1].buyback)
  end)

  it("fires MERCHANT_CLOSED when the merchant is closed", function()
    local closed = false
    local frame = env.CreateFrame("Frame")
    frame:RegisterEvent("MERCHANT_CLOSED")
    frame:SetScript("OnEvent", function() closed = true end)

    session:setMerchant({ items = {} })
    env.CloseMerchant()
    assert.is_true(closed)
  end)

  it("provides the default panels so an addon can hide them", function()
    assert.is_table(env.GossipFrame)
    assert.is_table(env.QuestFrame)
    assert.is_table(env.MerchantFrame)

    env.ShowUIPanel(env.MerchantFrame)
    assert.is_true(env.MerchantFrame:IsShown())
    env.HideUIPanel(env.MerchantFrame)
    assert.is_false(env.MerchantFrame:IsShown())
  end)

  it("records the tooltip link an addon asked for", function()
    env.GameTooltip:SetOwner(env.UIParent, "ANCHOR_RIGHT")
    env.GameTooltip:SetHyperlink("item:1234")
    assert.are.same({ action = "tooltip", detail = "item:1234" }, session:interactions()[1])
  end)

  it("delivers stick movement to a frame", function()
    local seen
    local frame = env.CreateFrame("Frame")
    frame:EnableGamePadStick(true)
    frame:SetScript("OnGamePadStick", function(_, stick, x, y)
      seen = { stick = stick, x = x, y = y }
    end)

    assert.is_true(session:gamePadStick(frame, "Left", 0, -1))
    assert.are.same({ stick = "Left", x = 0, y = -1 }, seen)
  end)
end)
