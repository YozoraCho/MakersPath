local ADDON, MakersPath = ...
MakersPath                   = MakersPath or {}
MakersPath.Professions       = MakersPath.Professions or {}
MakersPath.Static            = MakersPath.Static or {}
MakersPath.Static.Craftables = MakersPath.Static.Craftables or {}

local C = MakersPath.Const or {}
local P = MakersPath.Professions

-- =======================
-- Small utility helpers
-- =======================
local function toNum(x) return type(x)=="number" and x or tonumber(x) or 0 end

local function armorTagByIDs(classID, subClassID)
  if not classID then return nil end
  if classID ~= C.CLASS_ARMOR then return nil end
  if subClassID == C.ARMOR_SUB.CLOTH   then return "CLOTH"  end
  if subClassID == C.ARMOR_SUB.LEATHER then return "LEATHER" end
  if subClassID == C.ARMOR_SUB.MAIL    then return "MAIL"   end
  if subClassID == C.ARMOR_SUB.PLATE   then return "PLATE"  end
  return nil
end

local function armorTagFallbackStrings(itemType, itemSubType)
  local armorName = GetItemClassInfo and GetItemClassInfo(4) or nil
  if not armorName or itemType ~= armorName then return nil end

  local cloth   = GetItemSubClassInfo and GetItemSubClassInfo(4, 1) or nil
  local leather = GetItemSubClassInfo and GetItemSubClassInfo(4, 2) or nil
  local mail    = GetItemSubClassInfo and GetItemSubClassInfo(4, 3) or nil
  local plate   = GetItemSubClassInfo and GetItemSubClassInfo(4, 4) or nil

  if cloth   and itemSubType == cloth   then return "CLOTH"   end
  if leather and itemSubType == leather then return "LEATHER" end
  if mail    and itemSubType == mail    then return "MAIL"    end
  if plate   and itemSubType == plate   then return "PLATE"   end
  return nil
end

local function armorTag(itemID, itemType, itemSubType)
  local _, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(itemID)
  if not classID and C_Item and C_Item.GetItemInfoInstant then
    local _, _, _, _, _, _classID, _subClassID = C_Item.GetItemInfoInstant(itemID)
    classID, subClassID = _classID, _subClassID
  end
  local token = armorTagByIDs(classID, subClassID)
  if token then return token end
  return armorTagFallbackStrings(itemType, itemSubType)
end

local function looksBogusName(name)
  if not name or name=="" then return false end
  if name:find("^Monster%s*%-") then return true end
  if name:upper():find("^TEST") then return true end
  if name:find("Bucket") then return true end
  return false
end

local INV_WHITELIST = {
  INVTYPE_HEAD=true, INVTYPE_NECK=true, INVTYPE_SHOULDER=true, INVTYPE_CLOAK=true,
  INVTYPE_CHEST=true, INVTYPE_ROBE=true, INVTYPE_WRIST=true, INVTYPE_HAND=true,
  INVTYPE_WAIST=true, INVTYPE_LEGS=true, INVTYPE_FEET=true, INVTYPE_FINGER=true,
  INVTYPE_TRINKET=true,
  INVTYPE_WEAPON=true, INVTYPE_WEAPONMAINHAND=true, INVTYPE_WEAPONOFFHAND=true,
  INVTYPE_2HWEAPON=true, INVTYPE_SHIELD=true, INVTYPE_HOLDABLE=true,
  INVTYPE_RANGED=true, INVTYPE_RANGEDRIGHT=true, INVTYPE_RELIC=true,
  INVTYPE_THROWN=true, INVTYPE_AMMO=true,
}

local function getSpellIdFromRec(rec)  return rec and (rec.spellid or rec.spell or rec.recipeid or rec.recipeId) or nil end
local function getItemIdFromRec(rec)   return rec and (rec.productid or rec.productId or rec.itemid or rec.itemId) or nil end
local function getLearnedAt(rec)       return toNum(rec and (rec.learnedat or rec.learnedAt or rec.skill or rec.rank)) end

-- =======================
-- Build spell↔item maps
-- =======================
local function buildSpellMaps()
  P.ItemToSpell = P.ItemToSpell or {}
  P.SpellToItem = P.SpellToItem or {}

  if next(P.ItemToSpell) and not next(P.SpellToItem) then
    for itemID, spellID in pairs(P.ItemToSpell) do
      if itemID and spellID then P.SpellToItem[spellID] = itemID end
    end
  end

  if not next(P.SpellToItem) and P.AllRecipes then
    for _, list in pairs(P.AllRecipes) do
      for key, rec in pairs(list) do
        local spellID = getSpellIdFromRec(rec) or (type(key)=="number" and key or nil)
        local itemID  = getItemIdFromRec(rec)
        if spellID and itemID then
          P.SpellToItem[spellID] = itemID
          P.ItemToSpell[itemID]  = spellID
        end
      end
    end
  end
end

-- =======================
-- Bucketing
-- =======================
local unresolved = {}

local function bucketInsert(inv, row)
  if not inv or inv=="" then return end
  local b = MakersPath.Static.Craftables[inv]
  if not b then b = {}; MakersPath.Static.Craftables[inv] = b end
  for i=1,#b do if b[i].itemID == row.itemID then return end end
  table.insert(b, row)
end

local function bucketStaticItem(itemID, profId, learnedAt)
  local name, _, _, reqLevel, _, itemType, itemSubType, _, equipLoc = GetItemInfo(itemID)
  if not equipLoc or equipLoc=="" then return false end

  if not INV_WHITELIST[equipLoc] then
    return true
  end

  if looksBogusName(name) then
    return true
  end

  local tag = armorTag(itemID, itemType, itemSubType)

  local row = {
    itemID         = itemID,
    name           = name,
    invType        = equipLoc,
    reqLevel       = toNum(reqLevel),
    reqSkill       = toNum(profId),
    reqSkillLevel  = toNum(learnedAt),
    armor          = tag,
    source         = "crafted",
    isCrafted      = true,
  }
  bucketInsert(equipLoc, row)
  return true
end

-- =======================
-- Index static recipes
-- =======================
local function indexStaticRecipes()
  buildSpellMaps()
  if not P.AllRecipes then return end

  for profId, list in pairs(P.AllRecipes) do
    for key, rec in pairs(list) do
      local spellID = getSpellIdFromRec(rec) or (type(key)=="number" and key or nil)
      local itemID  = getItemIdFromRec(rec)
      if not itemID and spellID and P.SpellToItem then
        itemID = P.SpellToItem[spellID]
      end

      if itemID then
        local ok = bucketStaticItem(itemID, profId, getLearnedAt(rec))
        if not ok then
          unresolved[itemID] = { profId, getLearnedAt(rec) }
          if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
        end
      end
    end
  end
end

local frameRetry = CreateFrame("Frame")
frameRetry:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frameRetry:SetScript("OnEvent", function(_, _, iid)
  local meta = unresolved[iid]
  if not meta then return end
  local ok = bucketStaticItem(iid, meta[1], meta[2])
  if ok then unresolved[iid] = nil end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
  indexStaticRecipes()
  C_Timer.After(2.0, function()
    for iid, meta in pairs(unresolved) do
      bucketStaticItem(iid, meta[1], meta[2])
    end
  end)
end)