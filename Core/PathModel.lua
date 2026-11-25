local _, MakersPath = ...
MakersPath = MakersPath or {}

local M = {}
MakersPath.PathModel = M

local floor = math.floor

local function gainOf(row)
  local g = (tonumber(row.bestScore) or 0) - (tonumber(row.eqScore) or 0)
  if g < 0 then g = 0 end
  return floor(g * 10 + 0.5) / 10
end

function M.Assess(row, ctx)
  local e = row.best
  local itemID = e.itemID
  local line = tonumber(e.__profId or e.__profSkillLine or e.reqSkill) or 0
  if line == 0 then line = nil end
  local need = tonumber(e.__needRank or e.reqSkillLevel) or 0
  local reqLevel = ctx.reqLevel(itemID, tonumber(e.reqLevel) or 0) or 0
  local level = ctx.level or 1

  local it = {
    slot = row.slot, row = row, entry = e, itemID = itemID, gain = gainOf(row),
    line = line, need = need, reqLevel = reqLevel, checks = {},
  }

  local rank = line and ctx.profRank(line) or nil
  it.rank = rank
  it.hasProf = rank ~= nil
  if not line then
    it.checks.skill = "Y"
  elseif rank == nil then
    it.checks.skill = "N"; it.learnProf = true
  elseif rank < need then
    it.checks.skill = "N"; it.skillShort = need - rank
  else
    it.checks.skill = "Y"
  end

  if not line then
    it.checks.recipe = "U"
  elseif rank == nil then
    it.checks.recipe = "N"
  else
    local k = ctx.recipeKnown(itemID, line)
    it.recipeKnown = k
    it.checks.recipe = (k == true and "Y") or (k == false and "N") or "U"
  end

  local reagents = ctx.reagents(itemID)
  it.reagents = {}
  if not reagents then
    it.checks.mats = "U"
  else
    local all, unknown = true, false
    for _, r in ipairs(reagents) do
      local have = ctx.count(r.id)
      if have == nil then unknown = true end
      it.reagents[#it.reagents + 1] = { id = r.id, num = r.num, have = have }
      if have and have < r.num then all = false end
    end
    it.checks.mats = unknown and "U" or (all and "Y" or "N")
  end

  it.checks.equip = (reqLevel <= level) and "Y" or "N"
  it.levelShort = reqLevel > level and (reqLevel - level) or nil

  if line and ctx.crafters then
    local list = ctx.crafters(line) or {}
    if list[1] then it.bestAlt = { name = list[1].name, class = list[1].class, rank = list[1].rank } end
  end

  if line and it.checks.equip == "Y" and (it.checks.skill == "N" or it.checks.recipe ~= "Y") and ctx.crafters then
    for _, cr in ipairs(ctx.crafters(line) or {}) do
      if (cr.rank or 0) >= need then
        local k = ctx.altKnows and ctx.altKnows(itemID, line, cr.key)
        if k ~= false then
          it.altCrafter = { name = cr.name, class = cr.class, rank = cr.rank, known = k }
          break
        end
      end
    end
  end
  return it
end

local function groupKey(it)
  local c = it.checks
  if c.equip == "Y" and c.skill == "Y" then
    if c.recipe == "Y" then
      if c.mats == "Y" then return "now" end
      if c.mats == "N" then return "gather" end
      return "learned"
    end
    if c.recipe == "U" then
      if not it.line then return c.mats == "Y" and "now" or "learned" end
      return "check:" .. tostring(it.line)
    end
    -- recipe missing
    if it.altCrafter then return "alt:" .. it.altCrafter.name end
    return "recipe:" .. tostring(it.line)
  end
  if c.equip == "Y" and it.altCrafter then return "alt:" .. it.altCrafter.name end
  local parts = {}
  if c.skill == "N" then
    parts[#parts + 1] = "p" .. tostring(it.line) .. "=" .. (it.learnProf and "learn" or tostring(it.need))
  elseif c.recipe == "N" then
    parts[#parts + 1] = "r" .. tostring(it.line)
  end
  if c.equip == "N" then parts[#parts + 1] = "L" .. tostring(it.reqLevel) end
  return "m:" .. table.concat(parts, ",")
end

local HERE_ORDER = { now = 1, gather = 2, learned = 3, check = 4, alt = 5, recipe = 6 }

local function tier(g)
  return g.here and 0 or 1
end

function M.Build(rows, ctx, T)
  local model = {
    items = {}, groups = {}, lanes = {}, laneIndex = {}, mats = {},
    counts = { total = 0, now = 0, gather = 0 },
  }

  for _, row in ipairs(rows or {}) do
    if row and row.best and row.best.itemID and gainOf(row) > 0 then
      local it = M.Assess(row, ctx)
      model.items[#model.items + 1] = it
      model.counts.total = model.counts.total + 1
    end
  end

  model.lanes[1] = { key = "level", kind = "level", value = ctx.level }
  model.laneIndex.level = 1
  local profs, seen = {}, {}
  for _, it in ipairs(model.items) do
    if it.line and not seen[it.line] and ctx.profRank(it.line) ~= nil then
      seen[it.line] = true
      profs[#profs + 1] = it.line
    end
  end
  table.sort(profs, function(a, b)
    local ra, rb = ctx.profRank(a), ctx.profRank(b)
    if (ra ~= nil) ~= (rb ~= nil) then return ra ~= nil end
    if ra and rb and ra ~= rb then return ra > rb end
    return (ctx.profName(a) or "") < (ctx.profName(b) or "")
  end)
  for _, line in ipairs(profs) do
    local lane = { key = line, kind = "prof", line = line, rank = ctx.profRank(line), max = ctx.profMax and ctx.profMax(line) or nil }
    model.lanes[#model.lanes + 1] = lane
    model.laneIndex[line] = #model.lanes
  end

  local byKey = {}
  for _, it in ipairs(model.items) do
    local key = groupKey(it)
    it.group = key
    local g = byKey[key]
    if not g then
      g = { key = key, items = {}, lanes = {}, gainSum = 0 }
      byKey[key] = g
      model.groups[#model.groups + 1] = g
      local kind = key:match("^(%a+)")
      g.kind = kind
      g.here = HERE_ORDER[kind] ~= nil
      g.line = it.line
      if kind == "alt" then g.crafter = it.altCrafter end
      g.bestAlt = it.bestAlt
      if kind == "m" then
        g.levelTarget = it.checks.equip == "N" and it.reqLevel or nil
        if it.checks.skill == "N" then
          g.skillTarget = it.need
          g.learnProf = it.learnProf
        elseif it.checks.recipe == "N" then
          g.learnRecipe = true
        end
      end
    end
    g.items[#g.items + 1] = it
    g.gainSum = g.gainSum + it.gain
    if g.kind == "now" then model.counts.now = model.counts.now + 1 end
    if g.kind == "gather" then model.counts.gather = model.counts.gather + 1 end
  end

  for _, g in ipairs(model.groups) do
    table.sort(g.items, function(a, b)
      if a.gain ~= b.gain then return a.gain > b.gain end
      return (a.slot or "") < (b.slot or "")
    end)
    if g.levelTarget then g.lanes[#g.lanes + 1] = model.laneIndex.level end
    if (g.skillTarget or g.learnRecipe) and g.line and model.laneIndex[g.line] then
      g.lanes[#g.lanes + 1] = model.laneIndex[g.line]
    end
    if (g.kind == "check" or g.kind == "recipe") and g.line and model.laneIndex[g.line] then
      g.lanes[#g.lanes + 1] = model.laneIndex[g.line]
    end
    table.sort(g.lanes)
    local d = 0
    if g.levelTarget then d = d + (g.levelTarget - (ctx.level or 0)) * 10 end
    if g.skillTarget then
      local r = ctx.profRank(g.line)
      d = d + (r and math.max(0, g.skillTarget - r) or (g.skillTarget + 50))
    end
    if g.learnRecipe then d = d + 5 end
    g.distance = d
    -- when the group's upgrades can be worn, for reading the Path as a progression
    local lv
    for _, it in ipairs(g.items) do if not lv or it.reqLevel < lv then lv = it.reqLevel end end
    g.sortLevel = lv or 0
  end

  table.sort(model.groups, function(a, b)
    local ta, tb = tier(a), tier(b)
    if ta ~= tb then return ta < tb end
    if a.here then
      local oa, ob = HERE_ORDER[a.kind], HERE_ORDER[b.kind]
      if oa ~= ob then return oa < ob end
    end
    if not a.here then
      if a.sortLevel ~= b.sortLevel then return a.sortLevel < b.sortLevel end
      if (a.skillTarget or 0) ~= (b.skillTarget or 0) then return (a.skillTarget or 0) < (b.skillTarget or 0) end
    end
    if a.distance ~= b.distance then return a.distance < b.distance end
    return a.gainSum > b.gainSum
  end)

  for _, lane in ipairs(model.lanes) do lane.items = {}; lane.needMax = 0 end
  for _, it in ipairs(model.items) do
    if it.checks.equip == "N" then
      local lane = model.lanes[model.laneIndex.level]
      lane.items[#lane.items + 1] = it
      if it.reqLevel > lane.needMax then lane.needMax = it.reqLevel end
    end
    local li = it.line and model.laneIndex[it.line]
    if li and not it.learnProf and (it.checks.skill == "N" or it.checks.recipe ~= "Y") then
      local lane = model.lanes[li]
      lane.items[#lane.items + 1] = it
      if it.need > lane.needMax then lane.needMax = it.need end
    end
  end

  local agg, order = {}, {}
  local crafts = 0
  for _, it in ipairs(model.items) do
    if it.group == "now" or it.group == "gather" or it.group == "learned" then
      crafts = crafts + 1
      for _, r in ipairs(it.reagents) do
        local a = agg[r.id]
        if not a then
          a = { id = r.id, need = 0, have = r.have }
          agg[r.id] = a
          order[#order + 1] = a
        end
        a.need = a.need + r.num
      end
    end
  end
  table.sort(order, function(a, b)
    local sa = (a.have or 0) < a.need
    local sb = (b.have or 0) < b.need
    if sa ~= sb then return sa end
    return a.id < b.id
  end)
  model.mats = order
  model.matsCrafts = crafts
  return model
end
