local ADDON, MakersPath = ...
MakersPath = MakersPath or {}

local Filters = MakersPath and MakersPath.Filters

local GearFinder = {}
MakersPath.GearFinder = GearFinder

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

-- ==============================
-- Crafted/bogus guards
-- ==============================
local function IsCraftedLike(entry)
  if not entry then return false end
  if entry.source == "crafted" or entry.isCrafted then return true end
  if tonumber(entry.profId or entry.reqSkill or 0) > 0 then return true end
  return false
end

local function LooksBogus(entry)
  if not entry or not entry.itemID then return true end
  local name = entry.name or GetItemInfo(entry.itemID)
  if name then
    if name:find("^Monster%s*%-")  then return true end
    if name:upper():find("^TEST")  then return true end
  end
  local _, _, _, _, _, itemType, itemSubType = GetItemInfo(entry.itemID)
  if itemType == "Miscellaneous" and (itemSubType == "Junk" or itemSubType == "Other") then
    return true
  end
  return false
end

-- ==============================
-- SavedVariables access (runtime)
-- ==============================
local function GDB()
  MakersPathGlobalDB = MakersPathGlobalDB or {}
  MakersPathGlobalDB.items       = MakersPathGlobalDB.items       or {}
  MakersPathGlobalDB.buckets     = MakersPathGlobalDB.buckets     or {}
  MakersPathGlobalDB.itemRecords = MakersPathGlobalDB.itemRecords or {}
  return MakersPathGlobalDB
end

-- ==============================
-- Scoring
-- ==============================
local CLASS_WEIGHTS = {
  WARRIOR = { STR=1.0, STA=0.6, AGI=0.5, CRIT_RATING=0.4, HIT_RATING=0.5, AP=0.3 },
  PALADIN = { STR=1.0, STA=0.6, INT=0.2, CRIT_RATING=0.35, SPELL_POWER=0.2 },
  HUNTER  = { AGI=1.0, STA=0.5, RAP=0.7, CRIT_RATING=0.5, HIT_RATING=0.6 },
  ROGUE   = { AGI=1.0, STA=0.5, AP=0.8, CRIT_RATING=0.6, HIT_RATING=0.7 },
  PRIEST  = { INT=1.0, STA=0.5, SP=0.9, HEAL=1.0, MP5=0.6, SPIRIT=0.5 },
  SHAMAN  = { INT=0.8, STA=0.5, AGI=0.6, STR=0.6, SP=0.6 },
  MAGE    = { INT=1.0, STA=0.4, SP=1.0, CRIT_SPELL_RATING=0.4, HIT_SPELL_RATING=0.5 },
  WARLOCK = { INT=1.0, STA=0.6, SP=1.0, HIT_SPELL_RATING=0.6, SPIRIT=0.2 },
  DRUID   = { INT=0.7, STA=0.5, AGI=0.7, STR=0.5, SP=0.6 },
}

local STAT_ALIAS = {
  ITEM_MOD_STRENGTH               = "STR",
  ITEM_MOD_AGILITY                = "AGI",
  ITEM_MOD_INTELLECT              = "INT",
  ITEM_MOD_STAMINA                = "STA",
  ITEM_MOD_SPIRIT                 = "SPIRIT",
  ITEM_MOD_ATTACK_POWER           = "AP",
  ITEM_MOD_RANGED_ATTACK_POWER    = "RAP",
  ITEM_MOD_SPELL_POWER            = "SP",
  ITEM_MOD_SPELL_HEALING_DONE     = "HEAL",
  ITEM_MOD_MANA_REGENERATION      = "MP5",
  ITEM_MOD_CRIT_RATING            = "CRIT_RATING",
  ITEM_MOD_CRIT_SPELL_RATING      = "CRIT_SPELL_RATING",
  ITEM_MOD_HIT_RATING             = "HIT_RATING",
  ITEM_MOD_HIT_SPELL_RATING       = "HIT_SPELL_RATING",
}

local function GetClassWeights()
  local _, class = UnitClass("player")
  return CLASS_WEIGHTS[class] or {}
end

local function ScoreFromStats(stats)
  local w = GetClassWeights()
  local score = 0
  for statName, value in pairs(stats or {}) do
    local alias = STAT_ALIAS[statName]
    if alias and w[alias] and tonumber(value) then
      score = score + (value * w[alias])
    end
  end
  return score
end

local ARMOR_COEF = 0.020
local DPS_COEF   = 0.600

local function GetItemScore_ByStats(itemID)
  if not itemID then return 0 end
  local link = select(2, GetItemInfo(itemID))
  if not link then return 0 end
  local stats = GetItemStats(link) or {}

  local score = ScoreFromStats(stats)

  local armor = stats["RESISTANCE0_NAME"] or stats["ITEM_MOD_ARMOR_SHORT"] or stats["ITEM_MOD_ARMOR"] or 0
  if armor and armor > 0 then score = score + (armor * ARMOR_COEF) end

  local dps = stats["DPS"] or stats["DAMAGE_PER_SECOND"] or stats["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"] or 0
  if dps and dps > 0 then score = score + (dps * DPS_COEF) end

  return score
end

-- ==============================
-- Armor / Weapon bias
-- ==============================
local function ArmorTokenFromInfo(itemType, itemSubType)
  local ARMOR = GetItemClassInfo and GetItemClassInfo(4) or "Armor"
  if itemType ~= ARMOR then return nil end
  if itemSubType == (GetItemSubClassInfo and GetItemSubClassInfo(4,1) or "Cloth")   then return "CLOTH" end
  if itemSubType == (GetItemSubClassInfo and GetItemSubClassInfo(4,2) or "Leather") then return "LEATHER" end
  if itemSubType == (GetItemSubClassInfo and GetItemSubClassInfo(4,3) or "Mail")    then return "MAIL" end
  if itemSubType == (GetItemSubClassInfo and GetItemSubClassInfo(4,4) or "Plate")   then return "PLATE" end
  return nil
end

local function ArmorBias(entry)
  if not entry or not entry.armor then return 0 end
  local _, class = UnitClass("player")
  if class == "ROGUE" or class == "DRUID" then
    return (entry.armor == "LEATHER") and 1.5 or 0
  elseif class == "HUNTER" or class == "SHAMAN" then
    return (entry.armor == "MAIL") and 1.5 or 0
  elseif class == "WARRIOR" or class == "PALADIN" then
    local lvl = UnitLevel("player") or 1
    if lvl >= 40 then
      return (entry.armor == "PLATE") and 1.5 or 0
    else
      return (entry.armor == "MAIL") and 1.5 or 0
    end
  elseif class == "MAGE" or class == "PRIEST" or class == "WARLOCK" then
    return (entry.armor == "CLOTH") and 1.5 or 0
  end
  return 0
end

local function WeaponBias(entry)
  if not entry or not entry.invType then return 0 end
  if not (entry.invType:find("WEAPON") or entry.invType:find("RANGED") or entry.invType=="INVTYPE_SHIELD" or entry.invType=="INVTYPE_HOLDABLE") then
    return 0
  end
  local _, class = UnitClass("player")
  local _, _, _, _, _, itemType, itemSubType = GetItemInfo(entry.itemID)
  itemType, itemSubType = itemType or "", itemSubType or ""
  if entry.invType == "INVTYPE_SHIELD" then
    if class=="WARRIOR" or class=="PALADIN" or class=="SHAMAN" then return 0.8 else return -999 end
  end
  if class=="ROGUE" then
    if itemSubType=="Daggers" then return 1.2 end
    if itemSubType=="One-Handed Swords" or itemSubType=="One-Handed Maces" then return 0.6 end
    return 0
  elseif class=="WARRIOR" then
    if itemSubType=="Two-Handed Axes" or itemSubType=="Two-Handed Swords" or itemSubType=="Two-Handed Maces" then return 0.7 end
    if itemSubType=="One-Handed Swords" or itemSubType=="One-Handed Maces" or itemSubType=="One-Handed Axes" then return 0.5 end
    return 0
  elseif class=="PALADIN" then
    if itemSubType=="One-Handed Maces" or itemSubType=="Two-Handed Maces" then return 0.8 end
    if itemSubType=="One-Handed Swords" then return 0.6 end
    return 0
  elseif class=="HUNTER" then
    if itemSubType=="Bows" or itemSubType=="Guns" or itemSubType=="Crossbows" then return 1.2 end
    return 0
  elseif class=="SHAMAN" then
    if itemSubType=="One-Handed Maces" or itemSubType=="One-Handed Axes" then return 0.7 end
    return 0
  elseif class=="DRUID" then
    if itemSubType=="Staves" then return 0.8 end
    return 0
  elseif class=="PRIEST" or class=="MAGE" or class=="WARLOCK" then
    if itemSubType=="Staves" then return 0.8 end
    if itemSubType=="Wands"  then return 0.6 end
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
  if MakersPath and MakersPath.Util and MakersPath.Util.CanUseItemSubType then
    return MakersPath.Util.CanUseItemSubType(itemSubType)
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
  SecondaryHandSlot = { "INVTYPE_WEAPONOFFHAND","INVTYPE_SHIELD","INVTYPE_HOLDABLE" },
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
          out[#out+1]  = row
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
          out[#out+1] = {
            itemID   = id,
            name     = rec and rec.name or nil,
            invType  = invType,
            reqLevel = (rec and (rec.reqLevel or rec.minLevel)) or 0,
            reqSkill = (rec and (rec.profId or rec.reqSkill)) or 0,
            armor    = rec and rec.armor or nil,
            source   = (rec and rec.source) or "crafted",
          }
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
  return (MakersPath and MakersPath.FutureWindow) or 3
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
  if req <= 0 then return false end
  return req <= (me + cap)
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
  local link = select(2, GetItemInfo(iid))
  if not link then
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(iid) end
    return nil
  end
  return GetItemStats(link) or {}
end

local function HasAnyPrimaryStat(stats)
  for k,v in pairs(stats or {}) do
    if PRIMARY_KEYS[k] and (tonumber(v) or 0) > 0 then return true end
  end
  return false
end

local function HasValueForSlot(slotName, iid)
  if not iid then return false end
  if slotName == "AmmoSlot" then return true end

  local stats = _ItemStats(iid)
  if not stats then return false end

  local armor = stats["RESISTANCE0_NAME"] or stats["ITEM_MOD_ARMOR_SHORT"] or stats["ITEM_MOD_ARMOR"] or 0
  local dps   = stats["DPS"] or stats["DAMAGE_PER_SECOND"] or stats["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"] or 0
  local any   = HasAnyPrimaryStat(stats)

  if slotName == "MainHandSlot" or slotName == "SecondaryHandSlot" or slotName == "RangedSlot" then
    return (tonumber(dps) or 0) > 0
  end

  if slotName == "NeckSlot" or slotName == "Finger0Slot" or slotName == "Finger1Slot"
     or slotName == "Trinket0Slot" or slotName == "Trinket1Slot" then
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
    return cache[slotName].score, cache[slotName].ids
  end

  local equippedIDs = {}
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

  local best = 0
  for iid in pairs(equippedIDs) do
    local s = GetItemScore_ByStats(iid) or 0
    if s > best then best = s end
  end

  cache[slotName] = { score = best, ids = equippedIDs }
  return best, equippedIDs
end

-- ==============================
-- Tiebreaker
-- ==============================
local function betterTiebreak(a, b)
  local ra = tonumber(a.reqLevel or a.minLevel or 0) or 0
  local rb = tonumber(b.reqLevel or b.minLevel or 0) or 0
  if ra ~= rb then return ra < rb end

  local ba = ArmorBias(a)
  local bb = ArmorBias(b)
  if ba ~= bb then return ba > bb end

  local na = (a.name and 1 or 0)
  local nb = (b.name and 1 or 0)
  if na ~= nb then return na > nb end

  return (a.itemID or 0) < (b.itemID or 0)
end

local function CraftSourceMakesSense(entry)
  if not entry then return false end
  local pid = tonumber(entry.reqSkill or entry.profId or 0) or 0
  if pid <= 0 then return false end

  local inv   = entry.invType or select(9, GetItemInfo(entry.itemID)) or ""
  local armor = entry.armor
  if armor then
    return (pid == 197) or (pid == 165) or (pid == 164) or (pid == 202)
  end
  if inv:find("WEAPON") or inv:find("RANGED") or inv == "INVTYPE_SHIELD" or inv == "INVTYPE_HOLDABLE" then
    return (pid == 164) or (pid == 202) or (pid == 333)
  end
  return true
end

local function ProfessionBias(entry)
  local pmap = MakersPath.Util and MakersPath.Util.CurrentProfMap() or {}
  local pid  = tonumber(entry.reqSkill or entry.profId or 0) or 0
  if pid ~= 0 then
    for _ in pairs(pmap) do
      return 0.5
    end
  end
  return 0
end

local function GatherBias(entry)
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
  if pmap[raw] then return tonumber(pmap[raw]) or 0 end
  local spell = SKILLLINE_TO_SPELL[raw]
  if spell and pmap[spell] then return tonumber(pmap[spell]) or 0 end
  local skill = SPELL_TO_SKILLLINE[raw]
  if skill and pmap[skill] then return tonumber(pmap[skill]) or 0 end
  return 0
end

local function AugmentNeedHave(entry)
  if not entry then return end
  local pid  = tonumber(entry.profId or entry.reqSkill or 0) or 0
  local need = tonumber(entry.reqSkillLevel or entry.skillReq or entry.learnedAt or 0) or 0
  if pid > 0 then
    local skillLine = ResolveSkillLineId(pid)
    entry.__profId   = (skillLine ~= 0) and skillLine or nil
    entry.__needRank = need
    entry.__haveRank = CurrentRankFor(pid) or 0
  else
    entry.__profId, entry.__needRank, entry.__haveRank = nil, nil, nil
  end
end

-- ==============================
-- Best-next selection
-- ==============================
local EPS = 0.01

function GearFinder:GetBestCraftable(slotName)
  local eqScore, equippedIDs = GetEquippedScore(slotName)

  local best, bestScore = nil, nil

  for _, entry in ipairs(CandidatesForSlot(slotName)) do
    if withinCap(entry) and IsCraftedLike(entry) and CraftSourceMakesSense(entry) and not LooksBogus(entry) and WeaponSkillAllows(entry) then
      if not (equippedIDs and equippedIDs[entry.itemID]) then
        if (not Filters or not Filters.IsAllowed or Filters:IsAllowed(entry)) and HasValueForSlot(slotName, entry.itemID) then
          if not entry.armor then
            local _, _, _, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(entry.itemID)
            entry.invType = entry.invType or equipLoc
            entry.armor   = entry.armor or ArmorTokenFromInfo(itemType, itemSubType)
          end
          AugmentNeedHave(entry)
          local s = (GetItemScore_ByStats(entry.itemID) or 0)
                    + ArmorBias(entry) + WeaponBias(entry)
                    + ProfessionBias(entry) + GatherBias(entry)
          if s > (eqScore + EPS) then
            if not bestScore or s > bestScore or (s == bestScore and betterTiebreak(entry, best)) then
              best, bestScore = entry, s
            end
          end
        end
      end
    end
  end
  if best then return best, bestScore or 0, eqScore or 0 end

  local futureBest, futureBestScore = nil, nil
  for _, entry in ipairs(CandidatesForSlot(slotName)) do
    if withinCap(entry) and IsCraftedLike(entry) and CraftSourceMakesSense(entry) and not LooksBogus(entry) and WeaponSkillAllows(entry) then
      if not (equippedIDs and equippedIDs[entry.itemID]) then
        if (not Filters or not Filters.IsAllowed or Filters:IsAllowed(entry)) and HasValueForSlot(slotName, entry.itemID) then
          if not entry.armor then
            local _, _, _, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(entry.itemID)
            entry.invType = entry.invType or equipLoc
            entry.armor   = entry.armor or ArmorTokenFromInfo(itemType, itemSubType)
          end
          AugmentNeedHave(entry)
          local s = (GetItemScore_ByStats(entry.itemID) or 0)
                    + ArmorBias(entry) + WeaponBias(entry)
                    + ProfessionBias(entry) + GatherBias(entry)
          if not futureBestScore or s > futureBestScore or (s == futureBestScore and betterTiebreak(entry, futureBest)) then
            futureBest, futureBestScore = entry, s
          end
        end
      end
    end
  end

  return futureBest, futureBestScore or 0, eqScore or 0
end

-- ==============================
-- Summary for UI
-- ==============================
function GearFinder:BuildSummary()
  self:BeginSession()

  local slots = {
    "HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot",
    "HandsSlot","WaistSlot","LegsSlot","FeetSlot",
    "Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot",
    "MainHandSlot","SecondaryHandSlot","RangedSlot","AmmoSlot",
  }

  local rows = {}
  for _, slotName in ipairs(slots) do
    local best, bestScore, eqScore = self:GetBestCraftable(slotName)
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
    }
  end
  return rows
end

-- ==============================
-- Warm cache helper (optional)
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
    for i = 1, math.min(10, #candidates) do
      local id = candidates[i].itemID
      if id then GetItemInfo(id) end
    end
  end
end