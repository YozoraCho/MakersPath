local ADDON, ns = ...
ns.Systems = ns.Systems or {}
ns.Systems.GearFinder = ns.Systems.GearFinder or {}
local GF = ns.Systems.GearFinder

GF._callbacks = {}
GF._resultsByChar = {}
GF._dirtyByChar = {}
GF._scanQueued = false

local function CharKey()
  if ns.Util and ns.Util.CurrentCharKey then return ns.Util.CurrentCharKey() end
  local name = UnitName("player") or "?"
  local realm = GetRealmName() or "?"
  return name .. "-" .. realm
end

function GF:SetCallback(fn)
  if type(fn) ~= "function" then return end
  self._callbacks[#self._callbacks+1] = fn
end

local function Fire(results)
  for _, fn in ipairs(GF._callbacks) do pcall(fn, results) end
end

function GF:MarkDirty()
  self._dirtyByChar[CharKey()] = true
end

function GF:GetResults()
  return self._resultsByChar[CharKey()] or {}
end

function GF:RequestScan(opts)
  opts = opts or {}
  local key = CharKey()

  if not opts.force and not self._dirtyByChar[key] and self._resultsByChar[key] then
    Fire(self._resultsByChar[key])
    return self._resultsByChar[key]
  end

  if self._scanQueued then return end
  self._scanQueued = true

  C_Timer.After(0.05, function()
    self._scanQueued = false
    local results = self:_ScanNow()
    self._resultsByChar[key] = results
    self._dirtyByChar[key] = false
    Fire(results)
  end)
end

function GF:_ScanNow()
  local Slots = ns.Systems.GearFinder.Slots
  local out = {}

  for _, slot in ipairs(Slots.SLOT_ORDER) do
    local best = self:GetBestForSlot(slot)
    if best then out[slot] = best end
  end

  return out
end