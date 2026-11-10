-- GreenScreen: a solid backdrop that covers the 3D world so only the UI is visible, plus "visible UI" modes that
-- fade out every other top-level window (everything / minimap only / one picked window).
local addonName, ns = ...

local GS = { listeners = {} }
ns.GS = GS

BINDING_HEADER_GREENSCREEN = "GreenScreen"
BINDING_NAME_GREENSCREEN_MENU = "Open menu"
BINDING_NAME_GREENSCREEN_TOGGLE = "Toggle backdrop"
BINDING_NAME_GREENSCREEN_ISOLATE = "Show only the window under the mouse"
BINDING_NAME_GREENSCREEN_MINIMAP = "Show only the minimap"
BINDING_NAME_GREENSCREEN_CYCLE = "Next colour"
BINDING_NAME_GREENSCREEN_SHOT = "Take screenshot"

-- Standard chroma-key values plus plain backgrounds.
GS.COLORS = {
	{ key = "green",   label = "Green",   r = 0,   g = 177/255, b = 64/255  },
	{ key = "blue",    label = "Blue",    r = 0,   g = 71/255,  b = 187/255 },
	{ key = "magenta", label = "Magenta", r = 1,   g = 0,       b = 1       },
	{ key = "black",   label = "Black",   r = 0,   g = 0,       b = 0       },
	{ key = "white",   label = "White",   r = 1,   g = 1,       b = 1       },
	{ key = "grey",    label = "Grey",    r = 0.5, g = 0.5,     b = 0.5     },
}
local BY_KEY = {}
for i, c in ipairs(GS.COLORS) do BY_KEY[c.key] = i end
BY_KEY.gray = BY_KEY.grey

local DEFAULTS = { color = "green", custom = { r = 0, g = 1, b = 0 }, shown = false, minimap = true, minimapAngle = 200, minimapIcon = {} }

local db
local function say(msg) print("|cff00b140GreenScreen|r: " .. msg) end
GS.say = say

-- Anything showing state (the menu) registers here and is told when it changes.
function GS:Changed()
	for _, fn in ipairs(self.listeners) do fn() end
end

---------------------------------------------------------------- backdrop
-- Lowest strata/level under UIParent: every UI frame draws above it, the 3D world below. Mouse passes through.
local screen = CreateFrame("Frame", "GreenScreenBackdrop", UIParent)
screen:SetFrameStrata("BACKGROUND")
screen:SetFrameLevel(0)
screen:SetAllPoints(UIParent)
screen:EnableMouse(false)
screen:Hide()
local tex = screen:CreateTexture(nil, "BACKGROUND")
tex:SetAllPoints()
GS.screen = screen

function GS:RGB(key)
	key = key or db.color
	if key == "custom" then return db.custom.r, db.custom.g, db.custom.b end
	local c = self.COLORS[BY_KEY[key] or 1]
	return c.r, c.g, c.b
end

function GS:Apply()
	tex:SetColorTexture(self:RGB())
	screen:SetShown(db.shown)
	self:Changed()
end

function GS:IsShown() return db.shown end
function GS:Color() return db.color end
function GS:SetShown(v) db.shown = v and true or false; self:Apply() end
function GS:ToggleBackdrop() self:SetShown(not db.shown) end

function GS:SetColor(key, quiet)
	if key == "gray" then key = "grey" end
	db.color = key
	db.shown = true
	self:Apply()
	if not quiet then say("colour " .. key) end
end

function GS:SetCustom(r, g, b)
	db.custom = { r = r, g = g, b = b }
	self:SetColor("custom", true)
end

function GS:Cycle()
	local i = (BY_KEY[db.color] or 0) % #self.COLORS + 1
	self:SetColor(self.COLORS[i].key)
end

function GS:PickCustom()
	local r, g, b = self:RGB()
	local prevColor = db.color
	if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then
		say("colour picker not available; use /gs custom <r> <g> <b> (0-255)")
		return
	end
	ColorPickerFrame:SetupColorPickerAndShow({
		r = r, g = g, b = b, hasOpacity = false,
		swatchFunc = function()
			local nr, ng, nb = ColorPickerFrame:GetColorRGB()
			GS:SetCustom(nr, ng, nb)
		end,
		cancelFunc = function(prev)
			if prev then db.custom = { r = prev.r, g = prev.g, b = prev.b } end
			db.color = prevColor
			GS:Apply()
		end,
	})
end

---------------------------------------------------------------- visible UI
-- mode: "all", "minimap" or "window". Other top-level UIParent children fade to alpha 0 and get their alpha back
-- afterwards. The backdrop and the menu always stay.
local mode, faded = "all", nil
function GS:Mode() return mode end

local function TopLevel(f)
	while f and f:GetParent() and f:GetParent() ~= UIParent do
		f = f:GetParent()
		if f:IsForbidden() then return nil end
	end
	if f and f:GetParent() == UIParent then return f end
end
GS.TopLevel = TopLevel

function GS:IsExempt(f) return f == screen or (ns.Menu and f == ns.Menu.frame) end

local function Restore()
	if not faded then return end
	for f, a in pairs(faded) do
		if not f:IsForbidden() then f:SetAlpha(a) end
	end
	faded = nil
end

local function FadeAllBut(keep)
	Restore()
	faded = {}
	for _, f in ipairs({ UIParent:GetChildren() }) do
		if f ~= keep and not GS:IsExempt(f) and not f:IsForbidden() and f:IsShown() then
			faded[f] = f:GetAlpha()
			f:SetAlpha(0)
		end
	end
end

function GS:SetMode(newMode, target)
	self:CancelPick()
	if newMode ~= "all" and InCombatLockdown() then say("not in combat") return end
	if newMode == "all" then
		Restore()
	elseif newMode == "minimap" then
		local keep = Minimap and TopLevel(Minimap)
		if not keep then say("minimap not found") return end
		FadeAllBut(keep)
	elseif newMode == "window" then
		if not target then return self:StartPick() end
		FadeAllBut(target)
		say("showing only " .. (target:GetName() or "the picked window"))
	end
	mode = newMode
	if newMode ~= "all" then db.shown = true end
	self:Apply()
end

-- The window under the mouse right now (keybind / slash use): no pick step.
function GS:IsolateUnderMouse()
	if mode == "window" then return self:SetMode("all") end
	local target = self:UnderMouse()
	if not target then say("point the mouse at a window first") return end
	self:SetMode("window", target)
end

function GS:UnderMouse()
	for _, f in ipairs(GetMouseFoci and GetMouseFoci() or {}) do
		if f and f ~= WorldFrame and f ~= UIParent and not f:IsForbidden() then
			local top = TopLevel(f)
			if top and not self:IsExempt(top) then return top end
		end
	end
end

---------------------------------------------------------------- pick mode
-- After "One window" in the menu: a gold outline follows the window under the mouse; a left-click picks it,
-- a right-click cancels.
local picker = CreateFrame("Frame", nil, UIParent)
picker:SetFrameStrata("TOOLTIP")
picker:EnableMouse(false)
picker:Hide()
for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
	local t = picker:CreateTexture(nil, "OVERLAY")
	t:SetColorTexture(1, 0.82, 0, 1)
	t:SetPoint(side[1])
	t:SetPoint(side[2])
	if side[3] then t:SetHeight(2) else t:SetWidth(2) end
end
local pickWatcher = CreateFrame("Frame")
pickWatcher:Hide()
pickWatcher:SetScript("OnUpdate", function()
	local f = GS:UnderMouse()
	if f then
		picker:ClearAllPoints()
		picker:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2)
		picker:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
		picker:Show()
	else
		picker:Hide()
	end
end)
pickWatcher:SetScript("OnEvent", function(_, _, button)
	if button == "RightButton" then
		GS:CancelPick()
		say("pick cancelled")
		GS:Changed()
	elseif button == "LeftButton" then
		local f = GS:UnderMouse()
		if f then GS:SetMode("window", f) end
	end
end)

function GS:IsPicking() return pickWatcher:IsShown() end

function GS:StartPick()
	if InCombatLockdown() then say("not in combat") return end
	pickWatcher:Show()
	pickWatcher:RegisterEvent("GLOBAL_MOUSE_DOWN")
	say("click the window to keep (right-click cancels)")
	self:Changed()
end

function GS:CancelPick()
	pickWatcher:Hide()
	pickWatcher:UnregisterEvent("GLOBAL_MOUSE_DOWN")
	picker:Hide()
end

---------------------------------------------------------------- screenshot
-- Hides the menu for the capture and brings it back afterwards.
local shotFrame = CreateFrame("Frame")
local menuWasShown
shotFrame:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	if menuWasShown and ns.Menu then ns.Menu:Show() end
	menuWasShown = nil
end)

function GS:Shot()
	menuWasShown = ns.Menu and ns.Menu.frame and ns.Menu.frame:IsShown()
	if menuWasShown then ns.Menu.frame:Hide() end
	shotFrame:RegisterEvent("SCREENSHOT_SUCCEEDED")
	shotFrame:RegisterEvent("SCREENSHOT_FAILED")
	C_Timer.After(0.05, Screenshot) -- a moment so the menu has left the screen
end

---------------------------------------------------------------- settings used by the minimap button and menu
function GS:Setting(key) return db[key] end
function GS:Set(key, value)
	db[key] = value
	if key == "minimap" and ns.MinimapButton then ns.MinimapButton:Update() end
	self:Changed()
end
function GS:DB() return db end

---------------------------------------------------------------- entry points
function GreenScreen_Menu() if ns.Menu then ns.Menu:Toggle() end end
function GreenScreen_Toggle() GS:ToggleBackdrop() end
function GreenScreen_Isolate() GS:IsolateUnderMouse() end
function GreenScreen_MinimapOnly() GS:SetMode(GS:Mode() == "minimap" and "all" or "minimap") end
function GreenScreen_Cycle() GS:Cycle() end
function GreenScreen_Shot() GS:Shot() end

function GreenScreen_OnAddonCompartmentClick(_, button)
	if button == "RightButton" then GS:ToggleBackdrop() else GreenScreen_Menu() end
end

local HELP = {
	"/gs - open the menu",
	"/gs bg - toggle the backdrop (also: on, off)",
	"/gs green | blue | magenta | black | white | grey - set colour",
	"/gs custom - colour picker;  /gs custom <r> <g> <b> - exact 0-255 values",
	"/gs next - cycle colours",
	"/gs minimap - show only the minimap (again for everything)",
	"/gs isolate - show only the window under the mouse (again for everything)",
	"/gs all - show all UI again",
	"/gs shot - take a screenshot",
	"Keybinds: Options > Keybindings > AddOns > GreenScreen",
}

SLASH_GREENSCREEN1 = "/gs"
SLASH_GREENSCREEN2 = "/greenscreen"
SlashCmdList.GREENSCREEN = function(msg)
	local cmd, rest = strtrim(msg or ""):lower():match("^(%S*)%s*(.-)$")
	if cmd == "" or cmd == "menu" then GreenScreen_Menu()
	elseif cmd == "bg" or cmd == "toggle" then GS:ToggleBackdrop()
	elseif cmd == "on" then GS:SetShown(true)
	elseif cmd == "off" then GS:SetShown(false)
	elseif BY_KEY[cmd] then GS:SetColor(cmd)
	elseif cmd == "custom" then
		local r, g, b = rest:match("^(%d+)%s+(%d+)%s+(%d+)$")
		if r then
			GS:SetCustom(math.min(tonumber(r), 255) / 255, math.min(tonumber(g), 255) / 255, math.min(tonumber(b), 255) / 255)
		else
			GS:PickCustom()
		end
	elseif cmd == "next" then GS:Cycle()
	elseif cmd == "minimap" then GreenScreen_MinimapOnly()
	elseif cmd == "isolate" then GS:IsolateUnderMouse()
	elseif cmd == "all" then GS:SetMode("all")
	elseif cmd == "shot" then GS:Shot()
	else
		for _, line in ipairs(HELP) do say(line) end
	end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		GreenScreenDB = GreenScreenDB or {}
		db = GreenScreenDB
		for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
		GS:Apply()
		if ns.MinimapButton then ns.MinimapButton:Create() end
	elseif event == "PLAYER_REGEN_DISABLED" and (mode ~= "all" or GS:IsPicking()) then
		-- entering combat: the player gets their UI back
		GS:SetMode("all")
		say("combat: all UI back")
	end
end)
