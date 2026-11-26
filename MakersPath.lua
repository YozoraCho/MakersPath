local ADDON_NAME, MakersPath = ...
local API = MakersPath.API or {}  -- see Core/Compat.lua

MakersPath = MakersPath or {}
MakersPath.name = ADDON_NAME
MakersPath.version = "2.0.0"
_G.MakersPath = MakersPath
local debugprofilestop = debugprofilestop
MakersPath.Config = MakersPath.Config or {}
MakersPath.Config.DEBUG_TIMING = MakersPath.Config.DEBUG_TIMING or false
MakersPath.Util = MakersPath.Util or {}
MakersPath.Spec = MakersPath.Spec or {}

-- ===================== Localization shim =====================
local AceLocale = LibStub and LibStub("AceLocale-3.0", true)
local L = AceLocale and AceLocale:GetLocale("MakersPath", true) or {}
local function Ls(key) return (L and L[key]) or key end

MakersPath.L = L
MakersPath.Ls = Ls

-- ===================== Dropdowns =====================
local LibDD = LibStub("LibUIDropDownMenu-4.0")
MakersPath.LibDD = LibDD
-- ===================== Client Detection =====================

local client   = MakersPath.client or {}
local features = MakersPath.features or {}

-- ===================== SavedVariables =====================
local DB

local MIN_W, MIN_H   = 760, 560
local MAX_W, MAX_H   = 900, 700

-- ==================== Alt Helpers ====================

local function GetCachedSummaryForKey(key)
  if not key then return nil end
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.chars = MakersPathDB.chars or {}
  local rec = MakersPathDB.chars[key]
  return rec and rec.gearSummary or nil
end

local SLOT_ORDER = {
  "HeadSlot",
  "NeckSlot",
  "ShoulderSlot",
  "BackSlot",
  "ChestSlot",
  "WristSlot",
  "HandsSlot",
  "WaistSlot",
  "LegsSlot",
  "FeetSlot",
  "Finger0Slot",
  "Finger1Slot",
  "Trinket0Slot",
  "Trinket1Slot",
  "MainHandSlot",
  "SecondaryHandSlot",
  "RangedSlot",
  "AmmoSlot",
}

local SLOT_INDEX = {}
for i, slot in ipairs(SLOT_ORDER) do
  SLOT_INDEX[slot] = i
end

local function SummaryRowsFromCached(gs)
  local rows = {}
  if not gs or type(gs) ~= "table" then return rows end

  local slots = gs.slots or {}
  for slotName, info in pairs(slots) do
    local bestScore = info.bestScore or 0
    local eqScore   = info.eqScore or 0
    local pct = 0
    if bestScore > 0 then
      pct = math.max(0, math.min(1, (eqScore or 0) / bestScore))
    end

    local best
    if info.itemID then
      best = {
        itemID        = info.itemID,
        invType       = info.invType,
        reqLevel      = info.reqLevel,
        reqSkill      = info.reqSkill,
        reqSkillLevel = info.reqSkillLevel,
        score         = bestScore,
        eqScore       = eqScore,
        __profId      = info.__profId,
        __needRank    = info.__needRank,
        __haveRank    = info.__haveRank,
      }
    end
    local alts
    if info.alts and #info.alts > 0 then
      alts = {}
      for _, a in ipairs(info.alts) do
        if a and a.itemID then
          alts[#alts+1] = {
            itemID        = a.itemID,
            invType       = a.invType,
            reqLevel      = a.reqLevel,
            reqSkill      = a.reqSkill,
            reqSkillLevel = a.reqSkillLevel,
            score         = a.score or 0,
            __profId      = a.__profId,
            __needRank    = a.__needRank,
            __haveRank    = a.__haveRank,
          }
        end
      end
    end

    rows[#rows+1] = {
      slot      = slotName,
      best      = best,
      bestScore = bestScore,
      eqScore   = eqScore,
      progress  = pct,
      alts      = alts,
    }
  end

  table.sort(rows, function(a, b)
    local ia = SLOT_INDEX[a.slot] or 999
    local ib = SLOT_INDEX[b.slot] or 999
    if ia ~= ib then
      return ia < ib
    end
    return (a.slot or "") < (b.slot or "")
  end)

  return rows
end

-- ===================== Panel =====================
local panel = CreateFrame("Frame", "MakersPathFrame", UIParent, "BackdropTemplate")
table.insert(UISpecialFrames, "MakersPathFrame")
panel:SetFrameStrata("DIALOG")
panel:SetClampedToScreen(true)
panel:Hide()
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
local W, Theme = MakersPath.Widgets, MakersPath.Theme
local page = W.Window(panel)

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
function MakersPath.UI.Toggle()
  if not MakersPathFrame then return end

  if MakersPathFrame:IsShown() then
    MakersPathFrame:Hide()
  else
    if MakersPath and MakersPath.GearFinder and MakersPath.GearFinder.BeginSession then
      MakersPath.GearFinder:BeginSession()
    end
    if MakersPath.UI and MakersPath.UI.EnsureMainPanelSize then
      MakersPath.UI.EnsureMainPanelSize()
    end
    MakersPathFrame:Show()
  end
end
MakersPath.UI.ActiveProfileKey = MakersPath.UI.ActiveProfileKey or nil
function MakersPath.UI.EnsureMainPanelSize()
  if not MakersPathFrame then return end
  local w, h = MakersPathFrame:GetSize()
  local newW = math.max(MIN_W, math.min(w or MIN_W, MAX_W))
  local newH = math.max(MIN_H, math.min(h or MIN_H, MAX_H))
  if newW ~= w or newH ~= h then
    MakersPathFrame:SetSize(newW, newH)
  end
end

-- Header
panel.header = W.Header(page, L["ADDON_NAME"], function() panel:Hide() end)
panel.title = panel.header.title
panel.header:EnableMouse(true)
panel.header:RegisterForDrag("LeftButton")
panel.header:SetScript("OnDragStart", function() panel:StartMoving() end)
panel.header:SetScript("OnDragStop", function() panel:GetScript("OnDragStop")(panel) end)

panel.footer = W.Footer(page)

panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
panel.status:Hide()

-- ===================== Accessors =====================
local function GF()
  return MakersPath and MakersPath.GearFinder
end

local function RefreshStatus()
  if not panel.status then return end
  local gf = GF()
  local count = gf and gf.GetIndexedCount and gf:GetIndexedCount() or 0
  panel.status:SetText((L["INDEXED_CRAFTABLES_FMT"] or "Indexed Craftables: %d"):format(count))
end

panel:HookScript("OnShow", RefreshStatus)

-- ============ Resize / Scale Helpers ============
local MIN_SCALE, MAX_SCALE = 0.7, 1.4
local SCALE_STEP     = 0.05

local function ApplyPanelSize()
  if not DB then return end
  local w = DB.size and DB.size.w or MIN_W
  local h = DB.size and DB.size.h or MIN_H
  panel:SetSize(w, h)
end

local function ApplyPanelScale(scale)
  scale = tonumber(scale) or 1.0
  scale = math.floor(scale / SCALE_STEP + 0.5) * SCALE_STEP
  scale = math.max(MIN_SCALE, math.min(scale, MAX_SCALE))
  panel:SetScale(scale)
  if DB then DB.scale = scale end
  return scale
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
sizer:SetFrameLevel(panel:GetFrameLevel() + 20)
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
  local new = ApplyPanelScale(cur + (delta > 0 and SCALE_STEP or -SCALE_STEP))
  UIErrorsFrame:AddMessage(L["MAIN_SCALE_FMT"]:format(new), 0.2, 0.8, 1.0)
end)

-- Restore / Reset
local function RestorePanelPosition()
  if not DB then return end
  ApplyPanelSize()
  RestoreMainScale()
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
  DB.size = { w=MIN_W, h=MIN_H }
  DB.scale= DB.scale or 1.0
  panel:ClearAllPoints()
  panel:SetPoint("CENTER")
  ApplyPanelSize()
  RestoreMainScale()
end

-- ===================== List UI =====================
local RefreshList
local RebuildCurrentSummaryView

local function SafeRefresh(delay)
  delay = delay or 0.05
  C_Timer.After(delay, function()
    if not (MakersPathFrame and MakersPathFrame:IsShown()) then
      return
    end
    RebuildCurrentSummaryView()
  end)
end

local function GetSummaryBySlot()
  local finder = GF()
  if not finder then return {} end

  local activeKey = MakersPath.UI.ActiveProfileKey
  local thisKey   = MakersPath.Util.CurrentCharKey()
  local summary

  if not activeKey or activeKey == thisKey then
    -- Draw whatever we have. Building happens in the background
    -- (EnsureSummaryFresh); a synchronous build here caused frame stutter.
    summary = finder._lastSummary or {}
  else
    local cached = GetCachedSummaryForKey(activeKey)
    summary = SummaryRowsFromCached(cached)
  end

  local bySlot = {}
  for _, row in ipairs(summary) do
    if row and row.slot then
      bySlot[row.slot] = row
    end
  end
  return bySlot
end

-- Forced rebuild (Refresh button, spec change, /mpcap). If the window is
-- closed it only marks the summary dirty; the next open rebuilds it.
function RebuildCurrentSummaryView()
  local finder = GF()
  if not finder then return end

  local activeKey = MakersPath.UI.ActiveProfileKey
  local thisKey = MakersPath.Util.CurrentCharKey()

  if activeKey and activeKey ~= thisKey then
    if RefreshList then RefreshList() end
    return
  end

  if not (MakersPathFrame and MakersPathFrame:IsShown()) then
    if finder.MarkDirty then finder:MarkDirty() end
    return
  end

  if finder.InvalidateSummary then
    finder:InvalidateSummary()
  else
    finder._summaryDirty = true
    finder._lastSummary = nil
    finder._equippedScoreCache = nil
    finder._isBuildingSummary = false
  end

  if MakersPathFrame and MakersPathFrame:IsShown() then
    if finder.BuildSummaryAsync then
      finder:BuildSummaryAsync(
        function(rows)
          finder._lastSummary = rows
          if RefreshList then RefreshList() end
        end,
        function(rows)
          finder._lastSummary = rows
          if RefreshList then RefreshList() end
        end
      )
    elseif finder.BuildSummary then
      finder._lastSummary = finder:BuildSummary() or {}
      if RefreshList then RefreshList() end
    end
  end
end

-- Restore the summary saved for this character if nothing it depends on has
-- changed since it was built (e.g. right after /reload or login).
local function TryRestoreSavedSummary(finder)
  if finder._lastSummary and #finder._lastSummary > 0 then return end
  if not finder.InputSignature then return end
  local gs = GetCachedSummaryForKey(MakersPath.Util.CurrentCharKey())
  if not (gs and gs.sig) then return end
  if gs.sig ~= finder:InputSignature() then return end
  local rows = SummaryRowsFromCached(gs)
  if #rows == 0 then return end
  finder._lastSummary = rows
  finder._builtSig    = gs.sig
  finder._summaryDirty = false
end

-- Rebuild only when something the summary depends on changed; otherwise
-- just redraw. While rebuilding, the previous list stays on screen.
local function EnsureSummaryFresh()
  if not (MakersPathFrame and MakersPathFrame:IsShown()) then return end
  local finder = GF()
  if not finder then return end

  local activeKey = MakersPath.UI.ActiveProfileKey
  if activeKey and activeKey ~= MakersPath.Util.CurrentCharKey() then
    if RefreshList then RefreshList() end
    return
  end

  TryRestoreSavedSummary(finder)

  local sig = finder.InputSignature and finder:InputSignature()
  local hasRows = finder._lastSummary and #finder._lastSummary > 0
  if hasRows and not finder._summaryDirty and sig == finder._builtSig then
    if RefreshList then RefreshList() end
    return
  end

  -- Already building exactly this? Let it finish.
  if finder._isBuildingSummary and not finder._summaryDirty and sig == finder._buildingSig then
    return
  end

  if not finder.BuildSummaryAsync then
    if finder.BuildSummary then finder:BuildSummary() end
    if RefreshList then RefreshList() end
    return
  end

  local showPartial = not hasRows
  finder:BuildSummaryAsync(
    function(rows)
      if showPartial and MakersPathFrame:IsShown() and RefreshList then
        finder._lastSummary = rows
        RefreshList()
      end
    end,
    function(rows)
      finder._lastSummary = rows
      if MakersPathFrame:IsShown() and RefreshList then RefreshList() end
    end
  )
  if RefreshList then RefreshList() end
end
MakersPath.UI.EnsureSummaryFresh = EnsureSummaryFresh

-- Debounced: many requests in a burst cause one check after things settle.
do
  local requestGen = 0
  function MakersPath.RequestUIRefresh(delay)
    requestGen = requestGen + 1
    local myGen = requestGen
    C_Timer.After(math.max(delay or 0.10, 0.10), function()
      if myGen ~= requestGen then return end
      EnsureSummaryFresh()
    end)
  end
end

-- Cheap redraw (names/icons only), throttled.
local QueueRedraw
do
  local queued = false
  QueueRedraw = function()
    if queued then return end
    queued = true
    C_Timer.After(0.2, function()
      queued = false
      if MakersPathFrame and MakersPathFrame:IsShown() and RefreshList then RefreshList() end
    end)
  end
  MakersPath.UI.QueueRedraw = QueueRedraw
end

RefreshList = function()
  local view = MakersPath.UI and MakersPath.UI.MainView
  if not view then return end
  local finder = GF()
  view.Refresh(GetSummaryBySlot(), finder and finder._isBuildingSummary or false)
end

local function UpdateEmptyHint()
  local gf = GF()
  local count = gf and gf.GetIndexedCount and gf:GetIndexedCount() or 0
  if panel.status then
    if count == 0 then
      panel.status:SetText("|cffaaaaaa" .. (L["EMPTY_HINT"] or "") .. "|r")
    else
      panel.status:SetText("")
    end
  end
end

--- Character Roster
local function BuildProfileRoster()
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.chars = MakersPathDB.chars or {}
  local thisKey = MakersPath.Util.CurrentCharKey()
  local out = {}

  for key, rec in pairs(MakersPathDB.chars) do
    if key ~= thisKey then
      local name  = rec.name or key:match("^[^-]+") or key
      local level = rec.level
      local class = rec.class

      local label = name
      if level and class then
        label = string.format("%s (|cffffff00%s %s|r)", name, tostring(level), class)
      end

      out[#out+1] = {
        key       = key,
        label     = label,
        isCurrent = false,
      }
    end
  end

  table.sort(out, function(a, b) return a.label < b.label end)
  return out
end

-- ===================== Profile viewer (alts) =====================
MakersPath.UI.ActiveProfileKey = MakersPath.UI.ActiveProfileKey or nil

local function SetActiveProfile(key)
  MakersPath.UI.ActiveProfileKey = key

  if not MakersPathFrame:IsShown() then
    return
  end

  local thisKey = MakersPath.Util.CurrentCharKey()
  if not key or key == thisKey then
    EnsureSummaryFresh()
  else
    if RefreshList then RefreshList() end
  end
end

function MakersPath.UI.CurrentProfileText()
  local thisKey = MakersPath.Util.CurrentCharKey()
  local active  = MakersPath.UI.ActiveProfileKey

  if not active or active == thisKey then
    local name = UnitName("player") or "?"
    return name
  end

  MakersPathDB       = MakersPathDB or {}
  MakersPathDB.chars = MakersPathDB.chars or {}
  local rec = MakersPathDB.chars[active]

  local displayName
  if rec and rec.name then
    displayName = rec.name
  else
    local n = active:match("^([^%-]+)%-.+$")
    displayName = n or active
  end

  return displayName
end

local function ProfileDrop_Init(self, level)
  if level ~= 1 then return end

  local thisKey = MakersPath.Util.CurrentCharKey()
  local active  = MakersPath.UI.ActiveProfileKey
  local roster  = BuildProfileRoster()
  do
    local info = LibDD:UIDropDownMenu_CreateInfo()
    info.text         = L["PROFILE_ACTIVE"]
    info.func         = function() SetActiveProfile(nil) end
    info.checked      = (not active or active == thisKey)
    info.notCheckable = false
    LibDD:UIDropDownMenu_AddButton(info, level)
  end
  if #roster > 0 then
    local sep = LibDD:UIDropDownMenu_CreateInfo()
    sep.isTitle      = true
    sep.notCheckable = true
    sep.text         = L["PROFILE_ALT"]
    LibDD:UIDropDownMenu_AddButton(sep, level)
  end
  for _, row in ipairs(roster) do
    local info = LibDD:UIDropDownMenu_CreateInfo()
    info.text         = row.label
    info.arg1         = row.key
    info.notCheckable = false
    info.checked      = (active == row.key)
    info.func = function(_, key)
      SetActiveProfile(key)
    end
    LibDD:UIDropDownMenu_AddButton(info, level)
  end
end

panel.charsBtn = W.Dropdown(panel.header, "MakersPathProfileDropdown", ProfileDrop_Init)
panel.charsBtn:SetText(L["PROFILE_BUTTON"] or "Characters")
panel.charsBtn:SetPoint("RIGHT", panel.header.close, "LEFT", -4, 0)

-- Refresh Button
local refreshBtn = W.Button(panel.footer, L["BTN_REFRESH"], nil, { primary = true, minWidth = 70 })
refreshBtn:SetPoint("RIGHT", panel.footer, "RIGHT", -8, 0)
panel.refreshBtn = refreshBtn
refreshBtn:SetScript("OnClick", function(self)
  self:SetEnabled(false)
  self._oldText = self._oldText or self:GetText()
  self:SetText(L["BTN_REFRESHING"])

  local finder = GF()
  if finder and finder.BeginSession then
    finder:BeginSession()
  end

  RefreshStatus()
  UpdateEmptyHint()

  if MakersPathFrame:IsShown() then
    RebuildCurrentSummaryView()
  end

  C_Timer.After(0.10, function()
    if self then
      self:SetText(self._oldText or L["BTN_REFRESH"])
      self:SetEnabled(true)
    end
  end)
end)

-- Profession Book Button
local profBookBtn = W.Button(panel.footer, L["BTN_PROF_BOOK"])
profBookBtn:SetPoint("LEFT", panel.footer, "LEFT", 8, 0)
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

-- Options Button
local optionsBtn = W.Button(panel.footer, L["BTN_OPTIONS"] or "Options")
optionsBtn:SetPoint("LEFT", profBookBtn, "RIGHT", 6, 0)
panel.optionsBtn = optionsBtn
optionsBtn:SetScript("OnClick", function()
  if MakersPath and MakersPath.UI and MakersPath.UI.ToggleOptions then
    MakersPath.UI:ToggleOptions()
  end
end)

MakersPathFrame:HookScript("OnShow", function()
  local finder = GF()

  local count = finder and finder.GetIndexedCount and finder:GetIndexedCount() or 0
  if MakersPathFrame.status then
    MakersPathFrame.status:SetText(L["INDEXED_CRAFTABLES_FMT"]:format(count))
  end

  UpdateEmptyHint()

  -- Shows the last (or saved) results immediately; rebuilds in the
  -- background only if something they depend on has changed.
  EnsureSummaryFresh()
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
    DB.size  = DB.size  or { w=MIN_W, h=MIN_H }
    DB.scale = DB.scale or 1.0
    DB.config = DB.config or {}
    if DB.config.FUTURE_WINDOW then MakersPath.FutureWindow = DB.config.FUTURE_WINDOW end
    if MakersPath.SyncDebugMirror then MakersPath.SyncDebugMirror() end
    RestorePanelPosition()

  -- None of these force a rebuild. They rescan what changed and ask for a
  -- refresh; EnsureSummaryFresh compares the input signature and only
  -- rebuilds if something the suggestions depend on is different.
  -- (SKILL_LINES_CHANGED fires on every weapon skill-up, and
  -- PLAYER_ENTERING_WORLD on every loading screen.)
  elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD"
      or event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_SHOW" then
    if GF() and GF().InvalidateKnownSpellNames then GF():InvalidateKnownSpellNames() end
    if MakersPath.ScanProfessions then
      MakersPath.ScanProfessions(function()
        if MakersPath.RequestUIRefresh then MakersPath.RequestUIRefresh(0.5) end
      end)
    end
    RefreshStatus()
    UpdateEmptyHint()

  elseif event == "PLAYER_EQUIPMENT_CHANGED"
      or event == "PLAYER_LEVEL_UP" then
    RefreshStatus()
    UpdateEmptyHint()
    if MakersPath.RequestUIRefresh then MakersPath.RequestUIRefresh(0.3) end

  elseif event == "GET_ITEM_INFO_RECEIVED" then
    -- Fires for every item the game loads, ours or not. Redraw names and
    -- icons; rebuild only if the last build was waiting on this item.
    local itemID = tonumber(arg1)
    local finder = GF()
    if itemID and finder and finder._pendingItems and finder._pendingItems[itemID] then
      finder._pendingItems[itemID] = nil
      finder._summaryDirty = true
      if MakersPath.RequestUIRefresh then MakersPath.RequestUIRefresh(0.5) end
    end
    if MakersPathFrame and MakersPathFrame:IsShown() then
      QueueRedraw()
    end

  elseif event == "PLAYER_LOGOUT" then
  end
end)

if MakersPath and MakersPath.GearFinder and MakersPath.GearFinder._equippedScoreCache then
  wipe(MakersPath.GearFinder._equippedScoreCache)
end

-- ===================== Character Panel Button =====================
local function _CreateCharPanelButton()
  if not CharacterFrame or not PaperDollFrame then return end
  if MakersPathCharBtn then return end

  local btn = CreateFrame("Button", "MakersPathCharBtn", PaperDollFrame)
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
    if CharacterFrame and PaperDollFrame then
      _CreateCharPanelButton()
    end
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

  local lbl = W.Text(parent.footer, "body", "muted")
  lbl:SetText(L["SPEC_LABEL"] or "Spec")
  lbl:SetPoint("LEFT", parent.optionsBtn, "RIGHT", 14, 0)

  local dd

  local function currentText()
    local cur = CurrentSpec() or ""
    for _, o in ipairs(choices) do
      if o.value == cur then return o.text end
    end
    return "Auto (no override)"
  end

  local function OnSelect(_, arg1)
    SetCurrentSpec(arg1 or "")
    dd:SetText(currentText())
    RebuildCurrentSummaryView()
  end

  local function Initialize(self, level)
    if level ~= 1 then return end
    local cur = CurrentSpec() or ""
    for _, opt in ipairs(choices) do
      local info = LibDD:UIDropDownMenu_CreateInfo()
      info.text    = opt.text
      info.arg1    = opt.value
      info.func    = OnSelect
      info.checked = (cur == (opt.value or ""))
      LibDD:UIDropDownMenu_AddButton(info, 1)
    end
  end

  dd = W.Dropdown(parent.footer, "MakersPathSpecDropdown", Initialize, { minWidth = 60 })
  dd:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
  dd:SetText(currentText())
  parent.specBtn = dd

  parent:HookScript("OnShow", function()
    dd:SetText(currentText())
  end)
end
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("ADDON_LOADED")
  f:SetScript("OnEvent", function(_, ev, addon)
    if ev == "PLAYER_LOGIN" or (ev=="ADDON_LOADED" and addon == ADDON_NAME) then
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
  if MakersPath and MakersPath.UI and MakersPath.UI.Toggle then
    MakersPath.UI.Toggle()
  end
end
-- Reset panel position/size/scale
SLASH_MAKERSPATHRESET1 = "/mpreset"
SlashCmdList["MAKERSPATHRESET"] = function() ResetPanelPosition() end

SLASH_MAKERSPATHSCALE1 = "/mpscale"
SlashCmdList["MAKERSPATHSCALE"] = function(msg)
  local s = tonumber((tostring(msg or ""):gsub(",", ".")))
  if not DB then return end
  if not s or s <= 0 then return end
  ApplyPanelScale(s)
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
    MakersPath.FutureWindow = math.max(0, math.min(60, math.floor(v)))
  else
    print("|cff66ccff["..Ls("ADDON_NAME").."]|r "..Ls("USAGE_MPCAP"))
    return
  end
  if DB and DB.config then DB.config.FUTURE_WINDOW = MakersPath.FutureWindow end
  print("|cff66ccff["..Ls("ADDON_NAME").."]|r "..Ls("FUTUREWINDOW_SET"):format(MakersPath.FutureWindow))
  if MakersPath and MakersPath.GearFinder and MakersPath.GearFinder.MarkDirty then
    MakersPath.GearFinder:MarkDirty()
  end
  if MakersPathFrame and MakersPathFrame:IsShown() then
    RebuildCurrentSummaryView()
  end
end
-- ===================== Simple CPU snapshot =====================
SLASH_MPCPU1 = "/mpcpu"
SlashCmdList["MPCPU"] = function()
  if not GetAddOnCPUUsage then
    print("|cff66ccff[Maker'sPath]|r CPU profiling API not available (scriptProfile off?).")
    return
  end

  UpdateAddOnCPUUsage()

  local num = API.GetNumAddOns()
  local totals = {}

  for i = 1, num do
    local name, _, _, loadable, reason, security = API.GetAddOnInfo(i)
    if name and API.IsAddOnLoaded(i) then
      local cpu = GetAddOnCPUUsage(i) or 0
      totals[#totals+1] = { name = name, cpu = cpu }
    end
  end

  table.sort(totals, function(a, b) return (a.cpu or 0) > (b.cpu or 0) end)

  print("|cff66ccff[Maker'sPath]|r Top addon CPU usage (ms since last reload):")
  for i = 1, math.min(10, #totals) do
    local row = totals[i]
    local mark = (row.name == ADDON_NAME) and "  <-- MakersPath" or ""
    print(string.format("  %2d) %s : %.1f%s", i, row.name, row.cpu or 0, mark))
  end
end