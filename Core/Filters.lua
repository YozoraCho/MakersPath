local ADDON, MakersPath = ...
MakersPath             = MakersPath or {}
MakersPath.Config      = MakersPath.Config or {}
MakersPath.Filters     = MakersPath.Filters or {}
local F                = MakersPath.Filters
local FILTER_PROF_REQUIRED = true
if MakersPath and MakersPath.Config and type(MakersPath.Config.FILTER_EQUIP_PROF_REQUIRED) == "boolean" then
  FILTER_PROF_REQUIRED = MakersPath.Config.FILTER_EQUIP_PROF_REQUIRED
end
local C = MakersPath.Const or {}


local function MPDBG(...)
  if not (MakersPath and MakersPath.Config and MakersPath.Config.DEBUG_GF) then return end
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts+1] = tostring(select(i, ...)) end
  local msg = table.concat(parts, " ")
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Maker'sPath:Filters]|r "..msg)
  else
    print("[Maker'sPath:Filters] "..msg)
  end
end
local DBG = _G.DBG or MPDBG


-- ================= Helpers =================
local function playerClass()
  local _, class = UnitClass("player")
  return class
end

local function playerLevel()
  return UnitLevel("player") or 1
end

local function GetClassSubClass(itemID)
  local equipLoc, classID, subclassID
  if C_Item and C_Item.GetItemInfoInstant then
    local _, _, _, invType, _, cID, scID = C_Item.GetItemInfoInstant(itemID)
    equipLoc, classID, subclassID = invType, cID, scID
  else
    local _, _, _, _, _, _, _, _, invType, _, _, cID, scID = GetItemInfo(itemID)
    equipLoc, classID, subclassID = invType, cID, scID
  end
  return classID, subclassID, equipLoc
end

local function ItemIsOkForPlayerClass(_)
  return true
end

-- Hidden Scanner
local MPScanTT = MPScanTT or CreateFrame("GameTooltip", "MPScanTT", UIParent, "GameTooltipTemplate")
MPScanTT:SetOwner(UIParent, "ANCHOR_NONE")

local NAME_TO_SKILLLINE = {}
do
  for skillLineID, spellID in pairs(C.SKILLLINE_TO_SPELL or {}) do
    local name = GetSpellInfo(spellID)
    if name and name ~= "" then
      NAME_TO_SKILLLINE[name] = skillLineID
    end
  end
end

local function ScanEquipProfession(itemID)
  if not itemID then return nil end
  local link = select(2, GetItemInfo(itemID))
  if not link then
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return nil
  end

  MPScanTT:ClearLines()
  MPScanTT:SetHyperlink(link)

  for i = 2, MPScanTT:NumLines() do
    local line = _G["MPScanTTTextLeft"..i]
    local text = line and line:GetText() or ""
    if text and text ~= "" then
      local needed = text:match("%((%d+)%)")
      if needed then
        needed = tonumber(needed) or 0
        for profName, skillLineID in pairs(NAME_TO_SKILLLINE) do
          if text:find(profName, 1, true) then
            return skillLineID, needed
          end
        end
      end
    end
  end
  return nil
end

local function ProfessionEquipOk(itemID)
  if not FILTER_PROF_REQUIRED then return true end
  local skillLineID, needed = ScanEquipProfession(itemID)
  if not skillLineID then return true end

  local pmap = MakersPath.Util and MakersPath.Util.CurrentProfMap and MakersPath.Util.CurrentProfMap() or {}
  local have = 0

  if pmap[skillLineID] then
    have = tonumber(pmap[skillLineID]) or 0
  else
    local spell = C.SKILLLINE_TO_SPELL and C.SKILLLINE_TO_SPELL[skillLineID]
    if spell and pmap[spell] then have = tonumber(pmap[spell]) or 0 end
  end

  return have >= (tonumber(needed) or 0)
end

local ALL_SUBS = {
  C.WEAPON_SUB.ONE_HAND_AXES,
  C.WEAPON_SUB.TWO_HAND_AXES,
  C.WEAPON_SUB.BOWS,
  C.WEAPON_SUB.GUNS,
  C.WEAPON_SUB.ONE_HAND_MACES,
  C.WEAPON_SUB.TWO_HAND_MACES,
  C.WEAPON_SUB.POLEARMS,
  C.WEAPON_SUB.ONE_HAND_SWORDS,
  C.WEAPON_SUB.TWO_HAND_SWORDS,
  C.WEAPON_SUB.STAVES,
  C.WEAPON_SUB.FIST_WEAPONS,
  C.WEAPON_SUB.DAGGERS,
  C.WEAPON_SUB.THROWN,
  C.WEAPON_SUB.SPEARS,
  C.WEAPON_SUB.CROSSBOWS,
  C.WEAPON_SUB.WANDS,
}

local function set_of(...)
  local t = {}; for i=1,select("#", ...) do t[select(i, ...)] = true end; return t
end

local function build_never(allowed_set)
  local never = {}
  for _, sub in ipairs(ALL_SUBS) do
    if sub ~= nil and not allowed_set[sub] then
      never[sub] = true
    end
  end
  return never
end

local ALLOW = {}

ALLOW.ROGUE = set_of(
  C.WEAPON_SUB.DAGGERS,
  C.WEAPON_SUB.ONE_HAND_SWORDS,
  C.WEAPON_SUB.ONE_HAND_MACES,
  C.WEAPON_SUB.FIST_WEAPONS,
  C.WEAPON_SUB.THROWN,
  C.WEAPON_SUB.BOWS, C.WEAPON_SUB.GUNS, C.WEAPON_SUB.CROSSBOWS
)

ALLOW.DRUID = set_of(
  C.WEAPON_SUB.STAVES,
  C.WEAPON_SUB.ONE_HAND_MACES, C.WEAPON_SUB.TWO_HAND_MACES,
  C.WEAPON_SUB.DAGGERS,
  C.WEAPON_SUB.FIST_WEAPONS
)

ALLOW.HUNTER = set_of(
  C.WEAPON_SUB.BOWS, C.WEAPON_SUB.CROSSBOWS, C.WEAPON_SUB.GUNS,
  C.WEAPON_SUB.ONE_HAND_SWORDS, C.WEAPON_SUB.TWO_HAND_SWORDS,
  C.WEAPON_SUB.ONE_HAND_AXES,   C.WEAPON_SUB.TWO_HAND_AXES,
  C.WEAPON_SUB.FIST_WEAPONS,
  C.WEAPON_SUB.SPEARS,
  C.WEAPON_SUB.DAGGERS,
  C.WEAPON_SUB.STAVES,
  C.WEAPON_SUB.THROWN
)

ALLOW.MAGE = set_of(
  C.WEAPON_SUB.STAVES,
  C.WEAPON_SUB.WANDS,
  C.WEAPON_SUB.DAGGERS,
  C.WEAPON_SUB.ONE_HAND_SWORDS
)

ALLOW.PALADIN = set_of(
  C.WEAPON_SUB.ONE_HAND_AXES, C.WEAPON_SUB.TWO_HAND_AXES,
  C.WEAPON_SUB.ONE_HAND_MACES, C.WEAPON_SUB.TWO_HAND_MACES,
  C.WEAPON_SUB.ONE_HAND_SWORDS, C.WEAPON_SUB.TWO_HAND_SWORDS,
  C.WEAPON_SUB.POLEARMS
)

ALLOW.PRIEST = set_of(
  C.WEAPON_SUB.ONE_HAND_MACES,
  C.WEAPON_SUB.DAGGERS,
  C.WEAPON_SUB.STAVES,
  C.WEAPON_SUB.WANDS
)

ALLOW.SHAMAN = set_of(
  C.WEAPON_SUB.STAVES,
  C.WEAPON_SUB.FIST_WEAPONS,
  C.WEAPON_SUB.DAGGERS,
  C.WEAPON_SUB.ONE_HAND_AXES, C.WEAPON_SUB.TWO_HAND_AXES,
  C.WEAPON_SUB.ONE_HAND_MACES, C.WEAPON_SUB.TWO_HAND_MACES
)

ALLOW.WARLOCK = set_of(
  C.WEAPON_SUB.WANDS,
  C.WEAPON_SUB.STAVES,
  C.WEAPON_SUB.DAGGERS,
  C.WEAPON_SUB.ONE_HAND_SWORDS
)

ALLOW.WARRIOR = set_of(
  C.WEAPON_SUB.ONE_HAND_AXES,  C.WEAPON_SUB.TWO_HAND_AXES,
  C.WEAPON_SUB.BOWS,           C.WEAPON_SUB.GUNS,          C.WEAPON_SUB.CROSSBOWS,
  C.WEAPON_SUB.ONE_HAND_MACES, C.WEAPON_SUB.TWO_HAND_MACES,
  C.WEAPON_SUB.POLEARMS,       C.WEAPON_SUB.SPEARS,
  C.WEAPON_SUB.ONE_HAND_SWORDS, C.WEAPON_SUB.TWO_HAND_SWORDS,
  C.WEAPON_SUB.STAVES,
  C.WEAPON_SUB.FIST_WEAPONS,
  C.WEAPON_SUB.DAGGERS,
  C.WEAPON_SUB.THROWN
)

local HARD_NEVER = {
  ROGUE   = build_never(ALLOW.ROGUE),
  DRUID   = build_never(ALLOW.DRUID),
  HUNTER  = build_never(ALLOW.HUNTER),
  MAGE    = build_never(ALLOW.MAGE),
  PALADIN = build_never(ALLOW.PALADIN),
  PRIEST  = build_never(ALLOW.PRIEST),
  SHAMAN  = build_never(ALLOW.SHAMAN),
  WARLOCK = build_never(ALLOW.WARLOCK),
  WARRIOR = build_never(ALLOW.WARRIOR),
}

local function IsWand(entry)
  if not entry or not entry.itemID then return false end
  local _, subID, inv = GetClassSubClass(entry.itemID)
  if inv == "INVTYPE_RANGEDRIGHT" then return true end
  return (C and C.WEAPON_SUB and subID == C.WEAPON_SUB.WANDS) or false
end

local function HardNeverForClass(entry)
  if not entry or not entry.itemID then return false end
  local _, classTag = UnitClass("player")

  local _, _, inv = GetClassSubClass(entry.itemID)
  if not inv then inv = select(9, GetItemInfo(entry.itemID)) end
  if not inv then return false end
  if not (inv:find("WEAPON") or inv == "INVTYPE_HOLDABLE" or inv == "INVTYPE_SHIELD"
       or inv == "INVTYPE_RANGED" or inv == "INVTYPE_RANGEDRIGHT" or inv == "INVTYPE_THROWN") then
    return false
  end

  if inv == "INVTYPE_SHIELD" and not (classTag=="WARRIOR" or classTag=="PALADIN" or classTag=="SHAMAN") then
    return true
  end
  if IsWand(entry) and not (classTag=="MAGE" or classTag=="PRIEST" or classTag=="WARLOCK") then
    return true
  end

  local never = HARD_NEVER[classTag]
  if not never then return false end
  if not C.WEAPON_SUB or next(C.WEAPON_SUB) == nil then
    return false
  end

  local _, subclassID = GetClassSubClass(entry.itemID)
  return (subclassID ~= nil) and (never[subclassID] == true)
end



-- ================= Armor & Shield Gating =================
local function allowedArmorFor(class, lvl)
  local allow = { CLOTH = true }
  if class == "MAGE" or class == "PRIEST" or class == "WARLOCK" then return allow end
  if class == "ROGUE" or class == "DRUID" then allow.LEATHER = true; return allow end
  if class == "HUNTER" or class == "SHAMAN" then allow.LEATHER = true; if lvl >= 40 then allow.MAIL = true end; return allow end
  if class == "WARRIOR" or class == "PALADIN" then allow.LEATHER = true; allow.MAIL = true; if lvl >= 40 then allow.PLATE = true end; return allow end
  allow.LEATHER = true; return allow
end

local SHIELD_OK = { WARRIOR=true, PALADIN=true, SHAMAN=true }

local ARMOR_TOKEN_FROM_SUB = {
  [1] = "CLOTH",
  [2] = "LEATHER",
  [3] = "MAIL",
  [4] = "PLATE",
}

local function ArmorTokenFromItem(itemID)
  if not itemID then return nil end
  local _, _, _, _, _, classID, subID = GetItemInfoInstant(itemID)
  if classID == 4 then
    return ARMOR_TOKEN_FROM_SUB[subID]
  end
  return nil
end

function F:ArmorOkForClass(entry)
  if not entry then return false end

  local class = playerClass()
  local lvl   = playerLevel()

  local inv = entry.invType
  if not inv and entry.itemID then
    inv = select(9, GetItemInfo(entry.itemID))
  end
  if inv == "INVTYPE_SHIELD" then
    return SHIELD_OK[class] or false
  end

  local armorToken = entry.armor
  if not armorToken and entry.itemID then
    armorToken = ArmorTokenFromItem(entry.itemID)
  end
  if not armorToken then
    return true
  end

  local allow = allowedArmorFor(class, lvl)
  return allow[armorToken] or false
end

-- ================= Ammo / Ranged Gating =================
local RANGED_ALLOWED = {
  HUNTER  = { [C.WEAPON_SUB.BOWS]=true, [C.WEAPON_SUB.GUNS]=true, [C.WEAPON_SUB.CROSSBOWS]=true, [C.WEAPON_SUB.THROWN]=false, [C.WEAPON_SUB.WANDS]=false },
  ROGUE   = { [C.WEAPON_SUB.BOWS]=true, [C.WEAPON_SUB.GUNS]=true, [C.WEAPON_SUB.CROSSBOWS]=true, [C.WEAPON_SUB.THROWN]=true },
  WARRIOR = { [C.WEAPON_SUB.BOWS]=true, [C.WEAPON_SUB.GUNS]=true, [C.WEAPON_SUB.CROSSBOWS]=true, [C.WEAPON_SUB.THROWN]=true },
  MAGE    = { [C.WEAPON_SUB.WANDS]=true },
  PRIEST  = { [C.WEAPON_SUB.WANDS]=true },
  WARLOCK = { [C.WEAPON_SUB.WANDS]=true },
  DRUID   = {},
  SHAMAN  = {},
  PALADIN = {},
}

local function HasRangedThatUsesAmmo()
  local slot = GetInventorySlotInfo("RangedSlot")
  if not slot then return false end
  local link = GetInventoryItemLink("player", slot)
  if not link then return false end
  local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(link)
  return subClassID and (subClassID == C.WEAPON_SUB.BOWS or subClassID == C.WEAPON_SUB.GUNS or subClassID == C.WEAPON_SUB.CROSSBOWS)
end

local function RangedOkForClass(entry)
  if not entry or not entry.itemID then return true end
  local _, subclassID, inv = GetClassSubClass(entry.itemID)
  if not inv then inv = select(9, GetItemInfo(entry.itemID)) end
  if not inv then return true end

  local _, classTag = UnitClass("player")

  if (not C.WEAPON_SUB) or (next(C.WEAPON_SUB) == nil) then
    if inv == "INVTYPE_RANGEDRIGHT" then
      return (classTag=="MAGE" or classTag=="PRIEST" or classTag=="WARLOCK")
    elseif inv == "INVTYPE_RANGED" then
      return (classTag=="HUNTER" or classTag=="ROGUE" or classTag=="WARRIOR")
    elseif inv == "INVTYPE_THROWN" then
      return (classTag=="ROGUE" or classTag=="WARRIOR")
    end
    return true
  end

  if inv=="INVTYPE_AMMO" then
    local hasAmmoRanged = HasRangedThatUsesAmmo()
    return hasAmmoRanged
  elseif inv=="INVTYPE_THROWN" or inv=="INVTYPE_RANGED" or inv=="INVTYPE_RANGEDRIGHT" then
    local allow = RANGED_ALLOWED[classTag] or {}
    return allow[subclassID] == true
  end
  return true
end


-- ================= Weapon Gating (non-ranged) =================
local ALLOW_BY_CLASS = {
  MAGE    = { [C.WEAPON_SUB.ONE_HAND_SWORDS]=true, [C.WEAPON_SUB.STAVES]=true, [C.WEAPON_SUB.WANDS]=true, [C.WEAPON_SUB.DAGGERS]=true },
  PRIEST  = { [C.WEAPON_SUB.STAVES]=true, [C.WEAPON_SUB.WANDS]=true, [C.WEAPON_SUB.DAGGERS]=true, [C.WEAPON_SUB.ONE_HAND_MACES]=true },
  WARLOCK = { [C.WEAPON_SUB.STAVES]=true, [C.WEAPON_SUB.WANDS]=true, [C.WEAPON_SUB.DAGGERS]=true, [C.WEAPON_SUB.ONE_HAND_SWORDS]=true },
  ROGUE   = { [C.WEAPON_SUB.DAGGERS]=true, [C.WEAPON_SUB.ONE_HAND_SWORDS]=true, [C.WEAPON_SUB.ONE_HAND_MACES]=true, [C.WEAPON_SUB.ONE_HAND_AXES]=true },
}

local function WeaponOkForClass(entry)
  if not entry or not entry.itemID then return true end
  local _, subclassID, inv = GetClassSubClass(entry.itemID)
  if not inv then inv = select(9, GetItemInfo(entry.itemID)) end
  if not inv then
    return true
  end
  if not (inv:find("WEAPON") or inv == "INVTYPE_HOLDABLE" or inv == "INVTYPE_SHIELD"
      or inv == "INVTYPE_RANGED" or inv == "INVTYPE_RANGEDRIGHT") then
    return true
  end

  local _, classTag = UnitClass("player")


  if inv == "INVTYPE_2HWEAPON" and (classTag == "ROGUE" or classTag == "MAGE" or classTag == "PRIEST" or classTag == "WARLOCK") then
    return false
  end

  if not C or not C.WEAPON_SUB or not next(C.WEAPON_SUB) then
    if classTag == "ROGUE" then
      return inv == "INVTYPE_WEAPON" or inv == "INVTYPE_WEAPONMAINHAND" or inv == "INVTYPE_WEAPONOFFHAND" or inv == "INVTYPE_HOLDABLE"
    elseif classTag == "MAGE" or classTag == "PRIEST" or classTag == "WARLOCK" then
      return inv == "INVTYPE_2HWEAPON" or inv == "INVTYPE_WEAPON" or inv == "INVTYPE_WEAPONMAINHAND"
          or inv == "INVTYPE_HOLDABLE" or inv == "INVTYPE_RANGEDRIGHT"
    else
      return true
    end
  end

  if subclassID == nil then
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(entry.itemID) end
    return true
  end
  local allow = ALLOW_BY_CLASS[classTag]
  if not allow then
    return true
  end
  return allow[subclassID] == true
end


-- ================= Proficiency =================
local function WeaponProficiencyOk(entry)
  if not entry or not entry.itemID then return true end
  local _, _, inv = GetClassSubClass(entry.itemID)
  if not inv then inv = select(9, GetItemInfo(entry.itemID)) end
  if not inv then return true end
  if not (inv:find("WEAPON") or inv:find("RANGED") or inv=="INVTYPE_SHIELD" or inv=="INVTYPE_HOLDABLE") then return true end
  if inv=="INVTYPE_SHIELD" then
    local _, c = UnitClass("player")
    return SHIELD_OK[c] or false
  end
  if inv=="INVTYPE_HOLDABLE" then
    return true
  end
  local _, subclassID = GetClassSubClass(entry.itemID)
  if not subclassID then return true end
  if not C.SUBCLASS_TO_LINE or next(C.SUBCLASS_TO_LINE) == nil then
    return true
  end
  local needLine = C.SUBCLASS_TO_LINE[subclassID]
  if not needLine then
    return true
  end
  local me = UnitLevel("player") or 1
  local weps = MakersPath.Util and MakersPath.Util.CurrentWeaponMap and MakersPath.Util.CurrentWeaponMap() or {}
  if me < 10 or not weps then
    return true
  end
  local rank = weps[needLine]
  return (rank and rank > 0) or false
end

-- ================= Level Window =================
function F:LevelOk(entry)
  local me = UnitLevel("player") or 1
  local base = (MakersPath and MakersPath.FutureWindow) or 1
  local req = tonumber(entry and (entry.reqLevel or entry.minLevel)) or 0
  if entry and entry.itemID then
    local _, _, _, _, reqLevel = GetItemInfo(entry.itemID)
    if type(reqLevel)=="number" and reqLevel > 0 then
      req = reqLevel
    else
      if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(entry.itemID)
      end
      req = (req > 0) and req or 999
    end
  end
  return req <= (me + base)
end

-- ================= Master Gate =================
function F:IsAllowed(entry)
  if not entry then return false end
  if HardNeverForClass(entry) then DBG("deny HardNever", entry.itemID) return false end
  if not RangedOkForClass(entry) then DBG("deny Ranged", entry.itemID) return false end
  if not WeaponOkForClass(entry) then DBG("deny WeaponOk", entry.itemID) return false end
  if not WeaponProficiencyOk(entry) then DBG("deny Proficiency", entry.itemID) return false end
  if not self:ArmorOkForClass(entry) then DBG("deny Armor", entry.itemID) return false end
  if not self:LevelOk(entry) then DBG("deny Level", entry.itemID) return false end
  if entry.itemID and not ProfessionEquipOk(entry.itemID) then DBG("deny ProfEquip", entry.itemID) return false end
  return true
end
