-- Minimap button, as in Your Legacy (YourLegacy/UI/Minimap.lua): a LibDBIcon button when another addon has loaded
-- LibDataBroker + LibDBIcon (so button bins can collect it), else our own button dragged around the rim.
local _, ns = ...
local T, GS = ns.Theme, ns.GS

local MB = {}
ns.MinimapButton = MB

local ICON = T.MEDIA .. "Icon"

local function Tooltip(tooltip)
	tooltip:AddLine("GreenScreen", 1, 1, 1)
	tooltip:AddLine("Backdrop: " .. (GS:IsShown() and GS:Color() or "off"), T.unpack(T.C.head))
	tooltip:AddLine("Left-click: menu. Right-click: backdrop on/off.", T.unpack(T.C.muted))
end

local function Click(_, button)
	if button == "RightButton" then GS:ToggleBackdrop() else ns.Menu:Toggle() end
end

local function Library(name)
	local stub = _G.LibStub
	return type(stub) == "table" and stub.GetLibrary and stub:GetLibrary(name, true) or nil
end

local function Place(button)
	local angle = math.rad(tonumber(GS:Setting("minimapAngle")) or 200)
	local radius = (Minimap:GetWidth() / 2) + 6
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OwnButton()
	local b = CreateFrame("Button", "GreenScreenMinimapButton", Minimap)
	b:SetSize(32, 32)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON)
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER")
	local ring = T.Tex(b, "MinimapRing", "BACKGROUND")
	ring:SetAllPoints()
	local hl = T.Tex(b, "MinimapRing", "HIGHLIGHT", T.C.ink, 0.35)
	hl:SetAllPoints()
	hl:SetBlendMode("ADD")
	b:SetScript("OnClick", Click)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		Tooltip(GameTooltip)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnDragStart", function(self)
		if self:GetParent() ~= Minimap then return end
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			GS:DB().minimapAngle = math.floor(math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360 + 0.5)
			Place(self)
		end)
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	Place(b)
	return b
end

function MB:Create()
	if self.button or self.icon or not Minimap then return end
	local ldb = Library("LibDataBroker-1.1")
	if ldb and not self.broker then
		self.broker = ldb:NewDataObject("GreenScreen", {
			type = "launcher", label = "GreenScreen", icon = ICON, OnClick = Click, OnTooltipShow = Tooltip,
		})
	end
	local dbicon = Library("LibDBIcon-1.0")
	if dbicon and self.broker then
		self.icon = dbicon
		dbicon:Register("GreenScreen", self.broker, GS:DB().minimapIcon)
	else
		self.button = OwnButton()
	end
	self:Update()
end

function MB:Update()
	local show = GS:Setting("minimap") and true or false
	if self.icon then
		GS:DB().minimapIcon.hide = not show
		if show then self.icon:Show("GreenScreen") else self.icon:Hide("GreenScreen") end
	elseif self.button then
		self.button:SetShown(show)
	end
end
