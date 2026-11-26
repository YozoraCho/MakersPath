local _, MakersPath = ...
MakersPath = MakersPath or {}

local T = MakersPath.Theme
local C, S, Tex = T.C, T.S, T.Tex
local W = {}
MakersPath.Widgets = W

-- =================== Basics ===================
function W.Fill(parent, color, layer, sub)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
  local c = type(color) == "string" and C[color] or color
  t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
  return t
end

function W.SetColor(tex, color, alpha)
  local c = type(color) == "string" and C[color] or color
  tex:SetColorTexture(c[1], c[2], c[3], alpha or c[4] or 1)
end

function W.TextColor(fs, color)
  local c = type(color) == "string" and C[color] or color
  fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

function W.Tile(parent, path, layer, sub)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
  t:SetTexture(path, "REPEAT", "REPEAT")
  if t.SetHorizTile then t:SetHorizTile(true); t:SetVertTile(true) end
  return t
end

function W.KeepTiled(frame, tex, size)
  size = size or 128
  local function fit()
    local w, h = frame:GetSize()
    if w and w > 0 and h and h > 0 then tex:SetTexCoord(0, w / size, 0, h / size) end
  end
  frame:HookScript("OnSizeChanged", fit)
  fit()
end

function W.Text(parent, role, color, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFontObject(T.Font[role or "body"])
  W.TextColor(fs, color or "bone")
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("MIDDLE")
  fs:SetWordWrap(false)
  return fs
end

function W.Line(parent, color, layer, vertical, thickness)
  local t = W.Fill(parent, color, layer or "ARTWORK")
  if vertical then t:SetWidth(thickness or 1) else t:SetHeight(thickness or 1) end
  return t
end

function W.Rule(parent, layer)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(2)
  local a = W.Fill(f, "ruleDark", layer or "ARTWORK")
  a:SetPoint("TOPLEFT"); a:SetPoint("TOPRIGHT"); a:SetHeight(1)
  local b = W.Fill(f, "ruleLight", layer or "ARTWORK")
  b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT"); b:SetHeight(1)
  return f
end

function W.Heading(parent, text)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(18)
  f.label = W.Text(f, "strong", "brass")
  f.label:SetPoint("LEFT")
  f.label:SetText(text or "")
  f.note = W.Text(f, "small", "muted")
  f.note:SetPoint("LEFT", f.label, "RIGHT", 6, 0)
  f.rule = W.Rule(f)
  f.rule:SetPoint("LEFT", f.note, "RIGHT", 6, 0)
  f.rule:SetPoint("RIGHT")
  function f:SetText(t, note)
    self.label:SetText(t or "")
    self.note:SetText(note or "")
  end
  return f
end

function W.Inset(parent)
  local f = CreateFrame("Frame", nil, parent)
  f.bg = W.Fill(f, "panel")
  f.bg:SetAllPoints()
  local top = W.Line(f, "ruleDark", "BORDER"); top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT")
  local bot = W.Line(f, "ruleLight", "BORDER"); bot:SetPoint("BOTTOMLEFT", 0, -1); bot:SetPoint("BOTTOMRIGHT", 0, -1)
  return f
end

-- =================== Windows ===================
function W.Window(frame)
  if frame.SetBackdrop then frame:SetBackdrop(nil) end

  local leather = W.Tile(frame, Tex.leather, "BACKGROUND", -8)
  leather:SetAllPoints()
  W.KeepTiled(frame, leather)

  local edge = {
    W.Line(frame, "ruleDark", "BACKGROUND", false), W.Line(frame, "ruleDark", "BACKGROUND", false),
    W.Line(frame, "ruleDark", "BACKGROUND", true),  W.Line(frame, "ruleDark", "BACKGROUND", true),
  }
  edge[1]:SetPoint("TOPLEFT"); edge[1]:SetPoint("TOPRIGHT")
  edge[2]:SetPoint("BOTTOMLEFT"); edge[2]:SetPoint("BOTTOMRIGHT")
  edge[3]:SetPoint("TOPLEFT"); edge[3]:SetPoint("BOTTOMLEFT")
  edge[4]:SetPoint("TOPRIGHT"); edge[4]:SetPoint("BOTTOMRIGHT")

  local page = CreateFrame("Frame", nil, frame)
  page:SetPoint("TOPLEFT", S.pad, -S.pad)
  page:SetPoint("BOTTOMRIGHT", -S.pad, S.pad)
  page.bg = W.Fill(page, "page", "BACKGROUND", -8)
  page.bg:SetAllPoints()

  local o = {
    W.Line(page, "ruleDark", "BORDER"), W.Line(page, "ruleDark", "BORDER"),
    W.Line(page, "ruleDark", "BORDER", true), W.Line(page, "ruleDark", "BORDER", true),
  }
  o[1]:SetPoint("TOPLEFT", -1, 1); o[1]:SetPoint("TOPRIGHT", 1, 1)
  o[2]:SetPoint("BOTTOMLEFT", -1, -1); o[2]:SetPoint("BOTTOMRIGHT", 1, -1)
  o[3]:SetPoint("TOPLEFT", -1, 1); o[3]:SetPoint("BOTTOMLEFT", -1, -1)
  o[4]:SetPoint("TOPRIGHT", 1, 1); o[4]:SetPoint("BOTTOMRIGHT", 1, -1)
  local hl = W.Line(page, "edgeLight", "BORDER")
  hl:SetPoint("TOPLEFT"); hl:SetPoint("TOPRIGHT")

  local coords = {
    { "TOPLEFT", 0, 1, 0, 1 }, { "TOPRIGHT", 1, 0, 0, 1 },
    { "BOTTOMLEFT", 0, 1, 1, 0 }, { "BOTTOMRIGHT", 1, 0, 1, 0 },
  }
  local deco = CreateFrame("Frame", nil, frame)
  deco:SetAllPoints()
  deco:SetFrameLevel(page:GetFrameLevel() + 12)
  frame.deco = deco
  for _, c in ipairs(coords) do
    local t = deco:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture(Tex.corner)
    t:SetSize(18, 18)
    t:SetPoint(c[1])
    t:SetTexCoord(c[2], c[3], c[4], c[5])
  end

  frame.page = page
  return page
end

function W.Header(page, titleText, onClose)
  local h = CreateFrame("Frame", nil, page)
  h:SetPoint("TOPLEFT"); h:SetPoint("TOPRIGHT")
  h:SetHeight(S.header)
  h.bg = W.Fill(h, "bar", "BACKGROUND", -6); h.bg:SetAllPoints()
  local line = W.Line(h, "ruleDark", "BORDER"); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")

  h.emblem = h:CreateTexture(nil, "ARTWORK")
  h.emblem:SetTexture(Tex.emblem)
  h.emblem:SetSize(30, 30)
  h.emblem:SetPoint("LEFT", 7, 0)

  h.title = W.Text(h, "title", "brassLight")
  h.title:SetPoint("LEFT", h.emblem, "RIGHT", 8, 0)
  h.title:SetText(titleText or "")

  h.close = W.IconButton(h, Tex.close, 10, onClose)
  h.close:SetPoint("RIGHT", -6, 0)
  h.right = h.close
  return h
end

function W.HeaderDivider(h, anchor)
  local d = CreateFrame("Frame", nil, h)
  d:SetSize(2, 18)
  local a = W.Fill(d, "ruleDark", "ARTWORK"); a:SetPoint("TOPLEFT"); a:SetPoint("BOTTOMLEFT"); a:SetWidth(1)
  local b = W.Fill(d, "edgeLight", "ARTWORK"); b:SetPoint("TOPRIGHT"); b:SetPoint("BOTTOMRIGHT"); b:SetWidth(1)
  d:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
  return d
end

function W.Footer(page)
  local f = CreateFrame("Frame", nil, page)
  f:SetPoint("BOTTOMLEFT"); f:SetPoint("BOTTOMRIGHT")
  f:SetHeight(S.footer)
  f.bg = W.Fill(f, "bar", "BACKGROUND", -6); f.bg:SetAllPoints()
  local a = W.Line(f, "ruleDark", "BORDER"); a:SetPoint("TOPLEFT"); a:SetPoint("TOPRIGHT")
  local b = W.Line(f, "edgeLight", "BORDER"); b:SetPoint("TOPLEFT", 0, -1); b:SetPoint("TOPRIGHT", 0, -1)
  return f
end

function W.MakeMovable(frame, handle, onStop)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  handle = handle or frame
  handle:EnableMouse(true)
  handle:RegisterForDrag("LeftButton")
  handle:SetScript("OnDragStart", function() frame:StartMoving() end)
  handle:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    if onStop then
      local p, _, rp, x, y = frame:GetPoint(1)
      onStop(p, rp, x, y)
    end
  end)
end

-- =================== Buttons ===================
local function paintButton(b)
  local primary = b._primary
  local state = (not b:IsEnabled()) and "off" or b._down and "down" or b._over and "over" or "up"
  local bg = primary and { 0.169, 0.133, 0.086, 1 } or C.button
  if state == "over" then bg = primary and { 0.22, 0.17, 0.10, 1 } or { 0.18, 0.145, 0.11, 1 } end
  if state == "down" then bg = { 0.10, 0.08, 0.06, 1 } end
  W.SetColor(b.bg, bg)
  local edge = primary and { 0.69, 0.553, 0.341, 1 } or C.buttonEdge
  if state == "over" and not primary then edge = C.brassDark end
  for _, e in ipairs(b.edges) do W.SetColor(e, edge) end
  W.SetColor(b.shine, primary and { 0.43, 0.337, 0.204, 1 } or C.edgeLight, state == "down" and 0 or 1)
  if b.label then
    if state == "off" then W.TextColor(b.label, "faint")
    elseif primary then W.TextColor(b.label, { 0.886, 0.773, 0.549, 1 })
    else W.TextColor(b.label, "bone") end
  end
  if b.chev then b.chev:SetVertexColor(C.secondary[1], C.secondary[2], C.secondary[3]) end
end

local function frameEdges(b)
  local e = {
    W.Line(b, "buttonEdge", "BORDER"), W.Line(b, "buttonEdge", "BORDER"),
    W.Line(b, "buttonEdge", "BORDER", true), W.Line(b, "buttonEdge", "BORDER", true),
  }
  e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT")
  e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT")
  e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT")
  e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT")
  return e
end

function W.Button(parent, text, onClick, opts)
  opts = opts or {}
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(opts.height or 22)
  b._primary = opts.primary
  b.bg = W.Fill(b, "button", "BACKGROUND"); b.bg:SetAllPoints()
  b.edges = frameEdges(b)
  b.shine = W.Line(b, "edgeLight", "ARTWORK"); b.shine:SetPoint("TOPLEFT", 1, -1); b.shine:SetPoint("TOPRIGHT", -1, -1)
  local pad = opts.pad or 8
  b.label = W.Text(b, "body", "bone")
  b.label:SetPoint("LEFT", pad, 0)
  if opts.dropdown then
    b.chev = b:CreateTexture(nil, "ARTWORK")
    b.chev:SetTexture(Tex.chevron)
    b.chev:SetSize(9, 9)
    b.chev:SetPoint("RIGHT", -7, 0)
    b.label:SetPoint("RIGHT", b.chev, "LEFT", -5, 0)
  else
    b.label:SetPoint("RIGHT", -pad, 0)
    b.label:SetJustifyH("CENTER")
  end
  b._fixedW = opts.width
  function b:SetText(t)
    self.label:SetText(t or "")
    if not self._fixedW then
      local w = self.label:GetStringWidth() + pad * 2 + (self.chev and 14 or 0)
      self:SetWidth(math.max(opts.minWidth or 0, math.ceil(w)))
    end
  end
  function b:GetText() return self.label:GetText() end
  if opts.width then b:SetWidth(opts.width) end
  b:SetText(text)
  b:SetScript("OnEnter", function(self) self._over = true; paintButton(self); if self.tooltip then W.SimpleTooltip(self, self.tooltip, self.tooltipText) end end)
  b:SetScript("OnLeave", function(self) self._over = false; self._down = false; paintButton(self); if self.tooltip then W.TipHide() end end)
  b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self._down = true; paintButton(self) end end)
  b:SetScript("OnMouseUp", function(self) self._down = false; paintButton(self) end)
  b:SetScript("OnEnable", paintButton)
  b:SetScript("OnDisable", paintButton)
  if onClick then b:SetScript("OnClick", onClick) end
  paintButton(b)
  return b
end

function W.IconButton(parent, path, size, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(22, 22)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexture(path)
  b.icon:SetSize(size or 10, size or 10)
  b.icon:SetPoint("CENTER")
  b.icon:SetVertexColor(C.secondary[1], C.secondary[2], C.secondary[3])
  b:SetScript("OnEnter", function(self) self.icon:SetVertexColor(C.bone[1], C.bone[2], C.bone[3]) end)
  b:SetScript("OnLeave", function(self) self.icon:SetVertexColor(C.secondary[1], C.secondary[2], C.secondary[3]) end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

function W.LinkButton(parent, text, icon, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(18)
  b.label = W.Text(b, "body", "brass")
  if icon then
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture(icon)
    b.icon:SetSize(9, 9)
    b.icon:SetPoint("LEFT")
    b.icon:SetVertexColor(C.brass[1], C.brass[2], C.brass[3])
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
  else
    b.label:SetPoint("LEFT")
  end
  b.label:SetText(text)
  b:SetWidth(b.label:GetStringWidth() + (icon and 13 or 0))
  b:SetScript("OnEnter", function(self) W.TextColor(self.label, "brassLight") end)
  b:SetScript("OnLeave", function(self) W.TextColor(self.label, "brass") end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

function W.Dropdown(parent, name, initFn, opts)
  local LibDD = MakersPath.LibDD or (LibStub and LibStub("LibUIDropDownMenu-4.0", true))
  local b = W.Button(parent, "", nil, { dropdown = true, minWidth = opts and opts.minWidth, width = opts and opts.width })
  local menu = LibDD:Create_UIDropDownMenu(name, UIParent)
  menu.displayMode = "MENU"
  LibDD:UIDropDownMenu_Initialize(menu, initFn, "MENU")
  b:SetScript("OnClick", function(self)
    LibDD:ToggleDropDownMenu(1, nil, menu, self, 0, 0)
  end)
  b.menu = menu
  return b
end

-- =================== Checkbox ===================
function W.Check(parent, label, desc, getter, setter)
  local f = CreateFrame("Button", nil, parent)
  f:SetHeight(desc and desc ~= "" and 34 or 20)
  f.box = CreateFrame("Frame", nil, f)
  f.box:SetSize(16, 16)
  f.box:SetPoint("TOPLEFT", 0, -2)
  f.box.bg = W.Fill(f.box, "well"); f.box.bg:SetAllPoints()
  f.box.edges = frameEdges(f.box)
  f.tick = f.box:CreateTexture(nil, "OVERLAY")
  f.tick:SetTexture(Tex.check)
  f.tick:SetSize(16, 16)
  f.tick:SetPoint("CENTER")
  f.label = W.Text(f, "body", "bone")
  f.label:SetPoint("TOPLEFT", f.box, "TOPRIGHT", 8, 0)
  f.label:SetPoint("RIGHT")
  f.label:SetHeight(16)
  f.label:SetText(label)
  if desc and desc ~= "" then
    f.desc = W.Text(f, "small", "muted")
    f.desc:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -1)
    f.desc:SetPoint("RIGHT")
    f.desc:SetText(desc)
  end
  function f:Sync()
    local on = getter() and true or false
    self.tick:SetShown(on)
  end
  f:SetScript("OnClick", function(self)
    setter(not getter())
    self:Sync()
  end)
  f:SetScript("OnShow", f.Sync)
  f:SetScript("OnEnter", function(self) for _, e in ipairs(self.box.edges) do W.SetColor(e, "brassDark") end end)
  f:SetScript("OnLeave", function(self) for _, e in ipairs(self.box.edges) do W.SetColor(e, "buttonEdge") end end)
  f:Sync()
  return f
end

function W.Stepper(parent, label, desc, getter, setter, format, minV, maxV, step)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(34)
  f.label = W.Text(f, "body", "bone")
  f.label:SetPoint("TOPLEFT", 0, -2)
  f.label:SetText(label)
  f.desc = W.Text(f, "small", "muted")
  f.desc:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -1)
  f.desc:SetText(desc or "")
  f.plus = W.Button(f, "+", nil, { width = 22, pad = 2 })
  f.plus:SetPoint("RIGHT", 0, 0)
  f.value = W.Input(f, 64, { justify = "CENTER", maxLetters = 8 })
  f.value:SetPoint("RIGHT", f.plus, "LEFT", -2, 0)
  f.shown = W.Text(f.value, "body", "bone")
  f.shown:SetPoint("LEFT", 2, 0)
  f.shown:SetPoint("RIGHT", -2, 0)
  f.shown:SetJustifyH("CENTER")
  f.minus = W.Button(f, "-", nil, { width = 22, pad = 2 })
  f.minus:SetPoint("RIGHT", f.value, "LEFT", -2, 0)
  f.desc:SetPoint("RIGHT", f.minus, "LEFT", -8, 0)

  local decimals = 0
  local s = tostring(step)
  if s:find("%.") then decimals = #s:match("%.(%d+)") end
  if decimals == 0 and minV >= 0 then f.value:SetNumeric(true) end
  local function raw(v)
    if decimals == 0 then return tostring(math.floor(v + 0.5)) end
    return string.format("%." .. decimals .. "f", v)
  end

  function f:Sync()
    local v = getter()
    if self.value:HasFocus() then
      self.value:SetText(raw(v))
      self.shown:Hide()
    else
      self.value:SetText("")
      self.shown:SetText(format(v))
      self.shown:Show()
    end
    self.minus:SetEnabled(v > minV + 1e-6)
    self.plus:SetEnabled(v < maxV - 1e-6)
  end
  local function apply(v)
    v = math.max(minV, math.min(maxV, v))
    v = math.floor(v / step + 0.5) * step
    v = math.max(minV, math.min(maxV, v))
    if math.abs(v - getter()) > 1e-6 then setter(v) end
    f:Sync()
  end
  local function bump(d) apply(getter() + d) end
  local function commit(box)
    local text = (box:GetText() or ""):gsub(",", "."):match("^%s*(-?[%d%.]+)")
    local v = tonumber(text)
    if v then apply(v) end
  end

  f.minus:SetScript("OnClick", function() f.value:ClearFocus(); bump(-step) end)
  f.plus:SetScript("OnClick", function() f.value:ClearFocus(); bump(step) end)

  local gained = f.value:GetScript("OnEditFocusGained")
  local lost = f.value:GetScript("OnEditFocusLost")
  f.value:SetScript("OnEditFocusGained", function(self)
    gained(self)
    f.shown:Hide()
    self:SetText(raw(getter()))
    self:HighlightText()
  end)
  f.value:SetScript("OnEditFocusLost", function(self)
    lost(self)
    commit(self)
    f:Sync()
  end)
  f.value:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  f.value:SetScript("OnEscapePressed", function(self)
    self:SetText(raw(getter()))
    self:ClearFocus()
  end)
  f.value:EnableMouseWheel(true)
  f.value:SetScript("OnMouseWheel", function(self, delta)
    if self:HasFocus() then commit(self) end
    bump(delta > 0 and step or -step)
    if self:HasFocus() then self:SetText(raw(getter())); self:HighlightText() end
  end)

  f:SetScript("OnShow", f.Sync)
  f:Sync()
  return f
end

function W.Tabs(parent, labels, onSelect)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(28)
  local rule = W.Rule(bar)
  rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT")
  bar.tabs = {}
  local x = 12
  for i, text in ipairs(labels) do
    local t = CreateFrame("Button", nil, bar)
    t:SetHeight(26)
    t:SetPoint("BOTTOMLEFT", x, 2)
    t.label = W.Text(t, "strong", "secondary")
    t.label:SetPoint("CENTER", 0, 1)
    t.label:SetText(text)
    t:SetWidth(t.label:GetStringWidth() + 16)
    t.under = W.Fill(t, "brass", "ARTWORK")
    t.under:SetHeight(2)
    t.under:SetPoint("BOTTOMLEFT", 4, -2); t.under:SetPoint("BOTTOMRIGHT", -4, -2)
    t:SetScript("OnClick", function() bar:Select(i) end)
    t:SetScript("OnEnter", function(self) if bar.active ~= i then W.TextColor(self.label, "bone") end end)
    t:SetScript("OnLeave", function(self) if bar.active ~= i then W.TextColor(self.label, "secondary") end end)
    bar.tabs[i] = t
    x = x + t:GetWidth() + 6
  end
  function bar:Select(i)
    self.active = i
    for j, t in ipairs(self.tabs) do
      t.under:SetShown(j == i)
      W.TextColor(t.label, j == i and "brassLight" or "secondary")
    end
    if onSelect then onSelect(i) end
  end
  return bar
end

-- =================== Scroll Bar ===================
function W.ScrollBar(scroll, onScrolled)
  local bar = CreateFrame("Button", nil, scroll:GetParent())
  bar:SetWidth(10)
  bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
  bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
  bar:SetFrameLevel(scroll:GetFrameLevel() + 6)
  bar:RegisterForClicks("LeftButtonUp")
  bar.track = W.Fill(bar, { 0, 0, 0, 0.35 }, "BACKGROUND")
  bar.track:SetPoint("TOP"); bar.track:SetPoint("BOTTOM"); bar.track:SetWidth(4)

  local thumb = CreateFrame("Button", nil, bar)
  thumb:SetWidth(6)
  thumb.tex = W.Fill(thumb, "buttonEdge", "ARTWORK")
  thumb.tex:SetAllPoints()
  bar.thumb = thumb

  local function child() return scroll:GetScrollChild() end
  local function maxOff()
    local c = child()
    return math.max(0, (c and c:GetHeight() or 0) - (scroll:GetHeight() or 0))
  end
  local function cursorY()
    local _, y = GetCursorPosition()
    return y / (bar:GetEffectiveScale() or 1)
  end

  function bar:Update()
    local viewH = scroll:GetHeight() or 0
    local m = maxOff()
    if m <= 1 or viewH <= 0 then self:Hide() return end
    self:Show()
    local total = viewH + m
    local th = math.max(20, viewH * viewH / total)
    local off = math.min(m, scroll:GetVerticalScroll() or 0)
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", bar, "TOP", 0, -(viewH - th) * (off / m))
    self.thumbTravel = viewH - th
  end

  function bar:SetOffset(v)
    v = math.max(0, math.min(maxOff(), v or 0))
    scroll:SetVerticalScroll(v)
    self:Update()
    if onScrolled then onScrolled() end
  end

  function bar:Scroll(delta)
    self:SetOffset((scroll:GetVerticalScroll() or 0) - delta)
  end

  bar:SetScript("OnClick", function(self)
    local y = cursorY()
    local top = thumb:GetTop() or 0
    local page = (scroll:GetHeight() or 0) * 0.9
    self:Scroll(y > top and page or -page)
  end)

  thumb:SetScript("OnMouseDown", function(self)
    self.startY, self.startOff = cursorY(), scroll:GetVerticalScroll() or 0
    self:SetScript("OnUpdate", function(me)
      local travel = bar.thumbTravel or 1
      if travel <= 0 then return end
      local dy = me.startY - cursorY()
      bar:SetOffset(me.startOff + dy * (maxOff() / travel))
    end)
  end)
  local function stop(self) self:SetScript("OnUpdate", nil) end
  thumb:SetScript("OnMouseUp", stop)
  thumb:SetScript("OnHide", stop)
  thumb:SetScript("OnEnter", function(self) W.SetColor(self.tex, "brassDark") end)
  thumb:SetScript("OnLeave", function(self) W.SetColor(self.tex, "buttonEdge") end)

  scroll:EnableMouseWheel(true)
  bar:EnableMouseWheel(true)
  bar:SetScript("OnMouseWheel", function(self, delta) self:Scroll(delta * (self.wheelStep or 40)) end)
  bar:Hide()
  return bar
end

-- =================== Inputs ===================
local function paintInput(b)
  local edge = b:HasFocus() and C.brassDark or b._over and C.brassDark or C.buttonEdge
  for _, e in ipairs(b.edges) do W.SetColor(e, edge) end
end

function W.Input(parent, width, opts)
  opts = opts or {}
  local b = CreateFrame("EditBox", nil, parent)
  b:SetSize(width or 120, opts.height or 22)
  b:SetAutoFocus(false)
  b:SetFontObject(T.Font[opts.font or "body"])
  b:SetTextColor(C.bone[1], C.bone[2], C.bone[3])
  b:SetJustifyH(opts.justify or "LEFT")
  b:SetTextInsets(6, 6, 0, 0)
  if opts.maxLetters then b:SetMaxLetters(opts.maxLetters) end
  b.bg = W.Fill(b, "well", "BACKGROUND"); b.bg:SetAllPoints()
  b.edges = frameEdges(b)
  b:SetScript("OnEditFocusGained", paintInput)
  b:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0); paintInput(self) end)
  b:SetScript("OnEnter", function(self) self._over = true; paintInput(self) end)
  b:SetScript("OnLeave", function(self) self._over = false; paintInput(self) end)
  b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  paintInput(b)
  return b
end

function W.Slider(parent, width)
  local s = CreateFrame("Slider", nil, parent)
  s:SetSize(width or 140, 16)
  s:SetOrientation("HORIZONTAL")
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouseWheel(false)
  s.track = W.Fill(s, "well", "BACKGROUND")
  s.track:SetPoint("LEFT"); s.track:SetPoint("RIGHT"); s.track:SetHeight(4)
  local top = W.Line(s, "ruleDark", "BORDER"); top:SetPoint("BOTTOMLEFT", s.track, "TOPLEFT"); top:SetPoint("BOTTOMRIGHT", s.track, "TOPRIGHT")
  local bot = W.Line(s, "ruleLight", "BORDER"); bot:SetPoint("TOPLEFT", s.track, "BOTTOMLEFT"); bot:SetPoint("TOPRIGHT", s.track, "BOTTOMRIGHT")
  s.thumb = s:CreateTexture(nil, "OVERLAY")
  s.thumb:SetColorTexture(C.brass[1], C.brass[2], C.brass[3], 1)
  s.thumb:SetSize(6, 14)
  s:SetThumbTexture(s.thumb)
  s.fill = W.Fill(s, "trailOn", "ARTWORK")
  s.fill:SetHeight(4)
  s.fill:SetPoint("LEFT", s.track, "LEFT")
  s.fill:SetPoint("RIGHT", s.thumb, "CENTER")
  s:SetScript("OnEnter", function(self) self.thumb:SetColorTexture(C.brassLight[1], C.brassLight[2], C.brassLight[3], 1) end)
  s:SetScript("OnLeave", function(self) self.thumb:SetColorTexture(C.brass[1], C.brass[2], C.brass[3], 1) end)
  return s
end

-- =================== Dialog ===================
local dialog

local function buildDialog()
  local f = CreateFrame("Frame", "MakersPathDialog", UIParent)
  f:SetSize(360, 160)
  f:SetPoint("CENTER", 0, 120)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:Hide()
  table.insert(UISpecialFrames, "MakersPathDialog")
  local page = W.Window(f)
  f.header = W.Header(page, "", function() f:Hide() end)
  W.MakeMovable(f, f.header)

  f.text = W.Text(page, "body", "secondary")
  f.text:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 14, -12)
  f.text:SetWordWrap(true)
  f.text:SetJustifyV("TOP")

  f.input = W.Input(page, 300)
  f.input:SetPoint("LEFT", page, "LEFT", 14, 0)
  f.input:SetPoint("RIGHT", page, "RIGHT", -14, 0)

  f.hint = W.Text(page, "small", "muted")
  f.hint:SetPoint("TOPLEFT", f.input, "BOTTOMLEFT", 0, -4)

  f.cancel = W.Button(page, "", function() f:Hide() end, { minWidth = 70 })
  f.cancel:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -10, 10)
  f.accept = W.Button(page, "", nil, { primary = true, minWidth = 70 })
  f.accept:SetPoint("RIGHT", f.cancel, "LEFT", -6, 0)

  local function accept()
    local cb = f.onAccept
    local text = f.input:IsShown() and f.input:GetText() or nil
    f:Hide()
    if cb then cb(text) end
  end
  f.accept:SetScript("OnClick", accept)
  f.input:SetScript("OnEnterPressed", function()
    if f.copyText then f:Hide() elseif f.accept:IsShown() then accept() end
  end)
  f.input:SetScript("OnEscapePressed", function() f:Hide() end)
  f.input:SetScript("OnTextChanged", function(self, user)
    if user and f.copyText then
      self:SetText(f.copyText)
      self:HighlightText()
    end
  end)
  f.input:SetScript("OnKeyDown", function(_, key)
    if f.copyText and key == "C" and IsControlKeyDown() and f.copiedHint then
      f.hint:SetText(f.copiedHint)
      W.TextColor(f.hint, "brass")
    end
  end)
  f.input:SetScript("OnMouseUp", function(self) if f.copyText then self:HighlightText() end end)
  f:SetScript("OnHide", function(self) self.onAccept = nil; self.copyText = nil; self.input:ClearFocus() end)
  return f
end

function W.Dialog(opts)
  dialog = dialog or buildDialog()
  local f = dialog
  f:Hide()
  f.header.title:SetText(opts.title or "")
  f.text:SetText(opts.text or "")
  f.onAccept = opts.onAccept
  f.copyText = opts.copy
  f.copiedHint = opts.copiedHint
  f:SetWidth(opts.width or 360)
  f.text:SetWidth((opts.width or 360) - S.pad * 2 - 28)

  local textH = math.ceil(f.text:GetStringHeight() or 14)
  if (opts.text or "") == "" then textH = 0 end
  local hasInput = opts.copy ~= nil or opts.input ~= nil
  f.input:SetShown(hasInput)
  f.hint:SetText(opts.hint or "")
  W.TextColor(f.hint, "muted")
  f.hint:SetShown(hasInput and (opts.hint or "") ~= "")
  local y = S.header + 12 + textH + (textH > 0 and 10 or 0)
  if hasInput then
    f.input:ClearAllPoints()
    f.input:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 14, -(12 + textH + (textH > 0 and 10 or 0)))
    f.input:SetPoint("RIGHT", f.input:GetParent(), "RIGHT", -14, 0)
    f.input:SetMaxLetters(opts.maxLetters or 0)
    f.input:SetText(opts.copy or opts.input or "")
    y = y + 22 + (f.hint:IsShown() and 20 or 8)
  end

  f.accept:SetShown(opts.accept ~= nil)
  if opts.accept then f.accept:SetText(opts.accept) end
  f.cancel:SetText(opts.cancel or CLOSE or "Close")
  f:SetHeight(y + 12 + 22 + 10 + S.pad * 2)
  f:Show()
  f:Raise()
  if hasInput then
    f.input:SetFocus()
    f.input:HighlightText()
  end
  return f
end

-- =================== Readiness ===================
function W.Pip(parent, size)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetSize(size or S.pip, size or S.pip)
  function t:SetState(kind, state) self:SetTexture(T.Pip(kind, state)) end
  return t
end

function W.PipRow(parent, size, gap)
  local f = CreateFrame("Frame", nil, parent)
  size, gap = size or S.pip, gap or 2
  f:SetSize(size * 4 + gap * 3, size)
  f.pips = {}
  for i, kind in ipairs(T.CHECKS) do
    local p = W.Pip(f, size)
    p:SetPoint("LEFT", (i - 1) * (size + gap), 0)
    p.kind = kind
    f.pips[i] = p
  end
  function f:Set(checks)
    for _, p in ipairs(self.pips) do p:SetState(p.kind, checks and checks[p.kind] or "U") end
  end
  return f
end

-- =================== Sockets ===================
function W.Socket(parent, size)
  size = size or S.socket
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)

  b.well = W.Fill(b, "well", "BACKGROUND")
  b.well:SetAllPoints()
  local sh1 = W.Line(b, { 0, 0, 0, 1 }, "BORDER"); sh1:SetPoint("TOPLEFT"); sh1:SetPoint("TOPRIGHT"); sh1:SetHeight(2)
  local sh2 = W.Line(b, { 0, 0, 0, 1 }, "BORDER", true, 2); sh2:SetPoint("TOPLEFT"); sh2:SetPoint("BOTTOMLEFT")
  local hl1 = W.Line(b, { 0.239, 0.196, 0.149, 1 }, "BORDER"); hl1:SetPoint("BOTTOMLEFT"); hl1:SetPoint("BOTTOMRIGHT")
  local hl2 = W.Line(b, { 0.239, 0.196, 0.149, 1 }, "BORDER", true); hl2:SetPoint("TOPRIGHT"); hl2:SetPoint("BOTTOMRIGHT")

  local inner = 3
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", inner + 1, -(inner + 1))
  b.icon:SetPoint("BOTTOMRIGHT", -(inner + 1), inner + 1)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  b.border = {}
  for i = 1, 4 do b.border[i] = W.Fill(b, { 1, 1, 1, 1 }, "OVERLAY", 1) end
  b.border[1]:SetPoint("TOPLEFT", inner, -inner); b.border[1]:SetPoint("TOPRIGHT", -inner, -inner); b.border[1]:SetHeight(1)
  b.border[2]:SetPoint("BOTTOMLEFT", inner, inner); b.border[2]:SetPoint("BOTTOMRIGHT", -inner, inner); b.border[2]:SetHeight(1)
  b.border[3]:SetPoint("TOPLEFT", inner, -inner); b.border[3]:SetPoint("BOTTOMLEFT", inner, inner); b.border[3]:SetWidth(1)
  b.border[4]:SetPoint("TOPRIGHT", -inner, -inner); b.border[4]:SetPoint("BOTTOMRIGHT", -inner, inner); b.border[4]:SetWidth(1)

  b.ring = {}
  for i = 1, 4 do b.ring[i] = W.Fill(b, "brass", "OVERLAY", 2) end
  b.ring[1]:SetPoint("TOPLEFT", -1, 1); b.ring[1]:SetPoint("TOPRIGHT", 1, 1); b.ring[1]:SetHeight(1)
  b.ring[2]:SetPoint("BOTTOMLEFT", -1, -1); b.ring[2]:SetPoint("BOTTOMRIGHT", 1, -1); b.ring[2]:SetHeight(1)
  b.ring[3]:SetPoint("TOPLEFT", -1, 1); b.ring[3]:SetPoint("BOTTOMLEFT", -1, -1); b.ring[3]:SetWidth(1)
  b.ring[4]:SetPoint("TOPRIGHT", 1, 1); b.ring[4]:SetPoint("BOTTOMRIGHT", 1, -1); b.ring[4]:SetWidth(1)

  b.craftMark = b:CreateTexture(nil, "OVERLAY", nil, 4)
  b.craftMark:SetSize(16, 16)
  b.levelMark = b:CreateTexture(nil, "OVERLAY", nil, 4)
  b.levelMark:SetTexture(Tex.markLevel)
  b.levelMark:SetSize(16, 16)

  b.bracket = {}
  local bc = { { "TOPLEFT", -6, 6, 0, 1, 0, 1 }, { "TOPRIGHT", 6, 6, 1, 0, 0, 1 },
               { "BOTTOMLEFT", -6, -6, 0, 1, 1, 0 }, { "BOTTOMRIGHT", 6, -6, 1, 0, 1, 0 } }
  for i, c in ipairs(bc) do
    local t = b:CreateTexture(nil, "OVERLAY", nil, 5)
    t:SetTexture(Tex.bracket)
    t:SetSize(14, 14)
    t:SetPoint(c[1], c[2], c[3])
    t:SetTexCoord(c[4], c[5], c[6], c[7])
    b.bracket[i] = t
  end

  function b:SetMarksSide(side)
    self.craftMark:ClearAllPoints(); self.levelMark:ClearAllPoints()
    self.craftMark:SetPoint("CENTER", self, "TOP" .. side, side == "RIGHT" and -1 or 1, -4)
    self.levelMark:SetPoint("CENTER", self, "BOTTOM" .. side, side == "RIGHT" and -1 or 1, 4)
  end
  b:SetMarksSide("RIGHT")

  function b:SetQualityColor(c, a)
    for _, t in ipairs(self.border) do t:SetColorTexture(c[1], c[2], c[3], a or 1) end
  end
  function b:SetHover(on)
    for _, t in ipairs(self.ring) do t:SetShown(on and true or false) end
  end
  function b:SetSelected(on)
    for _, t in ipairs(self.bracket) do t:SetShown(on and true or false) end
  end
  function b:SetMarks(craftPath, levelUnmet)
    if craftPath then self.craftMark:SetTexture(craftPath); self.craftMark:Show() else self.craftMark:Hide() end
    self.levelMark:SetShown(levelUnmet and true or false)
  end
  b:SetHover(false); b:SetSelected(false); b:SetMarks(nil, false)
  return b
end

function W.ItemIcon(parent, size)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(size, size)
  f.bg = W.Fill(f, "well", "BACKGROUND"); f.bg:SetAllPoints()
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetPoint("TOPLEFT", 1, -1); f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.edges = frameEdges(f)
  function f:Set(path, q)
    self.icon:SetTexture(path or Tex.question)
    for _, e in ipairs(self.edges) do W.SetColor(e, q or "buttonEdge") end
  end
  return f
end

-- =================== Tooltips ===================
function W.TipBegin(owner, anchor, minWidth)
  GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
  if GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(minWidth or 260) end
end

function W.TipHide()
  if GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(0) end
  GameTooltip:Hide()
end

function W.SimpleTooltip(owner, title, text)
  W.TipBegin(owner, "ANCHOR_RIGHT", text and 220 or 0)
  GameTooltip:AddLine(title, C.tipGold[1], C.tipGold[2], C.tipGold[3])
  if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
  GameTooltip:Show()
end

function W.TipCheck(kind, state, text)
  local c = state == "N" and C.amber or state == "U" and C.muted or C.secondary
  GameTooltip:AddLine(T.PipInline(kind, state, 14) .. "  " .. text, c[1], c[2], c[3], true)
end

function W.TipLine(text, color, wrap)
  local c = type(color) == "string" and C[color] or color or { 1, 1, 1 }
  GameTooltip:AddLine(text, c[1], c[2], c[3], wrap ~= false)
end

function W.TipFoot(text)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(text, C.tipGrey[1], C.tipGrey[2], C.tipGrey[3], true)
end
