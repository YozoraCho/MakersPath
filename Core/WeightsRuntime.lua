local ADDON, MakersPath = ...
MakersPath = MakersPath or {}
MakersPath.WeightsRT = MakersPath.WeightsRT or {}

local RT = MakersPath.WeightsRT

-- =====================================================================
-- Canonical stat key list
-- =====================================================================
RT.GROUPS = {
  { name = "Primary", keys = {
      "STRENGTH", "AGILITY", "STAMINA", "INTELLECT", "SPIRIT",
  }},
  { name = "Defense", keys = {
      "ARMOR", "DEFENSE_SKILL", "DODGE", "PARRY", "BLOCK", "BLOCK_VALUE",
      "RESILIENCE",
  }},
  { name = "Health / Mana", keys = {
      "HEALTH", "MANA", "HEALTH_REGENERATION", "MANA_REGENERATION",
  }},
  { name = "Attack", keys = {
      "ATTACK_POWER", "MELEE_ATTACK_POWER", "RANGED_ATTACK_POWER",
      "FERAL_ATTACK_POWER", "DAMAGE_PER_SECOND",
  }},
  { name = "Ratings", keys = {
      "CRIT", "CRIT_SPELL", "HIT", "HIT_SPELL", "HASTE", "HASTE_SPELL",
      "EXPERTISE", "ARMOR_PENETRATION", "SPELL_PENETRATION",
  }},
  { name = "Spell / Healing", keys = {
      "SPELL_DAMAGE_DONE", "SPELL_HEALING_DONE",
      "SPELL_DAMAGE_DONE_HOLY", "SPELL_DAMAGE_DONE_FIRE",
      "SPELL_DAMAGE_DONE_NATURE", "SPELL_DAMAGE_DONE_FROST",
      "SPELL_DAMAGE_DONE_SHADOW", "SPELL_DAMAGE_DONE_ARCANE",
  }},
  { name = "Resistances", keys = {
      "FIRE_RESISTANCE", "NATURE_RESISTANCE", "FROST_RESISTANCE",
      "SHADOW_RESISTANCE", "ARCANE_RESISTANCE",
  }},
}

RT.ALL_KEYS = {}
RT.KEY_SET  = {}
for _, grp in ipairs(RT.GROUPS) do
  for _, k in ipairs(grp.keys) do
    RT.ALL_KEYS[#RT.ALL_KEYS + 1] = k
    RT.KEY_SET[k] = true
  end
end

RT.MIN_WEIGHT = 0.00
RT.MAX_WEIGHT = 5.00

-- =====================================================================
-- DB accessors
-- =====================================================================
local function CharKey()
  if MakersPath.Util and MakersPath.Util.CurrentCharKey then
    local ok, key = pcall(MakersPath.Util.CurrentCharKey)
    if ok and key then return key end
  end
  local name  = UnitName("player") or "?"
  local realm = GetRealmName() or "?"
  return name .. "-" .. realm
end
RT.CharKey = CharKey

local function CharWeightDB(class, spec)
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.chars = MakersPathDB.chars or {}
  local key = CharKey()
  local rec = MakersPathDB.chars[key]
  if not rec then
    rec = {}
    MakersPathDB.chars[key] = rec
  end
  rec.weights = rec.weights or {}
  if not class then return rec.weights end
  rec.weights[class] = rec.weights[class] or {}
  if not spec then return rec.weights[class] end
  rec.weights[class][spec] = rec.weights[class][spec] or {}
  return rec.weights[class][spec]
end

local function PresetDB()
  MakersPathGlobalDB = MakersPathGlobalDB or {}
  MakersPathGlobalDB.weightPresets = MakersPathGlobalDB.weightPresets or {}
  return MakersPathGlobalDB.weightPresets
end
RT.PresetDB = PresetDB

-- =====================================================================
-- Spec / class resolution
-- =====================================================================
function RT.CurrentClass()
  local _, class = UnitClass("player")
  return class and class:upper() or "UNKNOWN"
end

function RT.NormalizeSpecKey(class, spec)
  if not spec or spec == "" then return nil end
  local key = spec:upper()
  if class == "WARRIOR" and key == "PROT" then key = "PROTECTION" end
  return key
end

function RT.ResolveDefaults(class, lvl, spec)
  local all = MakersPath.Weights or {}
  class = class or RT.CurrentClass()
  lvl   = lvl or (UnitLevel("player") or 1)

  local classTbl = all[class]
  if not classTbl then return nil, nil end

  if lvl < 10 then
    if classTbl.BASE then return "BASE", classTbl.BASE end
    for k, v in pairs(classTbl) do
      if k ~= "BASE" and type(v) == "table" then return k, v end
    end
    return nil, nil
  end

  local key = RT.NormalizeSpecKey(class, spec)
  if not key then
    return "BASE", classTbl.BASE or nil
  end

  local w = classTbl[key]
  if w then return key, w end
  return "BASE", classTbl.BASE or nil
end

-- =====================================================================
-- Resolution cache
-- =====================================================================
local cache = {}
local cacheKey = nil

local function BuildCacheKey(class, specKey, lvl)
  return (class or "?") .. "/" .. (specKey or "BASE") .. "/" .. (lvl < 10 and "lo" or "hi")
end

function RT:Invalidate()
  cache = {}
  cacheKey = nil
  if MakersPath.GearFinder then
    if MakersPath.GearFinder.InvalidateScoreCache then
      MakersPath.GearFinder:InvalidateScoreCache()
    end
    if MakersPath.GearFinder.MarkDirty then
      MakersPath.GearFinder:MarkDirty()
    end
    MakersPath.GearFinder._equippedScoreCache = {}
  end
end

local function Resolve()
  local class   = RT.CurrentClass()
  local lvl     = UnitLevel("player") or 1
  local spec    = MakersPath.Spec and MakersPath.Spec.Get and MakersPath.Spec.Get() or nil
  local specKey, defaults = RT.ResolveDefaults(class, lvl, spec)

  local ck = BuildCacheKey(class, specKey, lvl)
  if cacheKey == ck and cache[ck] then
    return cache[ck]
  end

  local entry = { class = class, specKey = specKey, full = {}, scoring = {} }

  if defaults then
    local overrides = CharWeightDB(class, specKey or "BASE")
    local full, scoring = entry.full, entry.scoring

    for i = 1, #RT.ALL_KEYS do
      full[RT.ALL_KEYS[i]] = 0
    end
    for k, v in pairs(defaults) do
      if type(v) == "number" then full[k] = v end
    end
    for k, v in pairs(overrides) do
      if type(v) == "number" then full[k] = v end
    end
    for k, v in pairs(full) do
      if v ~= 0 then scoring[k] = v end
    end
  end

  cache[ck] = entry
  cacheKey = ck
  return entry
end

function RT.GetScoringWeights()
  local e = Resolve()
  if not e or not e.scoring then return nil end
  if next(e.scoring) == nil then return nil end
  return e.scoring
end

function RT.GetEditableWeights()
  local e = Resolve()
  return e and e.full or nil, e and e.class or nil, e and e.specKey or nil
end

function RT.GetDefaultsTable()
  local class = RT.CurrentClass()
  local lvl   = UnitLevel("player") or 1
  local spec  = MakersPath.Spec and MakersPath.Spec.Get and MakersPath.Spec.Get() or nil
  local _, defaults = RT.ResolveDefaults(class, lvl, spec)
  return defaults
end

-- =====================================================================
-- Mutation
-- =====================================================================
local function clampWeight(v)
  v = tonumber(v) or 0
  if v < RT.MIN_WEIGHT then v = RT.MIN_WEIGHT end
  if v > RT.MAX_WEIGHT then v = RT.MAX_WEIGHT end
  return math.floor(v * 100 + 0.5) / 100
end
RT.ClampWeight = clampWeight

function RT.SetWeight(statKey, value)
  if not statKey then return end
  local e = Resolve()
  if not e then return end
  local defaults = RT.GetDefaultsTable() or {}
  local ov = CharWeightDB(e.class, e.specKey or "BASE")

  local v = clampWeight(value)
  local d = tonumber(defaults[statKey])

  if d and math.abs(d - v) < 0.005 then
    ov[statKey] = nil
  else
    ov[statKey] = v
  end

  RT:Invalidate()
end

function RT.GetWeight(statKey)
  local full = RT.GetEditableWeights()
  return (full and full[statKey]) or 0
end

function RT.IsOverridden(statKey)
  local e = Resolve()
  if not e then return false end
  local ov = CharWeightDB(e.class, e.specKey or "BASE")
  return ov[statKey] ~= nil
end

function RT.HasAnyOverride()
  local e = Resolve()
  if not e then return false end
  local ov = CharWeightDB(e.class, e.specKey or "BASE")
  return next(ov) ~= nil
end

function RT.ResetToDefaults()
  local e = Resolve()
  if not e then return end
  local weights = CharWeightDB(e.class)
  weights[e.specKey or "BASE"] = {}
  RT:Invalidate()
end

function RT.ApplyWeightTable(tbl)
  if type(tbl) ~= "table" then return false end
  local e = Resolve()
  if not e then return false end
  local defaults = RT.GetDefaultsTable() or {}
  local ov = {}
  for k, v in pairs(tbl) do
    if type(v) == "number" then
      local val = clampWeight(v)
      local d = tonumber(defaults[k])
      if not (d and math.abs(d - val) < 0.005) then
        ov[k] = val
      end
    end
  end
  local weights = CharWeightDB(e.class)
  weights[e.specKey or "BASE"] = ov
  RT:Invalidate()
  return true
end

-- =====================================================================
-- Presets
-- =====================================================================
function RT.ListPresets(classFilter)
  local out = {}
  for name, rec in pairs(PresetDB()) do
    if type(rec) == "table" then
      if not classFilter or rec.class == classFilter then
        out[#out + 1] = name
      end
    end
  end
  table.sort(out)
  return out
end

function RT.SavePreset(name)
  if not name or name == "" then return false, "empty-name" end
  local e = Resolve()
  if not e then return false, "no-class" end
  local full = e.full
  local snapshot = {}
  for k, v in pairs(full) do
    if type(v) == "number" and v ~= 0 then snapshot[k] = v end
  end
  PresetDB()[name] = {
    class   = e.class,
    spec    = e.specKey or "BASE",
    weights = snapshot,
    saved   = time and time() or 0,
  }
  return true
end

function RT.LoadPreset(name)
  local rec = PresetDB()[name]
  if not rec or type(rec.weights) ~= "table" then return false, "missing" end
  return RT.ApplyWeightTable(rec.weights)
end

function RT.DeletePreset(name)
  if not name then return false end
  PresetDB()[name] = nil
  return true
end

function RT.RenamePreset(oldName, newName)
  local db = PresetDB()
  if not oldName or not newName or newName == "" then return false end
  if not db[oldName] then return false end
  if db[newName] then return false, "exists" end
  db[newName] = db[oldName]
  db[oldName] = nil
  return true
end

-- =====================================================================
-- Import / export share strings
--
-- Format:  MPW1:<CLASS>:<SPEC>:<KEY>=<val>,<KEY>=<val>,...:<checksum>
-- Plain text on purpose
-- =====================================================================
local function Checksum(s)
  local sum = 0
  for i = 1, #s do
    sum = (sum * 31 + s:byte(i)) % 65521
  end
  return sum
end

function RT.ExportString()
  local e = Resolve()
  if not e then return nil end

  local parts = {}
  for i = 1, #RT.ALL_KEYS do
    local k = RT.ALL_KEYS[i]
    local v = e.full[k]
    if v and v ~= 0 then
      parts[#parts + 1] = k .. "=" .. string.format("%.2f", v)
    end
  end
  for k, v in pairs(e.full) do
    if not RT.KEY_SET[k] and type(v) == "number" and v ~= 0 then
      parts[#parts + 1] = k .. "=" .. string.format("%.2f", v)
    end
  end

  local body = (e.class or "UNKNOWN") .. ":" .. (e.specKey or "BASE")
             .. ":" .. table.concat(parts, ",")
  return "MPW1:" .. body .. ":" .. Checksum(body)
end

function RT.ParseString(str)
  if type(str) ~= "string" then return nil, "not-a-string" end
  str = str:gsub("%s+", "")
  local class, spec, payload, sum = str:match("^MPW1:([^:]*):([^:]*):([^:]*):(%d+)$")
  if not class then return nil, "bad-format" end

  local body = class .. ":" .. spec .. ":" .. payload
  if tonumber(sum) ~= Checksum(body) then
    return nil, "bad-checksum"
  end

  local out = {}
  local n = 0
  for k, v in payload:gmatch("([%u%d_]+)=([%d%.%-]+)") do
    local num = tonumber(v)
    if num then
      out[k] = clampWeight(num)
      n = n + 1
    end
  end
  if n == 0 then return nil, "no-values" end
  return out, class, spec
end

function RT.ImportString(str, opts)
  local tbl, classOrErr, spec = RT.ParseString(str)
  if not tbl then return false, classOrErr end

  local e = Resolve()
  if e and classOrErr ~= e.class then
    return false, "class-mismatch", classOrErr
  end

  local warning, warningDetail
  if e and spec and spec ~= "" then
    local incoming = RT.NormalizeSpecKey(classOrErr, spec)
    local active   = e.specKey or "BASE"
    if incoming ~= active and incoming ~= "BASE" and active ~= "BASE" then
      if opts and opts.rejectSpecMismatch then
        return false, "spec-mismatch", incoming
      end
      warning, warningDetail = "spec-mismatch", incoming
    end
  end

  RT.ApplyWeightTable(tbl)
  return true, nil, nil, warning, warningDetail
end

-- =====================================================================
-- Invalidate whenever anything that feeds resolution changes
-- =====================================================================
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LEVEL_UP")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function()
  RT:Invalidate()
end)

MakersPath.WeightsRT = RT
