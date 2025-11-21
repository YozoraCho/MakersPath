local ADDON, MakersPath = ...
MakersPath = MakersPath or {}
MakersPath.Util = MakersPath.Util or {}
_G.MakersPath = MakersPath
local C = MakersPath.Const or {}
local Filters = MakersPath and MakersPath.Filters
local function Ls(key) if MakersPath and MakersPath.Ls then return MakersPath.Ls(key) end return key end
local GearFinder = {}
MakersPath.GearFinder = GearFinder
GearFinder._summaryDirty = true
GearFinder._lastSummary = nil
function GearFinder:MarkDirty() self._summaryDirty = true end
local debugprofilestop = debugprofilestop or function() return 0 end
local StatsCache = {}
MakersPath.Spec = MakersPath.Spec or {}
MakersPath.Config = MakersPath.Config or {}
MakersPath.Config.CHAR_SPEC = MakersPath.Config.CHAR_SPEC or {}
local PREF_NATIVE_ARMOR = (MakersPath.Config.PREF_NATIVE_ARMOR ~= false) -- default: true
local function GetIgnoreFilters()
  return MakersPath.Config.IGNORE_FILTERS == true
end
local function SetIgnoreFilters(v)
  MakersPath.Config.IGNORE_FILTERS = (v == true)
end
local ONLY_STATS_WEAPONS = (MakersPath.Config.ONLY_STATS_WEAPONS == true)
local _pendingKick = _pendingKick or {}

-- temp: slash to toggle filter gating at runtime
SLASH_MPIGN1 = "/mpignorefilters"
SlashCmdList["MPIGN"] = function(msg)
  msg = (msg or ""):lower():match("^%s*(%S*)") or ""
  if msg == "on" or msg == "true" or msg == "1" then
    SetIgnoreFilters(true)
  elseif msg == "off" or msg == "false" or msg == "0" then
    SetIgnoreFilters(false)
  else
    SetIgnoreFilters(not GetIgnoreFilters())
  end
  print("|cff66ccff[Maker'sPath]|r " .. string.format(Ls("IGNORE_FILTERS_STATUS"), tostring(GetIgnoreFilters())))
  if MakersPath and MakersPath.GearFinder and MakersPath.GearFinder.MarkDirty then
    MakersPath.GearFinder:MarkDirty()
  end
  if MakersPath and MakersPath.GearFinderScan then MakersPath.GearFinderScan() end
  if MakersPathFrame and MakersPathFrame:IsShown() and RefreshList then RefreshList() end
end

if not MakersPath.Util.ArmorTokenForItemID then
  function MakersPath.Util.ArmorTokenForItemID(itemID)
    if not itemID then return nil end
    local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
    if classID == C.CLASS_ARMOR then
      if subClassID == C.ARMOR_SUB.CLOTH   then return "CLOTH"
      elseif subClassID == C.ARMOR_SUB.LEATHER then return "LEATHER"
      elseif subClassID == C.ARMOR_SUB.MAIL    then return "MAIL"
      elseif subClassID == C.ARMOR_SUB.PLATE   then return "PLATE"
      end
    end
    return nil
  end
end
-- ===== Spec API =====
function MakersPath.Spec.CharKey()
  return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

function CurrentSpec()
  return MakersPath.Spec.Get and MakersPath.Spec.Get() or nil
end

function SetCurrentSpec(spec)
  if MakersPath.Spec.Set then
    MakersPath.Spec.Set(spec)
  end
end

ArmorTokenForItemID = ArmorTokenForItemID or MakersPath.Util.ArmorTokenForItemID

-- ==============================
-- Spec selection (per-character)
-- ==============================
MakersPath.Config = MakersPath.Config or {}
MakersPath.Config.CHAR_SPEC = MakersPath.Config.CHAR_SPEC or {}
local CharConfig

local function CurrentSpec()
  local rec, key = CharConfig()
  local s = rec.spec or MakersPath.Config.CHAR_SPEC[key]
  if not s or s == "" then
    return nil
  end
  s = s:upper()
  MakersPath.Config.CHAR_SPEC[key] = s
  return s
end

local function SetCurrentSpec(spec)
  local rec, key = CharConfig()
  if spec and spec ~= "" then
    spec = spec:upper()
    rec.spec = spec
    MakersPath.Config.CHAR_SPEC[key] = spec
  else
    rec.spec = nil
    MakersPath.Config.CHAR_SPEC[key] = nil
  end
  if MakersPath and MakersPath.GearFinder then
    MakersPath.GearFinder._equippedScoreCache = {}
    if MakersPath.GearFinder.MarkDirty then
      MakersPath.GearFinder:MarkDirty()
    end
  end
  if MakersPath and MakersPath.GearFinderScan then MakersPath.GearFinderScan() end
  if MakersPathFrame and MakersPathFrame:IsShown() and RefreshList then RefreshList() end
end

local function _printSpecChanged()
  local spec = CurrentSpec() or Ls("SPEC_AUTO_KEYWORD")
  print("|cff66ccff[Maker'sPath]|r" .. string.format(Ls("SPEC_CURRENT_STATUS"), spec))
end

MakersPath.Spec.Get = function()
  return CurrentSpec()
end
MakersPath.Spec.Set = function(spec)
  return SetCurrentSpec(spec)
end


-- ==============================
-- Per-character session (avoid cross-character bleed)
-- ==============================
local function CurrentCharKey()
  local name  = UnitName("player") or "?"
  local realm = GetRealmName() or "?"
  return name .. "-" .. realm
end

function GearFinder:BeginSession()
  local key = CurrentCharKey()
  if self._charKey ~= key then
    self._charKey = key
    self._equippedScoreCache = {}
  else
    self._equippedScoreCache = {}
  end
end

CharConfig = function()
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.chars = MakersPathDB.chars or {}

  local name  = UnitName("player") or "?"
  local realm = GetRealmName() or "?"
  local key   = name .. "-" .. realm

  MakersPathDB.chars[key] = MakersPathDB.chars[key] or {}
  return MakersPathDB.chars[key], key
end

local function ArmorTokenFromIDs(classID, subClassID)
  if not classID then return nil end
  if classID ~= C.CLASS_ARMOR then return nil end
  if subClassID == C.ARMOR_SUB.CLOTH   then return "CLOTH"   end
  if subClassID == C.ARMOR_SUB.LEATHER then return "LEATHER" end
  if subClassID == C.ARMOR_SUB.MAIL    then return "MAIL"    end
  if subClassID == C.ARMOR_SUB.PLATE   then return "PLATE"   end
  return nil
end

local function ArmorTokenByStrings(itemType, itemSubType)
  local armorName = GetItemClassInfo and GetItemClassInfo(C.CLASS_ARMOR or 4)
  if not armorName or itemType ~= armorName then return nil end

  local cloth   = GetItemSubClassInfo and GetItemSubClassInfo(C.CLASS_ARMOR or 4, C.ARMOR_SUB.CLOTH or 1)
  local leather = GetItemSubClassInfo and GetItemSubClassInfo(C.CLASS_ARMOR or 4, C.ARMOR_SUB.LEATHER or 2)
  local mail    = GetItemSubClassInfo and GetItemSubClassInfo(C.CLASS_ARMOR or 4, C.ARMOR_SUB.MAIL or 3)
  local plate   = GetItemSubClassInfo and GetItemSubClassInfo(C.CLASS_ARMOR or 4, C.ARMOR_SUB.PLATE or 4)

  if cloth   and itemSubType == cloth   then return "CLOTH"   end
  if leather and itemSubType == leather then return "LEATHER" end
  if mail    and itemSubType == mail    then return "MAIL"    end
  if plate   and itemSubType == plate   then return "PLATE"   end
  return nil
end

local function ArmorTokenForItemID(itemID)
  if not itemID then return nil end
  local _, _, _, _, _, _classID, _subClassID = nil, nil, nil, nil, nil, nil, nil
  if C_Item and C_Item.GetItemInfoInstant then
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    _classID, _subClassID = classID, subClassID
  end

  local tok = ArmorTokenFromIDs(_classID, _subClassID)
  if tok then return tok end

  local itemType, itemSubType = select(6, GetItemInfo(itemID))
  if not itemType then
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return nil
  end
  return ArmorTokenByStrings(itemType, itemSubType)
end

local function IsArmorish(inv)
  return inv=="INVTYPE_HEAD" or inv=="INVTYPE_NECK" or inv=="INVTYPE_SHOULDER" or inv=="INVTYPE_CLOAK" or inv=="INVTYPE_CHEST" or inv=="INVTYPE_ROBE" or inv=="INVTYPE_WRIST" or inv=="INVTYPE_HAND" or inv=="INVTYPE_WAIST" or inv=="INVTYPE_LEGS" or inv=="INVTYPE_FEET" or inv=="INVTYPE_FINGER" or inv=="INVTYPE_TRINKET"
end

local function casterHasPrimaries(s)
  return (tonumber(s.ITEM_MOD_INTELLECT or 0) > 0)
      or (tonumber(s.ITEM_MOD_SPELL_POWER or 0) > 0)
      or (tonumber(s.ITEM_MOD_SPELL_HEALING_DONE or 0) > 0)
      or (tonumber(s.ITEM_MOD_HIT_SPELL_RATING or 0) > 0)
      or (tonumber(s.ITEM_MOD_CRIT_SPELL_RATING or 0) > 0)
end

local function WeaponLineForItem(itemID)
  if not itemID then return nil end
  local _, _, _, _, _, classID, subClassID = nil, nil, nil, nil, nil, nil, nil
  if C_Item and C_Item.GetItemInfoInstant then
    local _, _, _, _, _, _classID, _subClassID = C_Item.GetItemInfoInstant(itemID)
    classID, subClassID = _classID, _subClassID
  end
  if not classID then
    local _ = GetItemInfo(itemID)
    local _, _, _, _, _, _, _, _, _, _, _, cID, scID = GetItemInfo(itemID)
    classID, subClassID = cID, scID
  end
  if classID ~= C.CLASS_WEAPON then return nil end
  return C.SUBCLASS_TO_LINE and C.SUBCLASS_TO_LINE[subClassID] or nil
end

local function IsMiscJunkOrOther(itemID)
  local itemType, itemSubType = select(6, GetItemInfo(itemID))
  if not itemType then
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return false
  end
  local miscName = GetItemClassInfo and GetItemClassInfo(LE_ITEM_CLASS_MISCELLANEOUS or 15)
  if not miscName or itemType ~= miscName then return false end
  local junkName  = GetItemSubClassInfo and GetItemSubClassInfo(LE_ITEM_CLASS_MISCELLANEOUS or 15, 0) -- "Junk"
  local otherName = GetItemSubClassInfo and GetItemSubClassInfo(LE_ITEM_CLASS_MISCELLANEOUS or 15, 1) -- "Reagent"/"Other"
  if junkName  and itemSubType == junkName  then return true end
  if otherName and itemSubType == otherName then return true end
  return false
end

local MPGFTT = MPGFTT or CreateFrame("GameTooltip","MPGFTT",UIParent,"GameTooltipTemplate")
MPGFTT:SetOwner(UIParent, "ANCHOR_NONE")

-- ===========================
-- Locale-aware tooltip parse
-- ===========================
local GF_STAT_LINES
local GF_DAMAGE_PATTERNS
local GF_SPEED_PATTERNS
local GF_ARMOR_PATTERNS
local GF_DPS_PATTERNS

local function GF_EscapePattern(text)
  return (text or ""):gsub("([%^%$%(%)%.%[%]%*%+%-%?])","%%%1")
end

local function GF_MakeIntPairPattern(tmpl)
  if not tmpl or tmpl == "" then return nil end
  if tmpl:find("%%1%$") or tmpl:find("%%2%$") or tmpl:find("%%3%$") then
    return nil
  end

  tmpl = GF_EscapePattern(tmpl)
  tmpl = tmpl:gsub("%%d", "(%%d+)")
  return "^" .. tmpl .. "$"
end

local function GF_MakeNumberPattern(tmpl)
  if not tmpl or tmpl == "" then return nil end
  if tmpl:find("%%1%$") or tmpl:find("%%2%$") or tmpl:find("%%3%$") then
    return nil
  end

  tmpl = GF_EscapePattern(tmpl)
  tmpl = tmpl:gsub("%%%.%df", "([%%d%%.,]+)")
  tmpl = tmpl:gsub("%%f", "([%%d%%.,]+)")
  return "^" .. tmpl .. "$"
end

local function GF_BuildTooltipPatterns()
  if GF_STAT_LINES then return end

  GF_STAT_LINES     = {}
  GF_DAMAGE_PATTERNS = {}
  GF_SPEED_PATTERNS  = {}
  GF_ARMOR_PATTERNS  = {}
  GF_DPS_PATTERNS    = {}

  local function addStat(shortGlobal, fieldKey)
    local label = _G[shortGlobal]
    if not label or label == "" then return end
    label = GF_EscapePattern(label)
    local pat = "^%+(%d+)%s+" .. label .. "$"
    GF_STAT_LINES[#GF_STAT_LINES+1] = { field = fieldKey, pattern = pat }
  end

  addStat("ITEM_MOD_STRENGTH_SHORT",  "ITEM_MOD_STRENGTH")
  addStat("ITEM_MOD_AGILITY_SHORT",   "ITEM_MOD_AGILITY")
  addStat("ITEM_MOD_STAMINA_SHORT",   "ITEM_MOD_STAMINA")
  addStat("ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_INTELLECT")
  addStat("ITEM_MOD_SPIRIT_SHORT",    "ITEM_MOD_SPIRIT")

  local dmgTmpl  = _G.DAMAGE_TEMPLATE
  local dmgSchT  = _G.DAMAGE_TEMPLATE_WITH_SCHOOL
  local dmgAlt   = "%%d%s*%-%s*%%d%s+" .. (GF_EscapePattern(_G.DAMAGE or "Damage"))

  local p1 = GF_MakeIntPairPattern(dmgTmpl)
  local p2 = GF_MakeIntPairPattern(dmgSchT)
  if p1 then table.insert(GF_DAMAGE_PATTERNS, p1) end
  if p2 then table.insert(GF_DAMAGE_PATTERNS, p2) end
  table.insert(GF_DAMAGE_PATTERNS, "^" .. dmgAlt .. "$")

  local spdTmpl = _G.WEAPON_SPEED or _G.TOOLTIP_SPEED or "Speed %.2f"
  local spdPat  = GF_MakeNumberPattern(spdTmpl)
  if spdPat then table.insert(GF_SPEED_PATTERNS, spdPat) end
  table.insert(GF_SPEED_PATTERNS, "^[Ss]peed[:%s]+([%d%.%,]+)")

  local armorWord = _G.ARMOR or "Armor"
  armorWord = GF_EscapePattern(armorWord)
  table.insert(GF_ARMOR_PATTERNS, "^([%d,%.]+)%s+" .. armorWord .. "$")

  local dpsTmpl   = _G.DPS_TEMPLATE
  local dpsSimple = _G.DPS_TEMPLATE_SIMPLE
  local pDps1     = GF_MakeNumberPattern(dpsTmpl)
  local pDps2     = GF_MakeNumberPattern(dpsSimple)
  if pDps1 then table.insert(GF_DPS_PATTERNS, pDps1) end
  if pDps2 then table.insert(GF_DPS_PATTERNS, pDps2) end
  table.insert(GF_DPS_PATTERNS, "^([%d%.%,]+)%s+[Dd][Pp][Ss]$")
  table.insert(GF_DPS_PATTERNS, "%(([%d%.%,]+)%s+[Dd]amage%s+per%s+second%)")
end

local function ParseTooltipStatsToTable(itemID)
  GF_BuildTooltipPatterns()

  local t = {}
  local link = select(2, GetItemInfo(itemID))
  if not link then
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return nil
  end

  MPGFTT:ClearLines()
  MPGFTT:SetOwner(UIParent, "ANCHOR_NONE")
  MPGFTT:SetHyperlink(link)

  local function feed(txt)
    if not txt or txt == "" then return end

    local handledStat = false
    for _, row in ipairs(GF_STAT_LINES) do
      local val = txt:match(row.pattern)
      if val then
        val = tonumber(val) or 0
        if val > 0 then
          t[row.field] = (t[row.field] or 0) + val
          handledStat = true
        end
        break
      end
    end
    if handledStat then return end
    for _, pat in ipairs(GF_DAMAGE_PATTERNS) do
      local dmin, dmax = txt:match(pat)
      if dmin and dmax then
        t.__TMP_MIN = tonumber(dmin) or t.__TMP_MIN
        t.__TMP_MAX = tonumber(dmax) or t.__TMP_MAX
        break
      end
    end
    if not t.__TMP_SPD then
      for _, pat in ipairs(GF_SPEED_PATTERNS) do
        local spd = txt:match(pat)
        if spd then
          spd = tonumber((spd:gsub(",", ".")))
          if spd and spd > 0 then
            t.__TMP_SPD = spd
            break
          end
        end
      end
    end
    do
      local armor
      for _, pat in ipairs(GF_ARMOR_PATTERNS) do
        armor = txt:match(pat)
        if armor then break end
      end
      if armor then
        armor = tonumber((armor:gsub("[,%.]", ""))) or 0
        if armor > 0 then
          t.ITEM_MOD_ARMOR = math.max(armor, t.ITEM_MOD_ARMOR or 0)
        end
      end
    end
    do
      local dpsVal
      for _, pat in ipairs(GF_DPS_PATTERNS) do
        local m = txt:match(pat)
        if m then
          dpsVal = tonumber((m:gsub(",", "."))) or 0
          if dpsVal > 0 then break end
        end
      end
      if dpsVal and dpsVal > 0 then
        t.DAMAGE_PER_SECOND = math.max(dpsVal, t.DAMAGE_PER_SECOND or 0)
      end
    end
  end

  local hadAny = false
  for i = 1, MPGFTT:NumLines() do
    local L = _G["MPGFTTTextLeft"..i]
    local R = _G["MPGFTTTextRight"..i]
    local ltxt = L and L:GetText() or ""
    local rtxt = R and R:GetText() or ""
    if ltxt ~= "" then hadAny = true; feed(ltxt) end
    if rtxt ~= "" then hadAny = true; feed(rtxt) end
  end

  if not hadAny then
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return nil
  end

  if t.__TMP_MIN and t.__TMP_MAX and t.__TMP_SPD and t.__TMP_SPD > 0 then
    local avg = (t.__TMP_MIN + t.__TMP_MAX) / 2
    local dps = avg / t.__TMP_SPD
    if dps > 0 then
      t.DAMAGE_PER_SECOND = math.max(dps, t.DAMAGE_PER_SECOND or 0)
    end
  end
  t.__TMP_MIN, t.__TMP_MAX, t.__TMP_SPD = nil, nil, nil

  if t.DAMAGE_PER_SECOND and t.DAMAGE_PER_SECOND > 0 then
    t.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = t.DAMAGE_PER_SECOND
    t.DPS = t.DAMAGE_PER_SECOND
  end
  return t
end

-- ==============================
-- Crafted/bogus guards
-- ==============================
local function IsCraftedLike(entry)
  return entry and (entry.isCrafted == true or entry.source == "crafted")
end

local function IsEngineeringOnlyTool(entry)
  if not entry or not entry.itemID then return false end
  local Const = MakersPath.Const or {}
  local engSpell = (Const.SKILLLINE_TO_SPELL and Const.SKILLLINE_TO_SPELL[202]) or 4036
  local engName = GetSpellInfo(engSpell) or ""

  local link = select(2, GetItemInfo(entry.itemID))
  if not link or engName == "" then
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(entry.itemID) end
    return false
  end

  MPGFTT:ClearLines()
  MPGFTT:SetHyperlink(link)

  for i = 2, MPGFTT:NumLines() do
    local L = _G["MPGFTTTextLeft"..i]
    local txt = L and L:GetText() or ""
    if txt ~= "" and txt:find(engName, 1, true) and txt:find("%(", 1, true) then
      return true
    end
  end
  return false
end

local function LooksBogus(entry)
  if not entry or not entry.itemID then return true end

  local BAD_ITEMS = {
    [7005]  = true, -- Skinning Knife
    [7007]  = true, -- Mining Pick
    [7010]  = true, -- Fishing Pole
    [7420] = true, -- Phalanx Headguard
    [7748] = true, -- Forcestone Buckler
    [13529] = true, -- Husk of Nerub'ekkan
    [22750] = true, -- Sentinel's Lizardhide Pants
  }
  if BAD_ITEMS[entry.itemID] then
    return true
  end

  local name = entry.name or GetItemInfo(entry.itemID)
  if name then
    if name:find("^Monster%s*%-")  then return true end
    if name:upper():find("^TEST")  then return true end
  end
  if IsMiscJunkOrOther(entry.itemID) then
    return true
  end
  return false
end

-- ==============================
-- SavedVariables access (runtime)
-- ==============================
function GDB()
  MakersPathGlobalDB.items       = MakersPathGlobalDB.items       or {}
  MakersPathGlobalDB.buckets     = MakersPathGlobalDB.buckets     or {}
  MakersPathGlobalDB.itemRecords = MakersPathGlobalDB.itemRecords or {}

  local db = MakersPathGlobalDB
  db.factionLocks = db.factionLocks or {}
  db.factionLocks.items = db.factionLocks.items or {}

  local defaults = {
    [4455] = "HORDE",     -- Raptor Hide Harness
    [7929] = "HORDE", -- Orcish War Leggings
    [7916] = "HORDE", -- Barbaric Iron Boots
    [7914] = "HORDE", -- Barbaric Iron Breastplate
    [7917] = "HORDE", -- Barbaric Iron Gloves
    [7915] = "HORDE", -- Barbaric Iron Helm
    [7913] = "HORDE", -- Barbaric Iron Shoulders
    [4456] = "ALLIANCE",  -- Raptor Hide Belt
    [9366] = "ALLIANCE",  -- Golden Scale Gauntlets
    [6731] = "ALLIANCE",  -- Iron Forged Breastplate
    [7283] = "ALLIANCE",  -- Black Whelp Cloak
    [20575] = "ALLIANCE", -- Black Whelp Tunic
    [7349] = "ALLIANCE",  -- Herbalist's Gloves
    [6709] = "ALLIANCE",  -- Moonglow Vest
    [7284] = "ALLIANCE",  -- Red Whelp Gloves
    [4332] = "ALLIANCE",  -- Bright Yellow Shirt
  }
  for iid, fac in pairs(defaults) do
    if db.factionLocks.items[iid] == nil then
      db.factionLocks.items[iid] = fac
    end
  end

  return db
end

-- ==============================
-- Scoring
-- ==============================

-- ===== NORMALIZE ITEM STATS =====
local function NormalizeToMaker(stats)
  local t = {}

  local function add(key, val)
    if type(val) ~= "number" then
      if val == nil then
        val = 0
      else
        val = tonumber(val) or 0
      end
    end
    if val > 0 then
      t[key] = (t[key] or 0) + val
    end
  end
  local function pickVals(...)
    local best = 0
    local n = select("#", ...)
    for i = 1, n do
      local raw = select(i, ...)
      local v = 0
      if type(raw) == "number" then
        v = raw
      elseif type(raw) == "string" then
        v = tonumber(raw) or 0
      end
      if v > best then
        best = v
      end
    end
    return best
  end
  local function stat2(base)
    return pickVals(
      stats["ITEM_MOD_"..base],
      stats["ITEM_MOD_"..base.."_SHORT"]
    )
  end

  -- Primary stats
  add("STRENGTH",  stat2("STRENGTH"))
  add("AGILITY",   stat2("AGILITY"))
  add("STAMINA",   stat2("STAMINA"))
  add("INTELLECT", stat2("INTELLECT"))
  add("SPIRIT",    stat2("SPIRIT"))

  -- Armor
  local armor = pickVals(
    stats.ITEM_MOD_ARMOR,
    stats.ITEM_MOD_ARMOR_SHORT,
    stats.RESISTANCE0_NAME
  )
  if type(armor) ~= "number" then
    if armor == nil then
      armor = 0
    else
      armor = tonumber(armor) or 0
    end
  end
  if armor > 0 then
    add("ARMOR", armor)
  end
  add("ARMOR", stats.ITEM_MOD_ARMOR_BONUS)

  -- Melee / Ranged / Feral AP
  add("ATTACK_POWER",        stat2("ATTACK_POWER"))
  add("RANGED_ATTACK_POWER", stat2("RANGED_ATTACK_POWER"))
  add("FERAL_ATTACK_POWER",  stats.FERAL_ATTACK_POWER or stats.FERAL_AP)

  -- DPS
  add("DAMAGE_PER_SECOND", pickVals(
    stats.DPS,
    stats.DAMAGE_PER_SECOND,
    stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
  ))

  -- Ratings
  add("CRIT",              stat2("CRIT_RATING"))
  add("CRIT_SPELL",        stat2("CRIT_SPELL_RATING"))
  add("HIT",               stat2("HIT_RATING"))
  add("HIT_SPELL",         stat2("HIT_SPELL_RATING"))
  add("HASTE",             pickVals(stats.ITEM_MOD_HASTE_RATING, stats.ITEM_MOD_HASTE_SPELL_RATING))
  add("EXPERTISE",         stat2("EXPERTISE_RATING"))
  add("ARMOR_PENETRATION", stat2("ARMOR_PENETRATION_RATING"))

  -- Defensive ratings
  add("DEFENSE_SKILL", stats.DEFENSE_RATING or stats.ITEM_MOD_DEFENSE_SKILL_RATING)
  add("DODGE",               stat2("DODGE_RATING"))
  add("PARRY",               stat2("PARRY_RATING"))
  add("BLOCK",               stat2("BLOCK_RATING"))
  add("BLOCK_VALUE",         stats.ITEM_MOD_BLOCK_VALUE)

  -- Health / Mana / regen
  add("HEALTH",              stats.HEALTH or stats.ITEM_MOD_HEALTH)
  add("MANA",                stats.MANA   or stats.ITEM_MOD_MANA)
  add("HEALTH_REGENERATION", stats.ITEM_MOD_HEALTH_REGENERATION or stats.HEALTH_REGEN)
  add("MANA_REGENERATION",   stats.ITEM_MOD_MANA_REGENERATION   or stats.MP5)

  -- Spell power & healing
  add("SPELL_DAMAGE_DONE",  stat2("SPELL_POWER"))
  add("SPELL_HEALING_DONE", stats.ITEM_MOD_SPELL_HEALING_DONE or stats.HEALING_POWER)
  add("SPELL_PENETRATION",  stats.ITEM_MOD_SPELL_PENETRATION)

  -- School-specific spell damage
  add("SPELL_DAMAGE_DONE_HOLY",   stats.SPELL_DMG_HOLY)
  add("SPELL_DAMAGE_DONE_FIRE",   stats.SPELL_DMG_FIRE)
  add("SPELL_DAMAGE_DONE_NATURE", stats.SPELL_DMG_NATURE)
  add("SPELL_DAMAGE_DONE_FROST",  stats.SPELL_DMG_FROST)
  add("SPELL_DAMAGE_DONE_SHADOW", stats.SPELL_DMG_SHADOW)
  add("SPELL_DAMAGE_DONE_ARCANE", stats.SPELL_DMG_ARCANE)

  -- Resistances
  add("FIRE_RESISTANCE",   stats.RESISTANCE2_NAME or stats.RESISTANCEFIRE)
  add("NATURE_RESISTANCE", stats.RESISTANCE3_NAME or stats.RESISTANCENATURE)
  add("FROST_RESISTANCE",  stats.RESISTANCE4_NAME or stats.RESISTANCEFROST)
  add("SHADOW_RESISTANCE", stats.RESISTANCE5_NAME or stats.RESISTANCESHADOW)
  add("ARCANE_RESISTANCE", stats.RESISTANCE6_NAME or stats.RESISTANCEARCANE)

  return t
end


local ROLE_FOR_SPEC = {
  SHAMAN = {
    ELEMENTAL   = "CASTER",
    ENHANCEMENT = "MELEE",
    RESTORATION = "CASTER",
  },
  DRUID = {
    BALANCE     = "CASTER",
    FERAL_DPS   = "MELEE",
    FERAL_TANK  = "MELEE",
    RESTORATION = "CASTER",
  },
  WARRIOR = { ARMS="MELEE", FURY="MELEE", PROTECTION="MELEE", FURYPROT="HYBRID" },
  PALADIN = { HOLY="CASTER", PROTECTION="MELEE", RETRIBUTION="MELEE" },
  PRIEST  = { DISCIPLINE="CASTER", HOLY="CASTER", SHADOW="CASTER" },
  MAGE    = { ARCANE="CASTER", FIRE="CASTER", FROST="CASTER" },
  WARLOCK = { AFFLICTION="CASTER", DEMONOLOGY="CASTER", DESTRUCTION="CASTER" },
  HUNTER  = { BEAST_MASTERY="HYBRID", MARKSMANSHIP="HYBRID", SURVIVAL="HYBRID" },
  ROGUE   = { ASSASSINATION="MELEE", COMBAT="MELEE", SUBTLETY="MELEE" },
}

local function IsTankSpec()
  local _, class = UnitClass("player")
  class = class and class:upper() or "UNKNOWN"
  local spec = CurrentSpec()
  if not spec then return false end
  if class=="DRUID"  and spec=="FERAL_TANK"  then return true end
  if class=="WARRIOR" and spec=="PROTECTION" then return true end
  if class=="PALADIN" and spec=="PROTECTION" then return true end
  return false
end

local function RolePhase(class, lvl)
  lvl = lvl or (UnitLevel("player") or 1)
  class = (class and class:upper()) or "UNKNOWN"
  local spec = CurrentSpec()

  local role
  if spec and ROLE_FOR_SPEC[class] and ROLE_FOR_SPEC[class][spec] then
    role = ROLE_FOR_SPEC[class][spec]
  else
    if class=="WARRIOR" or class=="PALADIN" or class=="ROGUE" then
      role = "MELEE"
    elseif class=="HUNTER" or class=="DRUID" or class=="SHAMAN" then
      role = "HYBRID"
    elseif class=="MAGE" or class=="PRIEST" or class=="WARLOCK" then
      role = "CASTER"
    else
      role = "GENERIC"
    end
  end

  local band
  if lvl < 20 then band = 1
  elseif lvl < 30 then band = 2
  else band = 3 end

  return role, band
end

local function GetClassWeights()
  local all = MakersPath.Weights or {}
  local _, class = UnitClass("player")
  class = class and class:upper() or "UNKNOWN"
  local lvl = UnitLevel("player") or 1

  local classTbl = all[class]
  if not classTbl then return nil end

  if lvl < 10 then
    if classTbl.BASE then
      return classTbl.BASE
    end
    for k, v in pairs(classTbl) do
      if k ~= "BASE" and type(v) == "table" then
        return v
      end
    end
    return nil
  end

  local spec = MakersPath.Spec.Get()
  if not spec or spec == "" then
    return classTbl.BASE or nil
  end

  local key = spec
  if class == "WARRIOR" and key == "PROT"     then key = "PROTECTION" end
  if class == "WARRIOR" and key == "FURYPROT" then key = "FURYPROT"   end

  local weights = classTbl[key]
  if weights then
    return weights
  end
  return classTbl.BASE or nil
end

local function ScoreFromStats(statsRaw)
  local weights = GetClassWeights()
  if not weights then return 0 end
  local mstats = NormalizeToMaker(statsRaw or {})

  local total = 0
  for k, w in pairs(weights) do
    local v = mstats[k]
    if v and w and v > 0 then
      total = total + (v * w)
    end
  end
  return total
end

local function LevelScaledCoeffs()
  local lvl = UnitLevel("player") or 1
  if lvl < 20 then
    return 0.020, 0.25
  elseif lvl < 40 then
    return 0.020, 0.40
  else
    return 0.020, 0.50
  end
end

local function StatsAreEmpty(stats)
  if not stats then return true end
  for _, v in pairs(stats) do
    if type(v) == "number" and v > 0 then
      return false
    end
  end
  return true
end

local function PickArmor(stats)
  if not stats then return 0 end
  local keys = { "RESISTANCE0_NAME", "ITEM_MOD_ARMOR_SHORT", "ITEM_MOD_ARMOR" }
  local best = 0
  for _, k in ipairs(keys) do
    local v = stats[k]
    if type(v) == "number" and v > best then
      best = v
    end
  end
  if best == 0 then
    for k, v in pairs(stats) do
      if type(v) == "number" and v > 0 and k and k:find("ARMOR", 1, true) then
        if v > best then best = v end
      end
    end
  end
  return best
end

local function PickDPS(stats)
  local keys = { "DPS", "DAMAGE_PER_SECOND", "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" }
  local best = 0
  for _, k in ipairs(keys) do
    local v = stats and stats[k]
    if type(v) == "number" and v > best then best = v end
  end
  return best
end

local ArmorBias
local WeaponBias
local ProfessionBias
local GatherBias
local AugmentNeedHave

-- ==============================
-- Debug + scoring breakdown
-- ==============================
MakersPath.Config = MakersPath.Config or {}

local function _say(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts+1] = tostring(select(i, ...)) end
  local msg = table.concat(parts, " ")
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Maker'sPath:GF]|r "..msg)
  else
    print("[Maker'sPath:GF] "..msg)
  end
end

-- Make DEBUG dynamic (no snapshot). Also expose globally for Filters.lua.
_G.DBG = function(...)
  if MakersPath and MakersPath.Config and MakersPath.Config.DEBUG_GF then
    _say(...)
  end
end
local DBG = _G.DBG

-- Slash: /mpdebug on|off|toggle
SLASH_MPDEBUG1 = "/mpdebug"
SlashCmdList["MPDEBUG"] = function(msg)
  msg = (msg or ""):lower():match("^%s*(%S*)") or ""
  if msg == "on" then
    MakersPath.Config.DEBUG_GF = true
  elseif msg == "off" then
    MakersPath.Config.DEBUG_GF = false
  else
    MakersPath.Config.DEBUG_GF = not MakersPath.Config.DEBUG_GF
  end
  print("|cff66ccff[Maker'sPath]|r".. string.format(Ls("DEBUG_GF_STATUS"), tostring(MakersPath.Config.DEBUG_GF)))
end


local function _ArmorTokenForItemID(iid)
  return ArmorTokenForItemID(iid)
end

function ArmorBias(_)      return 0 end
function WeaponBias(_)     return 0 end
function ProfessionBias(_) return 0 end
function GatherBias(_)     return 0 end

local function ArmorCoefFor(class, slotName, lvl)
  local ARMOR_COEF = select(1, LevelScaledCoeffs())
  local major = (slotName == "ChestSlot" or slotName == "LegsSlot" or slotName == "HeadSlot" or slotName == "ShoulderSlot")
  if major then
    return ARMOR_COEF * 1.5
  end

  return ARMOR_COEF
end

local function StatFromStats(stats, key)
  return tonumber((stats and stats[key]) or 0) or 0
end

local function GetItemStatsTable(iid)
  if not iid then return nil end
  local cached = StatsCache[iid]
  if cached ~= nil then
    return cached or nil
  end

  local link = select(2, GetItemInfo(iid))
  if not link then
    if C_Item and C_Item.RequestLoadItemDataByID then
      C_Item.RequestLoadItemDataByID(iid)
    end
    return nil
  end

  local s = GetItemStats(link)
  if StatsAreEmpty(s) then
    s = ParseTooltipStatsToTable(iid)
  end
  StatsCache[iid] = s or false
  return s
end

local function EquippedStatForSlot(slotName, statKey)

  local function statOn(token)
    local slotId = GetInventorySlotInfo(token)
    if not slotId then return 0 end
    local link = GetInventoryItemLink("player", slotId)
    if not link then return 0 end
    local iid = GetItemInfoInstant(link)
    if not iid then return 0 end
    local s = GetItemStatsTable(iid)
    return StatFromStats(s, statKey)
  end

  if slotName=="Finger0Slot" or slotName=="Finger1Slot" then
    return math.max(statOn("Finger0Slot"), statOn("Finger1Slot"))
  elseif slotName=="Trinket0Slot" or slotName=="Trinket1Slot" then
    return math.max(statOn("Trinket0Slot"), statOn("Trinket1Slot"))
  else
    return statOn(slotName)
  end
end

local PRIMARY_LIST = {
  "ITEM_MOD_INTELLECT","ITEM_MOD_STAMINA","ITEM_MOD_SPIRIT",
  "ITEM_MOD_STRENGTH","ITEM_MOD_AGILITY",
  "ITEM_MOD_SPELL_POWER","ITEM_MOD_SPELL_HEALING_DONE",
  "ITEM_MOD_MANA_REGENERATION","ITEM_MOD_ATTACK_POWER",
  "ITEM_MOD_RANGED_ATTACK_POWER","ITEM_MOD_CRIT_RATING",
  "ITEM_MOD_CRIT_SPELL_RATING","ITEM_MOD_HIT_RATING","ITEM_MOD_HIT_SPELL_RATING",
}

local function StatRichnessBonus(stats, invType, class)
  if not stats then return 0 end
  local role, band = RolePhase(class)
  local mstats = NormalizeToMaker(stats or {})
  local primKeys = {
    "STRENGTH","AGILITY","STAMINA","INTELLECT","SPIRIT",
    "ATTACK_POWER","RANGED_ATTACK_POWER",
    "SPELL_DAMAGE_DONE","SPELL_HEALING_DONE","MANA_REGENERATION",
    "CRIT","CRIT_SPELL","HIT","HIT_SPELL",
  }
  local primCount, primSum = 0, 0
  for _,k in ipairs(primKeys) do
    local v = tonumber(mstats[k] or 0) or 0
    if v > 0 then primCount = primCount + 1; primSum = primSum + v end
  end

  local base = (primCount > 0) and (0.25 + 0.05 * primCount) or 0

  if role == "CASTER" then
    local intVal    = tonumber(mstats.INTELLECT or 0) or 0
    local spVal     = tonumber(mstats.SPELL_DAMAGE_DONE or mstats.SPELL_HEALING_DONE or 0) or 0
    local spiritVal = tonumber(mstats.SPIRIT or 0) or 0
    local hitVal    = tonumber(mstats.HIT_SPELL or 0) or 0
    local critVal   = tonumber(mstats.CRIT_SPELL or 0) or 0

    if band == 1 then
      base = base + (intVal + spiritVal) * 0.01
    elseif band == 2 then
      base = base + (intVal * 0.06) + (spiritVal * 0.05)
    else
      base = base + (intVal * 0.08) + (spVal * 0.07)
           + (spiritVal * 0.05) + (hitVal * 0.06) + (critVal * 0.05)
    end
  end

  return math.min(1.25, base)
end

local function ScoreItemWithBreakdown(iid, slotName, preKnownArmorTok, preKnownInvType)
  if not iid then
    return 0, false, { reason = "no-iid" }
  end

  local link = select(2, GetItemInfo(iid))
  if not link then
    if C_Item and C_Item.RequestLoadItemDataByID then
      C_Item.RequestLoadItemDataByID(iid)
    end
    return 0, true, { reason = "link-pending" }
  end

  local stats = GetItemStatsTable(iid)
  if not stats or StatsAreEmpty(stats) then
    return 0, true, { reason = "stats-pending" }
  end

  local baseStatsScore = ScoreFromStats(stats or {})

  local _, class = UnitClass("player")
  class = class or "UNKNOWN"
  local lvl = UnitLevel("player") or 1

  local armorVal = PickArmor(stats) or 0
  local dpsVal   = PickDPS(stats)   or 0

  local ARMOR_COEF, DPS_COEF = LevelScaledCoeffs()
  local armorAdd = armorVal * ArmorCoefFor(class, slotName, lvl)
  local dpsAdd   = dpsVal   * DPS_COEF

  local invType  = preKnownInvType or select(9, GetItemInfo(iid)) or ""
  local armorTok = preKnownArmorTok or _ArmorTokenForItemID(iid)

  local statBonus = 0
  do
    local _, c = UnitClass("player")
    statBonus = StatRichnessBonus(stats, invType, c)
  end

  local entryShim = {
    itemID  = iid,
    invType = invType,
    armor   = armorTok,
  }
  local biasArmor, biasWeap = 0, 0

  local isWeaponish = invType
    and (invType:find("WEAPON")
      or invType:find("RANGED")
      or invType == "INVTYPE_HOLDABLE"
      or invType == "INVTYPE_SHIELD")

  if not (ONLY_STATS_WEAPONS and isWeaponish) then
    biasArmor  = ArmorBias(entryShim)
    biasWeap   = WeaponBias(entryShim)
  end

  local total = (baseStatsScore or 0) + armorAdd + dpsAdd + statBonus + biasArmor + biasWeap

  return total, false, {
    iid        = iid,
    base       = baseStatsScore or 0,
    armor      = armorVal or 0,
    armorAdd   = armorAdd or 0,
    dps        = dpsVal   or 0,
    dpsAdd     = dpsAdd   or 0,
    biasArmor  = biasArmor or 0,
    biasWeap   = biasWeap  or 0,
    biasProf   = biasProf  or 0,
    biasGather = biasGather or 0,
    invType    = invType,
    armorTok   = armorTok,
    slot       = slotName,
    statBonus  = statBonus or 0,
  }
end


-- ==============================
-- Armor / Weapon bias
-- ==============================
local ARMOR_ORDER = { CLOTH=1, LEATHER=2, MAIL=3, PLATE=4 }

local function EquippedArmorForSlot(slotName)
  local bestToken, bestOrder = nil, 0
  local function check(token)
    local slotID = GetInventorySlotInfo(token)
    if not slotID then return end
    local link = GetInventoryItemLink("player", slotID)
    if not link then return end
    local iid = GetItemInfoInstant(link)
    if not iid then return end

    local tok = ArmorTokenForItemID(iid)
    local ord = tok and ARMOR_ORDER[tok] or 0
    if ord > bestOrder then
      bestOrder, bestToken = ord, tok
    end
  end

  if slotName == "Finger0Slot" or slotName == "Finger1Slot" or slotName == "Trinket0Slot" or slotName == "Trinket1Slot" then
    return nil
  end

  check(slotName)
  return bestToken
end

local function ShouldSkipLighterArmor(slotName, candidateArmorTok, eqArmorTok, eqScore, candScore)
  if not candidateArmorTok or not eqArmorTok then return false end
  if not PREF_NATIVE_ARMOR then return false end
  local major =
    (slotName == "ChestSlot" or
     slotName == "LegsSlot"  or
     slotName == "HeadSlot"  or
     slotName == "ShoulderSlot")

  if not major then
    return false
  end

  local candOrd = ARMOR_ORDER[candidateArmorTok] or 0
  local eqOrd   = ARMOR_ORDER[eqArmorTok] or 0
  if candOrd >= eqOrd then
    return false
  end

  local lvl = UnitLevel("player") or 1
  local THRESH
  if lvl < 20 then
    THRESH = 0.50
  elseif lvl < 40 then
    THRESH = 0.35
  else
    THRESH = 0.20
  end
  if (candScore or 0) >= (eqScore or 0) * 1.15 then
    return false
  end
  if (candScore or 0) > (eqScore or 0) and (eqScore or 0) < 0.6 then
    return false
  end

  return (candScore or 0) < (eqScore + THRESH)
end

function ArmorBias(entry)
  if not entry or not entry.armor then return 0 end
  if not PREF_NATIVE_ARMOR then return 0 end

  local _, class = UnitClass("player")
  local lvl = UnitLevel("player") or 1
  local role, band = RolePhase(class, lvl)

  if role=="MELEE" then
    if band==1 then return (entry.armor=="MAIL" or entry.armor=="PLATE" or entry.armor=="LEATHER") and 1.0 or 0
    elseif band==2 then return (entry.armor=="MAIL" or entry.armor=="PLATE") and 1.0 or 0
    else return (entry.armor=="PLATE") and 1.0 or 0 end

  elseif role=="HYBRID" then
    if band==1 then return (entry.armor=="LEATHER" or entry.armor=="MAIL") and 1.0 or 0
    elseif band==2 then return (entry.armor=="MAIL") and 0.75 or 0
    else return (entry.armor=="MAIL") and 0.25 or 0 end

  elseif role=="CASTER" then
    if band==1 then return 0
    elseif band==2 then return (entry.armor=="CLOTH") and 0.5 or 0
    else return (entry.armor=="CLOTH") and 0.25 or 0 end
  end
  return 0
end

function WeaponBias(entry)
  if not entry or not entry.invType then return 0 end
  if not (entry.invType:find("WEAPON") or entry.invType:find("RANGED") or entry.invType=="INVTYPE_SHIELD" or entry.invType=="INVTYPE_HOLDABLE") then
    return 0
  end
  local _, class = UnitClass("player")
  local line = WeaponLineForItem(entry.itemID)

  if entry.invType == "INVTYPE_SHIELD" then
    if class=="WARRIOR" or class=="PALADIN" or class=="SHAMAN" then return 0.6 else return -999 end
  end
  if class=="ROGUE" then
    if line=="Daggers" then return 1.0 end
    if line=="One-Handed Swords" or line=="One-Handed Maces" or line=="One-Handed Axes" then return 0.4 end
    return 0
  elseif class=="WARRIOR" then
    if line=="Two-Handed Axes" or line=="Two-Handed Swords" or line=="Two-Handed Maces" then return 0.5 end
    if line=="One-Handed Swords" or line=="One-Handed Maces" or line=="One-Handed Axes" then return 0.3 end
    return 0
  elseif class=="PALADIN" then
    if line=="One-Handed Maces" or line=="Two-Handed Maces" then return 0.5 end
    if line=="One-Handed Swords" then return 0.3 end
    if line=="Two-Handed Swords" then return 0.2 end
    if line=="One-Handed Axes" or line=="Two-Handed Axes" then return 0.2 end
    return 0
  elseif class=="HUNTER" then
    if line=="Bows" or line=="Guns" or line=="Crossbows" then return 1.0 end
    return 0
  elseif class=="SHAMAN" then
    if line=="One-Handed Maces" or line=="One-Handed Axes" then return 0.5 end
    return 0
  elseif class=="DRUID" then
    if line=="Staves" then return 0.6 end
    return 0
  elseif class=="PRIEST" or class=="MAGE" or class=="WARLOCK" then
    if line=="Staves" then return 0.6 end
    if line=="Wands"  then return 0.4 end
    return 0
  end
  return 0
end


local function WeaponSkillAllows(entry)
  if not entry or not entry.itemID then return true end
  local invType = entry.invType or select(9, GetItemInfo(entry.itemID)) or ""
  if not (invType:find("WEAPON") or invType:find("RANGED")) then
    return true
  end
  local _, _, _, _, _, _, itemSubType = GetItemInfo(entry.itemID)
  if not itemSubType then
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(entry.itemID) end
    return true
  end
  local me = UnitLevel("player") or 1
  if me < 10 then return true end
  if MakersPath and MakersPath.Util and MakersPath.Util.CanUseItemSubType then
    local ok = MakersPath.Util.CanUseItemSubType(itemSubType)
    if ok ~= nil then return ok end
  end
  return true
end

-- ==============================
-- Dual wield gating for offhand
-- ==============================
local function HasDualWield()
  if IsPlayerSpell then
    if IsPlayerSpell(674) then
      return true
    end
    return false
  end

  local _, classTag = UnitClass("player")
  local lvl = UnitLevel("player") or 1

  if classTag == "ROGUE" and lvl >= 10 then
    return true
  end
  if (classTag == "WARRIOR" or classTag == "HUNTER") and lvl >= 20 then
    return true
  end
  if classTag == "SHAMAN" and lvl >= 40 then
    return true
  end
  return false
end

local function IsEquippedTwoHander()
  local slotId = GetInventorySlotInfo("MainHandSlot")
  if not slotId then return false end
  local link = GetInventoryItemLink("player", slotId)
  if not link then return false end
  local _, _, _, _, _, _, _, _, invType = GetItemInfo(link)
  return invType == "INVTYPE_2HWEAPON"
end

local function CanUseAsOffhand(entry, slotName)
  if slotName ~= "SecondaryHandSlot" then
    return true
  end
  if not entry or not entry.itemID then
    return true
  end

  local inv = entry.invType
  if not inv then
    inv = select(9, GetItemInfo(entry.itemID))
  end
  if not inv then
    return true
  end

  if inv == "INVTYPE_SHIELD" or inv == "INVTYPE_HOLDABLE" then
    return true
  end

  if inv == "INVTYPE_WEAPON"
     or inv == "INVTYPE_WEAPONOFFHAND"
     or inv == "INVTYPE_WEAPONMAINHAND"
  then
    if IsEquippedTwoHander() then
      return false
    end

    if not HasDualWield() then
      DBG("deny DualWield", entry.itemID or "nil")
      return false
    end
  end

  return true
end

-- ==============================
-- Slot mapping (includes Ammo)
-- ==============================
local SLOT_TO_INV = {
  HeadSlot          = { "INVTYPE_HEAD" },
  NeckSlot          = { "INVTYPE_NECK" },
  ShoulderSlot      = { "INVTYPE_SHOULDER" },
  BackSlot          = { "INVTYPE_CLOAK" },
  ChestSlot         = { "INVTYPE_CHEST","INVTYPE_ROBE" },
  WristSlot         = { "INVTYPE_WRIST" },
  HandsSlot         = { "INVTYPE_HAND" },
  WaistSlot         = { "INVTYPE_WAIST" },
  LegsSlot          = { "INVTYPE_LEGS" },
  FeetSlot          = { "INVTYPE_FEET" },
  Finger0Slot       = { "INVTYPE_FINGER" },
  Finger1Slot       = { "INVTYPE_FINGER" },
  Trinket0Slot      = { "INVTYPE_TRINKET" },
  Trinket1Slot      = { "INVTYPE_TRINKET" },
  MainHandSlot      = { "INVTYPE_WEAPON","INVTYPE_WEAPONMAINHAND","INVTYPE_2HWEAPON" },
  SecondaryHandSlot = { "INVTYPE_WEAPON","INVTYPE_WEAPONOFFHAND","INVTYPE_SHIELD","INVTYPE_HOLDABLE" },
  RangedSlot        = { "INVTYPE_RANGED","INVTYPE_RANGEDRIGHT","INVTYPE_RELIC" },
  AmmoSlot          = { "INVTYPE_AMMO","INVTYPE_THROWN" },
}

local function KeysForSlot(slotName) return SLOT_TO_INV[slotName] or {} end
local function InvTypeMatchesSlot(invType, slotName)
  local keys = KeysForSlot(slotName)
  for i=1,#keys do if keys[i]==invType then return true end end
  return false
end

-- ==============================
-- Candidates (runtime + static)
-- ==============================
local function CandidatesForSlot(slotName)
  local out, seen = {}, {}
  local db = GDB()

  for invType, list in pairs(db.items) do
    if InvTypeMatchesSlot(invType, slotName) and type(list)=="table" then
      for _, row in ipairs(list) do
        local id = row.itemID or row.id
        if id and not seen[id] then
          seen[id]  = true
          row.invType  = row.invType or invType
          row.reqLevel = row.reqLevel or row.minLevel or 0
          row.source   = row.source or "crafted"
          row.armor    = row.armor or MakersPath.Util.ArmorTokenForItemID(row.itemID)
          if IsCraftedLike(row) then
            AugmentNeedHave(row)
            out[#out+1] = row
          end
        end
      end
    end
  end

  for invType, list in pairs(db.buckets) do
    if InvTypeMatchesSlot(invType, slotName) and type(list)=="table" then
      for _, e in ipairs(list) do
        local id = e.itemID
        if id and not seen[id] then
          seen[id]=true
          local rec = db.itemRecords[id]
          local cand = {
            itemID   = id,
            name     = rec and rec.name or nil,
            invType  = invType,
            reqLevel = (rec and (rec.reqLevel or rec.minLevel)) or 0,
            reqSkill = (rec and (rec.profId or rec.reqSkill)) or 0,
            armor    = rec and rec.armor or nil,
            source   = rec and rec.source or nil,
            isCrafted = rec and rec.isCrafted or nil,
          }
          if IsCraftedLike(cand) then
            AugmentNeedHave(cand)
            out[#out+1] = cand
          end
        end
      end
    end
  end

  local static = MakersPath and MakersPath.Static and MakersPath.Static.Craftables or {}
  for invType, list in pairs(static) do
    if InvTypeMatchesSlot(invType, slotName) and type(list)=="table" then
      for _, row in ipairs(list) do
        local id = row.itemID or row.id
        if id and not seen[id] then
          seen[id] = true
          row.invType = row.invType or invType
          AugmentNeedHave(row)
          out[#out+1] = row
        end
      end
    end
  end

  return out
end

-- ==============================
-- Count (status line)
-- ==============================
function GearFinder:GetIndexedCount()
  local n = 0
  local db = GDB().items
  for _, list in pairs(db) do
    if type(list) == "table" then n = n + #list end
  end
  local static = MakersPath and MakersPath.Static and MakersPath.Static.Craftables or {}
  for _, list in pairs(static) do
    if type(list) == "table" then n = n + #list end
  end
  return n
end

-- ==============================
-- “Best next” window (cap)
-- ==============================
local function FutureCap()
  return (MakersPath and MakersPath.FutureWindow) or 1
end

local function RealRequiredLevel(entry)
  if not entry then return 0 end
  local iid = entry.itemID

  if iid then
    local _, _, _, _, reqLevel = GetItemInfo(iid)
    if type(reqLevel) == "number" and reqLevel > 0 then
      return reqLevel
    end
    if C_Item and C_Item.RequestLoadItemDataByID then
      C_Item.RequestLoadItemDataByID(iid)
    end
  end

  local learned = tonumber(entry.reqSkillLevel or entry.learnedAt or entry.skill or 0) or 0
  if learned > 0 then
    return math.max(1, math.floor(learned / 10))
  end

  return tonumber(entry.reqLevel or entry.minLevel or 0) or 0
end

local function withinCap(entry)
  local me  = UnitLevel("player") or 1
  local cap = FutureCap()
  local req = RealRequiredLevel(entry)
  if req <= 0 then return true end
  return req <= (me + cap)
end

local function LevelBias(entry)
  if not entry then return 0 end
  local me  = UnitLevel("player") or 1
  local cap = FutureCap()
  local req = RealRequiredLevel(entry)

  if req <= 0 then return 0 end
  local maxReq = me + cap
  if req > maxReq then return 0 end
  local t = (req - me) / math.max(1, cap)
  if t < 0 then t = 0 end
  local BIAS_MAX = 0.5
  return t * BIAS_MAX
end


-- ==============================
-- Value gate: skip cosmetic/statless pieces
-- ==============================
local PRIMARY_KEYS = {
  ITEM_MOD_STRENGTH=true, ITEM_MOD_AGILITY=true, ITEM_MOD_INTELLECT=true, ITEM_MOD_STAMINA=true,
  ITEM_MOD_SPIRIT=true, ITEM_MOD_SPELL_POWER=true, ITEM_MOD_SPELL_HEALING_DONE=true,
  ITEM_MOD_MANA_REGENERATION=true, ITEM_MOD_ATTACK_POWER=true, ITEM_MOD_RANGED_ATTACK_POWER=true,
  ITEM_MOD_CRIT_RATING=true, ITEM_MOD_CRIT_SPELL_RATING=true, ITEM_MOD_HIT_RATING=true, ITEM_MOD_HIT_SPELL_RATING=true,
}

local function _ItemStats(iid)
  return GetItemStatsTable(iid)
end

local function HasAnyPrimaryStat(stats)
  local mstats = NormalizeToMaker(stats or {})
  local keys = {
    "STRENGTH","AGILITY","STAMINA","INTELLECT","SPIRIT",
    "ATTACK_POWER","RANGED_ATTACK_POWER",
    "SPELL_DAMAGE_DONE","SPELL_HEALING_DONE",
    "MANA_REGENERATION","CRIT","CRIT_SPELL","HIT","HIT_SPELL",
  }
  for _,k in ipairs(keys) do
    if (tonumber(mstats[k] or 0) or 0) > 0 then
      return true
    end
  end
  return false
end

local function HasValueForSlot(slotName, iid)
  if not iid then return false end
  if slotName == "AmmoSlot" then return true end

  local stats = _ItemStats(iid)
  if not stats then return true end

  local armor = PickArmor(stats)
  local dps   = PickDPS(stats)
  local any   = HasAnyPrimaryStat(stats)

  if slotName == "MainHandSlot" then
    return (tonumber(dps) or 0) > 0
  end

  if slotName == "RangedSlot" then
    return (tonumber(dps) or 0) > 0
  end

  if slotName == "SecondaryHandSlot" then
    local inv = select(9, GetItemInfo(iid)) or ""
    if inv:find("WEAPON") or inv:find("RANGED") then
      return (tonumber(dps) or 0) > 0
    else
      return (tonumber(armor) or 0) > 0 or any
    end
  end

  if slotName == "NeckSlot"
     or slotName == "Finger0Slot"
     or slotName == "Finger1Slot"
     or slotName == "Trinket0Slot"
     or slotName == "Trinket1Slot" then
    return any
  end
  return (tonumber(armor) or 0) > 0 or any
end


-- ==============================
-- Equipped score (per-slot; handles ring/trinket pairs)
-- ==============================
local function GetEquippedScore(slotName)
  local cache = GearFinder._equippedScoreCache or {}
  GearFinder._equippedScoreCache = cache
  if cache[slotName] then
    return cache[slotName].score, cache[slotName].ids, cache[slotName].pending, cache[slotName].dbg
  end

  local equippedIDs, best, pending = {}, 0, false
  local dbglist = {}
  local function pushByToken(token)
    local slotId = GetInventorySlotInfo(token)
    if not slotId then return end
    local link = GetInventoryItemLink("player", slotId)
    if not link then return end
    local iid = GetItemInfoInstant(link)
    if iid then equippedIDs[iid] = true end
  end

  if slotName == "Finger0Slot" or slotName == "Finger1Slot" then
    pushByToken("Finger0Slot")
    pushByToken("Finger1Slot")
  elseif slotName == "Trinket0Slot" or slotName == "Trinket1Slot" then
    pushByToken("Trinket0Slot")
    pushByToken("Trinket1Slot")
  else
    pushByToken(slotName)
  end

  for iid in pairs(equippedIDs) do
    local total, pend, breakdown = ScoreItemWithBreakdown(iid, slotName)
    if pend then pending = true end
    dbglist[#dbglist+1] = { kind="equipped", total = total, br = breakdown}
    if total > best then best = total end
  end

  cache[slotName] = { score = best, ids = equippedIDs, pending = pending, dbg = dbglist }
  return best, equippedIDs, pending, dbglist
end

-- ==============================
-- Tiebreaker
-- ==============================
local function betterTiebreak(a, b)
  local ra = tonumber(a.reqLevel or a.minLevel or 0) or 0
  local rb = tonumber(b.reqLevel or b.minLevel or 0) or 0
  if ra ~= rb then return ra < rb end

  local invA = a.invType or select(9, GetItemInfo(a.itemID)) or ""
  local invB = b.invType or select(9, GetItemInfo(b.itemID)) or ""
  local wepA = invA:find("WEAPON") or invA:find("RANGED") or invA=="INVTYPE_HOLDABLE" or invA=="INVTYPE_SHIELD"
  local wepB = invB:find("WEAPON") or invB:find("RANGED") or invB=="INVTYPE_HOLDABLE" or invB=="INVTYPE_SHIELD"

  if not (ONLY_STATS_WEAPONS and (wepA or wepB)) then
    local ba = ArmorBias(a)
    local bb = ArmorBias(b)
    if ba ~= bb then return ba > bb end
  end

  local na = (a.name and 1 or 0)
  local nb = (b.name and 1 or 0)
  if na ~= nb then return na > nb end

  return (a.itemID or 0) < (b.itemID or 0)
end

local function CraftSourceMakesSense(entry)
  if not entry then return false end
  if entry.source == "crafted" or entry.isCrafted then
    return true
  end
  local pid = tonumber(entry.reqSkill or entry.profId or 0) or 0
  if pid > 0 then
    return true
  end

  local inv = entry.invType or select(9, GetItemInfo(entry.itemID)) or ""
  if inv == "" then
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(entry.itemID) end
    return true
  end

  if inv:find("WEAPON") or inv:find("RANGED") or inv=="INVTYPE_SHIELD" or inv=="INVTYPE_HOLDABLE" or inv=="INVTYPE_RELIC" then
    return true
  end
  return true
end

function ProfessionBias(entry)
  local pmap = MakersPath.Util and MakersPath.Util.CurrentProfMap() or {}
  local pid  = tonumber(entry.reqSkill or entry.profId or 0) or 0
  if pid ~= 0 then
    for _ in pairs(pmap) do
      return 0.5
    end
  end
  return 0
end

function GatherBias(entry)
  local pmap = MakersPath.Util and MakersPath.Util.CurrentProfMap() or {}
  local has = function(spellID) return pmap[spellID] ~= nil end
  local T = {
    LW   = 2108, SKIN = 8613,
    ALC  = 2259, HERB = 2366,
    BS   = 2018, ENG  = 4036, MINE = 2575,
  }
  local pid = tonumber(entry.reqSkill or entry.profId or 0) or 0
  if pid == 165 and has(T.SKIN)        then return 0.2 end
  if pid == 171 and has(T.HERB)        then return 0.2 end
  if (pid == 164 or pid == 202) and has(T.MINE) then return 0.2 end
  return 0
end

local SKILLLINE_TO_SPELL = {
  [164] = 2018,  -- Blacksmithing
  [165] = 2108,  -- Leatherworking
  [171] = 2259,  -- Alchemy
  [197] = 3908,  -- Tailoring
  [202] = 4036,  -- Engineering
  [333] = 7411,  -- Enchanting
  -- gather/secondary
  [186] = 2575,  -- Mining
  [182] = 2366,  -- Herbalism
  [393] = 8613,  -- Skinning
  [185] = 2550,  -- Cooking
  [356] = 7620,  -- Fishing
  [129] = 3273,  -- First Aid
}
local SPELL_TO_SKILLLINE = {}
for k,v in pairs(SKILLLINE_TO_SPELL) do SPELL_TO_SKILLLINE[v] = k end

local function ResolveSkillLineId(id)
  id = tonumber(id or 0) or 0
  if SKILLLINE_TO_SPELL[id] then return id end
  if SPELL_TO_SKILLLINE[id] then return SPELL_TO_SKILLLINE[id] end
  return 0
end

local function CurrentRankFor(profIdOrSpell)
  local pmap = MakersPath.Util and MakersPath.Util.CurrentProfMap() or {}
  local raw  = tonumber(profIdOrSpell or 0) or 0
  local r = pmap[raw]
  if r then
    return tonumber(r) or 0
  end
  local spellFromSkill = SKILLLINE_TO_SPELL and SKILLLINE_TO_SPELL[raw]
  if spellFromSkill and pmap[spellFromSkill] then
    return tonumber(pmap[spellFromSkill]) or 0
  end
  local skillFromSpell = SPELL_TO_SKILLLINE and SPELL_TO_SKILLLINE[raw]
  if skillFromSpell and SKILLLINE_TO_SPELL and SKILLLINE_TO_SPELL[skillFromSpell] then
    local spellAgain = SKILLLINE_TO_SPELL[skillFromSpell]
    if pmap[spellAgain] then
      return tonumber(pmap[spellAgain]) or 0
    end
  end
  return 0
end

function AugmentNeedHave(entry)
  if not entry then return end

  local pid  = tonumber(entry.profId or entry.reqSkill or 0) or 0
  local need = tonumber(entry.reqSkillLevel or entry.skillReq or entry.learnedAt or 0) or 0

  if pid > 0 then
    local skillLine = ResolveSkillLineId(pid)
    local profSpellId

    if skillLine ~= 0 then
      profSpellId = SKILLLINE_TO_SPELL[skillLine]
    else
      profSpellId = pid
    end

    local haveRank = CurrentRankFor(pid) or 0

    local pmap    = MakersPath.Util and MakersPath.Util.CurrentProfMap() or {}
    local hasProf = (profSpellId ~= nil and pmap[profSpellId] ~= nil) or false

    entry.__profSkillLine = (skillLine ~= 0) and skillLine or nil
    entry.__profSpellID   = profSpellId
    entry.__profId        = entry.__profSkillLine
    entry.__needRank      = need
    entry.__haveRank      = haveRank
    entry.__hasProfession = hasProf
  else
    entry.__profSkillLine = nil
    entry.__profSpellID   = nil
    entry.__profId        = nil
    entry.__needRank      = nil
    entry.__haveRank      = 0
    entry.__hasProfession = false
  end
end

SLASH_MPAUGTEST1 = "/mpaugtest"
SlashCmdList["MPAUGTEST"] = function(msg)
  local itemID, profId, need = msg:match("^(%d+)%s+(%d+)%s+(%d+)")
  if not itemID then
    print("|cff66ccff[Maker's Path]|r Usage: /mpaugtest <itemID> <profIdOrSkillLine> <needRank>")
    return
  end

  itemID = tonumber(itemID)
  profId = tonumber(profId)
  need   = tonumber(need)

  local e = {
    itemID        = itemID,
    profId        = profId,
    reqSkillLevel = need,
  }

  AugmentNeedHave(e)

  local spellName = (e.__profSpellID and GetSpellInfo(e.__profSpellID)) or "?"
  print(string.format(
    "|cff66ccff[Maker's Path]|r item=%d prof=%s (%d) need=%d have=%d hasProf=%s",
    itemID,
    spellName,
    e.__profSkillLine or 0,
    e.__needRank or 0,
    e.__haveRank or 0,
    tostring(e.__hasProfession)
  ))
end

-- ==============================
-- Best-next selection
-- ==============================
ALT_MAX_COUNT = 3
ALT_MIN_RELATIVE = 0.80
local EPS = 0.01

local function EquippedMinReqLevel(equippedIDs)
  if not equippedIDs then return 0 end
  local minReq = nil
  for iid in pairs(equippedIDs) do
    if iid then
      local _, _, _, _, reqLevel = GetItemInfo(iid)
      if type(reqLevel) == "number" and reqLevel > 0 then
        if not minReq or reqLevel < minReq then
          minReq = reqLevel
        end
      end
    end
  end
  return minReq or 0
end

function GearFinder:GetBestCraftable(slotName)
  local eqScore, equippedIDs, eqPending = GetEquippedScore(slotName)
  local eqReqLevel = EquippedMinReqLevel(equippedIDs)
  local cs = CandidatesForSlot(slotName)
  local eqArmorTok = EquippedArmorForSlot(slotName)
  for i = 1, math.min(20, #cs) do
    if cs[i].itemID then GetItemInfo(cs[i].itemID) end
  end

  if eqPending then
    if self._equippedScoreCache then self._equippedScoreCache[slotName] = nil end
    C_Timer.After(0.15, function()
      if MakersPath and MakersPath.GearFinderScan then MakersPath.GearFinderScan() end
      if MakersPathFrame and MakersPathFrame:IsShown() and RefreshList then RefreshList() end
    end)
    return nil, 0, eqScore or 0, nil
  end

  -- DIAG counters
  local diag = {
    total=0, inv_match=0, craftedlike=0, notbogus=0, prof=0, value=0, cap=0,
    filters_ok=0, pending=0, equippedskip=0, lighterarmor=0,
  }
  local strictCandidates   = {}
  local futureCandidates   = {}

  local function consider_entry(entry, wantStrictUpgrade, curBestScore, bucket)
    diag.total = diag.total + 1
    AugmentNeedHave(entry)

    if not entry.invType or not InvTypeMatchesSlot(entry.invType, slotName) then
      local equipLoc = select(9, GetItemInfo(entry.itemID))
      if equipLoc then entry.invType = entry.invType or equipLoc end
      if not (entry.invType and InvTypeMatchesSlot(entry.invType, slotName)) then
        return nil
      end
    end
    diag.inv_match = diag.inv_match + 1

    if not IsCraftedLike(entry) then return nil else diag.craftedlike=diag.craftedlike+1 end
    if LooksBogus(entry) then return nil else diag.notbogus=diag.notbogus+1 end
    if IsEngineeringOnlyTool(entry) then return nil end
    if not WeaponSkillAllows(entry) then return nil else diag.prof=diag.prof+1 end
    if not CanUseAsOffhand(entry, slotName) then return nil end
    if equippedIDs and equippedIDs[entry.itemID] then diag.equippedskip=diag.equippedskip+1; return nil end
    if not HasValueForSlot(slotName, entry.itemID) then return nil else diag.value=diag.value+1 end
    if not withinCap(entry) then return nil else diag.cap=diag.cap+1 end

    if not entry.armor then entry.armor = ArmorTokenForItemID(entry.itemID) end

    local total, pend, br = ScoreItemWithBreakdown(entry.itemID, slotName, entry.armor, entry.invType)
    if pend then
      diag.pending = diag.pending + 1

      if not _pendingKick[slotName] then
        _pendingKick[slotName] = true
        C_Timer.After(0.25, function()
          _pendingKick[slotName] = nil
          if MakersPath and MakersPath.GearFinderScan then MakersPath.GearFinderScan() end
          if MakersPathFrame and MakersPathFrame:IsShown() and RefreshList then RefreshList() end
        end)
      end
      return nil
    end
    local lvlBonus = LevelBias(entry)
    if lvlBonus ~= 0 then
      total = total + lvlBonus
      if br then br.levelAdd = lvlBonus end
    end
    if eqArmorTok and entry.armor then
      if ShouldSkipLighterArmor(slotName, entry.armor, eqArmorTok, eqScore or 0, total or 0) then
        diag.lighterarmor = diag.lighterarmor + 1
        return nil
      end
    end

    do
      local _, class = UnitClass("player")
      if class=="MAGE" or class=="PRIEST" or class=="WARLOCK" then
        local inv = entry.invType or ""
        if IsArmorish(inv) then
          local candStats = GetItemStatsTable(entry.itemID)
          if candStats then
            local lvl = UnitLevel("player") or 1
            local hasPrim = casterHasPrimaries(candStats)
            local isJewelry = (inv=="INVTYPE_NECK" or inv=="INVTYPE_FINGER" or inv=="INVTYPE_TRINKET")
            local isCloak   = (inv=="INVTYPE_CLOAK")

            if isJewelry and not hasPrim then
              return nil
            end
            if isCloak and lvl >= 20 and not hasPrim then
              return nil
            end

            if lvl >= 12 then
              local candINT = tonumber(candStats.ITEM_MOD_INTELLECT or 0) or 0
              local eqINT   = EquippedStatForSlot(slotName, "ITEM_MOD_INTELLECT") or 0
              if candINT < eqINT then
                local candSP    = math.max(tonumber(candStats.ITEM_MOD_SPELL_POWER or 0) or 0, tonumber(candStats.ITEM_MOD_SPELL_HEALING_DONE or 0) or 0)
                local candHitS  = tonumber(candStats.ITEM_MOD_HIT_SPELL_RATING or 0) or 0
                local candCritS = tonumber(candStats.ITEM_MOD_CRIT_SPELL_RATING or 0) or 0

                local intLoss   = (eqINT - candINT)
                local paid      = (candSP * 0.67) + (candHitS * 1.0) + (candCritS * 0.83)
                local threshold = (lvl < 40) and intLoss or (intLoss * 0.85)

                if paid < threshold then
                  return nil
                end
              end
            end
          end
        end
      end
    end

    if (not GetIgnoreFilters()) and Filters and Filters.IsAllowed then
      if not Filters:IsAllowed(entry) then
        return nil
      end
    end
    diag.filters_ok = diag.filters_ok + 1

    if wantStrictUpgrade then
      local eq = eqScore or 0
      local cand = total or 0
      if cand <= eq + EPS then
        return nil
      end
    end

    entry.__dbg = { kind="candidate", total=total, br=br }
    if bucket then
      bucket[#bucket+1] = { entry = entry, score = total }
    end
    return total
  end

  local function buildAlts(bucket, bestEntry, bestScore, eqScore)
    if not bestEntry or not bestScore or bestScore <= 0 then return nil end
    if not bucket or #bucket == 0 then return nil end
    table.sort(bucket, function(a, b)
      return (a.score or 0) > (b.score or 0)
    end)

    local out = {}
    local eq = eqScore or 0
    for _, rec in ipairs(bucket) do
      if rec.entry ~= bestEntry then
        local s = rec.score or 0
        if s > eq + EPS and s >= bestScore * ALT_MIN_RELATIVE then
          out[#out+1] = rec.entry
          if #out >= ALT_MAX_COUNT then
            break
          end
        end
      end
    end
    if #out == 0 then return nil end
    return out
  end

  local best, bestScore
  local list = CandidatesForSlot(slotName)

  for _, entry in ipairs(list) do
    local s = consider_entry(entry, true, bestScore, strictCandidates)
    if s and (not bestScore or s > bestScore or (s == bestScore and betterTiebreak(entry, best))) then
      best, bestScore = entry, s
    end
  end
  if best then
    local alts = buildAlts(strictCandidates, best, bestScore or 0, eqScore or 0)
    DBG("GF["..slotName.."] diag:", "tot="..diag.total, "inv="..diag.inv_match, "crafted="..diag.craftedlike, "okbogus="..diag.notbogus,
        "prof="..diag.prof, "value="..diag.value, "cap="..diag.cap, "pend="..diag.pending, "lighter="..diag.lighterarmor,
        "eqskip="..diag.equippedskip, "filtOK="..diag.filters_ok)
    return best, bestScore or 0, eqScore or 0, alts
  end

  local futureBest, futureBestScore
  for _, entry in ipairs(list) do
    local s = consider_entry(entry, false, futureBestScore, futureCandidates)
    if s and (not futureBestScore or s > futureBestScore or (s == futureBestScore and betterTiebreak(entry, futureBest))) then
      futureBest, futureBestScore = entry, s
    end
  end

  DBG("GF["..slotName.."] diag:", "tot="..diag.total, "inv="..diag.inv_match, "crafted="..diag.craftedlike, "okbogus="..diag.notbogus,
      "prof="..diag.prof, "value="..diag.value, "cap="..diag.cap, "pend="..diag.pending, "lighter="..diag.lighterarmor,
      "eqskip="..diag.equippedskip, "filtOK="..diag.filters_ok)

  if futureBest and (futureBestScore or 0) > (eqScore or 0) + EPS then
    local alts = buildAlts(futureCandidates, futureBest, futureBestScore or 0, eqScore or 0)
    return futureBest, futureBestScore or 0, eqScore or 0, alts
  end

  return nil, 0, eqScore or 0, nil
end

-- ==============================
-- Summary for UI
-- ==============================
function GearFinder:BuildSummary()
  if not self._summaryDirty and self._lastSummary then
    return self._lastSummary
  end

  local t0 = debugprofilestop()
  self:BeginSession()

  local slots = {
    "HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot",
    "HandsSlot","WaistSlot","LegsSlot","FeetSlot",
    "Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot",
    "MainHandSlot","SecondaryHandSlot","RangedSlot","AmmoSlot",
  }

  local rows = {}
  local slowestSlot, slowestTime = nil, 0

  for _, slotName in ipairs(slots) do
    local s0 = debugprofilestop()

    local best, bestScore, eqScore, alts = self:GetBestCraftable(slotName)
    local pct = 0
    if bestScore and bestScore > 0 then
      pct = math.max(0, math.min(1, (eqScore or 0) / bestScore))
    end
    if best then best.eqScore = eqScore end
    rows[#rows+1] = {
      slot      = slotName,
      best      = best,
      bestScore = bestScore or 0,
      eqScore   = eqScore or 0,
      progress  = pct,
      alts      = alts,
    }

    local sdt = debugprofilestop() - s0
    if sdt > slowestTime then
      slowestTime, slowestSlot = sdt, slotName
    end
  end

  local dt = debugprofilestop() - t0
  if MakersPath.Config.DEBUG_TIMING then
    print(string.format(
      "|cff66ccff[Maker'sPath]|r BuildSummary %.1f ms; slowest %s = %.1f ms",
      dt, tostring(slowestSlot), slowestTime
    ))
  end

  self._lastSummary = rows
  self._summaryDirty = false
  return rows
end

-- ==============================
-- Warm cache helper
-- ==============================
MakersPath.GearFinderScan = MakersPath.GearFinderScan or function()
  local probe = {
    "HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot",
    "HandsSlot","WaistSlot","LegsSlot","FeetSlot",
    "Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot",
    "MainHandSlot","SecondaryHandSlot","RangedSlot","AmmoSlot",
  }
  for _, slot in ipairs(probe) do
    local candidates = CandidatesForSlot(slot)
    for i = 1, math.min(25, #candidates) do 
      local id = candidates[i].itemID
      if id then GetItemInfo(id) end
    end
  end
end

-- ==============================
-- Debug dump
-- ==============================
SLASH_MPGF1 = "/mpgf"
SlashCmdList["MPGF"] = function(msg)
  local arg = msg and msg:lower():match("^%s*(%S+)")
  local slots = {
    HeadSlot="HeadSlot", NeckSlot="NeckSlot", ShoulderSlot="ShoulderSlot", BackSlot="BackSlot",
    ChestSlot="ChestSlot", WristSlot="WristSlot", HandsSlot="HandsSlot", WaistSlot="WaistSlot",
    LegsSlot="LegsSlot", FeetSlot="FeetSlot", Finger0Slot="Finger0Slot", Finger1Slot="Finger1Slot",
    Trinket0Slot="Trinket0Slot", Trinket1Slot="Trinket1Slot",
    MainHandSlot="MainHandSlot", SecondaryHandSlot="SecondaryHandSlot", RangedSlot="RangedSlot", AmmoSlot="AmmoSlot",
  }

  local function dumpFor(slotName)
    _say("=== Slot:", slotName, "===")
    local eqScore, eqIDs, eqPending, dbgEquipped = GetEquippedScore(slotName)
    if eqPending then _say("equipped pending data; rerun shortly") end
    _say("equipped total:", string.format("%.2f", eqScore or 0))
    if dbgEquipped then
      for _,row in ipairs(dbgEquipped) do
        local br = row.br or {}
        local name = select(1, GetItemInfo(br.iid or 0)) or ("item:"..tostring(br.iid))
        DBG("  EQ", name, "tot=", string.format("%.2f", row.total or 0),
            " base=", string.format("%.2f", br.base or 0),
            " +armor=", string.format("%.2f", br.armorAdd or 0),
            " +dps=", string.format("%.2f", br.dpsAdd or 0),
            " +bias[a,w,p,g]=", string.format("%.2f", br.biasArmor or 0)..","..
                                string.format("%.2f", br.biasWeap or 0)..","..
                                string.format("%.2f", br.biasProf or 0)..","..
                                string.format("%.2f", br.biasGather or 0),
            " tok=", tostring(br.armorTok), "inv=", tostring(br.invType))
      end
    end

    local best, bestScore = MakersPath.GearFinder:GetBestCraftable(slotName)
    if not best then
      _say("no craftable upgrade for", slotName)
      return
    end
    local bname = best.name or (GetItemInfo(best.itemID) or ("item:"..tostring(best.itemID)))
    local br = (best.__dbg and best.__dbg.br) or {}

    _say("BEST", bname, "tot=", string.format("%.2f", bestScore or 0), "vs eq=", string.format("%.2f", eqScore or 0))
    DBG("   base=", string.format("%.2f", br.base or 0), " +armor=", string.format("%.2f", br.armorAdd or 0),
      " +dps=", string.format("%.2f", br.dpsAdd or 0), " +bias[a,w,p,g]=", string.format("%.2f", br.biasArmor or 0)..","..
      string.format("%.2f", br.biasWeap or 0)..",".. string.format("%.2f", br.biasProf or 0)..",".. string.format("%.2f", br.biasGather or 0),
      " tok=", tostring(br.armorTok), "inv=", tostring(br.invType))
  end

  if arg == "all" or arg == nil then
    for _,sn in ipairs({
      "HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot",
      "HandsSlot","WaistSlot","LegsSlot","FeetSlot",
      "Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot",
      "MainHandSlot","SecondaryHandSlot","RangedSlot","AmmoSlot",
    }) do dumpFor(sn) end
  else
    local map = {
      head="HeadSlot", neck="NeckSlot", shoulder="ShoulderSlot", back="BackSlot",
      chest="ChestSlot", wrist="WristSlot", hands="HandsSlot", waist="WaistSlot",
      legs="LegsSlot", feet="FeetSlot", finger0="Finger0Slot", finger1="Finger1Slot",
      trinket0="Trinket0Slot", trinket1="Trinket1Slot", mainhand="MainHandSlot",
      offhand="SecondaryHandSlot", secondary="SecondaryHandSlot", ranged="RangedSlot", ammo="AmmoSlot"
    }
    local sn = slots[arg] or map[arg]
    if sn then dumpFor(sn) else DBG("unknown slot:", arg) end
  end
end

SLASH_MPCOUNT1 = "/mpcount"
SlashCmdList["MPCOUNT"] = function()
  local db = GDB()
  local function count(tbl)
    local n=0; for _ in pairs(tbl or {}) do n=n+1 end; return n
  end
  print("|cff66ccff[Maker'sPath]|r items INVTYPE buckets:")
  for invType, list in pairs(db.items or {}) do
    print("  ", invType, "=", type(list)=="table" and #list or 0)
  end
  print("|cff66ccff[Maker'sPath]|r dynamic buckets:")
  for invType, list in pairs(db.buckets or {}) do
    print("  ", invType, "=", type(list)=="table" and #list or 0)
  end
end
-- replace your MPGFLIST handler body with:
SLASH_MPGFLIST1 = "/mpgflist"
SlashCmdList["MPGFLIST"] = function(arg)
  local slot, limit = (arg or ""):match("^(%S+)"), tonumber((arg or ""):match("%s+(%d+)$"))
  slot  = slot or "MainHandSlot"
  limit = limit or 30

  local seen = {}
  local count = 0
  for _, e in ipairs(CandidatesForSlot(slot)) do
    if e.itemID and not seen[e.itemID] then
      seen[e.itemID] = true
      local name = GetItemInfo(e.itemID) or ("item:"..e.itemID)
      local inv  = e.invType or select(9, GetItemInfo(e.itemID)) or "?"
      local stats= (function()
        local link = select(2, GetItemInfo(e.itemID))
        local s = link and GetItemStats(link) or nil
        if not s or next(s) == nil then s = ParseTooltipStatsToTable(e.itemID) end
        return s
      end)()
      local dps = stats and (stats.DPS or stats.DAMAGE_PER_SECOND or stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT) or 0
      local allowed = MakersPath.Filters:IsAllowed(e)
      print(string.format("|cff66ccff[MP:list]|r %s (%s) dps=%.2f allowed=%s", name, inv, dps, tostring(allowed)))
      count = count + 1
      if count >= limit then break end
    end
  end
end
SLASH_MPCLEAN1 = "/mpclean"
SlashCmdList["MPCLEAN"] = function()
  local db = MakersPathGlobalDB or {}
  local changed = 0

  if db.items then
    for inv, list in pairs(db.items) do
      if type(list) == "table" then
        for i=#list,1,-1 do
          local r = list[i]
          if r and not IsCraftedLike(r) then
            table.remove(list, i); changed = changed + 1
          end
        end
      end
    end
  end
  if db.buckets then
    for inv, list in pairs(db.buckets) do
      if type(list) == "table" then
        for i=#list,1,-1 do
          local e = list[i]
          local rec = db.itemRecords and db.itemRecords[e.itemID] or nil
          local tmp = { itemID = e.itemID, source = rec and rec.source, isCrafted = rec and rec.isCrafted }
          if not IsCraftedLike(tmp) then
            table.remove(list, i); changed = changed + 1
          end
        end
      end
    end
  end
  print("|cff66ccff[Maker's Path]|r cleaned "..changed.." non-crafted entries. /reload recommended.")
end
-- ===================== Timing toggle =====================
SLASH_MPTIMING1 = "/mptiming"
SlashCmdList["MPTIMING"] = function()
  MakersPath.Config.DEBUG_TIMING = not MakersPath.Config.DEBUG_TIMING
  print("|cff66ccff[Maker'sPath]|r timing debug is now " .. tostring(MakersPath.Config.DEBUG_TIMING))
end