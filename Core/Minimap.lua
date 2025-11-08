local ADDON, MakersPath = ...
MakersPath = MakersPath or {}

local L = LibStub("AceLocale-3.0", true)
L = (L and L:GetLocale("MakersPath", true)) or setmetatable({}, { __index = function(_, k) return k end })


local function DB()
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.minimap = MakersPathDB.minimap or {}
  if MakersPathDB.minimap.minimapPos == nil then MakersPathDB.minimap.minimapPos = 220 end
  if MakersPathDB.minimap.hide == nil then MakersPathDB.minimap.hide = false end
  return MakersPathDB
end

local LDB     = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

if not LDB or not LDBIcon then
  function MakersPath_Minimap_Hide() end
  function MakersPath_Minimap_Show() end
  return
end

local launcher = LDB:NewDataObject("MakersPath", {
  type  = "launcher",
  icon  = "Interface\\AddOns\\MakersPath\\Art\\makerspathmm",
  label = L["ADDON_NAME"],
  OnClick = function(_, button)
    if button == "LeftButton" then
      if MakersPathFrame and MakersPathFrame:IsShown() then
        MakersPathFrame:Hide()
      else
        if MakersPath and MakersPath.GearFinder and MakersPath.GearFinder.BeginSession then
          MakersPath.GearFinder:BeginSession()
        end
        if MakersPath and MakersPath.UI and MakersPath.UI.EnsureMainPanelSize then
          MakersPath.UI.EnsureMainPanelSize()
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
    tt:AddLine(L["LDB_TT_TITLE"])
    tt:AddLine(L["LDB_TT_LEFT"])
    tt:AddLine(L["LDB_TT_RIGHT"])
  end,
})

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, ev, name)
  if ev == "ADDON_LOADED" and name == ADDON then
    LDBIcon:Register("MakersPath", launcher, DB().minimap)
    if DB().minimap.hide then
      LDBIcon:Hide("MakersPath")
    else
      LDBIcon:Show("MakersPath")
    end
  end
end)

function MakersPath_Minimap_Hide() DB().minimap.hide = true;  LDBIcon:Hide("MakersPath") end
function MakersPath_Minimap_Show() DB().minimap.hide = false; LDBIcon:Show("MakersPath") end