local ADDON, ns = ...

SLASH_MAKERSPATH1 = "/mp"
SLASH_MAKERSPATH2 = "/makerspath"

SlashCmdList["MAKERSPATH"] = function()
  if ns.UI and ns.UI.Toggle then
    ns.UI:Toggle()
  end
end