local _, MakersPath = ...
MakersPath = MakersPath or {}

local API = {}
MakersPath.API = API

local C_Item, C_Spell, C_SpellBook, C_AddOns, C_SkillInfo, C_XMLUtil =
      C_Item, C_Spell, C_SpellBook, C_AddOns, C_SkillInfo, C_XMLUtil

local function pick(old, ns, name)
  if old then return old end
  return ns and ns[name] or nil
end

-- ---------- Items (same return shape on every client) ----------
API.GetItemInfo         = pick(_G.GetItemInfo,         C_Item, "GetItemInfo")
API.GetItemInfoInstant  = pick(_G.GetItemInfoInstant,  C_Item, "GetItemInfoInstant")
API.GetItemStats        = pick(_G.GetItemStats,        C_Item, "GetItemStats")
API.GetItemClassInfo    = pick(_G.GetItemClassInfo,    C_Item, "GetItemClassInfo")
API.GetItemSubClassInfo = pick(_G.GetItemSubClassInfo, C_Item, "GetItemSubClassInfo")
API.GetItemIcon         = pick(_G.GetItemIcon,         C_Item, "GetItemIconByID")
API.GetItemCount        = pick(_G.GetItemCount,        C_Item, "GetItemCount")

-- ---------- AddOns ----------
API.GetNumAddOns  = pick(C_AddOns and C_AddOns.GetNumAddOns,  nil, nil) or _G.GetNumAddOns
API.GetAddOnInfo  = pick(C_AddOns and C_AddOns.GetAddOnInfo,  nil, nil) or _G.GetAddOnInfo
API.IsAddOnLoaded = pick(C_AddOns and C_AddOns.IsAddOnLoaded, nil, nil) or _G.IsAddOnLoaded

-- ---------- Spells ----------
if _G.GetSpellInfo then
  API.GetSpellInfo = _G.GetSpellInfo
elseif C_Spell and C_Spell.GetSpellInfo then
  API.GetSpellInfo = function(spell)
    if spell == nil then return nil end
    local i = C_Spell.GetSpellInfo(spell)
    if not i then return nil end
    return i.name, nil, i.iconID, i.castTime, i.minRange, i.maxRange, i.spellID
  end
else
  API.GetSpellInfo = function() return nil end
end

if _G.GetSpellTexture then
  API.GetSpellTexture = _G.GetSpellTexture
elseif C_Spell and C_Spell.GetSpellTexture then
  API.GetSpellTexture = function(spell) return C_Spell.GetSpellTexture(spell) end
else
  API.GetSpellTexture = function(spell) return select(3, API.GetSpellInfo(spell)) end
end

if _G.GetSpellBookItemInfo then
  API.GetSpellBookItemInfo = _G.GetSpellBookItemInfo
elseif C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
  local TYPE_NAME = {}
  if Enum and Enum.SpellBookItemType then
    for k, v in pairs(Enum.SpellBookItemType) do TYPE_NAME[v] = string.upper(k) end
  end
  local NONE = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.None or 0
  local BANK = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
  API.GetSpellBookItemInfo = function(index)
    local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, index, BANK)
    if not ok or type(info) ~= "table" or info.itemType == nil or info.itemType == NONE then
      return nil
    end
    return TYPE_NAME[info.itemType] or "SPELL", info.spellID or info.actionID
  end
else
  API.GetSpellBookItemInfo = function() return nil end
end

-- ---------- Skill lines (professions + weapon skills) ----------
function API.GetSkillLines()
  local out = {}
  if _G.GetNumSkillLines and _G.GetSkillLineInfo then
    for i = 1, (_G.GetNumSkillLines() or 0) do
      local name, isHeader, _, rank, _, _, maxRank = _G.GetSkillLineInfo(i)
      out[#out+1] = { name = name, isHeader = isHeader, rank = rank, maxRank = maxRank }
    end
  elseif C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo then
    for i = 1, (C_SkillInfo.GetNumSkillLines() or 0) do
      local info = C_SkillInfo.GetSkillLineInfo(i)
      if type(info) == "table" then
        out[#out+1] = {
          name     = info.name,
          isHeader = info.isHeader,
          rank     = info.rank,
          maxRank  = info.maxRank,
          skillID  = info.skillID,
        }
      end
    end
  end
  return out
end

function API.GetProfessionList()
  local out = {}
  if not (_G.GetProfessions and _G.GetProfessionInfo) then return out end
  local slots = { _G.GetProfessions() }
  for s = 1, 8 do
    local idx = slots[s]
    if idx then
      local name, _, rank, maxRank, _, _, skillLine = _G.GetProfessionInfo(idx)
      if name then
        out[#out+1] = { name = name, rank = rank, maxRank = maxRank, skillLine = skillLine }
      end
    end
  end
  return out
end

-- ---------- Frame templates ----------
function API.PickTemplate(...)
  local n = select("#", ...)
  if not (C_XMLUtil and C_XMLUtil.GetTemplateInfo) then return (...) end
  for i = 1, n do
    local t = select(i, ...)
    if t and C_XMLUtil.GetTemplateInfo(t) then return t end
  end
  return nil
end

-- ---------- Class icons ----------
function API.ClassIcon(classTag)
  local coords = classTag and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classTag:upper()]
  if not coords then return nil end
  return "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes", coords
end
