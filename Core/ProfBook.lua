local ADDON, MakersPath = ...
local API = MakersPath.API or {}  -- see Core/Compat.lua
MakersPath = MakersPath or {}
MakersPath.UI = MakersPath.UI or {}

-- ===== Locale & Consts =====
local C = MakersPath.Const or {}
local L = LibStub("AceLocale-3.0"):GetLocale("MakersPath", true) or {}
local function Lx(key, fallback) return rawget(L, key) or fallback or key end

local T, W = MakersPath.Theme, MakersPath.Widgets
local Tex = T.Tex

local SECONDARY = {
  [185] = true,  -- Cooking
  [129] = true,  -- First Aid
  [356] = true,  -- Fishing
}

local function ProfName(line)
  local sp = C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[line]
  return sp and API.GetSpellInfo(sp) or ("#" .. tostring(line))
end
local function ProfIcon(line)
  local sp = C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[line]
  return sp and API.GetSpellTexture and API.GetSpellTexture(sp) or Tex.question
end

local SPELL_TO_LINE = {}
for line, sp in pairs(C.SKILLLINE_TO_SPELL or {}) do SPELL_TO_LINE[sp] = line end

local function CurrentKey()
  return (MakersPath.Util and MakersPath.Util.CurrentCharKey and MakersPath.Util.CurrentCharKey())
      or ((UnitName("player") or "?") .. "-" .. (GetRealmName() or "?"))
end

local function Roster()
  local out = {}
  MakersPathDB = MakersPathDB or {}; MakersPathDB.chars = MakersPathDB.chars or {}
  local cur = CurrentKey()
  for key, rec in pairs(MakersPathDB.chars) do
    if type(rec) == "table" then
      out[#out + 1] = { key = key, rec = rec, name = rec.name or key:match("^[^-]+") or key, current = key == cur }
    end
  end
  table.sort(out, function(a, b)
    if a.current ~= b.current then return a.current end
    return a.key < b.key
  end)
  return out
end

-- =================== Frame ===================
local frame = CreateFrame("Frame", "MakersPathProfBook", UIParent)
frame:SetSize(460, 560)
frame:SetFrameStrata("DIALOG")
frame:SetFrameLevel(50)
frame:SetClampedToScreen(true)
frame:Hide()
frame:EnableMouse(true)
table.insert(UISpecialFrames, "MakersPathProfBook")

local page = W.Window(frame)
W.MakeMovable(frame, frame, function(p, rp, x, y)
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.ui = MakersPathDB.ui or {}
  MakersPathDB.ui.profbook = { point = p, relPoint = rp, x = x, y = y }
end)

local header = W.Header(page, Lx("PROFBOOK_HEADER", "Profession Book"), function() frame:Hide() end)
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function() frame:StartMoving() end)
header:SetScript("OnDragStop", function() frame:GetScript("OnDragStop")(frame) end)
header.count = W.Text(header, "body", "secondary")
header.count:SetPoint("LEFT", header.title, "RIGHT", 10, -1)
frame.header, frame.title = header, header.title

local footer = W.Footer(page)
footer.hint = W.Text(footer, "small", "muted")
footer.hint:SetPoint("LEFT", 10, 0)
footer.hint:SetText(Lx("PROFBOOK_FORGET_HINT", "Shift + right-click a character to remove it"))

-- ============== Scaling (Ctrl + MouseWheel) ==============
local BOOK_MIN_SCALE, BOOK_MAX_SCALE, BOOK_STEP = 0.7, 1.4, 0.05

local function ApplyBookScale(scale)
  scale = tonumber(scale) or 1.0
  scale = math.floor(scale / BOOK_STEP + 0.5) * BOOK_STEP
  scale = math.max(BOOK_MIN_SCALE, math.min(scale, BOOK_MAX_SCALE))
  frame:SetScale(scale)
  MakersPathDB = MakersPathDB or {}; MakersPathDB.ui = MakersPathDB.ui or {}
  MakersPathDB.ui.profbookScale = scale
  return scale
end

local function RestoreBookScale()
  MakersPathDB = MakersPathDB or {}; MakersPathDB.ui = MakersPathDB.ui or {}
  ApplyBookScale(MakersPathDB.ui.profbookScale or 1.0)
end

-- =================== Content ===================
local scroll = CreateFrame("ScrollFrame", nil, page)
scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 8, -8)
scroll:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -8, 6)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(1, 1)
scroll:SetScrollChild(content)
scroll:EnableMouseWheel(true)
local bar = W.ScrollBar(scroll)
local function UpdateThumb() bar:Update() end

frame:EnableMouseWheel(true)
frame:SetScript("OnMouseWheel", function(self, delta)
  if IsControlKeyDown() then
    local cur = (MakersPathDB and MakersPathDB.ui and MakersPathDB.ui.profbookScale) or self:GetScale() or 1.0
    local new = ApplyBookScale(cur + (delta > 0 and BOOK_STEP or -BOOK_STEP))
    UIErrorsFrame:AddMessage(string.format(L["BOOK_SCALE_CHANGED"], new), 0.2, 0.8, 1.0)
    return
  end
  bar:Scroll(delta * 40)
end)

local expanded = {}
local sections = {}

local function Section(i)
  local s = sections[i]
  if s then return s end
  s = CreateFrame("Frame", nil, content)
  s.bg = W.Fill(s, "panel", "BACKGROUND"); s.bg:SetAllPoints()
  s.edge = W.Line(s, "ruleDark", "BORDER"); s.edge:SetPoint("TOPLEFT"); s.edge:SetPoint("TOPRIGHT")
  s.edge2 = W.Line(s, "ruleLight", "BORDER"); s.edge2:SetPoint("BOTTOMLEFT"); s.edge2:SetPoint("BOTTOMRIGHT")
  s.mark = W.Fill(s, "brass", "ARTWORK"); s.mark:SetWidth(2); s.mark:SetPoint("TOPLEFT"); s.mark:SetPoint("BOTTOMLEFT")

  s.head = CreateFrame("Button", nil, s)
  s.head:SetPoint("TOPLEFT"); s.head:SetPoint("TOPRIGHT")
  s.head:SetHeight(36)
  s.head.hl = W.Fill(s.head, "hover", "BACKGROUND", 1); s.head.hl:SetAllPoints(); s.head.hl:Hide()
  s.classIcon = W.ItemIcon(s.head, 24); s.classIcon:SetPoint("LEFT", 10, 0)
  s.name = W.Text(s.head, "name", "bone"); s.name:SetPoint("LEFT", s.classIcon, "RIGHT", 9, 0)
  s.sub = W.Text(s.head, "body", "secondary"); s.sub:SetPoint("LEFT", s.name, "RIGHT", 8, -1)
  s.chev = s.head:CreateTexture(nil, "ARTWORK"); s.chev:SetTexture(Tex.chevron); s.chev:SetSize(9, 9); s.chev:SetPoint("RIGHT", -10, 0)
  s.chev:SetVertexColor(T.C.secondary[1], T.C.secondary[2], T.C.secondary[3])
  s.summary = W.Text(s.head, "body", "muted"); s.summary:SetPoint("RIGHT", s.chev, "LEFT", -8, 0); s.summary:SetJustifyH("RIGHT")
  s.summary:SetPoint("LEFT", s.sub, "RIGHT", 8, 0)
  s.head:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  s.head:SetScript("OnEnter", function(self)
    self.hl:Show()
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    GameTooltip:AddLine(L["ROW_HINT_FORGET"], 1, 1, 1)
    GameTooltip:Show()
  end)
  s.head:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
  s.head:SetScript("OnClick", function(self, button)
    local key = self:GetParent().key
    if button == "RightButton" then
      if not IsShiftKeyDown() then
        UIErrorsFrame:AddMessage(L["ROW_HINT_FORGET_ERR"], 1, 0.82, 0, 1)
        return
      end
      MakersPathDB = MakersPathDB or {}; MakersPathDB.chars = MakersPathDB.chars or {}
      if key and MakersPathDB.chars[key] then
        MakersPathDB.chars[key] = nil
        print("|cff00ccff[Maker's Path]|r " .. string.format(L["REMOVED_FROM_ROSTER"], key))
        MakersPath.UI.RefreshProfBook()
      end
      return
    end
    expanded[key] = not expanded[key]
    MakersPath.UI.RefreshProfBook()
  end)

  s.rows = {}
  s.secondary = W.Text(s, "body", "muted")
  sections[i] = s
  return s
end

local function ProfRow(s, i)
  local r = s.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, s)
  r:SetHeight(24)
  r.icon = W.ItemIcon(r, 18); r.icon:SetPoint("LEFT", 44, 0)
  r.name = W.Text(r, "body", "bone"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0); r.name:SetWidth(110)
  r.rank = W.Text(r, "num", "bone"); r.rank:SetPoint("LEFT", r.name, "RIGHT", 6, 0); r.rank:SetWidth(70)
  r.note = W.Text(r, "small", "muted"); r.note:SetPoint("LEFT", r.rank, "RIGHT", 6, 0); r.note:SetPoint("RIGHT", -10, 0)
  s.rows[i] = r
  return r
end

-- =================== Refresh ===================
function MakersPath.UI.RefreshProfBook()
  local roster = Roster()
  header.count:SetText(string.format(Lx("PROFBOOK_COUNT_FMT", "%d |4character:characters;"), #roster))
  local width = scroll:GetWidth() or 420
  content:SetWidth(width)
  for _, s in ipairs(sections) do s:Hide() end
  local cur = CurrentKey()
  local y = 0
  for i, e in ipairs(roster) do
    local s = Section(i)
    s.key = e.key
    if expanded[e.key] == nil then expanded[e.key] = (#roster <= 4) or e.current end
    local open = expanded[e.key]
    local rec = e.rec
    local cc = T.ClassColor(rec.class)

    local path, coords
    if API.ClassIcon then path, coords = API.ClassIcon(rec.class) end
    if path then
      s.classIcon.icon:SetTexture(path)
      s.classIcon.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
      s.classIcon.icon:SetTexture(Tex.question)
      s.classIcon.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    for _, edge in ipairs(s.classIcon.edges) do W.SetColor(edge, cc) end

    s.name:SetText(e.name); W.TextColor(s.name, cc)
    local className = rec.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[rec.class] or (rec.class or "")
    s.sub:SetText(rec.level and string.format(Lx("HEADER_LEVEL_FMT", "Level %d %s"), rec.level, className) or className)
    s.mark:SetShown(e.key == cur)
    if s.chev.SetRotation then s.chev:SetRotation(open and 0 or (math.pi / 2)) end

    -- professions
    local main, sec = {}, {}
    for sp, rank in pairs(rec.profs or {}) do
      local line = SPELL_TO_LINE[sp]
      rank = tonumber(rank) or 0
      if line and rank > 0 then
        if SECONDARY[line] then sec[#sec + 1] = { line = line, rank = rank }
        else main[#main + 1] = { line = line, rank = rank } end
      end
    end
    table.sort(main, function(a, b) return a.rank > b.rank end)
    table.sort(sec, function(a, b) return a.rank > b.rank end)
    local secText = {}
    for _, p in ipairs(sec) do secText[#secText + 1] = ProfName(p.line) .. " " .. p.rank end

    if open then
      s.summary:SetText(e.current and Lx("PROFBOOK_THIS_CHAR", "this character") or "")
    else
      local parts = {}
      for _, p in ipairs(main) do parts[#parts + 1] = ProfName(p.line) .. " " .. p.rank end
      if #parts > 0 then
        s.summary:SetText(table.concat(parts, " · "))
      elseif #sec > 0 then
        s.summary:SetText(Lx("PROFBOOK_NO_PRIMARY", "No primary professions"))
      else
        s.summary:SetText(Lx("NO_PROFS", "No professions recorded"))
      end
    end

    for _, r in ipairs(s.rows) do r:Hide() end
    local h = 36
    if open then
      for k, p in ipairs(main) do
        local r = ProfRow(s, k)
        r.icon:Set(ProfIcon(p.line), T.C.buttonEdge)
        r.icon:Show()
        r.name:SetText(ProfName(p.line))
        r.rank:SetText(T.Wrap("bone", tostring(p.rank)))
        local crafting = p.line == 164 or p.line == 165 or p.line == 197 or p.line == 202 or p.line == 755 or p.line == 171 or p.line == 333
        local n = crafting and MakersPath.RecipeInfo and MakersPath.RecipeInfo.KnownCount(p.line, e.key)
        if not crafting then
          r.note:SetText("")
        elseif n then
          r.note:SetText(string.format(Lx("PROFBOOK_KNOWN_FMT", "%d recipes known"), n)); W.TextColor(r.note, "muted")
        else
          r.note:SetText(string.format(Lx("PROFBOOK_OPEN_FMT", "open %s once to record recipes"), ProfName(p.line))); W.TextColor(r.note, "amber")
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -(h + (k - 1) * 24)); r:SetPoint("RIGHT")
        r:Show()
      end
      h = h + #main * 24
      if #main == 0 then
        s.empty = s.empty or W.Text(s, "body", "muted")
        s.empty:ClearAllPoints()
        s.empty:SetPoint("TOPLEFT", 44, -(h + 4))
        s.empty:SetPoint("RIGHT", -10, 0)
        s.empty:SetText(#sec > 0 and Lx("PROFBOOK_NO_PRIMARY", "No primary professions") or Lx("NO_PROFS", "No professions recorded"))
        s.empty:Show()
        h = h + 24
      elseif s.empty then
        s.empty:Hide()
      end
      if #secText > 0 then
        s.secondary:ClearAllPoints()
        s.secondary:SetPoint("TOPLEFT", 44, -(h + 2))
        s.secondary:SetPoint("RIGHT", -10, 0)
        s.secondary:SetText(T.Wrap("secondary", Lx("PROFBOOK_SECONDARY", "Secondary") .. ":") .. "  " .. table.concat(secText, " · "))
        s.secondary:Show()
        h = h + 20
      else
        s.secondary:Hide()
      end
      h = h + 6
    else
      s.secondary:Hide()
      if s.empty then s.empty:Hide() end
    end

    s:SetHeight(h)
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    s:SetPoint("RIGHT", content, "RIGHT", -14, 0)
    s:Show()
    y = y + h + 6
  end
  content:SetHeight(math.max(1, y))
  UpdateThumb()
end

function MakersPath.UI.ToggleProfBook()
  if frame:IsShown() then frame:Hide() else MakersPath.UI.RefreshProfBook(); frame:Show() end
end

local function RestorePos()
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.ui = MakersPathDB.ui or {}

  local pos = MakersPathDB.ui.profbook
  frame:ClearAllPoints()

  if pos and pos.point then
    frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
  else
    frame:SetPoint("CENTER")
  end
end

-- Buttons
local rescan = W.Button(footer, L["BTN_RESCAN"], function()
  if MakersPath.ScanProfessions then
    MakersPath.ScanProfessions(MakersPath.UI.RefreshProfBook)
  else
    MakersPath.UI.RefreshProfBook()
  end
end, { primary = true })
rescan:SetPoint("RIGHT", -8, 0)
footer.hint:SetPoint("RIGHT", rescan, "LEFT", -8, 0)

frame:SetScript("OnShow", function() MakersPath.UI.RefreshProfBook() end)

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
  local v = tonumber((tostring(msg or ""):gsub(",", ".")))
  if not v then
    local cur = (MakersPathDB and MakersPathDB.ui and MakersPathDB.ui.profbookScale) or (frame:GetScale() or 1.0)
    print(string.format(L["BOOK_SCALE_USAGE"], 0.70, 1.40, cur))
    return
  end
  print(string.format(L["BOOK_SCALE_SET"], ApplyBookScale(v)))
end
