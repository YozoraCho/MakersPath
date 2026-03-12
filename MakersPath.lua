local ADDON_NAME, MakersPath = ...

MakersPath = MakersPath or {}
MakersPath.name = ADDON_NAME
MakersPath.version = "1.4.4"
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

function MakersPath.Util.CharKey(name, realm)
  name = name or UnitName("player") or "?"
  realm = realm or GetRealmName() or "?"
  return name .."-".. realm
end

function MakersPath.Util.CurrentCharKey()
  return MakersPath.Util.CharKey()
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
panel:SetBackdrop({
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = false,
  edgeSize = 12,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
panel:SetBackdropColor(0, 0, 0, 0.8)
panel:SetBackdropBorderColor(0.3, 0.1, 0.1, 0.85)

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

-- Top header strip
panel.header = CreateFrame("Frame", nil, panel, "BackdropTemplate")
panel.header:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
panel.header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
panel.header:SetHeight(28)
panel.header:SetBackdrop({
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = false,
  edgeSize = 12,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
panel.header:SetBackdropColor(0.12, 0.12, 0.16, 0.95)
panel.header:SetBackdropBorderColor(0.28, 0.28, 0.34, 0.9)

-- Title
panel.title = panel.header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
panel.title:SetPoint("LEFT", panel.header, "LEFT", 10, 0)
panel.title:SetJustifyH("LEFT")
panel.title:SetText(L["ADDON_NAME"])

-- Close button
panel.close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
panel.close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)

-- Status line
panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
panel.status:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -42)
panel.status:SetText((L["INDEXED_CRAFTABLES_FMT"] or "Indexed Craftables: %d"):format(0))

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
  DB.size = { w=MIN_W, h=MIN_H }
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
    if not (MakersPathFrame and MakersPathFrame:IsShown()) then
      return
    end
    RebuildCurrentSummaryView()
  end)
end

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
  Finger0Slot       = (_G.INVTYPE_FINGER or L["RING"]) .. " 1",
  Finger1Slot       = (_G.INVTYPE_FINGER or L["RING"]) .. " 2",
  Trinket0Slot      = (_G.INVTYPE_TRINKET or L["TRINKET"]) .. " 1",
  Trinket1Slot      = (_G.INVTYPE_TRINKET or L["TRINKET"]) .. " 2",
  MainHandSlot      = _G.MAINHANDSLOT or L["MAIN_HAND"],
  SecondaryHandSlot = _G.SECONDARYHANDSLOT or L["OFF_HAND"],
  RangedSlot        = _G.RANGEDSLOT or L["RANGED"],
  AmmoSlot          = _G.AMMOSLOT or L["AMMO"],
}

local LEFT_SLOTS = {
  "HeadSlot",
  "NeckSlot",
  "ShoulderSlot",
  "BackSlot",
  "ChestSlot",
  "WristSlot",
  "HandsSlot",
  "WaistSlot",
}

local RIGHT_SLOTS = {
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

local slotWidgets = {}

local function ProfShort(id)
  if id == 164 then return L["BS"] or "BS"
  elseif id == 165 then return L["LW"] or "LW"
  elseif id == 197 then return L["Tailor"] or "Tailor"
  elseif id == 202 then return L["Eng"] or "Eng"
  elseif id == 333 then return L["Ench"] or "Ench"
  elseif id == 755 then return L["JC"] or "JC"
  elseif id == 171 then return L["Alc"] or "Alc"
  else return tostring(id or "?") end
end

local function GetSummaryBySlot()
  local finder = GF()
  if not finder then return {} end

  local activeKey = MakersPath.UI.ActiveProfileKey
  local thisKey   = MakersPath.Util.CurrentCharKey()
  local summary

  if not activeKey or activeKey == thisKey then
    if finder.BeginSession then
      finder:BeginSession()
    end

    summary = finder._lastSummary or {}

    if (not summary or #summary == 0) and finder.BuildSummary then
      summary = finder:BuildSummary() or {}
      finder._lastSummary = summary
    end
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

local function RebuildCurrentSummaryView()
  local finder = GF()
  if not finder then return end

  local activeKey = MakersPath.UI.ActiveProfileKey
  local thisKey = MakersPath.Util.CurrentCharKey()

  if activeKey and activeKey ~= thisKey then
    if RefreshList then RefreshList() end
    return
  end

  if finder._isBuildingSummary then
    return
  end

  if finder.InvalidateSummary then
    finder:InvalidateSummary()
  else
    finder._summaryDirty = true
    finder._lastSummary = nil
    finder._equippedScoreCache = nil
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

local function CreateSlotWidget(parent, side, slotName, index)
  local wrap = CreateFrame("Frame", nil, parent)
  wrap:SetSize(250, 42)

  local topY = -74 - ((index - 1) * 40)

  if side == "LEFT" then
    wrap:SetPoint("TOPLEFT", parent, "TOPLEFT", 70, topY)
  else
    wrap:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -26, topY)
  end

  wrap.iconBtn = CreateFrame("Button", nil, wrap, "BackdropTemplate")
  wrap.iconBtn:SetSize(34, 34)
  wrap.iconBtn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  wrap.iconBtn:SetBackdropColor(0, 0, 0, 0.55)
  wrap.iconBtn:SetBackdropBorderColor(0.55, 0.12, 0.12, 0.9)

  wrap.icon = wrap.iconBtn:CreateTexture(nil, "ARTWORK")
  wrap.icon:SetPoint("TOPLEFT", 3, -3)
  wrap.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  wrap.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  if side == "LEFT" then
    wrap.iconBtn:SetPoint("LEFT", wrap, "LEFT", 0, 0)
  else
    wrap.iconBtn:SetPoint("LEFT", wrap, "LEFT", 0, 0)
  end

  wrap.name = wrap:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  wrap.name:SetPoint("TOPLEFT", wrap.iconBtn, "TOPRIGHT", 8, -2)
  wrap.name:SetWidth(190)
  wrap.name:SetJustifyH("LEFT")

  wrap.meta = wrap:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  wrap.meta:SetPoint("TOPLEFT", wrap.name, "BOTTOMLEFT", 0, -1)
  wrap.meta:SetWidth(190)
  wrap.meta:SetJustifyH("LEFT")

  wrap.slotLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  wrap.slotLabel:SetWidth(72)
  wrap.slotLabel:SetText(SLOT_LABEL[slotName] or slotName)

  if side == "LEFT" then
    wrap.slotLabel:SetJustifyH("RIGHT")
    wrap.slotLabel:SetPoint("RIGHT", wrap, "LEFT", -8, 0)
  else
    wrap.slotLabel:SetJustifyH("CENTER")
    wrap.slotLabel:SetPoint("RIGHT", wrap, "LEFT", -8, 0)
  end

  wrap.iconBtn:SetScript("OnEnter", function(btn)
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

  wrap.iconBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  wrap.iconBtn:RegisterForClicks("AnyUp")
  wrap.iconBtn:SetScript("OnClick", function(btn)
    local id = btn.itemID
    if not id then return end
    local link = select(2, GetItemInfo(id))
    if not link then
      if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(id)
      end
      return
    end

    if IsModifiedClick("DRESSUP") then
      DressUpItemLink(link)
    elseif IsModifiedClick("CHATLINK") then
      ChatEdit_InsertLink(link)
    end
  end)

  slotWidgets[slotName] = wrap
  return wrap
end

for i, slotName in ipairs(LEFT_SLOTS) do
  CreateSlotWidget(panel, "LEFT", slotName, i)
end

for i, slotName in ipairs(RIGHT_SLOTS) do
  CreateSlotWidget(panel, "RIGHT", slotName, i)
end

local function ResolveRequiredLevel(iid2, fallback)
  if not iid2 then return fallback or 0 end
  local _, _, _, _, reqLevel = GetItemInfo(iid2)
  if type(reqLevel) == "number" then return reqLevel end
  return fallback or 0
end

local function RenderSlot(slotName, data)
  local w = slotWidgets[slotName]
  if not w then return end

  local best = data and data.best or nil
  if not best then
    w.icon:SetTexture("Interface\\ICONS\\INV_Misc_QuestionMark")
    w.iconBtn.itemID = nil
    w.name:SetText("|cffbbbbbb" .. (L["NO_CRAFT_UPGRADE"] or "No upgrade found") .. "|r")
    w.meta:SetText("")
    return
  end

  local iid = best.itemID
  local link = iid and select(2, GetItemInfo(iid)) or nil
  local shown = link or (best.name or L["ITEM_ID_FMT"]:format(iid or 0))
  w.name:SetText(shown)

  local icon = iid and GetItemIcon(iid) or "Interface\\ICONS\\INV_Misc_QuestionMark"
  w.icon:SetTexture(icon)
  w.iconBtn.itemID = iid

  local prof  = ProfShort(best.__profId or best.reqSkill)
  local need  = tonumber(best.__needRank or best.reqSkillLevel or 0) or 0
  local have  = tonumber(best.__haveRank or 0) or 0
  local delta = math.max(0, need - have)
  local reqL  = ResolveRequiredLevel(iid, tonumber(best.reqLevel or 0) or 0)

  local meta = "|cffff6666" .. prof .. "|r " .. need
  if delta > 0 then
    meta = meta .. "  |cffffff88+" .. delta .. "|r"
  end
  if reqL > 0 then
    meta = meta .. "  |cffaaaaaaLv " .. reqL .. "|r"
  end

  w.meta:SetText(meta)

  if iid and not link and C_Item and C_Item.RequestLoadItemDataByID then
    C_Item.RequestLoadItemDataByID(iid)
  end
end

RefreshList = function()
  local bySlot = GetSummaryBySlot()

  for _, slotName in ipairs(LEFT_SLOTS) do
    RenderSlot(slotName, bySlot[slotName])
  end
  for _, slotName in ipairs(RIGHT_SLOTS) do
    RenderSlot(slotName, bySlot[slotName])
  end
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

local profileLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
profileLabel:SetText(L["PROFILE_LABEL"])

local profileDrop = CreateFrame("Frame", "MakersPathProfileDropdown", panel, "UIDropDownMenuTemplate")
UIDropDownMenu_SetWidth(profileDrop, 120)

do
  local name   = profileDrop:GetName()
  local left   = _G[name.."Left"]
  local mid    = _G[name.."Middle"]
  local right  = _G[name.."Right"]
  local button = _G[name.."Button"]
  local text   = _G[name.."Text"]

  if left  then left:Hide() end
  if mid   then mid:Hide() end
  if right then right:Hide() end

  if text then
    text:ClearAllPoints()
    text:SetPoint("LEFT", profileDrop, "LEFT", 8, 0)
    text:SetFontObject(GameFontDisableSmall)
    text:SetTextColor(0.75, 0.75, 0.75)
  end
  if button then
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", profileDrop, "TOPRIGHT", 0, 0)
    button:SetPoint("BOTTOMLEFT", profileDrop, "BOTTOMLEFT", 0, 0)
  end
end

profileDrop:ClearAllPoints()
profileDrop:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -32, -28)

profileLabel:ClearAllPoints()
profileLabel:SetPoint("RIGHT", profileDrop, "LEFT", -8, 2)

local function SetActiveProfile(key)
  MakersPath.UI.ActiveProfileKey = key
  UIDropDownMenu_SetText(profileDrop, MakersPath.UI.CurrentProfileText())

  if not MakersPathFrame:IsShown() then
    return
  end

  local thisKey = MakersPath.Util.CurrentCharKey()
  if not key or key == thisKey then
    RebuildCurrentSummaryView()
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
    local info = UIDropDownMenu_CreateInfo()
    info.text         = L["PROFILE_ACTIVE"]
    info.func         = function() SetActiveProfile(nil) end
    info.checked      = (not active or active == thisKey)
    info.notCheckable = false
    UIDropDownMenu_AddButton(info, level)
  end
  if #roster > 0 then
    local sep = UIDropDownMenu_CreateInfo()
    sep.isTitle      = true
    sep.notCheckable = true
    sep.text         = L["PROFILE_ALT"]
    UIDropDownMenu_AddButton(sep, level)
  end
  for _, row in ipairs(roster) do
    local info = UIDropDownMenu_CreateInfo()
    info.text         = row.label
    info.arg1         = row.key
    info.notCheckable = false
    info.checked      = (active == row.key)
    info.func = function(_, key)
      SetActiveProfile(key)
    end
    UIDropDownMenu_AddButton(info, level)
  end
end

UIDropDownMenu_Initialize(profileDrop, ProfileDrop_Init)
UIDropDownMenu_SetText(profileDrop, MakersPath.UI.CurrentProfileText())

MakersPathFrame:HookScript("OnShow", function()
  UIDropDownMenu_SetText(profileDrop, MakersPath.UI.CurrentProfileText())
end)

-- Refresh Button
local refreshBtn = CreateFrame("Button", nil, MakersPathFrame, "UIPanelButtonTemplate")
refreshBtn:SetSize(90, 22)
refreshBtn:SetPoint("BOTTOMRIGHT", MakersPathFrame, "BOTTOMRIGHT", -12, 12)
refreshBtn:SetText(L["BTN_REFRESH"])
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
  local finder = GF()
  if finder and finder.BeginSession then
    finder:BeginSession()
  end

  local count = finder and finder.GetIndexedCount and finder:GetIndexedCount() or 0
  if MakersPathFrame.status then
    MakersPathFrame.status:SetText(L["INDEXED_CRAFTABLES_FMT"]:format(count))
  end

  UpdateEmptyHint()

  if finder and finder._lastSummary and RefreshList then
    RefreshList()
  end

  if finder and finder.BuildSummaryAsync then
    finder:BuildSummaryAsync(
      function(rows)
        if MakersPathFrame and MakersPathFrame:IsShown() and RefreshList then
          finder._lastSummary = rows
          RefreshList()
        end
      end,
      function(rows)
        if MakersPathFrame and MakersPathFrame:IsShown() and RefreshList then
          finder._lastSummary = rows
          RefreshList()
        end
      end
    )
  else
    SafeRefresh(0.10)
  end
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
    RestorePanelPosition()

  elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    if GF() and GF().BeginSession then GF():BeginSession() end
    if GF() and GF().MarkDirty then GF():MarkDirty() end
    if GF() and GF().InvalidateKnownSpellNames then GF():InvalidateKnownSpellNames() end
    if MakersPath.ScanProfessions then MakersPath.ScanProfessions() end
    RefreshStatus()
    UpdateEmptyHint()

  elseif event == "SKILL_LINES_CHANGED"
      or event == "TRADE_SKILL_SHOW" then
    if GF() and GF().BeginSession then GF():BeginSession() end
    if GF() and GF().MarkDirty then GF():MarkDirty() end
    if GF() and GF().InvalidateKnownSpellNames then GF():InvalidateKnownSpellNames() end
    RefreshStatus()
    UpdateEmptyHint()
    RebuildCurrentSummaryView()

  elseif event == "PLAYER_EQUIPMENT_CHANGED"
      or event == "PLAYER_LEVEL_UP" then
    if GF() and GF().BeginSession then GF():BeginSession() end
    if GF() and GF().MarkDirty then GF():MarkDirty() end
    RefreshStatus()
    UpdateEmptyHint()
    RebuildCurrentSummaryView()

  elseif event == "GET_ITEM_INFO_RECEIVED" then
    if MakersPathFrame and MakersPathFrame:IsShown() and RefreshList then
      RefreshList()
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

  local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lbl:SetText("Spec:")
  lbl:SetPoint("LEFT", profBookBtn, "RIGHT", 8, 0)

  local dd = CreateFrame("Frame", "MakersPathSpecDropdown", parent, "UIDropDownMenuTemplate")
  dd:SetPoint("LEFT", lbl, "RIGHT", 4, -2)
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
    RebuildCurrentSummaryView()
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

  local num = GetNumAddOns()
  local totals = {}

  for i = 1, num do
    local name, _, _, loadable, reason, security = GetAddOnInfo(i)
    if name and IsAddOnLoaded(i) then
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