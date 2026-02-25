local ADDON, ns = ...

ns.UI = ns.UI or {}

local function LT(key)
  local L = ns.L
  if L and L[key] then return L[key] end
  return key
end

function ns.UI:CreateMainFrame()
  if self.frame then return self.frame end

  local f = CreateFrame("Frame", "MakersPathMainFrame", UIParent, "BackdropTemplate")
  self.frame = f

  f:SetSize(860, 520)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:Hide()

  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })

  -- Dragging
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  -- Title
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText(LT("UI_TITLE"))

  -- Close button
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  if ns.UI.GearFinder and ns.UI.GearFinder.Create then
    ns.UI.GearFinder:Create(f)
  end
  if ns.UI.GearFinder and ns.UI.GearFinder.ScanNow then
    ns.UI.GearFinder:ScanNow()
  end

  return f
end

function ns.UI:Show()
  local f = self.frame or self:CreateMainFrame()
  f:Show()
  f:Raise()
end

function ns.UI:Hide()
  if self.frame then self.frame:Hide() end
end

function ns.UI:Toggle()
  local f = self.frame or self:CreateMainFrame()
  if f:IsShown() then self:Hide() else self:Show() end
end