local _, MakersPath = ...
local API = MakersPath.API or {}  -- see Core/Compat.lua
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
    local n = API.GetSpellInfo(spellID)
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
local WEAPONLINE_TO_SUBID

local function BuildWeaponLocaleTables()
  if WEAPON_LINE_SET then return end
  WEAPON_LINE_SET = {}
  SUBTYPE_TO_WEAPONLINE = {}
  WEAPONLINE_TO_SUBID = {}

  local itemClassWeapons = 2
  for _, subId in ipairs(WEAPON_SUB_IDS) do
    local localizedSubtype = API.GetItemSubClassInfo(itemClassWeapons, subId)
    if localizedSubtype and localizedSubtype ~= "" then
      WEAPON_LINE_SET[localizedSubtype] = true
      SUBTYPE_TO_WEAPONLINE[localizedSubtype] = localizedSubtype
      WEAPONLINE_TO_SUBID[localizedSubtype] = subId
    end
  end

  local unarmedName = API.GetSpellInfo(203)
  if unarmedName and unarmedName ~= "" then
    WEAPON_LINE_SET[unarmedName] = true
  end
end

local function isWeaponSkillLine(localizedSkillName)
  BuildWeaponLocaleTables()
  return localizedSkillName and WEAPON_LINE_SET and WEAPON_LINE_SET[localizedSkillName] == true
end

function MakersPath.Util.WeaponSubIdFromSkillName(localizedSkillName)
  BuildWeaponLocaleTables()
  return localizedSkillName and WEAPONLINE_TO_SUBID and WEAPONLINE_TO_SUBID[localizedSkillName]
end

MakersPath.Util.WEAPON_LINE_FROM_SUBTYPE = function(itemSubType)
  BuildWeaponLocaleTables()
  return SUBTYPE_TO_WEAPONLINE and SUBTYPE_TO_WEAPONLINE[itemSubType]
end

local function charKey()
  return MakersPath.Util.CurrentCharKey()
end

-- Classic SkillLine IDs for weapon skills. Clients that report a skillID
-- (WoW Forever's C_SkillInfo) are matched by ID, which does not depend on
-- the client language or on skill names matching item subtype names.
local WEAPON_SKILLLINE_TO_SUB = {}
if C.WEAPON_SUB then
  local W = C.WEAPON_SUB
  WEAPON_SKILLLINE_TO_SUB = {
    [44]  = W.ONE_HAND_AXES,   [172] = W.TWO_HAND_AXES,
    [54]  = W.ONE_HAND_MACES,  [160] = W.TWO_HAND_MACES,
    [43]  = W.ONE_HAND_SWORDS, [55]  = W.TWO_HAND_SWORDS,
    [229] = W.POLEARMS,        [136] = W.STAVES,
    [173] = W.DAGGERS,         [473] = W.FIST_WEAPONS,
    [45]  = W.BOWS,            [46]  = W.GUNS,
    [226] = W.CROSSBOWS,       [176] = W.THROWN,
    [228] = W.WANDS,
  }
end

local function doScan()
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.chars = MakersPathDB.chars or {}
  local key = charKey()
  local outProfs, outWeps, outWepsById = {}, {}, {}

  for _, line in ipairs(API.GetSkillLines()) do
    local skillName = line.name
    local rank = tonumber(line.rank) or 0
    if not line.isHeader and rank > 0 and skillName and skillName ~= "" then
      local subId = line.skillID and WEAPON_SKILLLINE_TO_SUB[line.skillID]
      local profSpell = (line.skillID and SKILLLINE_TO_SPELL[line.skillID]) or PROF_NAME_TO_SPELL[skillName]

      if subId then
        -- Key by the item subtype name so CanUseItemSubType() can find it.
        local subName = API.GetItemSubClassInfo and API.GetItemSubClassInfo(C.CLASS_WEAPON or 2, subId)
        outWeps[subName or skillName] = rank
        outWepsById[subId] = rank
      elseif isWeaponSkillLine(skillName) then
        outWeps[skillName] = rank
        local byName = MakersPath.Util.WeaponSubIdFromSkillName(skillName)
        if byName then outWepsById[byName] = rank end
      elseif profSpell then
        outProfs[profSpell] = rank
      end
    end
  end

  -- Professions from the profession API as well, so a collapsed header in
  -- the Skills panel can't hide them.
  for _, p in ipairs(API.GetProfessionList()) do
    local spellId = (p.skillLine and SKILLLINE_TO_SPELL[p.skillLine]) or PROF_NAME_TO_SPELL[p.name or ""]
    local rank = tonumber(p.rank) or 0
    if spellId and rank > (outProfs[spellId] or 0) then
      outProfs[spellId] = rank
    end
  end

  local rec = MakersPathDB.chars[key] or {}
  rec.profs     = outProfs
  rec.weps      = outWeps
  rec.wepsById  = outWepsById

  local _, classTag = UnitClass("player")
  rec.class = classTag
  rec.level = UnitLevel("player") or rec.level
  rec.name  = MakersPath.Util.CurrentCharName and MakersPath.Util.CurrentCharName() or rec.name
  rec.seen  = time()

  MakersPathDB.chars[key] = rec
end

local pending = false
local afterScan = {}
local function scheduleScan(onComplete)
  if onComplete then afterScan[#afterScan+1] = onComplete end
  if pending then return end
  pending = true
  C_Timer.After(0.10, function()
    pending = false
    doScan()
    local callbacks = afterScan
    afterScan = {}
    for _, cb in ipairs(callbacks) do
      local ok, err = pcall(cb)
      if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[Maker's Path]|r scan callback error: " .. tostring(err))
      end
    end
  end)
end

function MakersPath.ScanProfessions(onComplete)
  scheduleScan(onComplete)
end

-- === Utilities used elsewhere ===
function MakersPath.Util.ProfNames(map)
  local names = {}
  for spellID,_ in pairs(map or {}) do
    local n = API.GetSpellInfo(spellID) or tostring(spellID)
    names[#names+1] = n
  end
  table.sort(names)
  return names
end

function MakersPath.Util.CurrentProfMap()
  local map = {}

  -- GetProfessionInfo returns name, icon, rank, maxRank, ..., skillLine (7th);
  -- API.GetProfessionList() unpacks it and handles Forever's 7 slots.
  for _, p in ipairs(API.GetProfessionList()) do
    local spellId = (p.skillLine and SKILLLINE_TO_SPELL[p.skillLine]) or PROF_NAME_TO_SPELL[p.name or ""]
    local rank = tonumber(p.rank) or 0
    if spellId and rank > 0 then
      map[spellId] = rank
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
    local key          = charKey()
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
    local name = API.GetSpellInfo(id) or "?"
    print(string.format("  %d -> %s (%d)", id, name, r or 0))
  end
  if not any then
    print("  (no entries)")
  end
end

SLASH_MPSKILLS1 = "/mpskills"
SlashCmdList["MPSKILLS"] = function()
  print("|cff66ccff[Maker's Path]|r skill lines (name  rank/max  skillID):")
  for i, l in ipairs(API.GetSkillLines()) do
    print(string.format("  %d %s%s  %s/%s  id=%s", i, l.isHeader and "[H] " or "",
      tostring(l.name), tostring(l.rank), tostring(l.maxRank), tostring(l.skillID)))
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

function MakersPath.Util.CurrentWeaponSubIds()
  MakersPathDB         = MakersPathDB or {}
  MakersPathDB.chars   = MakersPathDB.chars or {}
  local key            = charKey()
  MakersPathDB.chars[key] = MakersPathDB.chars[key] or {}

  local rec = MakersPathDB.chars[key]
  rec.wepsById = rec.wepsById or {}

  return rec.wepsById, (next(rec.wepsById) ~= nil)
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