local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function()
  UnmockedAddonZone = GetRealZoneText and GetRealZoneText() or "unknown"
end)

frame:RegisterEvent("PLAYER_LOGIN")
