local _, addon = ...

local frame = CreateFrame("Frame", "SampleAddonFrame", UIParent)
frame:SetSize(200, 120)
frame:SetPoint("CENTER")
frame:EnableMouse(true)
frame:SetMovable(true)

local title = frame:CreateFontString(nil, "OVERLAY")
title:SetPoint("TOP", frame, "TOP", 0, -8)
title:SetText("Sample Addon")

local button = CreateFrame("Button", "SampleAddonButton", frame)
button:SetSize(80, 22)
button:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
button:SetScript("OnClick", function()
  addon.clicked = (addon.clicked or 0) + 1
  print("sample: button clicked " .. addon.clicked .. " time(s)")
end)

frame:SetScript("OnUpdate", function(_, elapsed)
  addon.elapsed = (addon.elapsed or 0) + elapsed
end)

addon.frame = frame
addon.button = button
