-- GU-WOW by levan: the in-game panel for the GU-WOW ReShade effects. © 2026 levan, the author's licence (LICENSE-GUWOW.txt).
-- The settings travel to the shader as a strip of 89 cells, 4 by 4 pixels, in the top left corner of the screen.
-- The effect LegionGUBridge (LegionGUbylevan.fx) reads the strip after the interface is drawn and covers it
-- again, so it is not seen. Each colour channel is black or white, one bit. Cell 0 is black, cell 1 white, cell 2
-- magenta (the signature); each value 0..63 takes two cells, high bits first; the last two are the checksum.
-- Besides the settings the strip carries what only the game knows: the time of day, indoors, flying, photo mode.

local VERSION = "public-release-beta-1.1"
local CELL = 4
local CELLS = 89

-- Russian on a Russian client, English elsewhere.
local RU = GetLocale() == "ruRU"
local function T(ru, en)
	return RU and ru or en
end

-- The standard settings, the preset «Levan Soft»: the owner's own look, neutral and soft, taken from the live
-- Legion game on 2026-09-28 evening. The same on every client.
local DEFAULTS = {
	master = true, fog = true, weather = true, wet = true, rays = true, night = true, eye = true,
	zones = true, autoQuality = false, targetFps = 45, orbit = false, hideNames = true, cinema = true, style = 0,
	chatBack = true,
	fogThickness = 27, fogDistance = 100, mist = 30, mistDensity = 40, raysStrength = 80,
	nightDarkness = 25, nightDepth = 41, lightGlow = 50, caveDarkness = 6,
	sharpness = 15, grade = 75, vignette = 55, ao = 75,
	-- Heat haze and cinema HDR: 0 off, 50 the look of 1.5.4.
	hazeStrength = 24, hdrStrength = 50, grain = 29, bokeh = false, photoBlur = 30,
	-- 1.6.0: how much of the low mist stays seen from a height, and how defined the ray shafts are.
	mistHigh = 80, rayDefinition = 20,
	-- 1.6.7: the drift of the mist; the shader caps it at 40 (beta-1.0).
	mistFlow = 10,
	-- 1.7.0: brightness and colour, 50 is the game's own picture.
	bright = 60, contrast = 40, satur = 50, warmth = 50,
	-- 1.7.1: the rays' own dials. In the open the old fixed cut was 22; 45 makes a field twice as sunlit.
	raysOpen = 70, raysReach = 60, sunGlow = 60,
	-- 1.7.1: the mist at the feet, ankle-deep in swamps. 0 keeps it off.
	mistNear = 0,
	-- 1.7.3: which objects glow at night and how far (50 is the old look), and the motion blur (0 off). These are
	-- the player's own taste for the screen, like the dials above: a code and a ready preset leave them alone.
	lightThreshold = 50, lightRadius = 50, motionBlur = 0,
	-- 1.7.3: the far land softly blurred in normal play, the photo mode lens at its own strength (0 off).
	playBlur = 0,
	-- 1.7.3: a panel shows whole under the mouse and the fight panels in a fight (see PanelAlpha).
	panelWake = true,
	-- 1.7.6: the look of the play photo mode: plain play (false) or the photo blur and the cinema bars (true).
	gamePhoto = false,
}
-- 1.7.3: how much of each panel shows, 100 whole, 0 gone: ui_ in plain play, photo_ in photo mode, game_ in the
-- play photo mode (1.7.6), where only the chat stays by default.
for _, k in ipairs({ "bars", "player", "target", "party", "minimap", "chat", "buffs", "quests", "castbar" }) do
	DEFAULTS["ui_" .. k], DEFAULTS["photo_" .. k], DEFAULTS["game_" .. k] = 100, 0, k == "chat" and 100 or 0
end
-- The order of the values in the strip, the same as LEGIONGU_CTL_* in the shaders (after the flags).
local VALUES = { "fogThickness", "fogDistance", "mist", "raysStrength", "nightDarkness", "lightGlow",
	"caveDarkness", "sharpness", "grade", "vignette", "mistDensity" }
-- The values a share code carries, in this order.
local CODE_KEYS = { "fogThickness", "fogDistance", "mist", "mistDensity", "raysStrength", "nightDarkness", "nightDepth",
	"lightGlow", "caveDarkness", "sharpness", "grade", "vignette", "ao", "style" }
local CODE_FLAGS = { "fog", "rays", "night", "weather", "wet", "eye", "zones", "cinema" }
-- Since 1.5.4 a code (GUW2) carries these too; keys a code's version does not carry come out as the defaults
-- (see ParseCode). GUW2 had heat haze and cinema HDR as switches, GUW3 (1.5.8) carries their strengths; the two
-- first bits of the switches stay unused.
local CODE_KEYS2 = { "grain", "photoBlur" }
local CODE_KEYS3 = { "grain", "photoBlur", "hazeStrength", "hdrStrength" }
local CODE_KEYS4 = { "grain", "photoBlur", "hazeStrength", "hdrStrength", "mistHigh", "rayDefinition" }
local CODE_KEYS5 = { "grain", "photoBlur", "hazeStrength", "hdrStrength", "mistHigh", "rayDefinition", "mistFlow" }
-- GUW6 (1.7.0) carries the brightness-and-colour dials too; an older code leaves them at the defaults.
local CODE_KEYS6 = { "grain", "photoBlur", "hazeStrength", "hdrStrength", "mistHigh", "rayDefinition", "mistFlow",
	"bright", "contrast", "satur", "warmth" }
-- GUW7 (1.7.1) carries the rays' dials too; GUW8 the mist at the feet.
local CODE_KEYS7 = { "grain", "photoBlur", "hazeStrength", "hdrStrength", "mistHigh", "rayDefinition", "mistFlow",
	"bright", "contrast", "satur", "warmth", "raysOpen", "raysReach", "sunGlow" }
local CODE_KEYS8 = { "grain", "photoBlur", "hazeStrength", "hdrStrength", "mistHigh", "rayDefinition", "mistFlow",
	"bright", "contrast", "satur", "warmth", "raysOpen", "raysReach", "sunGlow", "mistNear" }
local CODE_FLAGS2 = { "heatHaze", "cinemaHdr", "bokeh" }
-- The look: what a style, a ready profile or a friend's code may change. The zones and the cinema bars are the
-- player's habits, not the look, so a preview leaves them alone.
local LOOK = { fog = true, rays = true, night = true, weather = true, wet = true, eye = true,
	hazeStrength = true, hdrStrength = true, grain = true, mistHigh = true, rayDefinition = true, mistFlow = true,
	bright = true, contrast = true, satur = true, warmth = true,
	raysOpen = true, raysReach = true, sunGlow = true, mistNear = true }
-- The personal tuning dials: the picture (1.7.0) and the rays (1.7.1). They are part of the look (a code and a
-- user preset carry them), but the ready atmosphere presets leave them alone: «Golden Sunset» is about the air,
-- not the player's screen or their rays taste.
local TUNE = { bright = true, contrast = true, satur = true, warmth = true,
	raysOpen = true, raysReach = true, sunGlow = true }
for _, k in ipairs(CODE_KEYS) do
	LOOK[k] = true
end
local MAX_PRESETS = 10

-- The ready presets of the main page: «Levan Soft» (the standard settings) with a few values changed. English names
-- on every client, as the author named them. Styles: 1 warm, 2 cold, 3 film, 4 vivid, 5 sunset, 6 fairy tale, 7 noir.
local BASE_PRESETS = {
	{ "Levan Soft", {} },
	-- The standard look of beta-1.0 and 1.7.x: thick mist, deep night, strong light round the lamps.
	{ "Deep Atmosphere", { fogThickness = 10, mist = 70, mistDensity = 45, raysStrength = 100, nightDarkness = 80,
		nightDepth = 70, lightGlow = 100, caveDarkness = 75, sharpness = 25, grade = 80, ao = 90, hazeStrength = 30,
		hdrStrength = 15, grain = 10, mistHigh = 40, rayDefinition = 55, mistNear = 25 } },
	-- Bright colours and crisp edges for questing by day; little mist, a light night.
	{ "Vivid Adventure", { fogThickness = 10, mist = 20, mistDensity = 35, nightDarkness = 20, nightDepth = 25,
		sharpness = 45, grade = 90, vignette = 30, hdrStrength = 40, grain = 0, style = 4 } },
	-- Moonlit night: the dark is blue, the lamps glow softly.
	{ "Moonlight", { fogThickness = 20, mist = 45, mistDensity = 45, nightDarkness = 60, nightDepth = 55, lightGlow = 80,
		grade = 90, vignette = 50, hdrStrength = 45, grain = 20, mistHigh = 60, style = 2 } },
	-- Low mist over the ground, soft light, a quiet dawn look.
	{ "Misty Dawn", { fogThickness = 45, fogDistance = 80, mist = 90, mistDensity = 65, raysStrength = 90, grade = 85,
		sharpness = 10, vignette = 35, hazeStrength = 20, hdrStrength = 30, grain = 15, mistHigh = 90, mistNear = 30, style = 1 } },
	-- The picture close to the game's own: the effects on, but light.
	{ "Pure Game", { fogThickness = 5, mist = 10, mistDensity = 30, raysStrength = 50, nightDarkness = 10, nightDepth = 10,
		lightGlow = 30, caveDarkness = 0, sharpness = 10, grade = 40, vignette = 15, ao = 40, hazeStrength = 0,
		hdrStrength = 0, grain = 0, mistHigh = 20, mistNear = 0, style = 0 } },
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
	-- 1.7.3: three more looks. Cold clear air with a blue night; warm lamps in a dark night; a soft picture with
	-- no sharpening and no grain, like a painting.
	{ "Northern Frost", { fogThickness = 20, fogDistance = 90, mist = 55, mistDensity = 45, nightDarkness = 45, grade = 80,
		sharpness = 25, vignette = 40, hdrStrength = 45, grain = 15, mistHigh = 60, style = 2 } },
	{ "Warm Night Lamps", { nightDarkness = 55, nightDepth = 50, lightGlow = 100, caveDarkness = 30, grade = 90,
		vignette = 55, hdrStrength = 50, grain = 25, style = 1 } },
	{ "Soft Watercolor", { fogThickness = 35, fogDistance = 85, mist = 50, mistDensity = 35, sharpness = 0, grade = 70,
		vignette = 25, hdrStrength = 20, grain = 0, style = 6 } },
}
for _, p in ipairs(BASE_PRESETS) do
	local full = {}
	for k in pairs(LOOK) do
		if not TUNE[k] then
			full[k] = DEFAULTS[k]
		end
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
-- The play photo mode (1.7.6): only the panels hide, to the player's own dials, and the game goes on, in a fight
-- too. The map, Esc and the chat leave it on.
local game = false
-- The depth check view (/gu check): the shaders draw the depth instead of the picture, bit 16 of the switches.
local checkView = false
local lowQuality = false
local zoneKind
local cells = {}
local widgets = {}
-- Declared here: the mod key (GUWOW_ToggleMod) and the photo mode above the menu call it.
local Refresh

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

-- The second row of the strip carries the interface for the effects to leave alone (see PaintUI): a signature,
-- UI_RECTS rectangles of four coordinates 0..511 in three cells each, a checksum of two cells. 972 pixels long.
local UI_RECTS = 20
local UI_CELLS = 1 + UI_RECTS * 12 + 2
local uiCells = {}

-- The strip. No parent: it stays on screen with the interface hidden (Alt+Z), when the shader still needs it.
local strip = CreateFrame("Frame", "LegionGUStrip")
strip:SetFrameStrata("TOOLTIP")
strip:SetWidth(UI_CELLS * CELL)
strip:SetHeight(2 * CELL)
local function StripCell(row, i)
	local t = strip:CreateTexture(nil, "OVERLAY")
	t:SetWidth(CELL)
	t:SetHeight(CELL)
	t:SetPoint("TOPLEFT", strip, "TOPLEFT", i * CELL, -row * CELL)
	return t
end
for i = 0, CELLS - 1 do
	cells[i] = StripCell(0, i)
end
for i = 0, UI_CELLS - 1 do
	uiCells[i] = StripCell(1, i)
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

local function Tint(t, r, g, b)
	if t.SetColorTexture then
		t:SetColorTexture(r, g, b, 1)
	else
		t:SetTexture(r, g, b, 1)
	end
end

local function Colour(i, r, g, b)
	Tint(cells[i], r, g, b)
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
	-- Direct3D 9 (WotLK 3.3.5 and older): a cell of 3 units, read by the shader as BUFFER_HEIGHT / 256 pixels. A
	-- maximized window is shorter than the resolution, and a strip scaled to the resolution was not read there.
	local major = tonumber(string.match(GetBuildInfo() or "", "^(%d+)")) or 7
	local scale = major < 4 and 0.75 or 768 / ScreenHeight()
	for _, f in ipairs({ strip, first }) do
		f:SetScale(scale)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	end
	-- The dot of the first draw hangs below its square, and on Direct3D 9 nothing covers it there: a yellow pixel
	-- under the strip (3.3.5, 29.09). Above the top edge the game still draws it, and the player sees nothing.
	firstText:ClearAllPoints()
	if major < 4 then
		firstText:SetPoint("BOTTOMLEFT", first, "TOPLEFT", 0, 0)
	else
		firstText:SetPoint("TOPLEFT", first, "TOPLEFT", 0, 0)
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
-- The map stays "open" for the effects half a second after it closes: the first frames of the world after it
-- still carry the depth and the light of the frame before the map, and the land showed a ghost of it (29.09).
local mapUntil = 0
local function GameState()
	local s = 1
	if IsIndoors and IsIndoors() then
		s = s + 2
	end
	if IsFlying and IsFlying() then
		s = s + 4
	end
	if photo or (game and DB.gamePhoto) then
		s = s + 8
	end
	if V("wet") and not lowQuality then
		s = s + 16
	end
	-- Only the fullscreen map: part of it is drawn before the effects start, and the night darkened it. The
	-- windowed map covers a piece of the screen, and the world around it keeps the effects.
	if (WorldMapFrame and WorldMapFrame:IsShown() and not (WorldMapFrame_InWindowedMode and WorldMapFrame_InWindowedMode()))
		or GetTime() < mapUntil then
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

-- The chat window in screen shares, 0..63 each, for the heat haze to leave alone (beta-1.0). The player moves
-- and resizes the chat, so the painted mask cannot know it; zeros when the frame is not there.
local function ChatRect()
	local f = ChatFrame1
	if not f or not f.GetLeft or not f:GetLeft() then
		return 0, 0, 0, 0
	end
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	if not sw or sw <= 0 or not sh or sh <= 0 then
		return 0, 0, 0, 0
	end
	local pad = 24
	local l = math.max(0, (f:GetLeft() - pad) / sw)
	local r = math.min(1, (f:GetRight() + pad) / sw)
	local t = math.max(0, 1 - (f:GetTop() + pad) / sh)
	local b = math.min(1, 1 - (f:GetBottom() - pad) / sh)
	return math.floor(l * 63 + 0.5), math.floor(t * 63 + 0.5), math.floor(r * 63 + 0.5), math.floor(b * 63 + 0.5)
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
		+ (checkView and 16 or 0)
	local chatL, chatT, chatR, chatB = ChatRect()
	local extra = { state, time, Code(V("nightDepth")), Code(Effective("ao")), (V("style") or 0) + ((DB.cinema or (game and DB.gamePhoto)) and 8 or 0),
		Code(V("grain") or 0), Code(DB.photoBlur or 35), switches, Code(haze), Code(hdr), facing,
		Code(V("mistHigh") or 0), Code(V("rayDefinition") or 0), Code(V("mistFlow") or 0),
		Code(V("bright") or 50), Code(V("contrast") or 50), Code(V("satur") or 50), Code(V("warmth") or 50),
		Code(V("raysOpen") or 45), Code(V("raysReach") or 50), Code(V("sunGlow") or 50), Code(V("mistNear") or 0),
		chatL, chatT, chatR, chatB,
		Code(V("lightThreshold") or 50), Code(V("lightRadius") or 50), Code(V("motionBlur") or 0),
		Code(V("playBlur") or 0) }
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

-- The minimap draws its blips past the interface transparency, so the icons stayed on a clean screen: the map
-- itself hides for photo mode and the shot, and comes back only if it was shown.
local mmHidden = false
local function MinimapOff()
	if Minimap and Minimap:IsShown() and not InCombatLockdown() then
		Minimap:Hide()
		mmHidden = true
	end
end
local function MinimapBack()
	if mmHidden and Minimap and not InCombatLockdown() then
		Minimap:Show()
		mmHidden = false
	end
end

-- The panels the player hides in plain play (1.7.3), each on its own, from the page «Дополнительно». A hidden panel
-- goes transparent, as the whole interface does in photo mode: transparency is allowed in combat and taints
-- nothing, and the panel keeps its place, so a click on it still works.
local function ChatFrames()
	local list = { "GeneralDockManager", "ChatFrameMenuButton", "FriendsMicroButton", "QuickJoinToastButton",
		"ChatFrameChannelButton" }
	for i = 1, NUM_CHAT_WINDOWS or 10 do
		list[#list + 1] = "ChatFrame" .. i
		list[#list + 1] = "ChatFrame" .. i .. "Tab"
	end
	return list
end
local HIDE_GROUPS = {
	{ "bars", T("Панели заклинаний", "Action bars"), { "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight",
		"MultiBarRight", "MultiBarLeft" } },
	{ "player", T("Портрет персонажа и питомца", "Player and pet frames"), { "PlayerFrame", "PetFrame" } },
	{ "target", T("Портрет цели и фокуса", "Target and focus frames"), { "TargetFrame", "FocusFrame" } },
	{ "party", T("Группа и рейд", "Party and raid"), { "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3",
		"PartyMemberFrame4", "CompactRaidFrameManager", "CompactRaidFrameContainer" } },
	{ "minimap", T("Миникарта", "Minimap"), { "MinimapCluster" } },
	{ "chat", T("Чат", "Chat"), ChatFrames() },
	{ "buffs", T("Эффекты на персонаже", "Buffs and debuffs"), { "BuffFrame", "TemporaryEnchantFrame", "ConsolidatedBuffs" } },
	{ "quests", T("Список заданий", "Quest tracker"), { "ObjectiveTrackerFrame", "WatchFrame", "QuestWatchFrame" } },
	{ "castbar", T("Полоса заклинания", "Cast bar"), { "CastingBarFrame" } },
}
local mmByPanel = false
local chatTyping = false
-- The panels that matter in a fight: with «wake» on they show whole while the player fights.
local FIGHT = { bars = true, player = true, target = true, party = true, castbar = true }
-- A group's frames under the mouse: the frame's own rectangle, so a see-through panel still answers.
local function MouseOver(names)
	local cx, cy = GetCursorPosition()
	for _, n in ipairs(names) do
		local f = _G[n]
		if f and f.IsVisible and f:IsVisible() and f:GetLeft() then
			local s = f:GetEffectiveScale()
			local x, y = cx / s, cy / s
			if x >= f:GetLeft() and x <= f:GetRight() and y >= f:GetBottom() and y <= f:GetTop() then
				return true
			end
		end
	end
	return false
end
-- How much of a group shows now, 0..1: its dial in plain play, in photo mode or in the play photo mode, whole when
-- the player types in the chat, points at the panel or fights (the fight panels).
local function PanelAlpha(g)
	local key = g[1]
	local a = ((photo and DB["photo_" .. key]) or (game and DB["game_" .. key]) or DB["ui_" .. key] or 100) / 100
	if a >= 1 then
		return 1
	end
	if key == "chat" and (chatTyping or (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow())) then
		return 1
	end
	if DB.panelWake and ((FIGHT[key] and InCombatLockdown()) or MouseOver(g[3])) then
		return 1
	end
	return a
end
-- The frames see-through now, each with its cap. The game sets some alphas itself (the chat tabs fade, the party
-- frames on range, the cast bar at every cast): a hook on SetAlpha puts such a frame back under its cap at once, so
-- it never blinks. A frame the player keeps whole is never touched, only given back its alpha once.
local hiddenFrames, hooked, reasserting = {}, {}, false
local function KeepHidden(self, a)
	local cap = hiddenFrames[self]
	if cap and not reasserting and a and a > cap then
		reasserting = true
		self:SetAlpha(cap)
		reasserting = false
	end
end
-- Each group's alpha on screen and the one it goes to: under the mouse or in a fight a panel comes up softly and
-- goes back slower still, the eye follows it. A dial, photo mode or the chat set it at once.
local panelGoal, panelNow = {}, {}
local FADE_IN, FADE_OUT = 3, 1.25
local function PanelGoals()
	for _, g in ipairs(HIDE_GROUPS) do
		panelGoal[g[1]] = PanelAlpha(g)
	end
	-- The minimap blips draw past the transparency (see MinimapOff), so a map faded to 0 hides itself, out of
	-- combat only.
	if Minimap and not InCombatLockdown() and not photo then
		local mmOff = panelGoal.minimap == 0 and (panelNow.minimap or 0) == 0
		if mmOff and Minimap:IsShown() then
			Minimap:Hide()
			mmByPanel = true
		elseif panelGoal.minimap > 0 and mmByPanel then
			Minimap:Show()
			mmByPanel = false
		end
	end
end
-- dt moves each group toward its goal (nil: straight there); all sets every frame, so frames that appeared later
-- (the raid) get their alpha too.
local function PanelFade(dt, all)
	for _, g in ipairs(HIDE_GROUPS) do
		local key = g[1]
		local goal, a = panelGoal[key] or 1, panelNow[key]
		if not dt or not a then
			a = goal
		elseif a < goal then
			a = math.min(goal, a + dt * FADE_IN)
		elseif a > goal then
			a = math.max(goal, a - dt * FADE_OUT)
		end
		if all or a ~= panelNow[key] then
			panelNow[key] = a
			for _, name in ipairs(g[3]) do
				local f = _G[name]
				if f and f.SetAlpha then
					if a < 1 then
						if not hooked[f] then
							hooked[f] = true
							hooksecurefunc(f, "SetAlpha", KeepHidden)
						end
						if hiddenFrames[f] ~= a then
							hiddenFrames[f] = a
							f:SetAlpha(a)
						end
					elseif hiddenFrames[f] then
						hiddenFrames[f] = nil
						f:SetAlpha(1)
					end
				end
			end
		end
	end
end
local function ApplyHide()
	if not DB then
		return
	end
	PanelGoals()
	PanelFade(nil, true)
end
-- Photo mode shows what the photo dials ask: all at 0 hides the whole interface at once, as before.
local function PhotoShowsPanels()
	for _, g in ipairs(HIDE_GROUPS) do
		if (DB["photo_" .. g[1]] or 0) > 0 then
			return true
		end
	end
	return false
end
-- With panels kept, every other window on UIParent goes to 0 and back as it was: UIParent at 0 would take the kept
-- panels with it. A panel inside another window keeps that window too.
local panelFrame, dimmed = nil, {}
local function PhotoDim(on)
	if on then
		if not panelFrame then
			panelFrame = {}
			for _, g in ipairs(HIDE_GROUPS) do
				for _, n in ipairs(g[3]) do
					local f = _G[n]
					while f and f ~= UIParent and not panelFrame[f] do
						panelFrame[f] = true
						f = f.GetParent and f:GetParent()
					end
				end
			end
		end
		for _, f in ipairs({ UIParent:GetChildren() }) do
			if not panelFrame[f] and f.GetAlpha and not dimmed[f] then
				dimmed[f] = f:GetAlpha()
				f:SetAlpha(0)
			end
		end
	else
		for f, a in pairs(dimmed) do
			f:SetAlpha(a)
		end
		dimmed = {}
	end
end
local photoPanels = false

-- ---------------------------------------------------------------------------------------------------------------
-- The interface for the effects to leave alone: the rectangles of the open windows and panels, in the second row of
-- the strip. On Direct3D 11 the effects run after the interface is drawn, and the blur of distance and of motion
-- smeared the panels with the world (29.09).
-- In its own block: the file is at the limit of 200 locals of one Lua function, and one more broke the whole addon.
-- ---------------------------------------------------------------------------------------------------------------

do
local UI_GROUPS = {}
for _, n in ipairs({ "GameMenuFrame", "InterfaceOptionsFrame", "VideoOptionsFrame", "AudioOptionsFrame", "AddonList",
	"KeyBindingFrame", "MacroFrame", "StaticPopup1", "StaticPopup2", "StaticPopup3", "CharacterFrame", "SpellBookFrame",
	"PlayerTalentFrame", "WorldMapFrame", "FriendsFrame", "GuildFrame", "PVEFrame", "EncounterJournal",
	"AchievementFrame", "CollectionsJournal", "WardrobeFrame", "CalendarFrame", "GossipFrame", "QuestFrame",
	"MerchantFrame", "MailFrame", "OpenMailFrame", "BankFrame", "TradeFrame", "AuctionFrame", "TradeSkillFrame",
	"ClassTrainerFrame", "LootFrame", "HelpFrame", "DressUpFrame", "ItemTextFrame", "GarrisonLandingPage",
	"OrderHallMissionFrame", "GUWOWPreviewBar", "LegionGUReport", "GameTooltip", "ItemRefTooltip",
	"DropDownList1", "DropDownList2" }) do
	UI_GROUPS[#UI_GROUPS + 1] = { n }
end
local bags = {}
for i = 1, 13 do
	bags[i] = "ContainerFrame" .. i
end
UI_GROUPS[#UI_GROUPS + 1] = bags
-- The quest tracker stands over the whole right side, blocks or not: its rectangle is what it shows now.
local function TrackerParts()
	local list = { ObjectiveTrackerFrame and ObjectiveTrackerFrame.HeaderMenu }
	local blocks = ObjectiveTrackerFrame and ObjectiveTrackerFrame.BlocksFrame
	if blocks then
		for _, f in ipairs({ blocks:GetChildren() }) do
			list[#list + 1] = f
		end
	elseif ObjectiveTrackerFrame then
		list[#list + 1] = ObjectiveTrackerFrame
	end
	return list
end
for _, g in ipairs(HIDE_GROUPS) do
	if g[1] == "quests" then
		UI_GROUPS[#UI_GROUPS + 1] = { "WatchFrame", "QuestWatchFrame", parts = TrackerParts }
	elseif g[1] == "chat" then
		local names = { "ChatFrame1EditBox" }
		for _, n in ipairs(g[3]) do
			names[#names + 1] = n
		end
		UI_GROUPS[#UI_GROUPS + 1] = names
	elseif g[1] == "bars" then
		UI_GROUPS[#UI_GROUPS + 1] = { "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight" }
		UI_GROUPS[#UI_GROUPS + 1] = { "MultiBarRight", "MultiBarLeft" }
	elseif g[1] == "party" or g[1] == "target" then
		for _, n in ipairs(g[3]) do
			UI_GROUPS[#UI_GROUPS + 1] = { n }
		end
	elseif g[1] == "buffs" then
		-- The buttons stand outside the small BuffFrame, in rows to the left and down.
		local names = { "BuffFrame" }
		for i = 1, 32 do
			names[#names + 1] = "BuffButton" .. i
		end
		for i = 1, 16 do
			names[#names + 1] = "DebuffButton" .. i
		end
		for i = 1, 3 do
			names[#names + 1] = "TempEnchant" .. i
		end
		UI_GROUPS[#UI_GROUPS + 1] = names
	else
		UI_GROUPS[#UI_GROUPS + 1] = g[3]
	end
end

local function UIBits(i, v)
	Tint(uiCells[i], math.floor(v / 4) % 2, math.floor(v / 2) % 2, v % 2)
end

-- A coordinate 0..511 in three cells, the high bits first.
local function UICell(i, v)
	UIBits(i, math.floor(v / 64))
	UIBits(i + 1, math.floor(v / 8) % 8)
	UIBits(i + 2, v % 8)
end

-- A panel the player made see-through (the dials) or photo mode dimmed: below half its alpha the effects go over
-- its place.
local function PanelHidden(f)
	while f and f ~= UIParent do
		if (hiddenFrames[f] and hiddenFrames[f] < 0.5) or dimmed[f] then
			return true
		end
		f = f.GetParent and f:GetParent()
	end
	return false
end
-- A visible group's rectangle in the units of UIParent; nil if nothing is shown.
local function GroupRect(g)
	local l, t, r, b
	local function Add(f)
		if type(f) == "string" then
			f = _G[f]
		end
		if f and f.GetLeft and f.IsVisible and f:IsVisible() and f:GetLeft() and f:GetTop() and not PanelHidden(f) then
			local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
			local fl, fr, ft, fb = f:GetLeft() * s, f:GetRight() * s, f:GetTop() * s, f:GetBottom() * s
			if fr > fl and ft > fb then
				l, r = math.min(l or fl, fl), math.max(r or fr, fr)
				t, b = math.max(t or ft, ft), math.min(b or fb, fb)
			end
		end
	end
	for _, n in ipairs(g) do
		Add(n)
	end
	if g.parts then
		for _, f in ipairs(g.parts()) do
			Add(f)
		end
	end
	return l, t, r, b
end

-- A group over 60% of the screen is no window (the full screen world map, another addon's frame over the world):
-- it is skipped, else the effects would leave the whole picture alone. DB.uiSeen keeps what was sent last, each group
-- by its first frame in screen percent, for a report from a live game.
local UI_PAD = 3
local UI_MAX_SHARE = 0.6
local function Clamp511(v)
	return math.max(0, math.min(511, v))
end
local lastUI
local function PaintUI()
	local sw, sh = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
	local px = UI_PAD * sh / ScreenHeight()
	local coords, seen = {}, {}
	-- Photo mode hides the interface with alpha, so everything is still "visible": no rectangles then, unless the
	-- player keeps some panels in photo mode (their see-through ones drop out in GroupRect).
	if (not photo or photoPanels) and UIParent:IsVisible() and UIParent:GetAlpha() > 0.5 and sw > 0 and sh > 0 then
		for _, g in ipairs(UI_GROUPS) do
			if #coords >= UI_RECTS * 4 then
				break
			end
			local l, t, r, b = GroupRect(g)
			if l and (r - l) * (t - b) <= UI_MAX_SHARE * sw * sh then
				seen[#seen + 1] = string.format("%s %d,%d-%d,%d", tostring(g[1] or "tracker"), math.floor(l / sw * 100),
					math.floor((1 - t / sh) * 100), math.floor(r / sw * 100), math.floor((1 - b / sh) * 100))
				coords[#coords + 1] = Clamp511(math.floor((l - px) / sw * 511))
				coords[#coords + 1] = Clamp511(math.floor((1 - (t + px) / sh) * 511))
				coords[#coords + 1] = Clamp511(math.ceil((r + px) / sw * 511))
				coords[#coords + 1] = Clamp511(math.ceil((1 - (b - px) / sh) * 511))
			end
		end
	end
	for i = #coords + 1, UI_RECTS * 4 do
		coords[i] = 0
	end
	local key = table.concat(coords, ",")
	if key == lastUI then
		return
	end
	lastUI = key
	DB.uiSeen = table.concat(seen, "; ")
	UIBits(0, 5)
	local sum = 0
	for i, v in ipairs(coords) do
		UICell(1 + 3 * (i - 1), v)
		sum = sum + v
	end
	sum = sum % 64
	UIBits(UI_CELLS - 2, math.floor(sum / 8))
	UIBits(UI_CELLS - 1, sum % 8)
end

-- Twenty times a second: a quarter of a second of blur over a freshly opened window shows. The cells change only
-- when a rectangle does.
local uiWait = 0
local uiWatch = CreateFrame("Frame")
uiWatch:SetScript("OnUpdate", function(self, dt)
	uiWait = uiWait - dt
	if DB and uiWait <= 0 then
		uiWait = 0.05
		PaintUI()
	end
end)
end

local function Photo(on)
	if on == photo then
		return
	end
	if on and InCombatLockdown() then
		print("|cffffd200GUWOW!:|r " .. T("фоторежим недоступен в бою.", "photo mode is not available in combat."))
		return
	end
	photo = on
	DropKeyboard()
	if on then
		CloseOptions()
		photoPanels = PhotoShowsPanels()
		if photoPanels then
			PhotoDim(true)
			ApplyHide()
			if PanelAlpha(HIDE_GROUPS[5]) == 0 then
				MinimapOff()
			end
		else
			UIParent:SetAlpha(0)
			MinimapOff()
		end
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
		if photoPanels then
			PhotoDim(false)
			photoPanels = false
		end
		UIParent:SetAlpha(1)
		MinimapBack()
		ApplyHide()
	end
	Paint()
end

function GUWOW_TogglePhoto()
	Photo(not photo)
end

-- The play photo mode: the panels go to their game_ dials, nothing else changes, so bags, windows, the map and the
-- fight work as always. The look with the photo blur rides on bit 8 of the state (see GameState).
function GUWOW_ToggleGame()
	if not DB then
		return
	end
	game = not game
	ApplyHide()
	Paint()
	print("|cffffd200GUWOW!:|r " .. (game and T("игровой фоторежим включён. Выход: та же клавиша, /gu game или Alt + щелчок по кнопке у миникарты.",
		"play photo mode on. Leave with the same key, /gu game or Alt + click on the minimap button.")
		or T("игровой фоторежим выключен.", "play photo mode off.")))
end

-- The mod on and off, for the key the player picks in the game's key bindings and for the minimap button.
function GUWOW_ToggleMod()
	if not DB then
		return
	end
	DB.master = not DB.master
	Refresh()
	Paint()
	print("|cffffd200GUWOW!:|r " .. (DB.master and T("включён", "on") or T("выключен", "off")))
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
		MinimapOff()
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
				MinimapBack()
			end
		end)
	end)
end

-- Esc and Enter to chat end photo mode: the Esc menu shows over the picture, chat is not typed blind. The play
-- photo mode stays on through both.
GameMenuFrame:HookScript("OnShow", function()
	if photo then
		Photo(false)
	end
end)
hooksecurefunc("ChatEdit_ActivateChat", function()
	if photo then
		Photo(false)
	end
	chatTyping = true
	ApplyHide()
end)
if ChatEdit_DeactivateChat then
	hooksecurefunc("ChatEdit_DeactivateChat", function()
		chatTyping = false
		ApplyHide()
	end)
end
-- The fullscreen map hides UIParent and shows it again on closing: photo mode stays and hides the interface anew
-- (1.7.6; the map used to throw the player out of photo mode).
UIParent:HookScript("OnShow", function()
	if not photo then
		return
	end
	if photoPanels then
		PhotoDim(true)
		ApplyHide()
	else
		UIParent:SetAlpha(0)
	end
	MinimapOff()
	Paint()
end)

BINDING_HEADER_GUWOW = "GUWOW!"
BINDING_NAME_GUWOW_TOGGLE = T("Включить или выключить GUWOW!", "Turn GUWOW! on or off")
BINDING_NAME_GUWOW_PHOTO = T("Фоторежим (прячет интерфейс, размывает фон)", "Photo mode (hides the interface, blurs the background)")
BINDING_NAME_GUWOW_SHOT = T("Чистый снимок экрана", "Clean screenshot")
BINDING_NAME_GUWOW_GAME = T("Игровой фоторежим (прячет панели, игра идёт)", "Play photo mode (hides the panels, the game goes on)")

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
	for _, k in ipairs(CODE_KEYS8) do
		parts[#parts + 1] = tostring(math.floor((DB[k] or 0) + 0.5))
	end
	parts[#parts + 1] = tostring(DB.bokeh and 4 or 0)
	return "GUW8:" .. table.concat(parts, ".")
end

-- The values a code carries, or nil when the line is not a GU-WOW code.
local function ParseCode(code)
	local ver, body = string.match(code or "", "GUW([12345678]):([%d%.]+)")
	if not body then
		return nil
	end
	local nums = {}
	for n in string.gmatch(body, "%d+") do
		nums[#nums + 1] = tonumber(n)
	end
	local n1 = #CODE_KEYS + 1
	local keys2 = ver == "8" and CODE_KEYS8 or (ver == "7" and CODE_KEYS7 or (ver == "6" and CODE_KEYS6
		or (ver == "5" and CODE_KEYS5 or (ver == "4" and CODE_KEYS4 or (ver == "3" and CODE_KEYS3 or CODE_KEYS2)))))
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
	-- A code of an older version has no word about the newer dials: it means their defaults, so an old preset
	-- is still recognised exactly and shows a neutral picture, not whatever was on screen.
	for k in pairs(LOOK) do
		if t[k] == nil then
			t[k] = DEFAULTS[k]
		end
	end
	return t
end

-- ---------------------------------------------------------------------------------------------------------------
-- The panels: Interface > AddOns > GU-WOW, and its page «Profiles and photo»
-- ---------------------------------------------------------------------------------------------------------------

-- The widgets show what is on screen, a preview too. Setting a slider there is not a change by the player.
local refreshing = false
Refresh = function()
	refreshing = true
	for _, w in pairs(widgets) do
		w:Refresh()
	end
	refreshing = false
end

local function Say(text)
	print("|cffffd200GUWOW!:|r " .. text)
end

-- Yes or no before a change that replaces or deletes something. The action runs only on «Accept».
-- What is new, once after an update.
StaticPopupDialogs["GUWOW_NEWS"] = {
	text = T("GUWOW! обновлён: публичная бета 1.1.\n\nНаписать в поддержку теперь можно из отдельной страницы «Сообщение в поддержку» в меню или по Ctrl + щелчок по кнопке у миникарты. Клавишу фоторежима можно назначить прямо на странице «Фоторежим», там же мягкое размытие дали для обычной игры. На странице «Панели» у каждой панели свой ползунок прозрачности: под мышью и в бою панель плавно проявляется целиком. На «Ночи» новые ручки: что считать огнём и радиус свечения. На «Картинке» размытие при движении. У каждого ползунка подсказка простыми словами, готовых пресетов стало больше.\n\nМеню: /gu или кнопка у миникарты.",
		"GUWOW! is updated: public beta 1.1.\n\nWriting to support now has its own page, Message to support, in the menu, or Ctrl + click on the minimap button. The photo mode key is set right on the Photo mode page, and so is a soft far blur for normal play. On the Panels page each panel has its own transparency slider: under the mouse and in a fight the panel fades in whole. Night has new dials: what counts as a light and the glow radius. Picture has motion blur. Every slider has a tip in plain words, and there are more ready presets.\n\nMenu: /gu or the minimap button."),
	button1 = OKAY or "OK",
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

-- The full screen glow off on WotLK 3.3.5 (see PLAYER_ENTERING_WORLD): one click turns it on.
StaticPopupDialogs["GUWOW_GLOW"] = {
	text = T("GUWOW!: в настройках графики выключено полноэкранное свечение. Без него туман и ночь ложатся и на окна игры.\n\nВключить свечение сейчас?",
		"GUWOW!: the full screen glow is off in the video settings. Without it the fog and the night cover the game's windows too.\n\nTurn the glow on now?"),
	button1 = T("Включить", "Turn on"),
	button2 = CANCEL or "Cancel",
	OnAccept = function()
		SetCVar("ffxGlow", "1")
		Say(T("свечение включено. Если окна остались в тумане, перезапустите игру.", "the glow is on. If the windows stay in the fog, restart the game."))
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

-- After «Send» and the reload (1.7.3): players saw no answer at all. The game cannot hear the helper, so the window
-- says where the report is now and what the Windows notice means.
StaticPopupDialogs["GUWOW_SENT"] = {
	text = T("GUWOW!: отчёт сохранён и передан программе GU-WOW.\n\nЧерез несколько секунд Windows покажет уведомление «Спасибо. Сообщение об ошибке доставлено разработчику».\n\nЕсли уведомления нет, программа GU-WOW не запущена. Запустите её, и отчёт уйдёт сам.",
		"GUWOW!: the report is saved and handed to the GU-WOW program.\n\nIn a few seconds Windows shows the notice «Thank you. The error report has been delivered to the developer».\n\nIf no notice shows, the GU-WOW program is not running. Start it, and the report goes on its own."),
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
-- Declared below, used by the self-heal above their bodies.
local ChatBack, PlaceMinimapButton

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
-- warn: from this value on a small orange note under the slider says artifacts are possible. tip: a tooltip.
-- onChange: called with the new value after it is stored (the menu scale applies itself this way).
local function Slider(parent, key, label, x, y, lo, hi, warn, tip, onChange)
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
	local warnText
	if warn then
		warnText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		warnText:SetPoint("TOP", s, "BOTTOM", 0, 3)
		warnText:SetTextColor(1.0, 0.55, 0.1)
		warnText:SetText(T("значения от " .. warn .. " могут добавлять артефакты", "values of " .. warn .. " and up may add artifacts"))
		warnText:Hide()
	end
	if tip then
		s:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(tip, nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		s:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end
	s:SetScript("OnValueChanged", function(self, v)
		v = math.floor(v + 0.5)
		text:SetText(label .. ": " .. v)
		if warnText then
			if v >= warn then
				warnText:Show()
			else
				warnText:Hide()
			end
		end
		if refreshing or not DB or V(key) == v then
			return
		end
		Set(key, v)
		if onChange then
			onChange(v)
		end
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

-- The welcome page (1.6.9): what GU-WOW is, the hints and the bug report. The settings live on the three
-- child pages: «Основные», «Дополнительно», «Фоторежим».
local home = CreateFrame("Frame", "LegionGUHome", UIParent)
home.name = "GUWOW!"
home:Hide()
local homeTitle = home:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
homeTitle:SetPoint("TOPLEFT", 16, -16)
homeTitle:SetText("GUWOW! " .. VERSION)
local homeText = home:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
homeText:SetPoint("TOPLEFT", 16, -52)
homeText:SetWidth(600)
homeText:SetJustifyH("LEFT")
homeText:SetSpacing(4)
homeText:SetText(T("Туман, лучи солнца, ночь по игровым часам, свет огней и картинка. Всё меняется сразу.\n\nСтраницы слева:\n«Сообщение в поддержку» — написать автору об ошибке, со снимком экрана.\n«Основные» — включатель мода и готовые пресеты.\n«Атмосфера» — туман, погода, мокрая земля, тени и марево.\n«Лучи» — лучи солнца и свечение в тумане, со своими пресетами.\n«Ночь» — темнота, свет огней и подземелья.\n«Картинка» — резкость, цвет, яркость, размытие при движении и плёночные эффекты.\n«Дополнительно» — стили, коды, свои пресеты, поведение и видимость панелей.\n«Фоторежим» — снимки, своя клавиша и всё, что нужно только для них.\n\nПодсказки:\nНаведите мышь на ползунок, и появится подсказка простыми словами.\nF11 включает и выключает весь мод. Клавишу фоторежима можно назначить на странице «Фоторежим».\nИгровой фоторежим прячет выбранные панели, играть в нём можно как обычно, и в бою тоже. Его панели и вид задаются на странице «Панели».\nКнопка у миникарты: левая — меню, правая — вкл/выкл, средняя — фоторежим, Alt + левая — игровой фоторежим.\nКоманды чата: /gu меню · /gu photo · /gu game · /gu shot · /gu check · /gu fix · /gu report · /gu help.",
	"Fog, sun rays, night by the game clock, firelight and the picture. Everything applies at once.\n\nThe pages on the left:\nMessage to support — tell the author about a bug, with a screenshot.\nMain — the mod switch and the ready presets.\nAtmosphere — fog, weather, wet ground, shadows and heat haze.\nRays — the sun rays and the glow in the fog, with their own presets.\nNight — darkness, firelight and dungeons.\nPicture — sharpness, colour, brightness, motion blur and the film effects.\nExtras — styles, codes, your presets, behaviour and the panels you see.\nPhoto mode — screenshots, its own key and what only they need.\n\nHints:\nHover a slider for a tip in plain words.\nF11 toggles the whole mod. The photo mode key is set on the Photo mode page.\nThe play photo mode hides the panels you pick, and you play in it as usual, in a fight too. Its panels and look are set on the Panels page.\nThe minimap button: left opens the menu, right toggles, middle starts photo mode, Alt + left the play photo mode.\nChat commands: /gu menu · /gu photo · /gu game · /gu shot · /gu check · /gu fix · /gu report · /gu help."))

local panel = CreateFrame("Frame", "LegionGUPanel", UIParent)
panel.name = T("Основные", "Main")
panel.parent = home.name
panel:Hide()

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("GUWOW!: " .. panel.name)
local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
sub:SetText(T("Всё, что видно в игре. Меняется сразу. Пресет листается стрелками, «Применить» на полоске вверху экрана оставляет его.",
	"Everything seen in the game. Changes apply at once. The arrows walk the presets, «Apply» on the top bar keeps one."))

-- The settings live on their own pages since 1.7.1: one page per theme keeps the text at full size. The old
-- single page grew past the window, and the fit-to-window scale made the font tiny.
local function NewPage(frameName, ru, en, subRu, subEn)
	local f = CreateFrame("Frame", frameName, UIParent)
	f.name = T(ru, en)
	f.parent = home.name
	f:Hide()
	local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	t:SetPoint("TOPLEFT", 16, -16)
	t:SetText("GUWOW!: " .. f.name)
	if subRu then
		local s = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
		s:SetText(T(subRu, subEn))
	end
	return f
end
local panelAtmo = NewPage("LegionGUPanelAtmo", "Атмосфера", "Atmosphere",
	"Туман, низовой туман, погода, мокрая земля, тени и марево.", "Fog, ground mist, weather, wet ground, shadows and heat haze.")
local panelRays = NewPage("LegionGUPanelRays", "Лучи", "Rays",
	"Лучи солнца и свечение солнца в тумане.", "The sun rays and the sun's glow in the fog.")
local panelNight = NewPage("LegionGUPanelNight", "Ночь", "Night",
	"Ночь по игровым часам, свет огней и темнота подземелий.", "Night by the game clock, firelight and dungeon darkness.")
local panelPic = NewPage("LegionGUPanelPic", "Картинка", "Picture",
	"Резкость, цвет, яркость и плёночные эффекты.", "Sharpness, colour, brightness and the film effects.")

-- The GU-WOW pages are laid out about 745 by 585 points and the Blizzard options window is smaller. The pages
-- scale themselves into the window on show (1.6.9): the window itself never changes size and no manual font
-- slider is needed — the fit follows the player's own window and UI scale.
local guPages = {}
local function FitPages()
	local c = InterfaceOptionsFramePanelContainer
	if not c then
		return
	end
	local sc = math.min(1, c:GetWidth() / 748, c:GetHeight() / 588)
	if sc < 0.5 then
		sc = 0.5
	end
	for _, f in ipairs(guPages) do
		f:SetScale(sc)
	end
end
local function GrowOptions()
	FitPages()
end
local function ShrinkOptions()
end

local L, R = 16, 470
Check(panel, "master", T("Включить GUWOW!", "Enable GUWOW!"), L, -60)

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

Header(panelAtmo, T("Туман", "Fog"), L, -60)
Check(panelAtmo, "fog", T("Туман", "Fog"), L, -74)
Slider(panelAtmo, "fogThickness", T("Густота тумана", "Fog density"), L + 6, -110, nil, nil, nil,
	T("Сколько тумана в воздухе. 0 — воздух чистый, 100 — дали почти не видно", "How much fog hangs in the air. 0 is clear air, 100 hides the distance"))
Slider(panelAtmo, "fogDistance", T("Дальность тумана", "Fog distance"), L + 6, -152, nil, nil, nil,
	T("Где туман становится стеной. Меньше — стена ближе к вам, больше — дальше", "Where the fog turns into a wall. Lower brings it closer, higher pushes it away"))
Slider(panelAtmo, "mist", T("Низовой туман", "Ground mist"), L + 6, -194, nil, nil, nil,
	T("Дымка, которая лежит в низинах, над водой и под деревьями", "The haze lying in hollows, over water and under the trees"))
Slider(panelAtmo, "mistDensity", T("Плотность низового тумана", "Ground mist thickness"), L + 6, -236, nil, nil, 86,
	T("Насколько эта дымка непрозрачная. Выше — как вата", "How solid that haze is. Higher looks like cotton wool"))
Slider(panelAtmo, "mistHigh", T("Туман с высоты: с гор и в полёте", "Mist from a height: hills and flight"), L + 6, -278, nil, nil, nil,
	T("Сколько дымки видно внизу, когда вы на горе или летите. 0 — сверху всё чисто", "How much haze you see below from a hill or in flight. 0 keeps the view clear"))
-- The mist at the feet (1.7.1): ankle-deep, with no clear circle around the player. Swamps ask for it.
Slider(panelAtmo, "mistNear", T("Туман у ног: по щиколотку", "Mist at the feet: ankle-deep"), L + 6, -320, nil, nil, 71,
	T("Стелется прямо под персонажем, без чистого круга. 0 выключает — как раньше", "Lies right under the character, no clear circle. 0 turns it off — as before"))
Header(panelAtmo, T("Погода и земля", "Weather and ground"), R, -60)
Check(panelAtmo, "weather", T("Погодное настроение", "Weather mood"), R, -74)
Check(panelAtmo, "wet", T("Мокрая земля в дождь", "Wet ground in rain"), R, -98)
Slider(panelAtmo, "ao", T("Тени в щелях", "Contact shadows"), R + 6, -140, nil, nil, nil,
	T("Мягкие тени под камнями, травой и у стен: предметы стоят на земле, а не парят. Немного нагружает видеокарту", "Soft shadows under stones, grass and by walls: things sit on the ground. Costs a little GPU"))
Slider(panelAtmo, "hazeStrength", T("Марево в пустынях и огненных землях", "Heat haze in deserts and fire lands"), R + 6, -182, nil, nil, 71,
	T("Воздух дрожит от жары в пустынях и у лавы. В других местах его нет", "The air shimmers with heat in deserts and by lava. Nowhere else"))

Check(panelRays, "rays", T("Лучи солнца", "Sun rays"), L, -60)
Slider(panelRays, "raysStrength", T("Сила лучей", "Ray strength"), L + 6, -100, nil, nil, nil,
	T("Насколько ярко светят лучи солнца сквозь кроны и облака. 0 — без лучей", "How bright the sun shafts through trees and clouds are. 0 turns them off"))
Slider(panelRays, "rayDefinition", T("Чёткость лучей: от свечения до снопов", "Ray definition: a glow or shafts"), L + 6, -142, nil, nil, 71,
	T("0 — мягкое свечение в воздухе. Выше — отдельные снопы света с тенью между ними", "0 is a soft glow in the air. Higher gives separate shafts with shade between them"))
-- The rays' own dials (1.7.1): the open-sky strength, the length and the sun's glow in the fog.
Slider(panelRays, "raysOpen", T("Лучи в открытом небе", "Rays in the open"), L + 6, -184, nil, nil, 71,
	T("Сила лучей в поле и на снегу, где нет крон. 22 — как в 1.7.0, выше — заметнее", "Ray strength over fields and snow, with no canopy. 22 is the 1.7.0 look, higher is bolder"))
Slider(panelRays, "raysReach", T("Длина лучей (50 — как было)", "Ray length (50 — as before)"), R + 6, -100, nil, nil, 81,
	T("Как далеко от солнца тянутся лучи. Меньше — короткие, больше — через весь экран", "How far the shafts reach from the sun. Lower is short, higher crosses the screen"))
Slider(panelRays, "sunGlow", T("Свечение солнца в тумане (50 — как было)", "Sun glow in the fog (50 — as before)"), R + 6, -142, nil, nil, 76,
	T("Светлое пятно вокруг солнца, когда оно в тумане", "The bright patch round the sun when it is in the fog"))

Header(panelNight, T("Ночь", "Night"), L, -60)
Check(panelNight, "night", T("Ночь и огни", "Night and lights"), L, -76)
Slider(panelNight, "nightDarkness", T("Темнота ночи", "Night darkness"), L + 6, -116, nil, nil, nil,
	T("Насколько темнеет мир ночью по игровым часам. 0 — ночь как в игре", "How dark the world gets at night by the game clock. 0 keeps the game's own night"))
Slider(panelNight, "nightDepth", T("Глубина ночи", "Night depth"), L + 6, -158, nil, nil, nil,
	T("Дополнительная тьма поверх «Темноты ночи»: 0 обычная ночь, 100 глухая", "Extra darkness over the night darkness: 0 a plain night, 100 pitch dark"))
Slider(panelNight, "lightGlow", T("Свет огней", "Light glow"), R + 6, -116, nil, nil, nil,
	T("Насколько ярко ночью светят фонари, костры и окна. 0 — огни не светят сверх игры", "How bright lamps, fires and windows glow at night. 0 adds no glow"))
Slider(panelNight, "caveDarkness", T("Темнота подземелий", "Dungeon darkness"), R + 6, -158, nil, nil, nil,
	T("Насколько темно в пещерах и подземельях. 0 — как в игре", "How dark caves and dungeons are. 0 keeps the game's look"))
-- The lights' own dials (1.7.3): which objects glow and how far the glow spreads. 50 is the old look.
Header(panelNight, T("Огни ночью", "Lights at night"), L, -210)
Slider(panelNight, "lightThreshold", T("Что считать огнём (50 — как было)", "What counts as a light (50 — as before)"), L + 6, -250, nil, nil, nil,
	T("Больше — светятся только настоящие фонари и костры. Меньше — светятся и тусклые предметы. Если ночью светится то, что не должно, прибавьте", "Higher: only real lamps and fires glow. Lower: dim things glow too. If wrong things glow at night, raise it"))
Slider(panelNight, "lightRadius", T("Радиус свечения (50 — как было)", "Glow radius (50 — as before)"), R + 6, -250, nil, nil, 86,
	T("Как далеко вокруг огня разливается свет. Меньше — аккуратный ореол, больше — широкое зарево", "How far the light spreads round a flame. Lower is a tight halo, higher a wide glow"))

Header(panelPic, T("Картинка", "Picture"), L, -60)
Check(panelPic, "eye", T("Привыкание глаз", "Eye adaptation"), L, -76)
Slider(panelPic, "sharpness", T("Резкость", "Sharpness"), L + 6, -116, nil, nil, 61,
	T("Чётче края и мелкие детали: листва, камни, броня. Слишком много — появляется рябь", "Crisper edges and fine detail: leaves, stones, armour. Too much adds shimmer"))
Slider(panelPic, "grade", T("Цвет по времени суток", "Time of day colour"), L + 6, -158, nil, nil, nil,
	T("Золото вечера и утра, холод ночи: сила окраски по игровым часам", "The gold of the evening and the cool of the night, by the game clock"))
Slider(panelPic, "vignette", T("Виньетка", "Vignette"), L + 6, -200, nil, nil, nil,
	T("Лёгкое затемнение по углам экрана, как на фото. 0 — без него", "A light darkening in the screen corners, as on a photo. 0 turns it off"))
Slider(panelPic, "hdrStrength", T("Кино-HDR: глубже тени, мягче блики", "Cinema HDR: deeper shadows, softer highlights"), R + 6, -116, nil, nil, nil,
	T("Картинка как в кино: тени глубже, яркое небо и блики не выгорают в белое", "A film look: deeper shadows, bright sky and highlights keep their detail"))
Slider(panelPic, "grain", T("Плёночное зерно", "Film grain"), R + 6, -158, nil, nil, 71,
	T("Мелкий шум как на плёнке. 0 — картинка чистая", "A fine noise as on film. 0 keeps the picture clean"))
-- Motion blur (1.7.3): the picture smears along the camera turn, not the player's habit of a look, so a preset
-- leaves it alone. 0 keeps it off.
Slider(panelPic, "motionBlur", T("Размытие при движении", "Motion blur"), R + 6, -200, nil, nil, 71,
	T("При быстром повороте камеры картинка слегка смазывается, как в кино. 0 — выключено. Интерфейс не размывается", "The picture smears a little on a fast camera turn, as in films. 0 is off. The interface stays sharp"))

-- A preset carousel (1.7.1): the ready looks and, when saved, the player's own one («Мой») at the end. «<» and
-- «>» page with a preview, «+» saves the on-screen values into the own slot, «-» deletes it. One factory serves
-- the picture and the rays; opts: keys, presets, slot (the DB field), what (for the speech), x, y, widget.
local function Carousel(opts)
	local index = 1
	local function List()
		local list = {}
		for _, p in ipairs(opts.presets) do
			list[#list + 1] = p
		end
		if DB and DB[opts.slot] then
			list[#list + 1] = { T("Мой", "My own"), DB[opts.slot] }
		end
		return list
	end
	local function Matching()
		for i, p in ipairs(List()) do
			local same = true
			for _, k in ipairs(opts.keys) do
				if V(k) ~= p[2][k] then
					same = false
					break
				end
			end
			if same then
				return i, p[1]
			end
		end
	end
	local label = (opts.parent or panel):CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", opts.x + 28, opts.y - 5)
	label:SetWidth(160)
	label:SetHeight(12)
	label:SetJustifyH("CENTER")
	local function Show(d)
		local list = List()
		index = (index - 1 + d) % #list + 1
		Preview(list[index][2], list[index][1])
	end
	Tip(Button(opts.parent or panel, "<", opts.x, opts.y, 24, function() Show(-1) end), T("Предыдущий пресет: ", "Previous preset: ") .. opts.what)
	Tip(Button(opts.parent or panel, ">", opts.x + 192, opts.y, 24, function() Show(1) end), T("Следующий пресет: ", "Next preset: ") .. opts.what)
	Tip(Button(opts.parent or panel, "+", opts.x + 220, opts.y, 24, function()
		local save = function()
			local my = {}
			for _, k in ipairs(opts.keys) do
				my[k] = V(k)
			end
			DB[opts.slot] = my
			Refresh()
			Say(opts.what .. T(" с экрана сохранены в пресет «Мой».", " from the screen are saved as «My own»."))
		end
		if DB[opts.slot] then
			Confirm(T("Заменить пресет «Мой» настройками с экрана?", "Replace «My own» with the on-screen settings?"), save)
		else
			save()
		end
	end), T("Сохранить настройки с экрана в пресет «Мой»", "Save the on-screen settings as «My own»"))
	Tip(Button(opts.parent or panel, "-", opts.x + 248, opts.y, 24, function()
		if not DB[opts.slot] then
			Say(T("пресет «Мой» не сохранён, удалять нечего.", "«My own» is not saved, nothing to delete."))
			return
		end
		Confirm(T("Удалить пресет «Мой»?", "Delete «My own»?"), function()
			DB[opts.slot] = nil
			index = 1
			Refresh()
			Say(T("пресет «Мой» удалён.", "«My own» is deleted."))
		end)
	end), T("Удалить пресет «Мой». Готовые не удаляются", "Delete «My own». The ready ones stay"))
	widgets[opts.widget] = { Refresh = function()
		local i, name = Matching()
		if i then
			index = i
		end
		label:SetText(name or T("Свои настройки", "Custom"))
	end }
end

-- Brightness and colour (1.7.0): the game has no brightness control of its own, so GU-WOW carries one. 50 on
-- every dial is the game's own picture.
Header(panelPic, T("Яркость и цвет", "Brightness and colour"), L, -240)
Slider(panelPic, "bright", T("Яркость (50 — как в игре)", "Brightness (50 — the game's own)"), L + 6, -280, nil, nil, 76,
	T("Общая яркость картинки. Если ночью слишком темно, прибавьте", "The overall brightness. If the night is too dark, raise it"))
Slider(panelPic, "satur", T("Сочность цвета", "Colour richness"), L + 6, -322, nil, nil, 81,
	T("Меньше — цвета спокойнее и ближе к серому, больше — ярче и насыщеннее", "Lower calms the colours towards grey, higher makes them richer"))
Slider(panelPic, "contrast", T("Контрастность", "Contrast"), R + 6, -280, nil, nil, 76,
	T("Разница между светлым и тёмным. Больше — картинка резче, меньше — мягче", "The gap between light and dark. Higher is punchier, lower is softer"))
Slider(panelPic, "warmth", T("Тепло картинки: холоднее или теплее", "Picture warmth: colder or warmer"), R + 6, -322, nil, nil, nil,
	T("Меньше 50 — оттенок холодный, синеватый. Больше 50 — тёплый, золотистый", "Below 50 is a cold bluish tint, above 50 a warm golden one"))
Header(panelRays, T("Пресет лучей", "Rays preset"), L, -230)
Carousel({
	keys = { "raysStrength", "rayDefinition", "raysOpen", "raysReach", "sunGlow" },
	presets = {
		{ T("Стандарт GU", "GU standard"), { raysStrength = 100, rayDefinition = 55, raysOpen = 45, raysReach = 50, sunGlow = 50 } },
		{ T("Утро в лесу", "Forest morning"), { raysStrength = 80, rayDefinition = 10, raysOpen = 30, raysReach = 60, sunGlow = 75 } },
		{ T("Снопы света", "Light shafts"), { raysStrength = 100, rayDefinition = 90, raysOpen = 45, raysReach = 80, sunGlow = 50 } },
		{ T("Яркий полдень", "Bright noon"), { raysStrength = 100, rayDefinition = 40, raysOpen = 80, raysReach = 50, sunGlow = 60 } },
		{ T("Тихая дымка", "Quiet haze"), { raysStrength = 60, rayDefinition = 15, raysOpen = 25, raysReach = 40, sunGlow = 35 } },
	},
	slot = "raysMy", what = T("настройки лучей", "the rays settings"),
	parent = panelRays, x = L + 6, y = -246, widget = "raysBase",
})
Header(panelPic, T("Пресет картинки", "Picture preset"), L, -370)
Carousel({
	keys = { "bright", "contrast", "satur", "warmth" },
	presets = {
		{ T("Стандарт WoW", "WoW standard"), { bright = 50, contrast = 50, satur = 50, warmth = 50 } },
		{ T("Живые краски", "Living colours"), { bright = 52, contrast = 58, satur = 62, warmth = 52 } },
		{ T("Кино", "Cinema"), { bright = 50, contrast = 62, satur = 45, warmth = 54 } },
		{ T("Мягкий вечер", "Soft evening"), { bright = 55, contrast = 44, satur = 50, warmth = 56 } },
		{ T("Север", "North"), { bright = 50, contrast = 54, satur = 42, warmth = 40 } },
		{ T("Полдень Азерота", "Azeroth noon"), { bright = 54, contrast = 52, satur = 56, warmth = 50 } },
	},
	slot = "lookMy", what = T("яркость и цвет", "the brightness and colour"),
	parent = panelPic, x = L + 6, y = -386, widget = "picBase",
})

-- The lesson of 1.6.2: with MSAA on the effects see no depth and quietly stop. Say it in the menu.
local msaaWarn = home:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
msaaWarn:SetPoint("BOTTOMLEFT", 16, 14)
msaaWarn:SetWidth(600)
msaaWarn:SetJustifyH("LEFT")
msaaWarn:SetTextColor(1.0, 0.35, 0.35)
msaaWarn:SetText(T("Включено сглаживание (MSAA): туман, лучи и ночь не работают без глубины. Выключите сглаживание: Меню игры → Система → Графика.",
	"Anti-aliasing (MSAA) is on: the fog, the rays and the night cannot see depth. Turn anti-aliasing off: Game Menu → System → Graphics."))
msaaWarn:Hide()
widgets.msaa = { Refresh = function()
	local q = tonumber(GetCVar and (GetCVar("MSAAQuality") or GetCVar("gxMultisample")) or 0) or 0
	if q > (GetCVar and GetCVar("gxMultisample") and not GetCVar("MSAAQuality") and 1 or 0) then
		msaaWarn:Show()
	else
		msaaWarn:Hide()
	end
end }

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
authorButton:SetText(T("Стандартные настройки", "Standard settings"))
authorButton:SetScript("OnClick", function()
	Confirm(T("Вернуть стандартные настройки? Ваши нынешние заменятся. Пресеты останутся.", "Restore the standard settings? Your current ones are replaced. Presets stay."), function()
		panel.default()
		Say(T("стандартные настройки вернулись.", "the standard settings are back."))
	end)
end)

-- The self-heal (/gu fix, 1.6.9): mends everything the addon side can reach and names what it did. The
-- shaders cannot be touched from Lua; for them it points at the two known killers (MSAA, a stale install).
local function SelfHeal()
	local did = {}
	if checkView then
		checkView = false
		did[#did + 1] = T("выключен вид проверки", "check view off")
	end
	if preview then
		CancelPreview()
		did[#did + 1] = T("сброшен предпросмотр", "preview cancelled")
	end
	for k, v in pairs(DEFAULTS) do
		if type(v) == "number" and type(DB[k]) ~= "number" then
			DB[k] = v
			did[#did + 1] = T("исправлена настройка ", "healed setting ") .. k
		end
	end
	if type(DB.presets) ~= "table" then
		DB.presets = {}
		did[#did + 1] = T("восстановлен список пресетов", "presets list restored")
	end
	PlaceMinimapButton()
	if DB.chatBack then
		ChatBack()
	end
	UpdateZone()
	Refresh()
	Paint()
	Say(T("самолечение: ", "self-heal: ") .. (#did > 0 and table.concat(did, ", ") or T("поломок на стороне меню нет", "nothing broken on the menu side")) .. ".")
	local msaa = tonumber(GetCVar and (GetCVar("MSAAQuality") or GetCVar("gxMultisample")) or 0) or 0
	if msaa > 1 then
		Say(T("ВНИМАНИЕ: включено сглаживание (MSAA), туман, лучи и ночь не видят глубину. Выключите: Меню игры → Система → Графика → Сглаживание: Нет.",
			"WARNING: anti-aliasing (MSAA) is on, the fog, the rays and the night see no depth. Turn it off: Game Menu → System → Graphics."))
	end
	Say(T("если эффекты всё равно не работают: закройте игру и запустите GU-WOW.exe → «Установить» ещё раз, затем /gu check в игре.",
		"if the effects still do not work: close the game, run GU-WOW.exe → Install again, then /gu check in game."))
end

-- The bug report (1.6.9): a small window with a title and a description. Saving puts the text and a machine
-- snapshot into the saved variables; the game writes them to disk on logout, and GU-WOW.exe picks the report
-- up with the logs and opens a prefilled GitHub issue. The game itself cannot reach the internet.
local reportFrame
local function OpenReport()
	if reportFrame then
		reportFrame:Show()
		return
	end
	local fr = CreateFrame("Frame", "LegionGUReport", UIParent)
	reportFrame = fr
	fr:SetWidth(440)
	fr:SetHeight(372)
	fr:SetPoint("CENTER")
	fr:SetFrameStrata("DIALOG")
	fr:SetMovable(true)
	fr:EnableMouse(true)
	fr:RegisterForDrag("LeftButton")
	fr:SetScript("OnDragStart", fr.StartMoving)
	fr:SetScript("OnDragStop", fr.StopMovingOrSizing)
	local back = fr:CreateTexture(nil, "BACKGROUND")
	back:SetAllPoints(fr)
	if back.SetColorTexture then back:SetColorTexture(0, 0, 0, 0.85) else back:SetTexture(0, 0, 0, 0.85) end
	local head = fr:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	head:SetPoint("TOP", 0, -12)
	head:SetText(T("Сообщение об ошибке GUWOW!", "GUWOW! bug report"))
	local l1 = fr:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	l1:SetPoint("TOPLEFT", 16, -44)
	l1:SetText(T("Название ошибки:", "Title:"))
	local titleBox = CreateFrame("EditBox", "LegionGUReportTitle", fr, "InputBoxTemplate")
	titleBox:SetPoint("TOPLEFT", 24, -60)
	titleBox:SetWidth(396)
	titleBox:SetHeight(22)
	titleBox:SetAutoFocus(false)
	titleBox:SetMaxLetters(90)
	titleBox:SetScript("OnEscapePressed", titleBox.ClearFocus)
	titleBox:SetScript("OnHide", titleBox.ClearFocus)
	local l2 = fr:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	l2:SetPoint("TOPLEFT", 16, -92)
	l2:SetText(T("Что случилось и как повторить:", "What happened and how to repeat it:"))
	local textBox = CreateFrame("EditBox", "LegionGUReportText", fr)
	textBox:SetPoint("TOPLEFT", 24, -110)
	textBox:SetWidth(392)
	textBox:SetHeight(110)
	textBox:SetMultiLine(true)
	textBox:SetAutoFocus(false)
	textBox:SetMaxLetters(1200)
	textBox:SetFontObject(GameFontHighlightSmall)
	textBox:SetScript("OnEscapePressed", textBox.ClearFocus)
	textBox:SetScript("OnHide", textBox.ClearFocus)
	-- A bare multiline EditBox takes no clicks: a button-like catcher over its area passes the focus in.
	local textCatch = CreateFrame("Button", nil, fr)
	textCatch:SetPoint("TOPLEFT", 20, -106)
	textCatch:SetPoint("BOTTOMRIGHT", fr, "TOPRIGHT", -20, -226)
	textCatch:SetScript("OnClick", function()
		textBox:SetFocus()
	end)
	textBox:EnableMouse(true)
	textBox:SetScript("OnMouseDown", function(self)
		self:SetFocus()
	end)
	local tb = fr:CreateTexture(nil, "BORDER")
	tb:SetPoint("TOPLEFT", 20, -106)
	tb:SetPoint("BOTTOMRIGHT", fr, "TOPRIGHT", -20, -226)
	if tb.SetColorTexture then tb:SetColorTexture(1, 1, 1, 0.08) else tb:SetTexture(1, 1, 1, 0.08) end
	-- The warning before the reload: the player is told the interface blinks for a moment and why.
	local warn = fr:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	warn:SetPoint("BOTTOMLEFT", 16, 86)
	warn:SetWidth(408)
	warn:SetJustifyH("LEFT")
	warn:SetText(T("Для отправки GUWOW! снимет вашу конфигурацию и ошибки интерфейса и перезагрузит игровой интерфейс. Это займёт пару секунд, и вы вернётесь в игру.",
		"To send the report, GUWOW! takes your setup and interface errors and reloads the game interface. It takes a couple of seconds, and you are back in the game."))
	local note = fr:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	note:SetPoint("BOTTOMLEFT", warn, "TOPLEFT", 0, 6)
	note:SetWidth(408)
	note:SetJustifyH("LEFT")
	note:SetText(T("Служебные данные (версия, настройки, логи) прилагаются автоматически.",
		"The service data (version, settings, logs) is attached for you."))
	-- The screenshot (beta-1.0): the player frames the shot, the window hides for a second, the game takes a
	-- JPEG, and the helper attaches it to the issue. The moment is remembered so the helper picks the right file.
	local shotAt
	local shotNote = fr:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	shotNote:SetPoint("BOTTOMLEFT", 16, 62)
	shotNote:SetWidth(408)
	shotNote:SetJustifyH("LEFT")
	shotNote:SetTextColor(0.4, 1.0, 0.4)
	shotNote:Hide()
	Button(fr, T("Приложить снимок", "Attach a shot"), 16, -330, 136, function()
		local fmt = GetCVar and GetCVar("screenshotFormat")
		local q = GetCVar and GetCVar("screenshotQuality")
		if SetCVar then
			SetCVar("screenshotFormat", "jpeg")
			SetCVar("screenshotQuality", "9")
		end
		fr:Hide()
		After(0.25, function()
			Screenshot()
		end)
		After(1.2, function()
			if SetCVar then
				SetCVar("screenshotFormat", fmt or "jpeg")
				if q then
					SetCVar("screenshotQuality", q)
				end
			end
			shotAt = date("%Y-%m-%d %H:%M:%S")
			shotNote:SetText(T("Снимок сделан и приложится к отчёту.", "The shot is taken and goes with the report."))
			shotNote:Show()
			fr:Show()
		end)
	end)
	Button(fr, T("Отправить", "Send"), 158, -330, 140, function()
		titleBox:ClearFocus()
		textBox:ClearFocus()
		local build, _, _, iface = GetBuildInfo()
		DB.report = {
			v = VERSION, when = date("%Y-%m-%d %H:%M:%S"),
			title = string.gsub(titleBox:GetText() or "", "|", ""),
			text = string.gsub(textBox:GetText() or "", "|", ""),
			code = MakeCode(), fps = math.floor(GetFramerate() or 0),
			msaa = GetCVar and (GetCVar("MSAAQuality") or GetCVar("gxMultisample")) or "?",
			win = GetCVar and GetCVar("gxWindow") or "?", build = tostring(build) .. "/" .. tostring(iface),
			shot = shotAt,
		}
		DB.reportPending = true
		fr:Hide()
		-- The game writes saved variables to disk only on logout or a UI reload, and the support helper reads
		-- the disk: the reload hands the report over at once. The helper tells the outcome in a Windows balloon.
		-- The reload runs inside the click itself: the game ignores it from a timer, outside a key or mouse press.
		ReloadUI()
	end)
	Button(fr, T("Закрыть", "Close"), 304, -330, 116, function()
		fr:Hide()
	end)
	fr:Show()
end


-- The welcome page buttons, created here so SelfHeal and OpenReport already exist.
Button(home, T("Самолечение", "Self-heal"), 16, -350, 170, function() SelfHeal() end)
Button(home, T("Сообщить об ошибке", "Report a bug"), 196, -350, 170, function() OpenReport() end)

-- The support page (1.7.3): players did not find the report behind a button on the welcome page, so it has its own
-- line in the list of pages, the first one, with one big button.
local panelSupport = NewPage("LegionGUPanelSupport", "Сообщение в поддержку", "Message to support",
	"Что-то не так с картинкой или меню? Напишите автору, это пара минут.", "Something wrong with the picture or the menu? Write to the author, it takes a couple of minutes.")
local supportText = panelSupport:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
supportText:SetPoint("TOPLEFT", 16, -70)
supportText:SetWidth(600)
supportText:SetJustifyH("LEFT")
supportText:SetSpacing(4)
supportText:SetText(T("Как написать:\n1. Встаньте так, чтобы ошибка была видна на экране.\n2. Нажмите «Написать в поддержку».\n3. Коротко назовите ошибку и опишите, что вы делали.\n4. Нажмите «Приложить снимок», если ошибку видно глазами.\n5. Нажмите «Отправить». Интерфейс перезагрузится на пару секунд.\n\nВерсия игры, настройки GUWOW! и журналы прикладываются сами. Отчёт отправляет программа GU-WOW, она должна быть запущена.\n\nЕсли эффекты пропали совсем, сначала нажмите «Самолечение».",
	"How to write:\n1. Stand so that the bug is on the screen.\n2. Press «Write to support».\n3. Name the bug in a few words and describe what you were doing.\n4. Press «Attach a shot» if the bug can be seen.\n5. Press «Send». The interface reloads for a couple of seconds.\n\nThe game version, the GUWOW! settings and the logs go with it on their own. The GU-WOW program sends the report, so keep it running.\n\nIf the effects are gone completely, press «Self-heal» first."))
local supportButton = Button(panelSupport, T("Написать в поддержку", "Write to support"), 16, -300, 260, function() OpenReport() end)
supportButton:SetHeight(32)
Button(panelSupport, T("Самолечение", "Self-heal"), 290, -305, 170, function() SelfHeal() end)

-- The extras page.
local page = CreateFrame("Frame", "LegionGUPanel2", UIParent)
page.name = T("Дополнительно", "Extras")
page.parent = home.name
page:Hide()
local title2 = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title2:SetPoint("TOPLEFT", 16, -16)
title2:SetText("GUWOW!: " .. page.name)

local sub2 = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub2:SetPoint("TOPLEFT", title2, "BOTTOMLEFT", 0, -6)
sub2:SetWidth(590)
sub2:SetJustifyH("LEFT")
sub2:SetText(T("Стили и коды сначала только показываются. Сохраняет их кнопка «Применить». Готовые пресеты на странице «Основные».",
	"Styles and codes are only shown at first. «Apply» saves them. The ready presets are on the Main page."))

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
		Say(T("это не код GUWOW!.", "this is not a GUWOW! code."))
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

-- The photo page: only what works in photo mode and on the clean screenshot.
local pagePhoto = CreateFrame("Frame", "LegionGUPanel3", UIParent)
pagePhoto.name = T("Фоторежим", "Photo mode")
pagePhoto.parent = home.name
pagePhoto:Hide()
local title3 = pagePhoto:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title3:SetPoint("TOPLEFT", 16, -16)
title3:SetText("GUWOW!: " .. pagePhoto.name)
local sub3 = pagePhoto:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub3:SetPoint("TOPLEFT", title3, "BOTTOMLEFT", 0, -6)
sub3:SetText(T("Интерфейс прячется, персонаж в фокусе, фон размыт. Выход: Esc, Enter или сама клавиша фоторежима.",
	"The interface hides, your character stays in focus, the background is blurred. Leave with Esc, Enter or the photo key."))
Check(pagePhoto, "orbit", T("Медленный облёт камеры", "Slow camera orbit"), 16, -70)
Check(pagePhoto, "hideNames", T("Прятать имена над головами", "Hide names above heads"), 16, -96)
Check(pagePhoto, "cinema", T("Кинорамка", "Cinema bars"), 16, -122)
Check(pagePhoto, "bokeh", T("Боке огней на размытом фоне", "Bokeh of lights in the blur"), 16, -148)
Slider(pagePhoto, "photoBlur", T("Сила размытия", "Blur strength"), 336, -146, nil, nil, nil,
	T("Насколько размыт фон за персонажем в фоторежиме. 0 — фон резкий", "How blurred the background behind your character is in photo mode. 0 keeps it sharp"))
Slider(pagePhoto, "playBlur", T("Размытие дали в обычной игре", "Far blur in normal play"), 336, -200, nil, nil, nil,
	T("Дальний план за персонажем слегка размыт, как в объективе, и глазу спокойнее. Персонаж, всё рядом с ним и интерфейс остаются чёткими. 0 — выключено", "The far land behind your character is a little blurred, as through a lens, easier on the eyes. Your character, everything near and the interface stay sharp. 0 is off"))
Button(pagePhoto, T("Фоторежим", "Photo mode"), 330, -74, 150, GUWOW_TogglePhoto)
Button(pagePhoto, T("Чистый снимок", "Clean screenshot"), 330, -102, 150, GUWOW_Screenshot)
local photoPanelsNote = pagePhoto:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
photoPanelsNote:SetPoint("TOPLEFT", 16, -250)
photoPanelsNote:SetWidth(590)
photoPanelsNote:SetJustifyH("LEFT")
photoPanelsNote:SetText(T("Какие панели оставить в фоторежиме и насколько прозрачными, задаётся на странице «Панели», кнопка «Фоторежим».",
	"Which panels stay in photo mode and how see-through, is set on the «Panels» page, button «Photo mode»."))

-- The photo key right here (1.7.3): the player presses the button, then the key, and the game's own binding is set,
-- the same one as in Menu → Key Bindings. Esc cancels. A key that had another action loses it, the speech says which.
local keyLabel = pagePhoto:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
keyLabel:SetPoint("TOPLEFT", 16, -196)
keyLabel:SetWidth(300)
keyLabel:SetJustifyH("LEFT")
local function ShowPhotoKey()
	local k = GetBindingKey and GetBindingKey("GUWOW_PHOTO")
	keyLabel:SetText(T("Клавиша фоторежима: ", "Photo mode key: ") .. (k and (GetBindingText and GetBindingText(k, "KEY_") or k) or T("не назначена", "none")))
end
widgets.photoKey = { Refresh = ShowPhotoKey }
local catcher = CreateFrame("Button", "LegionGUKeyCatcher", pagePhoto, "UIPanelButtonTemplate")
catcher:SetWidth(220)
catcher:SetHeight(22)
catcher:SetPoint("TOPLEFT", 16, -212)
catcher:SetText(T("Назначить клавишу фоторежима", "Set the photo mode key"))
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, UNKNOWN = true }
local function StopCatch()
	catcher:EnableKeyboard(false)
	catcher:SetScript("OnKeyDown", nil)
	catcher:SetText(T("Назначить клавишу фоторежима", "Set the photo mode key"))
end
catcher:SetScript("OnClick", function(self)
	if InCombatLockdown() then
		Say(T("клавиши нельзя менять в бою.", "keys cannot be changed in combat."))
		return
	end
	self:SetText(T("Нажмите клавишу… (Esc — отмена)", "Press a key… (Esc cancels)"))
	self:EnableKeyboard(true)
	self:SetScript("OnKeyDown", function(_, key)
		if MODIFIERS[key] then
			return
		end
		StopCatch()
		if key == "ESCAPE" then
			return
		end
		local full = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
		local old = GetBindingAction and GetBindingAction(full)
		local was = GetBindingKey and GetBindingKey("GUWOW_PHOTO")
		if SetBinding(full, "GUWOW_PHOTO") then
			-- One key for photo mode: the old one is freed only after the new one is set.
			if was and was ~= full then
				SetBinding(was)
			end
			SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
			local lost = (old and old ~= "" and old ~= "GUWOW_PHOTO") and (T(" Прежнее действие этой клавиши снято: ", " The key's old action is cleared: ")
				.. (_G["BINDING_NAME_" .. old] or old) .. ".") or ""
			Say(T("фоторежим теперь на клавише ", "photo mode is now on ") .. full .. "." .. lost)
		else
			Say(T("эту клавишу игра назначить не дала.", "the game did not allow this key."))
		end
		ShowPhotoKey()
	end)
end)
catcher:SetScript("OnHide", StopCatch)
pagePhoto:SetScript("OnShow", function()
	GrowOptions()
	Refresh()
end)
pagePhoto:SetScript("OnHide", ShrinkOptions)

Header(page, T("Поведение и производительность", "Behaviour and performance"), 16, -252)
Check(page, "autoQuality", T("Автокачество: упрощать тяжёлое при низких кадрах", "Auto quality: lighten heavy effects at low FPS"), 16, -270)
Check(page, "zones", T("Атмосфера по зонам", "Atmosphere by zone"), 16, -296, function()
	UpdateZone()
end)
-- The chat over the fogged world: the game's own window shade, so the text does not sink into the textures.
-- The game's mechanism (FCF_SetWindowAlpha), so the player's later choice in the chat tab menu simply wins.
ChatBack = function()
	if not FCF_SetWindowAlpha then
		return
	end
	for i = 1, NUM_CHAT_WINDOWS or 10 do
		local f = _G["ChatFrame" .. i]
		if f then
			FCF_SetWindowAlpha(f, DB.chatBack and 0.35 or 0)
		end
	end
end
Check(page, "chatBack", T("Подложка под чатом, чтобы текст не тонул в мире", "A shade behind the chat, so the text does not sink into the world"), 16, -322, ChatBack)
Slider(page, "targetFps", T("Держать кадров не ниже", "Keep FPS at least"), 330, -274, 20, 120)
Slider(page, "mistFlow", T("Движение тумана: дымка плывёт", "Fog motion: the mist drifts"), 336, -320, nil, nil, 81,
	T("Низовой туман медленно течёт и дышит. 0 — неподвижный туман, как раньше", "The ground mist slowly flows and breathes. 0 keeps it still, as before"))

-- The panels page (1.7.3): how much of each game panel shows, in plain play and in photo mode, 100 whole, 0 gone.
local panelPanels = NewPage("LegionGUPanelPanels", "Панели", "Panels",
	"Прозрачная панель работает: клавиши и щелчки по её месту действуют. Чат виден целиком, пока вы пишете.",
	"A see-through panel works: its keys and clicks on its place still act. The chat shows whole while you type.")
local panelSliders = { ui_ = {}, photo_ = {}, game_ = {} }
local panelMode = "ui_"
local modeNote = panelPanels:CreateFontString(nil, "ARTWORK", "GameFontNormal")
modeNote:SetPoint("TOPLEFT", 490, -74)
local function ShowPanelMode(mode)
	panelMode = mode
	for m, list in pairs(panelSliders) do
		for _, s in ipairs(list) do
			if m == mode then
				s:Show()
			else
				s:Hide()
			end
		end
	end
	modeNote:SetText(mode == "ui_" and T("Сейчас: обычная игра", "Now: plain play")
		or mode == "game_" and T("Сейчас: игровой", "Now: play photo") or T("Сейчас: фоторежим", "Now: photo mode"))
end
Button(panelPanels, T("Обычная игра", "Plain play"), 16, -70, 150, function()
	ShowPanelMode("ui_")
end)
Button(panelPanels, T("Фоторежим", "Photo mode"), 172, -70, 150, function()
	ShowPanelMode("photo_")
end)
Button(panelPanels, T("Игровой фоторежим", "Play photo mode"), 328, -70, 150, function()
	ShowPanelMode("game_")
end)
for mode in pairs(panelSliders) do
	for i, g in ipairs(HIDE_GROUPS) do
		local s = Slider(panelPanels, mode .. g[1], g[2], i <= 5 and 20 or 340, -120 - ((i - 1) % 5) * 48, 0, 100, nil,
			mode == "ui_" and T("Сколько видно панели в обычной игре. 100 — целиком, 0 — не видно совсем",
				"How much of the panel shows in plain play. 100 whole, 0 not at all")
			or mode == "game_" and T("Сколько видно панели в игровом фоторежиме. Играть можно как обычно, прозрачная панель работает",
				"How much of the panel shows in the play photo mode. You play as usual, a see-through panel still works")
			or T("Сколько видно панели в фоторежиме. Все панели на 0 — интерфейс прячется целиком",
				"How much of the panel shows in photo mode. All panels at 0 hide the whole interface"),
			function()
				ApplyHide()
			end)
		table.insert(panelSliders[mode], s)
	end
end
ShowPanelMode("ui_")
Check(panelPanels, "panelWake", T("Под мышью панель видна целиком, в бою — панели боя", "A panel shows whole under the mouse, the fight panels in a fight"), 16, -366, ApplyHide)
Button(panelPanels, T("Показать все панели", "Show all panels"), 16, -400, 200, function()
	for _, g in ipairs(HIDE_GROUPS) do
		DB[panelMode .. g[1]] = panelMode == "photo_" and 0 or 100
	end
	ApplyHide()
	Refresh()
end)
Button(panelPanels, T("Игровой фоторежим: вкл/выкл", "Play photo mode: on/off"), 230, -400, 220, GUWOW_ToggleGame)
Check(panelPanels, "gamePhoto", T("Игровой фоторежим с размытием фона и кинорамкой", "Play photo mode with the background blur and the cinema bars"), 16, -430)


page:SetScript("OnShow", function()
	GrowOptions()
	Refresh()
end)
page:SetScript("OnHide", ShrinkOptions)
page.refresh = Refresh
guPages[1], guPages[2], guPages[3], guPages[4] = home, panel, page, pagePhoto
guPages[5], guPages[6], guPages[7], guPages[8] = panelAtmo, panelRays, panelNight, panelPic
guPages[9], guPages[10] = panelSupport, panelPanels
for _, f in ipairs({ panelAtmo, panelRays, panelNight, panelPic, panelSupport, panelPanels }) do
	f:SetScript("OnShow", function()
		GrowOptions()
		Refresh()
	end)
	f:SetScript("OnHide", ShrinkOptions)
	f.refresh = Refresh
	f.okay = function() end
	f.cancel = function() end
end
home:SetScript("OnShow", function()
	GrowOptions()
	Refresh()
end)
home:SetScript("OnHide", ShrinkOptions)

local category
if InterfaceOptions_AddCategory then
	InterfaceOptions_AddCategory(home)
	InterfaceOptions_AddCategory(panelSupport)
	InterfaceOptions_AddCategory(panel)
	InterfaceOptions_AddCategory(panelAtmo)
	InterfaceOptions_AddCategory(panelRays)
	InterfaceOptions_AddCategory(panelNight)
	InterfaceOptions_AddCategory(panelPic)
	InterfaceOptions_AddCategory(page)
	InterfaceOptions_AddCategory(panelPanels)
	InterfaceOptions_AddCategory(pagePhoto)
elseif Settings and Settings.RegisterCanvasLayoutCategory then
	category = Settings.RegisterCanvasLayoutCategory(home, home.name)
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
	elseif msg == "game" or msg == "игра" then
		GUWOW_ToggleGame()
	elseif msg == "shot" or msg == "снимок" then
		GUWOW_Screenshot()
	elseif msg == "check" or msg == "проверка" then
		checkView = not checkView
		Paint()
		if checkView then
			Say(T("вид проверки: близкое светлое, дальнее темнее, небо чёрное. Красная рамка = эффекты не видят глубину (чаще всего включено сглаживание). Выключить: /gu check.",
				"check view: near is bright, far is darker, the sky is black. A red border means the effects see no depth (usually anti-aliasing is on). Turn off: /gu check."))
		else
			Say(T("вид проверки выключен.", "the check view is off."))
		end
	elseif msg == "news" or msg == "новости" then
		StaticPopup_Show("GUWOW_NEWS")
	elseif msg == "fix" or msg == "лечение" then
		SelfHeal()
	elseif msg == "report" or msg == "ошибка" or msg == "support" or msg == "поддержка" then
		OpenReport()
	elseif msg ~= "" and msg ~= "menu" and msg ~= "меню" then
		-- «help» and any word the addon does not know: the list, so a mistyped command still shows the way.
		Say(T("/gu меню · /gu photo фоторежим · /gu game игровой фоторежим · /gu shot чистый снимок · /gu check проверка глубины · /gu fix самолечение · /gu report написать в поддержку · /gu news что нового",
			"/gu menu · /gu photo photo mode · /gu game play photo mode · /gu shot clean screenshot · /gu check depth check · /gu fix self-heal · /gu report write to support · /gu news what is new"))
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

PlaceMinimapButton = function()
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
		FitPages()
	end)
end)
mm:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
end)
mm:SetScript("OnClick", function(self, button)
	if button == "RightButton" then
		GUWOW_ToggleMod()
	elseif button == "MiddleButton" or IsShiftKeyDown() then
		GUWOW_TogglePhoto()
	elseif IsAltKeyDown() then
		GUWOW_ToggleGame()
	elseif IsControlKeyDown() then
		OpenReport()
	else
		OpenPanel()
	end
end)
mm:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("GUWOW! " .. VERSION)
	GameTooltip:AddLine(T("Левая кнопка: меню", "Left click: menu"), 1, 1, 1)
	GameTooltip:AddLine(T("Правая кнопка: включить или выключить", "Right click: on or off"), 1, 1, 1)
	GameTooltip:AddLine(T("Shift + левая или средняя: фоторежим", "Shift + left or middle click: photo mode"), 1, 1, 1)
	GameTooltip:AddLine(T("Alt + левая: игровой фоторежим", "Alt + left click: play photo mode"), 1, 1, 1)
	GameTooltip:AddLine(T("Ctrl + левая: написать в поддержку", "Ctrl + left click: write to support"), 0.4, 1, 0.4)
	GameTooltip:Show()
end)
mm:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

-- ---------------------------------------------------------------------------------------------------------------
-- The clock, indoors, flight and the frame rate change on their own: look four times a second.
-- ---------------------------------------------------------------------------------------------------------------

local ticker = CreateFrame("Frame")
local elapsed, slowFor, fastFor, panelWait = 0, 0, 0, 0
ticker:SetScript("OnUpdate", function(self, dt)
	-- The panels' goals ten times a second: the mouse comes and goes without an event, the raid frames appear only in
	-- a raid, and the minimap waits for the end of a fight. The fade itself runs every frame, a steady panel costs
	-- nothing.
	panelWait = panelWait - dt
	if DB and panelWait <= 0 then
		panelWait = 0.1
		PanelGoals()
		PanelFade(dt, true)
	elseif DB then
		PanelFade(dt, false)
	end
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
		mapUntil = GetTime() + 0.5
		UpdateZone()
		Paint()
		After(0.55, Paint)
	end)
end

local events = CreateFrame("Frame")
local greeted
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
			-- A corrupt or out-of-range number goes back to the default, so a broken save cannot wedge a slider.
			if type(v) == "number" and type(DB[k]) == "number" then
				local lo = k == "targetFps" and 20 or 0
				local hi = k == "targetFps" and 120 or (k == "style" and 7 or 100)
				if DB[k] < lo or DB[k] > hi then
					DB[k] = v
				end
			end
		end
		-- The three slots of 1.5.0 become the first presets, so nothing saved in them is lost.
		DB.presets = DB.presets or {}
		-- The ticked panels of the first 1.7.3 builds become panels at 0.
		if type(DB.hide) == "table" then
			for k, v in pairs(DB.hide) do
				if v == true and DEFAULTS["ui_" .. k] then
					DB["ui_" .. k] = 0
				end
			end
		end
		DB.hide = nil
		-- The player's own preset slots (1.7.0, 1.7.1): a broken save is dropped, not clamped, it is one button to remake.
		local SLOT_KEYS = { lookMy = { "bright", "contrast", "satur", "warmth" },
			raysMy = { "raysStrength", "rayDefinition", "raysOpen", "raysReach", "sunGlow" } }
		for slot, keys in pairs(SLOT_KEYS) do
			if DB[slot] then
				for _, k in ipairs(keys) do
					local v = DB[slot][k]
					if type(v) ~= "number" or v < 0 or v > 100 then
						DB[slot] = nil
						break
					end
				end
			end
		end
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
	if event == "PLAYER_ENTERING_WORLD" then
		ApplyHide()
		-- The chat shade, when it is on: the game keeps the alpha per window, this only reasserts the choice.
		-- A moment later too: the chat settings cache can land after this event and overwrite the alpha.
		if DB.chatBack then
			ChatBack()
			After(3, function()
				if DB.chatBack then
					ChatBack()
				end
			end)
		end
	end
	if event == "PLAYER_ENTERING_WORLD" and DB.newsSeen ~= VERSION then
		DB.newsSeen = VERSION
		After(6, function()
			StaticPopup_Show("GUWOW_NEWS")
		end)
	end
	-- Once a session, the way to support in the chat: players of the old clients did not find it in the menu.
	if event == "PLAYER_ENTERING_WORLD" and not greeted then
		greeted = true
		Say(T("меню: /gu или кнопка у миникарты. Написать в поддержку: /gu report или Ctrl + щелчок по кнопке у миникарты.",
			"menu: /gu or the minimap button. Write to support: /gu report or Ctrl + click on the minimap button."))
		-- WotLK 3.3.5: GU-WOW.addon32 finds the interface by the full screen glow's own pass. With the glow off the
		-- effects run over the finished picture, windows too (1.7.3). The player hears it at once, in the game.
		local major = tonumber(string.match(GetBuildInfo() or "", "^(%d+)")) or 7
		if major < 4 and GetCVar("ffxGlow") == "0" then
			StaticPopup_Show("GUWOW_GLOW")
		end
		if DB.reportPending then
			DB.reportPending = nil
			StaticPopup_Show("GUWOW_SENT")
		end
	end
	Layout()
	Paint()
end)
