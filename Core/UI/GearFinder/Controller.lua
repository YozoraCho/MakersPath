local ADDON, ns = ...
local UI = ns.UI.GearFinder
local SYS = ns.Systems.GearFinder

function UI:BindSystem()
  if self._bound then return end
  self._bound = true

  SYS:SetCallback(function(results)
    self:Update(results)
  end)
end

function UI:ScanNow()
  self:BindSystem()
  SYS:RequestScan({ force = true })
end