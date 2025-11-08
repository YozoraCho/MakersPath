MakersPath = MakersPath or {}
MakersPath.Static = MakersPath.Static or {}
MakersPath.Static.Craftables = MakersPath.Static.Craftables or {}

local S = MakersPath.Static.Craftables
S["INVTYPE_WEAPONMAINHAND"] = S["INVTYPE_WEAPONMAINHAND"] or {}

local seed = {
  -- { itemID = <id>, name = "<name>", reqLevel = 1, source = "crafted" },
  { itemID = 7166, name = "Copper Dagger", reqLevel = 6, source="crafted" },
  { itemID = 2845, name = "Copper Axe", reqLevel = 4, source="crafted" },
  { itemID = 2844, name = "Copper Mace", reqLevel = 4, source="crafted" },
  { itemID = 2847, name = "Copper Shortsword", reqLevel = 4, source="crafted" },
  { itemID = 7955, name = "Copper Claymore", reqLevel = 6, source="crafted" },
}

local seen = {}
for _, row in ipairs(S["INVTYPE_WEAPONMAINHAND"]) do seen[row.itemID] = true end
for _, row in ipairs(seed) do
  if not seen[row.itemID] then
    row.invType = "INVTYPE_WEAPONMAINHAND"
    row.isCrafted = true
    table.insert(S["INVTYPE_WEAPONMAINHAND"], row)
  end
end
