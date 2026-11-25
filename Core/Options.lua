local ADDON, MakersPath = ...
MakersPath = MakersPath or {}
MakersPath.UI = MakersPath.UI or {}
MakersPath.Config = MakersPath.Config or {}

local L = LibStub("AceLocale-3.0"):GetLocale("MakersPath", true) or {}
local function LT(key, fallback)
  return (L and rawget(L, key)) or fallback or key
end

local T, W = MakersPath.Theme, MakersPath.Widgets

local function ConfigDB()
  MakersPathDB = MakersPathDB or {}
  MakersPathDB.config = MakersPathDB.config or {}
  return MakersPathDB.config
end

local function RefreshAddon()
  if MakersPath and MakersPath.GearFinder and MakersPath.GearFinder.MarkDirty then
    MakersPath.GearFinder:MarkDirty()
  end
  if MakersPath and MakersPath.GearFinderScan then
    MakersPath.GearFinderScan()
  end
  if MakersPath and MakersPath.RequestUIRefresh then
    MakersPath.RequestUIRefresh()
  end
end
MakersPath.UI.RefreshAddon = RefreshAddon

local function Setting(get, set)
  return get, function(v) set(v); RefreshAddon() end
end

local function Stack(panel)
  local y = -10
  local st = {}
  function st:Group(title)
    local h = W.Heading(panel, title)
    h:SetPoint("TOPLEFT", 16, y)
    h:SetPoint("RIGHT", -16, 0)
    y = y - 24
    return h
  end
  function st:Add(ctrl, gapAfter)
    ctrl:SetPoint("TOPLEFT", 16, y)
    ctrl:SetPoint("RIGHT", -16, 0)
    y = y - ctrl:GetHeight() - (gapAfter or 6)
    return ctrl
  end
  function st:Space(n) y = y - (n or 8) end
  return st
end

-- =====================================================================
-- General
-- =====================================================================
local function BuildGeneralPanel(parent)
  local p = CreateFrame("Frame", nil, parent)
  local st = Stack(p)

  st:Group(LT("OPT_GROUP_RECS", "Recommendations"))
  st:Add(W.Check(p, LT("OPT_PREF_NATIVE_ARMOR", "Prefer my class's armor type"),
    LT("OPT_PREF_NATIVE_ARMOR_DESC", "Used when two items score about the same"),
    Setting(function() return ConfigDB().PREF_NATIVE_ARMOR ~= false end,
            function(v) ConfigDB().PREF_NATIVE_ARMOR = (v == true) end)))
  st:Add(W.Check(p, LT("OPT_TRAINER_ONLY", "Trainer recipes only"),
    LT("OPT_TRAINER_ONLY_DESC", "Hide recipes from drops, vendors and quests"),
    Setting(function() return ConfigDB().TRAINER_ONLY == true end,
            function(v) ConfigDB().TRAINER_ONLY = (v == true) end)))
  st:Add(W.Check(p, LT("OPT_IGNORE_FILTERS", "Ignore class and weapon checks"),
    LT("OPT_IGNORE_FILTERS_DESC", "Show everything that can be crafted"),
    Setting(function() return ConfigDB().IGNORE_FILTERS == true end,
            function(v) ConfigDB().IGNORE_FILTERS = (v == true) end)))
  st:Add(W.Check(p, LT("OPT_ONLY_STATS_WEAPONS", "Score weapons on stats only"),
    LT("OPT_ONLY_STATS_WEAPONS_DESC", "Leave weapon damage out of the score"),
    Setting(function() return ConfigDB().ONLY_STATS_WEAPONS == true end,
            function(v) ConfigDB().ONLY_STATS_WEAPONS = (v == true) end)))

  st:Space(6)
  st:Group(LT("PATH_TITLE", "The Path"))
  st:Add(W.Stepper(p, LT("OPT_LOOKAHEAD", "Look ahead"),
    LT("OPT_LOOKAHEAD_DESC", "Include upgrades you can wear within this many levels"),
    function() return tonumber(MakersPath.FutureWindow) or 1 end,
    function(v)
      MakersPath.FutureWindow = v
      ConfigDB().FUTURE_WINDOW = v
      if MakersPath.GearFinder and MakersPath.GearFinder.MarkDirty then MakersPath.GearFinder:MarkDirty() end
      if MakersPathFrame and MakersPathFrame:IsShown() and MakersPath.RequestUIRefresh then MakersPath.RequestUIRefresh(0.2) end
    end,
    function(v) return string.format(LT("OPT_LEVELS_FMT", "%d |4level:levels;"), v) end,
    0, 60, 1))

  st:Space(6)
  st:Group(LT("OPT_GROUP_WINDOW", "Window"))
  st:Add(W.Check(p, LT("OPT_HIDE_MINIMAP", "Hide minimap button"), nil,
    function() return MakersPathDB and MakersPathDB.minimap and MakersPathDB.minimap.hide == true end,
    function(v)
      if v then if MakersPath_Minimap_Hide then MakersPath_Minimap_Hide() end
      else if MakersPath_Minimap_Show then MakersPath_Minimap_Show() end end
    end))
  st:Add(W.Stepper(p, LT("OPT_SCALE", "Scale"), LT("OPT_SCALE_DESC", "Ctrl + mouse wheel over the window also works"),
    function() return (MakersPathDB and MakersPathDB.scale) or 1.0 end,
    function(v)
      MakersPathDB = MakersPathDB or {}
      MakersPathDB.scale = v
      if MakersPathFrame then MakersPathFrame:SetScale(v) end
    end,
    function(v) return string.format("%.2f", v) end,
    0.7, 1.4, 0.05))
  return p
end

-- =====================================================================
-- Debug
-- =====================================================================
local function BuildDebugPanel(parent)
  local p = CreateFrame("Frame", nil, parent)
  local st = Stack(p)
  st:Group(LT("OPT_SECTION_DEBUG", "Debug"))
  st:Add(W.Check(p, LT("OPT_DEBUG_GF", "Debug GearFinder"), LT("OPT_DEBUG_GF_TT", "Print GearFinder debug output to chat."),
    function() return MakersPath.GetDebugGF and MakersPath.GetDebugGF() or false end,
    function(v) if MakersPath.SetDebugGF then MakersPath.SetDebugGF(v) end end))
  st:Add(W.Check(p, LT("OPT_DEBUG_TIMING", "Debug timing"), LT("OPT_DEBUG_TIMING_TT", "Print BuildSummary timing information."),
    function() return MakersPath.GetDebugTiming and MakersPath.GetDebugTiming() or false end,
    function(v) if MakersPath.SetDebugTiming then MakersPath.SetDebugTiming(v) end end))
  return p
end

-- =====================================================================
-- Frame
-- =====================================================================
function MakersPath.UI:CreateOptionsFrame()
  if self.OptionsFrame then
    return self.OptionsFrame
  end

  local f = CreateFrame("Frame", "MakersPathOptionsFrame", UIParent)
  self.OptionsFrame = f

  f:SetSize(470, 540)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:Hide()
  table.insert(UISpecialFrames, "MakersPathOptionsFrame")

  local page = W.Window(f)
  W.MakeMovable(f)
  local header = W.Header(page, LT("OPT_HEADER", "Options"), function() f:Hide() end)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() f:StartMoving() end)
  header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

  local footer = W.Footer(page)

  local body = CreateFrame("Frame", nil, page)
  body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -30)
  body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT")

  local generalPanel = BuildGeneralPanel(body)
  local weightsPanel
  if MakersPath.UI.BuildWeightsPanel then
    weightsPanel = MakersPath.UI:BuildWeightsPanel(body)
  else
    weightsPanel = CreateFrame("Frame", nil, body)
    local msg = W.Text(weightsPanel, "body", "muted")
    msg:SetPoint("CENTER")
    msg:SetText(LT("OPT_WEIGHTS_UNAVAILABLE", "Weight editor unavailable."))
  end
  local debugPanel = BuildDebugPanel(body)
  local panels = { generalPanel, weightsPanel, debugPanel }
  for _, p in ipairs(panels) do
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -4)
    p:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 4)
  end
  f.WeightsPanel = weightsPanel

  local tabs = W.Tabs(page, { LT("OPT_TAB_GENERAL", "General"), LT("OPT_TAB_WEIGHTS", "Stat weights"), LT("OPT_TAB_DEBUG", "Debug") },
    function(i)
      for k, p in ipairs(panels) do p:SetShown(k == i) end
      f.activeTab = i
    end)
  tabs:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
  tabs:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
  f.SelectTab = function(i) tabs:Select(i) end
  tabs:Select(1)

  local resetBtn = W.Button(footer, LT("OPT_RESET_POSITION", "Reset window position"), function()
    if SlashCmdList and SlashCmdList["MAKERSPATHRESET"] then SlashCmdList["MAKERSPATHRESET"]() end
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end)
  resetBtn:SetPoint("LEFT", 8, 0)

  local ver = W.Text(footer, "small", "muted")
  ver:SetPoint("RIGHT", -10, 0)
  ver:SetText((LT("ADDON_NAME", "Maker's Path")) .. " " .. tostring(MakersPath.version or ""))

  return f
end

function MakersPath.UI:ToggleOptions(tabIndex)
  local f = self.OptionsFrame or self:CreateOptionsFrame()
  if f:IsShown() and not tabIndex then
    f:Hide()
  else
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:Show()
    f:Raise()
    if tabIndex and f.SelectTab then f.SelectTab(tabIndex) end
  end
end

SLASH_MPOPTIONS1 = "/mpoptions"
SLASH_MPOPTIONS2 = "/mpsettings"
SlashCmdList["MPOPTIONS"] = function()
  if MakersPath and MakersPath.UI and MakersPath.UI.ToggleOptions then
    MakersPath.UI:ToggleOptions()
  end
end

SLASH_MPWEIGHTS1 = "/mpweights"
SlashCmdList["MPWEIGHTS"] = function()
  if MakersPath and MakersPath.UI and MakersPath.UI.ToggleOptions then
    MakersPath.UI:ToggleOptions(2)
  end
end
