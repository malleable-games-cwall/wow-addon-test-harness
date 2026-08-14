local frame = CreateFrame("Frame", "BrokenAddonFrame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
  local config = nil
  -- Classic hard failure: indexing a nil table during login.
  print(config.enabled)
end)
