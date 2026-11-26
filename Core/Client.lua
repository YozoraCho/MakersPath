local ADDON, MakersPath = ...
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
local savedLoaded, adopted = false, false

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

local function fillMissing(dst, src)
  for k, v in pairs(src) do
    local cur = dst[k]
    if cur == nil then
      dst[k] = v
    elseif type(cur) == "table" and type(v) == "table" then
      fillMissing(cur, v)
    end
  end
end

local function adoptLegacyRecord()
  if adopted or not savedLoaded or not cachedKey then return end
  adopted = true
  if realmName() ~= "" then return end
  local chars = MakersPathDB and MakersPathDB.chars
  if type(chars) ~= "table" then return end
  local legacy = (UnitName("player") or "?") .. "-"
  if legacy == cachedKey then return end
  local old = chars[legacy]
  if type(old) ~= "table" then return end
  local _, class = UnitClass("player")
  if old.class and class and old.class ~= class then return end
  local level = UnitLevel("player")
  if tonumber(old.level) and tonumber(level) and level > 0 and old.level > level then return end
  local cur = chars[cachedKey]
  if type(cur) == "table" then
    fillMissing(cur, old)
  else
    chars[cachedKey] = old
  end
  chars[legacy] = nil
end

do
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("ADDON_LOADED")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
      if name ~= ADDON then return end
      savedLoaded = true
      self:UnregisterEvent("ADDON_LOADED")
    end
    if savedLoaded and MakersPath.Util.CurrentCharKey then MakersPath.Util.CurrentCharKey() end
    adoptLegacyRecord()
    if adopted then self:UnregisterAllEvents() end
  end)
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
  adoptLegacyRecord()
  return cachedKey
end
