local _, MakersPath = ...
MakersPath = MakersPath or {}
local API = MakersPath.API or {}

local T, W = MakersPath.Theme, MakersPath.Widgets
local C, S, Tex = T.C, T.S, T.Tex
local L = MakersPath.L or {}
local R = MakersPath.RecipeInfo
local Model = MakersPath.PathModel
local Const = MakersPath.Const or {}

local function Lx(key, fallback) return (L and rawget(L, key)) or fallback or key end

local MV = {}
MakersPath.UI = MakersPath.UI or {}
MakersPath.UI.MainView = MV

local panel = MakersPathFrame
local page = panel.page

-- =================== Slots ===================
local SLOT_LABEL = {
  HeadSlot = _G.HEADSLOT, NeckSlot = _G.NECKSLOT, ShoulderSlot = _G.SHOULDERSLOT, BackSlot = _G.BACKSLOT,
  ChestSlot = _G.CHESTSLOT, ShirtSlot = _G.SHIRTSLOT, TabardSlot = _G.TABARDSLOT, WristSlot = _G.WRISTSLOT,
  HandsSlot = _G.HANDSSLOT, WaistSlot = _G.WAISTSLOT, LegsSlot = _G.LEGSSLOT, FeetSlot = _G.FEETSLOT,
  Finger0Slot = _G.INVTYPE_FINGER, Finger1Slot = _G.INVTYPE_FINGER,
  Trinket0Slot = _G.INVTYPE_TRINKET, Trinket1Slot = _G.INVTYPE_TRINKET,
  MainHandSlot = _G.MAINHANDSLOT, SecondaryHandSlot = _G.SECONDARYHANDSLOT,
  RangedSlot = _G.RANGEDSLOT, AmmoSlot = _G.AMMOSLOT,
}
local function SlotLabel(slot) return SLOT_LABEL[slot] or (slot and slot:gsub("Slot$", "")) or "?" end
MV.SlotLabel = SlotLabel

local LEFT   = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" }
local RIGHT  = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }
local BOTTOM = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot", "AmmoSlot" }
local DECOR  = { ShirtSlot = true, TabardSlot = true }

local slotInfo = {}
local function SlotInfo(slot)
  local v = slotInfo[slot]
  if v == nil then
    local ok, id, tex = pcall(GetInventorySlotInfo, slot)
    v = ok and id and { id = id, tex = tex } or false
    slotInfo[slot] = v
  end
  return v or nil
end

-- =================== Items ===================
local function ItemInfo(itemID)
  if not itemID then return nil end
  local name, link, quality, ilvl, reqLevel, _, _, _, equipLoc, icon = API.GetItemInfo(itemID)
  if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
  return name, link, quality, ilvl, reqLevel, equipLoc, icon or (API.GetItemIcon and API.GetItemIcon(itemID))
end

local function ItemName(it)
  local name = ItemInfo(it.itemID)
  return name or (it.entry and it.entry.name) or ("item:" .. tostring(it.itemID))
end

local function ItemQuality(itemID)
  local _, _, q = ItemInfo(itemID)
  return T.Quality(q or 1)
end

local function ProfSpell(line) return Const.SKILLLINE_TO_SPELL and Const.SKILLLINE_TO_SPELL[line] end
local profNameCache = {}
local function ProfName(line)
  if not line then return "?" end
  local n = profNameCache[line]
  if not n then
    local sp = ProfSpell(line)
    n = sp and API.GetSpellInfo(sp) or nil
    if n then profNameCache[line] = n end
  end
  return n or ("#" .. tostring(line))
end
local function ProfIcon(line)
  local sp = ProfSpell(line)
  return sp and API.GetSpellTexture and API.GetSpellTexture(sp) or Tex.question
end

local function fmtGain(g) return string.format("+%.1f", g or 0) end

-- =================== Context ===================
local function ViewedKey()
  return MakersPath.UI.ActiveProfileKey or R.CurrentKey()
end
local function IsCurrent() return ViewedKey() == R.CurrentKey() end

local function CharRec(key)
  return MakersPathDB and MakersPathDB.chars and MakersPathDB.chars[key] or nil
end

local function CharName(key)
  local rec = CharRec(key)
  return (rec and rec.name) or (key and key:match("^([^%-]+)")) or key or "?"
end

local function LiveProfMax(line)
  local name = ProfName(line)
  for _, s in ipairs(API.GetSkillLines and API.GetSkillLines() or {}) do
    if s.name == name and not s.isHeader then return s.maxRank end
  end
  return nil
end

local function BuildContext()
  local key = ViewedKey()
  local current = IsCurrent()
  local rec = CharRec(key)
  local profs
  if current then
    profs = MakersPath.Util and MakersPath.Util.CurrentProfMap and MakersPath.Util.CurrentProfMap() or {}
  else
    profs = rec and rec.profs or {}
  end
  local maxCache = {}
  local ctx = {
    key = key,
    current = current,
    name = current and (MakersPath.Util.CurrentCharName and MakersPath.Util.CurrentCharName() or UnitName("player") or "?") or CharName(key),
    class = current and select(2, UnitClass("player")) or (rec and rec.class),
    level = current and (UnitLevel("player") or 1) or (rec and rec.level or 1),
  }
  function ctx.profRank(line)
    local sp = ProfSpell(line)
    local r = sp and profs[sp]
    r = tonumber(r)
    return (r and r > 0) and r or nil
  end
  function ctx.profMax(line)
    if not current then return nil end
    if maxCache[line] == nil then maxCache[line] = LiveProfMax(line) or false end
    return maxCache[line] or nil
  end
  ctx.profName = ProfName
  function ctx.reqLevel(itemID, fallback)
    local _, _, _, _, req = ItemInfo(itemID)
    return (type(req) == "number" and req > 0) and req or (fallback or 0)
  end
  function ctx.recipeKnown(itemID, line) return R.IsKnown(itemID, line, key) end
  ctx.reagents = R.Reagents
  function ctx.count(itemID) if current then return R.Count(itemID) end return nil end
  function ctx.crafters(line)
    local out = {}
    local sp = ProfSpell(line)
    for k, crec in pairs(MakersPathDB and MakersPathDB.chars or {}) do
      if k ~= key and type(crec) == "table" and crec.profs and sp then
        local r = tonumber(crec.profs[sp])
        if r and r > 0 then
          out[#out + 1] = { key = k, name = crec.name or k:match("^([^%-]+)") or k, class = crec.class, rank = r }
        end
      end
    end
    table.sort(out, function(a, b) return a.rank > b.rank end)
    return out
  end
  function ctx.altKnows(itemID, line, k) return R.IsKnown(itemID, line, k) end
  return ctx
end

-- =================== Wording ===================
local function StateText(it)
  local g = it.group or ""
  local kind = g:match("^(%a+)")
  local c = it.checks
  if kind == "now" then return Lx("PATH_READY", "Ready"), "secondary", Tex.markReady, false end
  if kind == "gather" then return Lx("PATH_NEED_MATS", "Need materials"), "secondary", Tex.markMats, false end
  if kind == "learned" then return Lx("PATH_LEARNED", "Learned"), "secondary", Tex.markMats, false end
  if kind == "check" then return Lx("PATH_CHECK_RECIPE", "Check recipe"), "secondary", Tex.markMats, false end
  if kind == "alt" then return string.format(Lx("PATH_ALT_CAN_FMT", "%s can craft"), it.altCrafter.name), "secondary", Tex.markMats, c.equip == "N" end
  if kind == "recipe" then return Lx("PATH_LEARN_RECIPE", "Learn recipe"), "amber", Tex.markNeed, false end
  local parts = {}
  if c.skill == "N" then
    parts[#parts + 1] = ProfName(it.line) .. " " .. it.need
  elseif c.recipe == "N" then
    parts[#parts + 1] = Lx("PATH_RECIPE_SHORT", "Recipe")
  end
  if c.equip == "N" then
    parts[#parts + 1] = (#parts > 0 and Lx("PATH_LV_SHORT_FMT", "Lv %d") or Lx("PATH_LEVEL_FMT", "Level %d")):format(it.reqLevel)
  end
  local craftUnmet = c.skill == "N" or c.recipe == "N"
  return table.concat(parts, " · "), "amber", craftUnmet and Tex.markNeed or nil, c.equip == "N"
end

local function GroupText(g, ctx)
  local kind = g.kind
  if kind == "now" then return Lx("PATH_G_NOW", "Craft now"), Lx("PATH_G_NOW_SUB", "all four checks met") end
  if kind == "gather" then
    local short = {}
    for _, it in ipairs(g.items) do
      for _, r in ipairs(it.reagents) do if (r.have or 0) < r.num then short[r.id] = true end end
    end
    local n = 0; for _ in pairs(short) do n = n + 1 end
    return Lx("PATH_G_GATHER", "Gather materials"),
      string.format(Lx("PATH_G_GATHER_SUB_FMT", "skill and recipe met · %d |4material:materials; short"), n)
  end
  if kind == "learned" then
    return Lx("PATH_G_LEARNED", "Skill and recipe met"),
      ctx.current and Lx("PATH_G_LEARNED_NODATA", "materials aren't in the recipe data")
                  or Lx("PATH_G_LEARNED_SUB", "materials can't be checked for this character")
  end
  if kind == "check" then
    return string.format(Lx("PATH_G_CHECK_FMT", "Check your %s recipes"), ProfName(g.line)),
      string.format(Lx("PATH_G_CHECK_SUB_FMT", "skill met · open %s once to record them"), ProfName(g.line))
  end
  if kind == "alt" then
    return string.format(Lx("PATH_G_ALT_FMT", "Ask %s to craft"), g.crafter.name),
      string.format("%s %d", ProfName(g.line), g.crafter.rank or 0)
  end
  if kind == "recipe" then
    return string.format(Lx("PATH_G_RECIPE_FMT", "Learn %s recipes"), ProfName(g.line)), Lx("PATH_G_RECIPE_SUB", "skill met")
  end
  local title, prog = {}, {}
  local rank = g.line and ctx.profRank(g.line)
  local alone = (g.levelTarget and 1 or 0) + ((g.skillTarget or g.learnRecipe) and 1 or 0) == 1
  if g.skillTarget then
    if g.learnProf then
      title[#title + 1] = ProfName(g.line) .. " " .. g.skillTarget
      prog[#prog + 1] = g.bestAlt and string.format(Lx("PATH_CRAFTER_HAS_FMT", "%s has %d"), g.bestAlt.name, g.bestAlt.rank)
                                   or Lx("PATH_NO_CRAFTER", "no crafter on this account")
    else
      title[#title + 1] = alone and string.format(Lx("PATH_TRAIN_FMT", "Train %s to %d"), ProfName(g.line), g.skillTarget)
                                 or (ProfName(g.line) .. " " .. g.skillTarget)
      prog[#prog + 1] = alone and string.format(Lx("PATH_SKILL_PROG_FMT", "%d / %d · %d skill"), rank or 0, g.skillTarget, g.skillTarget - (rank or 0))
                               or string.format("%d / %d", rank or 0, g.skillTarget)
    end
  elseif g.learnRecipe then
    title[#title + 1] = Lx("PATH_LEARN_THE_RECIPE", "Learn the recipe")
    prog[#prog + 1] = Lx("PATH_G_RECIPE_SUB", "skill met")
  end
  if g.levelTarget then
    local lv = ctx.level or 0
    if alone then
      title[#title + 1] = string.format(Lx("PATH_REACH_LEVEL_FMT", "Reach level %d"), g.levelTarget)
      local d = g.levelTarget - lv
      prog[#prog + 1] = string.format(Lx("PATH_LEVEL_PROG_FMT", "%d / %d · %d |4level:levels;"), lv, g.levelTarget, d)
    else
      title[#title + 1] = string.format(Lx("PATH_AND_LEVEL_FMT", "level %d"), g.levelTarget)
      prog[#prog + 1] = string.format("%d / %d", lv, g.levelTarget)
    end
  end
  return table.concat(title, Lx("PATH_AND", " and ")), table.concat(prog, " · ")
end

local function SourceText(src)
  if not src then return nil end
  local map = {
    trainer = Lx("SRC_TRAINER", "taught by a trainer"), vendor = Lx("SRC_VENDOR", "sold by a vendor"),
    drop = Lx("SRC_DROP", "recipe drops in the world"), quest = Lx("SRC_QUEST", "from a quest"),
    reputation = Lx("SRC_REP", "from a reputation vendor"), world = Lx("SRC_DROP", "recipe drops in the world"),
  }
  return map[src:lower()] or src
end

-- =================== Tooltips ===================
local function AddChecks(it, ctx)
  local c = it.checks
  -- skill
  if not it.line then
    W.TipCheck("skill", "Y", Lx("TIP_NO_PROF", "No profession recorded for this item"))
  elseif it.learnProf then
    W.TipCheck("skill", "N", string.format(Lx("TIP_NOT_LEARNED_NEED_FMT", "%s not learned on %s · needs %d"), ProfName(it.line), ctx.name, it.need))
  else
    W.TipCheck("skill", c.skill, string.format(Lx("TIP_SKILL_FMT", "%s %d · you have %d"), ProfName(it.line), it.need, it.rank or 0))
  end
  -- recipe
  if c.recipe == "Y" then
    W.TipCheck("recipe", "Y", Lx("TIP_RECIPE_KNOWN", "Recipe known"))
  elseif c.recipe == "N" then
    local src = SourceText(R.Source(it.itemID))
    W.TipCheck("recipe", "N", Lx("TIP_RECIPE_UNKNOWN", "Recipe not known") .. (src and (" · " .. src) or ""))
  else
    W.TipCheck("recipe", "U", string.format(Lx("TIP_RECIPE_UNREC_FMT", "Recipes not recorded yet · open %s once"), ProfName(it.line)))
  end
  -- materials
  if #it.reagents == 0 then
    W.TipCheck("mats", "U", Lx("TIP_MATS_NODATA", "Materials aren't in the recipe data"))
  elseif c.mats == "U" then
    W.TipCheck("mats", "U", Lx("TIP_MATS_ALT", "Bags can only be read on the character you're playing"))
  else
    local parts = {}
    for _, r in ipairs(it.reagents) do
      local n = ItemInfo(r.id) or ("item:" .. r.id)
      parts[#parts + 1] = string.format("%s %d/%d", n, r.have or 0, r.num)
    end
    W.TipCheck("mats", c.mats, table.concat(parts, " · "))
  end
  -- equip
  if c.equip == "Y" then
    W.TipCheck("equip", "Y", string.format(Lx("TIP_EQUIP_OK_FMT", "Can equip · level %d"), it.reqLevel))
  else
    W.TipCheck("equip", "N", string.format(Lx("TIP_EQUIP_FMT", "Equip at level %d · you are %d"), it.reqLevel, ctx.level))
  end
end

function MV.ItemTooltip(owner, it, ctx, isAlt)
  W.TipBegin(owner, "ANCHOR_RIGHT", 270)
  local q = ItemQuality(it.itemID)
  GameTooltip:AddLine(ItemName(it), q[1], q[2], q[3])
  W.TipLine(SlotLabel(it.slot) .. " · " .. T.Wrap("tipGold", fmtGain(it.gain) .. " " .. Lx("TIP_UPGRADE", "upgrade")), { 1, 1, 1 })
  AddChecks(it, ctx)
  if it.altCrafter then
    W.TipLine(string.format(Lx("TIP_ALT_CRAFTER_FMT", "%s can craft this (%s %d)"), it.altCrafter.name, ProfName(it.line), it.altCrafter.rank), "brassLight")
  elseif it.learnProf then
    if it.bestAlt then
      W.TipLine(string.format(Lx("TIP_BEST_ALT_FMT", "%s has %s %d · needs %d"), it.bestAlt.name, ProfName(it.line), it.bestAlt.rank, it.need), "secondary")
    else
      W.TipLine(string.format(Lx("TIP_NOBODY_HAS_FMT", "No other character on this account has %s"), ProfName(it.line)), "muted")
    end
  end
  W.TipFoot(isAlt and Lx("TIP_FOOT_LINK", "Shift-click to link · Ctrl-click to preview")
                   or Lx("TIP_FOOT_ITEM", "Click to inspect · Shift-click to link · Ctrl-click to preview"))
  GameTooltip:Show()
end

local function ListItems(items, max)
  local names = {}
  for i, it in ipairs(items) do
    if i > (max or 4) then
      names[#names + 1] = string.format(Lx("TIP_MORE_FMT", "%d more"), #items - (max or 4))
      break
    end
    names[#names + 1] = string.format("%s (%s)", ItemName(it), SlotLabel(it.slot))
  end
  return table.concat(names, ", ")
end

function MV.LaneTooltip(owner, lane, ctx)
  W.TipBegin(owner, "ANCHOR_BOTTOMRIGHT", 290)
  if lane.kind == "level" then
    W.TipLine(Lx("TIP_LEVEL_TRAIL", "Level trail"), "tipGold")
    W.TipLine(string.format(Lx("TIP_LEVEL_NOW_FMT", "%s is level %d"), ctx.name, ctx.level), { 1, 1, 1 })
    if #lane.items > 0 then
      W.TipLine(string.format(Lx("TIP_LEVEL_WAIT_FMT", "%d |4upgrade waits:upgrades wait; on a higher level: %s"), #lane.items, ListItems(lane.items)), { 1, 1, 1 })
      W.TipLine(string.format(Lx("TIP_LEVEL_MAX_FMT", "Highest level needed: %d"), lane.needMax), "secondary")
    else
      W.TipLine(Lx("TIP_LEVEL_NONE", "Nothing on The Path is waiting on your level."), "secondary")
    end
  else
    local name = ProfName(lane.line)
    W.TipLine(string.format(Lx("TIP_PROF_TRAIL_FMT", "%s trail"), name), "tipGold")
    if lane.rank then
      W.TipLine(lane.max and string.format("%s %d / %d", name, lane.rank, lane.max) or string.format("%s %d", name, lane.rank), { 1, 1, 1 })
    else
      W.TipLine(string.format(Lx("TIP_NOT_LEARNED_ON_FMT", "Not learned on %s"), ctx.name), "amber")
    end
    if #lane.items > 0 then
      W.TipLine(string.format(Lx("TIP_PROF_WAIT_FMT", "%d |4upgrade waits:upgrades wait; on this trail: %s"), #lane.items, ListItems(lane.items)), { 1, 1, 1 })
      W.TipLine(string.format(Lx("TIP_PROF_MAX_FMT", "Highest skill these need: %s %d"), name, lane.needMax), "secondary")
    end
    if lane.rank then
      local n = R.KnownCount(lane.line, ctx.key)
      if n then W.TipLine(string.format(Lx("TIP_RECIPES_REC_FMT", "%d recipes recorded"), n), "secondary")
      else W.TipLine(string.format(Lx("TIP_RECIPE_UNREC_FMT", "Recipes not recorded yet · open %s once"), name), "muted") end
    end
    local cr = ctx.crafters(lane.line)
    if #cr > 0 then
      local parts = {}
      for i, c in ipairs(cr) do if i <= 4 then parts[#parts + 1] = string.format("%s %d", c.name, c.rank) end end
      W.TipLine(string.format(Lx("TIP_ALSO_ON_ACCOUNT_FMT", "Also on this account: %s"), table.concat(parts, ", ")), "secondary")
    else
      W.TipLine(string.format(Lx("TIP_NOBODY_HAS_FMT", "No other character on this account has %s"), name), "muted")
    end
  end
  W.TipFoot(Lx("TIP_TRAIL_FOOT", "Each trail is one thing you can improve. Trails run side by side and don't depend on each other. The highlighted line shows where this one leads."))
  GameTooltip:Show()
end

function MV.GroupTooltip(owner, g, ctx, model, laneIdx)
  W.TipBegin(owner, "ANCHOR_RIGHT", 290)
  local title, prog = GroupText(g, ctx)
  local kind = g.kind
  if kind == "m" or kind == "recipe" or kind == "check" then
    W.TipLine(Lx("TIP_MILESTONE", "Milestone") .. " · " .. title, "tipGold")
    local lane = laneIdx and model.lanes[laneIdx]
    if lane and lane.kind == "level" then
      W.TipLine(string.format(Lx("TIP_ON_LEVEL_FMT", "On the level trail · you are %d, %d to go"), ctx.level, (g.levelTarget or ctx.level) - ctx.level), { 1, 1, 1 })
    elseif lane then
      local r = ctx.profRank(lane.line)
      if not r then
        W.TipLine(string.format(Lx("TIP_ON_PROF_UNL_FMT", "On the %s trail · not learned"), ProfName(lane.line)), { 1, 1, 1 })
      elseif g.skillTarget then
        W.TipLine(string.format(Lx("TIP_ON_PROF_FMT", "On the %s trail · you have %d, %d to go"), ProfName(lane.line), r, math.max(0, g.skillTarget - r)), { 1, 1, 1 })
      else
        W.TipLine(string.format(Lx("TIP_ON_PROF_MET_FMT", "On the %s trail · skill met (%d)"), ProfName(lane.line), r), { 1, 1, 1 })
      end
    else
      W.TipLine(prog, { 1, 1, 1 })
    end
    if g.learnProf then
      W.TipLine(string.format(Lx("TIP_OTHER_CRAFTER_FMT", "%s doesn't have %s, so these are made by another character."), ctx.name, ProfName(g.line)), "secondary")
    end
    W.TipLine(string.format(Lx("TIP_UNLOCKS_FMT", "Unlocks %d |4upgrade:upgrades;: %s"), #g.items, ListItems(g.items)), { 1, 1, 1 })
    if #g.lanes > 1 then W.TipLine(Lx("TIP_BOTH_NEEDED", "Both are needed; the bar joins the two trails."), "secondary") end
    if g.skillTarget then
      local missing, unknown = 0, 0
      for _, it in ipairs(g.items) do
        if it.checks.recipe == "N" then missing = missing + 1 elseif it.checks.recipe == "U" then unknown = unknown + 1 end
      end
      if missing > 0 and not g.learnProf then
        W.TipCheck("recipe", "N", string.format(Lx("TIP_SKILL_NOT_ENOUGH_FMT", "Skill alone isn't enough: %d |4recipe is:recipes are; still unknown"), missing))
      elseif unknown > 0 then
        W.TipCheck("recipe", "U", string.format(Lx("TIP_RECIPE_UNREC_FMT", "Recipes not recorded yet · open %s once"), ProfName(g.line)))
      end
    end
    if kind == "check" then W.TipLine(string.format(Lx("TIP_CHECK_BODY_FMT", "You have the skill. Open %s once so Maker's Path can record which recipes you know."), ProfName(g.line)), "secondary") end
    W.TipFoot(Lx("TIP_MILESTONE_FOOT", "Milestones are grouped by what unlocks them. Work toward any of them, in any order."))
  else
    W.TipLine(title, "tipGold")
    if kind == "now" then
      W.TipLine(Lx("TIP_NOW_BODY", "Every check is met, materials included. You can make these right now."), { 1, 1, 1 })
    elseif kind == "gather" then
      W.TipLine(Lx("TIP_GATHER_BODY", "You have the skill and the recipe, but not enough materials in your bags."), { 1, 1, 1 })
      local short = {}
      for _, m in ipairs(model.mats) do
        if (m.have or 0) < m.need then short[#short + 1] = string.format("%s %d/%d", ItemInfo(m.id) or ("item:" .. m.id), m.have or 0, m.need) end
      end
      if #short > 0 then W.TipCheck("mats", "N", table.concat(short, " · ")) end
    elseif kind == "learned" then
      W.TipLine(ctx.current and Lx("TIP_LEARNED_NODATA", "Skill and recipe are met. This game version's recipe data has no material lists, so check them in your profession window.")
                             or Lx("TIP_LEARNED_BODY", "Skill and recipe are met. Bags can only be read on the character you're playing."), { 1, 1, 1 })
    elseif kind == "alt" then
      W.TipLine(string.format(Lx("TIP_ALT_BODY_FMT", "%s has %s %d. Crafted items can be traded unless they bind on pickup."), g.crafter.name, ProfName(g.line), g.crafter.rank or 0), { 1, 1, 1 })
    end
    W.TipLine(string.format(Lx("TIP_GROUP_ITEMS_FMT", "%d |4upgrade:upgrades;: %s"), #g.items, ListItems(g.items)), "secondary")
  end
  GameTooltip:Show()
end

function MV.GuideTooltip(owner, model)
  W.TipBegin(owner, "ANCHOR_BOTTOMRIGHT", 300)
  W.TipLine(Lx("GUIDE_TITLE", "How to read The Path"), "tipGold")
  W.TipLine(Lx("GUIDE_SUB", "A roadmap of your crafted upgrades, rebuilt whenever your gear, level or professions change."), { 1, 1, 1 })
  GameTooltip:AddLine(" ")
  W.TipLine(Lx("GUIDE_TRAILS", "Trails: your level and each crafting profession. Each runs top to bottom."), { 1, 1, 1 })
  W.TipLine(Lx("GUIDE_MILESTONES", "Milestones: a coin on a trail marks the skill or level an upgrade needs. A bar joining two coins means both are needed."), { 1, 1, 1 })
  W.TipLine(Lx("GUIDE_NOW", "Craft now: every check is met, materials included."), "brassLight")
  W.TipLine(Lx("GUIDE_GATHER", "Gather materials: you have the skill and the recipe, but not enough materials in your bags."), "brassLight")
  GameTooltip:AddLine(" ")
  for _, k in ipairs(T.CHECKS) do
    local label = ({ skill = Lx("CHECK_SKILL", "Profession skill"), recipe = Lx("CHECK_RECIPE", "Recipe known"),
                     mats = Lx("CHECK_MATS", "Materials in bags"), equip = Lx("CHECK_EQUIP", "Can equip") })[k]
    W.TipLine(T.PipInline(k, "Y") .. " " .. T.PipInline(k, "N") .. " " .. T.PipInline(k, "U") .. "  " .. label, "secondary")
  end
  W.TipLine(Lx("GUIDE_STATES", "Outline: met · Amber: not met · Dashed: not known yet"), "muted")
  local gf = MakersPath.GearFinder
  local n = gf and gf.GetIndexedCount and gf:GetIndexedCount() or 0
  W.TipFoot(string.format(Lx("GUIDE_FOOT_FMT", "Nothing here has to be done in order. Checked against %d craftable items."), n))
  GameTooltip:Show()
end

-- =================== Layout ===================
local body = CreateFrame("Frame", nil, page)
body:SetPoint("TOPLEFT", panel.header, "BOTTOMLEFT")
body:SetPoint("BOTTOMRIGHT", panel.footer, "TOPRIGHT")

local function Rail(side)
  local f = CreateFrame("Frame", nil, body)
  f:SetWidth(S.railW)
  if side == "LEFT" then
    f:SetPoint("TOPLEFT"); f:SetPoint("BOTTOMLEFT", 0, S.bottomRail)
  else
    f:SetPoint("TOPRIGHT"); f:SetPoint("BOTTOMRIGHT", 0, S.bottomRail)
  end
  local bg = W.Tile(f, Tex.rail, "BACKGROUND", -4)
  bg:SetAllPoints()
  W.KeepTiled(f, bg)
  local inner = side == "LEFT" and "RIGHT" or "LEFT"
  local a = W.Line(f, "edgeLight", "BORDER", true); a:SetPoint("TOP" .. inner); a:SetPoint("BOTTOM" .. inner)
  local b = W.Line(f, "ruleDark", "BORDER", true)
  b:SetPoint("TOP" .. inner, side == "LEFT" and -1 or 1, 0); b:SetPoint("BOTTOM" .. inner, side == "LEFT" and -1 or 1, 0)
  local sh = W.Fill(f, { 0, 0, 0, 0.6 }, "BORDER"); sh:SetPoint("TOPLEFT"); sh:SetPoint("TOPRIGHT"); sh:SetHeight(2)
  return f
end

local leftRail, rightRail = Rail("LEFT"), Rail("RIGHT")

local center = CreateFrame("Frame", nil, body)
center:SetPoint("TOPLEFT", leftRail, "TOPRIGHT")
center:SetPoint("BOTTOMRIGHT", rightRail, "BOTTOMLEFT")

local bottomRail = CreateFrame("Frame", nil, body)
bottomRail:SetPoint("BOTTOMLEFT"); bottomRail:SetPoint("BOTTOMRIGHT")
bottomRail:SetHeight(S.bottomRail)
do
  local bg = W.Tile(bottomRail, Tex.rail, "BACKGROUND", -4); bg:SetAllPoints(); W.KeepTiled(bottomRail, bg)
  local a = W.Line(bottomRail, "edgeLight", "BORDER"); a:SetPoint("TOPLEFT"); a:SetPoint("TOPRIGHT")
  local b = W.Line(bottomRail, "ruleDark", "BORDER"); b:SetPoint("TOPLEFT", 0, -1); b:SetPoint("TOPRIGHT", 0, -1)
end

local area = CreateFrame("Frame", nil, center)
area:SetPoint("TOPLEFT", 12, -8)
area:SetPoint("BOTTOMRIGHT", center, "BOTTOMRIGHT", -12, 6)

-- =================== Shared State ===================
MV.model, MV.ctx = nil, nil
MV.selected = nil
MV.hoverSlot = nil
MV.hotLane = nil
local railRows = {}
local itemBySlot = {}
local rowsBySlot = {}

local Redraw

-- =================== Rail Rows ===================
local function ApplyRowHover(row)
  local on = MV.hoverSlot == row.slot or MV.selected == row.slot
  row.hl:SetShown(on)
  row.socket:SetHover(MV.hoverSlot == row.slot)
  row.socket:SetSelected(MV.selected == row.slot)
end

local function OnRowEnter(row)
  MV.hoverSlot = row.slot
  for _, r in pairs(railRows) do ApplyRowHover(r) end
  if MV.ApplyPathHover then MV.ApplyPathHover() end
  local it = itemBySlot[row.slot]
  if it then
    MV.ItemTooltip(row, it, MV.ctx)
  elseif row.equippedInv and IsCurrent() then
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetInventoryItem("player", row.equippedInv)
    GameTooltip:Show()
  else
    W.SimpleTooltip(row, SlotLabel(row.slot), row.emptyNote)
  end
end

local function OnRowLeave(row)
  if MV.hoverSlot == row.slot then MV.hoverSlot = nil end
  for _, r in pairs(railRows) do ApplyRowHover(r) end
  if MV.ApplyPathHover then MV.ApplyPathHover() end
  W.TipHide()
end

local function LinkOrPreview(itemID)
  local _, link = ItemInfo(itemID)
  if not link then return false end
  if IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(link) return true end
  if IsModifiedClick("DRESSUP") then DressUpItemLink(link) return true end
  return false
end

local function OnRowClick(row)
  local it = itemBySlot[row.slot]
  if not it then return end
  if LinkOrPreview(it.itemID) then return end
  MV.Select(MV.selected ~= row.slot and row.slot or nil)
end

local function NewRailRow(parent, side, slot)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(S.railRow)
  row.slot = slot
  row.side = side
  row.hl = W.Fill(row, "selected", "BACKGROUND", 1); row.hl:SetAllPoints(); row.hl:Hide()
  row.socket = W.Socket(row, S.socket)
  row.socket:EnableMouse(false)
  row.title = W.Text(row, side == "BOTTOM" and "small" or "body", "bone")
  row.meta = W.Text(row, "small", "secondary")
  row.gain = W.Text(row, "num", "bone")
  if side == "RIGHT" then
    row.socket:SetPoint("RIGHT", -4, 0)
    row.socket:SetMarksSide("LEFT")
    row.title:SetPoint("BOTTOMRIGHT", row.socket, "LEFT", -8, 1)
    row.title:SetPoint("BOTTOMLEFT", row, "LEFT", 4, 1)
    row.title:SetJustifyH("RIGHT")
    row.gain:SetPoint("TOPRIGHT", row.socket, "LEFT", -8, -2)
    row.meta:SetPoint("TOPRIGHT", row.gain, "TOPLEFT", -4, 0)
    row.meta:SetPoint("TOPLEFT", row, "LEFT", 4, -2)
    row.meta:SetJustifyH("RIGHT")
  else
    row.socket:SetPoint("LEFT", 4, 0)
    row.title:SetPoint("BOTTOMLEFT", row.socket, "RIGHT", 8, 1)
    row.title:SetPoint("BOTTOMRIGHT", row, "RIGHT", -4, 1)
    row.gain:SetPoint("TOPLEFT", row.socket, "RIGHT", 8, -2)
    row.meta:SetPoint("TOPLEFT", row.gain, "TOPRIGHT", 4, 0)
    row.meta:SetPoint("TOPRIGHT", row, "RIGHT", -4, -2)
  end
  row.title:SetJustifyV("BOTTOM")
  if side ~= "BOTTOM" then
    row.title:SetWordWrap(true)
    if row.title.SetMaxLines then row.title:SetMaxLines(2) end
  end
  row.meta:SetHeight(14)
  row:SetScript("OnEnter", OnRowEnter)
  row:SetScript("OnLeave", OnRowLeave)
  row:RegisterForClicks("LeftButtonUp")
  row:SetScript("OnClick", OnRowClick)
  railRows[slot] = row
  return row
end

local leftRows, rightRows, bottomRows = {}, {}, {}
for i, slot in ipairs(LEFT) do leftRows[i] = NewRailRow(leftRail, "LEFT", slot) end
for i, slot in ipairs(RIGHT) do rightRows[i] = NewRailRow(rightRail, "RIGHT", slot) end
for i, slot in ipairs(BOTTOM) do bottomRows[i] = NewRailRow(bottomRail, "BOTTOM", slot) end

local function LayoutRails()
  local function stack(rail, rows)
    local h = rail:GetHeight() or 0
    if h < S.railRow * 2 then return end
    local n = #rows
    local step = n > 1 and math.max(S.railRow, (h - 12 - S.railRow) / (n - 1)) or 0
    if step * (n - 1) + S.railRow > h - 8 then step = (h - 8 - S.railRow) / (n - 1) end
    for i, row in ipairs(rows) do
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 4, -(6 + (i - 1) * step))
      row:SetPoint("RIGHT", rail, "RIGHT", -6, 0)
    end
  end
  stack(leftRail, leftRows)
  stack(rightRail, rightRows)
  local w = (bottomRail:GetWidth() or 0) - 12
  if w < 200 then return end
  local cell = w / #bottomRows
  for i, row in ipairs(bottomRows) do
    row:ClearAllPoints()
    row:SetPoint("LEFT", bottomRail, "LEFT", 6 + (i - 1) * cell, 0)
    row:SetWidth(cell - 4)
  end
end

local relayoutQueued = false
local function QueueRelayout(tries)
  if relayoutQueued then return end
  relayoutQueued = true
  C_Timer.After(0, function()
    relayoutQueued = false
    if not panel:IsShown() then return end
    if (leftRail:GetHeight() or 0) < S.railRow * 2 or (bottomRail:GetWidth() or 0) < 200 then
      if (tries or 0) < 10 then QueueRelayout((tries or 0) + 1) end
      return
    end
    LayoutRails()
    for _, r in pairs(railRows) do MV.CenterBottomRow(r) end
    if MV.LayoutPath then MV.LayoutPath() end
  end)
end
MV.QueueRelayout = QueueRelayout
body:SetScript("OnSizeChanged", function() QueueRelayout() end)
panel:HookScript("OnSizeChanged", function() QueueRelayout() end)

local function CenterBottomRow(row)
  if row.side ~= "BOTTOM" then return end
  local w = row:GetWidth() or 0
  if w <= 0 then return end
  local metaW = (row.meta:GetText() or "") ~= "" and row.meta:GetStringWidth() or 0
  local gainW = (row.gain:GetText() or "") ~= "" and (row.gain:GetStringWidth() + 4) or 0
  local textW = math.max(row.title:GetStringWidth() or 0, gainW + metaW)
  textW = math.min(textW, w - S.socket - 12)
  local off = math.max(4, math.floor((w - (S.socket + 8 + textW)) / 2))
  row.socket:ClearAllPoints()
  row.socket:SetPoint("LEFT", off, 0)
end

MV.CenterBottomRow = CenterBottomRow

local RenderRowInner
local function RenderRow(row, slot, building)
  RenderRowInner(row, slot, building)
  CenterBottomRow(row)
end

RenderRowInner = function(row, slot, building)
  local it = itemBySlot[slot]
  row.equippedInv = nil
  row.emptyNote = nil
  row:SetAlpha(1)
  row.socket:SetMarks(nil, false)
  row.gain:SetText("")
  if DECOR[slot] then
    local info = SlotInfo(slot)
    row.socket.icon:SetTexture(info and info.tex or nil)
    row.socket.icon:SetDesaturated(true)
    row.socket:SetQualityColor(C.well)
    row.title:SetText(SlotLabel(slot)); W.TextColor(row.title, "muted")
    row.meta:SetText("")
    row:SetAlpha(0.45)
    row:EnableMouse(false)
    return
  end
  row:EnableMouse(true)
  row.socket.icon:SetDesaturated(false)
  if it then
    local name, _, quality, _, _, _, icon = ItemInfo(it.itemID)
    local q = T.Quality(quality or 1)
    row.socket.icon:SetTexture(icon or Tex.question)
    row.socket:SetQualityColor(q)
    row.title:SetText(name or ItemName(it)); W.TextColor(row.title, q)
    local text, color, mark, lock = StateText(it)
    row.gain:SetText(fmtGain(it.gain))
    W.TextColor(row.gain, it.group == "now" and "bone" or "secondary")
    row.meta:SetText(text); W.TextColor(row.meta, color)
    row.socket:SetMarks(mark, lock)
    return
  end
  local info = SlotInfo(slot)
  local invId = info and info.id
  local eqID = IsCurrent() and invId and GetInventoryItemID("player", invId) or nil
  local outOfAmmo = false
  if eqID and slot == "AmmoSlot" then
    local _, _, _, _, _, classID = API.GetItemInfoInstant(eqID)
    local n = GetInventoryItemCount and GetInventoryItemCount("player", invId)
    local ranged = SlotInfo("RangedSlot")
    local rangedID = ranged and GetInventoryItemID("player", ranged.id)
    local _, _, _, _, _, rClass, rSub = API.GetItemInfoInstant(rangedID or 0)
    local usesAmmo = rClass == 2 and (rSub == 2 or rSub == 3 or rSub == 18)
    if classID ~= 6 or not usesAmmo then
      eqID = nil
    elseif not n or n <= 0 then
      eqID, outOfAmmo = nil, true
    end
  end
  if eqID then
    local name, _, quality, _, _, _, icon = ItemInfo(eqID)
    local q = T.Quality(quality or 1)
    row.equippedInv = invId
    row.socket.icon:SetTexture(GetInventoryItemTexture("player", invId) or icon)
    row.socket:SetQualityColor(q, 0.8)
    row.title:SetText(name or ""); W.TextColor(row.title, q)
    row.meta:SetText(Lx("RAIL_EQUIPPED", "equipped")); W.TextColor(row.meta, "muted")
    row:SetAlpha(0.72)
  else
    row.socket.icon:SetTexture(info and info.tex or nil)
    row.socket:SetQualityColor({ 0.165, 0.137, 0.106, 1 })
    row.title:SetText(SlotLabel(slot)); W.TextColor(row.title, "muted")
    local note = (building and not rowsBySlot[slot]) and Lx("CALCULATING", "Calculating...")
              or outOfAmmo and Lx("RAIL_OUT_OF_AMMO", "out of ammo") or ""
    row.meta:SetText(note); W.TextColor(row.meta, "faint")
    row.emptyNote = Lx("RAIL_NOTHING", "No crafted upgrade for this slot right now.")
    row:SetAlpha(0.85)
  end
end

-- =================== The Path ===================
local pathView = CreateFrame("Frame", nil, area)
pathView:SetAllPoints()

local titleFS = W.Text(pathView, "heading", "brassLight")
titleFS:SetPoint("TOPLEFT", 0, -2)
titleFS:SetText(Lx("PATH_TITLE", "The Path"))

local guide = CreateFrame("Button", nil, pathView)
guide:SetSize(15, 15)
guide:SetPoint("LEFT", titleFS, "RIGHT", 6, 0)
guide.ring = guide:CreateTexture(nil, "ARTWORK"); guide.ring:SetTexture(Tex.coin); guide.ring:SetAllPoints()
guide.q = W.Text(guide, "num", "secondary"); guide.q:SetPoint("CENTER", 0.5, 0); guide.q:SetText("?")
guide:SetScript("OnEnter", function(self) self.ring:SetTexture(Tex.coinHot); MV.GuideTooltip(self, MV.model) end)
guide:SetScript("OnLeave", function(self) self.ring:SetTexture(Tex.coin); W.TipHide() end)

local summaryFS = W.Text(pathView, "body", "secondary")
summaryFS:SetPoint("LEFT", guide, "RIGHT", 8, 0)
summaryFS:SetPoint("RIGHT", pathView, "RIGHT")

local laneBar = CreateFrame("Frame", nil, pathView)
laneBar:SetPoint("TOPLEFT", 0, -24)
laneBar:SetPoint("TOPRIGHT", 0, -24)
laneBar:SetHeight(30)
local laneCells = {}

local function LaneCell(i)
  local c = laneCells[i]
  if c then return c end
  c = CreateFrame("Button", nil, laneBar)
  c:SetHeight(30)
  c.top = W.Fill(c, "trail", "ARTWORK"); c.top:SetPoint("TOPLEFT"); c.top:SetPoint("TOPRIGHT"); c.top:SetHeight(2)
  c.hl = W.Fill(c, "hover", "BACKGROUND"); c.hl:SetAllPoints(); c.hl:Hide()
  c.ring = c:CreateTexture(nil, "ARTWORK"); c.ring:SetTexture(Tex.coin); c.ring:SetSize(20, 20); c.ring:SetPoint("LEFT", 0, -1)
  c.icon = c:CreateTexture(nil, "OVERLAY"); c.icon:SetSize(12, 12); c.icon:SetPoint("CENTER", c.ring, "CENTER")
  c.label = W.Text(c, "small", "muted"); c.label:SetPoint("TOPLEFT", c.ring, "TOPRIGHT", 5, 3); c.label:SetPoint("RIGHT", -2, 0)
  c.value = W.Text(c, "body", "bone"); c.value:SetPoint("TOPLEFT", c.label, "BOTTOMLEFT", 0, -1); c.value:SetPoint("RIGHT", -2, 0)
  c:SetScript("OnEnter", function(self)
    MV.hotLane = self.index
    self.hl:Show()
    if MV.ApplyPathHover then MV.ApplyPathHover() end
    MV.LaneTooltip(self, MV.model.lanes[self.index], MV.ctx)
  end)
  c:SetScript("OnLeave", function(self)
    MV.hotLane = nil
    self.hl:Hide()
    if MV.ApplyPathHover then MV.ApplyPathHover() end
    W.TipHide()
  end)
  laneCells[i] = c
  return c
end

local scroll = CreateFrame("ScrollFrame", nil, pathView)
scroll:SetPoint("TOPLEFT", laneBar, "BOTTOMLEFT", 0, -4)
scroll:SetPoint("RIGHT", pathView, "RIGHT")
scroll:SetPoint("BOTTOM", pathView, "BOTTOM")
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(1, 1)
scroll:SetScrollChild(content)
scroll:EnableMouseWheel(true)

local fade = scroll:CreateTexture(nil, "OVERLAY", nil, 6)
fade:SetTexture(Tex.fade)
fade:SetPoint("BOTTOMLEFT"); fade:SetPoint("BOTTOMRIGHT"); fade:SetHeight(32)

local moreFS = W.Text(pathView, "small", "muted", "OVERLAY")
moreFS:SetPoint("TOPRIGHT", scroll, "BOTTOMRIGHT", -2, -2)

local matsStrip = CreateFrame("Frame", nil, pathView)
matsStrip:SetPoint("BOTTOMLEFT"); matsStrip:SetPoint("BOTTOMRIGHT")
matsStrip:SetHeight(1)
matsStrip:Hide()
do
  local r = W.Rule(matsStrip); r:SetPoint("TOPLEFT"); r:SetPoint("TOPRIGHT")
end
matsStrip.label = W.Text(matsStrip, "body", "brass")
matsStrip.label:SetPoint("TOPLEFT", 0, -8)
matsStrip.list = W.Text(matsStrip, "body", "secondary")
matsStrip.list:SetPoint("TOPLEFT", matsStrip.label, "TOPRIGHT", 10, 0)
matsStrip.list:SetPoint("RIGHT")
matsStrip.list:SetWordWrap(true)
matsStrip.list:SetJustifyV("TOP")
if matsStrip.list.SetMaxLines then matsStrip.list:SetMaxLines(2) end
matsStrip:SetScript("OnEnter", function(self)
  if not MV.model then return end
  W.TipBegin(self, "ANCHOR_TOP", 280)
  W.TipLine(self.label:GetText() or "", "tipGold")
  for _, m in ipairs(MV.model.mats) do
    local short = (m.have or 0) < m.need
    W.TipLine(string.format("%s  %d / %d", ItemInfo(m.id) or ("item:" .. m.id), m.have or 0, m.need), short and "amber" or "secondary", false)
  end
  GameTooltip:Show()
end)
matsStrip:SetScript("OnLeave", W.TipHide)

local emptyBox = CreateFrame("Frame", nil, pathView)
emptyBox:SetPoint("TOPLEFT", laneBar, "BOTTOMLEFT", 0, -12)
emptyBox:SetPoint("RIGHT")
emptyBox:SetHeight(160)
emptyBox.title = W.Text(emptyBox, "name", "bone"); emptyBox.title:SetPoint("TOPLEFT", S.pathIndent, -60)
emptyBox.text = W.Text(emptyBox, "body", "secondary"); emptyBox.text:SetPoint("TOPLEFT", emptyBox.title, "BOTTOMLEFT", 0, -6)
emptyBox.text:SetPoint("RIGHT", -10, 0); emptyBox.text:SetWordWrap(true); emptyBox.text:SetJustifyV("TOP")
emptyBox.note = W.Text(emptyBox, "body", "muted"); emptyBox.note:SetPoint("TOPLEFT", emptyBox.text, "BOTTOMLEFT", 0, -8)
emptyBox.note:SetPoint("RIGHT", -10, 0); emptyBox.note:SetWordWrap(true)
emptyBox.lines = {}

local blocks = {}
local BLOCK_HEAD = 6 + 18 + 3
local BLOCK_TAIL = 8

local function LaneX(i) return 6 + (i - 1) * S.laneStep + 8 end

local function NewItemRow(parent)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(S.itemRow)
  r.hl = W.Fill(r, "hover", "BACKGROUND"); r.hl:SetAllPoints(); r.hl:Hide()
  r.hlTop = W.Line(r, "edgeLight", "BORDER"); r.hlTop:SetPoint("TOPLEFT"); r.hlTop:SetPoint("TOPRIGHT"); r.hlTop:Hide()
  r.icon = W.ItemIcon(r, 22); r.icon:SetPoint("LEFT", 4, 0)
  r.gain = W.Text(r, "num", "bone"); r.gain:SetPoint("RIGHT", -4, 0); r.gain:SetWidth(40); r.gain:SetJustifyH("RIGHT")
  r.pips = W.PipRow(r); r.pips:SetPoint("RIGHT", r.gain, "LEFT", -6, 0)
  r.name = W.Text(r, "body", "bone"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 7, 0); r.name:SetPoint("RIGHT", r.pips, "LEFT", -6, 0)
  r:RegisterForClicks("LeftButtonUp")
  r:SetScript("OnEnter", function(self)
    MV.hoverSlot = self.item.slot
    for _, rr in pairs(railRows) do ApplyRowHover(rr) end
    MV.ApplyPathHover()
    MV.ItemTooltip(self, self.item, MV.ctx)
  end)
  r:SetScript("OnLeave", function(self)
    MV.hoverSlot = nil
    for _, rr in pairs(railRows) do ApplyRowHover(rr) end
    MV.ApplyPathHover()
    W.TipHide()
  end)
  r:SetScript("OnClick", function(self)
    if LinkOrPreview(self.item.itemID) then return end
    MV.Select(self.item.slot)
  end)
  return r
end

local function NewCoin(parent)
  local c = CreateFrame("Button", nil, parent)
  c:SetSize(16, 16)
  c.tex = c:CreateTexture(nil, "OVERLAY"); c.tex:SetAllPoints(); c.tex:SetTexture(Tex.coin)
  c:SetScript("OnEnter", function(self)
    self.tex:SetTexture(Tex.coinHot)
    MV.hotLane = self.lane
    MV.ApplyPathHover()
    MV.GroupTooltip(self, self.group, MV.ctx, MV.model, self.lane)
  end)
  c:SetScript("OnLeave", function(self)
    self.tex:SetTexture(Tex.coin)
    MV.hotLane = nil
    MV.ApplyPathHover()
    W.TipHide()
  end)
  return c
end

local function Block(i)
  local b = blocks[i]
  if b then return b end
  b = CreateFrame("Frame", nil, content)
  b.segs, b.coins, b.rows = {}, {}, {}
  b.bridge = W.Fill(b, "brassDark", "ARTWORK", 2); b.bridge:SetHeight(3)
  b.bridgeShadow = W.Fill(b, "ruleDark", "ARTWORK", 1); b.bridgeShadow:SetHeight(5)
  b.bridgeShadow:SetPoint("TOPLEFT", b.bridge, "TOPLEFT", 0, 1); b.bridgeShadow:SetPoint("BOTTOMRIGHT", b.bridge, "BOTTOMRIGHT", 0, -1)
  b.bar = CreateFrame("Frame", nil, b)
  b.bar:SetHeight(4)
  b.bar:SetPoint("TOPLEFT", 4, -12)
  b.bar.fill = W.Fill(b.bar, "brass", "ARTWORK"); b.bar.fill:SetAllPoints()
  b.bar.edges = {}
  for k = 1, 4 do b.bar.edges[k] = W.Fill(b.bar, "brass", "ARTWORK", 1) end
  b.bar.edges[1]:SetPoint("TOPLEFT"); b.bar.edges[1]:SetPoint("TOPRIGHT"); b.bar.edges[1]:SetHeight(1)
  b.bar.edges[2]:SetPoint("BOTTOMLEFT"); b.bar.edges[2]:SetPoint("BOTTOMRIGHT"); b.bar.edges[2]:SetHeight(1)
  b.bar.edges[3]:SetPoint("TOPLEFT"); b.bar.edges[3]:SetPoint("BOTTOMLEFT"); b.bar.edges[3]:SetWidth(1)
  b.bar.edges[4]:SetPoint("TOPRIGHT"); b.bar.edges[4]:SetPoint("BOTTOMRIGHT"); b.bar.edges[4]:SetWidth(1)
  b.head = CreateFrame("Button", nil, b)
  b.head:SetHeight(18)
  b.title = W.Text(b.head, "strong", "bone"); b.title:SetPoint("LEFT")
  b.prog = W.Text(b.head, "body", "secondary"); b.prog:SetPoint("LEFT", b.title, "RIGHT", 8, 0)
  b.head:SetScript("OnEnter", function(self)
    local blk = self:GetParent()
    MV.GroupTooltip(self, blk.group, MV.ctx, MV.model, blk.group.lanes[1])
  end)
  b.head:SetScript("OnLeave", W.TipHide)
  blocks[i] = b
  return b
end

local function Seg(b, i)
  local s = b.segs[i]
  if s then return s end
  s = {}
  s.shadow = W.Fill(b, "ruleDark", "BACKGROUND", 2); s.shadow:SetWidth(4)
  s.line = W.Fill(b, "trail", "BACKGROUND", 3); s.line:SetWidth(2)
  b.segs[i] = s
  return s
end

function MV.ApplyPathHover()
  for _, b in ipairs(blocks) do
    if b:IsShown() and b.group then
      local involved = {}
      for _, li in ipairs(b.group.lanes) do involved[li] = true end
      for i, s in ipairs(b.segs) do
        if s.line:IsShown() then
          local col = (MV.hotLane == i) and C.trailHot or involved[i] and C.trailOn or C.trail
          W.SetColor(s.line, col)
        end
      end
      for _, r in ipairs(b.rows) do
        if r:IsShown() and r.item then
          local on = MV.hoverSlot == r.item.slot
          r.hl:SetShown(on); r.hlTop:SetShown(on)
        end
      end
    end
  end
  for i, c in ipairs(laneCells) do
    if c:IsShown() then W.SetColor(c.top, MV.hotLane == i and C.trailHot or C.trail) end
  end
end

local function RenderBlock(b, g, model, ctx, width, indent)
  b.group = g
  local nl = #model.lanes
  local involved = {}
  for _, li in ipairs(g.lanes) do involved[li] = true end
  local h = BLOCK_HEAD + #g.items * S.itemRow + BLOCK_TAIL
  b:SetSize(width, h)

  for i = 1, math.max(nl, #b.segs) do
    local s = Seg(b, i)
    if i <= nl then
      local x = LaneX(i)
      s.shadow:ClearAllPoints(); s.shadow:SetPoint("TOP", b, "TOPLEFT", x, 0); s.shadow:SetPoint("BOTTOM", b, "BOTTOMLEFT", x, 0)
      s.line:ClearAllPoints(); s.line:SetPoint("TOP", b, "TOPLEFT", x, 0); s.line:SetPoint("BOTTOM", b, "BOTTOMLEFT", x, 0)
      s.shadow:Show(); s.line:Show()
    else
      s.shadow:Hide(); s.line:Hide()
    end
  end

  local barKinds = { now = true, gather = true, learned = true, alt = true }
  local showBar = barKinds[g.kind]
  b.bar:SetShown(showBar and true or false)
  if showBar then
    b.bar:SetWidth(indent - 8)
    local solid = g.kind == "now"
    b.bar.fill:SetShown(solid)
    for _, e in ipairs(b.bar.edges) do e:SetShown(not solid) end
  end

  for _, c in ipairs(b.coins) do c:Hide() end
  if not showBar then
    for k, li in ipairs(g.lanes) do
      local c = b.coins[k] or NewCoin(b)
      b.coins[k] = c
      c.group, c.lane = g, li
      c:ClearAllPoints()
      c:SetPoint("CENTER", b, "TOPLEFT", LaneX(li), -14)
      c:SetFrameLevel(b:GetFrameLevel() + 3)
      c:Show()
    end
  end
  if not showBar and #g.lanes > 1 then
    local x1, x2 = LaneX(g.lanes[1]), LaneX(g.lanes[#g.lanes])
    b.bridge:ClearAllPoints()
    b.bridge:SetPoint("TOPLEFT", b, "TOPLEFT", x1, -13)
    b.bridge:SetWidth(x2 - x1)
    b.bridge:Show(); b.bridgeShadow:Show()
  else
    b.bridge:Hide(); b.bridgeShadow:Hide()
  end

  local title, prog = GroupText(g, ctx)
  b.head:ClearAllPoints()
  b.head:SetPoint("TOPLEFT", indent, -6)
  b.head:SetPoint("RIGHT", b, "RIGHT")
  b.title:SetText(title)
  W.TextColor(b.title, (g.kind == "now" or g.kind == "gather") and "brassLight" or "bone")
  b.prog:SetText(prog or "")
  b.prog:SetPoint("RIGHT", b.head, "RIGHT")

  for _, r in ipairs(b.rows) do r:Hide() end
  local y = BLOCK_HEAD
  for k, it in ipairs(g.items) do
    local r = b.rows[k] or NewItemRow(b)
    b.rows[k] = r
    r.item = it
    r.top = y
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", b, "TOPLEFT", indent - 4, -y)
    r:SetPoint("RIGHT", b, "RIGHT", 0, 0)
    y = y + S.itemRow
    local name, _, quality, _, _, _, icon = ItemInfo(it.itemID)
    local q = T.Quality(quality or 1)
    r.icon:Set(icon, q)
    r.name:SetText(T.Wrap(q, name or ItemName(it)) .. " " .. T.Wrap("muted", SlotLabel(it.slot)))
    r.pips:Set(it.checks)
    r.gain:SetText(fmtGain(it.gain))
    W.TextColor(r.gain, g.kind == "now" and "bone" or "secondary")
    r:Show()
  end
  return h
end

local function UpdateScrollChrome()
  local viewH = scroll:GetHeight() or 0
  local total = content:GetHeight() or 0
  local off = scroll:GetVerticalScroll() or 0
  local over = total > viewH + 1
  local atEnd = off >= total - viewH - 1
  fade:SetShown(over and not atEnd)
  moreFS:SetShown(over and not atEnd)
  if MV.scrollBar then MV.scrollBar:Update() end
  if over then
    local below = 0
    for _, b in ipairs(blocks) do
      if b:IsShown() then
        for _, r in ipairs(b.rows) do
          if r:IsShown() then
            local top = (b.y or 0) + (r.top or BLOCK_HEAD)
            if top + S.itemRow / 2 > off + viewH then below = below + 1 end
          end
        end
      end
    end
    moreFS:SetText(below > 0 and string.format(Lx("PATH_MORE_FMT", "%d more below"), below) or "")
  end
end

MV.scrollBar = W.ScrollBar(scroll, UpdateScrollChrome)
MV.scrollBar.wheelStep = S.itemRow * 2
scroll:SetScript("OnMouseWheel", function(self, delta) MV.scrollBar:Scroll(delta * S.itemRow * 2) end)

local function EmptyState(kind, ctx)
  scroll:Hide()
  emptyBox:Show()
  if kind == "building" then
    emptyBox.title:SetText(Lx("PATH_BUILDING_TITLE", "Checking every slot..."))
    emptyBox.text:SetText(Lx("PATH_BUILDING_TEXT", "Comparing your gear with every recipe. This takes a moment the first time."))
    emptyBox.note:SetText("")
  elseif kind == "noindex" then
    emptyBox.title:SetText(Lx("PATH_NOINDEX_TITLE", "No recipes indexed yet"))
    emptyBox.text:SetText(Lx("EMPTY_HINT", "Open a profession window to index craftables, then click Refresh."))
    emptyBox.note:SetText("")
  else
    local gf = MakersPath.GearFinder
    local n = gf and gf.GetIndexedCount and gf:GetIndexedCount() or 0
    emptyBox.title:SetText(Lx("PATH_DONE_TITLE", "Nothing craftable beats your gear"))
    emptyBox.text:SetText(string.format(Lx("PATH_DONE_TEXT_FMT",
      "Every slot was checked against %d craftable items from every profession, including ones %s hasn't learned. The Path picks up again when your gear or your crafters change."), n, ctx.name))
    local parts = {}
    for k, rec in pairs(MakersPathDB and MakersPathDB.chars or {}) do
      if type(rec) == "table" and rec.profs then
        local best, bestLine
        for line, sp in pairs(Const.SKILLLINE_TO_SPELL or {}) do
          local r = tonumber(rec.profs[sp])
          if r and (line == 164 or line == 165 or line == 197 or line == 202 or line == 755) and (not best or r > best) then best, bestLine = r, line end
        end
        if best then
          local cc = T.ClassColor(rec.class)
          parts[#parts + 1] = T.Wrap(cc, rec.name or k:match("^([^%-]+)") or k) .. " " .. ProfName(bestLine) .. " " .. best
        end
      end
    end
    emptyBox.note:SetText(#parts > 0 and (Lx("PATH_ACCOUNT_CRAFTERS", "Account crafters:") .. " " .. table.concat(parts, " · ")) or "")
  end
end

local function RenderLanes(model, ctx)
  local n = #model.lanes
  local w = laneBar:GetWidth() or 300
  local gap = 6
  local cw = (w - gap * (n - 1)) / math.max(1, n)
  for i, c in ipairs(laneCells) do if i > n then c:Hide() end end
  for i, lane in ipairs(model.lanes) do
    local c = LaneCell(i)
    c.index = i
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", (i - 1) * (cw + gap), 0)
    c:SetWidth(cw)
    if lane.kind == "level" then
      c.icon:SetTexture(Tex.levelGlyph)
      c.icon:SetTexCoord(0, 1, 0, 1)
      c.icon:SetVertexColor(C.brass[1], C.brass[2], C.brass[3])
      c.label:SetText(Lx("LANE_LEVEL", "Level"))
      c.value:SetText(tostring(ctx.level)); W.TextColor(c.value, "bone")
    else
      c.icon:SetTexture(ProfIcon(lane.line))
      c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      c.icon:SetVertexColor(1, 1, 1)
      c.label:SetText(ProfName(lane.line))
      if lane.rank then
        c.value:SetText(lane.max and string.format("%d / %d", lane.rank, lane.max) or tostring(lane.rank))
        W.TextColor(c.value, "bone")
      else
        c.value:SetText(Lx("PATH_NOT_LEARNED", "not learned")); W.TextColor(c.value, "amber")
      end
    end
    c:Show()
  end
end

local function RenderPath(model, ctx, building)
  local n = model.counts.total
  if n == 0 then
    summaryFS:SetText(building and Lx("CALCULATING", "Calculating...") or Lx("PATH_SUMMARY_NONE", "no upgrades right now"))
  else
    local s = string.format(Lx("PATH_SUMMARY_FMT", "%d |4upgrade:upgrades;"), n)
    if model.counts.now > 0 then
      s = s .. " · " .. string.format(Lx("PATH_SUMMARY_NOW_FMT", "%d ready to craft"), model.counts.now)
    elseif model.counts.gather > 0 then
      s = s .. " · " .. string.format(Lx("PATH_SUMMARY_GATHER_FMT", "%d |4needs:need; materials"), model.counts.gather)
    end
    summaryFS:SetText(s)
  end
  RenderLanes(model, ctx)

  local showMats = ctx.current and #model.mats > 0
  matsStrip:SetShown(showMats)
  if showMats then
    matsStrip.label:SetText(string.format(Lx("PATH_MATS_FMT", "For %d learned |4craft:crafts;"), model.matsCrafts))
    local parts = {}
    for _, m in ipairs(model.mats) do
      local short = (m.have or 0) < m.need
      parts[#parts + 1] = (ItemInfo(m.id) or ("item:" .. m.id)) .. " " .. T.Wrap(short and "amber" or "bone", tostring(m.have or 0)) .. T.Wrap("muted", "/" .. m.need)
    end
    matsStrip.list:SetText(table.concat(parts, "   "))
    local lh = math.min(2, math.max(1, math.ceil((matsStrip.list:GetStringHeight() or 14) / 15)))
    matsStrip:SetHeight(14 + lh * 15)
    scroll:SetPoint("BOTTOM", matsStrip, "TOP", 0, 18)
  else
    scroll:SetPoint("BOTTOM", pathView, "BOTTOM", 0, 16)
  end

  for _, b in ipairs(blocks) do b:Hide() end
  if n == 0 then
    local gf = MakersPath.GearFinder
    local indexed = gf and gf.GetIndexedCount and gf:GetIndexedCount() or 0
    EmptyState(building and "building" or (indexed == 0 and "noindex") or "done", ctx)
    return
  end
  emptyBox:Hide()
  scroll:Show()

  local width = scroll:GetWidth() or 300
  local indent = math.max(S.pathIndent, LaneX(#model.lanes) + 18)
  width = width - 10   -- gutter for the scroll bar
  content:SetWidth(width)
  local y = 0
  for i, g in ipairs(model.groups) do
    local b = Block(i)
    local h = RenderBlock(b, g, model, ctx, width, indent)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    b.y = y
    for k, r in ipairs(b.rows) do r.index = k end
    b:Show()
    y = y + h
  end
  content:SetHeight(math.max(1, y))
  local maxOff = math.max(0, y - (scroll:GetHeight() or 0))
  if (scroll:GetVerticalScroll() or 0) > maxOff then scroll:SetVerticalScroll(maxOff) end
  MV.ApplyPathHover()
  UpdateScrollChrome()
end


-- =================== Inspection ===================
local insp = CreateFrame("Frame", nil, area)
insp:SetAllPoints()
insp:Hide()
if insp.SetClipsChildren then insp:SetClipsChildren(true) end

insp.back = W.LinkButton(insp, Lx("PATH_TITLE", "The Path"), Tex.back, function() MV.Select(nil) end)
insp.back:SetPoint("TOPLEFT", 0, -2)
insp.crumb = W.Text(insp, "body", "secondary")
insp.crumb:SetPoint("LEFT", insp.back, "RIGHT", 6, 0)
insp.crumb:SetPoint("RIGHT")

-- equipped -> crafted
insp.cmp = W.Inset(insp)
insp.cmp:SetPoint("TOPLEFT", 0, -26)
insp.cmp:SetPoint("RIGHT")
insp.cmp:SetHeight(46)
local function CmpSide(parent)
  local f = CreateFrame("Button", nil, parent)
  f:SetHeight(34)
  f.icon = W.ItemIcon(f, 32); f.icon:SetPoint("LEFT")
  f.cap = W.Text(f, "small", "muted"); f.cap:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -1); f.cap:SetPoint("RIGHT")
  f.name = W.Text(f, "strong", "bone"); f.name:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 8, 1); f.name:SetPoint("RIGHT")
  f:SetScript("OnEnter", function(self)
    if self.link then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.link); GameTooltip:Show() end
  end)
  f:SetScript("OnLeave", W.TipHide)
  f:SetScript("OnClick", function(self)
    if self.link and IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(self.link)
    elseif self.link and IsModifiedClick("DRESSUP") then DressUpItemLink(self.link) end
  end)
  return f
end
insp.eq = CmpSide(insp.cmp)
insp.cr = CmpSide(insp.cmp)
insp.arrow = W.Text(insp.cmp, "strong", "muted"); insp.arrow:SetText("->")
insp.score = W.Text(insp.cmp, "numBig", "bone"); insp.score:SetPoint("TOPRIGHT", -8, -6); insp.score:SetJustifyH("RIGHT")
insp.scoreCap = W.Text(insp.cmp, "small", "muted"); insp.scoreCap:SetPoint("TOPRIGHT", insp.score, "BOTTOMRIGHT", 0, -1)
insp.scoreCap:SetText(Lx("INSP_SCORE", "upgrade score"))

insp.stats = W.Text(insp, "body", "secondary")
insp.stats:SetPoint("TOPLEFT", insp.cmp, "BOTTOMLEFT", 2, -7)
insp.stats:SetPoint("RIGHT")
insp.stats:SetWordWrap(true)
insp.stats:SetSpacing(3)
insp.statMeasure = W.Text(insp, "body", "secondary")
insp.statMeasure:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 100, -100)
insp.statMeasure:Hide()

local function ReqList(parent, title)
  local f = CreateFrame("Frame", nil, parent)
  f.head = W.Heading(f, title)
  f.head:SetPoint("TOPLEFT"); f.head:SetPoint("TOPRIGHT")
  f.lines = {}
  function f:Set(list)
    for _, l in ipairs(self.lines) do l:Hide() end
    for i, item in ipairs(list) do
      local l = self.lines[i]
      if not l then
        l = CreateFrame("Frame", nil, self)
        l:SetHeight(17)
        l.pip = W.Pip(l); l.pip:SetPoint("TOPLEFT", 0, -1)
        l.text = W.Text(l, "body", "secondary"); l.text:SetPoint("TOPLEFT", l.pip, "TOPRIGHT", 7, 1); l.text:SetPoint("RIGHT")
        self.lines[i] = l
      end
      l:ClearAllPoints()
      l:SetPoint("TOPLEFT", 0, -(20 + (i - 1) * 17)); l:SetPoint("RIGHT")
      l.pip:SetState(item.kind, item.state)
      l.text:SetText(T.Wrap(item.state == "N" and "amber" or "secondary", item.text) .. (item.note and ("  " .. T.Wrap("muted", item.note)) or ""))
      l:Show()
    end
    self:SetHeight(20 + #list * 17)
  end
  return f
end

insp.craft = ReqList(insp, Lx("INSP_TO_CRAFT", "To craft"))
insp.equip = ReqList(insp, Lx("INSP_TO_EQUIP", "To equip"))

local function RowList(parent, title, note)
  local f = CreateFrame("Frame", nil, parent)
  f.head = W.Heading(f, title)
  f.head:SetPoint("TOPLEFT"); f.head:SetPoint("TOPRIGHT")
  if note then f.head:SetText(title, note) end
  f.rows = {}
  return f
end

insp.mats = RowList(insp, Lx("INSP_MATS", "Materials"), Lx("INSP_MATS_NOTE", "in your bags"))
insp.mats.pip = W.Pip(insp.mats.head)
insp.mats.pip:SetPoint("LEFT")
insp.mats.head.label:ClearAllPoints()
insp.mats.head.label:SetPoint("LEFT", insp.mats.pip, "RIGHT", 6, 0)
insp.crafters = RowList(insp, Lx("INSP_CRAFTERS", "Crafters on this account"))
insp.crafters.empty = W.Text(insp.crafters, "body", "muted")
insp.crafters.empty:SetPoint("TOPLEFT", 0, -24)
insp.crafters.empty:SetWordWrap(true)
insp.crafters.empty:SetJustifyV("TOP")
insp.note = W.Text(insp, "small", "muted")
insp.note:SetText(Lx("INSP_RECIPES_NOTE", "Known recipes are read from each character's profession window the last time it was opened."))
insp.alts = RowList(insp, "")

local function MatRow(parent, i)
  local r = parent.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, parent)
  r:SetHeight(22)
  r.icon = W.ItemIcon(r, 18); r.icon:SetPoint("LEFT")
  r.count = W.Text(r, "body", "bone"); r.count:SetPoint("RIGHT"); r.count:SetJustifyH("RIGHT")
  r.name = W.Text(r, "body", "bone"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0); r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
  r:SetScript("OnEnter", function(self)
    if self.itemID then
      local _, link = ItemInfo(self.itemID)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetText("item:" .. self.itemID) end
      GameTooltip:Show()
    end
  end)
  r:SetScript("OnLeave", W.TipHide)
  r:SetScript("OnClick", function(self) if self.itemID then LinkOrPreview(self.itemID) end end)
  parent.rows[i] = r
  return r
end

local function CrafterRow(parent, i)
  local r = parent.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, parent)
  r:SetHeight(22)
  r.name = W.Text(r, "strong", "bone"); r.name:SetPoint("LEFT"); r.name:SetWidth(74)
  r.state = W.Text(r, "body", "secondary"); r.state:SetPoint("LEFT", r.name, "RIGHT", 6, 0); r.state:SetPoint("RIGHT")
  parent.rows[i] = r
  return r
end

local function AltRow(parent, i)
  local r = parent.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, parent)
  r:SetHeight(24)
  r.line = W.Line(r, "hover", "BORDER"); r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
  r.icon = W.ItemIcon(r, 20); r.icon:SetPoint("LEFT")
  r.gain = W.Text(r, "num", "bone"); r.gain:SetPoint("RIGHT"); r.gain:SetWidth(40); r.gain:SetJustifyH("RIGHT")
  r.pips = W.PipRow(r); r.pips:SetPoint("RIGHT", r.gain, "LEFT", -6, 0)
  r.state = W.Text(r, "body", "secondary"); r.state:SetPoint("RIGHT", r.pips, "LEFT", -8, 0); r.state:SetJustifyH("RIGHT")
  r.name = W.Text(r, "body", "bone"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0); r.name:SetPoint("RIGHT", r.state, "LEFT", -8, 0)
  r:RegisterForClicks("LeftButtonUp")
  r:SetScript("OnEnter", function(self) if self.item then MV.ItemTooltip(self, self.item, MV.ctx, true) end end)
  r:SetScript("OnLeave", W.TipHide)
  r:SetScript("OnClick", function(self) if self.item then LinkOrPreview(self.item.itemID) end end)
  parent.rows[i] = r
  return r
end

local STAT_LABELS = {
  STRENGTH = "ITEM_MOD_STRENGTH_SHORT", AGILITY = "ITEM_MOD_AGILITY_SHORT",
  STAMINA = "ITEM_MOD_STAMINA_SHORT", INTELLECT = "ITEM_MOD_INTELLECT_SHORT",
  SPIRIT = "ITEM_MOD_SPIRIT_SHORT", ARMOR = "RESISTANCE0_NAME",
  ATTACK_POWER = "ITEM_MOD_ATTACK_POWER_SHORT", RANGED_ATTACK_POWER = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
  FERAL_ATTACK_POWER = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT", DAMAGE_PER_SECOND = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT",
  CRIT = "ITEM_MOD_CRIT_RATING_SHORT", CRIT_SPELL = "ITEM_MOD_CRIT_SPELL_RATING_SHORT",
  HIT = "ITEM_MOD_HIT_RATING_SHORT", HIT_SPELL = "ITEM_MOD_HIT_SPELL_RATING_SHORT",
  HASTE = "ITEM_MOD_HASTE_RATING_SHORT", HASTE_SPELL = "ITEM_MOD_HASTE_SPELL_RATING_SHORT",
  EXPERTISE = "ITEM_MOD_EXPERTISE_RATING_SHORT", ARMOR_PENETRATION = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
  SPELL_PENETRATION = "ITEM_MOD_SPELL_PENETRATION_SHORT", RESILIENCE = "ITEM_MOD_RESILIENCE_RATING_SHORT",
  DODGE = "ITEM_MOD_DODGE_RATING_SHORT", PARRY = "ITEM_MOD_PARRY_RATING_SHORT",
  BLOCK = "ITEM_MOD_BLOCK_RATING_SHORT", BLOCK_VALUE = "ITEM_MOD_BLOCK_VALUE_SHORT",
  DEFENSE_SKILL = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", MANA_REGENERATION = "ITEM_MOD_MANA_REGENERATION_SHORT",
  HEALTH = "ITEM_MOD_HEALTH_SHORT", MANA = "ITEM_MOD_MANA_SHORT",
  HEALTH_REGENERATION = "ITEM_MOD_HEALTH_REGENERATION_SHORT",
  SPELL_DAMAGE_DONE = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", SPELL_HEALING_DONE = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
  FIRE_RESISTANCE = "RESISTANCE2_NAME", NATURE_RESISTANCE = "RESISTANCE3_NAME",
  FROST_RESISTANCE = "RESISTANCE4_NAME", SHADOW_RESISTANCE = "RESISTANCE5_NAME",
  ARCANE_RESISTANCE = "RESISTANCE6_NAME",
}
local SCHOOL_INDEX = {
  SPELL_DAMAGE_DONE_HOLY = 1, SPELL_DAMAGE_DONE_FIRE = 2, SPELL_DAMAGE_DONE_NATURE = 3,
  SPELL_DAMAGE_DONE_FROST = 4, SPELL_DAMAGE_DONE_SHADOW = 5, SPELL_DAMAGE_DONE_ARCANE = 6,
}
local ERA_PCT = {
  HIT = { 10, "STAT_HIT", "Hit" }, CRIT = { 14, "STAT_CRIT", "Crit" },
  HIT_SPELL = { 10, "STAT_SPELL_HIT", "Spell hit" }, CRIT_SPELL = { 14, "STAT_SPELL_CRIT", "Spell crit" },
  DODGE = { 12, "STAT_DODGE", "Dodge" }, PARRY = { 20, "STAT_PARRY", "Parry" },
  BLOCK = { 5, "STAT_BLOCK", "Block" }, DEFENSE_SKILL = { 1.5, "STAT_DEFENSE", "Defense", true },
}

local function FmtStat(v, decimals)
  if decimals then return string.format("%.1f", v) end
  local r = math.floor(v + 0.5)
  if math.abs(v - r) < 0.05 then return tostring(r) end
  return string.format("%.1f", v)
end

local function StatLabel(k)
  local school = SCHOOL_INDEX[k]
  if school then
    local name = _G["SPELL_SCHOOL" .. school .. "_CAP"]
    local sp = _G.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT
    return name and sp and (name .. " " .. sp) or nil
  end
  local g = STAT_LABELS[k]
  local label = g and _G[g]
  if type(label) == "string" and label ~= "" then return label end
end

local function StatDiffs(eqLink, crLink)
  local GF = MakersPath.GearFinder
  local read = GF and GF.StatsForLink
  local a = (eqLink and read and read(eqLink)) or {}
  local b = (crLink and read and read(crLink)) or {}
  local era = MakersPath.client and MakersPath.client.isEra
  local RT = MakersPath.WeightsRT
  local keys, out = {}, {}
  for k in pairs(a) do keys[k] = true end
  for k in pairs(b) do keys[k] = true end
  for k in pairs(keys) do
    local va, vb = tonumber(a[k]) or 0, tonumber(b[k]) or 0
    local pct = era and ERA_PCT[k]
    local label, unit, dec = nil, "", (k == "DAMAGE_PER_SECOND")
    if pct then
      va, vb = va / pct[1], vb / pct[1]
      label = Lx(pct[2], pct[3])
      unit = pct[4] and "" or "%"
    else
      label = StatLabel(k)
    end
    local sa, sb = FmtStat(va, dec), FmtStat(vb, dec)
    if sa ~= sb and label then
      local w = RT and RT.GetWeight and tonumber(RT.GetWeight(k)) or 0
      local rawDelta = (tonumber(b[k]) or 0) - (tonumber(a[k]) or 0)
      out[#out + 1] = {
        label = label, a = sa .. unit, b = sb .. unit, d = vb - va,
        sd = FmtStat(math.abs(vb - va), dec) .. unit,
        rank = math.abs(rawDelta) * math.max(w, 0.001),
      }
    end
  end
  table.sort(out, function(x, y) return x.rank > y.rank end)
  local parts = {}
  for i = 1, math.min(6, #out) do
    local s = out[i]
    local delta = T.Wrap(s.d > 0 and "gain" or "loss", "(" .. (s.d > 0 and "+" or "-") .. s.sd .. ")")
    parts[#parts + 1] = string.format("%s %s %s", s.label, T.Wrap("bone", s.a .. " -> " .. s.b), delta)
  end
  return parts
end

local function LayoutStats(parts)
  local fs, m = insp.stats, insp.statMeasure
  local width = fs:GetWidth() or 0
  if width <= 0 then width = 400 end
  local gap = "     "
  local lines, line = {}, nil
  for _, p in ipairs(parts) do
    if not line then
      line = p
    else
      m:SetText(line .. gap .. p)
      if (m:GetStringWidth() or 0) > width then
        lines[#lines + 1] = line
        line = p
      else
        line = line .. gap .. p
      end
    end
  end
  if line then lines[#lines + 1] = line end
  fs:SetText(table.concat(lines, "\n"))
end

local function RenderInspect(slot)
  local it = itemBySlot[slot]
  if not it then return end
  local ctx = MV.ctx
  local row = it.row
  local title = GroupText(MV.model and (function()
    for _, g in ipairs(MV.model.groups) do if g.key == it.group then return g end end
  end)() or { kind = "now", items = {} }, ctx)
  insp.crumb:SetText(T.Wrap("faint", "/  ") .. title)

  -- compare
  local info = SlotInfo(slot)
  local eqID = ctx.current and info and GetInventoryItemID("player", info.id) or nil
  local eName, eLink, eQ, eIlvl, _, _, eIcon = ItemInfo(eqID)
  local cName, cLink, cQ, cIlvl, _, _, cIcon = ItemInfo(it.itemID)
  local w = (insp.cmp:GetWidth() or 360) - 90
  insp.eq:ClearAllPoints(); insp.eq:SetPoint("LEFT", 8, 0); insp.eq:SetWidth(w / 2 - 14)
  insp.arrow:ClearAllPoints(); insp.arrow:SetPoint("LEFT", insp.eq, "RIGHT", 4, 0)
  insp.cr:ClearAllPoints(); insp.cr:SetPoint("LEFT", insp.eq, "RIGHT", 24, 0); insp.cr:SetWidth(w / 2 - 14)
  if eqID then
    local q = T.Quality(eQ or 1)
    insp.eq.icon:Set(eIcon, q)
    insp.eq.cap:SetText(string.format(Lx("INSP_EQUIPPED_FMT", "Equipped · item level %s"), tostring(eIlvl or "?")))
    insp.eq.name:SetText(eName or ""); W.TextColor(insp.eq.name, q)
    insp.eq.link = eLink
  else
    insp.eq.icon:Set(info and info.tex or nil, C.buttonEdge)
    insp.eq.cap:SetText(ctx.current and Lx("INSP_EMPTY", "Nothing equipped") or Lx("INSP_EQUIP_UNKNOWN", "Equipped item not recorded"))
    insp.eq.name:SetText(SlotLabel(slot)); W.TextColor(insp.eq.name, "muted")
    insp.eq.link = nil
  end
  local cq = T.Quality(cQ or 1)
  insp.cr.icon:Set(cIcon, cq)
  insp.cr.cap:SetText(string.format(Lx("INSP_CRAFTED_FMT", "Crafted · item level %s"), tostring(cIlvl or "?")))
  insp.cr.name:SetText(cName or ItemName(it)); W.TextColor(insp.cr.name, cq)
  insp.cr.link = cLink
  insp.score:SetText(fmtGain(it.gain))

  LayoutStats(StatDiffs(eLink, cLink))

  local c = it.checks
  local craft = {}
  if it.line then
    if it.learnProf then
      craft[#craft + 1] = { kind = "skill", state = "N", text = ProfName(it.line) .. " " .. it.need, note = string.format(Lx("INSP_NOT_LEARNED_ON_FMT", "not learned on %s"), ctx.name) }
    else
      craft[#craft + 1] = { kind = "skill", state = c.skill, text = ProfName(it.line) .. " " .. it.need, note = string.format(Lx("INSP_YOU_HAVE_FMT", "you have %d"), it.rank or 0) }
    end
  end
  local src = SourceText(R.Source(it.itemID))
  if c.recipe == "Y" then
    craft[#craft + 1] = { kind = "recipe", state = "Y", text = Lx("TIP_RECIPE_KNOWN", "Recipe known") }
  elseif c.recipe == "N" then
    craft[#craft + 1] = { kind = "recipe", state = "N", text = Lx("TIP_RECIPE_UNKNOWN", "Recipe not known"), note = src or Lx("INSP_SRC_UNKNOWN", "source not in the recipe data") }
  else
    craft[#craft + 1] = { kind = "recipe", state = "U", text = Lx("INSP_RECIPE_UNREC", "Recipes not recorded yet"), note = string.format(Lx("INSP_OPEN_ONCE_FMT", "open %s once"), ProfName(it.line)) }
  end
  insp.craft:Set(craft)
  insp.equip:Set({
    { kind = "equip", state = c.equip, text = string.format(Lx("INSP_LEVEL_FMT", "Level %d"), it.reqLevel), note = string.format(Lx("INSP_YOU_ARE_FMT", "you are %d"), ctx.level) },
  })

  insp.mats.pip:SetState("mats", c.mats)
  for _, r in ipairs(insp.mats.rows) do r:Hide() end
  if #it.reagents == 0 then
    local r = MatRow(insp.mats, 1)
    r.itemID = nil
    r.icon:Set(Tex.question, C.buttonEdge)
    r.name:SetText(T.Wrap("muted", Lx("TIP_MATS_NODATA", "Materials aren't in the recipe data")))
    r.count:SetText("")
    r:SetPoint("TOPLEFT", 0, -20); r:SetPoint("RIGHT")
    r:Show()
  else
    for i, m in ipairs(it.reagents) do
      if i > 5 then break end
      local r = MatRow(insp.mats, i)
      r.itemID = m.id
      local n, _, q, _, _, _, icon = ItemInfo(m.id)
      r.icon:Set(icon, T.Quality(q or 1))
      r.name:SetText(n or ("item:" .. m.id))
      local short = m.have and m.have < m.num
      r.count:SetText(T.Wrap(m.have == nil and "muted" or short and "amber" or "bone", m.have == nil and "?" or tostring(m.have)) .. T.Wrap("muted", " / " .. m.num))
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -(20 + (i - 1) * 22)); r:SetPoint("RIGHT")
      r:Show()
    end
  end
  insp.mats:SetHeight(20 + math.max(1, math.min(5, #it.reagents)) * 22)

  for _, r in ipairs(insp.crafters.rows) do r:Hide() end
  local list = {}
  if it.line then
    local sp = ProfSpell(it.line)
    for k, crec in pairs(MakersPathDB and MakersPathDB.chars or {}) do
      local rank = type(crec) == "table" and crec.profs and sp and tonumber(crec.profs[sp])
      if rank and rank > 0 then list[#list + 1] = { key = k, rec = crec, rank = rank } end
    end
  end
  table.sort(list, function(a, b) return a.rank > b.rank end)
  insp.crafters.empty:SetShown(#list == 0)
  if #list == 0 then
    insp.crafters.empty:SetText(string.format(Lx("TIP_NOBODY_HAS_FMT", "No other character on this account has %s"), ProfName(it.line)))
  end
  for i, e in ipairs(list) do
    if i > 4 then break end
    local r = CrafterRow(insp.crafters, i)
    r.name:SetText(e.rec.name or e.key:match("^([^%-]+)") or e.key)
    W.TextColor(r.name, T.ClassColor(e.rec.class))
    local state, col
    if e.rank < it.need then
      state, col = Lx("INSP_SKILL_LOW", "skill too low"), "muted"
    else
      local k = R.IsKnown(it.itemID, it.line, e.key)
      if k == true then state, col = Lx("INSP_CAN_CRAFT", "can craft"), "brassLight"
      elseif k == false then state, col = Lx("INSP_SKILL_NO_RECIPE", "skill met, recipe not known"), "amber"
      else state, col = Lx("INSP_SKILL_UNREC", "skill met, recipes not recorded"), "secondary" end
    end
    r.state:SetText(ProfName(it.line) .. " " .. e.rank .. " · " .. T.Wrap(col, state))
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -(20 + (i - 1) * 22)); r:SetPoint("RIGHT")
    r:Show()
  end
  insp.crafters:SetHeight(20 + math.max(1, math.min(4, #list)) * 22)

  for _, r in ipairs(insp.alts.rows) do r:Hide() end
  local alts = row.alts or {}
  insp.alts.head:SetText(string.format(Lx("INSP_ALTS_FMT", "Other options for %s"), SlotLabel(slot)))
  local shown = 0
  for _, a in ipairs(alts) do
    if a and a.itemID and shown < 3 then
      shown = shown + 1
      local aIt = Model.Assess({ slot = slot, best = a, bestScore = a.score or 0, eqScore = row.eqScore or 0 }, ctx)
      local r = AltRow(insp.alts, shown)
      r.item = aIt
      local n, _, q, _, _, _, icon = ItemInfo(a.itemID)
      local qc = T.Quality(q or 1)
      r.icon:Set(icon, qc)
      r.name:SetText(T.Wrap(qc, n or ("item:" .. a.itemID)))
      local ac = aIt.checks
      local stxt, scol
      if ac.skill == "Y" and ac.recipe == "Y" and ac.mats == "Y" and ac.equip == "Y" then stxt, scol = Lx("INSP_READY_NOW", "ready now"), "secondary"
      elseif ac.equip == "N" then stxt, scol = string.format(Lx("PATH_LEVEL_FMT", "Level %d"), aIt.reqLevel), "amber"
      elseif ac.skill == "N" then stxt, scol = Lx("INSP_NEEDS_SKILL", "needs skill"), "amber"
      elseif ac.recipe == "N" then stxt, scol = Lx("INSP_RECIPE_NOT_KNOWN", "recipe not known"), "amber"
      elseif ac.mats == "N" then stxt, scol = Lx("PATH_NEED_MATS", "Need materials"), "secondary"
      else stxt, scol = "", "secondary" end
      r.state:SetText(stxt); W.TextColor(r.state, scol)
      r.pips:Set(ac)
      r.gain:SetText(fmtGain(aIt.gain))
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -(20 + (shown - 1) * 24)); r:SetPoint("RIGHT")
      r:Show()
    end
  end
  insp.alts:SetShown(shown > 0)
  insp.alts:SetHeight(20 + shown * 24)

  local W2 = insp:GetWidth() or 380
  local gap = 18
  local colA = math.floor((W2 - gap) * 0.55)
  local colB = W2 - gap - colA
  insp.craft:ClearAllPoints(); insp.craft:SetPoint("TOPLEFT", insp.stats, "BOTTOMLEFT", -2, -8); insp.craft:SetWidth(colA)
  insp.equip:ClearAllPoints(); insp.equip:SetPoint("TOPLEFT", insp.craft, "TOPRIGHT", gap, 0); insp.equip:SetWidth(colB)
  local reqH = math.max(insp.craft:GetHeight(), insp.equip:GetHeight())
  insp.mats:ClearAllPoints(); insp.mats:SetPoint("TOPLEFT", insp.craft, "TOPLEFT", 0, -(reqH + 8)); insp.mats:SetWidth(colB + 20)
  insp.crafters:ClearAllPoints(); insp.crafters:SetPoint("TOPLEFT", insp.mats, "TOPRIGHT", gap, 0); insp.crafters:SetPoint("RIGHT", insp, "RIGHT")
  if insp.crafters.empty:IsShown() then
    insp.crafters.empty:SetWidth(math.max(60, W2 - (colB + 20) - gap))
    insp.crafters:SetHeight(24 + math.ceil(insp.crafters.empty:GetStringHeight() or 14) + 4)
  end
  local mh = math.max(insp.mats:GetHeight(), insp.crafters:GetHeight())
  insp.note:ClearAllPoints(); insp.note:SetPoint("TOPLEFT", insp.mats, "TOPLEFT", 0, -(mh + 2)); insp.note:SetPoint("RIGHT", insp, "RIGHT")
  insp.alts:ClearAllPoints(); insp.alts:SetPoint("TOPLEFT", insp.note, "BOTTOMLEFT", 0, -8); insp.alts:SetPoint("RIGHT", insp, "RIGHT")
end

MV.RenderInspect = RenderInspect

function MV.LayoutPath()
  if not MV.model then return end
  if pathView:IsShown() then RenderPath(MV.model, MV.ctx, MV.building)
  elseif insp:IsShown() and MV.selected and MV.RenderInspect then MV.RenderInspect(MV.selected) end
end

-- =================== Public ===================
function MV.Select(slot)
  if slot and not itemBySlot[slot] then slot = nil end
  MV.selected = slot
  for _, r in pairs(railRows) do ApplyRowHover(r) end
  W.TipHide()
  if slot then
    pathView:Hide()
    insp:Show()
    RenderInspect(slot)
  else
    insp:Hide()
    pathView:Show()
    if MV.model then RenderPath(MV.model, MV.ctx, MV.building) end
  end
end

function MV.Refresh(bySlot, building)
  if not panel:IsShown() then return end
  rowsBySlot = bySlot or {}
  MV.building = building
  local ctx = BuildContext()
  local rows = {}
  for _, slot in ipairs(BOTTOM) do if rowsBySlot[slot] then rows[#rows + 1] = rowsBySlot[slot] end end
  for _, slot in ipairs(LEFT) do if rowsBySlot[slot] then rows[#rows + 1] = rowsBySlot[slot] end end
  for _, slot in ipairs(RIGHT) do if rowsBySlot[slot] then rows[#rows + 1] = rowsBySlot[slot] end end
  local model = Model.Build(rows, ctx)
  MV.model, MV.ctx = model, ctx
  wipe(itemBySlot)
  for _, it in ipairs(model.items) do itemBySlot[it.slot] = it end

  if MV.UpdateHeader then MV.UpdateHeader(ctx) end
  if MV.legend then MV.legend:Layout() end
  LayoutRails()
  for slot, row in pairs(railRows) do RenderRow(row, slot, building) end
  for _, r in pairs(railRows) do ApplyRowHover(r) end

  if MV.selected and not itemBySlot[MV.selected] then MV.selected = nil end
  MV.Select(MV.selected)
end

panel:HookScript("OnHide", function()
  MV.selected, MV.hoverSlot, MV.hotLane = nil, nil, nil
end)

-- =================== Header and Footer ===================
do
  local h = panel.header
  local div = W.HeaderDivider(h, h.title)
  h.charName = W.Text(h, "name", "bone")
  h.charName:SetPoint("LEFT", div, "RIGHT", 10, 0)
  h.charLine = W.Text(h, "body", "secondary")
  h.charLine:SetPoint("LEFT", h.charName, "RIGHT", 8, -1)
  if panel.charsBtn then h.charLine:SetPoint("RIGHT", panel.charsBtn, "LEFT", -10, 0) end
end

MV.KOFI_URL = "https://ko-fi.com/yozoracho"

do
  local h = panel.header
  local k = W.LinkButton(h, Lx("KOFI_BUTTON", "Ko-fi"), Tex.heart, function()
    W.TipHide()
    W.Dialog({
      title = Lx("KOFI_TIP_TITLE", "Support Maker's Path"),
      text = Lx("KOFI_DIALOG_TEXT", "WoW can't open web pages, so copy this link into your browser. Thank you for the support!"),
      copy = MV.KOFI_URL,
      hint = Lx("DIALOG_COPY_HINT", "Press Ctrl+C to copy"),
      copiedHint = Lx("DIALOG_COPIED", "Copied"),
    })
  end)
  if k.icon then k.icon:SetSize(11, 11) end
  k:SetWidth(k.label:GetStringWidth() + 15)
  if panel.charsBtn then k:SetPoint("RIGHT", panel.charsBtn, "LEFT", -12, 0) else k:SetPoint("RIGHT", h.right, "LEFT", -12, 0) end
  local enter, leave = k:GetScript("OnEnter"), k:GetScript("OnLeave")
  k:SetScript("OnEnter", function(self)
    enter(self)
    W.TipBegin(self, "ANCHOR_BOTTOM", 240)
    W.TipLine(Lx("KOFI_TIP_TITLE", "Support Maker's Path"), "tipGold")
    W.TipLine(Lx("KOFI_TIP_TEXT", "Maker's Path is free. If it's helped you, you can buy me a coffee on Ko-fi."), "secondary")
    W.TipFoot(Lx("KOFI_TIP_FOOT", "Click for the link. You can hide this in Options."))
    GameTooltip:Show()
  end)
  k:SetScript("OnLeave", function(self) leave(self); W.TipHide() end)
  h.kofi = k
end

function MakersPath.UI.UpdateKofi()
  local h = panel.header
  local cfg = MakersPathDB and MakersPathDB.config
  local show = not (cfg and cfg.SHOW_KOFI == false)
  h.kofi:SetShown(show)
  h.charLine:ClearAllPoints()
  h.charLine:SetPoint("LEFT", h.charName, "RIGHT", 8, -1)
  local anchor = show and h.kofi or panel.charsBtn
  if anchor then h.charLine:SetPoint("RIGHT", anchor, "LEFT", -10, 0) end
end
panel:HookScript("OnShow", MakersPath.UI.UpdateKofi)

function MV.UpdateHeader(ctx)
  local h = panel.header
  h.charName:SetText(ctx.name or "")
  W.TextColor(h.charName, T.ClassColor(ctx.class))
  local className = ctx.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[ctx.class] or ""
  h.charLine:SetText(string.format(Lx("HEADER_LEVEL_FMT", "Level %d %s"), ctx.level or 0, className))
end

local MARKS = {
  { tex = Tex.markReady, label = Lx("MARK_READY", "ready"),
    tip = Lx("MARK_READY_TIP", "Ready to craft: skill, recipe and materials are all there.") },
  { tex = Tex.markMats, label = Lx("MARK_CAN", "can be made"),
    tip = Lx("MARK_CAN_TIP", "Can be made: the skill is there, but you're short on materials, the recipe hasn't been recorded yet, or another character makes it.") },
  { tex = Tex.markNeed, label = Lx("MARK_TRAIN", "needs training"),
    tip = Lx("MARK_TRAIN_TIP", "Needs training: more profession skill, or a recipe you don't know yet.") },
  { tex = Tex.markLevel, label = Lx("MARK_LEVEL", "needs level"),
    tip = Lx("MARK_LEVEL_TIP", "Needs a higher level before you can wear it.") },
}

function MV.MarksTooltip(owner)
  W.TipBegin(owner, "ANCHOR_TOP", 300)
  W.TipLine(Lx("MARK_TITLE", "Slot marks"), "tipGold")
  for _, m in ipairs(MARKS) do
    W.TipLine(T.TexInline(m.tex, 14) .. "  " .. m.tip, "secondary")
  end
  W.TipFoot(Lx("MARK_FOOT", "Hover any slot for its full checklist."))
  GameTooltip:Show()
end

do
  local f = CreateFrame("Button", nil, panel.footer)
  f:SetHeight(20)
  f:SetPoint("RIGHT", panel.refreshBtn, "LEFT", -12, 0)
  f:SetHitRectInsets(-4, -4, -4, -4)
  f.items = {}
  for i, m in ipairs(MARKS) do
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetTexture(m.tex); t:SetSize(16, 16)
    local fs = W.Text(f, "small", "muted"); fs:SetText(m.label)
    f.items[i] = { tex = t, fs = fs }
  end
  function f:Layout()
    local x = 0
    for _, e in ipairs(self.items) do
      e.tex:ClearAllPoints(); e.tex:SetPoint("LEFT", x, 0)
      e.fs:ClearAllPoints(); e.fs:SetPoint("LEFT", e.tex, "RIGHT", 4, 0)
      x = x + 16 + 4 + math.ceil(e.fs:GetStringWidth() or 0) + 10
    end
    self:SetWidth(math.max(40, x - 10))
    self:Fit()
  end
  function f:Fit()
    local footer = panel.footer
    local specRight, footLeft = panel.specBtn and panel.specBtn:GetRight(), footer:GetLeft()
    if not (specRight and footLeft) then return end
    local free = (footer:GetWidth() or 0) - (specRight - footLeft) - (panel.refreshBtn:GetWidth() or 0) - 8 - 12 - 12
    self:SetShown(self:GetWidth() <= free)
  end
  f:Layout()
  f:SetScript("OnShow", f.Layout)
  f:SetScript("OnEnter", function(self) MV.MarksTooltip(self) end)
  f:SetScript("OnLeave", W.TipHide)
  MV.legend = f
  panel.footer:HookScript("OnSizeChanged", function() f:Layout() end)
end

do
  local ev = CreateFrame("Frame")
  local okDelayed = pcall(ev.RegisterEvent, ev, "BAG_UPDATE_DELAYED")
  if not okDelayed then ev:RegisterEvent("BAG_UPDATE") end
  ev:SetScript("OnEvent", function()
    if panel:IsShown() and IsCurrent() and MakersPath.UI.QueueRedraw then MakersPath.UI.QueueRedraw() end
  end)
end
