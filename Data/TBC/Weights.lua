local _, MakersPath = ...
MakersPath = MakersPath or {}
if MakersPath.client and not MakersPath.client.isTBC then return end
local W = MakersPath.Weights
if type(W) ~= "table" then return end

local function aliasStat(tbl, fromKey, toKey, scale)
  if type(tbl) ~= "table" then return end
  if tbl[toKey] == nil and tbl[fromKey] ~= nil then
    tbl[toKey] = tbl[fromKey] * (scale or 1)
  end
end

local function applyTbcAliases(spec)
  aliasStat(spec, "HIT",          "HIT_RATING")
  aliasStat(spec, "CRIT",         "CRIT_RATING")
  aliasStat(spec, "HASTE",        "HASTE_RATING")
  aliasStat(spec, "EXPERTISE",    "EXPERTISE_RATING")
  aliasStat(spec, "HIT_SPELL",    "HIT_RATING_SPELL")
  aliasStat(spec, "CRIT_SPELL",   "CRIT_RATING_SPELL")
  aliasStat(spec, "HASTE",        "HASTE_RATING_SPELL")
  aliasStat(spec, "ATTACK_POWER", "MELEE_ATTACK_POWER")
  aliasStat(spec, "RANGED_ATTACK_POWER", "RANGED_ATTACK_POWER")
  if spec.RESILIENCE == nil then
    spec.RESILIENCE = 0.00
    spec.RESILIENCE_RATING = 0.00
  end
end

for classKey, classTbl in pairs(W) do
  if type(classTbl) == "table" then
    if type(classTbl.BASE) == "table" then
      applyTbcAliases(classTbl.BASE)
    end

    for specKey, specTbl in pairs(classTbl) do
      if specKey ~= "BASE" and type(specTbl) == "table" then
        applyTbcAliases(specTbl)
      end
    end
  end
end