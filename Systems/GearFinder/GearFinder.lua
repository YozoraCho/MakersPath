local ADDON, ns = ...
ns.Systems = ns.Systems or {}
ns.Systems.GearFinder = ns.Systems.GearFinder or {}
local GF = ns.Systems.GearFinder

GF._callbacks = {}
GF._scanQueued = false

function GF:SetCallback(fn)
  if type(fn) ~= "function" then return end
  self._callbacks[#self._callbacks+1] = fn
end

local function Fire(results)
  for _, fn in ipairs(GF._callbacks) do
    pcall(fn, results)
  end
end

local function GetEquippedItemLink(invSlot)
  return GetInventoryItemLink("player", invSlot)
end

function GF:RequestScan(opts)
  opts = opts or {}

  if not opts.force and not self._dirty and self._results then
    Fire(self._results)
    return
  end

  if self._scanQueued then return end
  self._scanQueued = true

  C_Timer.After(0.05, function()
    self._scanQueued = false
    self:_ScanIncremental()
  end)
end

function GF:_ScanIncremental()
  local Slots = self
  local results = {}

  local i = 1
  local function step()
    local slotKey = Slots.SLOT_ORDER[i]
    if not slotKey then
      self:_SetResults(results)
      Fire(results)
      return
    end

    local invSlot = Slots.SLOT_TO_INVSLOT[slotKey]
    local equippedLink = invSlot and GetEquippedItemLink(invSlot)

    local candidates = self:GetCandidatesForSlot(slotKey)

    local best, alts = self:PickBestAndAlts(candidates, equippedLink)

    if best then
      results[slotKey] = {
        best = best,
        alts = alts,
      }
    end

    i = i + 1
    C_Timer.After(0, step)
  end

  step()
end