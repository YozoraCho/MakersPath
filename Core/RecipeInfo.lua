local _, MakersPath = ...
MakersPath = MakersPath or {}
local API = MakersPath.API or {}

local R = {}
MakersPath.RecipeInfo = R

-- =================== Recipe Data ===================
local byItem

local function itemOf(rec)
  return rec and (rec.productid or rec.productId or rec.itemid or rec.itemId) or nil
end

local function buildIndex()
  byItem = {}
  local P = MakersPath.Professions
  if not (P and P.AllRecipes) then return end
  for prof, list in pairs(P.AllRecipes) do
    for _, rec in pairs(list) do
      local id = tonumber(itemOf(rec))
      if id then
        local cur = byItem[id]
        local learned = tonumber(rec.learnedat or rec.learnedAt) or 0
        if not cur or learned < (tonumber(cur.rec.learnedat or cur.rec.learnedAt) or 0) then
          byItem[id] = { rec = rec, prof = tonumber(prof) }
        end
      end
    end
  end
end

local function lookup(itemID)
  if not byItem then buildIndex() end
  return itemID and byItem[tonumber(itemID)]
end

function R.Reagents(itemID)
  local e = lookup(itemID)
  local list = e and e.rec.reagents
  if type(list) ~= "table" or #list == 0 then return nil end
  local out = {}
  for _, r in ipairs(list) do
    local id = tonumber(r.id or r[1])
    local num = tonumber(r.num or r[2]) or 1
    if id then out[#out + 1] = { id = id, num = num } end
  end
  return #out > 0 and out or nil
end

function R.Source(itemID)
  local e = lookup(itemID)
  local s = e and e.rec.source
  if not s or s == "" or s == "undefined" then return nil end
  return s
end

function R.Profession(itemID)
  local e = lookup(itemID)
  return e and e.prof or nil
end

function R.SpellForItem(itemID)
  local e = lookup(itemID)
  return e and tonumber(e.rec.spell or e.rec.spellid) or nil
end

function R.Count(itemID)
  if not (itemID and API.GetItemCount) then return 0 end
  return API.GetItemCount(itemID) or 0
end

-- =================== Known Recipes ===================
local function charRec(key)
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.chars = MakersPathDB.chars or {}
  local rec = MakersPathDB.chars[key]
  if not rec then
    rec = {}
    MakersPathDB.chars[key] = rec
  end
  return rec
end

local function currentKey()
  return (MakersPath.Util and MakersPath.Util.CurrentCharKey and MakersPath.Util.CurrentCharKey())
      or ((UnitName("player") or "?") .. "-" .. (GetRealmName() or "?"))
end
R.CurrentKey = currentKey

function R.RecordLearned(skillLine, itemIDs)
  skillLine = tonumber(skillLine)
  if not skillLine or skillLine == 0 or type(itemIDs) ~= "table" then return end
  local rec = charRec(currentKey())
  rec.recipes = rec.recipes or {}
  local book = rec.recipes[skillLine]
  if not book then
    book = { items = {} }
    rec.recipes[skillLine] = book
  end
  local added = 0
  for _, id in ipairs(itemIDs) do
    id = tonumber(id)
    if id and not book.items[id] then
      book.items[id] = true
      added = added + 1
    end
  end
  book.seen = time and time() or book.seen
  return added
end

function R.IsKnown(itemID, skillLine, key)
  local rec = MakersPathDB and MakersPathDB.chars and MakersPathDB.chars[key or currentKey()]
  local book = rec and rec.recipes and rec.recipes[tonumber(skillLine) or 0]
  if not book then return nil end
  return book.items[tonumber(itemID) or 0] == true
end

function R.KnownCount(skillLine, key)
  local rec = MakersPathDB and MakersPathDB.chars and MakersPathDB.chars[key or currentKey()]
  local book = rec and rec.recipes and rec.recipes[tonumber(skillLine) or 0]
  if not book then return nil end
  local n = 0
  for _ in pairs(book.items) do n = n + 1 end
  return n
end
