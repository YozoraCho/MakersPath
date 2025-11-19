local ADDON_NAME, MakersPath = ...

MakersPath = MakersPath or {}
MakersPath.name = ADDON_NAME
MakersPath.version = "1.1.8"
_G.MakersPath = MakersPath

MakersPath.Config = MakersPath.Config or {}

-- ===================== Localization shim =====================
local L = LibStub("AceLocale-3.0"):GetLocale("MakersPath")
local function Ls(key) return (L and L[key]) or key end

MakersPath.L = L
MakersPath.Ls = Ls

-- ===================== SavedVariables =====================
local DB

local MIN_W, MIN_H   = 610, 470
local MAX_W, MAX_H   = 900, 700

-- ===================== Panel =====================
local panel = CreateFrame("Frame", "MakersPathFrame", UIParent, "BasicFrameTemplateWithInset")
panel:SetSize(MIN_W, MIN_H)
panel:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
panel:SetPoint("CENTER")
panel:Hide()

panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
panel:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  if DB then
    local point, _, relativePoint, x, y = self:GetPoint(1)
    DB.pos = DB.pos or {}
    DB.pos.point, DB.pos.relativePoint, DB.pos.x, DB.pos.y = point, relativePoint, x, y
  end
end)

MakersPath.UI = MakersPath.UI or {}
function MakersPath.UI.EnsureMainPanelSize()
  if not MakersPathFrame then return end
  local w, h = MakersPathFrame:GetSize()
  local newW = math.max(MIN_W, math.min(w or MIN_W, MAX_W))
  local newH = math.max(MIN_H, math.min(h or MIN_H, MAX_H))
  if newW ~= w or newH ~= h then
    MakersPathFrame:SetSize(newW, newH)
  end
end

-- Title
panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
panel.title:ClearAllPoints()
if panel.TitleBg then
  panel.title:SetPoint("TOPLEFT", panel.TitleBg, "TOPLEFT", 6, 0)
  panel.title:SetPoint("BOTTOMRIGHT", panel.TitleBg, "BOTTOMRIGHT", -6, 0)
else
  panel.title:SetPoint("TOP", panel, "TOP", 0, -10) -- fallback
end
panel.title:SetJustifyH("CENTER")
panel.title:SetText(L["ADDON_NAME"])

-- Status line
panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
panel.status:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -34)
panel.status:SetText(L["INDEXED_CRAFTABLES_FMT"]:format(0))

-- ===================== Accessors =====================
local function GF()
  return MakersPath and MakersPath.GearFinder
end

local function RefreshStatus()
  if not panel.status then return end
  local gf = GF()
  local count = gf and gf.GetIndexedCount and gf:GetIndexedCount() or 0
  panel.status:SetText(L["INDEXED_CRAFTABLES_FMT"]:format(count))
end

panel:HookScript("OnShow", RefreshStatus)

-- ============ Resize / Scale Helpers ============
local MIN_SCALE, MAX_SCALE = 0.7, 1.4
local SCALE_STEP     = 0.05

local function ApplyPanelSize()
  if not DB then return end
  local w = DB.size and DB.size.w or 400
  local h = DB.size and DB.size.h or 300
  panel:SetSize(w, h)
end

local function ApplyPanelScale(scale)
  scale = tonumber(scale) or 1.0
  scale = math.max(MIN_SCALE, math.min(scale, MAX_SCALE))
  panel:SetScale(scale)
  if DB then DB.scale = scale end
end

local function RestoreMainScale()
  local s = (DB and DB.scale) or 1.0
  ApplyPanelScale(s)
end

if panel.SetResizable then panel:SetResizable(true) end
if panel.SetResizeBounds then
  panel:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
elseif panel.SetMinResize then
  panel:SetMinResize(MIN_W, MIN_H)
else
  panel:SetScript("OnSizeChanged", function(self, width, height)
    local w = math.max(MIN_W, math.min(width,  MAX_W))
    local h = math.max(MIN_H, math.min(height, MAX_H))
    if w ~= width or h ~= height then self:SetSize(w, h) end
    if DB then
      DB.size = DB.size or {}
      DB.size.w, DB.size.h = w, h
    end
  end)
end

panel:HookScript("OnShow", function(self)
  MakersPath.UI.EnsureMainPanelSize()
end)


-- Resize grip
local sizer = CreateFrame("Button", nil, panel)
sizer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
sizer:SetSize(16, 16)
sizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
sizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
sizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
sizer:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
sizer:SetScript("OnMouseDown", function() panel:StartSizing("BOTTOMRIGHT") end)
sizer:SetScript("OnMouseUp", function()
  panel:StopMovingOrSizing()
  local w, h = panel:GetSize()
  if DB then
    DB.size = DB.size or {}
    DB.size.w, DB.size.h = w, h
  end
end)

panel:EnableMouseWheel(true)
panel:HookScript("OnMouseWheel", function(self, delta)
  if not IsControlKeyDown() then return end
  local cur = (DB and DB.scale) or self:GetScale() or 1.0
  local new = cur + (delta > 0 and SCALE_STEP or -SCALE_STEP)
  ApplyPanelScale(new)
  UIErrorsFrame:AddMessage(L["MAIN_SCALE_FMT"]:format(new), 0.2, 0.8, 1.0)
end)

-- Restore / Reset
local function RestorePanelPosition()
  if not DB then return end
  ApplyPanelSize()
  ApplyPanelScale()
  if not DB.pos then return end
  local point = DB.pos.point or "CENTER"
  local relPt = DB.pos.relativePoint or point
  local x     = DB.pos.x or 0
  local y     = DB.pos.y or 0
  panel:ClearAllPoints()
  panel:SetPoint(point, UIParent, relPt, x, y)
end

local function ResetPanelPosition()
  if not DB then return end
  DB.pos  = { point="CENTER", relativePoint="CENTER", x=0, y=0 }
  DB.size = { w=400, h=300 }
  DB.scale= DB.scale or 1.0
  panel:ClearAllPoints()
  panel:SetPoint("CENTER")
  ApplyPanelSize()
  ApplyPanelScale()
end

-- ===================== List UI =====================
local RefreshList
local function SafeRefresh(delay)
  delay = delay or 0.05
  C_Timer.After(delay, function()
    if MakersPath and MakersPath.GearFinderScan then MakersPath.GearFinderScan() end
    C_Timer.After(0.05, function()
      if MakersPathFrame and MakersPathFrame:IsShown() and RefreshList then
        RefreshList()
      end
    end)
  end)
end

-- Content parent
local content = CreateFrame("Frame", nil, MakersPathFrame)
content:SetPoint("TOPLEFT", 10, -40)
content:SetPoint("BOTTOMRIGHT", -10, 40)

-- ScrollFrame
local scroll = CreateFrame("ScrollFrame", nil, content, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT")
scroll:SetPoint("BOTTOMRIGHT")

local ROWS, ROW_H = 18, 20
local rows = {}

local function CreateRow(i)
  local row = CreateFrame("Frame", nil, content)
  row:SetSize(1, ROW_H)
  if i == 1 then
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  else
    row:SetPoint("TOPLEFT", rows[i-1], "BOTTOMLEFT", 0, -2)
  end
  row:SetPoint("RIGHT", content, "RIGHT")

  -- Slot label
  row.slotText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.slotText:SetPoint("LEFT", row, "LEFT", 6, 0)
  row.slotText:SetWidth(120)
  row.slotText:SetJustifyH("LEFT")

  -- Item icon
  row.iconTex = row:CreateTexture(nil, "ARTWORK")
  row.iconTex:SetSize(20, 20)
  row.iconTex:SetPoint("LEFT", row.slotText, "RIGHT", 6, 0)
  row.iconTex:Hide()
  row.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  -- Item name
  row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.itemText:SetPoint("LEFT", row.iconTex, "RIGHT", 6, 0)
  row.itemText:SetWidth(220)
  row.itemText:SetJustifyH("LEFT")

  -- Source/meta
  row.srcText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.srcText:SetPoint("LEFT", row.itemText, "RIGHT", 8, 0)
  row.srcText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
  row.srcText:SetJustifyH("RIGHT")

  -- Clickable overlay for tooltip & modified clicks
  row.itemBtn = CreateFrame("Button", nil, row)
  row.itemBtn:SetPoint("TOPLEFT", row.iconTex, "TOPLEFT", -2, 2)
  row.itemBtn:SetPoint("BOTTOMRIGHT", row.itemText, "BOTTOMRIGHT", 2, -2)
  row.itemBtn:EnableMouse(true)
  row.itemBtn:RegisterForClicks("AnyUp")

  row.itemBtn:SetScript("OnEnter", function(btn)
    local id = btn.itemID
    if not id then return end
    GameTooltip:SetOwner(btn, "ANCHOR_CURSOR_RIGHT")
    local link = select(2, GetItemInfo(id))
    if link then
      GameTooltip:SetHyperlink(link)
    else
      GameTooltip:SetText(L["ITEM_ID_FMT"]:format(id))
    end
    GameTooltip:Show()
  end)
  row.itemBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row.itemBtn:SetScript("OnClick", function(btn)
    local id = btn.itemID
    if not id then return end
    local link = select(2, GetItemInfo(id))
    if not link then
      if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
      return
    end
    if IsModifiedClick("DRESSUP") then
      DressUpItemLink(link)
    elseif IsModifiedClick("CHATLINK") then
      ChatEdit_InsertLink(link)
    end
  end)

  return row
end

for i=1,ROWS do rows[i] = CreateRow(i) end

local SLOT_LABEL = {
  HeadSlot          = _G.HEADSLOT or L["HEAD"],
  NeckSlot          = _G.NECKSLOT or L["NECK"],
  ShoulderSlot      = _G.SHOULDERSLOT or L["SHOULDER"],
  BackSlot          = _G.BACKSLOT or L["BACK"],
  ChestSlot         = _G.CHESTSLOT or L["CHEST"],
  WristSlot         = _G.WRISTSLOT or L["WRIST"],
  HandsSlot         = _G.HANDSSLOT or L["HANDS"],
  WaistSlot         = _G.WAISTSLOT or L["WAIST"],
  LegsSlot          = _G.LEGSSLOT or L["LEGS"],
  FeetSlot          = _G.FEETSLOT or L["FEET"],
  Finger0Slot       = ("%s %d"):format(_G.INVTYPE_FINGER or L["RING"], 1),
  Finger1Slot       = ("%s %d"):format(_G.INVTYPE_FINGER or L["RING"], 2),
  Trinket0Slot      = ("%s %d"):format(_G.INVTYPE_TRINKET or L["TRINKET"], 1),
  Trinket1Slot      = ("%s %d"):format(_G.INVTYPE_TRINKET or L["TRINKET"], 2),
  MainHandSlot      = _G.MAINHANDSLOT or L["MAIN_HAND"],
  SecondaryHandSlot = _G.SECONDARYHANDSLOT or L["OFF_HAND"],
  RangedSlot        = _G.RANGEDSLOT or L["RANGED"],
  AmmoSlot          = _G.AMMOSLOT or L["AMMO"],
}

local function ProfShort(id)
  if id == 164 then return L["BS"]     or "BS"
  elseif id == 165 then return L["LW"] or "LW"
  elseif id == 197 then return L["Tailor"] or "Tailor"
  elseif id == 202 then return L["Eng"]    or "Eng"
  elseif id == 333 then return L["Ench"]   or "Ench"
  else return tostring(id or "?")
  end
end

RefreshList = function()
  local finder = GF()
  if not (finder and finder.BuildSummary) then
    for i=1,ROWS do rows[i]:Hide() end
    FauxScrollFrame_Update(scroll, 0, ROWS, ROW_H+2)
    return
  end

  if finder.BeginSession then finder:BeginSession() end

  local summary = finder:BuildSummary() or {}
  local total  = #summary
  local offset = FauxScrollFrame_GetOffset(scroll)

  for i=1,ROWS do
    local idx = i + offset
    local row = rows[i]
    if idx <= total then
      local data = summary[idx]
      row:Show()

      local slotLabel = SLOT_LABEL[data.slot] or data.slot
      row.slotText:SetText(slotLabel or "")

      if data.best then
        local iid = data.best.itemID
        local link = iid and select(2, GetItemInfo(iid)) or nil
        local shown = link or (data.best.name or L["ITEM_ID_FMT"]:format(iid or 0))
        row.itemText:SetText(shown)

        local icon = iid and GetItemIcon(iid) or "Interface\\ICONS\\INV_Misc_QuestionMark"
        row.iconTex:SetTexture(icon or "Interface\\ICONS\\INV_Misc_QuestionMark")
        row.iconTex:Show()

        row.itemBtn.itemID = iid

        local function ResolveRequiredLevel(iid2, fallback)
          if not iid2 then return fallback or 0 end
          local _, _, _, _, reqLevel = GetItemInfo(iid2)
          if type(reqLevel)=="number" then return reqLevel end
          return fallback or 0
        end

        local prof   = ProfShort(data.best.__profId or data.best.reqSkill)
        local need   = tonumber(data.best.__needRank or data.best.reqSkillLevel or 0) or 0
        local have   = tonumber(data.best.__haveRank or 0) or 0
        local delta  = math.max(0, need - have)
        local reqL   = ResolveRequiredLevel(iid, tonumber(data.best.reqLevel or 0) or 0)
        local diff   = (data.bestScore or 0) - (data.eqScore or 0)

        local meta = L["META_PREFIX_FMT"]:format(prof, need)
        if delta > 0 then meta = meta .. L["META_DELTA_FMT"]:format(delta) end
        meta = meta .. L["META_CLOSE"]
        if reqL > 0 then meta = meta .. L["META_REQ_LVL_FMT"]:format(reqL) end
        if diff and diff ~= 0 then meta = meta .. ("  |cff00ff00"..L["SIGNED_FLOAT_FMT"].."|r"):format(diff) end
        row.srcText:SetText(meta)

        if iid and not link and C_Item and C_Item.RequestLoadItemDataByID then
          C_Item.RequestLoadItemDataByID(iid)
          C_Timer.After(0.1, function()
            if MakersPathFrame:IsShown() then RefreshList() end
          end)
        end
      else
        row.itemText:SetText("|cff888888"..L["NO_CRAFT_UPGRADE"].."|r")
        row.iconTex:Hide()
        row.itemBtn.itemID = nil
        row.srcText:SetText("")
      end
    else
      row:Hide()
    end
  end

  FauxScrollFrame_Update(scroll, total, ROWS, ROW_H+2)
end

-- ---------- Empty-state hint ----------
local emptyHint = MakersPathFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptyHint:SetPoint("TOPLEFT", MakersPathFrame, "TOPLEFT", 12, -50)
emptyHint:SetJustifyH("LEFT")
emptyHint:SetText("|cffaaaaaa"..L["EMPTY_HINT"].."|r")
emptyHint:Hide()

MakersPathFrame:HookScript("OnSizeChanged", function(self, w)
  emptyHint:SetWidth(w - 24)
end)

local function UpdateEmptyHint()
  local gf = GF()
  local count = gf and gf.GetIndexedCount and gf:GetIndexedCount() or 0
  emptyHint:SetShown(count == 0)
end

-- Refresh Button
local refreshBtn = CreateFrame("Button", nil, MakersPathFrame, "UIPanelButtonTemplate")
refreshBtn:SetSize(90, 22)
refreshBtn:SetPoint("BOTTOMRIGHT", MakersPathFrame, "BOTTOMRIGHT", -12, 12)
refreshBtn:SetText(L["BTN_REFRESH"])
refreshBtn:SetScript("OnClick", function(self)
  self:SetEnabled(false)
  self._oldText = self._oldText or self:GetText()
  self:SetText(L["BTN_REFRESHING"])

  if GF() and GF().BeginSession then GF():BeginSession() end
  if MakersPath and MakersPath.GearFinderScan then MakersPath.GearFinderScan() end

  C_Timer.After(0.10, function()
    UpdateEmptyHint()
    RefreshStatus()
    if MakersPathFrame:IsShown() and RefreshList then RefreshList() end
    if self then
      self:SetText(self._oldText or L["BTN_REFRESH"])
      self:SetEnabled(true)
    end
  end)
end)

-- Profession Book Button
local profBookBtn = CreateFrame("Button", nil, MakersPathFrame, "UIPanelButtonTemplate")
profBookBtn:SetSize(110, 22)
profBookBtn:SetPoint("BOTTOMLEFT", MakersPathFrame, "BOTTOMLEFT", 12, 12)
profBookBtn:SetText(L["BTN_PROF_BOOK"])
profBookBtn:SetScript("OnClick", function()
  if MakersPath and MakersPath.UI and MakersPath.UI.ToggleProfBook then
    MakersPath.UI.ToggleProfBook()
  elseif MakersPathProfBook then
    if MakersPathProfBook:IsShown() then
      MakersPathProfBook:Hide()
    else
      if MakersPath.UI and MakersPath.UI.RefreshProfBook then MakersPath.UI.RefreshProfBook() end
      MakersPathProfBook:Show()
    end
  end
end)

MakersPathFrame:HookScript("OnShow", function()
  if GF() and GF().BeginSession then GF():BeginSession() end
  local finder = GF()
  local count = finder and finder.GetIndexedCount and finder:GetIndexedCount() or 0
  if MakersPathFrame.status then
    MakersPathFrame.status:SetText(L["INDEXED_CRAFTABLES_FMT"]:format(count))
  end
  UpdateEmptyHint()
  SafeRefresh(0.10)
end)

-- ===================== Events =====================
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    MakersPathDB = MakersPathDB or {}
    DB = MakersPathDB
    DB.pos   = DB.pos   or { point="CENTER", relativePoint="CENTER", x=0, y=0 }
    DB.size  = DB.size  or { w=400, h=300 }
    DB.scale = DB.scale or 1.0
    RestorePanelPosition()
  elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    if GF() and GF().BeginSession then GF():BeginSession() end
    if MakersPath.ScanProfessions then MakersPath.ScanProfessions() end
    RefreshStatus()
    UpdateEmptyHint()
  elseif event == "PLAYER_EQUIPMENT_CHANGED"
      or event == "PLAYER_LEVEL_UP"
      or event == "SKILL_LINES_CHANGED"
      or event == "TRADE_SKILL_SHOW"
      or event == "GET_ITEM_INFO_RECEIVED" then
    if GF() and GF().BeginSession then GF():BeginSession() end
    RefreshStatus()
    UpdateEmptyHint()
    SafeRefresh(0.05)

    if panel:IsShown() then
      C_Timer.After(0.05, function()
        if MakersPath and MakersPath.GearFinderScan then MakersPath.GearFinderScan() end
        C_Timer.After(0.05, function() if panel:IsShown() then RefreshList() end end)
      end)
    end
  elseif event == "PLAYER_LOGOUT" then
  end
end)

if MakersPath and MakersPath.GearFinder and MakersPath.GearFinder._equippedScoreCache then
  wipe(MakersPath.GearFinder._equippedScoreCache)
end

-- ===================== Character Panel Button =====================
local function _CreateCharPanelButton()
  if not CharacterFrame then return end
  if MakersPathCharBtn then return end

  local btn = CreateFrame("Button", "MakersPathCharBtn", CharacterFrame)
  btn:SetSize(26, 26)

  if CharacterFrameCloseButton then
    btn:SetPoint("TOPRIGHT", CharacterFrameCloseButton, "BOTTOMRIGHT", -20, -4)
  else
    btn:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -42, -32)
  end

  btn:SetFrameStrata(CharacterFrame:GetFrameStrata())
  btn:SetFrameLevel(CharacterFrame:GetFrameLevel() + 5)

  local tex = btn:CreateTexture(nil, "ARTWORK", nil, 1)
  tex:SetTexture("Interface\\AddOns\\MakersPath\\Art\\makerspathmm")
  tex:SetSize(32, 32)
  tex:SetPoint("CENTER", btn, "CENTER", 0, 0)
  btn.tex = tex

  btn:SetScript("OnMouseDown", function(self)
    tex:SetVertexColor(0.8, 0.8, 0.8)
  end)
  btn:SetScript("OnMouseUp", function(self)
    tex:SetVertexColor(2.0, 2.0, 2.0)
  end)

  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("|cff00ccff"..L["ADDON_NAME"].."|r", 0.2, 0.8, 1)
    GameTooltip:AddLine(L["LEFTCLICK_OPEN"], 1,1,1)
    GameTooltip:AddLine(L["RIGHTCLICK_BOOK"], 1,1,1)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:SetScript("OnClick", function(_, b)
    if b == "RightButton" then
      if MakersPath and MakersPath.UI and MakersPath.UI.ToggleProfBook then
        MakersPath.UI.ToggleProfBook()
      end
    else
      if MakersPathFrame and MakersPathFrame:IsShown() then
        MakersPathFrame:Hide()
      else
        if MakersPath and MakersPath.GearFinder and MakersPath.GearFinder.BeginSession then
          MakersPath.GearFinder:BeginSession()
        end
        if MakersPathFrame then MakersPathFrame:Show() end
      end
    end
  end)
end
-- Paperdoll
do
  local w = CreateFrame("Frame")
  w:RegisterEvent("ADDON_LOADED")
  w:RegisterEvent("PLAYER_LOGIN")
  w:RegisterEvent("PLAYER_ENTERING_WORLD")
  w:SetScript("OnEvent", function(_, ev, name)
    if ev == "ADDON_LOADED" and name ~= ADDON_NAME then return end
    if CharacterFrame then _CreateCharPanelButton() end
  end)
end

-- ===== Spec Choices =====
MakersPath.Spec.CHOICES = {
  DRUID = {
    { text= Ls("SPEC_AUTO_NO_OVERRIDE"), value="" },
    { text= Ls("DRUID_BALANCE"),     value="BALANCE" },
    { text= Ls("DRUID_FERAL_DPS"),    value="FERAL_DPS" },
    { text= Ls("DRUID_FERAL_TANK"),   value="FERAL_TANK" },
    { text= Ls("DRUID_RESTORATION"),  value="RESTORATION" },
  },
  SHAMAN = {
    { text= Ls("SPEC_AUTO_NO_OVERRIDE"), value="" },
    { text= Ls("SHAMAN_ELEMENTAL"),   value="ELEMENTAL" },
    { text= Ls("SHAMAN_ENHANCEMENT"), value="ENHANCEMENT" },
    { text= Ls("SHAMAN_RESTORATION"), value="RESTORATION" },
  },
  WARRIOR = {
    { text= Ls("SPEC_AUTO_NO_OVERRIDE"), value="" },
    { text= Ls("WARRIOR_ARMS"),       value="ARMS" },
    { text= Ls("WARRIOR_FURY"),       value="FURY" },
    { text= Ls("WARRIOR_PROTECTION"), value="PROTECTION" },
    { text= Ls("WARRIOR_FURYPROT"),  value="FURYPROT" },
  },
  PALADIN = {
    { text= Ls("SPEC_AUTO_NO_OVERRIDE"), value="" },
    { text= Ls("PALADIN_HOLY"),       value="HOLY" },
    { text= Ls("PALADIN_PROTECTION"), value="PROTECTION" },
    { text= Ls("PALADIN_RETRIBUTION"),value="RETRIBUTION" },
  },
  PRIEST = {
    { text= Ls("SPEC_AUTO_NO_OVERRIDE"), value="" },
    { text= Ls("PRIEST_DISCIPLINE"), value="DISCIPLINE" },
    { text= Ls("PRIEST_HOLY"),       value="HOLY" },
    { text= Ls("PRIEST_SHADOW"),     value="SHADOW" },
  },
  MAGE = {
    { text= Ls("SPEC_AUTO_NO_OVERRIDE"), value="" },
    { text= Ls("MAGE_ARCANE"),     value="ARCANE" },
    { text= Ls("MAGE_FIRE"),       value="FIRE" },
    { text= Ls("MAGE_FROST"),      value="FROST" },
    { text= Ls("MAGE_AOE"),        value="AOE" },
  },
  WARLOCK = {
    { text= Ls("SPEC_AUTO_NO_OVERRIDE"), value="" },
    { text= Ls("WARLOCK_AFFLICTION"), value="AFFLICTION" },
    { text= Ls("WARLOCK_DEMONOLOGY"), value="DEMONOLOGY" },
    { text= Ls("WARLOCK_DESTRUCTION"),value="DESTRUCTION" },
  },
  HUNTER = {
    { text= Ls("SPEC_AUTO_NO_OVERRIDE"), value="" },
    { text= Ls("HUNTER_BEAST_MASTERY"), value="BEAST_MASTERY" },
    { text= Ls("HUNTER_MARKSMANSHIP"),  value="MARKSMANSHIP" },
    { text= Ls("HUNTER_SURVIVAL"),      value="SURVIVAL" },
  },
  ROGUE = {
    { text= Ls("SPEC_AUTO_NO_OVERRIDE"), value="" },
    { text= Ls("ROGUE_ASSASSINATION"), value="ASSASSINATION" },
    { text= Ls("ROGUE_COMBAT"),        value="COMBAT" },
    { text= Ls("ROGUE_SUBTLETY"),      value="SUBTLETY" },
  },
}

-- ===== Spec Dropdown UI =====
MakersPath.SpecUI = MakersPath.SpecUI or {}

function MakersPath.SpecUI.Init(parent)
  if not parent or MakersPath.SpecUI._inited then return end
  MakersPath.SpecUI._inited = true

  if not (MakersPath.Spec and MakersPath.Spec.CHOICES) then return end

  local _, class = UnitClass("player")
  class = class and class:upper() or "UNKNOWN"
  local choices = MakersPath.Spec.CHOICES[class]
  if not choices then return end

  local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lbl:SetText("Spec:")
  lbl:SetPoint("LEFT", profBookBtn, "RIGHT", 16, 0)

  local dd = CreateFrame("Frame", "MakersPathSpecDropdown", parent, "UIDropDownMenuTemplate")
  dd:SetPoint("LEFT", lbl, "RIGHT", 6, -2)
  UIDropDownMenu_SetWidth(dd, 170)

  local function currentText()
    local cur = CurrentSpec() or ""
    for _, o in ipairs(choices) do
      if o.value == cur then return o.text end
    end
    return "Auto (no override)"
  end

  local function OnSelect(_, arg1)
    SetCurrentSpec(arg1 or "")
    UIDropDownMenu_SetText(dd, currentText())
  end

  local function Initialize(self, level)
    if level ~= 1 then return end
    local cur = CurrentSpec() or ""
    for _, opt in ipairs(choices) do
      local info = UIDropDownMenu_CreateInfo()
      info.text    = opt.text
      info.arg1    = opt.value
      info.func    = OnSelect
      info.checked = (cur == (opt.value or ""))
      UIDropDownMenu_AddButton(info, 1)
    end
  end

  UIDropDownMenu_Initialize(dd, Initialize)
  UIDropDownMenu_SetText(dd, currentText())

  parent:HookScript("OnShow", function()
    UIDropDownMenu_SetText(dd, currentText())
  end)
end
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("ADDON_LOADED")
  f:SetScript("OnEvent", function(_, ev, addon)
    if ev == "PLAYER_LOGIN" or (ev=="ADDON_LOADED" and addon == ADDON) then
      if MakersPathFrame and MakersPath.SpecUI and MakersPath.SpecUI.Init then
        MakersPath.SpecUI.Init(MakersPathFrame)
      end
    end
  end)
end


-- ===================== Slash (user-facing only) =====================
-- Toggle
SLASH_MAKERSPATH1 = "/mp"
SLASH_MAKERSPATH2 = "/makerspath"
SlashCmdList["MAKERSPATH"] = function()
  if panel:IsShown() then panel:Hide() else
    if GF() and GF().BeginSession then GF():BeginSession() end
    panel:Show()
  end
end
-- Reset panel position/size/scale
SLASH_MAKERSPATHRESET1 = "/mpreset"
SlashCmdList["MAKERSPATHRESET"] = function() ResetPanelPosition() end

SLASH_MAKERSPATHSCALE1 = "/mpscale"
SlashCmdList["MAKERSPATHSCALE"] = function(msg)
  local s = tonumber(msg)
  if not DB then return end
  if not s or s <= 0 then return end
  s = math.max(MIN_SCALE, math.min(s, MAX_SCALE))
  DB.scale = s
  panel:SetScale(s)
end
-- Change Future Look
SLASH_MPCAP1 = "/mpcap"
SlashCmdList["MPCAP"] = function(msg)
  local raw = tostring(msg or "")
  local t = raw:match("^%s*(.-)%s*$") or ""
  local maxToken = Ls("CMD_MAX")
  local isMax = (maxToken and t:lower() == maxToken:lower()) or false
  local v = tonumber(t)
  if isMax then
    MakersPath.FutureWindow = 60
  elseif v then
    MakersPath.FutureWindow = math.max(0, math.floor(v))
  else
    print("|cff66ccff["..Ls("ADDON_NAME").."]|r "..Ls("USAGE_MPCAP"))
    return
  end
  print("|cff66ccff["..Ls("ADDON_NAME").."]|r "..Ls("FUTUREWINDOW_SET"):format(MakersPath.FutureWindow))
  if MakersPath and MakersPath.GearFinderScan then MakersPath.GearFinderScan() end
  if MakersPathFrame and MakersPathFrame:IsShown() and RefreshList then RefreshList() end
end
