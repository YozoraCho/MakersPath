local ADDON, ns = ...
local GF = ns.UI.GearFinder

function GF:Create(parent)
  if self.panel then return self.panel end

  local panel = CreateFrame("Frame", nil, parent)
  self.panel = panel
  panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -48)
  panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 16)

  panel.rows = {}

  local col1 = CreateFrame("Frame", nil, panel)
  col1:SetPoint("TOPLEFT")
  col1:SetPoint("BOTTOMLEFT")
  col1:SetWidth((parent:GetWidth() - 48) / 2)

  local col2 = CreateFrame("Frame", nil, panel)
  col2:SetPoint("TOPRIGHT")
  col2:SetPoint("BOTTOMRIGHT")
  col2:SetWidth((parent:GetWidth() - 48) / 2)

  local rowH, gap = 36, 6
  local slots = self.SLOT_ORDER
  local half = math.floor(#slots / 2)

  for i, slotKey in ipairs(slots) do
    local col = (i <= half) and col1 or col2
    local idxInCol = (i <= half) and i or (i - half)

    local row = self:CreateRow(col)
    row:SetPoint("TOPLEFT", 0, -((idxInCol - 1) * (rowH + gap)))
    row:SetPoint("TOPRIGHT", 0, -((idxInCol - 1) * (rowH + gap)))
    row:SetSlot(slotKey)
    row:SetEmpty()

    panel.rows[slotKey] = row
  end

  return panel
end