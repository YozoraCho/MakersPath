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
MakersPath.UI.RefreshAddon = RefreshAddon

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

-- =====================================================================
-- Tab strip
-- =====================================================================
local function CreateTabStrip(frame, panels, labels)
  local buttons = {}

  local function Select(index)
    for i, panel in ipairs(panels) do
      if i == index then panel:Show() else panel:Hide() end
    end
    for i, btn in ipairs(buttons) do
      if i == index then
        btn:Disable()
        btn:SetAlpha(1.0)
      else
        btn:Enable()
        btn:SetAlpha(0.7)
      end
    end
    frame.activeTab = index
  end

  local x = 12
  for i, label in ipairs(labels) do
    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetSize(96, 22)
    btn:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -30)
    btn:SetText(label)
    btn:SetScript("OnClick", function() Select(i) end)
    buttons[i] = btn
    x = x + 100
  end

  frame.SelectTab = Select
  Select(1)
  return buttons
end

-- =====================================================================
-- General panel
-- =====================================================================
local function BuildGeneralPanel(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -58)
  p:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 46)

  local subtitle = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -6)
  subtitle:SetWidth(420)
  subtitle:SetJustifyH("LEFT")
  subtitle:SetText(LT("OPT_GENERAL_SUBTITLE", "Configure GearFinder behavior and recommendation filters."))

  CreateSectionLabel(p, LT("OPT_SECTION_GEARFINDER", "GearFinder"), 16, -30)

  local y = -56
  local step = 30

  CreateCheckbox(
    p,
    LT("OPT_PREF_NATIVE_ARMOR", "Prefer native armor type"),
    16, y,
    function() return ConfigDB().PREF_NATIVE_ARMOR ~= false end,
    function(v) ConfigDB().PREF_NATIVE_ARMOR = (v == true) end,
    LT("OPT_PREF_NATIVE_ARMOR", "Prefer native armor type"),
    LT("OPT_PREF_NATIVE_ARMOR_TT", "When enabled, Maker's Path prefers your class's normal armor class when scores are close.")
  )
  y = y - step

  CreateCheckbox(
    p,
    LT("OPT_IGNORE_FILTERS", "Ignore external filters"),
    16, y,
    function() return ConfigDB().IGNORE_FILTERS == true end,
    function(v) ConfigDB().IGNORE_FILTERS = (v == true) end,
    LT("OPT_IGNORE_FILTERS", "Ignore external filters"),
    LT("OPT_IGNORE_FILTERS_TT", "Disables filter gating so GearFinder can show items even if external filters would normally reject them.")
  )
  y = y - step

  CreateCheckbox(
    p,
    LT("OPT_TRAINER_ONLY", "Trainer only recommendations"),
    16, y,
    function() return ConfigDB().TRAINER_ONLY == true end,
    function(v) ConfigDB().TRAINER_ONLY = (v == true) end,
    LT("OPT_TRAINER_ONLY", "Trainer only"),
    LT("OPT_TRAINER_ONLY_TT", "Only recommend recipes marked as trainer-sourced.")
  )
  y = y - step

  CreateCheckbox(
    p,
    LT("OPT_ONLY_STATS_WEAPONS", "Only score weapon stats mode"),
    16, y,
    function() return ConfigDB().ONLY_STATS_WEAPONS == true end,
    function(v) ConfigDB().ONLY_STATS_WEAPONS = (v == true) end,
    LT("OPT_ONLY_STATS_WEAPONS", "Only score weapon stats mode"),
    LT("OPT_ONLY_STATS_WEAPONS_TT", "Reduces non-stat weapon bias behavior. Useful for testing weapon comparisons.")
  )
  y = y - step

  CreateSectionLabel(p, LT("OPT_SECTION_DEBUG", "Debug"), 16, y - 2)
  y = y - 28

  CreateCheckbox(
    p,
    LT("OPT_DEBUG_GF", "Debug GearFinder"),
    16, y,
    function() return MakersPath.GetDebugGF and MakersPath.GetDebugGF() or false end,
    function(v) if MakersPath.SetDebugGF then MakersPath.SetDebugGF(v) end end,
    LT("OPT_DEBUG_GF", "Debug GearFinder"),
    LT("OPT_DEBUG_GF_TT", "Print GearFinder debug output to chat.")
  )
  y = y - step

  CreateCheckbox(
    p,
    LT("OPT_DEBUG_TIMING", "Debug timing"),
    16, y,
    function() return MakersPath.GetDebugTiming and MakersPath.GetDebugTiming() or false end,
    function(v) if MakersPath.SetDebugTiming then MakersPath.SetDebugTiming(v) end end,
    LT("OPT_DEBUG_TIMING", "Debug timing"),
    LT("OPT_DEBUG_TIMING_TT", "Print BuildSummary timing information.")
  )

  return p
end

-- =====================================================================
-- Frame
-- =====================================================================
function MakersPath.UI:CreateOptionsFrame()
  if self.OptionsFrame then
    return self.OptionsFrame
  end

  local f = CreateFrame("Frame", "MakersPathOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
  self.OptionsFrame = f

  f:SetSize(470, 540)
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
  title:SetText(LT("OPT_TITLE", "Maker's Path Options"))

  local generalPanel = BuildGeneralPanel(f)

  local weightsPanel
  if MakersPath.UI.BuildWeightsPanel then
    weightsPanel = MakersPath.UI:BuildWeightsPanel(f)
  else
    weightsPanel = CreateFrame("Frame", nil, f)
    weightsPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -58)
    weightsPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 46)
    local msg = weightsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    msg:SetPoint("CENTER")
    msg:SetText(LT("OPT_WEIGHTS_UNAVAILABLE", "Weight editor unavailable."))
  end
  f.WeightsPanel = weightsPanel

  CreateTabStrip(
    f,
    { generalPanel, weightsPanel },
    { LT("OPT_TAB_GENERAL", "General"), LT("OPT_TAB_WEIGHTS", "Weights") }
  )

  local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  resetBtn:SetSize(120, 24)
  resetBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 16)
  resetBtn:SetText(LT("OPT_RESET_POSITION", "Reset Position"))
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

function MakersPath.UI:ToggleOptions(tabIndex)
  local f = self.OptionsFrame or self:CreateOptionsFrame()
  if f:IsShown() and not tabIndex then
    f:Hide()
  else
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:Show()
    f:Raise()
    if tabIndex and f.SelectTab then f.SelectTab(tabIndex) end
  end
end

SLASH_MPOPTIONS1 = "/mpoptions"
SLASH_MPOPTIONS2 = "/mpsettings"
SlashCmdList["MPOPTIONS"] = function()
  if MakersPath and MakersPath.UI and MakersPath.UI.ToggleOptions then
    MakersPath.UI:ToggleOptions()
  end
end

SLASH_MPWEIGHTS1 = "/mpweights"
SlashCmdList["MPWEIGHTS"] = function()
  if MakersPath and MakersPath.UI and MakersPath.UI.ToggleOptions then
    MakersPath.UI:ToggleOptions(2)
  end
end
