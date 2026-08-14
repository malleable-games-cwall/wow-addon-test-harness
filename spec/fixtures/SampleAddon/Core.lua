local addonName, addon = ...

addon.events = CreateFrame("Frame", "SampleAddonEventFrame")
addon.ticks = 0

addon.events:RegisterEvent("ADDON_LOADED")
addon.events:RegisterEvent("PLAYER_LOGIN")
addon.events:RegisterEvent("PLAYER_REGEN_DISABLED")

addon.events:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local loaded = ...
    if loaded ~= addonName then
      return
    end
    SampleAddonDB = SampleAddonDB or { launches = 0 }
    SampleAddonDB.launches = SampleAddonDB.launches + 1
  elseif event == "PLAYER_LOGIN" then
    print(addonName .. " loaded for " .. UnitName("player"))
  elseif event == "PLAYER_REGEN_DISABLED" then
    addon.enteredCombat = true
  end
end)

C_Timer.After(0.5, function()
  addon.timerFired = true
end)

C_Timer.NewTicker(0.25, function()
  addon.ticks = addon.ticks + 1
end, 4)

SLASH_SAMPLEADDON1 = "/sample"
SlashCmdList["SAMPLEADDON"] = function(message)
  print("sample: " .. (message ~= "" and message or "no arguments"))
end
