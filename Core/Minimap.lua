local ADDON, MakersPath = ...
MakersPath = MakersPath or {}

local function DB()
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.minimap = MakersPathDB.minimap or {}
  if MakersPathDB.minimap.minimapPos == nil then MakersPathDB.minimap.minimapPos = 220 end
  if MakersPathDB.minimap.hide == nil then MakersPathDB.minimap.hide = false end
  return MakersPathDB
end

local LDB     = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

local launcher = LDB:NewDataObject("MakersPath", {
  type  = "launcher",
  icon  = "Interface\\AddOns\\MakersPath\\Art\\makerspathmm",
  label = "Maker's Path",
  OnClick = function(_, button)
    if button == "LeftButton" then
      if MakersPathFrame and MakersPathFrame:IsShown() then
        MakersPathFrame:Hide()
      else
        if MakersPath and MakersPath.GearFinder and MakersPath.GearFinder.BeginSession then
          MakersPath.GearFinder:BeginSession()
        end
        if MakersPathFrame then MakersPathFrame:Show() end
      end
    elseif button == "RightButton" then
      if MakersPath and MakersPath.UI and MakersPath.UI.ToggleProfBook then
        MakersPath.UI.ToggleProfBook()
      end
    end
  end,
  OnTooltipShow = function(tt)
    tt:AddLine("|cff00ccffMaker's Path|r")
    tt:AddLine("Left-click: open main panel")
    tt:AddLine("Right-click: open Profession Book")
  end,
})

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, ev, name)
  if ev == "ADDON_LOADED" and name == ADDON then
    LDBIcon:Register("MakersPath", launcher, DB().minimap)
  end
end)

function MakersPath_Minimap_Hide() DB().minimap.hide = true;  LDBIcon:Hide("MakersPath")  end
function MakersPath_Minimap_Show() DB().minimap.hide = false; LDBIcon:Show("MakersPath") end