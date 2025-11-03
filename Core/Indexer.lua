local ADDON, MakersPath = ...
MakersPath = MakersPath or {}

-- =====================================================================
-- Globals / DB shape
-- =====================================================================
-- MakersPathGlobalDB = {
--   itemRecords = { [itemID] = { prof="Tailoring", profId=197, equipLoc="INVTYPE_HEAD",
--                                minLevel=10, armor="CLOTH", source="crafted", name="..." } },
--   buckets     = { [equipLoc] = { {itemID=xxxx}, ... } },         -- legacy mirror
--   items       = { [invType] = {                                  -- GearFinder source
--                    { itemID=..., name="...", invType="INVTYPE_HEAD", source="crafted",
--                      reqSkill=197, reqSkillLevel=0, reqLevel=10, armor="CLOTH" }, ... } },
-- }
MakersPath.CraftDB = MakersPath.CraftDB or {}

-- =====================================================================
-- Helpers / constants
-- =====================================================================
local function EnsureGlobals()
  MakersPathGlobalDB = MakersPathGlobalDB or {}
  MakersPathGlobalDB.itemRecords = MakersPathGlobalDB.itemRecords or {}
  MakersPathGlobalDB.buckets     = MakersPathGlobalDB.buckets     or {}
  MakersPathGlobalDB.items       = MakersPathGlobalDB.items       or {}
end

local PROF_ID_BY_NAME = {
  ["Blacksmithing"]  = 164,
  ["Leatherworking"] = 165,
  ["Tailoring"]      = 197,
  ["Engineering"]    = 202,
}

local function ArmorToken(itemType, itemSubType)
  if itemType == "Armor" then
    if itemSubType == "Cloth"   then return "CLOTH"
    elseif itemSubType == "Leather" then return "LEATHER"
    elseif itemSubType == "Mail"    then return "MAIL"
    elseif itemSubType == "Plate"   then return "PLATE"
    end
  end
  return nil
end

-- =====================================================================
-- Insert into per-invType array
-- =====================================================================
local function InvTypeInsert(invType, row)
  if not invType or invType == "" then return end
  local t = MakersPathGlobalDB.items[invType]
  if not t then
    t = {}
    MakersPathGlobalDB.items[invType] = t
  end
  for i=1,#t do
    if t[i].itemID == row.itemID then return end
  end
  table.insert(t, row)
end

-- =====================================================================
-- Legacy mirrors
-- =====================================================================
local function BucketInsertLegacy(equipLoc, itemID, meta)
  if not equipLoc or equipLoc=="" then return end

  local bucket = MakersPathGlobalDB.buckets[equipLoc]
  if not bucket then bucket = {}; MakersPathGlobalDB.buckets[equipLoc] = bucket end
  for _, e in ipairs(bucket) do if e.itemID == itemID then return end end
  table.insert(bucket, { itemID = itemID })

  MakersPath.CraftDB[equipLoc] = MakersPath.CraftDB[equipLoc] or {}
  local rb = MakersPath.CraftDB[equipLoc]
  for _, e in ipairs(rb) do if e.itemID == itemID then return end end
  table.insert(rb, {
    itemID   = itemID,
    prof     = meta.prof,
    profId   = meta.profId or 0,
    minLevel = meta.minLevel or 0,
    armor    = meta.armor,
  })
end

-- =====================================================================
-- Cache & fan-out into DBs
-- =====================================================================
local function CacheAndBucket(itemID, profName)
  local name, _, _, _, reqLevel, itemType, itemSubType, _, equipLoc = GetItemInfo(itemID)
  if not equipLoc or equipLoc == "" then
    C_Timer.After(0.2, function() CacheAndBucket(itemID, profName) end)
    return
  end

  local armor  = ArmorToken(itemType, itemSubType)
  local profId = PROF_ID_BY_NAME[profName] or 0

  MakersPathGlobalDB.itemRecords[itemID] = {
    prof     = profName,
    profId   = profId,
    equipLoc = equipLoc,
    minLevel = reqLevel or 0,
    armor    = armor,
    source   = "crafted",
    name     = name,
  }

  InvTypeInsert(equipLoc, {
    itemID         = itemID,
    name           = name,
    invType        = equipLoc,
    source         = "crafted",
    reqSkill       = profId,
    reqSkillLevel  = 0,
    reqLevel       = reqLevel or 0,
    armor          = armor,
  })

  BucketInsertLegacy(equipLoc, itemID, {
    prof     = profName,
    profId   = profId,
    minLevel = reqLevel or 0,
    armor    = armor,
  })
end

-- =====================================================================
-- TradeSkill scanning
-- =====================================================================
local function ScanCurrentTrade()
  if not TradeSkillFrame or not TradeSkillFrame:IsShown() then return end

  local profName = GetTradeSkillLine()
  if not profName or profName == "" then return end

  local num = GetNumTradeSkills and GetNumTradeSkills() or 0
  if type(num) ~= "number" or num <= 0 then return end

  EnsureGlobals()

  for i = 1, num do
    local _, skillType = GetTradeSkillInfo(i)
    if skillType ~= "header" then
      local link = GetTradeSkillItemLink(i)
      if link and link:find("^|c") and link:find("|Hitem:") then
        local itemID = tonumber(link:match("item:(%d+)"))
        if itemID then
          if not MakersPathGlobalDB.itemRecords[itemID] then
            CacheAndBucket(itemID, profName)
          else
            local rec = MakersPathGlobalDB.itemRecords[itemID]
            if rec then
              InvTypeInsert(rec.equipLoc, {
                itemID         = itemID,
                name           = rec.name,
                invType        = rec.equipLoc,
                source         = "crafted",
                reqSkill       = rec.profId or 0,
                reqSkillLevel  = 0,
                reqLevel       = rec.minLevel or 0,
                armor          = rec.armor,
              })
              BucketInsertLegacy(rec.equipLoc, itemID, {
                prof     = rec.prof,
                profId   = rec.profId or 0,
                minLevel = rec.minLevel or 0,
                armor    = rec.armor,
              })
            end
          end
        end
      end
    end
  end
end

-- =====================================================================
-- Rebuild mirrors at login
-- =====================================================================
local function RebuildRuntimeBuckets()
  EnsureGlobals()
  wipe(MakersPath.CraftDB)
  for equipLoc, list in pairs(MakersPathGlobalDB.buckets or {}) do
    for _, e in ipairs(list) do
      local rec = MakersPathGlobalDB.itemRecords[e.itemID]
      MakersPath.CraftDB[equipLoc] = MakersPath.CraftDB[equipLoc] or {}
      table.insert(MakersPath.CraftDB[equipLoc], {
        itemID   = e.itemID,
        prof     = rec and rec.prof or nil,
        profId   = rec and rec.profId or 0,
        minLevel = rec and rec.minLevel or 0,
        armor    = rec and rec.armor or nil,
      })
    end
  end
end

-- =====================================================================
-- Events
-- =====================================================================
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")

f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    EnsureGlobals()
  elseif event == "PLAYER_LOGIN" then
    EnsureGlobals()
    RebuildRuntimeBuckets()
  elseif event == "TRADE_SKILL_SHOW" then
    EnsureGlobals()
    C_Timer.After(0.05, ScanCurrentTrade)
  elseif event == "GET_ITEM_INFO_RECEIVED" then
  end
end)