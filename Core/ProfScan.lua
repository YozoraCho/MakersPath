local ADDON, MakersPath = ...
MakersPath = MakersPath or {}
MakersPath.Util = MakersPath.Util or {}

-- Toggle to keep your roster lean (true = do NOT store Cooking/Fishing/First Aid)
local EXCLUDE_SECONDARIES = false

local PROF = {
  ALCHEMY=2259, BLACKSMITHING=2018, LEATHERWORKING=2108, TAILORING=3908,
  ENGINEERING=4036, ENCHANTING=7411, MINING=2575, HERBALISM=2366, SKINNING=8613,
  COOKING=2550, FISHING=7620, FIRSTAID=3273,
}

local NAME_TO_TOKEN = {
  ["ALCHEMY"]="ALCHEMY", ["BLACKSMITHING"]="BLACKSMITHING", ["LEATHERWORKING"]="LEATHERWORKING",
  ["TAILORING"]="TAILORING", ["ENGINEERING"]="ENGINEERING", ["ENCHANTING"]="ENCHANTING",
  ["MINING"]="MINING", ["HERBALISM"]="HERBALISM", ["SKINNING"]="SKINNING",
  ["COOKING"]="COOKING", ["FISHING"]="FISHING", ["FIRST AID"]="FIRSTAID",
}

local SECONDARY = {
  COOKING=true, FISHING=true, FIRSTAID=true,
}

local WEAPON_LINE_NORMALIZE = {
  ["One-Handed Swords"] = "One-Handed Swords", ["Two-Handed Swords"] = "Two-Handed Swords", ["One-Handed Axes"] = "One-Handed Axes",
  ["Two-Handed Axes"] = "Two-Handed Axes", ["One-Handed Maces"] = "One-Handed Maces", ["Two-Handed Maces"] = "Two-Handed Maces",
  ["Daggers"] = "Daggers", ["Fist Weapons"] = "Fist Weapons", ["Polearms"] = "Polearms", ["Staves"] = "Staves",
  ["Bows"] = "Bows", ["Guns"] = "Guns", ["Crossbows"] = "Crossbows", ["Thrown"] = "Thrown", ["Wands"] = "Wands",
}

local function isWeaponSkillLine(skillName)
  return WEAPON_LINE_NORMALIZE[skillName] ~= nil
end

local SUBTYPE_TO_WEAPONLINE = {
  ["One-Handed Swords"] = "One-Handed Swords", ["Two-Handed Swords"] = "Two-Handed Swords", ["One-Handed Axes"] = "One-Handed Axes",
  ["Two-Handed Axes"] = "Two-Handed Axes", ["One-Handed Maces"] = "One-Handed Maces", ["Two-Handed Maces"] = "Two-Handed Maces",
  ["Daggers"] = "Daggers", ["Fist Weapons"] = "Fist Weapons", ["Polearms"] = "Polearms", ["Staves"] = "Staves",
  ["Bows"] = "Bows", ["Guns"] = "Guns", ["Crossbows"] = "Crossbows", ["Thrown"] = "Thrown", ["Wands"] = "Wands",
}

local function norm(s) return (tostring(s or "")):upper():gsub("%s+"," ") end

local function charKey()
  local name  = UnitName("player") or "?"
  local realm = GetRealmName() or "?"
  return name.."-"..realm
end

local function doScan()
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.chars = MakersPathDB.chars or {}
  local key = charKey()
  local outProfs, outWeps = {}, {}

  local num = GetNumSkillLines and GetNumSkillLines() or 0
  for i = 1, num do
    local skillName, isHeader, _, skillRank = GetSkillLineInfo(i)
    if skillName and not isHeader then
      local token = NAME_TO_TOKEN[norm(skillName)]
      if token and PROF[token] then
        if not (EXCLUDE_SECONDARIES and SECONDARY[token]) then
          outProfs[PROF[token]] = tonumber(skillRank) or 1
        end
      elseif isWeaponSkillLine(skillName) then
        outWeps[WEAPON_LINE_NORMALIZE[skillName]] = tonumber(skillRank) or 1
      end
    end
  end

  local rec = MakersPathDB.chars[key] or {}
  rec.profs = outProfs
  rec.weps = outWeps

  local _, classTag = UnitClass("player")
  rec.class = classTag
  rec.level = UnitLevel("player") or nil
  rec.seen  = time()

  MakersPathDB.chars[key] = rec
end

local pending = false
local function scheduleScan()
  if pending then return end
  pending = true
  C_Timer.After(0.10, function()
    pending = false
    doScan()
  end)
end

function MakersPath.ScanProfessions()
  scheduleScan()
end

-- === Utilities used elsewhere ===
function MakersPath.Util.ProfNames(map)
  local names = {}
  for spellID,_ in pairs(map or {}) do
    local n = GetSpellInfo(spellID) or tostring(spellID)
    names[#names+1] = n
  end
  table.sort(names)
  return names
end

function MakersPath.Util.CurrentProfMap()
  local key = charKey()
  return (MakersPathDB and MakersPathDB.chars and MakersPathDB.chars[key] and MakersPathDB.chars[key].profs) or {}
end

function MakersPath.Util.ParseProfTokens(tokens)
  local map = {}
  local ALIAS = {
    ALCHEMY=PROF.ALCHEMY, ALC=PROF.ALCHEMY,
    BLACKSMITHING=PROF.BLACKSMITHING, BLACKSMITH=PROF.BLACKSMITHING, BS=PROF.BLACKSMITHING,
    LEATHERWORKING=PROF.LEATHERWORKING, LW=PROF.LEATHERWORKING,
    TAILORING=PROF.TAILORING, TAILOR=PROF.TAILORING, TAIL=PROF.TAILORING,
    ENGINEERING=PROF.ENGINEERING, ENG=PROF.ENGINEERING,
    ENCHANTING=PROF.ENCHANTING, ENCH=PROF.ENCHANTING, ENCHANT=PROF.ENCHANTING,
    MINING=PROF.MINING, MINE=PROF.MINING,
    HERBALISM=PROF.HERBALISM, HERB=PROF.HERBALISM,
    SKINNING=PROF.SKINNING, SKIN=PROF.SKINNING,
    COOKING=PROF.COOKING, COOK=PROF.COOKING,
    FISHING=PROF.FISHING, FISH=PROF.FISHING,
    ["FIRSTAID"]=PROF.FIRSTAID, FA=PROF.FIRSTAID,
  }
  for _,t in ipairs(tokens or {}) do
    local id = ALIAS[norm(t)]
    if id then map[id] = 1 end
  end
  return map
end

function MakersPath.Util.GetAllChars()
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.chars = MakersPathDB.chars or {}
  local out = {}
  for key, rec in pairs(MakersPathDB.chars) do
    local name, realm = key:match("^([^%-]+)%-(.+)$")
    out[#out+1] = {
      key   = key,
      name  = name or key,
      realm = realm,
      class = rec.class,
      level = rec.level,
      seen  = rec.seen,
      profs = rec.profs or {},
    }
  end
  table.sort(out, function(a,b)
    if (a.realm or "") ~= (b.realm or "") then
      return (a.realm or "") < (b.realm or "")
    end
    return (a.name or "") < (b.name or "")
  end)
  return out
end

MakersPath.Util.WEAPON_LINE_FROM_SUBTYPE = SUBTYPE_TO_WEAPONLINE

function MakersPath.Util.CanUseItemSubType(itemSubType)
  if not itemSubType or itemSubType == "" then return true end
  local weps = MakersPath.Util.CurrentWeaponSkills()
  local line = SUBTYPE_TO_WEAPONLINE[itemSubType]
  if not line then return true end
  return weps[line] ~= nil
end

function MakersPath.Util.CurrentWeaponMap()
  local key = charKey()
  return (MakersPathDB and MakersPathDB.chars and MakersPathDB.chars[key] and MakersPathDB.chars[key].weps) or {}
end

function MakersPath.Util.CurrentWeaponSkills()
  return MakersPath.Util.CurrentWeaponMap()
end

-- Events
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("SKILL_LINES_CHANGED")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:SetScript("OnEvent", scheduleScan)