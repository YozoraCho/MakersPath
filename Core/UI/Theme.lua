local _, MakersPath = ...
MakersPath = MakersPath or {}

local T = {}
MakersPath.Theme = T

T.ART = "Interface\\AddOns\\MakersPath\\Art\\UI\\"

local function rgb(hex, a)
  hex = hex:gsub("#", "")
  return {
    tonumber(hex:sub(1, 2), 16) / 255,
    tonumber(hex:sub(3, 4), 16) / 255,
    tonumber(hex:sub(5, 6), 16) / 255,
    a or 1,
    hex = "ff" .. hex:lower(),
  }
end

T.C = {
  leather    = rgb("#2a1b12"),
  page       = rgb("#1b1713"),
  bar        = rgb("#1f1a15"),   -- header and footer
  rail       = rgb("#13100d"),
  well       = rgb("#090706"),
  panel      = rgb("#16120f"),   -- recessed boxes inside the page
  hover      = rgb("#241d16"),
  selected   = rgb("#221b14"),
  ruleDark   = rgb("#0a0806"),
  ruleLight  = rgb("#2d251c"),
  edgeLight  = rgb("#3a3024"),
  trail      = rgb("#3d3226"),
  trailOn    = rgb("#8a6d3e"),
  trailHot   = rgb("#c19a5e"),
  button     = rgb("#241d16"),
  buttonEdge = rgb("#4d3f2a"),
  brass      = rgb("#c19a5e"),
  brassLight = rgb("#dcc08a"),
  brassDark  = rgb("#8a6d3e"),
  bone       = rgb("#ece3cf"),
  secondary  = rgb("#c2b69c"),
  muted      = rgb("#a99d86"),
  faint      = rgb("#6e6455"),
  amber      = rgb("#e8a85c"),
  loss       = rgb("#d98a7e"),
  tipGold    = rgb("#ffd100"),
  tipGrey    = rgb("#8f8fa3"),
}

local FALLBACK_Q = {
  [0] = rgb("#9d9d9d"), [1] = rgb("#ffffff"), [2] = rgb("#1eff00"),
  [3] = rgb("#0070dd"), [4] = rgb("#a335ee"), [5] = rgb("#ff8000"),
}
function T.Quality(q)
  q = tonumber(q)
  local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c and c.r then
    return { c.r, c.g, c.b, 1, hex = (c.hex and c.hex:gsub("|c", "") or nil) }
  end
  return FALLBACK_Q[q or 1] or FALLBACK_Q[1]
end

function T.ClassColor(classTag)
  local c = classTag and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag:upper()]
  if c then return { c.r, c.g, c.b, 1, hex = string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) } end
  return T.C.bone
end

function T.Wrap(color, text)
  local c = type(color) == "string" and T.C[color] or color
  return "|c" .. ((c and c.hex) or "ffffffff") .. tostring(text) .. "|r"
end

-- =================== Fonts ===================
local loc = GetLocale and GetLocale() or "enUS"
local NARROW_OK = not (loc == "koKR" or loc == "zhCN" or loc == "zhTW")
T.FONT_BODY  = NARROW_OK and "Fonts\\ARIALN.TTF" or STANDARD_TEXT_FONT
T.FONT_NUM   = NARROW_OK and "Fonts\\FRIZQT__.TTF" or STANDARD_TEXT_FONT
T.FONT_TITLE = NARROW_OK and "Fonts\\MORPHEUS.TTF" or STANDARD_TEXT_FONT

local FONTS = {
  title   = { T.FONT_TITLE, 16, "" },
  heading = { T.FONT_TITLE, 15, "" },
  name    = { T.FONT_BODY, 15, "" },
  body    = { T.FONT_BODY, 13, "" },
  strong  = { T.FONT_BODY, 14, "" },
  small   = { T.FONT_BODY, 12, "" },
  num     = { T.FONT_NUM, 11, "" },
  numBig  = { T.FONT_NUM, 18, "" },
}

T.Font = {}
for role, def in pairs(FONTS) do
  local fo = CreateFont("MakersPathFont_" .. role)
  fo:SetFont(def[1], def[2], def[3])
  fo:SetShadowColor(0, 0, 0, 0.9)
  fo:SetShadowOffset(1, -1)
  fo:SetJustifyH("LEFT")
  T.Font[role] = fo
end
-- =================== Sizes ===================
T.S = {
  pad        = 6,
  header     = 38,
  footer     = 32,
  railW      = 182,
  railRow    = 50,
  socket     = 40,
  bottomRail = 58,
  laneStep   = 18,
  pathIndent = 80,
  itemRow    = 26,
  pip        = 14,
}

-- =================== Textures ===================
T.Tex = {
  leather  = T.ART .. "leather",
  rail     = T.ART .. "rail",
  corner   = T.ART .. "corner",
  bracket  = T.ART .. "bracket",
  coin     = T.ART .. "coin",
  coinHot  = T.ART .. "coin_hot",
  fade     = T.ART .. "fade",
  check    = T.ART .. "check",
  emblem   = T.ART .. "emblem",
  chevron  = T.ART .. "chevron",
  close    = T.ART .. "close",
  back     = T.ART .. "back",
  levelGlyph = T.ART .. "glyph_level",
  markReady = T.ART .. "mark_ready",
  markMats  = T.ART .. "mark_mats",
  markNeed  = T.ART .. "mark_need",
  markLevel = T.ART .. "mark_level",
  heart     = T.ART .. "heart",
  question  = "Interface\\Icons\\INV_Misc_QuestionMark",
}

T.CHECKS = { "skill", "recipe", "mats", "equip" }

function T.Pip(kind, state)
  return T.ART .. "pip_" .. kind .. "_" .. (state == "Y" and "Y" or state == "N" and "N" or "U")
end

function T.Glyph(kind)
  return T.ART .. "glyph_" .. kind
end

function T.PipInline(kind, state, size)
  size = size or 14
  return "|T" .. T.Pip(kind, state) .. ":" .. size .. ":" .. size .. "|t"
end

function T.TexInline(path, size)
  size = size or 14
  return "|T" .. path .. ":" .. size .. ":" .. size .. "|t"
end
