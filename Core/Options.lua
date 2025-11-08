local ADDON, MakersPath = ...
MakersPath = MakersPath or {}

local L = LibStub("AceLocale-3.0"):GetLocale("MakersPath")

-- ==== Build a simple canvas panel ====
local options = CreateFrame("Frame", "MakersPathOptionsPanel", UIParent)
options.name = L["ADDON_NAME"]

-- Title
options.title = options:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
options.title:SetPoint("TOPLEFT", 16, -16)
options.title:SetText(L["ADDON_NAME"])

-- Description
options.desc = options:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
options.desc:SetPoint("TOPLEFT", options.title, "BOTTOMLEFT", 0, -8)
options.desc:SetWidth(440)
options.desc:SetJustifyH("LEFT")
options.desc:SetText(L["OPTIONS_DESC"] or "Configure Maker's Path.")

-- Example: Hide minimap icon
local hideBtn = CreateFrame("CheckButton", "MakersPathOptHideMM", options, "InterfaceOptionsCheckButtonTemplate")
hideBtn:SetPoint("TOPLEFT", options.desc, "BOTTOMLEFT", 0, -12)
_G[hideBtn:GetName().."Text"]:SetText(L["OPT_HIDE_MINIMAP"] or "Hide Minimap Icon")
hideBtn:SetScript("OnClick", function(self)
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.minimap = MakersPathDB.minimap or {}
  MakersPathDB.minimap.hide = self:GetChecked() or false
  if MakersPath_Minimap_Hide and MakersPath_Minimap_Show then
    if MakersPathDB.minimap.hide then MakersPath_Minimap_Hide() else MakersPath_Minimap_Show() end
  end
end)

options.refresh = function()
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.minimap = MakersPathDB.minimap or {}
  if hideBtn then hideBtn:SetChecked(MakersPathDB.minimap.hide or false) end
end

-- ===== Registration =====
local function RegisterOptionsCategory()
  if type(InterfaceOptions_AddCategory) == "function" then
    InterfaceOptions_AddCategory(options)
  elseif Settings and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(options, L["ADDON_NAME"])
    category.ID = "MakersPath"
    Settings.RegisterAddOnCategory(category)
  else
  end
end

-- Defer to ADDON_LOADED to avoid timing issues
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, ev, name)
  if ev == "ADDON_LOADED" and name == ADDON then
    RegisterOptionsCategory()
  end
end)
