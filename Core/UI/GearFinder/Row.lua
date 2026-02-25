local ADDON, ns = ...
local GF = ns.UI.GearFinder

local function LT(key)
  local L = ns.L
  if L and L[key] then return L[key] end
  return key
end

function GF:CreateRow(parent)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(36)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(32, 32)
  row.icon:SetPoint("LEFT", 0, 0)
  row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

  row.primary = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.primary:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
  row.primary:SetJustifyH("LEFT")

  row.reqProf = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.reqProf:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 2)
  row.reqProf:SetJustifyH("LEFT")

  row.reqSkill = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.reqSkill:SetPoint("LEFT", row.reqProf, "RIGHT", 4, 0)

  row.slotLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.slotLabel:SetPoint("RIGHT", -6, 0)

  function row:SetSlot(slotKey)
    self.slotKey = slotKey
    self.slotLabel:SetText(LT("SLOT_" .. slotKey))
  end

  function row:SetEmpty()
    self.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.primary:SetText(LT("NO_UPGRADE_FOUND"))
    self.primary:SetTextColor(0.6, 0.6, 0.6)
    self.reqProf:SetText("")
    self.reqSkill:SetText("")
  end

  function row:SetResult(r)
    if r.icon then
      self.icon:SetTexture(r.icon)
    else
      self.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    self.primary:SetText(r.itemLink or LT("UNKNOWN_ITEM"))
    self.primary:SetTextColor(1, 1, 1)

    local profText = LT("PROF_" .. (r.professionKey or "UNKNOWN"))
    self.reqProf:SetText(profText)
    self.reqProf:SetTextColor(1, 0.2, 0.2)

    self.reqSkill:SetText(r.skillRequired and tostring(r.skillRequired) or "")
    self.reqSkill:SetTextColor(0.2, 1, 0.2)
  end

  return row
end