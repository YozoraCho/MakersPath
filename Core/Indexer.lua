local ADDON, MakersPath = ...
local API = MakersPath.API or {}  -- see Core/Compat.lua
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
      local name = API.GetSpellInfo(spellID)
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
  if MakersPath.BumpCandidateGen then MakersPath.BumpCandidateGen() end
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
  if MakersPath.BumpCandidateGen then MakersPath.BumpCandidateGen() end

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
local NON_GEAR = {}
local retryCount = {}
local MAX_RETRIES = 25

local function CacheAndBucket(itemID, profName)
  if NON_GEAR[itemID] then return end

  local _, _, _, equipLoc, _, classID, subClassID = API.GetItemInfoInstant(itemID)
  local name, _, _, _, reqLevel = API.GetItemInfo(itemID)

  if equipLoc == "" then
    NON_GEAR[itemID] = true
    retryCount[itemID] = nil
    return
  end

  if not equipLoc or not name then
    local n = (retryCount[itemID] or 0) + 1
    if n > MAX_RETRIES then
      retryCount[itemID] = nil
      return
    end
    retryCount[itemID] = n
    C_Timer.After(0.2, function() CacheAndBucket(itemID, profName) end)
    return
  end

  retryCount[itemID] = nil

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
local function IndexCraftedItem(itemID, profName)
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

-- Classic Era / TBC: the old TradeSkillFrame API, which lists learned recipes.
local function CollectClassicTrade()
  if not (GetTradeSkillLine and GetNumTradeSkills) then return end
  if not TradeSkillFrame or not TradeSkillFrame:IsShown() then return end

  local profName = GetTradeSkillLine()
  if not profName or profName == "" then return end

  local num = GetNumTradeSkills() or 0
  if type(num) ~= "number" or num <= 0 then return end

  local ids = {}
  for i = 1, num do
    local _, skillType = GetTradeSkillInfo(i)
    if skillType ~= "header" then
      local link = GetTradeSkillItemLink(i)
      if link and link:find("|Hitem:") then
        local itemID = tonumber(link:match("item:(%d+)"))
        if itemID then ids[#ids+1] = itemID end
      end
    end
  end
  return profName, ids
end

-- WoW Forever (modern client): C_TradeSkillUI. Only learned recipes, and only
-- for the player's own profession window (not linked or guild views).
local function CollectModernTrade()
  local T = C_TradeSkillUI
  if not (T and T.GetAllRecipeIDs and T.GetRecipeInfo and T.GetBaseProfessionInfo) then return end
  if T.IsTradeSkillReady and not T.IsTradeSkillReady() then return end
  if T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return end
  if T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return end
  if T.IsNPCCrafting and T.IsNPCCrafting() then return end

  local base = T.GetBaseProfessionInfo()
  local profName = base and base.professionName
  if not profName or profName == "" then return end

  local ids = {}
  for _, recipeID in ipairs(T.GetAllRecipeIDs() or {}) do
    local info = T.GetRecipeInfo(recipeID)
    if info and info.learned then
      local schem = T.GetRecipeSchematic and T.GetRecipeSchematic(recipeID, false)
      local itemID = schem and schem.outputItemID
      if not itemID and T.GetRecipeItemLink then
        local link = T.GetRecipeItemLink(recipeID)
        itemID = link and tonumber(link:match("item:(%d+)"))
      end
      if itemID then ids[#ids+1] = itemID end
    end
  end
  return profName, ids
end

local function CollectCraft()
  if not (GetNumCrafts and GetCraftInfo and GetCraftItemLink and GetCraftDisplaySkillLine) then return end

  local profName = GetCraftDisplaySkillLine()
  if not profName or profName == "" then return end

  local num = GetNumCrafts() or 0
  if type(num) ~= "number" or num <= 0 then return end

  local ids = {}
  for i = 1, num do
    local _, _, craftType = GetCraftInfo(i)
    if craftType ~= "header" then
      local link = GetCraftItemLink(i)
      local itemID = link and tonumber(link:match("|Hitem:(%d+)"))
      if itemID then ids[#ids+1] = itemID end
    end
  end
  return profName, ids
end

local function RecordScan(profName, ids)
  if not profName or not ids then return end

  EnsureGlobals()
  for _, itemID in ipairs(ids) do
    IndexCraftedItem(itemID, profName)
  end

  local skillLine = PROF_SKILLLINE_BY_NAME[profName]
  if skillLine and MakersPath.RecipeInfo and MakersPath.RecipeInfo.RecordLearned then
    local added = MakersPath.RecipeInfo.RecordLearned(skillLine, ids)
    if added and added > 0 and MakersPath.UI and MakersPath.UI.QueueRedraw then
      MakersPath.UI.QueueRedraw()
    end
  end
end

local function ScanCurrentTrade()
  local profName, ids = CollectClassicTrade()
  if not profName then profName, ids = CollectModernTrade() end
  RecordScan(profName, ids)
end

local function ScanCurrentCraft()
  RecordScan(CollectCraft())
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
-- Modern clients fill the recipe list after TRADE_SKILL_SHOW. pcall because
-- registering an event a client doesn't know is an error on some builds.
pcall(f.RegisterEvent, f, "TRADE_SKILL_LIST_UPDATE")
pcall(f.RegisterEvent, f, "CRAFT_SHOW")
pcall(f.RegisterEvent, f, "CRAFT_UPDATE")

local scanQueued = false
local function QueueTradeScan(delay)
  if scanQueued then return end
  scanQueued = true
  C_Timer.After(delay or 0.05, function()
    scanQueued = false
    ScanCurrentTrade()
  end)
end

local craftQueued = false
local function QueueCraftScan(delay)
  if craftQueued then return end
  craftQueued = true
  C_Timer.After(delay or 0.05, function()
    craftQueued = false
    ScanCurrentCraft()
  end)
end

f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    EnsureGlobals()
    for skillLineID, spellID in pairs(C.SKILLLINE_TO_SPELL or {}) do
      local name = API.GetSpellInfo(spellID)
      if name then PROF_SKILLLINE_BY_NAME[name] = skillLineID end
    end
  elseif event == "PLAYER_LOGIN" then
    EnsureGlobals()
    RebuildRuntimeBuckets()
  elseif event == "TRADE_SKILL_SHOW" then
    EnsureGlobals()
    QueueTradeScan(0.05)
  elseif event == "TRADE_SKILL_LIST_UPDATE" then
    QueueTradeScan(0.25)
  elseif event == "CRAFT_SHOW" then
    EnsureGlobals()
    QueueCraftScan(0.05)
  elseif event == "CRAFT_UPDATE" then
    QueueCraftScan(0.25)
  elseif event == "GET_ITEM_INFO_RECEIVED" then
  end
end)