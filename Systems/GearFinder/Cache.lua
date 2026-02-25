local ADDON, ns = ...
local GF = ns.Systems.GearFinder

GF._dirty = true
GF._results = {}
GF._lastScanAt = 0

function GF:MarkDirty()
  self._dirty = true
end

function GF:GetResults()
  return self._results or {}
end

function GF:_SetResults(results)
  self._results = results or {}
  self._dirty = false
  self._lastScanAt = GetTime()
end