--- Paperdoll and bag mocks: what the player is wearing, what is in the bags,
-- and the equip call an addon makes to move one into the other.
local inventory = {}

local NUM_BAG_SLOTS = 4

local function items(context)
  return context.state.items
end

--- Item entries are addressed by whatever key a scenario used (a link, a name)
-- and are stored once, so the bags and the paperdoll agree about an item.
local function itemInfo(context, key)
  if key == nil then
    return nil
  end
  return items(context)[key]
end

local function installItems(context)
  local env = context.env

  env.GetItemInfo = function(key)
    local entry = itemInfo(context, key)
    if not entry then
      return nil
    end
    local link = entry.link or ("|cffffffff|Hitem:" .. tostring(entry.id) .. "|h[" ..
      tostring(entry.name) .. "]|h|r")
    return entry.name, link, entry.quality or 1, entry.level or 1, entry.minLevel or 1,
      entry.itemType or "Armor", entry.itemSubType or "Cloth", entry.stackCount or 1,
      entry.equipLocation, entry.texture
  end
  env.GetItemInfoInstant = function(key)
    local entry = itemInfo(context, key)
    if not entry then
      return nil
    end
    return entry.id, entry.itemType or "Armor", entry.itemSubType or "Cloth",
      entry.equipLocation, entry.texture
  end
end

local function installPaperdoll(context)
  local env = context.env

  local function equippedKey(slot)
    return context.state.equipment[slot]
  end

  env.GetInventoryItemLink = function(_, slot)
    local entry = itemInfo(context, equippedKey(slot))
    return entry and (entry.link or equippedKey(slot)) or nil
  end
  env.GetInventoryItemID = function(_, slot)
    local entry = itemInfo(context, equippedKey(slot))
    return entry and entry.id or nil
  end
  env.GetInventoryItemTexture = function(_, slot)
    local entry = itemInfo(context, equippedKey(slot))
    return entry and entry.texture or nil
  end
  env.GetInventoryItemQuality = function(_, slot)
    local entry = itemInfo(context, equippedKey(slot))
    return entry and entry.quality or nil
  end
  env.GetInventoryItemDurability = function() return nil end
  env.GetInventorySlotInfo = function(name)
    return context.state.slotIds[name] or 0
  end

  -- Both returns are the average of what is worn; the harness has no concept of
  -- bagged upgrades pulling the two apart.
  env.GetAverageItemLevel = function()
    local total, count = 0, 0
    for _, key in pairs(context.state.equipment) do
      local entry = itemInfo(context, key)
      if entry then
        total, count = total + (entry.level or 0), count + 1
      end
    end
    local average = count > 0 and total / count or 0
    return average, average
  end

  env.GetSpecialization = function()
    return context.state.specialization and context.state.specialization.index or nil
  end
  env.GetSpecializationInfo = function()
    local spec = context.state.specialization
    if not spec then
      return nil
    end
    return spec.id, spec.name, spec.description, spec.icon
  end
end

local function installBags(context)
  local env = context.env

  local function bag(index)
    return context.state.bags[index] or {}
  end

  env.NUM_BAG_SLOTS = NUM_BAG_SLOTS
  env.C_Container = {
    GetContainerNumSlots = function(index)
      return #bag(index)
    end,
    GetContainerItemLink = function(index, slot)
      local key = bag(index)[slot]
      local entry = itemInfo(context, key)
      return entry and (entry.link or key) or key
    end,
    GetContainerItemInfo = function(index, slot)
      local entry = itemInfo(context, bag(index)[slot])
      if not entry then
        return nil
      end
      return {
        iconFileID = entry.texture,
        stackCount = entry.stackCount or 1,
        quality = entry.quality or 1,
        hyperlink = entry.link,
        itemID = entry.id,
      }
    end,
    UseContainerItem = function(index, slot)
      table.insert(context.state.interactions, {
        action = "useContainerItem",
        detail = bag(index)[slot],
      })
    end,
  }

  --- Equips by key or link, which is what an addon has to hand from a bag scan.
  env.EquipItemByName = function(key, slot)
    local resolved = key
    if not itemInfo(context, resolved) then
      for candidate, entry in pairs(items(context)) do
        if entry.link == key then
          resolved = candidate
          break
        end
      end
    end
    if not itemInfo(context, resolved) then
      context:addWarning(string.format("EquipItemByName: unknown item '%s'", tostring(key)))
      return false
    end
    if context.state.inCombat then
      -- Matches the client: the call is simply dropped in combat.
      return false
    end

    context.state.equipment[slot] = resolved
    table.insert(context.state.interactions, { action = "equip", detail = resolved, slot = slot })
    context.events:fire("PLAYER_EQUIPMENT_CHANGED", slot, true)
    return true
  end
end

function inventory.install(context)
  context.state.equipment = context.state.equipment or {}
  context.state.bags = context.state.bags or {}
  context.state.slotIds = context.state.slotIds or {}
  context.state.interactions = context.state.interactions or {}

  installItems(context)
  installPaperdoll(context)
  installBags(context)

  -- The character sheet exists so an addon can take it over, like the other
  -- managed panels in api/interaction.lua.
  local character = context.createFrame("Frame", "CharacterFrame", context.env.UIParent)
  character:Hide()

  local tooltip = context.env.GameTooltip
  if tooltip then
    tooltip.SetInventoryItem = function(self, unit, slot)
      self.inventorySlot = slot
      table.insert(context.state.interactions, {
        action = "tooltip",
        detail = context.state.equipment[slot],
        unit = unit,
      })
    end
  end
end

inventory.NUM_BAG_SLOTS = NUM_BAG_SLOTS

return inventory
