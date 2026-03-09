local _, MakersPath = ...
MakersPath = MakersPath or {}
MakersPath.Static = MakersPath.Static or {}
MakersPath.Static.Craftables = MakersPath.Static.Craftables or {}
if MakersPath.client and not MakersPath.client.isTBC then return end

local S = MakersPath.Static.Craftables
S["INVTYPE_FINGER"] = S["INVTYPE_FINGER"] or {}

local seed = {
  { itemID = 25439, name = "Tigerseye Band", reqLevel = 13, source="crafted" },
  { itemID = 20823, name = "Gloom Band", reqLevel = 19, source="crafted" },
  { itemID = 20820, name = "Simple Pearl Ring", reqLevel = 17, source="crafted" },
  { itemID = 20827, name = "Ring of Silver Might", reqLevel = 21, source="crafted" },
  { itemID = 25439, name = "Tigerseye Band", reqLevel = 13, source="crafted" },
}

local seen = {}
for _, row in ipairs(S["INVTYPE_FINGER"]) do
  seen[row.itemID] = true
end

for _, row in ipairs(seed) do
  if not seen[row.itemID] then
    row.invType = "INVTYPE_FINGER"
    row.isCrafted = true
    table.insert(S["INVTYPE_FINGER"], row)
  end
end