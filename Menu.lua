-- The menu: Blizzard's portrait frame (as Your Legacy's window), with backdrop, colour, visible-UI and capture controls.
local _, ns = ...
local T, GS = ns.Theme, ns.GS
local C = T.C

local Menu = {}
ns.Menu = Menu

local WIDTH, HEIGHT = 300, 340
local PAD, TOP = 16, 34
local INNER = WIDTH - PAD * 2

local function Swatch(parent, key, label)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(30, 30)
	b.ring = T.Rounded(b, "Chip", "BACKGROUND", C.rule)
	b.sel = T.Rounded(b, "ChipEdge", "OVERLAY", C.head)
	b.sel:Hide()
	b.fill = b:CreateTexture(nil, "ARTWORK")
	b.fill:SetPoint("TOPLEFT", 3, -3)
	b.fill:SetPoint("BOTTOMRIGHT", -3, 3)
	T.Fill(b, "HIGHLIGHT", C.ink, 0.15)
	b.key = key
	if key == "custom" then
		local plus = T.Text(b, T.F.title, C.ink, "CENTER")
		plus:SetPoint("CENTER", 0, 1)
		plus:SetText("+")
	end
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(label)
		if key == "custom" then GameTooltip:AddLine("Click to pick a colour.", 1, 1, 1) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function()
		if key == "custom" then GS:PickCustom() else GS:SetColor(key, true) end
	end)
	return b
end

function Menu:Create()
	if self.frame then return self.frame end
	local f = CreateFrame("Frame", "GreenScreenMenu", UIParent)
	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("CENTER", 300, 0)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, "GreenScreenMenu") -- Escape closes it
	self.frame = f

	T.Fill(f, "BACKGROUND", C.paper, nil, -8)
	local border = T.NineSlice(f, "PortraitFrameTemplate", 40)
	local portrait = border:CreateTexture(nil, "OVERLAY", nil, 7)
	portrait:SetSize(44, 44)
	portrait:SetPoint("CENTER", border, "TOPLEFT", 25, -23)
	portrait:SetTexture(T.MEDIA .. "Icon")
	local title = T.Text(border, T.F.brand, C.head, "CENTER")
	title:SetPoint("TOP", 0, -5)
	title:SetPoint("LEFT", 60, 0)
	title:SetPoint("RIGHT", -60, 0)
	title:SetText("GreenScreen")
	local close = CreateFrame("Button", nil, border, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, 1)
	close:SetScript("OnClick", function() f:Hide() end)

	local y = -TOP - 14 -- clear of the portrait ring

	-- Backdrop
	local h1 = T.Heading(f, "Backdrop", INNER)
	h1:SetPoint("TOPLEFT", PAD, y)
	y = y - 30
	self.show = T.Checkbox(f, "Show backdrop", function(v) GS:SetShown(v) end)
	self.show:SetPoint("TOPLEFT", PAD, y)
	y = y - 30
	self.swatches = {}
	local x = PAD
	local list = {}
	for _, c in ipairs(GS.COLORS) do list[#list + 1] = { c.key, c.label } end
	list[#list + 1] = { "custom", "Custom" }
	for _, item in ipairs(list) do
		local s = Swatch(f, item[1], item[2])
		s:SetPoint("TOPLEFT", x, y)
		x = x + 32 + 6
		self.swatches[#self.swatches + 1] = s
	end
	y = y - 44

	-- Visible UI
	local h2 = T.Heading(f, "Visible UI", INNER)
	h2:SetPoint("TOPLEFT", PAD, y)
	y = y - 32
	self.mode = T.Segmented(f, {
		{ "all", "Everything", "Show all UI." },
		{ "minimap", "Minimap only", "Hide every other UI element, keep the minimap." },
		{ "window", "One window", "Then click the window to keep. Right-click cancels." },
	}, function(value)
		if value == "window" and GS:Mode() == "window" then value = "all" end
		GS:SetMode(value)
	end)
	self.mode:SetPoint("TOPLEFT", PAD, y)
	y = y - 30
	self.hint = T.Text(f, T.F.small, C.muted)
	self.hint:SetPoint("TOPLEFT", PAD, y)
	self.hint:SetWidth(INNER)
	self.hint:SetJustifyV("TOP")
	y = y - 40

	-- Capture
	local h3 = T.Heading(f, "Capture", INNER)
	h3:SetPoint("TOPLEFT", PAD, y)
	y = y - 32
	local shot = T.ActionButton(f, "Screenshot")
	shot:SetPoint("TOPLEFT", PAD, y)
	shot:SetScript("OnClick", function() GS:Shot() end)
	self.mm = T.Checkbox(f, "Minimap button", function(v) GS:Set("minimap", v) end)
	self.mm:SetPoint("LEFT", shot, "RIGHT", 14, 0)

	local foot = T.Text(f, T.F.small, C.muted, "CENTER")
	foot:SetPoint("BOTTOM", 0, 12)
	foot:SetText("/gs help for commands  ·  Esc closes")

	table.insert(GS.listeners, function() Menu:Refresh() end)
	f:SetScript("OnShow", function() Menu:Refresh() end)
	f:Hide()
	return f
end

function Menu:Refresh()
	if not (self.frame and self.frame:IsShown()) then return end
	self.show:SetChecked(GS:IsShown())
	self.mm:SetChecked(GS:Setting("minimap"))
	local current = GS:Color()
	for _, s in ipairs(self.swatches) do
		s.fill:SetColorTexture(GS:RGB(s.key))
		local on = s.key == current
		s.sel:SetShown(on)
		s.ring:SetVertexColor(T.unpack(on and C.head or C.rule))
	end
	self.mode:SetValue(GS:IsPicking() and "window" or GS:Mode())
	if GS:IsPicking() then
		self.hint:SetText("Click the window to keep. Right-click cancels.")
	elseif GS:Mode() == "all" then
		self.hint:SetText("Close this menu (Esc) or use Screenshot: the menu hides itself for the capture.")
	else
		self.hint:SetText("Other UI is faded out. Combat brings it back.")
	end
end

function Menu:Show()
	self:Create():Show()
end

function Menu:Toggle()
	local f = self:Create()
	f:SetShown(not f:IsShown())
end
