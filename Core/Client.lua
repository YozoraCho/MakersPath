local _, MakersPath = ...
MakersPath = MakersPath or {}

local pid = WOW_PROJECT_ID

MakersPath.client = {
  projectId = pid,
  isEra     = (pid == WOW_PROJECT_CLASSIC),
  isTBC     = (pid == WOW_PROJECT_BURNING_CRUSADE_CLASSIC),
  isForever = (WOW_PROJECT_CAMELOT ~= nil and pid == WOW_PROJECT_CAMELOT),
}

MakersPath.features = MakersPath.features or {}
MakersPath.features.jewelcrafting = MakersPath.client.isTBC
MakersPath.features.sockets       = MakersPath.client.isTBC
MakersPath.features.ratings       = MakersPath.client.isTBC

-- ===================== Character key =====================
MakersPath.Util = MakersPath.Util or {}
local cachedKey

local function realmName()
  local r = GetRealmName and GetRealmName() or ""
  if r == "" and GetNormalizedRealmName then r = GetNormalizedRealmName() or "" end
  return r
end

function MakersPath.Util.CurrentCharName()
  local first, second = UnitName("player")
  first = first or "?"
  if realmName() == "" and type(second) == "string" and second ~= "" then
    return first .. " " .. second
  end
  return first
end

local function adoptLegacyRecord(first, key)
  local chars = MakersPathDB and MakersPathDB.chars
  if not chars then return end
  local legacy = first .. "-"
  local old = chars[legacy]
  if type(old) ~= "table" or chars[key] then return end
  local _, class = UnitClass("player")
  if old.class and class and old.class ~= class then return end
  chars[key] = old
  chars[legacy] = nil
end

function MakersPath.Util.CharKey(name, realm)
  name = name or UnitName("player") or "?"
  realm = realm or realmName()
  return name .. "-" .. realm
end

function MakersPath.Util.CurrentCharKey()
  if cachedKey then return cachedKey end
  local first = UnitName("player") or "?"
  local realm = realmName()
  if realm ~= "" then
    cachedKey = first .. "-" .. realm
    return cachedKey
  end
  local guid = UnitGUID and UnitGUID("player")
  local id = guid and guid:match("^Player%-(.+)$")
  if not id then return first .. "-" end
  cachedKey = MakersPath.Util.CurrentCharName() .. "-" .. id
  adoptLegacyRecord(first, cachedKey)
  return cachedKey
end
