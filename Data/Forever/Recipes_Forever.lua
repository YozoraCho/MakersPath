local _, MakersPath = ...
MakersPath = MakersPath or {}
MakersPath.Professions = MakersPath.Professions or {}

local FOREVER_RECIPES = {
  -- [164] = {   -- Blacksmithing
  --   [123456] = {
  --     ["name"] = "Example Recipe",
  --     ["spell"] = 123456,
  --     ["productid"] = 654321,
  --     ["type"] = "item",
  --     ["source"] = "trainer",
  --     ["learnedat"] = "150",
  --   },
  -- },
}

local all = MakersPath.Professions.AllRecipes or {}
MakersPath.Professions.AllRecipes = all
for profId, list in pairs(FOREVER_RECIPES) do
  all[profId] = all[profId] or {}
  for spellId, rec in pairs(list) do
    all[profId][spellId] = rec
  end
end
