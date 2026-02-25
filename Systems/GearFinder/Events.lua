local ADDON, ns = ...
local GF = ns.Systems.GearFinder

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("SKILL_LINES_CHANGED")

f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    GF:MarkDirty()
    return
  end

  GF:MarkDirty()
end)