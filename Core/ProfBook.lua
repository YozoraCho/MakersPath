local ADDON, MakersPath = ...
MakersPath = MakersPath or {}
MakersPath.UI = MakersPath.UI or {}

-- ===== Locale & Consts =====
local C = MakersPath.Const or {}
local L = LibStub("AceLocale-3.0"):GetLocale("MakersPath")

-- =================== Styling ===================
local NAME_W       = 180
local ROWS         = 12
local ROW_H        = 22
local LEVEL_COL_W  = 52
local GAP_BETWEEN  = 8

local function SetReadableFont(fs, size)
  local ok = fs:SetFont(STANDARD_TEXT_FONT, size or 13, "OUTLINE")
  fs:SetShadowOffset(0.75, -0.75)
  fs:SetShadowColor(0, 0, 0, 0.6)
  return ok
end

local HIDE_IN_BOOK = {
  [2550] = true,  -- Cooking
  [3273] = true,  -- First Aid
  [7620] = true,  -- Fishing
}

local PROF_COLOR = {
  Tail = "ffc8e0ff",  -- light blue
  Ench = "ffd0b0ff",  -- light purple/pink
  Alc  = "ffb0ffb0",  -- light green
  LW   = "ffffe0a0",  -- sand
  BS   = "ffffc0c0",  -- rosy
  Eng  = "fff0e090",  -- amber
  Herb = "ffa0ffb0",  -- mint
  Mine = "ffd0d0d0",  -- steel
  Skin = "ffffe8c0",  -- leather
}

local SHORT_TAG_BY_SPELL = {
  [C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[165] or 2108] = "LW",
  [C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[164] or 2018] = "BS",
  [C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[202] or 4036] = "Eng",
  [C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[333] or 7411] = "Ench",
  [C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[197] or 3908] = "Tail",
  [C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[171] or 2259] = "Alc",
  [C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[182] or 2366] = "Herb",
  [C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[186] or 2575] = "Mine",
  [C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[393] or 8613] = "Skin",
  [C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[185] or 2550] = "Cook",
  [C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[356] or 7620] = "Fish",
  [C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[129] or 3273] = "FA",
}

local SHORT_PROF_FROM_SPELL = setmetatable({}, {
  __index = function(t, spellID)
    local short = SHORT_TAG_BY_SPELL[spellID]
    if not short then
      short = GetSpellInfo(spellID) or "?"
    end
    rawset(t, spellID, short)
    return short
  end
})

local function ColorizeProf(short, rank)
  local hex = PROF_COLOR[short] or "ffeaeaea"
  return string.format("|c%s%s %d|r", hex, short, rank or 0)
end

local function ClassColored(class)
  if not class or class == "" then return "" end
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class:upper()]
  if c then
    return string.format("|cFF%02X%02X%02X%s|r", c.r*255, c.g*255, c.b*255, class)
  end
  return class
end

local function FallbackGetAllChars()
  local roster = {}
  MakersPathDB = MakersPathDB or {}; MakersPathDB.chars = MakersPathDB.chars or {}
  for key, rec in pairs(MakersPathDB.chars) do
    local name = key:match("^[^-]+") or key
    roster[#roster+1] = {
      key   = key,
      name  = name,
      level = rec.level,
      class = rec.class,
      profs = rec.profs or {},
    }
  end
  table.sort(roster, function(a,b) return a.key < b.key end)
  return roster
end
local GetAllChars = (MakersPath.Util and MakersPath.Util.GetAllChars) or FallbackGetAllChars

-- =================== Frame ===================
local frame = CreateFrame("Frame", "MakersPathProfBook", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(540, 360)
frame:SetFrameStrata("DIALOG")
frame:SetFrameLevel(50)
frame:SetClampedToScreen(true)
frame:Hide()

do
  local bg = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  bg:SetAllPoints(true)
  bg:SetFrameLevel(frame:GetFrameLevel() - 1)
  bg:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
end

-- Title
frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
if frame.TitleBg then
  frame.title:SetPoint("TOPLEFT", frame.TitleBg, "TOPLEFT", 6, 0)
  frame.title:SetPoint("BOTTOMRIGHT", frame.TitleBg, "BOTTOMRIGHT", -6, 0)
else
  frame.title:SetPoint("TOP", frame, "TOP", 0, -10)
end
frame.title:SetJustifyH("CENTER")
frame.title:SetText(L["PROFBOOK_TITLE"])
SetReadableFont(frame.title, 14)

-- Movable + remember position
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  MakersPathDB = MakersPathDB or {}; MakersPathDB.ui = MakersPathDB.ui or {}
  local p, _, rp, x, y = self:GetPoint(1)
  MakersPathDB.ui.profbook = { point=p, relPoint=rp, x=x, y=y }
end)
local function RestorePos()
  MakersPathDB = MakersPathDB or {}; MakersPathDB.ui = MakersPathDB.ui or {}
  local pos = MakersPathDB.ui.profbook
  frame:ClearAllPoints()
  if pos and pos.point then
    frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
  else
    frame:SetPoint("CENTER")
  end
end

-- ============== Scaling (Ctrl + MouseWheel) ==============
local BOOK_MIN_SCALE, BOOK_MAX_SCALE, BOOK_STEP = 0.7, 1.4, 0.05

local function ApplyBookScale(scale)
  scale = tonumber(scale) or 1.0
  scale = math.max(BOOK_MIN_SCALE, math.min(scale, BOOK_MAX_SCALE))
  frame:SetScale(scale)
  MakersPathDB = MakersPathDB or {}; MakersPathDB.ui = MakersPathDB.ui or {}
  MakersPathDB.ui.profbookScale = scale
end

local function RestoreBookScale()
  MakersPathDB = MakersPathDB or {}; MakersPathDB.ui = MakersPathDB.ui or {}
  ApplyBookScale(MakersPathDB.ui.profbookScale or 1.0)
end

ApplyBookScale(1.0)

frame:EnableMouseWheel(true)
frame:HookScript("OnMouseWheel", function(self, delta)
  if not IsControlKeyDown() then return end
  local cur = (MakersPathDB and MakersPathDB.ui and MakersPathDB.ui.profbookScale) or self:GetScale() or 1.0
  local new = cur + (delta > 0 and BOOK_STEP or -BOOK_STEP)
  ApplyBookScale(new)
  UIErrorsFrame:AddMessage(string.format(L["BOOK_SCALE_CHANGED"], new), 0.2, 0.8, 1.0)
end)

function MakersPath.UI.ToggleProfBook()
  if frame:IsShown() then frame:Hide() else MakersPath.UI.RefreshProfBook(); frame:Show() end
end

-- =================== Content ===================
local content = CreateFrame("Frame", nil, frame)
content:SetPoint("TOPLEFT", 10, -40)
content:SetPoint("BOTTOMRIGHT", -10, 40)

local scroll = CreateFrame("ScrollFrame", nil, content, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT")
scroll:SetPoint("BOTTOMRIGHT")

local rows = {}
local dataset = {}

local function createRow(i)
  local row = CreateFrame("Frame", nil, content)
  row:SetSize(1, ROW_H)
  if i == 1 then
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  else
    row:SetPoint("TOPLEFT", rows[i-1], "BOTTOMLEFT", 0, -2)
  end
  row:SetPoint("RIGHT", content, "RIGHT")

  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.name:SetPoint("LEFT", row, "LEFT", 6, 0)
  row.name:SetWidth(NAME_W)
  row.name:SetJustifyH("LEFT")
  SetReadableFont(row.name, 13)

  row.level = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.level:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
  row.level:SetWidth(LEVEL_COL_W)
  row.level:SetJustifyH("LEFT")
  row.level:SetWordWrap(false)
  row.level:SetNonSpaceWrap(false)
  row.level:SetMaxLines(1)
  SetReadableFont(row.level, 13)

  row.class = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.class:ClearAllPoints()
  row.class:SetPoint("LEFT", row.level, "RIGHT", GAP_BETWEEN, 0)
  row.class:SetJustifyH("LEFT")
  row.class:SetWordWrap(false)
  row.class:SetNonSpaceWrap(true)
  row.class:SetMaxLines(1)
  SetReadableFont(row.class, 13)

  row.profs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.profs:SetPoint("LEFT", row.class, "RIGHT", 12, 0)
  row.profs:SetPoint("RIGHT", row, "RIGHT", -6, 0)
  row.profs:SetJustifyH("LEFT")
  row.profs:SetWordWrap(false)
  row.profs:SetNonSpaceWrap(true)
  row.profs:SetMaxLines(1)
  SetReadableFont(row.profs, 12)

  row.btn = CreateFrame("Button", nil, row)
  row.btn:SetAllPoints(row)
  row.btn:EnableMouse(true)
  row.btn:RegisterForClicks("RightButtonUp")

  row.btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:AddLine(L["ROW_HINT_FORGET"], 1, 1, 1)
    GameTooltip:Show()
  end)
  row.btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  row.btn:SetScript("OnClick", function()
    if not IsShiftKeyDown() then
      UIErrorsFrame:AddMessage(L["ROW_HINT_FORGET_ERR"], 1, 0.82, 0, 1)
      return
    end
    if row._key then
      MakersPathDB = MakersPathDB or {}; MakersPathDB.chars = MakersPathDB.chars or {}
      if MakersPathDB.chars[row._key] then
        MakersPathDB.chars[row._key] = nil
        print("|cff00ccff[Maker's Path]|r " .. string.format(L["REMOVED_FROM_ROSTER"], row._key))
        MakersPath.UI.RefreshProfBook()
      end
    end
  end)

  return row
end

for i=1,ROWS do rows[i] = createRow(i) end

-- =================== Refresh ===================
function MakersPath.UI.RefreshProfBook()
  local dataset = GetAllChars() or {}
  local total   = #dataset
  local offset  = FauxScrollFrame_GetOffset(scroll)

  for i = 1, ROWS do
    local r = rows[i]
    if not r then
      r = createRow(i)
      rows[i] = r
    end

    local idx = offset + i
    if idx <= total then
      local rec = dataset[idx]
      r:Show()
      r._key = rec.key
      r.name:SetText(rec.name or rec.key or "?")
      r.level:SetText(rec.level and (L["LEVEL_PREFIX"] .. " " .. tostring(rec.level)) or "")
      r.class:SetText(ClassColored(rec.class))

      local parts = {}
      for spellID, rank in pairs(rec.profs or {}) do
        if not HIDE_IN_BOOK[spellID] then
          local short = SHORT_PROF_FROM_SPELL[spellID]
          parts[#parts+1] = ColorizeProf(short, tonumber(rank) or 0)
        end
      end
      table.sort(parts, function(a,b) return a < b end)
      if #parts > 0 then
        r.profs:SetText(table.concat(parts, "  |  "))
      else
        r.profs:SetText("|cff888888" .. L["NO_PROFS"] .. "|r")
      end
    else
      r:Hide()
    end
  end

  FauxScrollFrame_Update(scroll, total, ROWS, ROW_H+2)
end

scroll:SetScript("OnVerticalScroll", function(self, delta)
  FauxScrollFrame_OnVerticalScroll(self, delta, ROW_H+2, MakersPath.UI.RefreshProfBook)
end)

-- Buttons
local rescan = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
rescan:SetSize(120, 22)
rescan:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
rescan:SetText(L["BTN_RESCAN"])
rescan:SetScript("OnClick", function()
  if MakersPath.ScanProfessions then MakersPath.ScanProfessions() end
  MakersPath.UI.RefreshProfBook()
end)

local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
close:SetSize(80, 22)
close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
close:SetText(L["BTN_CLOSE"])
close:SetScript("OnClick", function() frame:Hide() end)

do
  local ef = CreateFrame("Frame")
  ef:RegisterEvent("ADDON_LOADED")
  ef:SetScript("OnEvent", function(_, ev, name)
    if ev == "ADDON_LOADED" and name == ADDON then
      RestoreBookScale()
      RestorePos()
    end
  end)
end

-- Slash
SLASH_MPBOOK1 = "/mpbook"
SlashCmdList["MPBOOK"] = function() MakersPath.UI.ToggleProfBook() end

SLASH_MPBOOKSCALE1 = "/mpbookscale"
SlashCmdList["MPBOOKSCALE"] = function(msg)
  local v = tonumber(msg)
  if not v then
    local cur = (MakersPathDB and MakersPathDB.ui and MakersPathDB.ui.profbookScale) or (frame:GetScale() or 1.0)
    print(string.format(L["BOOK_SCALE_USAGE"], 0.70, 1.40, cur))
    return
  end
  ApplyBookScale(v)
  print(string.format(L["BOOK_SCALE_SET"], v))
end