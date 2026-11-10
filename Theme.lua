-- GreenScreen's look: a trimmed copy of Your Legacy's design system (YourLegacy/UI/Theme.lua). Blizzard's portrait
-- frame, the client's Friz Quadrata, gold for headings, white for values. Every colour from T.C, every face from T.F.
local _, ns = ...

local T = {}
ns.Theme = T

local C = {
	paper = { 0.070, 0.050, 0.035, 1 }, paper2 = { 0.030, 0.024, 0.018, 0.72 }, paper3 = { 0.300, 0.230, 0.130, 0.45 },
	ink = { 1, 1, 1, 1 }, ink2 = { 0.860, 0.840, 0.800, 1 }, muted = { 0.640, 0.610, 0.560, 1 }, head = { 1, 0.820, 0, 1 },
	rule = { 0.330, 0.270, 0.190, 1 }, accent = { 1, 0.820, 0, 1 }, hover = { 1, 0.780, 0.300, 1 },
}
T.C = C

local function unpackC(c, a) return c[1], c[2], c[3], a or c[4] or 1 end
T.unpack = unpackC

T.MEDIA = "Interface\\AddOns\\GreenScreen\\media\\"
function T.Path(name) return T.MEDIA .. "ui\\" .. name end

local CLIENT_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local FONT_OBJECTS = { GreenScreenFontBrand = 12, GreenScreenFontTitle = 14, GreenScreenFontBody = 12, GreenScreenFontSmall = 11 }
for name, size in pairs(FONT_OBJECTS) do
	local f = CreateFont(name)
	f:SetFont(CLIENT_FONT, size, "")
	f:SetShadowOffset(1, -1)
	f:SetShadowColor(0, 0, 0, 1)
end
T.F = { brand = "GreenScreenFontBrand", title = "GreenScreenFontTitle", body = "GreenScreenFontBody", small = "GreenScreenFontSmall" }

function T.Tex(parent, name, layer, c, a)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(T.Path(name))
	if c then t:SetVertexColor(unpackC(c, a)) end
	return t
end

function T.Fill(parent, layer, c, a, sub)
	local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
	tex:SetColorTexture(unpackC(c, a))
	tex:SetAllPoints()
	return tex
end

local SLICE = { Chip = 4, ChipEdge = 4 }
function T.Rounded(parent, name, layer, c, a, sub)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
	t:SetTexture(T.Path(name))
	local m = SLICE[name]
	t:SetTextureSliceMargins(m, m, m, m)
	t:SetTextureSliceMode(0)
	t:SetAllPoints()
	if c then t:SetVertexColor(unpackC(c, a)) end
	return t
end

-- A Blizzard atlas when the client has it, else the addon's own texture.
function T.Atlas(tex, atlas, fallback)
	local ok, info = pcall(function() return C_Texture and C_Texture.GetAtlasInfo(atlas) end)
	if ok and info then
		tex:SetAtlas(atlas)
		return true
	end
	if fallback then tex:SetTexture(T.Path(fallback)) end
	return false
end

-- Blizzard's NineSlice border (PortraitFrameTemplate) on its own child frame above the content.
function T.NineSlice(parent, layout, levelOffset)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints()
	f:SetFrameLevel(parent:GetFrameLevel() + (levelOffset or 0))
	if NineSliceUtil and NineSliceUtil.ApplyLayoutByName then NineSliceUtil.ApplyLayoutByName(f, layout) end
	return f
end

function T.Rule(parent, layer)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetColorTexture(unpackC(C.rule))
	t:SetHeight(1)
	return t
end

function T.Text(parent, font, c, justify, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFontObject(font or T.F.body)
	fs:SetTextColor(unpackC(c or C.ink))
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

-- Section head: gold title over a 1px rule.
function T.Heading(parent, text, width)
	local h = CreateFrame("Frame", nil, parent)
	h:SetSize(width, 24)
	h.text = T.Text(h, T.F.title, C.head)
	h.text:SetPoint("TOPLEFT", 0, -2)
	h.text:SetText(text)
	h.line = T.Rule(h)
	h.line:SetPoint("BOTTOMLEFT", 0, 0)
	h.line:SetPoint("BOTTOMRIGHT", 0, 0)
	return h
end

-- Segmented control: options = { {value, label}, ... }; onSelect(value).
function T.Segmented(parent, options, onSelect, height)
	local s = CreateFrame("Frame", nil, parent)
	height = height or 26
	T.Rounded(s, "Chip", "BACKGROUND", C.paper)
	T.Rounded(s, "ChipEdge", "BORDER", C.rule)
	s.buttons = {}
	local x = 2
	for i, opt in ipairs(options) do
		local b = CreateFrame("Button", nil, s)
		b.value = opt[1]
		b.fill = T.Rounded(b, "Chip", "ARTWORK", C.paper3)
		b.fillEdge = T.Rounded(b, "ChipEdge", "OVERLAY", C.muted, 0.6)
		b.fill:Hide()
		b.fillEdge:Hide()
		T.Rounded(b, "Chip", "HIGHLIGHT", C.paper3, 0.6)
		b.Label = T.Text(b, T.F.small, C.ink2, "CENTER")
		b.Label:SetPoint("CENTER")
		b.Label:SetText(opt[2])
		local w = math.max(36, b.Label:GetStringWidth() + 20)
		b:SetSize(w, height - 4)
		b:SetPoint("TOPLEFT", s, "TOPLEFT", x, -2)
		b:SetScript("OnClick", function(self) if onSelect then onSelect(self.value) end end)
		if opt[3] then
			b:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
				GameTooltip:SetText(opt[2])
				GameTooltip:AddLine(opt[3], 1, 1, 1, true)
				GameTooltip:Show()
			end)
			b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end
		s.buttons[i] = b
		x = x + w
	end
	s:SetSize(x + 2, height)
	function s:SetValue(value)
		for _, b in ipairs(self.buttons) do
			local on = b.value == value
			b.fill:SetShown(on)
			b.fillEdge:SetShown(on)
			b.Label:SetTextColor(unpackC(on and C.head or C.ink2))
		end
		self.value = value
	end
	return s
end

-- Checkbox (Blizzard's checkbox-minimal) with a label to its right; onChange(checked).
function T.Checkbox(parent, label, onChange)
	local b = CreateFrame("Button", nil, parent)
	b.box = b:CreateTexture(nil, "ARTWORK")
	b.box:SetSize(22, 22)
	b.box:SetPoint("LEFT")
	if not T.Atlas(b.box, "checkbox-minimal", "Box") then b.box:SetVertexColor(unpackC(C.muted)) end
	b.tick = b:CreateTexture(nil, "OVERLAY")
	b.tick:SetAllPoints(b.box)
	if not T.Atlas(b.tick, "checkmark-minimal", "Check") then b.tick:SetVertexColor(unpackC(C.head)) end
	b.Label = T.Text(b, T.F.body, C.ink2)
	b.Label:SetPoint("LEFT", b.box, "RIGHT", 6, 0)
	b.Label:SetText(label)
	b:SetSize(b.Label:GetStringWidth() + 30, 24)
	T.Fill(b, "HIGHLIGHT", C.ink, 0.06)
	function b:SetChecked(v)
		self.checked = v and true or false
		self.tick:SetShown(self.checked)
	end
	b:SetScript("OnClick", function(self)
		self:SetChecked(not self.checked)
		if onChange then onChange(self.checked) end
	end)
	b:SetChecked(false)
	return b
end

-- Blizzard's red UIPanelButtonTemplate.
function T.ActionButton(parent, label)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetText(label)
	b:SetSize(math.max(96, b:GetFontString():GetStringWidth() + 36), 22)
	return b
end
