local ADDON, MakersPath = ...
MakersPath = MakersPath or {}

-- =====================================================================
-- Globals / DB shape
-- =====================================================================
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

local C = MakersPath.Const

local PROF_SKILLLINE_BY_NAME = setmetatable({}, {
  __index = function(t, k)
    for skillLineID, spellID in pairs(C.SKILLLINE_TO_SPELL or {}) do
      local name = GetSpellInfo(spellID)
      if name then rawset(t, name, skillLineID) end
    end
    return rawget(t, k)
  end
})

local function ArmorTokenByIDs(classID, subClassID)
  if classID == C.CLASS_ARMOR then
    if subClassID == C.ARMOR_SUB.CLOTH   then return "CLOTH"
    elseif subClassID == C.ARMOR_SUB.LEATHER then return "LEATHER"
    elseif subClassID == C.ARMOR_SUB.MAIL    then return "MAIL"
    elseif subClassID == C.ARMOR_SUB.PLATE   then return "PLATE"
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
  local _, _, _, equipLoc, _, classID, subClassID = GetItemInfoInstant(itemID)
  local name, _, _, _, reqLevel = GetItemInfo(itemID)
  if not equipLoc or equipLoc == "" then
    C_Timer.After(0.2, function() CacheAndBucket(itemID, profName) end)
    return
  end

  local profSkillLine = PROF_SKILLLINE_BY_NAME[profName] or 0
  local armor = ArmorTokenByIDs(classID, subClassID)

  MakersPathGlobalDB.itemRecords[itemID] = {
    prof     = profName,
    profId   = profSkillLine,
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
    reqSkill       = profSkillLine,
    reqSkillLevel  = 0,
    reqLevel       = reqLevel or 0,
    armor          = armor,
  })

  BucketInsertLegacy(equipLoc, itemID, {
    prof     = profName,
    profId   = profSkillLine,
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
      if link and link:find("|Hitem:") then
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
      if rec then  -- guard
        MakersPath.CraftDB[equipLoc] = MakersPath.CraftDB[equipLoc] or {}
        table.insert(MakersPath.CraftDB[equipLoc], {
          itemID   = e.itemID,
          prof     = rec.prof,
          profId   = rec.profId or 0,
          minLevel = rec.minLevel or 0,
          armor    = rec.armor,
        })
      end
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
    for skillLineID, spellID in pairs(C.SKILLLINE_TO_SPELL or {}) do
      local name = GetSpellInfo(spellID)
      if name then PROF_SKILLLINE_BY_NAME[name] = skillLineID end
    end
  elseif event == "PLAYER_LOGIN" then
    EnsureGlobals()
    RebuildRuntimeBuckets()
  elseif event == "TRADE_SKILL_SHOW" then
    EnsureGlobals()
    C_Timer.After(0.05, ScanCurrentTrade)
  elseif event == "GET_ITEM_INFO_RECEIVED" then
  end
end)