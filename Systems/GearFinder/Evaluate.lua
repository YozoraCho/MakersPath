local ADDON, ns = ...
local GF = ns.Systems.GearFinder

local ALT_MAX = 3

function GF:ScoreCandidate(candidate, equipped)

  return candidate._score or 0
end

function GF:PickBestAndAlts(candidates, equipped)
  if not candidates or #candidates == 0 then return nil end

  for _, c in ipairs(candidates) do
    c.score = self:ScoreCandidate(c, equipped)
  end

  table.sort(candidates, function(a, b) return (a.score or 0) > (b.score or 0) end)

  local best = candidates[1]
  local alts = {}
  for i = 2, math.min(#candidates, 1 + ALT_MAX) do
    alts[#alts+1] = candidates[i]
  end

  return best, (#alts > 0 and alts or nil)
end