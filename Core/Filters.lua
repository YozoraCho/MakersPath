local ADDON, MakersPath = ...
MakersPath             = MakersPath or {}
MakersPath.Filters     = MakersPath.Filters or {}
local F                = MakersPath.Filters

-- ================= Helpers =================
local function playerClass()
  local _, class = UnitClass("player")
  return class
end

local function playerLevel()
  return UnitLevel("player") or 1
end

local function reqLevel(entry)
  return tonumber(entry and (entry.reqLevel or entry.minLevel or 0)) or 0
end

local _tt = CreateFrame("GameTooltip", "MakersPathHiddenTT", UIParent, "GameTooltipTemplate")
local function ItemIsOkForPlayerClass(itemID)
  if not itemID then return true end
  _tt:SetOwner(UIParent, "ANCHOR_NONE")
  _tt:SetHyperlink(("item:%d"):format(itemID))

  local _, cls = UnitClass("player")
  cls = tostring(cls or ""):upper()

  for i = 2, _tt:NumLines() do
    local left = _G["MakersPathHiddenTTTextLeft"..i]
    local text = left and left:GetText() or ""
    if text and text ~= "" then
      if text:find("^Classes:") or text:find("^Class:") then
        if not text:upper():find(cls, 1, true) then
          return false
        end
      end
    end
  end
  return true
end

-- ================= Armor & Shield Gating =================
local function allowedArmorFor(class, lvl)
  local allow = { CLOTH = true }  -- everyone can wear cloth in Classic

  if class == "MAGE" or class == "PRIEST" or class == "WARLOCK" then
    return allow
  end
  if class == "ROGUE" or class == "DRUID" then
    allow.LEATHER = true
    return allow
  end
  if class == "HUNTER" or class == "SHAMAN" then
    allow.LEATHER = true
    if lvl >= 40 then allow.MAIL = true end
    return allow
  end
  if class == "WARRIOR" or class == "PALADIN" then
    allow.LEATHER = true
    allow.MAIL    = true
    if lvl >= 40 then allow.PLATE = true end
    return allow
  end
  allow.LEATHER = true
  return allow
end

local SHIELD_OK = { WARRIOR=true, PALADIN=true, SHAMAN=true }

function F:ArmorOkForClass(entry)
  if not entry then return false end

  local class = playerClass()
  local lvl   = playerLevel()

  -- Non-armor slots: allow, except shields restricted by class
  if not entry.armor then
    if entry.invType == "INVTYPE_SHIELD" then
      return SHIELD_OK[class] or false
    end
    return true
  end

  local allow = allowedArmorFor(class, lvl)
  return allow[entry.armor] or false
end

-- ================= Ammo / Ranged Gating =================
local function HasRangedThatUsesAmmo()
  local slotId = GetInventorySlotInfo("RangedSlot")
  if not slotId then return false end
  local link = GetInventoryItemLink("player", slotId)
  if not link then return false end
  local _, _, _, _, _, _, itemSubType = GetItemInfo(link)
  itemSubType = itemSubType or ""
  return (itemSubType=="Bows" or itemSubType=="Guns" or itemSubType=="Crossbows")
end

local _itemTypeCache = setmetatable({}, { __mode = "kv" })
local function GetItemTypeSubType(itemID)
  local rec = _itemTypeCache[itemID]
  if rec then return rec.itemType, rec.itemSubType end
  local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemID)
  if itemType then _itemTypeCache[itemID] = { itemType=itemType, itemSubType=itemSubType } end
  return itemType, itemSubType
end

local RANGED_ALLOWED = {
  HUNTER  = { Bows=true, Guns=true, Crossbows=true },
  ROGUE   = { Bows=true, Guns=true, Crossbows=true, Thrown=true },
  WARRIOR = { Bows=true, Guns=true, Crossbows=true, Thrown=true },

  MAGE    = { Wands=true },
  PRIEST  = { Wands=true },
  WARLOCK = { Wands=true },

  DRUID   = {},
  SHAMAN  = {},
  PALADIN = {},
}

local function RangedOkForClass(entry)
  if not entry or not entry.itemID then return true end
  local inv = entry.invType
  if not inv or inv=="" then return true end

  -- Only gate ranged-ish types
  if inv ~= "INVTYPE_RANGED" and inv ~= "INVTYPE_RANGEDRIGHT"
     and inv ~= "INVTYPE_THROWN" and inv ~= "INVTYPE_AMMO" then
    return true
  end

  local _, class = UnitClass("player")
  local allow = RANGED_ALLOWED[class] or {}

  if inv == "INVTYPE_AMMO" then
    return (allow.Bows or allow.Guns or allow.Crossbows) and HasRangedThatUsesAmmo()
  end

  if inv == "INVTYPE_THROWN" then
    return allow.Thrown == true
  end

  -- RANGED / RANGEDRIGHT (Wands / Bows / Guns / Crossbows)
  local _, sub = GetItemTypeSubType(entry.itemID)
  if not sub or sub=="" then return false end
  return allow[sub] == true
end

-- ================= Weapon Gating (non-ranged) =================
local function WeaponOkForClass(entry)
  if not entry or not entry.itemID then return true end

  local inv = entry.invType
  if not inv then
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(entry.itemID)
    inv = equipLoc
  end
  if not inv then return true end
  if not (inv:find("WEAPON") or inv == "INVTYPE_HOLDABLE" or inv == "INVTYPE_SHIELD") then
    return true
  end

  local _, class = UnitClass("player")
  local _, _, _, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(entry.itemID)
  itemSubType = itemSubType or ""
  equipLoc    = equipLoc or inv

  -- 2H restriction for non-2H classes
  if equipLoc == "INVTYPE_2HWEAPON" then
    if class == "ROGUE" or class == "MAGE" or class == "PRIEST" or class == "WARLOCK" then
      return false
    end
  end

  if class == "MAGE" then
    return (itemSubType=="One-Handed Swords" or itemSubType=="Staves" or itemSubType=="Wands" or itemSubType=="Daggers")
  elseif class == "PRIEST" then
    return (itemSubType=="Staves" or itemSubType=="Wands" or itemSubType=="Daggers" or itemSubType=="One-Handed Maces")
  elseif class == "WARLOCK" then
    return (itemSubType=="Staves" or itemSubType=="Wands" or itemSubType=="Daggers" or itemSubType=="One-Handed Swords")
  elseif class == "ROGUE" then
    return (itemSubType=="Daggers" or itemSubType=="One-Handed Swords" or itemSubType=="One-Handed Maces" or itemSubType=="One-Handed Axes")
  end

  return true
end

-- ================= Level Window =================
function F:LevelOk(entry)
  local me = UnitLevel("player") or 1
  local base = (MakersPath and MakersPath.FutureWindow) or 3

  local req = 0
  if entry and entry.itemID then
    local _, _, _, _, reqLevel = GetItemInfo(entry.itemID)
    if type(reqLevel) == "number" then
      req = reqLevel
    else
      if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(entry.itemID)
      end
      req = tonumber(entry.reqLevel or entry.minLevel or 0) or 0
    end
  else
    req = tonumber(entry and (entry.reqLevel or entry.minLevel) or 0) or 0
  end

  if req == 0 then return true end
  return req <= (me + base)
end

-- ================= Master Gate =================
function F:IsAllowed(entry)
  if not entry then return false end
  if not RangedOkForClass(entry) then return false end
  if not WeaponOkForClass(entry) then return false end
  if not self:ArmorOkForClass(entry) then return false end
  if not self:LevelOk(entry) then return false end
  if entry.itemID and not ItemIsOkForPlayerClass(entry.itemID) then return false end
  return true
end