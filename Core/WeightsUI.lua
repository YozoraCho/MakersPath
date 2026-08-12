local ADDON, MakersPath = ...
MakersPath = MakersPath or {}
MakersPath.UI = MakersPath.UI or {}

local L = LibStub("AceLocale-3.0"):GetLocale("MakersPath", true) or {}
local function LT(key, fallback)
  return (L and L[key]) or fallback or key
end

local function RT()
  return MakersPath.WeightsRT
end

local function Say(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[Maker's Path]|r " .. tostring(msg))
  end
end

local ROW_HEIGHT    = 24
local HEADER_HEIGHT = 20
local PANEL_WIDTH   = 416

-- =====================================================================
-- Minimal dropdown
-- =====================================================================
local function CreateSimpleDropdown(parent, width, onSelect)
  local dd = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  dd:SetSize(width, 22)
  dd:SetText(LT("WT_PRESET_NONE", "<select preset>"))

  local list = CreateFrame("Frame", nil, dd)
  local bg = list:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(true)
  bg:SetColorTexture(0.05, 0.05, 0.07, 0.95)
  local border = list:CreateTexture(nil, "BORDER")
  border:SetPoint("TOPLEFT", list, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 1, -1)
  border:SetColorTexture(0.4, 0.4, 0.45, 0.9)
  bg:SetDrawLayer("BACKGROUND", 1)
  list:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
  list:SetWidth(width)
  list:SetFrameStrata("FULLSCREEN_DIALOG")
  list:Hide()

  dd.rows = {}
  dd.selected = nil

  local function Close()
    list:Hide()
  end

  function dd:SetItems(items)
    for _, row in ipairs(self.rows) do row:Hide() end

    local n = 0
    for i, label in ipairs(items) do
      local row = self.rows[i]
      if not row then
        row = CreateFrame("Button", nil, list)
        row:SetHeight(18)
        row:SetPoint("LEFT", list, "LEFT", 4, 0)
        row:SetPoint("RIGHT", list, "RIGHT", -4, 0)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", row, "LEFT", 4, 0)
        fs:SetJustifyH("LEFT")
        row.text = fs
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(true)
        hl:SetColorTexture(0.3, 0.5, 0.8, 0.35)
        self.rows[i] = row
      end
      row:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -4 - (i - 1) * 18)
      row.text:SetText(label)
      row.value = label
      row:SetScript("OnClick", function(self2)
        dd.selected = self2.value
        dd:SetText(self2.value)
        Close()
        if onSelect then onSelect(self2.value) end
      end)
      row:Show()
      n = i
    end

    list:SetHeight(math.max(20, n * 18 + 8))
    self.count = n
  end

  dd:SetScript("OnClick", function(self)
    if list:IsShown() then
      Close()
    else
      if self.Populate then self:Populate() end
      if (self.count or 0) > 0 then list:Show() end
    end
  end)

  dd:SetScript("OnHide", Close)
  dd.CloseList = Close
  return dd
end

-- =====================================================================
-- Text-entry popups (save-as / import / export)
-- =====================================================================
StaticPopupDialogs["MAKERSPATH_SAVE_PRESET"] = {
  text = LT("WT_POPUP_SAVE", "Name for this weight preset:"),
  button1 = SAVE or "Save",
  button2 = CANCEL or "Cancel",
  hasEditBox = true,
  maxLetters = 40,
  OnAccept = function(self)
    local box = self.editBox or (self.GetEditBox and self:GetEditBox())
    local name = box and box:GetText() or ""
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return end
    local ok = RT() and RT().SavePreset(name)
    if ok then
      Say(string.format(LT("WT_PRESET_SAVED", "Saved preset '%s'."), name))
      if MakersPath.UI.RefreshWeightsPanel then MakersPath.UI.RefreshWeightsPanel() end
    end
  end,
  EditBoxOnEnterPressed = function(self)
    local parent = self:GetParent()
    if parent and parent.button1 and parent.button1:IsEnabled() then
      StaticPopup_OnClick(parent, 1)
    end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["MAKERSPATH_IMPORT_WEIGHTS"] = {
  text = LT("WT_POPUP_IMPORT", "Paste a Maker's Path weight string:"),
  button1 = ACCEPT or "Accept",
  button2 = CANCEL or "Cancel",
  hasEditBox = true,
  maxLetters = 0,
  editBoxWidth = 300,
  OnAccept = function(self)
    local box = self.editBox or (self.GetEditBox and self:GetEditBox())
    local str = box and box:GetText() or ""
    local ok, err, foundClass, warning, warningDetail = RT() and RT().ImportString(str)
    if ok then
      Say(LT("WT_IMPORT_OK", "Weights imported."))
      if warning == "spec-mismatch" then
        Say(string.format(LT("WT_IMPORT_SPEC_MISMATCH",
          "Note: that string was built for %s. Applied to your active spec anyway."),
          tostring(warningDetail)))
      end
      if MakersPath.UI.RefreshWeightsPanel then MakersPath.UI.RefreshWeightsPanel() end
      if MakersPath.UI.RefreshAddon then MakersPath.UI.RefreshAddon() end
    elseif err == "class-mismatch" then
      Say(string.format(LT("WT_IMPORT_CLASS_MISMATCH",
        "That string is for %s, not your class."), tostring(foundClass)))
    elseif err == "bad-checksum" then
      Say(LT("WT_IMPORT_BAD_CHECKSUM", "That weight string looks corrupted."))
    else
      Say(LT("WT_IMPORT_BAD", "Could not read that weight string."))
    end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["MAKERSPATH_EXPORT_WEIGHTS"] = {
  text = LT("WT_POPUP_EXPORT", "Copy this string (Ctrl+C):"),
  button1 = CLOSE or "Close",
  hasEditBox = true,
  maxLetters = 0,
  editBoxWidth = 300,
  OnShow = function(self, data)
    local box = self.editBox or (self.GetEditBox and self:GetEditBox())
    if box then
      box:SetText(data or "")
      box:HighlightText()
      box:SetFocus()
    end
  end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["MAKERSPATH_DELETE_PRESET"] = {
  text = LT("WT_POPUP_DELETE", "Delete weight preset '%s'?"),
  button1 = DELETE or "Delete",
  button2 = CANCEL or "Cancel",
  OnAccept = function(self, data)
    if data and RT() then
      RT().DeletePreset(data)
      Say(string.format(LT("WT_PRESET_DELETED", "Deleted preset '%s'."), data))
      if MakersPath.UI.RefreshWeightsPanel then MakersPath.UI.RefreshWeightsPanel() end
    end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

-- =====================================================================
-- Stat rows
-- =====================================================================
local function CreateStatRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(PANEL_WIDTH - 30, ROW_HEIGHT)

  local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("LEFT", row, "LEFT", 4, 0)
  label:SetWidth(150)
  label:SetJustifyH("LEFT")
  row.label = label

  local slider = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
  slider:SetPoint("LEFT", row, "LEFT", 158, 0)
  slider:SetWidth(140)
  slider:SetHeight(16)
  slider:SetOrientation("HORIZONTAL")
  slider:SetObeyStepOnDrag(true)
  if slider.Low then slider.Low:SetText("") end
  if slider.High then slider.High:SetText("") end
  if slider.Text then slider.Text:SetText("") end
  row.slider = slider

  local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
  box:SetSize(48, 18)
  box:SetPoint("LEFT", slider, "RIGHT", 14, 0)
  box:SetAutoFocus(false)
  box:SetNumeric(false)
  box:SetMaxLetters(5)
  box:SetJustifyH("CENTER")
  row.box = box

  local marker = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  marker:SetPoint("LEFT", box, "RIGHT", 6, 0)
  marker:SetText("")
  marker:SetTextColor(1.0, 0.82, 0.0)
  row.marker = marker

  row.suppress = false

  local function Commit(value)
    if row.suppress or not row.statKey then return end
    local rt = RT()
    if not rt then return end
    rt.SetWeight(row.statKey, value)
    row:Refresh()
    if MakersPath.UI.RefreshAddon then MakersPath.UI.RefreshAddon() end
  end

  slider:SetScript("OnValueChanged", function(self, v)
    if row.suppress then return end
    Commit(v)
  end)

  box:SetScript("OnEnterPressed", function(self)
    Commit(tonumber(self:GetText()) or 0)
    self:ClearFocus()
  end)
  box:SetScript("OnEscapePressed", function(self)
    row:Refresh()
    self:ClearFocus()
  end)
  box:SetScript("OnEditFocusLost", function(self)
    row:Refresh()
  end)

  function row:Refresh()
    local rt = RT()
    if not rt or not self.statKey then return end
    local v = rt.GetWeight(self.statKey)
    self.suppress = true
    self.slider:SetValue(v)
    self.box:SetText(string.format("%.2f", v))
    self.suppress = false
    self.marker:SetText(rt.IsOverridden(self.statKey) and "*" or "")
  end

  function row:SetStat(statKey)
    local rt = RT()
    self.statKey = statKey
    self.label:SetText(statKey:gsub("_", " "))
    if rt then
      self.slider:SetMinMaxValues(rt.MIN_WEIGHT, rt.MAX_WEIGHT)
      self.slider:SetValueStep(0.05)
    end
    self:Refresh()
  end

  slider:SetScript("OnEnter", function(self)
    if not row.statKey then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(row.statKey:gsub("_", " "), 1, 0.82, 0)
    local rt = RT()
    local defaults = rt and rt.GetDefaultsTable()
    local d = defaults and defaults[row.statKey]
    GameTooltip:AddLine(string.format(LT("WT_TT_DEFAULT", "Default: %.2f"), tonumber(d) or 0), 1, 1, 1)
    GameTooltip:AddLine(LT("WT_TT_HINT", "Higher values make this stat count for more when ranking craftable upgrades."), 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  slider:SetScript("OnLeave", function() GameTooltip:Hide() end)

  return row
end

-- =====================================================================
-- Panel
-- =====================================================================
function MakersPath.UI:BuildWeightsPanel(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -58)
  p:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 46)
  p:Hide()

  local header = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -6)
  header:SetTextColor(1.0, 0.82, 0.0)
  p.header = header

  local hint = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
  hint:SetWidth(PANEL_WIDTH)
  hint:SetJustifyH("LEFT")
  hint:SetText(LT("WT_HINT", "Edits apply to this character's current spec. * marks a changed value."))

  local presetLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  presetLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
  presetLabel:SetText(LT("WT_PRESET_LABEL", "Preset:"))

  local dd = CreateSimpleDropdown(p, 168, function(name)
    local rt = RT()
    if not rt then return end
    if rt.LoadPreset(name) then
      Say(string.format(LT("WT_PRESET_LOADED", "Loaded preset '%s'."), name))
      if MakersPath.UI.RefreshWeightsPanel then MakersPath.UI.RefreshWeightsPanel() end
      if MakersPath.UI.RefreshAddon then MakersPath.UI.RefreshAddon() end
    end
  end)
  dd:SetPoint("LEFT", presetLabel, "RIGHT", 8, 0)
  p.dropdown = dd

  local BUILTIN_PREFIX = LT("WT_BUILTIN_PREFIX", "Default: ")

  function dd:Populate()
    local rt = RT()
    if not rt then self:SetItems({}) return end
    local items = {}
    local class = rt.CurrentClass()
    local classTbl = (MakersPath.Weights or {})[class]
    if classTbl then
      local specNames = {}
      for k, v in pairs(classTbl) do
        if type(v) == "table" then specNames[#specNames + 1] = k end
      end
      table.sort(specNames)
      for _, s in ipairs(specNames) do
        items[#items + 1] = BUILTIN_PREFIX .. s
      end
    end

    for _, name in ipairs(rt.ListPresets(class)) do
      items[#items + 1] = name
    end
    self:SetItems(items)
  end

  dd.HandleSelection = function(name)
    local rt = RT()
    if not rt then return end
    local builtin = name:match("^" .. BUILTIN_PREFIX:gsub("%p", "%%%1") .. "(.+)$")
    if builtin then
      local class = rt.CurrentClass()
      local classTbl = (MakersPath.Weights or {})[class]
      local tbl = classTbl and classTbl[builtin]
      if tbl then
        rt.ApplyWeightTable(tbl)
        Say(string.format(LT("WT_BUILTIN_LOADED", "Loaded built-in weights: %s."), builtin))
      end
    else
      rt.LoadPreset(name)
      Say(string.format(LT("WT_PRESET_LOADED", "Loaded preset '%s'."), name))
    end
    if MakersPath.UI.RefreshWeightsPanel then MakersPath.UI.RefreshWeightsPanel() end
    if MakersPath.UI.RefreshAddon then MakersPath.UI.RefreshAddon() end
  end

  local origSetItems = dd.SetItems
  dd.SetItems = function(self, items)
    origSetItems(self, items)
    for i = 1, (self.count or 0) do
      local row = self.rows[i]
      row:SetScript("OnClick", function(rowSelf)
        self.selected = rowSelf.value
        self:SetText(rowSelf.value)
        self:CloseList()
        dd.HandleSelection(rowSelf.value)
      end)
    end
  end

  local function MakeButton(label, width, anchorTo, xOff, yOff, onClick)
    local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", xOff or 0, yOff or -6)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
  end

  local saveBtn = MakeButton(LT("WT_SAVE_AS", "Save As"), 80, presetLabel, 0, -10, function()
    StaticPopup_Show("MAKERSPATH_SAVE_PRESET")
  end)

  local delBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  delBtn:SetSize(80, 22)
  delBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)
  delBtn:SetText(LT("WT_DELETE", "Delete"))
  delBtn:SetScript("OnClick", function()
    local sel = dd.selected
    if not sel or sel:find(BUILTIN_PREFIX, 1, true) == 1 then
      Say(LT("WT_DELETE_PICK", "Select a saved preset first."))
      return
    end
    StaticPopup_Show("MAKERSPATH_DELETE_PRESET", sel, nil, sel)
  end)

  local importBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  importBtn:SetSize(80, 22)
  importBtn:SetPoint("LEFT", delBtn, "RIGHT", 6, 0)
  importBtn:SetText(LT("WT_IMPORT", "Import"))
  importBtn:SetScript("OnClick", function()
    StaticPopup_Show("MAKERSPATH_IMPORT_WEIGHTS")
  end)

  local exportBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  exportBtn:SetSize(80, 22)
  exportBtn:SetPoint("LEFT", importBtn, "RIGHT", 6, 0)
  exportBtn:SetText(LT("WT_EXPORT", "Export"))
  exportBtn:SetScript("OnClick", function()
    local rt = RT()
    local str = rt and rt.ExportString()
    if str then
      StaticPopup_Show("MAKERSPATH_EXPORT_WEIGHTS", nil, nil, str)
    end
  end)

  local resetBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  resetBtn:SetSize(120, 22)
  resetBtn:SetPoint("TOPLEFT", saveBtn, "BOTTOMLEFT", 0, -6)
  resetBtn:SetText(LT("WT_RESET_DEFAULTS", "Reset to Default"))
  resetBtn:SetScript("OnClick", function()
    local rt = RT()
    if not rt then return end
    rt.ResetToDefaults()
    Say(LT("WT_RESET_DONE", "Weights reset to defaults."))
    if MakersPath.UI.RefreshWeightsPanel then MakersPath.UI.RefreshWeightsPanel() end
    if MakersPath.UI.RefreshAddon then MakersPath.UI.RefreshAddon() end
  end)

  local scroll = CreateFrame("ScrollFrame", "MakersPathWeightsScroll", p, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -10)
  scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -34, 8)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(PANEL_WIDTH - 30, 10)
  scroll:SetScrollChild(content)
  p.content = content

  local rows    = {}
  local headers = {}

  local function LayoutRows()
    local rt = RT()
    if not rt then return end

    for _, r in ipairs(rows) do r:Hide() end
    for _, h in ipairs(headers) do h:Hide() end

    local y = 0
    local rowIdx, hdrIdx = 0, 0

    for _, grp in ipairs(rt.GROUPS) do
      hdrIdx = hdrIdx + 1
      local h = headers[hdrIdx]
      if not h then
        h = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetTextColor(1.0, 0.82, 0.0)
        h:SetJustifyH("LEFT")
        headers[hdrIdx] = h
      end
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
      h:SetText(grp.name)
      h:Show()
      y = y + HEADER_HEIGHT

      for _, statKey in ipairs(grp.keys) do
        rowIdx = rowIdx + 1
        local r = rows[rowIdx]
        if not r then
          r = CreateStatRow(content)
          rows[rowIdx] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        r:SetStat(statKey)
        r:Show()
        y = y + ROW_HEIGHT
      end

      y = y + 6
    end

    content:SetHeight(math.max(y, 10))
  end

  local unavailable = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  unavailable:SetPoint("CENTER", scroll, "CENTER", 0, 0)
  unavailable:SetWidth(PANEL_WIDTH - 40)
  unavailable:SetText(LT("WT_NO_CLASS_WEIGHTS", "No stat weights are defined for your class yet."))
  unavailable:Hide()

  local function Refresh()
    local rt = RT()
    if not rt then return end

    local full, class, specKey = rt.GetEditableWeights()
    header:SetText(string.format(
      LT("WT_HEADER_FMT", "Editing: %s - %s"),
      tostring(class or "?"),
      tostring(specKey or "BASE")
    ))

    if not full or not next(full) then
      scroll:Hide()
      unavailable:Show()
      return
    end
    unavailable:Hide()
    scroll:Show()

    if #rows == 0 then
      LayoutRows()
    else
      for _, r in ipairs(rows) do
        if r:IsShown() then r:Refresh() end
      end
    end

    dd:SetText(LT("WT_PRESET_NONE", "<select preset>"))
    dd.selected = nil
  end

  p:SetScript("OnShow", function()
    LayoutRows()
    Refresh()
  end)

  MakersPath.UI.RefreshWeightsPanel = function()
    if p:IsShown() then
      for _, r in ipairs(rows) do
        if r:IsShown() then r:Refresh() end
      end
      local rt = RT()
      if rt then
        local _, class, specKey = rt.GetEditableWeights()
        header:SetText(string.format(
          LT("WT_HEADER_FMT", "Editing: %s - %s"),
          tostring(class or "?"),
          tostring(specKey or "BASE")
        ))
      end
    end
  end

  p.Refresh = Refresh
  return p
end
