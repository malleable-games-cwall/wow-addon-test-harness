--- NPC interaction mocks: gossip, quest giving, merchants, the item tooltip and
-- the managed panel helpers addons use to hide the default windows.
local interaction = {}

local QUALITY_COLORS = {
  [0] = { r = 0.62, g = 0.62, b = 0.62 },
  [1] = { r = 1.00, g = 1.00, b = 1.00 },
  [2] = { r = 0.12, g = 1.00, b = 0.00 },
  [3] = { r = 0.00, g = 0.44, b = 0.87 },
  [4] = { r = 0.64, g = 0.21, b = 0.93 },
  [5] = { r = 1.00, g = 0.50, b = 0.00 },
}

local PANEL_FRAMES = { "GossipFrame", "QuestFrame", "MerchantFrame" }

local function gossip(context)
  return context.state.gossip or {}
end

local function quest(context)
  return context.state.quest or {}
end

local function merchant(context)
  return context.state.merchant or {}
end

local function record(context, action, detail)
  table.insert(context.state.interactions, { action = action, detail = detail })
end

local function installGossip(context)
  local env = context.env

  env.C_GossipInfo = {
    GetText = function()
      return gossip(context).text or ""
    end,
    GetOptions = function()
      return gossip(context).options or {}
    end,
    GetAvailableQuests = function()
      return gossip(context).availableQuests or {}
    end,
    GetActiveQuests = function()
      return gossip(context).activeQuests or {}
    end,
    SelectOption = function(id)
      record(context, "gossipOption", id)
    end,
    SelectAvailableQuest = function(id)
      record(context, "availableQuest", id)
    end,
    SelectActiveQuest = function(id)
      record(context, "activeQuest", id)
    end,
    CloseGossip = function()
      context.state.gossip = nil
      record(context, "closeGossip")
      context.events:fire("GOSSIP_CLOSED")
    end,
  }
end

local function installQuest(context)
  local env = context.env

  env.GetGreetingText = function() return quest(context).greeting or "" end
  env.GetTitleText = function() return quest(context).title or "" end
  env.GetQuestText = function() return quest(context).detail or "" end
  env.GetObjectiveText = function() return quest(context).objective or "" end
  env.GetProgressText = function() return quest(context).progress or "" end
  env.GetRewardText = function() return quest(context).reward or "" end
  env.IsQuestCompletable = function() return quest(context).completable and true or false end

  env.GetNumActiveQuests = function() return #(quest(context).active or {}) end
  env.GetActiveTitle = function(index)
    local entry = (quest(context).active or {})[index]
    if not entry then return nil end
    return entry.title, entry.isComplete
  end
  env.GetNumAvailableQuests = function() return #(quest(context).available or {}) end
  env.GetAvailableTitle = function(index)
    local entry = (quest(context).available or {})[index]
    return entry and entry.title or nil
  end
  env.SelectActiveQuest = function(index) record(context, "activeQuest", index) end
  env.SelectAvailableQuest = function(index) record(context, "availableQuest", index) end

  env.GetNumQuestChoices = function() return #(quest(context).choices or {}) end
  env.GetQuestItemInfo = function(_, index)
    local choice = (quest(context).choices or {})[index]
    if not choice then return nil end
    return choice.name, choice.texture, choice.count or 1, choice.quality or 1
  end

  env.AcceptQuest = function()
    record(context, "acceptQuest", quest(context).title)
    context.events:fire("QUEST_ACCEPTED")
    context.events:fire("QUEST_FINISHED")
  end
  env.DeclineQuest = function()
    record(context, "declineQuest", quest(context).title)
    context.events:fire("QUEST_FINISHED")
  end
  env.CompleteQuest = function()
    record(context, "completeQuest", quest(context).title)
    context.events:fire("QUEST_COMPLETE")
  end
  env.GetQuestReward = function(choice)
    record(context, "questReward", choice)
    context.events:fire("QUEST_FINISHED")
  end
  env.CloseQuest = function()
    record(context, "closeQuest")
    context.events:fire("QUEST_FINISHED")
  end
end

local function installMerchant(context)
  local env = context.env

  local function items()
    return merchant(context).items or {}
  end

  env.GetMerchantNumItems = function() return #items() end
  env.GetMerchantItemInfo = function(index)
    local item = items()[index]
    if not item then return nil end
    return item.name, item.texture, item.price or 0, item.quantity or 1,
      item.available or -1, item.isUsable ~= false, item.extendedCost or false
  end
  env.GetMerchantItemLink = function(index)
    local item = items()[index]
    return item and (item.link or item.name) or nil
  end
  env.BuyMerchantItem = function(index, quantity)
    local item = items()[index]
    if not item then return end
    context.state.money = math.max(0, (context.state.money or 0) - (item.price or 0) * (quantity or 1))
    table.insert(context.state.purchases, { name = item.name, quantity = quantity or 1 })
    record(context, "buy", item.name)
    context.events:fire("MERCHANT_UPDATE")
  end

  env.GetNumBuybackItems = function() return #(context.state.buyback or {}) end
  env.GetBuybackItemInfo = function(index)
    local item = (context.state.buyback or {})[index]
    if not item then return nil end
    return item.name, item.texture, item.price or 0, item.quantity or 1
  end
  env.GetBuybackItemLink = function(index)
    local item = (context.state.buyback or {})[index]
    return item and (item.link or item.name) or nil
  end
  env.BuybackItem = function(index)
    local item = (context.state.buyback or {})[index]
    if not item then return end
    table.remove(context.state.buyback, index)
    table.insert(context.state.purchases, { name = item.name, buyback = true })
    record(context, "buyback", item.name)
    context.events:fire("MERCHANT_UPDATE")
  end

  env.CloseMerchant = function()
    context.state.merchant = nil
    record(context, "closeMerchant")
    context.events:fire("MERCHANT_CLOSED")
  end

  env.GetMoney = function() return context.state.money or 0 end
  env.GetCoinTextureString = function(amount)
    return string.format("%dg", math.floor((amount or 0) / 10000))
  end
end

local function installPanels(context)
  local env = context.env

  -- The default windows exist so an addon can hide them; they are plain frames
  -- here, which is enough to observe HideUIPanel and OnShow hooks.
  for _, name in ipairs(PANEL_FRAMES) do
    local frame = context.createFrame("Frame", name, env.UIParent)
    frame:Hide()
  end

  env.ShowUIPanel = function(frame)
    if type(frame) == "table" and frame.Show then frame:Show() end
  end
  env.HideUIPanel = function(frame)
    if type(frame) == "table" and frame.Hide then frame:Hide() end
  end

  env.ITEM_QUALITY_COLORS = QUALITY_COLORS

  local tooltip = context.createFrame("GameTooltip", "GameTooltip", env.UIParent)
  tooltip:Hide()
  tooltip.SetOwner = function(self, owner, anchor)
    self.owner, self.anchor = owner, anchor
  end
  tooltip.SetHyperlink = function(self, link)
    self.link = link
    record(context, "tooltip", link)
  end
  tooltip.SetMerchantItem = function(self, index)
    self.merchantIndex = index
  end
  tooltip.ClearLines = function() end
  tooltip.AddLine = function() end
end

function interaction.install(context)
  context.state.interactions = context.state.interactions or {}
  context.state.purchases = context.state.purchases or {}
  context.state.buyback = context.state.buyback or {}
  context.state.money = context.state.money or 0

  installGossip(context)
  installQuest(context)
  installMerchant(context)
  installPanels(context)
end

interaction.QUALITY_COLORS = QUALITY_COLORS

return interaction
