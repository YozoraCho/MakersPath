local ADDON, ns = ...
local AceLocale = LibStub("AceLocale-3.0")
_G.MakersPath = ns

ns.name = ADDON
ns.version = "2.0.0"
ns.L = AceLocale:GetLocale(ADDON)
local L = ns.L

local DEFAULTS = {
  minimap = { hide = false, minimapPos = 220 },
}

local function ApplyDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = dst[k] or {}
      ApplyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
  if name ~= ADDON then return end

  MakersPathDB = MakersPathDB or {}
  MakersPathGlobalDB = MakersPathGlobalDB or {}

  ApplyDefaults(MakersPathDB, DEFAULTS)
  ns.db = MakersPathDB
  ns.gdb = MakersPathGlobalDB

  local flavor = (ns.Client and ns.Client.flavor) or "?"
  print(L["BOOT_LOADED"]:format(flavor))
end)