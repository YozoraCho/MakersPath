local ADDON, ns = ...

ns.UI = ns.UI or {}
ns.UI.Minimap = ns.UI.Minimap or {}
local M = ns.UI.Minimap
local L = ns.L

local LDB = LibStub("LibDataBroker-1.1", true)
local Icon = LibStub("LibDBIcon-1.0", true)
if not LDB or not Icon then return end

local obj = LDB:NewDataObject("MakersPath", {
  type = "launcher",
  icon = "Interface\\AddOns\\MakersPath\\Art\\makerspathmm",
  label = L["MINIMAP_LABEL"],

  OnClick = function(_, button)
    if button == "LeftButton" then
      if ns.UI and ns.UI.Toggle then ns.UI:Toggle() end
    elseif button == "RightButton" then
      print(L["MINIMAP_RIGHT_CLICK_TODO"])
    end
  end,

  OnTooltipShow = function(tt)
    tt:AddLine(L["MINIMAP_TOOLTIP_TITLE"])
    tt:AddLine(L["MINIMAP_TOOLTIP_LEFT"])
    tt:AddLine(L["MINIMAP_TOOLTIP_RIGHT"])
  end,
})

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  if not ns.db then return end
  Icon:Register("MakersPath", obj, ns.db.minimap)
  if ns.db.minimap.hide then Icon:Hide("MakersPath") else Icon:Show("MakersPath") end
end)

function M:Hide()
  if not ns.db then return end
  ns.db.minimap.hide = true
  Icon:Hide("MakersPath")
end

function M:Show()
  if not ns.db then return end
  ns.db.minimap.hide = false
  Icon:Show("MakersPath")
end