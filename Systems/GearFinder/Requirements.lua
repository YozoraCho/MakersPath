local ADDON, ns = ...
local GF = ns.Systems.GearFinder

local PROF_ID_TO_KEY = {
  [164] = "BLACKSMITHING",
  [165] = "LEATHERWORKING",
  [171] = "ALCHEMY",
  [197] = "TAILORING",
  [202] = "ENGINEERING",
  [333] = "ENCHANTING",
  [755] = "JEWELCRAFTING",
}

function GF:MakeRequirement(profId, skill)
  local key = PROF_ID_TO_KEY[tonumber(profId or 0)]
  local req = tonumber(skill or 0)
  return key, (req > 0 and req or nil)
end