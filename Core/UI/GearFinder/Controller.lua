local SYS = ns.Systems and ns.Systems.GearFinder

function ns.UI.GearFinder:BindSystem()
  if self._bound or not SYS then return end
  self._bound = true

  SYS:SetCallback(function(results)
    self:Update(results)
  end)
end

function ns.UI.GearFinder:ScanNow()
  self:BindSystem()
  SYS:RequestScan({ force = true })
end