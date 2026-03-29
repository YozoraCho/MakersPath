local ADDON, MakersPath = ...
MakersPath = MakersPath or {}
MakersPath.UI = MakersPath.UI or {}
MakersPath.Config = MakersPath.Config or {}

local L = LibStub("AceLocale-3.0"):GetLocale("MakersPath", true) or {}
local function LT(key, fallback)
  return (L and L[key]) or fallback or key
end

local function ConfigDB()
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.config = MakersPathDB.config or {}
  return MakersPathDB.config
end

local function RefreshAddon()
  if MakersPath and MakersPath.GearFinder and MakersPath.GearFinder.MarkDirty then
    MakersPath.GearFinder:MarkDirty()
  end
  if MakersPath and MakersPath.GearFinderScan then
    MakersPath.GearFinderScan()
  end
  if MakersPath and MakersPath.RequestUIRefresh then
    MakersPath.RequestUIRefresh()
  end
end

local function CreateSectionLabel(parent, text, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetText(text)
  fs:SetTextColor(1.0, 0.82, 0.0)
  return fs
end

local function CreateCheckbox(parent, label, x, y, getter, setter, tooltipTitle, tooltipText)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

  local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
  text:SetText(label)

  cb.text = text
  cb.getter = getter
  cb.setter = setter

  cb:SetScript("OnShow", function(self)
    self:SetChecked(self.getter() and true or false)
  end)

  cb:SetScript("OnClick", function(self)
    self.setter(self:GetChecked() and true or false)
    RefreshAddon()
  end)

  if tooltipTitle or tooltipText then
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if tooltipTitle then
        GameTooltip:AddLine(tooltipTitle, 1, 0.82, 0)
      end
      if tooltipText then
        GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
      end
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end

  return cb
end

function MakersPath.UI:CreateOptionsFrame()
  if self.OptionsFrame then
    return self.OptionsFrame
  end

  local f = CreateFrame("Frame", "MakersPathOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
  self.OptionsFrame = f

  f:SetSize(420, 400)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:Hide()
  table.insert(UISpecialFrames, "MakersPathOptionsFrame")

  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("CENTER", f.TitleBg, "CENTER", 0, 0)
  title:SetText("Maker's Path Options")

  local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -34)
  subtitle:SetWidth(388)
  subtitle:SetJustifyH("LEFT")
  subtitle:SetText("Configure GearFinder behavior and recommendation filters.")

  CreateSectionLabel(f, "GearFinder", 16, -62)

  local y = -88
  local step = 30

  CreateCheckbox(
    f,
    "Prefer native armor type",
    16, y,
    function() return ConfigDB().PREF_NATIVE_ARMOR ~= false end,
    function(v) ConfigDB().PREF_NATIVE_ARMOR = (v == true) end,
    "Prefer native armor type",
    "When enabled, Maker's Path prefers your class's normal armor class when scores are close."
  )
  y = y - step

  CreateCheckbox(
    f,
    "Ignore external filters",
    16, y,
    function() return ConfigDB().IGNORE_FILTERS == true end,
    function(v) ConfigDB().IGNORE_FILTERS = (v == true) end,
    "Ignore external filters",
    "Disables filter gating so GearFinder can show items even if external filters would normally reject them."
  )
  y = y - step

  CreateCheckbox(
    f,
    "Trainer only recommendations",
    16, y,
    function() return ConfigDB().TRAINER_ONLY == true end,
    function(v) ConfigDB().TRAINER_ONLY = (v == true) end,
    "Trainer only",
    "Only recommend recipes marked as trainer-sourced."
  )
  y = y - step

  CreateCheckbox(
    f,
    "Only score weapon stats mode",
    16, y,
    function() return ConfigDB().ONLY_STATS_WEAPONS == true end,
    function(v) ConfigDB().ONLY_STATS_WEAPONS = (v == true) end,
    "Only score weapon stats mode",
    "Reduces non-stat weapon bias behavior. Useful for testing weapon comparisons."
  )
  y = y - step

  CreateSectionLabel(f, "Debug", 16, y - 2)
  y = y - 28

  CreateCheckbox(
    f,
    "Debug GearFinder",
    16, y,
    function() return ConfigDB().DEBUG_GF == true end,
    function(v) ConfigDB().DEBUG_GF = (v == true) end,
    "Debug GearFinder",
    "Print GearFinder debug output to chat."
  )
  y = y - step

  CreateCheckbox(
    f,
    "Debug timing",
    16, y,
    function() return ConfigDB().DEBUG_TIMING == true end,
    function(v) ConfigDB().DEBUG_TIMING = (v == true) end,
    "Debug timing",
    "Print BuildSummary timing information."
  )

  local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  resetBtn:SetSize(120, 24)
  resetBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 16)
  resetBtn:SetText("Reset Position")
  resetBtn:SetScript("OnClick", function()
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end)

  local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  closeBtn:SetSize(100, 24)
  closeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
  closeBtn:SetText(CLOSE)
  closeBtn:SetScript("OnClick", function()
    f:Hide()
  end)

  return f
end

function MakersPath.UI:ToggleOptions()
  local f = self.OptionsFrame or self:CreateOptionsFrame()
  if f:IsShown() then
    f:Hide()
  else
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:Show()
    f:Raise()
  end
end

SLASH_MPOPTIONS1 = "/mpoptions"
SLASH_MPOPTIONS2 = "/mpsettings"
SlashCmdList["MPOPTIONS"] = function()
  if MakersPath and MakersPath.UI and MakersPath.UI.ToggleOptions then
    MakersPath.UI:ToggleOptions()
  end
end