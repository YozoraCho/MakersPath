local ADDON, MakersPath = ...
MakersPath = MakersPath or {}
MakersPath.Util = MakersPath.Util or {}
local C = MakersPath.Const or {}
local SKILLLINE_TO_SPELL = C.SKILLLINE_TO_SPELL or {}

local PROF_BY_ID = {}
if SKILLLINE_TO_SPELL then
  for skillLineID, spellID in pairs(SKILLLINE_TO_SPELL) do
    PROF_BY_ID[skillLineID] = spellID
  end
end

local PROF_NAME_TO_SPELL = {}
do
  local src = SKILLLINE_TO_SPELL or {}
  for _, spellID in pairs(src) do
    local n = GetSpellInfo(spellID)
    if n and n ~= "" then
      PROF_NAME_TO_SPELL[n] = spellID
    end
  end
end
PROF_NAME_TO_SPELL["Herbalism"] = (SKILLLINE_TO_SPELL and SKILLLINE_TO_SPELL[182]) or 2366

local function _sanitizeRoster()
  MakersPathDB = MakersPathDB or {}; MakersPathDB.chars = MakersPathDB.chars or {}
  local fixes = 0
  for k, v in pairs(MakersPathDB.chars) do
    if type(k) ~= "string" or type(v) ~= "table" then
      MakersPathDB.chars[k] = nil
      fixes = fixes +1
    end
  end
  if fixes > 0 then
    print("|cff00ccff[Maker's Path]|r cleaned "..fixes.." invalid roster entr"..(fixes==1 and "y" or "ies")..".")
  end
end

local WEAPON_SUB_IDS = {}
if C.WEAPON_SUB then
  for _, subId in pairs(C.WEAPON_SUB) do
    table.insert(WEAPON_SUB_IDS, subId)
  end
end

local WEAPON_LINE_SET
local SUBTYPE_TO_WEAPONLINE

local function BuildWeaponLocaleTables()
  if WEAPON_LINE_SET then return end
  WEAPON_LINE_SET = {}
  SUBTYPE_TO_WEAPONLINE = {}

  local itemClassWeapons = 2
  for _, subId in ipairs(WEAPON_SUB_IDS) do
    local localizedSubtype = GetItemSubClassInfo(itemClassWeapons, subId)
    if localizedSubtype and localizedSubtype ~= "" then
      WEAPON_LINE_SET[localizedSubtype] = true
      SUBTYPE_TO_WEAPONLINE[localizedSubtype] = localizedSubtype
    end
  end

  local unarmedName = GetSpellInfo(203)
  if unarmedName and unarmedName ~= "" then
    WEAPON_LINE_SET[unarmedName] = true
  end
end

local function isWeaponSkillLine(localizedSkillName)
  BuildWeaponLocaleTables()
  return localizedSkillName and WEAPON_LINE_SET and WEAPON_LINE_SET[localizedSkillName] == true
end

MakersPath.Util.WEAPON_LINE_FROM_SUBTYPE = function(itemSubType)
  BuildWeaponLocaleTables()
  return SUBTYPE_TO_WEAPONLINE and SUBTYPE_TO_WEAPONLINE[itemSubType]
end

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

  local realProfSkillLines = {}
  if GetProfessions and GetProfessionInfo then
    local p1, p2, p3, p4, p5, p6 = GetProfessions()
    local plist = { p1, p2, p3, p4, p5, p6 }
    for _, idx in ipairs(plist) do
      if idx then
        local _, _, skillLine = GetProfessionInfo(idx)
        if skillLine then
          realProfSkillLines[skillLine] = true
        end
      end
    end
  end

  local num = GetNumSkillLines and GetNumSkillLines() or 0
  for i = 1, num do
    local skillName, isHeader, _, skillRank, _, _, maybeSkillLineID = GetSkillLineInfo(i)
    if not isHeader then
      local rank = tonumber(skillRank) or 0
      if rank > 0 and skillName and skillName ~= "" then
        local weaponLine = isWeaponSkillLine(skillName)
        if weaponLine then
          outWeps[skillName] = rank
        else
          local profSpell = PROF_NAME_TO_SPELL[skillName]
          if profSpell then
            outProfs[profSpell] = rank
          else
            if maybeSkillLineID and realProfSkillLines[maybeSkillLineID] and PROF_BY_ID[maybeSkillLineID] then
              outProfs[PROF_BY_ID[maybeSkillLineID]] = rank
            end
          end
        end
      end
    end
  end

  local rec = MakersPathDB.chars[key] or {}
  rec.profs = outProfs
  rec.weps  = outWeps

  local _, classTag = UnitClass("player")
  rec.class = classTag
  rec.level = UnitLevel("player") or rec.level
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
  local map = {}

  if GetProfessions and GetProfessionInfo then
    local p1, p2, p3, p4, p5, p6 = GetProfessions()
    local list = { p1, p2, p3, p4, p5, p6 }

    for _, profIndex in ipairs(list) do
      if profIndex then
        local name, icon, skillLine, rank = GetProfessionInfo(profIndex)
        local spellId = SKILLLINE_TO_SPELL[skillLine]
        if spellId and rank and rank > 0 then
          map[spellId] = rank
        end
      end
    end
  end

  local empty = true
  for _ in pairs(map) do
    empty = false
    break
  end

  if empty then
    MakersPathDB       = MakersPathDB or {}
    MakersPathDB.chars = MakersPathDB.chars or {}
    local key          = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    local rec          = MakersPathDB.chars[key]

    if rec and rec.profs then
      for spellId, rank in pairs(rec.profs) do
        if rank and rank > 0 then
          map[spellId] = rank
        end
      end
    end
  end

  return map
end

SLASH_MPPROFMAP1 = "/mpprofmap"
SlashCmdList["MPPROFMAP"] = function()
  local p = MakersPath.Util.CurrentProfMap()
  print("|cff66ccff[Maker's Path]|r CurrentProfMap dump:")
  local any = false
  for id, r in pairs(p) do
    any = true
    local name = GetSpellInfo(id) or "?"
    print(string.format("  %d -> %s (%d)", id, name, r or 0))
  end
  if not any then
    print("  (no entries)")
  end
end

function MakersPath.Util.CurrentWeaponMap()
  MakersPathDB         = MakersPathDB or {}
  MakersPathDB.chars   = MakersPathDB.chars or {}
  local key            = charKey()
  MakersPathDB.chars[key] = MakersPathDB.chars[key] or {}

  local rec = MakersPathDB.chars[key]
  rec.weps = rec.weps or {}

  return rec.weps
end

function MakersPath.Util.CurrentWeaponSkills()
  return MakersPath.Util.CurrentWeaponMap()
end

function MakersPath.Util.CanUseItemSubType(itemSubType)
  if not itemSubType or itemSubType == "" then return true end
  BuildWeaponLocaleTables()
  local line = SUBTYPE_TO_WEAPONLINE[itemSubType]
  if not line then return true end
  local weps = MakersPath.Util.CurrentWeaponSkills()
  return weps[line] ~= nil
end

-- Events
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("SKILL_LINES_CHANGED")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:SetScript("OnEvent", function(_, ev)
  if ev == "PLAYER_LOGIN" then _sanitizeRoster() end
  scheduleScan()
end)