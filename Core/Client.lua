local ADDON, ns = ...
ns.Client = ns.Client or {}
local C = ns.Client

local build = select(4, GetBuildInfo())
C.build = build or 0
if C.build >= 30400 then
  C.flavor = "WRATH"
elseif C.build >= 20505 then
  C.flavor = "TBC"
else
  C.flavor = "ERA"
end

C.has = C.has or {}
C.has.C_Item = (C_Item and true) or false
C.has.C_AddOns = (C_AddOns and true) or false

function C.LoadAddOn(name)
  if C_AddOns and C_AddOns.LoadAddOn then
    return C_AddOns.LoadAddOn(name)
  end
  if LoadAddOn then
    return LoadAddOn(name)
  end
  return nil
end