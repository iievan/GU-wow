-- GU-WOW by levan: the in-game panel for the GU-WOW ReShade effects. © 2026 levan, the author's licence (LICENSE-GUWOW.txt).
-- The settings travel to the shader as a strip of 55 cells, 4 by 4 pixels, in the top left corner of the screen.
-- The effect LegionGUBridge (LegionGUbylevan.fx) reads the strip after the interface is drawn and covers it
-- again, so it is not seen. Each colour channel is black or white, one bit. Cell 0 is black, cell 1 white, cell 2
-- magenta (the signature); each value 0..63 takes two cells, high bits first; the last two are the checksum.
-- Besides the settings the strip carries what only the game knows: the time of day, indoors, flying, photo mode.

local VERSION = "1.6.2-release"
local CELL = 4
local CELLS = 55

-- Russian on a Russian client, English elsewhere.
local RU = GetLocale() == "ruRU"
local function T(ru, en)
	return RU and ru or en
end

-- The author's own settings, the preset «Default», tuned in game on 2026-09-25.
local DEFAULTS = {
	master = true, fog = true, weather = true, wet = true, rays = true, night = true, eye = true,
	zones = true, autoQuality = false, targetFps = 45, orbit = false, hideNames = true, cinema = true, style = 0,
	fogThickness = 20, fogDistance = 100, mist = 58, mistDensity = 70, raysStrength = 100,
	nightDarkness = 95, nightDepth = 70, lightGlow = 95, caveDarkness = 75,
	sharpness = 40, grade = 95, vignette = 55, ao = 50,
	-- Heat haze and cinema HDR: 0 off, 50 the look of 1.5.4.
	hazeStrength = 50, hdrStrength = 50, grain = 55, bokeh = false, photoBlur = 50,
	-- 1.6.0: how much of the low mist stays seen from a height, and how defined the ray shafts are.
	mistHigh = 50, rayDefinition = 25,
}
-- The order of the values in the strip, the same as LEGIONGU_CTL_* in the shaders (after the flags).
local VALUES = { "fogThickness", "fogDistance", "mist", "raysStrength", "nightDarkness", "lightGlow",
	"caveDarkness", "sharpness", "grade", "vignette", "mistDensity" }
-- The values a share code carries, in this order.
local CODE_KEYS = { "fogThickness", "fogDistance", "mist", "mistDensity", "raysStrength", "nightDarkness", "nightDepth",
	"lightGlow", "caveDarkness", "sharpness", "grade", "vignette", "ao", "style" }
local CODE_FLAGS = { "fog", "rays", "night", "weather", "wet", "eye", "zones", "cinema" }
-- Since 1.5.4 a code (GUW2) carries these too; a GUW1 code leaves them as they are. GUW2 had heat haze and cinema
-- HDR as switches, GUW3 (1.5.8) carries their strengths; the two first bits of the switches stay unused.
local CODE_KEYS2 = { "grain", "photoBlur" }
local CODE_KEYS3 = { "grain", "photoBlur", "hazeStrength", "hdrStrength" }
local CODE_KEYS4 = { "grain", "photoBlur", "hazeStrength", "hdrStrength", "mistHigh", "rayDefinition" }
local CODE_FLAGS2 = { "heatHaze", "cinemaHdr", "bokeh" }
-- The look: what a style, a ready profile or a friend's code may change. The zones and the cinema bars are the
-- player's habits, not the look, so a preview leaves them alone.
local LOOK = { fog = true, rays = true, night = true, weather = true, wet = true, eye = true,
	hazeStrength = true, hdrStrength = true, grain = true, mistHigh = true, rayDefinition = true }
for _, k in ipairs(CODE_KEYS) do
	LOOK[k] = true
end
local MAX_PRESETS = 10

-- The ready presets of the main page: «Default» with a few values changed. English names on every client, as the
-- author named them. Styles: 1 warm, 2 cold, 3 film, 5 sunset, 6 fairy tale, 7 noir.
local BASE_PRESETS = {
	{ "Default", {} },
	-- Clear air and little mist keep the sky open; the night is dark, not black, the colour cold.
	{ "Starry Night", { fogThickness = 10, mist = 35, mistDensity = 50, nightDarkness = 85, nightDepth = 45, lightGlow = 100,
		grade = 100, vignette = 45, hdrStrength = 60, grain = 35, mistHigh = 30, style = 2 } },
	{ "Peaceful Morning", { fogThickness = 30, fogDistance = 90, mist = 85, mistDensity = 50, grade = 100, sharpness = 30,
		vignette = 30, ao = 45, hazeStrength = 25, hdrStrength = 35, grain = 25, mistHigh = 70, style = 1 } },
	{ "Cinema", { fogThickness = 40, fogDistance = 75, mist = 70, ao = 55, sharpness = 30, vignette = 65, hdrStrength = 70,
		grain = 65, style = 3 } },
	{ "Clear Day", { fogThickness = 5, mist = 25, mistDensity = 40, raysStrength = 85, nightDarkness = 75, nightDepth = 30,
		sharpness = 50, grade = 70, vignette = 20, hdrStrength = 30, grain = 0 } },
	{ "Golden Sunset", { fogThickness = 30, fogDistance = 90, mist = 60, grade = 100, vignette = 45, hazeStrength = 70,
		hdrStrength = 60, grain = 40, style = 5 } },
	{ "Fairy Forest", { fogThickness = 35, fogDistance = 85, mist = 100, mistDensity = 60, lightGlow = 100, nightDepth = 40,
		sharpness = 35, vignette = 40, hdrStrength = 40, grain = 20, style = 6 } },
	{ "Grim Storm", { fogThickness = 75, fogDistance = 45, mist = 100, mistDensity = 85, raysStrength = 60, nightDarkness = 100,
		nightDepth = 90, caveDarkness = 90, sharpness = 30, vignette = 65, hdrStrength = 60, grain = 60, mistHigh = 80, style = 2 } },
	{ "Noir", { fogThickness = 30, mist = 60, nightDepth = 80, sharpness = 45, vignette = 70, hdrStrength = 80, grain = 75,
		style = 7 } },
	-- The heavy parts off: the same that auto quality lightens, and the rays.
	{ "More FPS", { wet = false, eye = false, rays = false, mist = 0, ao = 0, sharpness = 0, hazeStrength = 0, grain = 0, mistHigh = 0 } },
}
for _, p in ipairs(BASE_PRESETS) do
	local full = {}
	for k in pairs(LOOK) do
		full[k] = DEFAULTS[k]
	end
	for k, v in pairs(p[2]) do
		full[k] = v
	end
	p[2] = full
end

local DB
-- A look tried on the page «Profiles and photo»: on screen until «Apply» or «Cancel», never saved by itself, so
-- experiments do not touch the player's own settings. Gone after /reload.
local preview, previewBase, previewStyle
local photo = false
local lowQuality = false
local zoneKind
local cells = {}
local widgets = {}

-- A small timer that works on every client (C_Timer is 6.0 and later).
local timers = CreateFrame("Frame")
local pending = {}
timers:SetScript("OnUpdate", function(self, dt)
	for i = #pending, 1, -1 do
		local p = pending[i]
		p.t = p.t - dt
		if p.t <= 0 then
			table.remove(pending, i)
			p.f()
		end
	end
end)
local function After(seconds, f)
	pending[#pending + 1] = { t = seconds, f = f }
end

-- The strip. No parent: it stays on screen with the interface hidden (Alt+Z), when the shader still needs it.
local strip = CreateFrame("Frame", "LegionGUStrip")
strip:SetFrameStrata("TOOLTIP")
strip:SetWidth(CELLS * CELL)
strip:SetHeight(CELL)
for i = 0, CELLS - 1 do
	local t = strip:CreateTexture(nil, "OVERLAY")
	t:SetWidth(CELL)
	t:SetHeight(CELL)
	t:SetPoint("TOPLEFT", strip, "TOPLEFT", i * CELL, 0)
	cells[i] = t
end

-- The first thing the interface draws each frame, in the lowest strata, under cell 0: REST starts the effects at the
-- first draw of the kind it watches for, and this makes that draw come before the chat and the rest of the
-- interface. Several kinds of drawing, so that one of them is the kind REST watches for.
local first = CreateFrame("Frame", "LegionGUFirst")
first:SetFrameStrata("BACKGROUND")
first:SetFrameLevel(0)
first:SetWidth(CELL)
first:SetHeight(CELL)
local function Bait(layer, file, blend)
	local t = first:CreateTexture(nil, layer)
	t:SetAllPoints(first)
	t:SetTexture(file)
	if blend then
		t:SetBlendMode(blend)
	end
	return t
end
Bait("BACKGROUND", "Interface\\Buttons\\WHITE8X8")
Bait("BORDER", "Interface\\Icons\\INV_Misc_QuestionMark")
Bait("ARTWORK", "Interface\\Buttons\\UI-Quickslot2")
Bait("OVERLAY", "Interface\\Buttons\\ButtonHilight-Square", "ADD")
local firstSolid = first:CreateTexture(nil, "OVERLAY")
firstSolid:SetAllPoints(first)
if firstSolid.SetColorTexture then
	firstSolid:SetColorTexture(0, 0, 0, 1)
else
	firstSolid:SetTexture(0, 0, 0, 1)
end
local firstText = first:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
firstText:SetPoint("TOPLEFT", first, "TOPLEFT", 0, 0)
firstText:SetText(".")

local function Colour(i, r, g, b)
	local t = cells[i]
	if t.SetColorTexture then
		t:SetColorTexture(r, g, b, 1)
	else
		t:SetTexture(r, g, b, 1)
	end
end

local function Bits(i, v)
	Colour(i, math.floor(v / 4) % 2, math.floor(v / 2) % 2, v % 2)
end

-- A value 0..63 in two cells, the high bits first.
local function Cell(i, v)
	Bits(i, math.floor(v / 8))
	Bits(i + 1, v % 8)
end

-- The height of the screen in real pixels, so one unit of the strip is one pixel.
local function ScreenHeight()
	if GetPhysicalScreenSize then
		local _, h = GetPhysicalScreenSize()
		if h and h > 0 then
			return h
		end
	end
	local res
	if GetCurrentResolution and GetScreenResolutions then
		local i = GetCurrentResolution()
		if i and i > 0 then
			res = select(i, GetScreenResolutions())
		end
	end
	res = res or GetCVar("gxWindowedResolution") or GetCVar("gxResolution")
	local h = res and tonumber(string.match(res, "%d+x(%d+)"))
	return h or 1080
end

local function Layout()
	local scale = 768 / ScreenHeight()
	for _, f in ipairs({ strip, first }) do
		f:SetScale(scale)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Atmosphere by zone: a light nudge of the player's own values by the kind of land (the world map area id).
-- ---------------------------------------------------------------------------------------------------------------

local KIND_MODS = {
	swamp = { mist = 1.3, mistDensity = 1.2, fogThickness = 1.15 },
	forest = { mist = 1.15 },
	desert = { fogThickness = 0.7, mist = 0.4 },
	snow = { fogThickness = 1.1, mist = 0.8 },
	fire = { fogThickness = 0.8, mist = 0.3 },
	city = { mist = 0.5 },
}
local ZONES = {
	-- swamps and marshes
	[141] = "swamp", [38] = "swamp", [40] = "swamp", [467] = "swamp",
	-- forests and jungles
	[1018] = "forest", [43] = "forest", [34] = "forest", [121] = "forest", [42] = "forest", [41] = "forest",
	[182] = "forest", [21] = "forest", [20] = "forest", [490] = "forest", [37] = "forest", [673] = "forest",
	[689] = "forest", [493] = "forest", [1024] = "forest",
	-- deserts, steppes and badlands
	[161] = "desert", [261] = "desert", [4] = "desert", [11] = "desert", [607] = "desert", [17] = "desert",
	[101] = "desert", [61] = "desert", [720] = "desert", [475] = "desert", [479] = "desert",
	-- snow
	[281] = "snow", [27] = "snow", [492] = "snow", [495] = "snow", [488] = "snow", [486] = "snow", [941] = "snow",
	[1017] = "snow",
	-- fire and fel
	[29] = "fire", [28] = "fire", [19] = "fire", [606] = "fire", [1021] = "fire", [1135] = "fire", [1171] = "fire",
	[473] = "fire", [465] = "fire",
	-- cities
	[321] = "city", [301] = "city", [341] = "city", [382] = "city", [362] = "city", [381] = "city", [480] = "city",
	[471] = "city", [481] = "city", [504] = "city", [1014] = "city",
}

local function UpdateZone()
	local id
	if WorldMapFrame and WorldMapFrame:IsShown() then
		return
	end
	if SetMapToCurrentZone and GetCurrentMapAreaID then
		SetMapToCurrentZone()
		id = GetCurrentMapAreaID()
	elseif C_Map and C_Map.GetBestMapForUnit then
		id = C_Map.GetBestMapForUnit("player")
	end
	zoneKind = id and ZONES[id] or nil
end

-- A value as the shader gets it: the player's, nudged by the zone, and off for the heavy parts in low quality.
local QUALITY_OFF = { ao = true, mist = true, sharpness = true }

-- A value on screen: the preview's while one is on, the player's own otherwise.
local function V(key)
	if preview and preview[key] ~= nil then
		return preview[key]
	end
	return DB[key]
end

local function Effective(key)
	local v = V(key)
	if DB.zones and zoneKind and KIND_MODS[zoneKind][key] then
		v = v * KIND_MODS[zoneKind][key]
	end
	if lowQuality and QUALITY_OFF[key] then
		v = 0
	end
	return math.max(0, math.min(100, v))
end

-- ---------------------------------------------------------------------------------------------------------------
-- The strip
-- ---------------------------------------------------------------------------------------------------------------

-- What only the game knows: 1 live, 2 indoors, 4 flying, 8 photo mode, 16 wet ground on, 32 world map open;
-- the time of day 0..63 for 0..24 h; the player's facing 0..63 for a full turn (0 north, counterclockwise).
local lastState, lastTime, lastFacing
local function GameState()
	local s = 1
	if IsIndoors and IsIndoors() then
		s = s + 2
	end
	if IsFlying and IsFlying() then
		s = s + 4
	end
	if photo then
		s = s + 8
	end
	if V("wet") and not lowQuality then
		s = s + 16
	end
	-- Only the fullscreen map: part of it is drawn before the effects start, and the night darkened it. The
	-- windowed map covers a piece of the screen, and the world around it keeps the effects.
	if WorldMapFrame and WorldMapFrame:IsShown() and not (WorldMapFrame_InWindowedMode and WorldMapFrame_InWindowedMode()) then
		s = s + 32
	end
	local h, m = GetGameTime()
	local f = GetPlayerFacing and GetPlayerFacing() or 0
	return s, math.floor(((h or 12) + (m or 0) / 60) * 63 / 24 + 0.5) % 64,
		math.floor((f or 0) * 63 / (2 * math.pi) + 0.5) % 64
end

local function Code(v)
	return math.floor(v * 63 / 100 + 0.5)
end

local function Paint()
	if not DB then
		return
	end
	Colour(0, 0, 0, 0)
	Colour(1, 1, 1, 1)
	Colour(2, 1, 0, 1)
	local flags = (DB.master and 1 or 0) + (V("fog") and 2 or 0) + (V("rays") and 4 or 0)
		+ (V("night") and 8 or 0) + (V("weather") and 16 or 0) + ((V("eye") and not lowQuality) and 32 or 0)
	Cell(3, flags)
	local sum = flags
	for i, key in ipairs(VALUES) do
		local v = Code(Effective(key))
		Cell(3 + 2 * i, v)
		sum = sum + v
	end
	local state, time, facing = GameState()
	lastState, lastTime, lastFacing = state, time, facing
	local hot = zoneKind == "desert" or zoneKind == "fire"
	local haze, hdr = V("hazeStrength") or 0, V("hdrStrength") or 0
	local switches = (haze > 0 and 1 or 0) + (hot and 2 or 0) + (hdr > 0 and 4 or 0) + (DB.bokeh and 8 or 0)
	local extra = { state, time, Code(V("nightDepth")), Code(Effective("ao")), (V("style") or 0) + (DB.cinema and 8 or 0),
		Code(V("grain") or 0), Code(DB.photoBlur or 35), switches, Code(haze), Code(hdr), facing,
		Code(V("mistHigh") or 0), Code(V("rayDefinition") or 0) }
	for i, v in ipairs(extra) do
		Cell(3 + 2 * (#VALUES + i), v)
		sum = sum + v
	end
	Cell(CELLS - 2, sum % 64)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Photo mode and the one-click screenshot
-- ---------------------------------------------------------------------------------------------------------------

local NAME_CVARS = { "UnitNameOwn", "UnitNameNPC", "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName",
	"nameplateShowFriends", "nameplateShowEnemies" }
local savedNames

local function Names(show)
	if show then
		if savedNames then
			for k, v in pairs(savedNames) do
				SetCVar(k, v)
			end
			savedNames = nil
		end
	elseif not savedNames then
		savedNames = {}
		for _, k in ipairs(NAME_CVARS) do
			local v = GetCVar(k)
			if v then
				savedNames[k] = v
				SetCVar(k, "0")
			end
		end
	end
end

-- The interface goes transparent, not hidden: UIParent:Hide and Show from an addon make Blizzard close every window
-- as addon code, and after that the game refuses keys, Esc too. Transparency closes nothing and taints nothing.
local function DropKeyboard()
	local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
	if focus then
		focus:ClearFocus()
	end
end

-- The options window opened from the Esc menu goes back to that menu when it hides: forgetting the way back closes
-- it alone, so an invisible window does not stay under the mouse.
local function CloseOptions()
	if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
		InterfaceOptionsFrame.lastFrame = nil
		HideUIPanel(InterfaceOptionsFrame)
	end
	StaticPopup_Hide("GUWOW_NEWS")
	StaticPopup_Hide("GUWOW_CONFIRM")
end

local function Photo(on)
	if on == photo then
		return
	end
	if on and InCombatLockdown() then
		print("|cffffd200GU-WOW:|r " .. T("фоторежим недоступен в бою.", "photo mode is not available in combat."))
		return
	end
	photo = on
	DropKeyboard()
	if on then
		CloseOptions()
		UIParent:SetAlpha(0)
		if DB.hideNames then
			Names(false)
		end
		if DB.orbit and MoveViewRightStart then
			MoveViewRightStart(0.03)
		end
	else
		if MoveViewRightStop then
			MoveViewRightStop()
		end
		Names(true)
		UIParent:SetAlpha(1)
	end
	Paint()
end

function GUWOW_TogglePhoto()
	Photo(not photo)
end

-- A clean shot: the interface and the strip hide for a moment (the shader keeps the last settings), the game takes
-- the screenshot, everything comes back.
function GUWOW_Screenshot()
	if InCombatLockdown() then
		Screenshot()
		return
	end
	local wasPhoto = photo
	if not wasPhoto then
		UIParent:SetAlpha(0)
	end
	-- The first-draw square goes too: with the strip gone nothing covers it, and it would stay on the shot.
	strip:Hide()
	first:Hide()
	After(0.15, function()
		Screenshot()
		After(0.3, function()
			strip:Show()
			first:Show()
			if not wasPhoto and not photo then
				UIParent:SetAlpha(1)
			end
		end)
	end)
end

-- Esc, Enter to chat and Alt+Z end photo mode: the Esc menu shows over the picture, chat is not typed blind.
GameMenuFrame:HookScript("OnShow", function()
	if photo then
		Photo(false)
	end
end)
hooksecurefunc("ChatEdit_ActivateChat", function()
	if photo then
		Photo(false)
	end
end)
UIParent:HookScript("OnShow", function()
	if photo then
		Photo(false)
	end
end)

BINDING_HEADER_GUWOW = "GU-WOW"
BINDING_NAME_GUWOW_PHOTO = T("Фоторежим (прячет интерфейс, размывает фон)", "Photo mode (hides the interface, blurs the background)")
BINDING_NAME_GUWOW_SHOT = T("Чистый снимок экрана", "Clean screenshot")

-- ---------------------------------------------------------------------------------------------------------------
-- Share codes: all the values in one line to paste into another player's panel.
-- ---------------------------------------------------------------------------------------------------------------

local function MakeCode()
	local parts = {}
	for _, k in ipairs(CODE_KEYS) do
		parts[#parts + 1] = tostring(math.floor((DB[k] or 0) + 0.5))
	end
	local f = 0
	for i, k in ipairs(CODE_FLAGS) do
		if DB[k] then
			f = f + 2 ^ (i - 1)
		end
	end
	parts[#parts + 1] = tostring(f)
	for _, k in ipairs(CODE_KEYS4) do
		parts[#parts + 1] = tostring(math.floor((DB[k] or 0) + 0.5))
	end
	parts[#parts + 1] = tostring(DB.bokeh and 4 or 0)
	return "GUW4:" .. table.concat(parts, ".")
end

-- The values a code carries, or nil when the line is not a GU-WOW code.
local function ParseCode(code)
	local ver, body = string.match(code or "", "GUW([1234]):([%d%.]+)")
	if not body then
		return nil
	end
	local nums = {}
	for n in string.gmatch(body, "%d+") do
		nums[#nums + 1] = tonumber(n)
	end
	local n1 = #CODE_KEYS + 1
	local keys2 = ver == "4" and CODE_KEYS4 or (ver == "3" and CODE_KEYS3 or CODE_KEYS2)
	if #nums ~= (ver == "1" and n1 or n1 + #keys2 + 1) then
		return nil
	end
	local t = {}
	for i, k in ipairs(CODE_KEYS) do
		t[k] = k == "style" and math.min(nums[i], 7) or math.min(nums[i], 100)
	end
	local f = nums[n1]
	for i, k in ipairs(CODE_FLAGS) do
		t[k] = math.floor(f / 2 ^ (i - 1)) % 2 == 1
	end
	if ver ~= "1" then
		for i, k in ipairs(keys2) do
			t[k] = math.min(nums[n1 + i], 100)
		end
		local f2 = nums[#nums]
		for i, k in ipairs(CODE_FLAGS2) do
			t[k] = math.floor(f2 / 2 ^ (i - 1)) % 2 == 1
		end
		-- A GUW2 switch becomes the strength of 1.5.4.
		if ver == "2" then
			t.hazeStrength = t.heatHaze and 50 or 0
			t.hdrStrength = t.cinemaHdr and 50 or 0
		end
		t.heatHaze, t.cinemaHdr = nil, nil
	end
	return t
end

-- ---------------------------------------------------------------------------------------------------------------
-- The panels: Interface > AddOns > GU-WOW, and its page «Profiles and photo»
-- ---------------------------------------------------------------------------------------------------------------

-- The widgets show what is on screen, a preview too. Setting a slider there is not a change by the player.
local refreshing = false
local function Refresh()
	refreshing = true
	for _, w in pairs(widgets) do
		w:Refresh()
	end
	refreshing = false
end

local function Say(text)
	print("|cffffd200GU-WOW:|r " .. text)
end

-- Yes or no before a change that replaces or deletes something. The action runs only on «Accept».
-- What is new, once after an update.
StaticPopupDialogs["GUWOW_NEWS"] = {
	text = T("GU-WOW обновлён до 1.6.2.\n\nПолзунок «Свет огней» управляет яркостью огней ночью по-настоящему: костры и фонари отвечают на него всей силой. Карта в окне не выключает эффекты, ночь остаётся вокруг окна карты.\n\nМеню: /gu или кнопка у миникарты.",
		"GU-WOW is updated to 1.6.2.\n\nThe light glow slider truly drives the fires at night: bonfires and lamps answer it with their full strength. The windowed map does not switch the effects off, the night stays around the map window.\n\nMenu: /gu or the minimap button."),
	button1 = OKAY or "OK",
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

StaticPopupDialogs["GUWOW_CONFIRM"] = {
	text = "%s",
	button1 = ACCEPT or "OK",
	button2 = CANCEL or "Cancel",
	OnAccept = function(self, data)
		if data then
			data()
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}
local function Confirm(text, onYes)
	local d = StaticPopup_Show("GUWOW_CONFIRM", text)
	if d then
		d.data = onYes
	end
end

-- A change in the panel during a preview tunes the preview: «Apply» saves it with the change, «Cancel» brings back
-- the player's own settings untouched.
local CancelPreview

-- Where a change goes: into the preview while one is on, into the player's settings otherwise.
local function Set(key, v)
	if preview and LOOK[key] then
		preview[key] = v
	else
		DB[key] = v
	end
	if widgets.base then
		widgets.base:Refresh()
	end
end

local function Header(parent, text, x, y)
	local h = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	h:SetPoint("TOPLEFT", x, y)
	h:SetText(text)
	return h
end

local checkCount = 0
local function Check(parent, key, label, x, y, onClick)
	checkCount = checkCount + 1
	local name = "LegionGUCheck" .. checkCount
	local c = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
	c:SetPoint("TOPLEFT", x, y)
	_G[name .. "Text"]:SetText(label)
	c:SetScript("OnClick", function(self)
		Set(key, self:GetChecked() and true or false)
		if onClick then
			onClick()
		end
		Paint()
	end)
	c.Refresh = function(self)
		self:SetChecked(V(key))
	end
	widgets[name] = c
	return c
end

local sliderCount = 0
local function Slider(parent, key, label, x, y, lo, hi)
	sliderCount = sliderCount + 1
	lo, hi = lo or 0, hi or 100
	local name = "LegionGUSlider" .. sliderCount
	local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	s:SetPoint("TOPLEFT", x, y)
	s:SetWidth(250)
	s:SetMinMaxValues(lo, hi)
	s:SetValueStep(1)
	if s.SetObeyStepOnDrag then
		s:SetObeyStepOnDrag(true)
	end
	_G[name .. "Low"]:SetText(tostring(lo))
	_G[name .. "High"]:SetText(tostring(hi))
	local text = _G[name .. "Text"]
	s:SetScript("OnValueChanged", function(self, v)
		v = math.floor(v + 0.5)
		text:SetText(label .. ": " .. v)
		if refreshing or not DB or V(key) == v then
			return
		end
		Set(key, v)
		Paint()
	end)
	s.Refresh = function(self)
		local v = V(key)
		self:SetValue(v)
		text:SetText(label .. ": " .. v)
	end
	widgets[name] = s
	return s
end

local function Button(parent, text, x, y, w, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetWidth(w)
	b:SetHeight(22)
	b:SetPoint("TOPLEFT", x, y)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

-- The preview bar at the top of the screen: what is being tried, «Apply» and «Cancel». It is part of the interface,
-- so photo mode and the clean screenshot hide it with the rest.
local bar = CreateFrame("Frame", "GUWOWPreviewBar", UIParent)
bar:SetFrameStrata("DIALOG")
-- Narrow and at the very top, between the target frame and the buffs at the default interface scale.
bar:SetWidth(400)
bar:SetHeight(34)
bar:SetPoint("TOP", UIParent, "TOP", 0, -4)
bar:Hide()
local barBack = bar:CreateTexture(nil, "BACKGROUND")
barBack:SetAllPoints(bar)
if barBack.SetColorTexture then
	barBack:SetColorTexture(0, 0, 0, 0.8)
else
	barBack:SetTexture(0, 0, 0, 0.8)
end
local barText = bar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
barText:SetPoint("LEFT", 10, 0)
barText:SetWidth(214)
barText:SetJustifyH("LEFT")

local function ShowBar()
	local what
	if previewBase and previewStyle then
		what = "«" .. previewBase .. "» + «" .. previewStyle .. "»"
	elseif previewBase then
		what = "«" .. previewBase .. "»"
	else
		what = "«" .. (previewStyle or "") .. "»"
	end
	barText:SetText(T("Предпросмотр: ", "Preview: ") .. what)
	bar:Show()
end

-- A ready profile or a code starts from the player's own settings; a style goes on top of what is on screen.
local function Preview(changes, base, styleName)
	if base or not preview then
		preview = {}
		for k in pairs(LOOK) do
			preview[k] = DB[k]
		end
		previewBase, previewStyle = base, nil
	end
	for k, v in pairs(changes) do
		if LOOK[k] then
			preview[k] = v
		end
	end
	if styleName then
		previewStyle = styleName
	end
	ShowBar()
	Refresh()
	Paint()
end

local function ApplyPreview()
	if not preview then
		return
	end
	for k in pairs(LOOK) do
		DB[k] = preview[k]
	end
	preview, previewBase, previewStyle = nil, nil, nil
	bar:Hide()
	Refresh()
	Paint()
	Say(T("новые настройки применены и сохранены.", "the new settings are applied and saved."))
end

CancelPreview = function()
	if not preview then
		return
	end
	preview, previewBase, previewStyle = nil, nil, nil
	bar:Hide()
	Refresh()
	Paint()
end

Button(bar, T("Применить", "Apply"), 230, -6, 84, ApplyPreview)
Button(bar, T("Отменить", "Cancel"), 318, -6, 76, function()
	CancelPreview()
	Say(T("предпросмотр отменён. На экране снова ваши настройки.", "preview cancelled. Your own settings are back on screen."))
end)

local panel = CreateFrame("Frame", "LegionGUPanel", UIParent)
panel.name = "GU-WOW"
panel:Hide()

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("GU-WOW " .. VERSION)
local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
sub:SetText(T("Всё, что видно в игре. Меняется сразу. Весь мод на клавише F11. Стили, свои пресеты и фото: «Профили и фото».",
	"Everything seen in the game. Changes apply at once. The whole mod toggles with F11. Styles, own presets, photo: «Profiles and photo»."))

-- The Blizzard options window is small and long labels did not fit. While a GU-WOW page is open the window
-- grows, and it comes back to the player's size when both pages hide. The check is deferred a moment: switching
-- between the two pages hides one and shows the other in either order. Plain frame sizing, nothing secure.
local optSize
local guPages = {}
local function GrowOptions()
	if InterfaceOptionsFrame and not optSize then
		optSize = { InterfaceOptionsFrame:GetWidth(), InterfaceOptionsFrame:GetHeight() }
		InterfaceOptionsFrame:SetWidth(math.max(optSize[1], 1020))
		InterfaceOptionsFrame:SetHeight(math.max(optSize[2], 706))
	end
end
local function ShrinkOptions()
	After(0.05, function()
		if not optSize then
			return
		end
		for _, f in ipairs(guPages) do
			if f:IsShown() then
				return
			end
		end
		InterfaceOptionsFrame:SetWidth(optSize[1])
		InterfaceOptionsFrame:SetHeight(optSize[2])
		optSize = nil
	end)
end

local L, R = 16, 470
Check(panel, "master", T("Включить GU-WOW", "Enable GU-WOW"), L, -60)

-- The presets: the arrows walk through the ready ones and the player's own and show each at once as a preview.
-- «Apply» on the bar at the top of the screen makes it the player's own, the sliders tune it before that. The name
-- shows while the settings are exactly a preset, «Свои настройки» after any change. «+» saves those as a numbered
-- user preset, «-» deletes the shown user preset; the ready ones stay.
local baseIndex = 1
local function FindPreset(name)
	for i, p in ipairs(DB.presets) do
		if p.name == name then
			return i
		end
	end
end
-- The preset the on-screen look is exactly equal to: its place among the ready ones and then the player's own,
-- and its name. Nothing when the look is the player's own mix.
local function MatchingPreset()
	for i, p in ipairs(BASE_PRESETS) do
		local same = true
		for k, v in pairs(p[2]) do
			if V(k) ~= v then
				same = false
				break
			end
		end
		if same then
			return i, p[1]
		end
	end
	for j, p in ipairs(DB and DB.presets or {}) do
		local t = ParseCode(p.code)
		if t then
			local same = true
			for k in pairs(LOOK) do
				if t[k] == nil or V(k) ~= t[k] then
					same = false
					break
				end
			end
			if same then
				return #BASE_PRESETS + j, p.name
			end
		end
	end
end
Header(panel, T("Пресет", "Preset"), R, -66)
local baseLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
baseLabel:SetPoint("TOPLEFT", R + 78, -66)
baseLabel:SetWidth(122)
baseLabel:SetHeight(12)
local function ShowBase(d)
	local total = #BASE_PRESETS + #(DB.presets or {})
	baseIndex = (baseIndex - 1 + d) % total + 1
	if baseIndex <= #BASE_PRESETS then
		Preview(BASE_PRESETS[baseIndex][2], BASE_PRESETS[baseIndex][1])
		return
	end
	local p = DB.presets[baseIndex - #BASE_PRESETS]
	local t = ParseCode(p.code)
	if t then
		Preview(t, p.name)
	else
		Say(T("пресет «", "the preset «") .. p.name .. T("» повреждён.", "» is damaged."))
	end
end
local function SaveShown()
	local _, name = MatchingPreset()
	if name then
		Say(T("это уже сохранённый пресет «", "this is already the preset «") .. name .. "».")
		return
	end
	if #DB.presets >= MAX_PRESETS then
		Say(T("пресетов уже 10. Удалите ненужный кнопкой «-» или на странице «Профили и фото».",
			"there are 10 presets already. Delete one with «-» or on the «Profiles and photo» page."))
		return
	end
	if preview then
		ApplyPreview()
	end
	local n = 1
	while FindPreset(T("Пользовательские #", "Custom #") .. n) do
		n = n + 1
	end
	local newName = T("Пользовательские #", "Custom #") .. n
	table.insert(DB.presets, { name = newName, code = MakeCode() })
	Refresh()
	Say(T("сохранено как пресет «", "saved as the preset «") .. newName .. "».")
end
local function DeleteShown()
	local i, name = MatchingPreset()
	if not i or i <= #BASE_PRESETS then
		Say(T("показан готовый пресет, удалить можно только пользовательский.",
			"a ready preset is shown; only a user preset can be deleted."))
		return
	end
	Confirm(T("Удалить пресет «", "Delete the preset «") .. name .. "»?", function()
		table.remove(DB.presets, i - #BASE_PRESETS)
		if preview then
			CancelPreview()
		else
			Refresh()
		end
		Say(T("пресет «", "preset «") .. name .. T("» удалён.", "» deleted."))
	end)
end
local function Tip(b, text)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, nil, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end
Tip(Button(panel, "<", R + 50, -61, 24, function() ShowBase(-1) end), T("Предыдущий пресет", "Previous preset"))
Tip(Button(panel, ">", R + 204, -61, 24, function() ShowBase(1) end), T("Следующий пресет", "Next preset"))
Tip(Button(panel, "+", R + 232, -61, 24, SaveShown),
	T("Сохранить настройки с экрана как пресет «Пользовательские #1» и дальше по номерам, всего до 10",
		"Save the on-screen settings as the preset «Custom #1» and up by number, 10 at most"))
Tip(Button(panel, "-", R + 260, -61, 24, DeleteShown),
	T("Удалить показанный пользовательский пресет. Готовые не удаляются",
		"Delete the shown user preset. The ready ones stay"))
widgets.base = { Refresh = function()
	local i, name = MatchingPreset()
	if i then
		baseIndex = i
	end
	baseLabel:SetText(name or T("Свои настройки", "Custom"))
end }

Header(panel, T("Атмосфера", "Atmosphere"), L, -94)
Check(panel, "fog", T("Туман", "Fog"), L, -108)
Slider(panel, "fogThickness", T("Густота тумана", "Fog density"), L + 6, -144)
Slider(panel, "fogDistance", T("Дальность тумана", "Fog distance"), L + 6, -182)
Slider(panel, "mist", T("Низовой туман", "Ground mist"), L + 6, -220)
Slider(panel, "mistDensity", T("Плотность низового тумана", "Ground mist thickness"), L + 6, -258)
Slider(panel, "mistHigh", T("Туман с высоты: с гор и в полёте", "Mist from a height: hills and flight"), L + 6, -296)
Check(panel, "weather", T("Погодное настроение", "Weather mood"), L, -318)
Check(panel, "wet", T("Мокрая земля в дождь", "Wet ground in rain"), L, -341)
Check(panel, "rays", T("Лучи солнца", "Sun rays"), L, -364)
Slider(panel, "raysStrength", T("Сила лучей", "Ray strength"), L + 6, -400)
Slider(panel, "rayDefinition", T("Чёткость лучей: от свечения до снопов", "Ray definition: a glow or shafts"), L + 6, -438)
Slider(panel, "ao", T("Тени в щелях", "Contact shadows"), L + 6, -476)
Slider(panel, "hazeStrength", T("Марево в пустынях и огненных землях", "Heat haze in deserts and fire lands"), L + 6, -514)

Header(panel, T("Ночь", "Night"), R, -94)
Check(panel, "night", T("Ночь и огни", "Night and lights"), R, -110)
Slider(panel, "nightDarkness", T("Темнота ночи", "Night darkness"), R + 6, -150)
Slider(panel, "nightDepth", T("Глубина ночи", "Night depth"), R + 6, -192)
Slider(panel, "lightGlow", T("Свет огней", "Light glow"), R + 6, -234)
Slider(panel, "caveDarkness", T("Темнота подземелий", "Dungeon darkness"), R + 6, -276)

Header(panel, T("Картинка", "Picture"), R, -306)
Check(panel, "eye", T("Привыкание глаз", "Eye adaptation"), R, -322)
Slider(panel, "sharpness", T("Резкость", "Sharpness"), R + 6, -360)
Slider(panel, "grade", T("Цвет по времени суток", "Time of day colour"), R + 6, -400)
Slider(panel, "vignette", T("Виньетка", "Vignette"), R + 6, -440)
Slider(panel, "hdrStrength", T("Кино-HDR: глубже тени, мягче блики", "Cinema HDR: deeper shadows, softer highlights"), R + 6, -480)
Slider(panel, "grain", T("Плёночное зерно", "Film grain"), R + 6, -520)

panel:SetScript("OnShow", function()
	GrowOptions()
	Refresh()
end)
panel:SetScript("OnHide", ShrinkOptions)
panel.okay = function() end
panel.cancel = function() end
panel.default = function()
	preview, previewBase, previewStyle = nil, nil, nil
	bar:Hide()
	for k, v in pairs(DEFAULTS) do
		DB[k] = v
	end
	Refresh()
	Paint()
end
panel.refresh = Refresh

-- The author's settings in one click, after a question. Blizzard's «Defaults» at the bottom of the window can also
-- reset the whole game interface, this button only GU-WOW.
local authorButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
authorButton:SetWidth(160)
authorButton:SetHeight(22)
authorButton:SetPoint("TOPRIGHT", -16, -16)
authorButton:SetText(T("Настройки автора", "Author's settings"))
authorButton:SetScript("OnClick", function()
	Confirm(T("Вернуть настройки автора? Ваши нынешние заменятся. Пресеты останутся.", "Restore the author's settings? Your current ones are replaced. Presets stay."), function()
		panel.default()
		Say(T("настройки автора вернулись.", "the author's settings are back."))
	end)
end)

-- The second page.
local page = CreateFrame("Frame", "LegionGUPanel2", UIParent)
page.name = T("Профили и фото", "Profiles and photo")
page.parent = panel.name
page:Hide()
local title2 = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title2:SetPoint("TOPLEFT", 16, -16)
title2:SetText("GU-WOW: " .. page.name)

local sub2 = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub2:SetPoint("TOPLEFT", title2, "BOTTOMLEFT", 0, -6)
sub2:SetWidth(590)
sub2:SetJustifyH("LEFT")
sub2:SetText(T("Стили и коды сначала только показываются. Сохраняет их кнопка «Применить». Готовые пресеты на главной странице.",
	"Styles and codes are only shown at first. «Apply» saves them. The ready presets are on the main page."))

Header(page, T("Цветовой стиль", "Colour style"), 16, -62)
local STYLE_NAMES = { T("Нет", "None"), T("Тёплый", "Warm"), T("Холодный", "Cold"), T("Плёнка", "Film"), T("Сочный", "Vivid"),
	T("Закат", "Sunset"), T("Сказка", "Fairy tale"), T("Нуар", "Noir") }
local styleButtons = {}
for i, n in ipairs(STYLE_NAMES) do
	styleButtons[i] = Button(page, n, 16 + (i - 1) * 73, -80, 70, function()
		Preview({ style = i - 1 }, nil, n)
	end)
end
widgets.styles = { Refresh = function()
	for i, b in ipairs(styleButtons) do
		if (V("style") or 0) == i - 1 then
			b:LockHighlight()
		else
			b:UnlockHighlight()
		end
	end
end }

Header(page, T("Код настройки: поделиться или вставить чужой", "Settings code: share yours or paste another"), 16, -116)
local codeBox = CreateFrame("EditBox", "LegionGUCodeBox", page, "InputBoxTemplate")
codeBox:SetPoint("TOPLEFT", 22, -136)
codeBox:SetWidth(460)
codeBox:SetHeight(20)
codeBox:SetAutoFocus(false)
codeBox:SetMaxLetters(200)
codeBox:SetScript("OnEnterPressed", codeBox.ClearFocus)
codeBox:SetScript("OnEscapePressed", codeBox.ClearFocus)
codeBox:SetScript("OnHide", codeBox.ClearFocus)
Button(page, T("Мой код", "My code"), 16, -162, 140, function()
	codeBox:SetText(MakeCode())
	codeBox:HighlightText()
	codeBox:SetFocus()
end)
Button(page, T("Попробовать код", "Try the code"), 162, -162, 140, function()
	local t = ParseCode(codeBox:GetText())
	if t then
		Preview(t, T("код настройки", "settings code"))
	else
		Say(T("это не код GU-WOW.", "this is not a GU-WOW code."))
	end
end)

-- My presets: up to ten named sets of the player's own settings. The arrows walk through them, the box holds the
-- name to save under, load or delete. Loading, deleting and overwriting ask first.
local presetHeader = Header(page, "", L, -198)
local presetIndex = 0
local nameBox = CreateFrame("EditBox", "LegionGUPresetName", page, "InputBoxTemplate")
nameBox:SetPoint("TOPLEFT", L + 40, -216)
nameBox:SetWidth(146)
nameBox:SetHeight(22)
nameBox:SetAutoFocus(false)
nameBox:SetMaxLetters(24)
nameBox:SetScript("OnEnterPressed", nameBox.ClearFocus)
nameBox:SetScript("OnEscapePressed", nameBox.ClearFocus)
-- A hidden box that keeps the focus keeps the whole keyboard, Esc too: it lets go when the menu closes.
nameBox:SetScript("OnHide", nameBox.ClearFocus)

local function ShowPreset(i)
	presetIndex = i
	local p = DB.presets[i]
	nameBox:SetText(p and p.name or "")
	presetHeader:SetText(T("Мои пресеты", "My presets") .. " (" .. #DB.presets .. T(" из ", " of ") .. MAX_PRESETS .. ")")
end
-- A refresh keeps a name the player has typed; only the arrows, saving and deleting put a preset's name in the box.
widgets.presets = { Refresh = function()
	local typed = nameBox:GetText() or ""
	ShowPreset(math.min(math.max(presetIndex, #DB.presets > 0 and 1 or 0), #DB.presets))
	if typed ~= "" then
		nameBox:SetText(typed)
	end
end }

-- The name in the box without the characters that would break the chat line or the colour codes.
local function PresetName()
	return (string.gsub(string.gsub(nameBox:GetText() or "", "|", ""), "^%s*(.-)%s*$", "%1"))
end

local function Step(d)
	local n = #DB.presets
	if n > 0 then
		ShowPreset((presetIndex - 1 + d) % n + 1)
	end
end
Button(page, "<", L, -216, 30, function() nameBox:ClearFocus() Step(-1) end)
Button(page, ">", L + 192, -216, 30, function() nameBox:ClearFocus() Step(1) end)

Button(page, T("Сохранить", "Save"), L + 228, -216, 110, function()
	nameBox:ClearFocus()
	-- A preset keeps the player's own settings; during a preview the screen shows something else.
	if preview then
		Say(T("идёт предпросмотр. Нажмите «Применить» или «Отменить», потом сохраните пресет.",
			"a preview is on. Press «Apply» or «Cancel», then save the preset."))
		return
	end
	local name = PresetName()
	if name == "" then
		local n = #DB.presets + 1
		while FindPreset(T("Пресет ", "Preset ") .. n) do
			n = n + 1
		end
		name = T("Пресет ", "Preset ") .. n
	end
	local i = FindPreset(name)
	if i then
		Confirm(T("Перезаписать пресет «", "Overwrite the preset «") .. name .. T("» текущими настройками?", "» with the current settings?"), function()
			DB.presets[i].code = MakeCode()
			ShowPreset(i)
			Say(T("пресет «", "preset «") .. name .. T("» перезаписан.", "» overwritten."))
		end)
	elseif #DB.presets >= MAX_PRESETS then
		Say(T("пресетов уже 10. Удалите ненужный, чтобы сохранить новый.", "there are 10 presets already. Delete one to save a new one."))
	else
		table.insert(DB.presets, { name = name, code = MakeCode() })
		ShowPreset(#DB.presets)
		Say(T("пресет «", "preset «") .. name .. T("» сохранён.", "» saved."))
	end
end)

Button(page, T("Загрузить", "Load"), L + 344, -216, 110, function()
	nameBox:ClearFocus()
	local name = PresetName()
	local i = FindPreset(name)
	if not i then
		Say(T("пресета с таким названием нет.", "there is no preset with this name."))
		return
	end
	Confirm(T("Загрузить пресет «", "Load the preset «") .. name .. T("»? Текущие настройки заменятся.", "»? It replaces the current settings."), function()
		local t = ParseCode(DB.presets[i].code)
		if not t then
			Say(T("пресет повреждён.", "the preset is damaged."))
			return
		end
		preview, previewBase, previewStyle = nil, nil, nil
		bar:Hide()
		for k, v in pairs(t) do
			DB[k] = v
		end
		UpdateZone()
		presetIndex = i
		Refresh()
		Paint()
		Say(T("пресет «", "preset «") .. name .. T("» загружен.", "» loaded."))
	end)
end)

Button(page, T("Удалить", "Delete"), L + 460, -216, 110, function()
	nameBox:ClearFocus()
	local name = PresetName()
	local i = FindPreset(name)
	if not i then
		Say(T("пресета с таким названием нет.", "there is no preset with this name."))
		return
	end
	Confirm(T("Удалить пресет «", "Delete the preset «") .. name .. "»?", function()
		table.remove(DB.presets, i)
		ShowPreset(math.min(i, #DB.presets))
		Say(T("пресет «", "preset «") .. name .. T("» удалён.", "» deleted."))
	end)
end)

-- Photo: only what works in photo mode and on the clean screenshot.
Header(page, T("Фото", "Photo"), 16, -252)
Check(page, "orbit", T("Медленный облёт камеры", "Slow camera orbit"), 16, -270)
Check(page, "hideNames", T("Прятать имена над головами", "Hide names above heads"), 16, -296)
Check(page, "cinema", T("Кинорамка", "Cinema bars"), 16, -322)
Check(page, "bokeh", T("Боке огней на размытом фоне", "Bokeh of lights in the blur"), 16, -348)
Slider(page, "photoBlur", T("Сила размытия", "Blur strength"), 336, -346)
Button(page, T("Фоторежим", "Photo mode"), 330, -274, 150, GUWOW_TogglePhoto)
Button(page, T("Чистый снимок", "Clean screenshot"), 330, -302, 150, GUWOW_Screenshot)

Header(page, T("Производительность и поведение", "Performance and behaviour"), 16, -386)
Check(page, "autoQuality", T("Автокачество: упрощать тяжёлое при низких кадрах", "Auto quality: lighten heavy effects at low FPS"), 16, -404)
Check(page, "zones", T("Атмосфера по зонам", "Atmosphere by zone"), 16, -430, function()
	UpdateZone()
end)
Slider(page, "targetFps", T("Держать кадров не ниже", "Keep FPS at least"), 330, -408, 20, 120)

page:SetScript("OnShow", function()
	GrowOptions()
	Refresh()
end)
page:SetScript("OnHide", ShrinkOptions)
page.refresh = Refresh
guPages[1], guPages[2] = panel, page

local category
if InterfaceOptions_AddCategory then
	InterfaceOptions_AddCategory(panel)
	InterfaceOptions_AddCategory(page)
elseif Settings and Settings.RegisterCanvasLayoutCategory then
	category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	Settings.RegisterAddOnCategory(category)
end

local function OpenPanel()
	if category then
		Settings.OpenToCategory(category:GetID())
		return
	end
	-- Called twice: the first call on a fresh session opens the list without the panel.
	InterfaceOptionsFrame_OpenToCategory(panel)
	InterfaceOptionsFrame_OpenToCategory(panel)
end

SLASH_LEGIONGU1 = "/gu"
SLASH_LEGIONGU2 = "/guwow"
SlashCmdList["LEGIONGU"] = function(msg)
	msg = string.lower(msg or "")
	if msg == "photo" or msg == "фото" then
		GUWOW_TogglePhoto()
	elseif msg == "shot" or msg == "снимок" then
		GUWOW_Screenshot()
	else
		OpenPanel()
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- The minimap button: left click the menu, right click the whole mod on or off, middle click or Shift+left photo.
-- ---------------------------------------------------------------------------------------------------------------

local mm = CreateFrame("Button", "GUWOWMinimapButton", Minimap)
mm:SetWidth(31)
mm:SetHeight(31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
mm:RegisterForDrag("LeftButton")
local mmIcon = mm:CreateTexture(nil, "BACKGROUND")
mmIcon:SetTexture("Interface\\Icons\\Spell_Nature_Starfall")
mmIcon:SetWidth(20)
mmIcon:SetHeight(20)
mmIcon:SetPoint("CENTER", 0, 1)
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetWidth(53)
mmBorder:SetHeight(53)
mmBorder:SetPoint("TOPLEFT")
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local function PlaceMinimapButton()
	local a = math.rad(DB.minimapAngle or 200)
	mm:ClearAllPoints()
	mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
end

mm:SetScript("OnDragStart", function(self)
	self:SetScript("OnUpdate", function()
		local mx, my = Minimap:GetCenter()
		local cx, cy = GetCursorPosition()
		local s = Minimap:GetEffectiveScale()
		DB.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
		PlaceMinimapButton()
	end)
end)
mm:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
end)
mm:SetScript("OnClick", function(self, button)
	if button == "RightButton" then
		DB.master = not DB.master
		Refresh()
		Paint()
		print("|cffffd200GU-WOW:|r " .. (DB.master and T("включён", "on") or T("выключен", "off")))
	elseif button == "MiddleButton" or IsShiftKeyDown() then
		GUWOW_TogglePhoto()
	else
		OpenPanel()
	end
end)
mm:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("GU-WOW " .. VERSION)
	GameTooltip:AddLine(T("Левая кнопка: меню", "Left click: menu"), 1, 1, 1)
	GameTooltip:AddLine(T("Правая кнопка: включить или выключить", "Right click: on or off"), 1, 1, 1)
	GameTooltip:AddLine(T("Shift + левая или средняя: фоторежим", "Shift + left or middle click: photo mode"), 1, 1, 1)
	GameTooltip:Show()
end)
mm:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

-- ---------------------------------------------------------------------------------------------------------------
-- The clock, indoors, flight and the frame rate change on their own: look four times a second.
-- ---------------------------------------------------------------------------------------------------------------

local ticker = CreateFrame("Frame")
local elapsed, slowFor, fastFor = 0, 0, 0
ticker:SetScript("OnUpdate", function(self, dt)
	elapsed = elapsed + dt
	if elapsed < 0.25 or not DB then
		return
	end
	local step = elapsed
	elapsed = 0
	-- Auto quality: below the target for 3 seconds lightens the heavy parts, 10 above it for 5 seconds brings them back.
	local changed = false
	if DB.autoQuality then
		local fps = GetFramerate()
		if fps < DB.targetFps then
			slowFor, fastFor = slowFor + step, 0
		elseif fps > DB.targetFps + 10 then
			fastFor, slowFor = fastFor + step, 0
		else
			slowFor, fastFor = 0, 0
		end
		if not lowQuality and slowFor >= 3 then
			lowQuality, changed = true, true
		elseif lowQuality and fastFor >= 5 then
			lowQuality, changed = false, true
		end
	elseif lowQuality then
		lowQuality, changed = false, true
	end
	local s, t, f = GameState()
	if changed or s ~= lastState or t ~= lastTime or f ~= lastFacing then
		Paint()
	end
end)

-- The world map switches the effects off at once, not at the next look of the ticker.
if WorldMapFrame then
	WorldMapFrame:HookScript("OnShow", function() Paint() end)
	WorldMapFrame:HookScript("OnHide", function()
		UpdateZone()
		Paint()
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= "LegionGU" then
			return
		end
		LegionGUDB = LegionGUDB or {}
		DB = LegionGUDB
		-- The switches of 1.5.4 to 1.5.6 become strengths: on is the look of 1.5.4.
		if DB.hazeStrength == nil and DB.heatHaze ~= nil then
			DB.hazeStrength = DB.heatHaze and 50 or 0
		end
		if DB.hdrStrength == nil and DB.cinemaHdr ~= nil then
			DB.hdrStrength = DB.cinemaHdr and 50 or 0
		end
		DB.heatHaze, DB.cinemaHdr = nil, nil
		for k, v in pairs(DEFAULTS) do
			if DB[k] == nil then
				DB[k] = v
			end
		end
		-- The three slots of 1.5.0 become the first presets, so nothing saved in them is lost.
		DB.presets = DB.presets or {}
		if DB.slots then
			for slot = 1, 3 do
				if DB.slots[slot] and #DB.presets < MAX_PRESETS then
					table.insert(DB.presets, { name = T("Слот ", "Slot ") .. slot, code = DB.slots[slot] })
				end
			end
			DB.slots = nil
		end
		PlaceMinimapButton()
	end
	if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		UpdateZone()
	end
	if event == "PLAYER_ENTERING_WORLD" and DB.newsSeen ~= VERSION then
		DB.newsSeen = VERSION
		After(6, function()
			StaticPopup_Show("GUWOW_NEWS")
		end)
	end
	Layout()
	Paint()
end)
