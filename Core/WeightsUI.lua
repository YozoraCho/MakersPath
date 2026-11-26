local ADDON, MakersPath = ...
MakersPath = MakersPath or {}
MakersPath.UI = MakersPath.UI or {}

local L = LibStub("AceLocale-3.0"):GetLocale("MakersPath", true) or {}
local function LT(key, fallback)
  return (L and rawget(L, key)) or fallback or key
end

local T, W = MakersPath.Theme, MakersPath.Widgets
local C = T.C

local function RT()
  return MakersPath.WeightsRT
end

local function Say(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[Maker's Path]|r " .. tostring(msg))
  end
end

local ROW_HEIGHT    = 24
local HEADER_HEIGHT = 26
local LABEL_WIDTH   = 150
local BOX_WIDTH     = 52

local function Pretty(key)
  key = tostring(key or ""):gsub("_", " "):lower()
  return (key:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

local function RefreshAll()
  if MakersPath.UI.RefreshWeightsPanel then MakersPath.UI.RefreshWeightsPanel() end
  if MakersPath.UI.RefreshAddon then MakersPath.UI.RefreshAddon() end
end

-- =================== Dialogs ===================
local function ShowSaveDialog()
  W.Dialog({
    title = LT("WT_SAVE_AS", "Save As"),
    text = LT("WT_POPUP_SAVE", "Name for this weight preset:"),
    input = "",
    maxLetters = 40,
    accept = SAVE or "Save",
    cancel = CANCEL or "Cancel",
    onAccept = function(name)
      name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if name == "" then return end
      local ok = RT() and RT().SavePreset(name)
      if ok then
        Say(string.format(LT("WT_PRESET_SAVED", "Saved preset '%s'."), name))
        if MakersPath.UI.RefreshWeightsPanel then MakersPath.UI.RefreshWeightsPanel() end
      end
    end,
  })
end

local function ShowImportDialog()
  W.Dialog({
    title = LT("WT_IMPORT", "Import"),
    text = LT("WT_POPUP_IMPORT", "Paste a Maker's Path weight string:"),
    input = "",
    accept = ACCEPT or "Accept",
    cancel = CANCEL or "Cancel",
    onAccept = function(str)
      local ok, err, foundClass, warning, warningDetail = RT() and RT().ImportString(str or "")
      if ok then
        Say(LT("WT_IMPORT_OK", "Weights imported."))
        if warning == "spec-mismatch" then
          Say(string.format(LT("WT_IMPORT_SPEC_MISMATCH",
            "Note: that string was built for %s. Applied to your active spec anyway."),
            tostring(warningDetail)))
        end
        RefreshAll()
      elseif err == "class-mismatch" then
        Say(string.format(LT("WT_IMPORT_CLASS_MISMATCH",
          "That string is for %s, not your class."), tostring(foundClass)))
      elseif err == "bad-checksum" then
        Say(LT("WT_IMPORT_BAD_CHECKSUM", "That weight string looks corrupted."))
      else
        Say(LT("WT_IMPORT_BAD", "Could not read that weight string."))
      end
    end,
  })
end

local function ShowExportDialog(str)
  W.Dialog({
    title = LT("WT_EXPORT", "Export"),
    copy = str,
    hint = LT("DIALOG_COPY_HINT", "Press Ctrl+C to copy"),
    copiedHint = LT("DIALOG_COPIED", "Copied"),
  })
end

local function ShowDeleteDialog(name)
  W.Dialog({
    title = LT("WT_DELETE", "Delete"),
    text = string.format(LT("WT_POPUP_DELETE", "Delete weight preset '%s'?"), name),
    accept = DELETE or "Delete",
    cancel = CANCEL or "Cancel",
    onAccept = function()
      if RT() then
        RT().DeletePreset(name)
        Say(string.format(LT("WT_PRESET_DELETED", "Deleted preset '%s'."), name))
        if MakersPath.UI.RefreshWeightsPanel then MakersPath.UI.RefreshWeightsPanel() end
      end
    end,
  })
end

-- =================== Stat Rows ===================
local function CreateStatRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_HEIGHT)
  row:EnableMouse(true)

  row.hl = W.Fill(row, "hover", "BACKGROUND")
  row.hl:SetAllPoints()
  row.hl:Hide()

  row.label = W.Text(row, "body", "secondary")
  row.label:SetPoint("LEFT", 6, 0)
  row.label:SetWidth(LABEL_WIDTH)

  row.marker = W.Text(row, "strong", "brass")
  row.marker:SetPoint("RIGHT", -6, 0)
  row.marker:SetWidth(8)

  row.box = W.Input(row, BOX_WIDTH, { height = 20, justify = "CENTER", maxLetters = 5, font = "num" })
  row.box:SetPoint("RIGHT", row.marker, "LEFT", -4, 0)

  row.slider = W.Slider(row, 140)
  row.slider:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
  row.slider:SetPoint("RIGHT", row.box, "LEFT", -14, 0)

  row.suppress = false

  local function Commit(value)
    if row.suppress or not row.statKey then return end
    local rt = RT()
    if not rt then return end
    rt.SetWeight(row.statKey, value)
    row:Refresh()
    if MakersPath.UI.RefreshAddon then MakersPath.UI.RefreshAddon() end
  end

  row.slider:SetScript("OnValueChanged", function(_, v)
    if row.suppress then return end
    Commit(v)
  end)

  row.box:SetScript("OnEnterPressed", function(self)
    Commit(tonumber(self:GetText()) or 0)
    self:ClearFocus()
  end)
  row.box:SetScript("OnEscapePressed", function(self)
    row:Refresh()
    self:ClearFocus()
  end)
  local focusLost = row.box:GetScript("OnEditFocusLost")
  row.box:SetScript("OnEditFocusLost", function(self)
    focusLost(self)
    row:Refresh()
  end)

  function row:Refresh()
    local rt = RT()
    if not rt or not self.statKey then return end
    local v = rt.GetWeight(self.statKey)
    local changed = rt.IsOverridden(self.statKey)
    self.suppress = true
    self.slider:SetValue(v)
    self.box:SetText(string.format("%.2f", v))
    self.suppress = false
    self.marker:SetText(changed and "*" or "")
    W.TextColor(self.label, changed and "bone" or "secondary")
  end

  function row:SetStat(statKey)
    local rt = RT()
    self.statKey = statKey
    self.label:SetText(Pretty(statKey))
    if rt then
      self.slider:SetMinMaxValues(rt.MIN_WEIGHT, rt.MAX_WEIGHT)
      self.slider:SetValueStep(0.05)
    end
    self:Refresh()
  end

  local function ShowTip(owner)
    if not row.statKey then return end
    row.hl:Show()
    W.TipBegin(owner, "ANCHOR_RIGHT", 240)
    W.TipLine(Pretty(row.statKey), "tipGold")
    local rt = RT()
    local defaults = rt and rt.GetDefaultsTable()
    local d = defaults and defaults[row.statKey]
    W.TipLine(string.format(LT("WT_TT_DEFAULT", "Default: %.2f"), tonumber(d) or 0), "bone")
    W.TipLine(LT("WT_TT_HINT", "Higher values make this stat count for more when ranking craftable upgrades."), "secondary")
    GameTooltip:Show()
  end
  local function HideTip()
    row.hl:Hide()
    W.TipHide()
  end

  row:SetScript("OnEnter", ShowTip)
  row:SetScript("OnLeave", HideTip)
  local sEnter, sLeave = row.slider:GetScript("OnEnter"), row.slider:GetScript("OnLeave")
  row.slider:SetScript("OnEnter", function(self) sEnter(self); ShowTip(self) end)
  row.slider:SetScript("OnLeave", function(self) sLeave(self); HideTip() end)

  return row
end

-- =================== Panel ===================
function MakersPath.UI:BuildWeightsPanel(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -4)
  p:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 4)
  p:Hide()

  local heading = W.Heading(p, LT("OPT_TAB_WEIGHTS", "Stat weights"))
  heading:SetPoint("TOPLEFT", 16, -10)
  heading:SetPoint("RIGHT", -16, 0)
  p.heading = heading

  local hint = W.Text(p, "small", "muted")
  hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  hint:SetPoint("RIGHT", -16, 0)
  hint:SetWordWrap(true)
  hint:SetText(LT("WT_HINT", "Edits apply to this character's current spec. * marks a changed value."))

  local BUILTIN_PREFIX = LT("WT_BUILTIN_PREFIX", "Default: ")
  local PICK_TEXT = LT("WT_PRESET_PICK", "Choose a preset")

  local dd
  local function Display(name)
    local builtin = name:match("^" .. BUILTIN_PREFIX:gsub("%p", "%%%1") .. "(.+)$")
    return builtin and (BUILTIN_PREFIX .. Pretty(builtin)) or name
  end

  local function HandleSelection(name)
    local rt = RT()
    if not rt then return end
    dd.selected = name
    dd:SetText(Display(name))
    local builtin = name:match("^" .. BUILTIN_PREFIX:gsub("%p", "%%%1") .. "(.+)$")
    if builtin then
      local class = rt.CurrentClass()
      local classTbl = (MakersPath.Weights or {})[class]
      local tbl = classTbl and classTbl[builtin]
      if tbl then
        rt.ApplyWeightTable(tbl)
        Say(string.format(LT("WT_BUILTIN_LOADED", "Loaded built-in weights: %s."), Pretty(builtin)))
      end
    else
      rt.LoadPreset(name)
      Say(string.format(LT("WT_PRESET_LOADED", "Loaded preset '%s'."), name))
    end
    for _, r in ipairs(p.rows or {}) do
      if r:IsShown() then r:Refresh() end
    end
    if MakersPath.UI.RefreshAddon then MakersPath.UI.RefreshAddon() end
  end

  local function PresetItems()
    local rt = RT()
    if not rt then return {}, {} end
    local builtins, saved = {}, {}
    local class = rt.CurrentClass()
    local classTbl = (MakersPath.Weights or {})[class]
    if classTbl then
      local specNames = {}
      for k, v in pairs(classTbl) do
        if type(v) == "table" then specNames[#specNames + 1] = k end
      end
      table.sort(specNames)
      for _, s in ipairs(specNames) do builtins[#builtins + 1] = BUILTIN_PREFIX .. s end
    end
    for _, name in ipairs(rt.ListPresets(class)) do saved[#saved + 1] = name end
    return builtins, saved
  end

  local function InitPresets(_, level)
    if level ~= 1 then return end
    local LibDD = MakersPath.LibDD
    if not LibDD then return end
    local builtins, saved = PresetItems()
    local function add(name)
      local info = LibDD:UIDropDownMenu_CreateInfo()
      info.text = Display(name)
      info.arg1 = name
      info.checked = (dd.selected == name)
      info.func = function(_, value) HandleSelection(value) end
      LibDD:UIDropDownMenu_AddButton(info, level)
    end
    for _, name in ipairs(builtins) do add(name) end
    if #saved > 0 and #builtins > 0 then
      local sep = LibDD:UIDropDownMenu_CreateInfo()
      sep.text = ""
      sep.isTitle = true
      sep.notCheckable = true
      LibDD:UIDropDownMenu_AddButton(sep, level)
    end
    for _, name in ipairs(saved) do add(name) end
  end

  dd = W.Dropdown(p, "MakersPathWeightsPresetDropdown", InitPresets, { width = 210 })
  dd:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)
  dd:SetText(PICK_TEXT)
  p.dropdown = dd

  local saveBtn = W.Button(p, LT("WT_SAVE_AS", "Save As"), ShowSaveDialog, { minWidth = 70 })
  saveBtn:SetPoint("LEFT", dd, "RIGHT", 6, 0)

  local delBtn = W.Button(p, LT("WT_DELETE", "Delete"), function()
    local sel = dd.selected
    if not sel or sel:find(BUILTIN_PREFIX, 1, true) == 1 then
      Say(LT("WT_DELETE_PICK", "Select a saved preset first."))
      return
    end
    ShowDeleteDialog(sel)
  end, { minWidth = 70 })
  delBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)

  local importBtn = W.Button(p, LT("WT_IMPORT", "Import"), ShowImportDialog, { minWidth = 70 })
  importBtn:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -6)

  local exportBtn = W.Button(p, LT("WT_EXPORT", "Export"), function()
    local rt = RT()
    local str = rt and rt.ExportString()
    if str then ShowExportDialog(str) end
  end, { minWidth = 70 })
  exportBtn:SetPoint("LEFT", importBtn, "RIGHT", 6, 0)

  local resetBtn = W.Button(p, LT("WT_RESET_DEFAULTS", "Reset to Default"), function()
    local rt = RT()
    if not rt then return end
    rt.ResetToDefaults()
    Say(LT("WT_RESET_DONE", "Weights reset to defaults."))
    RefreshAll()
  end)
  resetBtn:SetPoint("TOP", importBtn, "TOP")
  resetBtn:SetPoint("RIGHT", p, "RIGHT", -16, 0)

  local box = W.Inset(p)
  box:SetPoint("TOPLEFT", importBtn, "BOTTOMLEFT", 0, -12)
  box:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 8)

  local scroll = CreateFrame("ScrollFrame", nil, box)
  scroll:SetPoint("TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", -16, 4)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(10, 10)
  scroll:SetScrollChild(content)
  p.content = content

  local bar = W.ScrollBar(scroll)
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 3, 0)
  bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 3, 0)
  bar.wheelStep = ROW_HEIGHT * 3
  scroll:SetScript("OnMouseWheel", function(_, delta) bar:Scroll(delta * ROW_HEIGHT * 3) end)
  scroll:SetScript("OnSizeChanged", function(self, w)
    content:SetWidth(w or self:GetWidth() or 10)
    bar:Update()
  end)

  local rows    = {}
  local headers = {}
  p.rows = rows

  local function LayoutRows()
    local rt = RT()
    if not rt then return end

    for _, r in ipairs(rows) do r:Hide() end
    for _, h in ipairs(headers) do h:Hide() end

    local y = 4
    local rowIdx, hdrIdx = 0, 0

    for _, grp in ipairs(rt.GROUPS) do
      hdrIdx = hdrIdx + 1
      local h = headers[hdrIdx]
      if not h then
        h = W.Heading(content, "")
        headers[hdrIdx] = h
      end
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -y)
      h:SetPoint("RIGHT", content, "RIGHT", -6, 0)
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
        r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        r:SetStat(statKey)
        r:Show()
        y = y + ROW_HEIGHT
      end

      y = y + 8
    end

    content:SetHeight(math.max(y, 10))
    bar:Update()
  end

  local unavailable = W.Text(box, "body", "muted")
  unavailable:SetPoint("CENTER")
  unavailable:SetText(LT("WT_NO_CLASS_WEIGHTS", "No stat weights are defined for your class yet."))
  unavailable:Hide()

  local function UpdateHeading()
    local rt = RT()
    if not rt then return end
    local _, class, specKey = rt.GetEditableWeights()
    local className = class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or Pretty(class or "?")
    local spec = specKey and Pretty(specKey) or LT("WT_SPEC_BASE", "Base")
    heading:SetText(LT("OPT_TAB_WEIGHTS", "Stat weights"), T.Wrap(T.ClassColor(class), className) .. "  ·  " .. spec)
  end

  local function Refresh()
    local rt = RT()
    if not rt then return end

    local full = rt.GetEditableWeights()
    UpdateHeading()

    if not full or not next(full) then
      scroll:Hide()
      bar:Hide()
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
    bar:Update()

    dd:SetText(PICK_TEXT)
    dd.selected = nil
  end

  p:SetScript("OnShow", function()
    content:SetWidth(scroll:GetWidth() or 10)
    LayoutRows()
    Refresh()
  end)

  MakersPath.UI.RefreshWeightsPanel = function()
    if p:IsShown() then
      for _, r in ipairs(rows) do
        if r:IsShown() then r:Refresh() end
      end
      UpdateHeading()
    end
  end

  p.Refresh = Refresh
  return p
end
