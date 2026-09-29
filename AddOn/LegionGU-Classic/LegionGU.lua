-- GU-WOW by levan: the in-game menu for Classic 1.12. © 2026 levan, the author's licence (LICENSE-GUWOW.txt).
-- The same strip as the main addon (AddOn/LegionGU): 89 cells of 4 by 4 pixels in the top left corner, one bit per
-- colour channel, read and covered by LegionGUBridge. 1.12 runs Lua 5.0 and has no options window for addons, so
-- this is a file of its own: the menu is a window opened by /guwow and the minimap button. Lua 5.0 has no # and no %,
-- a loop variable is one for the whole loop, and the script handlers get this, event and arg1, not parameters.

local VERSION = "1.7.5-release"
local CELL = 4
local CELLS = 89

local RU = GetLocale() == "ruRU"
local function T(ru, en)
	return RU and ru or en
end

-- The remainder for any sign: math.mod keeps the sign of a.
local function Mod(a, b)
	local r = math.mod(a, b)
	if r < 0 then
		r = r + b
	end
	return r
end

local function Say(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd200GUWOW!:|r " .. text)
end

-- The standard settings, the preset «Levan Soft»: the owner's own look, neutral and soft, the same on every client
-- (taken from the live Legion game on 2026-09-28).
local DEFAULTS = {
	master = true, fog = true, weather = true, wet = true, rays = true, night = true, eye = true,
	zones = true, autoQuality = false, targetFps = 45, orbit = false, hideNames = true, cinema = true, style = 0,
	chatBack = true,
	fogThickness = 27, fogDistance = 100, mist = 30, mistDensity = 40, raysStrength = 80,
	nightDarkness = 25, nightDepth = 41, lightGlow = 50, caveDarkness = 6,
	sharpness = 15, grade = 75, vignette = 55, ao = 75,
	hazeStrength = 24, hdrStrength = 50, grain = 29, bokeh = false, photoBlur = 30,
	mistHigh = 80, rayDefinition = 20, mistFlow = 10,
	bright = 60, contrast = 40, satur = 50, warmth = 50,
	raysOpen = 70, raysReach = 60, sunGlow = 60, mistNear = 0,
	lightThreshold = 50, lightRadius = 50, motionBlur = 0,
	-- 1.7.3: the far land softly blurred in normal play, the photo mode lens at its own strength (0 off).
	playBlur = 0,
	-- 1.7.3: a panel shows whole under the mouse, and the fight panels in a fight (see PanelAlpha).
	panelWake = true,
}
-- 1.7.3: how much of each game panel shows, 0..100, in plain play (ui_) and in photo mode (photo_). All photo
-- values at 0 keep photo mode as it was: the whole interface hides.
for _, k in ipairs({ "bars", "player", "target", "party", "minimap", "chat", "buffs", "quests", "castbar" }) do
	DEFAULTS["ui_" .. k], DEFAULTS["photo_" .. k] = 100, 0
end
-- The order of the values in the strip, the same as LEGIONGU_CTL_* in the shaders (after the flags).
local VALUES = { "fogThickness", "fogDistance", "mist", "raysStrength", "nightDarkness", "lightGlow",
	"caveDarkness", "sharpness", "grade", "vignette", "mistDensity" }
-- The look a ready preset sets; the personal dials of the picture and the rays stay the player's.
local LOOK = { "fog", "rays", "night", "weather", "wet", "eye", "fogThickness", "fogDistance", "mist", "mistDensity",
	"raysStrength", "nightDarkness", "nightDepth", "lightGlow", "caveDarkness", "sharpness", "grade", "vignette", "ao",
	"style", "hazeStrength", "hdrStrength", "grain", "mistHigh", "rayDefinition", "mistFlow", "mistNear" }

-- The ready presets of the main addon.
local BASE_PRESETS = {
	{ "Levan Soft", {} },
	{ "Deep Atmosphere", { fogThickness = 10, mist = 70, mistDensity = 45, raysStrength = 100, nightDarkness = 80,
		nightDepth = 70, lightGlow = 100, caveDarkness = 75, sharpness = 25, grade = 80, ao = 90, hazeStrength = 30,
		hdrStrength = 15, grain = 10, mistHigh = 40, rayDefinition = 55, mistNear = 25 } },
	{ "Vivid Adventure", { fogThickness = 10, mist = 20, mistDensity = 35, nightDarkness = 20, nightDepth = 25,
		sharpness = 45, grade = 90, vignette = 30, hdrStrength = 40, grain = 0, style = 4 } },
	{ "Moonlight", { fogThickness = 20, mist = 45, mistDensity = 45, nightDarkness = 60, nightDepth = 55, lightGlow = 80,
		grade = 90, vignette = 50, hdrStrength = 45, grain = 20, mistHigh = 60, style = 2 } },
	{ "Misty Dawn", { fogThickness = 45, fogDistance = 80, mist = 90, mistDensity = 65, raysStrength = 90, grade = 85,
		sharpness = 10, vignette = 35, hazeStrength = 20, hdrStrength = 30, grain = 15, mistHigh = 90, mistNear = 30, style = 1 } },
	{ "Pure Game", { fogThickness = 5, mist = 10, mistDensity = 30, raysStrength = 50, nightDarkness = 10, nightDepth = 10,
		lightGlow = 30, caveDarkness = 0, sharpness = 10, grade = 40, vignette = 15, ao = 40, hazeStrength = 0,
		hdrStrength = 0, grain = 0, mistHigh = 20, mistNear = 0, style = 0 } },
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
	{ "More FPS", { wet = false, eye = false, rays = false, mist = 0, ao = 0, sharpness = 0, hazeStrength = 0, grain = 0, mistHigh = 0 } },
	{ "Northern Frost", { fogThickness = 20, fogDistance = 90, mist = 55, mistDensity = 45, nightDarkness = 45, grade = 80,
		sharpness = 25, vignette = 40, hdrStrength = 45, grain = 15, mistHigh = 60, style = 2 } },
	{ "Warm Night Lamps", { nightDarkness = 55, nightDepth = 50, lightGlow = 100, caveDarkness = 30, grade = 90,
		vignette = 55, hdrStrength = 50, grain = 25, style = 1 } },
	{ "Soft Watercolor", { fogThickness = 35, fogDistance = 85, mist = 50, mistDensity = 35, sharpness = 0, grade = 70,
		vignette = 25, hdrStrength = 20, grain = 0, style = 6 } },
}
for _, p in ipairs(BASE_PRESETS) do
	local full = {}
	for _, k in ipairs(LOOK) do
		full[k] = DEFAULTS[k]
	end
	for k, v in pairs(p[2]) do
		full[k] = v
	end
	p[2] = full
end

local DB
-- A ready preset tried with the arrows: on screen until «Apply» or «Cancel», never saved by itself.
local preview, previewName
local photo = false
-- Photo mode with some panels kept (the photo dials, 1.7.3): their rectangles still go to the shader.
local photoPanels = false
local checkView = false
local lowQuality = false
local inInstance = false
local zoneKind
local widgets = {}
local menu

-- A small timer: 1.12 has no C_Timer.
local pending = {}
local timers = CreateFrame("Frame")
timers:SetScript("OnUpdate", function()
	for i = table.getn(pending), 1, -1 do
		local p = pending[i]
		p.t = p.t - arg1
		if p.t <= 0 then
			table.remove(pending, i)
			p.f()
		end
	end
end)
local function After(seconds, f)
	table.insert(pending, { t = seconds, f = f })
end

-- The second row of the strip carries the interface for the effects to leave alone (see UIRects below): a
-- signature, UI_RECTS rectangles of four coordinates 0..511 in three cells each, a checksum of two cells. 972
-- pixels long, so it fits a screen of 1024.
local UI_RECTS = 20
local UI_CELLS = 1 + UI_RECTS * 12 + 2

-- The strip. No parent: it stays on screen with the interface hidden (Alt+Z), when the shader still needs it.
local strip = CreateFrame("Frame", "LegionGUStrip")
strip:SetFrameStrata("TOOLTIP")
strip:SetWidth(UI_CELLS * CELL)
strip:SetHeight(2 * CELL)
local cells, uiCells = {}, {}
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

local function Bits(i, v)
	cells[i]:SetTexture(Mod(math.floor(v / 4), 2), Mod(math.floor(v / 2), 2), Mod(v, 2), 1)
end

-- A value 0..63 in two cells, the high bits first.
local function Cell(i, v)
	Bits(i, math.floor(v / 8))
	Bits(i + 1, Mod(v, 8))
end

-- The height of the screen in real pixels, so one unit of the strip is one pixel.
local function ScreenHeight()
	local res
	if GetCurrentResolution and GetScreenResolutions then
		local i = GetCurrentResolution()
		if i and i > 0 then
			res = ({ GetScreenResolutions() })[i]
		end
	end
	res = res or GetCVar("gxResolution")
	local h
	if res then
		local _, _, s = string.find(res, "%d+x(%d+)")
		h = tonumber(s)
	end
	return h or 1080
end

local layoutHeight
local function Layout()
	local h = ScreenHeight()
	if h == layoutHeight then
		return
	end
	layoutHeight = h
	-- A cell of 3 units: the screen is 768 units high whatever its pixels, and the shader reads a cell as
	-- BUFFER_HEIGHT / 256 pixels. A maximized window is shorter than the resolution by the title bar and the
	-- taskbar, and a strip scaled to the resolution drifted off the cells there: no effects, the strip in sight.
	strip:SetScale(0.75)
	strip:ClearAllPoints()
	strip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Atmosphere by zone. 1.12 has no map area ids, so the kind of land goes by the zone's name, English and Russian.
-- ---------------------------------------------------------------------------------------------------------------

local KIND_MODS = {
	swamp = { mist = 1.3, mistDensity = 1.2, fogThickness = 1.15 },
	forest = { mist = 1.15 },
	desert = { fogThickness = 0.7, mist = 0.4 },
	snow = { fogThickness = 1.1, mist = 0.8 },
	fire = { fogThickness = 0.8, mist = 0.3 },
	city = { mist = 0.5 },
}
local ZONE_KINDS = {
	swamp = { "Swamp of Sorrows", "Dustwallow Marsh", "Wetlands", "Болото Печали", "Пылевые топи", "Болотина" },
	forest = { "Elwynn Forest", "Duskwood", "Teldrassil", "Ashenvale", "Feralas", "Stranglethorn Vale", "Silverpine Forest",
		"Tirisfal Glades", "Darkshore", "Un'Goro Crater", "Moonglade", "Элвиннский лес", "Сумеречный лес", "Тельдрассил",
		"Ясеневый лес", "Фералас", "Тернистая долина", "Серебряный бор", "Тирисфальские леса", "Темные берега",
		"Кратер Ун'Горо", "Лунная поляна" },
	desert = { "Tanaris", "Silithus", "Badlands", "Desolace", "Thousand Needles", "The Barrens", "Durotar", "Танарис",
		"Силитус", "Бесплодные земли", "Пустоши", "Тысяча Игл", "Степи", "Дуротар" },
	snow = { "Winterspring", "Dun Morogh", "Alterac Mountains", "Зимние Ключи", "Дун Морог", "Альтеракские горы" },
	fire = { "Burning Steppes", "Searing Gorge", "Blasted Lands", "Пылающие степи", "Тлеющее ущелье", "Выжженные земли" },
	city = { "Stormwind City", "Orgrimmar", "Ironforge", "Thunder Bluff", "Undercity", "Darnassus", "Штормград",
		"Оргриммар", "Стальгорн", "Громовой Утес", "Подгород", "Дарнас" },
}
local ZONES = {}
for kind, names in pairs(ZONE_KINDS) do
	for _, n in ipairs(names) do
		ZONES[n] = kind
	end
end

local function UpdateZone()
	zoneKind = GetRealZoneText and ZONES[GetRealZoneText() or ""] or nil
	inInstance = IsInInstance and IsInInstance() and true or false
end

-- A value on screen: the preview's while one is on, the player's own otherwise.
local function V(key)
	if preview and preview[key] ~= nil then
		return preview[key]
	end
	return DB[key]
end

-- A value as the shader gets it: nudged by the zone, and off for the heavy parts in low quality. The dungeon
-- darkness works in dungeons only: 1.12 lights its rooms far dimmer than Legion, and to the shader a tavern or the
-- halls of Ironforge look like a cave (no sky for a few seconds, a dark frame), so any room went as dark as night.
local QUALITY_OFF = { ao = true, mist = true, sharpness = true }
local function Effective(key)
	local v = V(key)
	if DB.zones and zoneKind and KIND_MODS[zoneKind][key] then
		v = v * KIND_MODS[zoneKind][key]
	end
	if lowQuality and QUALITY_OFF[key] then
		v = 0
	end
	if key == "caveDarkness" and not inInstance then
		v = 0
	end
	return math.max(0, math.min(100, v))
end

-- ---------------------------------------------------------------------------------------------------------------
-- The strip
-- ---------------------------------------------------------------------------------------------------------------

-- What only the game knows: 1 live, 2 indoors, 8 photo mode, 16 wet ground on, 32 world map open; the time of day
-- 0..63 for 0..24 h. 1.12 has no flight and no facing, so those stay 0.
local lastState, lastTime
local function GameState()
	local s = 1
	if IsIndoors and IsIndoors() then
		s = s + 2
	end
	if photo then
		s = s + 8
	end
	if V("wet") and not lowQuality then
		s = s + 16
	end
	if WorldMapFrame and WorldMapFrame:IsShown() then
		s = s + 32
	end
	local h, m = GetGameTime()
	return s, Mod(math.floor(((h or 12) + (m or 0) / 60) * 63 / 24 + 0.5), 64)
end

local function Code(v)
	return math.floor(v * 63 / 100 + 0.5)
end

-- The chat window in screen shares, 0..63 each, for the heat haze to leave alone.
local function ChatRect()
	local f = ChatFrame1
	if not f or not f:GetLeft() then
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
	Bits(0, 0)
	Bits(1, 7)
	Bits(2, 5)
	local flags = (DB.master and 1 or 0) + (V("fog") and 2 or 0) + (V("rays") and 4 or 0)
		+ (V("night") and 8 or 0) + (V("weather") and 16 or 0) + ((V("eye") and not lowQuality) and 32 or 0)
	Cell(3, flags)
	local sum = flags
	for i, key in ipairs(VALUES) do
		local v = Code(Effective(key))
		Cell(3 + 2 * i, v)
		sum = sum + v
	end
	local state, time = GameState()
	lastState, lastTime = state, time
	local hot = zoneKind == "desert" or zoneKind == "fire"
	local haze, hdr = V("hazeStrength") or 0, V("hdrStrength") or 0
	local switches = (haze > 0 and 1 or 0) + (hot and 2 or 0) + (hdr > 0 and 4 or 0) + (DB.bokeh and 8 or 0)
		+ (checkView and 16 or 0)
	local chatL, chatT, chatR, chatB = ChatRect()
	local extra = { state, time, Code(V("nightDepth")), Code(Effective("ao")), (V("style") or 0) + (DB.cinema and 8 or 0),
		Code(V("grain") or 0), Code(DB.photoBlur or 35), switches, Code(haze), Code(hdr), 0,
		Code(V("mistHigh") or 0), Code(V("rayDefinition") or 0), Code(V("mistFlow") or 0),
		Code(V("bright") or 50), Code(V("contrast") or 50), Code(V("satur") or 50), Code(V("warmth") or 50),
		Code(V("raysOpen") or 45), Code(V("raysReach") or 50), Code(V("sunGlow") or 50), Code(V("mistNear") or 0),
		chatL, chatT, chatR, chatB, Code(V("lightThreshold") or 50), Code(V("lightRadius") or 50), Code(V("motionBlur") or 0),
		Code(V("playBlur") or 0) }
	local n = table.getn(VALUES)
	for i, v in ipairs(extra) do
		Cell(3 + 2 * (n + i), v)
		sum = sum + v
	end
	Cell(CELLS - 2, Mod(sum, 64))
end

-- ---------------------------------------------------------------------------------------------------------------
-- The interface the effects leave alone. 1.12 draws the windows into the same frame as the world, and REST is
-- Legion's only, so without this the fog and the rays lay over them. The second strip row tells the shader the
-- rectangles of what is on screen: open windows first, each of its own, then the bars in groups.
-- A frame's bounds are often much wider than its art: the unit frames hold a portrait and a panel of bars with
-- empty world round them, the stance and pet bars span the whole bar width for one or two buttons. The world in
-- there stayed without fog, a box plainly seen around the window. So the bars go by their buttons and the unit
-- frames by their portrait and their bars, each grown by `grow` units to the art's rim.
-- ---------------------------------------------------------------------------------------------------------------

local function Numbered(prefix, count, suffix)
	local t = {}
	for i = 1, count do
		table.insert(t, prefix .. i .. (suffix or ""))
	end
	return t
end

local UI_GROUPS = {}
for _, n in ipairs({ "GUWOWMenu", "GameMenuFrame", "OptionsFrame", "SoundOptionsFrame", "UIOptionsFrame",
	"KeyBindingFrame", "StaticPopup1", "StaticPopup2", "CharacterFrame", "SpellBookFrame", "TalentFrame",
	"QuestLogFrame", "FriendsFrame", "MacroFrame", "GossipFrame", "QuestFrame", "MerchantFrame", "TaxiFrame",
	"MailFrame", "BankFrame", "TradeFrame", "AuctionFrame", "TradeSkillFrame", "CraftFrame", "ClassTrainerFrame",
	"LootFrame", "HelpFrame", "DressUpFrame", "ItemTextFrame", "GameTooltip" }) do
	table.insert(UI_GROUPS, { n })
end
local unitGrow = 6
for _, g in ipairs({
	Numbered("ContainerFrame", 12),
	{ "ChatFrame1", "ChatFrame2", "ChatFrame3", "ChatFrame4", "ChatFrame5", "ChatFrame6", "ChatFrame7", "ChatFrameEditBox" },
	{ "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight" },
	{ "MainMenuBarLeftEndCap" },
	{ "MainMenuBarRightEndCap" },
	Numbered("ShapeshiftButton", 10),
	Numbered("PetActionButton", 10),
	{ "MultiBarRight", "MultiBarLeft" },
	{ "PlayerPortrait", "PlayerLevelText", grow = unitGrow },
	{ "PlayerName", "PlayerFrameHealthBar", "PlayerFrameManaBar", grow = unitGrow },
	{ "TargetPortrait", "TargetLevelText", grow = unitGrow },
	{ "TargetName", "TargetFrameHealthBar", "TargetFrameManaBar", grow = unitGrow },
	{ "TargetofTargetFrame" },
	{ "PetFrame" },
	Numbered("PartyMemberFrame", 4),
	{ "MinimapCluster" },
	{ "BuffFrame", "TemporaryEnchantFrame" },
	{ "CastingBarFrame" },
}) do
	table.insert(UI_GROUPS, g)
end

local function UIBits(i, v)
	uiCells[i]:SetTexture(Mod(math.floor(v / 4), 2), Mod(math.floor(v / 2), 2), Mod(v, 2), 1)
end

-- A coordinate 0..511 in three cells, the high bits first.
local function UICell(i, v)
	UIBits(i, math.floor(v / 64))
	UIBits(i + 1, Mod(math.floor(v / 8), 8))
	UIBits(i + 2, Mod(v, 8))
end

-- A visible group's rectangle in the units of the frames on UIParent, with a few pixels of margin; nil if nothing
-- is shown. The scale goes by the frames' own scales up to UIParent. The screen is measured by a frame stretched
-- over UIParent through the same calls: in the 1.12 client UIParent:GetWidth() disagrees with the frame
-- coordinates by the interface scale, and with uiScale 0.84 the rectangles came out 1.19 times too far from the corner.
local UI_PAD = 3
local uiProbe = CreateFrame("Frame", nil, UIParent)
uiProbe:SetAllPoints(UIParent)
-- A portrait or a name is a texture or a font string: no scale of its own, it takes its frame's.
local function ScaleToUI(f)
	local s = 1
	while f and f ~= UIParent do
		if f.GetScale then
			s = s * (f:GetScale() or 1)
		end
		f = f:GetParent()
	end
	return s
end
-- A panel the player made see-through (see ApplyHide) stays "visible" to the game: below half its alpha the effects
-- go over its place. So do the windows photo mode dims around the panels it keeps (see PhotoDim).
local hiddenFrames, ownAlpha, dimmed = {}, {}, {}
local function PanelHidden(f)
	while f and f ~= UIParent do
		if (hiddenFrames[f] and hiddenFrames[f] < 0.5) or dimmed[f] then
			return true
		end
		f = f.GetParent and f:GetParent()
	end
	return false
end
local function GroupRect(names)
	local l, t, r, b
	for _, n in ipairs(names) do
		local f = getglobal(n)
		if f and f.GetLeft and f.IsVisible and f:IsVisible() and f:GetLeft() and not PanelHidden(f) then
			local s = ScaleToUI(f)
			local fl, fr, ft, fb = f:GetLeft() * s, f:GetRight() * s, f:GetTop() * s, f:GetBottom() * s
			l, r = math.min(l or fl, fl), math.max(r or fr, fr)
			t, b = math.max(t or ft, ft), math.min(b or fb, fb)
		end
	end
	local grow = names.grow or 0
	if l then
		l, t, r, b = l - grow, t + grow, r + grow, b - grow
	end
	return l, t, r, b
end

-- A group over 60% of the screen is no window: a client or another addon stretched a frame over the world, and the
-- effects would leave the whole picture alone. Such a group is skipped. DB.uiSeen keeps what was sent last, each
-- group by its first frame in screen percent, and DB.uiSkipped what was skipped, for a report from a live game.
local function Clamp511(v)
	return math.max(0, math.min(511, v))
end
local UI_MAX_SHARE = 0.6
local lastUI
local function PaintUI()
	local x0, y0 = uiProbe:GetLeft() or 0, uiProbe:GetBottom() or 0
	local sw = (uiProbe:GetRight() or 0) - x0
	local sh = (uiProbe:GetTop() or 0) - y0
	local px = UI_PAD * sh / ScreenHeight()
	local coords, seen, skipped = {}, {}, {}
	-- Photo mode hides the interface with alpha, so everything is still "visible": no rectangles then, unless the
	-- player keeps some panels in photo mode (their see-through ones drop out in GroupRect).
	if (not photo or photoPanels) and sw > 0 and sh > 0 then
		for _, g in ipairs(UI_GROUPS) do
			if table.getn(coords) >= UI_RECTS * 4 then
				break
			end
			local l, t, r, b = GroupRect(g)
			if l then
				l, r, t, b = l - x0, r - x0, t - y0, b - y0
			end
			local share = l and (r - l) * (t - b) / (sw * sh) or 0
			local where = l and string.format("%s %d,%d-%d,%d", g[1], math.floor(l / sw * 100), math.floor((1 - t / sh) * 100),
				math.floor(r / sw * 100), math.floor((1 - b / sh) * 100))
			if l and share > UI_MAX_SHARE then
				table.insert(skipped, where)
			elseif l and r > l and t > b then
				table.insert(seen, where)
				table.insert(coords, Clamp511(math.floor((l - px) / sw * 511)))
				table.insert(coords, Clamp511(math.floor((1 - (t + px) / sh) * 511)))
				table.insert(coords, Clamp511(math.ceil((r + px) / sw * 511)))
				table.insert(coords, Clamp511(math.ceil((1 - (b - px) / sh) * 511)))
			end
		end
	end
	for i = table.getn(coords) + 1, UI_RECTS * 4 do
		coords[i] = 0
	end
	local key = table.concat(coords, ",")
	if key == lastUI then
		return
	end
	lastUI = key
	DB.uiSeen = table.concat(seen, "; ")
	DB.uiScreen = string.format("%dx%d, UIParent %dx%d", sw, sh, UIParent:GetWidth(), UIParent:GetHeight())
	if table.getn(skipped) > 0 then
		DB.uiSkipped = table.concat(skipped, "; ")
	end
	UIBits(0, 5)
	local sum = 0
	for i, v in ipairs(coords) do
		UICell(1 + 3 * (i - 1), v)
		sum = sum + v
	end
	sum = Mod(sum, 64)
	UIBits(UI_CELLS - 2, math.floor(sum / 8))
	UIBits(UI_CELLS - 1, Mod(sum, 8))
end

-- Twenty times a second: a window opens, closes and moves without an event 1.12 is sure to have, and a quarter of a
-- second of fog over a freshly opened window shows. The cells change only when a rectangle does.
local uiWait = 0
local uiWatch = CreateFrame("Frame")
uiWatch:SetScript("OnUpdate", function()
	uiWait = uiWait - arg1
	if DB and uiWait <= 0 then
		uiWait = 0.05
		PaintUI()
	end
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Photo mode and the clean screenshot
-- ---------------------------------------------------------------------------------------------------------------

-- The names over heads. A console variable a client lacks is skipped: 1.12 builds differ in them.
local NAME_CVARS = { "UnitNameOwn", "UnitNameNPC", "UnitNamePlayer", "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName" }
local savedNames
local function Names(show)
	if show then
		if savedNames then
			for k, v in pairs(savedNames) do
				pcall(SetCVar, k, v)
			end
			savedNames = nil
		end
	elseif not savedNames then
		savedNames = {}
		for _, k in ipairs(NAME_CVARS) do
			local ok, v = pcall(GetCVar, k)
			if ok and v then
				savedNames[k] = v
				pcall(SetCVar, k, "0")
			end
		end
	end
end

-- The minimap draws its blips past the interface transparency, so the icons stayed on a clean screen: the map
-- itself hides for photo mode and the shot, and comes back only if it was shown.
local mmHidden = false
local function MinimapOff()
	if Minimap and Minimap:IsShown() then
		Minimap:Hide()
		mmHidden = true
	end
end
local function MinimapBack()
	if mmHidden and Minimap then
		Minimap:Show()
		mmHidden = false
	end
end

-- The panels the player hides in plain play (1.7.3), each on its own, from the tab «Панели». A hidden panel goes
-- transparent, as the whole interface does in photo mode, and keeps its place, so its keys and clicks still work.
-- 1.12 has no hooksecurefunc and no secure frames: the frame's own SetAlpha is wrapped instead, so the game's fades
-- (the chat tabs, the cast bar, the party frames on range) keep a hidden frame at 0.
local HIDE_GROUPS = {
	{ "bars", T("Панели заклинаний", "Action bars"), { "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight",
		"MultiBarRight", "MultiBarLeft" } },
	{ "player", T("Портрет персонажа и питомца", "Player and pet frames"), { "PlayerFrame", "PetFrame" } },
	{ "target", T("Портрет цели", "Target frame"), { "TargetFrame", "TargetofTargetFrame" } },
	{ "party", T("Группа", "Party"), Numbered("PartyMemberFrame", 4) },
	{ "minimap", T("Миникарта", "Minimap"), { "MinimapCluster" } },
	{ "chat", T("Чат", "Chat"), { "ChatFrameMenuButton", "ChatFrame1", "ChatFrame2", "ChatFrame3", "ChatFrame4",
		"ChatFrame5", "ChatFrame6", "ChatFrame7", "ChatFrame1Tab", "ChatFrame2Tab", "ChatFrame3Tab", "ChatFrame4Tab",
		"ChatFrame5Tab", "ChatFrame6Tab", "ChatFrame7Tab" } },
	{ "buffs", T("Эффекты на персонаже", "Buffs and debuffs"), { "BuffFrame", "TemporaryEnchantFrame" } },
	{ "quests", T("Список заданий", "Quest tracker"), { "QuestWatchFrame" } },
	{ "castbar", T("Полоса заклинания", "Cast bar"), { "CastingBarFrame" } },
}
local mmByPanel = false
local function Typing()
	return ChatFrameEditBox and ChatFrameEditBox:IsShown()
end
-- The panels that matter in a fight: with «wake» on they show whole while the player fights.
local FIGHT = { bars = true, player = true, target = true, party = true, castbar = true }
local fighting = false
-- A group's frames under the mouse: the frame's own rectangle, so a see-through panel still answers.
local function MouseOver(names)
	local cx, cy = GetCursorPosition()
	for _, n in ipairs(names) do
		local f = getglobal(n)
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
-- How much of a group shows now, 0..1: its dial in plain play or in photo mode, whole when the player types in the
-- chat, points at the panel or fights (the fight panels).
local function PanelAlpha(g)
	local key = g[1]
	local a = (photo and DB["photo_" .. key] or DB["ui_" .. key] or 100) / 100
	if a >= 1 then
		return 1
	end
	if key == "chat" and Typing() then
		return 1
	end
	if DB.panelWake and ((fighting and FIGHT[key]) or MouseOver(g[3])) then
		return 1
	end
	return a
end
-- Each group's alpha on screen and the one it goes to: under the mouse or in a fight a panel comes up softly and
-- goes back slower still, the eye follows it. A dial, photo mode or the chat set it at once.
local panelGoal, panelNow = {}, {}
local FADE_IN, FADE_OUT = 3, 1.25
local function PanelGoals()
	for _, g in ipairs(HIDE_GROUPS) do
		panelGoal[g[1]] = PanelAlpha(g)
	end
	-- The minimap blips draw past the transparency (see MinimapOff), so a map faded to 0 hides itself.
	if Minimap and not photo then
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
-- get their alpha too.
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
				local f = getglobal(name)
				if f and f.SetAlpha then
					if a < 1 then
						if not ownAlpha[f] then
							ownAlpha[f] = f.SetAlpha
							f.SetAlpha = function(self, v)
								ownAlpha[self](self, hiddenFrames[self] and math.min(v, hiddenFrames[self]) or v)
							end
						end
						if hiddenFrames[f] ~= a then
							hiddenFrames[f] = a
							ownAlpha[f](f, a)
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
-- Every other window on UIParent (the panels' own frames go by their dials), to 0 and back as it was.
local panelFrame = nil
local function PhotoDim(on)
	if on then
		if not panelFrame then
			-- A panel inside another window keeps that window too, or the kept panel would go with it.
			panelFrame = {}
			for _, g in ipairs(HIDE_GROUPS) do
				for _, n in ipairs(g[3]) do
					local f = getglobal(n)
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

local function Photo(on)
	if on == photo then
		return
	end
	photo = on
	if on then
		if menu then
			menu:Hide()
		end
		-- The photo dials: panels the player keeps in photo mode stay, at their own transparency. The rest of the
		-- interface goes to 0 frame by frame: UIParent at 0 would take the kept panels with it.
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

local Refresh
function GUWOW_ToggleMod()
	if not DB then
		return
	end
	DB.master = not DB.master
	Refresh()
	Paint()
	Say(DB.master and T("включён", "on") or T("выключен", "off"))
end

-- The interface and the strip hide for a moment (the shader keeps the last settings), the game takes the shot.
-- Without the strip the shader knows of no interface, so the effects cover the whole picture.
function GUWOW_Screenshot()
	local wasPhoto = photo
	if not wasPhoto then
		UIParent:SetAlpha(0)
		MinimapOff()
	end
	strip:Hide()
	After(0.15, function()
		Screenshot()
		After(0.3, function()
			strip:Show()
			if not wasPhoto and not photo then
				UIParent:SetAlpha(1)
				MinimapBack()
			end
		end)
	end)
end

BINDING_HEADER_GUWOW = "GUWOW!"
BINDING_NAME_GUWOW_TOGGLE = T("Включить или выключить GUWOW!", "Turn GUWOW! on or off")
BINDING_NAME_GUWOW_PHOTO = T("Фоторежим (прячет интерфейс, размывает фон)", "Photo mode (hides the interface, blurs the background)")
BINDING_NAME_GUWOW_SHOT = T("Чистый снимок экрана", "Clean screenshot")

-- ---------------------------------------------------------------------------------------------------------------
-- The menu: a window of its own with a page per theme
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

-- The full screen glow off (see PLAYER_ENTERING_WORLD): one click turns it on.
StaticPopupDialogs["GUWOW_GLOW"] = {
	text = T("GUWOW!: в настройках графики выключено полноэкранное свечение. Без него эффекты обходят окна игры квадратами, и вокруг грифонов, чата и карты видны тёмные рамки.\n\nВключить свечение сейчас?",
		"GUWOW!: the full screen glow is off in the video settings. Without it the effects go around the game's windows in squares, and dark frames show around the gryphons, the chat and the map.\n\nTurn the glow on now?"),
	button1 = T("Включить", "Turn on"),
	button2 = CANCEL or "Cancel",
	OnAccept = function()
		pcall(SetCVar, "ffxGlow", "1")
		Say(T("свечение включено. Если рамки остались, перезапустите игру.", "the glow is on. If the frames stay, restart the game."))
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
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
}
-- Yes or no before a change that replaces the player's settings. The action runs only on «Accept».
local confirmAction
StaticPopupDialogs["GUWOW_CONFIRM"] = {
	text = "%s",
	button1 = ACCEPT or "OK",
	button2 = CANCEL or "Cancel",
	OnAccept = function()
		local f = confirmAction
		confirmAction = nil
		if f then
			f()
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}
local function Confirm(text, onYes)
	confirmAction = onYes
	StaticPopup_Show("GUWOW_CONFIRM", text)
end

-- A change during a preview tunes the preview: «Apply» saves it with the change, «Cancel» brings back the player's own.
local function Set(key, v)
	if preview and preview[key] ~= nil then
		preview[key] = v
	else
		DB[key] = v
	end
end

local function Text(parent, text, x, y, font, width)
	local s = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
	s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	if width then
		s:SetWidth(width)
		s:SetJustifyH("LEFT")
	end
	s:SetText(text)
	return s
end

local widgetCount = 0
local function Check(parent, key, label, x, y, onClick)
	widgetCount = widgetCount + 1
	local name = "GUWOWClassicCheck" .. widgetCount
	local c = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
	c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	getglobal(name .. "Text"):SetText(label)
	c:SetScript("OnClick", function()
		Set(key, this:GetChecked() and true or false)
		if onClick then
			onClick()
		end
		Paint()
	end)
	c.Refresh = function(self)
		-- 1.12 takes 1 or nil here.
		self:SetChecked(V(key) and 1 or nil)
	end
	widgets[name] = c
	return c
end

-- warn: from this value on a small orange note under the slider says artifacts are possible.
-- tip: a plain-words hint in a tooltip over the slider, what the dial does in the game.
local function Slider(parent, key, label, x, y, lo, hi, warn, tip)
	widgetCount = widgetCount + 1
	lo, hi = lo or 0, hi or 100
	local name = "GUWOWClassicSlider" .. widgetCount
	local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	s:SetWidth(250)
	s:SetMinMaxValues(lo, hi)
	s:SetValueStep(1)
	getglobal(name .. "Low"):SetText(tostring(lo))
	getglobal(name .. "High"):SetText(tostring(hi))
	local text = getglobal(name .. "Text")
	local warnText
	if warn then
		warnText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		warnText:SetPoint("TOP", s, "BOTTOM", 0, 3)
		warnText:SetTextColor(1.0, 0.55, 0.1)
		warnText:SetText(T("значения от " .. warn .. " могут добавлять артефакты", "values of " .. warn .. " and up may add artifacts"))
		warnText:Hide()
	end
	s:SetScript("OnValueChanged", function()
		local v = math.floor(this:GetValue() + 0.5)
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
		Paint()
	end)
	if tip then
		s:SetScript("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetText(label, 1, 0.82, 0)
			GameTooltip:AddLine(tip, 1, 1, 1, 1)
			GameTooltip:Show()
		end)
		s:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end
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
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

menu = CreateFrame("Frame", "GUWOWMenu", UIParent)
menu:SetWidth(640)
menu:SetHeight(476)
menu:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
menu:SetFrameStrata("DIALOG")
menu:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 } })
menu:EnableMouse(true)
menu:SetMovable(true)
menu:RegisterForDrag("LeftButton")
menu:SetScript("OnDragStart", function()
	this:StartMoving()
end)
menu:SetScript("OnDragStop", function()
	this:StopMovingOrSizing()
end)
menu:SetScript("OnShow", function()
	Refresh()
end)
menu:Hide()
-- Esc closes the window, as any game window.
table.insert(UISpecialFrames, "GUWOWMenu")
Text(menu, "GUWOW! " .. VERSION, 20, -18, "GameFontNormalLarge")
local close = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, -6)

local PAGE_NAMES = { T("Основные", "Main"), T("Атмосфера", "Atmosphere"), T("Лучи", "Rays"), T("Ночь", "Night"),
	T("Картинка", "Picture"), T("Фото", "Photo"), T("Поддержка", "Support"), T("Панели", "Panels") }
local PAGE_SUPPORT, PAGE_PANELS = 7, 8
local pages, tabs = {}, {}
local function ShowPage(n)
	for i = 1, table.getn(pages) do
		if i == n then
			pages[i]:Show()
			tabs[i]:LockHighlight()
		else
			pages[i]:Hide()
			tabs[i]:UnlockHighlight()
		end
	end
end
for i = 1, table.getn(PAGE_NAMES) do
	local n = i
	local p = CreateFrame("Frame", nil, menu)
	p:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, -76)
	p:SetWidth(640)
	p:SetHeight(390)
	pages[n] = p
	tabs[n] = Button(menu, PAGE_NAMES[n], 20 + (n - 1) * 74, -44, 72, function()
		ShowPage(n)
	end)
end
local L, R = 26, 316

-- Main: the switch, the ready presets, the standard settings and the behaviour.
local pMain = pages[1]
Check(pMain, "master", T("Включить GUWOW!", "Enable GUWOW!"), 20, -4)
Text(pMain, T("Пресет", "Preset"), 24, -48)
local presetLabel = Text(pMain, "", 104, -48, "GameFontHighlight", 150)
local presetIndex = 1

-- The ready preset the on-screen look is exactly equal to, or nothing for the player's own mix.
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
end
local function ShowPreset(d)
	presetIndex = Mod(presetIndex - 1 + d, table.getn(BASE_PRESETS)) + 1
	local p = BASE_PRESETS[presetIndex]
	preview, previewName = {}, p[1]
	for k, v in pairs(p[2]) do
		preview[k] = v
	end
	Refresh()
	Paint()
end
local function EndPreview(keep)
	if not preview then
		return
	end
	if keep then
		for k, v in pairs(preview) do
			DB[k] = v
		end
		Say(T("пресет «", "the preset «") .. previewName .. T("» применён и сохранён.", "» is applied and saved."))
	else
		Say(T("предпросмотр отменён. На экране снова ваши настройки.", "preview cancelled. Your own settings are back on screen."))
	end
	preview, previewName = nil, nil
	Refresh()
	Paint()
end
Button(pMain, "<", 74, -44, 24, function()
	ShowPreset(-1)
end)
Button(pMain, ">", 258, -44, 24, function()
	ShowPreset(1)
end)
local applyButton = Button(pMain, T("Применить", "Apply"), 290, -44, 110, function()
	EndPreview(true)
end)
local cancelButton = Button(pMain, T("Отменить", "Cancel"), 404, -44, 110, function()
	EndPreview(false)
end)
local previewNote = Text(pMain, T("Это предпросмотр: «Применить» оставит пресет, «Отменить» вернёт ваши настройки.",
	"This is a preview: Apply keeps the preset, Cancel brings your settings back."), 24, -74, "GameFontNormalSmall", 540)
widgets.preset = { Refresh = function()
	if preview then
		presetLabel:SetText(previewName)
		applyButton:Enable()
		cancelButton:Enable()
		previewNote:Show()
		return
	end
	local i, name = MatchingPreset()
	if i then
		presetIndex = i
	end
	presetLabel:SetText(name or T("Свои настройки", "Custom"))
	applyButton:Disable()
	cancelButton:Disable()
	previewNote:Hide()
end }
Button(pMain, T("Стандартные настройки", "Standard settings"), 24, -100, 200, function()
	Confirm(T("Вернуть стандартные настройки? Ваши нынешние заменятся.", "Restore the standard settings? Your current ones are replaced."), function()
		preview, previewName = nil, nil
		for k, v in pairs(DEFAULTS) do
			DB[k] = v
		end
		UpdateZone()
		Refresh()
		Paint()
		Say(T("стандартные настройки вернулись.", "the standard settings are back."))
	end)
end)

-- The chat over the fogged world: the game's own window shade, so the text does not sink into the textures.
local function ChatBack()
	if not FCF_SetWindowAlpha then
		return
	end
	for i = 1, NUM_CHAT_WINDOWS or 7 do
		local f = getglobal("ChatFrame" .. i)
		if f then
			FCF_SetWindowAlpha(f, DB.chatBack and 0.35 or 0)
		end
	end
end
Text(pMain, T("Поведение и производительность", "Behaviour and performance"), 24, -140)
Check(pMain, "autoQuality", T("Автокачество: упрощать тяжёлое при низких кадрах", "Auto quality: lighten heavy effects at low FPS"), 20, -158)
Check(pMain, "zones", T("Атмосфера по зонам", "Atmosphere by zone"), 20, -184, UpdateZone)
Check(pMain, "chatBack", T("Подложка под чатом", "A shade behind the chat"), 20, -210, ChatBack)
Slider(pMain, "targetFps", T("Держать кадров не ниже", "Keep FPS at least"), R, -170, 20, 120)
Text(pMain, T("F11 включает и выключает весь мод, свою клавишу можно задать в назначении клавиш.\nКнопка у миникарты: левая открывает меню, правая включает и выключает, Shift + левая даёт фоторежим, Ctrl + левая открывает поддержку.\nНаведите мышь на ползунок: подсказка скажет, что он меняет в игре.\nКоманды чата: /guwow меню · /guwow photo · /guwow shot · /guwow report поддержка · /guwow check проверка глубины.",
	"F11 toggles the whole mod; your own key is in the key bindings.\nThe minimap button: left opens the menu, right toggles, Shift + left starts photo mode, Ctrl + left opens support.\nHover over a slider: the hint says what it changes in the game.\nChat commands: /guwow menu · /guwow photo · /guwow shot · /guwow report support · /guwow check depth check."),
	24, -250, "GameFontHighlightSmall", 590)

-- Atmosphere.
local pAtmo = pages[2]
Check(pAtmo, "fog", T("Туман", "Fog"), L - 6, -4)
Slider(pAtmo, "fogThickness", T("Густота тумана", "Fog density"), L, -44, nil, nil, nil,
	T("Сколько тумана в воздухе. 0 — воздух чистый, 100 — дали почти не видно", "How much fog hangs in the air. 0 is clear air, 100 hides the distance"))
Slider(pAtmo, "fogDistance", T("Дальность тумана", "Fog distance"), L, -86, nil, nil, nil,
	T("Где туман становится стеной. Меньше — стена ближе к вам, больше — дальше", "Where the fog turns into a wall. Lower brings it closer, higher pushes it away"))
Slider(pAtmo, "mist", T("Низовой туман", "Ground mist"), L, -128, nil, nil, nil,
	T("Дымка, которая лежит в низинах, над водой и под деревьями", "The haze lying in hollows, over water and under the trees"))
Slider(pAtmo, "mistDensity", T("Плотность низового тумана", "Ground mist thickness"), L, -170, nil, nil, 86,
	T("Насколько эта дымка непрозрачная. Выше — как вата", "How solid that haze is. Higher looks like cotton wool"))
Slider(pAtmo, "mistHigh", T("Туман с высоты", "Mist from a height"), L, -212, nil, nil, nil,
	T("Сколько дымки видно внизу, когда вы на горе. 0 — сверху всё чисто", "How much haze you see below from a hill. 0 keeps the view clear"))
Slider(pAtmo, "mistNear", T("Туман у ног", "Mist at the feet"), L, -254, nil, nil, 71,
	T("Стелется прямо под персонажем, без чистого круга. 0 выключает — как раньше", "Lies right under the character, no clear circle. 0 turns it off — as before"))
Slider(pAtmo, "mistFlow", T("Движение тумана", "Fog motion"), L, -296, nil, nil, 81,
	T("Низовой туман медленно течёт и дышит. 0 — неподвижный туман, как раньше", "The ground mist slowly flows and breathes. 0 keeps it still, as before"))
Check(pAtmo, "weather", T("Погодное настроение", "Weather mood"), R - 6, -4)
Check(pAtmo, "wet", T("Мокрая земля в дождь", "Wet ground in rain"), R - 6, -28)
Slider(pAtmo, "ao", T("Тени в щелях", "Contact shadows"), R, -86, nil, nil, nil,
	T("Мягкие тени под камнями, травой и у стен: предметы стоят на земле, а не парят. Немного нагружает видеокарту", "Soft shadows under stones, grass and by walls: things sit on the ground. Costs a little GPU"))
Slider(pAtmo, "hazeStrength", T("Марево в пустынях", "Heat haze in deserts"), R, -128, nil, nil, 71,
	T("Воздух дрожит от жары в пустынях и у лавы. В других местах его нет", "The air shimmers with heat in deserts and by lava. Nowhere else"))

-- Rays.
local pRays = pages[3]
Check(pRays, "rays", T("Лучи солнца", "Sun rays"), L - 6, -4)
Slider(pRays, "raysStrength", T("Сила лучей", "Ray strength"), L, -44, nil, nil, nil,
	T("Насколько ярко светят лучи солнца сквозь кроны и облака. 0 — без лучей", "How bright the sun shafts through trees and clouds are. 0 turns them off"))
Slider(pRays, "rayDefinition", T("Чёткость лучей", "Ray definition"), L, -86, nil, nil, 71,
	T("0 — мягкое свечение в воздухе. Выше — отдельные снопы света с тенью между ними", "0 is a soft glow in the air. Higher gives separate shafts with shade between them"))
Slider(pRays, "raysOpen", T("Лучи в открытом небе", "Rays in the open"), L, -128, nil, nil, 71,
	T("Сила лучей в поле и на снегу, где нет крон. Выше — заметнее", "Ray strength over fields and snow, with no canopy. Higher is bolder"))
Slider(pRays, "raysReach", T("Длина лучей", "Ray length"), R, -44, nil, nil, 81,
	T("Как далеко от солнца тянутся лучи. Меньше — короткие, больше — через весь экран", "How far the shafts reach from the sun. Lower is short, higher crosses the screen"))
Slider(pRays, "sunGlow", T("Свечение солнца в тумане", "Sun glow in the fog"), R, -86, nil, nil, 76,
	T("Светлое пятно вокруг солнца, когда оно в тумане", "The bright patch round the sun when it is in the fog"))

-- Night.
local pNight = pages[4]
Check(pNight, "night", T("Ночь и огни", "Night and lights"), L - 6, -4)
Slider(pNight, "nightDarkness", T("Темнота ночи", "Night darkness"), L, -44, nil, nil, nil,
	T("Насколько темнеет мир ночью по игровым часам. 0 — ночь как в игре", "How dark the world gets at night by the game clock. 0 keeps the game's own night"))
Slider(pNight, "nightDepth", T("Глубина ночи", "Night depth"), L, -86, nil, nil, nil,
	T("Дополнительная тьма поверх «Темноты ночи»: 0 обычная ночь, 100 глухая", "Extra darkness over the night darkness: 0 a plain night, 100 pitch dark"))
Slider(pNight, "lightGlow", T("Свет огней", "Light glow"), R, -44, nil, nil, nil,
	T("Насколько ярко ночью светят фонари, костры и окна. 0 — огни не светят сверх игры", "How bright lamps, fires and windows glow at night. 0 adds no glow"))
Slider(pNight, "caveDarkness", T("Темнота подземелий", "Dungeon darkness"), R, -86, nil, nil, nil,
	T("Насколько темно в пещерах и подземельях. 0 — как в игре", "How dark caves and dungeons are. 0 keeps the game's look"))
-- The lights' own dials (1.7.3): which objects glow and how far the glow spreads. 50 is the old look.
Slider(pNight, "lightThreshold", T("Что считать огнём (50 — как было)", "What counts as a light (50 — as before)"), L, -128, nil, nil, nil,
	T("Больше — светятся только настоящие фонари и костры. Меньше — светятся и тусклые предметы. Если ночью светится то, что не должно, прибавьте", "Higher: only real lamps and fires glow. Lower: dim things glow too. If wrong things glow at night, raise it"))
Slider(pNight, "lightRadius", T("Радиус свечения (50 — как было)", "Glow radius (50 — as before)"), R, -128, nil, nil, 86,
	T("Как далеко вокруг огня разливается свет. Меньше — аккуратный ореол, больше — широкое зарево", "How far the light spreads round a flame. Lower is a tight halo, higher a wide glow"))

-- Picture.
local pPic = pages[5]
Check(pPic, "eye", T("Привыкание глаз", "Eye adaptation"), L - 6, -4)
Slider(pPic, "sharpness", T("Резкость", "Sharpness"), L, -44, nil, nil, 61,
	T("Чётче края и мелкие детали: листва, камни, броня. Слишком много — появляется рябь", "Crisper edges and fine detail: leaves, stones, armour. Too much adds shimmer"))
Slider(pPic, "grade", T("Цвет по времени суток", "Time of day colour"), L, -86, nil, nil, nil,
	T("Золото вечера и утра, холод ночи: сила окраски по игровым часам", "The gold of the evening and the cool of the night, by the game clock"))
Slider(pPic, "vignette", T("Виньетка", "Vignette"), L, -128, nil, nil, nil,
	T("Лёгкое затемнение по углам экрана, как на фото. 0 — без него", "A light darkening in the screen corners, as on a photo. 0 turns it off"))
Slider(pPic, "bright", T("Яркость (50 — как в игре)", "Brightness (50 — the game's own)"), L, -170, nil, nil, 76,
	T("Общая яркость картинки. Если ночью слишком темно, прибавьте", "The overall brightness. If the night is too dark, raise it"))
Slider(pPic, "satur", T("Сочность цвета", "Colour richness"), L, -212, nil, nil, 81,
	T("Меньше — цвета спокойнее и ближе к серому, больше — ярче и насыщеннее", "Lower calms the colours towards grey, higher makes them richer"))
Slider(pPic, "hdrStrength", T("Кино-HDR", "Cinema HDR"), R, -44, nil, nil, nil,
	T("Картинка как в кино: тени глубже, яркое небо и блики не выгорают в белое", "A film look: deeper shadows, bright sky and highlights keep their detail"))
Slider(pPic, "grain", T("Плёночное зерно", "Film grain"), R, -86, nil, nil, 71,
	T("Мелкий шум как на плёнке. 0 — картинка чистая", "A fine noise as on film. 0 keeps the picture clean"))
-- Motion blur (1.7.3): the picture smears along the camera turn. 0 keeps it off.
Slider(pPic, "motionBlur", T("Размытие при движении", "Motion blur"), R, -128, nil, nil, 71,
	T("При быстром повороте камеры картинка слегка смазывается, как в кино. 0 — выключено. Интерфейс не размывается", "The picture smears a little on a fast camera turn, as in films. 0 is off. The interface stays sharp"))
Slider(pPic, "contrast", T("Контрастность", "Contrast"), R, -170, nil, nil, 76,
	T("Разница между светлым и тёмным. Больше — картинка резче, меньше — мягче", "The gap between light and dark. Higher is punchier, lower is softer"))
Slider(pPic, "warmth", T("Тепло картинки", "Picture warmth"), R, -212, nil, nil, nil,
	T("Меньше 50 — оттенок холодный, синеватый. Больше 50 — тёплый, золотистый", "Below 50 is a cold bluish tint, above 50 a warm golden one"))
Text(pPic, T("Цветовой стиль", "Colour style"), 24, -262)
local STYLE_NAMES = { T("Нет", "None"), T("Тёплый", "Warm"), T("Холодный", "Cold"), T("Плёнка", "Film"), T("Сочный", "Vivid"),
	T("Закат", "Sunset"), T("Сказка", "Fairy tale"), T("Нуар", "Noir") }
local styleButtons = {}
for i = 1, table.getn(STYLE_NAMES) do
	local style = i - 1
	styleButtons[i] = Button(pPic, STYLE_NAMES[i], 22 + (i - 1) * 69, -280, 67, function()
		Set("style", style)
		Refresh()
		Paint()
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

-- Photo mode.
local pPhoto = pages[6]
Text(pPhoto, T("Интерфейс прячется, фон размыт. Выход: Esc, Enter или сама клавиша фоторежима.",
	"The interface hides, the background is blurred. Leave with Esc, Enter or the photo key."), 24, -8, "GameFontHighlightSmall", 550)
Check(pPhoto, "orbit", T("Медленный облёт камеры", "Slow camera orbit"), 20, -30)
Check(pPhoto, "hideNames", T("Прятать имена над головами", "Hide names above heads"), 20, -56)
Check(pPhoto, "cinema", T("Кинорамка", "Cinema bars"), 20, -82)
Check(pPhoto, "bokeh", T("Боке огней на размытом фоне", "Bokeh of lights in the blur"), 20, -108)
Slider(pPhoto, "photoBlur", T("Сила размытия", "Blur strength"), R, -110)
Slider(pPhoto, "playBlur", T("Размытие дали в обычной игре", "Far blur in normal play"), R, -156, nil, nil, nil,
	T("Дальний план за персонажем слегка размыт, как в объективе, и глазу спокойнее. Персонаж, всё рядом с ним и интерфейс остаются чёткими. 0 — выключено", "The far land behind your character is a little blurred, as through a lens, easier on the eyes. Your character, everything near and the interface stay sharp. 0 is off"))
Button(pPhoto, T("Фоторежим", "Photo mode"), R, -34, 150, GUWOW_TogglePhoto)
Button(pPhoto, T("Чистый снимок", "Clean screenshot"), R, -62, 150, GUWOW_Screenshot)

-- The photo key right here (1.7.3): the player presses the button, then the key, and the game's own binding is set,
-- the same one as in Menu → Key Bindings. Esc cancels. A key that had another action loses it, the speech says which.
local keyLabel = Text(pPhoto, "", 24, -150, "GameFontHighlightSmall", 300)
local function ShowPhotoKey()
	local k = GetBindingKey and GetBindingKey("GUWOW_PHOTO")
	keyLabel:SetText(T("Клавиша фоторежима: ", "Photo mode key: ") .. (k or T("не назначена", "none")))
end
widgets.photoKey = { Refresh = ShowPhotoKey }
local CATCH_TEXT = T("Назначить клавишу фоторежима", "Set the photo mode key")
local catcher = Button(pPhoto, CATCH_TEXT, 20, -168, 230)
Text(pPhoto, T("Какие панели оставить в фоторежиме и насколько прозрачными, задаётся во вкладке «Панели», кнопка «Фоторежим».",
	"Which panels stay in photo mode and how see-through, is set on the «Panels» tab, button «Photo mode»."), 24, -204,
	"GameFontHighlightSmall", 550)
-- 1.12 names the modifiers on their own as SHIFT, CTRL and ALT; they only shape the key that follows.
local MODIFIERS = { SHIFT = true, CTRL = true, ALT = true, LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
	LALT = true, RALT = true, UNKNOWN = true }
local function StopCatch()
	catcher:EnableKeyboard(false)
	catcher:SetScript("OnKeyDown", nil)
	catcher:SetText(CATCH_TEXT)
end
catcher:SetScript("OnClick", function()
	this:SetText(T("Нажмите клавишу… (Esc — отмена)", "Press a key… (Esc cancels)"))
	this:EnableKeyboard(true)
	this:SetScript("OnKeyDown", function()
		local key = arg1
		if not key or MODIFIERS[key] then
			return
		end
		StopCatch()
		if key == "ESCAPE" then
			return
		end
		local full = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
		local old = GetBindingAction and GetBindingAction(full)
		local was = GetBindingKey and GetBindingKey("GUWOW_PHOTO")
		SetBinding(full, "GUWOW_PHOTO")
		-- 1.12 does not say whether the binding took: the key is asked back.
		if not GetBindingAction or GetBindingAction(full) == "GUWOW_PHOTO" then
			-- One key for photo mode: the old one is freed only after the new one is set.
			if was and was ~= full then
				SetBinding(was)
			end
			SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
			local lost = ""
			if old and old ~= "" and old ~= "GUWOW_PHOTO" then
				lost = T(" Прежнее действие этой клавиши снято: ", " The key's old action is cleared: ")
					.. (getglobal("BINDING_NAME_" .. old) or old) .. "."
			end
			Say(T("фоторежим теперь на клавише ", "photo mode is now on ") .. full .. "." .. lost)
		else
			Say(T("эту клавишу игра назначить не дала.", "the game did not allow this key."))
		end
		ShowPhotoKey()
	end)
end)
catcher:SetScript("OnHide", StopCatch)

-- The support page (1.7.3): players did not find the report, so it has its own tab with the form right on it.
-- «Send» writes the report into the saved variables and reloads the interface: the game writes them to disk only
-- then, and the GU-WOW helper reads the disk and sends the report on.
local pSupport = pages[PAGE_SUPPORT]
Text(pSupport, T("Как написать:\n1. Встаньте так, чтобы ошибка была видна на экране.\n2. Коротко назовите ошибку и опишите, что вы делали.\n3. Нажмите «Приложить снимок», если ошибку видно глазами.\n4. Нажмите «Отправить». Интерфейс перезагрузится на пару секунд.\nВерсия игры и настройки GUWOW! прикладываются сами. Отчёт отправляет программа GU-WOW, она должна быть запущена.",
	"How to write:\n1. Stand so that the bug is on the screen.\n2. Name the bug in a few words and describe what you were doing.\n3. Press «Attach a shot» if the bug can be seen.\n4. Press «Send». The interface reloads for a couple of seconds.\nThe game version and the GUWOW! settings go with it on their own. The GU-WOW program sends the report, so keep it running."),
	24, -4, "GameFontHighlightSmall", 590)
Text(pSupport, T("Ошибка в двух словах", "The bug in a few words"), 24, -108)
local titleBox = CreateFrame("EditBox", "GUWOWReportTitle", pSupport, "InputBoxTemplate")
titleBox:SetPoint("TOPLEFT", pSupport, "TOPLEFT", 30, -124)
titleBox:SetWidth(560)
titleBox:SetHeight(20)
titleBox:SetAutoFocus(false)
titleBox:SetMaxLetters(90)
Text(pSupport, T("Что вы делали и что увидели", "What you were doing and what you saw"), 24, -152)
local textBack = CreateFrame("Frame", nil, pSupport)
textBack:SetPoint("TOPLEFT", pSupport, "TOPLEFT", 22, -168)
textBack:SetWidth(576)
textBack:SetHeight(110)
textBack:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
textBack:SetBackdropColor(0, 0, 0, 0.6)
local textBox = CreateFrame("EditBox", "GUWOWReportText", textBack)
textBox:SetPoint("TOPLEFT", textBack, "TOPLEFT", 8, -8)
textBox:SetWidth(560)
textBox:SetHeight(94)
textBox:SetMultiLine(true)
textBox:SetAutoFocus(false)
textBox:SetMaxLetters(600)
textBox:SetFontObject(ChatFontNormal)
-- A click anywhere in the box puts the cursor there: the empty box is otherwise one line tall to the mouse.
textBack:EnableMouse(true)
textBack:SetScript("OnMouseDown", function()
	textBox:SetFocus()
end)
for _, box in ipairs({ titleBox, textBox }) do
	box:SetScript("OnEscapePressed", function()
		this:ClearFocus()
	end)
end
titleBox:SetScript("OnEnterPressed", function()
	textBox:SetFocus()
end)
titleBox:SetScript("OnTabPressed", function()
	textBox:SetFocus()
end)

local shotAt
local shotNote = Text(pSupport, "", 24, -318, "GameFontNormalSmall", 590)
shotNote:SetTextColor(0.4, 1.0, 0.4)
local function CVar(name)
	local ok, v = pcall(GetCVar, name)
	return ok and v or nil
end
-- The shot: the menu hides for a second, the game takes a JPEG, the helper finds it by the remembered moment.
Button(pSupport, T("Приложить снимок", "Attach a shot"), 22, -290, 150, function()
	titleBox:ClearFocus()
	textBox:ClearFocus()
	local fmt, q = CVar("screenshotFormat"), CVar("screenshotQuality")
	pcall(SetCVar, "screenshotFormat", "jpeg")
	pcall(SetCVar, "screenshotQuality", "9")
	menu:Hide()
	After(0.25, function()
		Screenshot()
	end)
	After(1.2, function()
		if fmt then
			pcall(SetCVar, "screenshotFormat", fmt)
		end
		if q then
			pcall(SetCVar, "screenshotQuality", q)
		end
		shotAt = date("%Y-%m-%d %H:%M:%S")
		shotNote:SetText(T("Снимок сделан и приложится к отчёту.", "The shot is taken and goes with the report."))
		menu:Show()
		ShowPage(PAGE_SUPPORT)
	end)
end)
-- The saved variables go through a pattern in the helper that ends a report at «}»: the player's text cannot.
local function Clean(s)
	s = string.gsub(s or "", "[|}]", "")
	return s
end
Button(pSupport, T("Отправить", "Send"), 178, -290, 150, function()
	titleBox:ClearFocus()
	textBox:ClearFocus()
	local version, build = GetBuildInfo()
	local settings = {}
	for k in pairs(DEFAULTS) do
		table.insert(settings, k .. "=" .. tostring(DB[k]))
	end
	table.sort(settings)
	DB.report = {
		v = VERSION, when = date("%Y-%m-%d %H:%M:%S"),
		title = Clean(titleBox:GetText()), text = Clean(textBox:GetText()),
		fps = math.floor(GetFramerate() or 0), build = tostring(version) .. "/" .. tostring(build),
		win = CVar("gxWindow") or "?", settings = Clean(table.concat(settings, " ")),
		shot = shotAt,
	}
	DB.reportPending = true
	-- The reload runs inside the click itself: the game ignores it from a timer, outside a key or mouse press.
	ReloadUI()
end)

-- The panels page (1.7.3): how much of each game panel shows, in plain play and in photo mode, 100 whole, 0 gone.
local pPanels = pages[PAGE_PANELS]
Text(pPanels, T("Прозрачная панель работает: клавиши и щелчки по её месту действуют. Чат виден целиком, пока вы пишете.",
	"A see-through panel works: its keys and clicks on its place still act. The chat shows whole while you type."),
	24, -4, "GameFontHighlightSmall", 590)
local panelSliders = { ui_ = {}, photo_ = {} }
local panelMode = "ui_"
local modeNote = Text(pPanels, "", 330, -30, "GameFontNormal")
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
	modeNote:SetText(mode == "ui_" and T("Сейчас: обычная игра", "Now: plain play") or T("Сейчас: фоторежим", "Now: photo mode"))
end
Button(pPanels, T("Обычная игра", "Plain play"), 22, -26, 140, function()
	ShowPanelMode("ui_")
end)
Button(pPanels, T("Фоторежим", "Photo mode"), 168, -26, 140, function()
	ShowPanelMode("photo_")
end)
for mode in pairs(panelSliders) do
	for i, g in ipairs(HIDE_GROUPS) do
		local s = Slider(pPanels, mode .. g[1], g[2], i <= 5 and 24 or R + 4, -70 - Mod(i - 1, 5) * 44, 0, 100, nil,
			mode == "ui_" and T("Сколько видно панели в обычной игре. 100 — целиком, 0 — не видно совсем",
				"How much of the panel shows in plain play. 100 whole, 0 not at all")
			or T("Сколько видно панели в фоторежиме. Все панели на 0 — интерфейс прячется целиком",
				"How much of the panel shows in photo mode. All panels at 0 hide the whole interface"))
		table.insert(panelSliders[mode], s)
	end
end
ShowPanelMode("ui_")
Check(pPanels, "panelWake", T("Под мышью панель видна целиком, в бою — панели боя", "A panel shows whole under the mouse, the fight panels in a fight"), 20, -290)
Button(pPanels, T("Показать все панели", "Show all panels"), 22, -324, 200, function()
	for _, g in ipairs(HIDE_GROUPS) do
		DB[panelMode .. g[1]] = panelMode == "ui_" and 100 or 0
	end
	ApplyHide()
	Refresh()
end)

ShowPage(1)

-- /gu is the guild chat in the 1.12 client: the chat box switches to the guild at the space and the command never
-- comes here. The menu and the hints go by /guwow.
SLASH_LEGIONGU1 = "/guwow"
SlashCmdList["LEGIONGU"] = function(msg)
	msg = string.lower(msg or "")
	if msg == "photo" or msg == "фото" then
		GUWOW_TogglePhoto()
	elseif msg == "shot" or msg == "снимок" then
		GUWOW_Screenshot()
	elseif msg == "check" or msg == "проверка" then
		checkView = not checkView
		Paint()
		if checkView then
			Say(T("вид проверки: близкое светлое, дальнее темнее, небо чёрное. Красная рамка = эффекты не видят глубину. Выключить: /guwow check.",
				"check view: near is bright, far is darker, the sky is black. A red border means the effects see no depth. Turn off: /guwow check."))
		else
			Say(T("вид проверки выключен.", "the check view is off."))
		end
	elseif msg == "ui" or msg == "окна" then
		Say(T("окна, которые обходят эффекты: ", "windows the effects leave alone: ") .. ((DB.uiSeen or "") ~= "" and DB.uiSeen or "-"))
		Say(T("пропущены как слишком большие: ", "skipped as too large: ") .. (DB.uiSkipped or "-"))
		Say(T("экран: ", "screen: ") .. (DB.uiScreen or "-"))
	elseif msg == "report" or msg == "support" or msg == "поддержка" then
		menu:Show()
		ShowPage(PAGE_SUPPORT)
	elseif msg ~= "" and msg ~= "menu" and msg ~= "меню" then
		-- «help» and any word the addon does not know: the list, so a mistyped command still shows the way.
		Say(T("/guwow меню · /guwow photo фоторежим · /guwow shot чистый снимок · /guwow report написать в поддержку · /guwow check проверка глубины",
			"/guwow menu · /guwow photo photo mode · /guwow shot clean screenshot · /guwow report write to support · /guwow check depth check"))
	elseif menu:IsShown() then
		menu:Hide()
	else
		menu:Show()
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- The minimap button: left click the menu, right click the whole mod on or off, Shift+left or middle photo mode.
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
mmIcon:SetPoint("CENTER", mm, "CENTER", 0, 1)
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetWidth(53)
mmBorder:SetHeight(53)
mmBorder:SetPoint("TOPLEFT", mm, "TOPLEFT", 0, 0)
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local function PlaceMinimapButton()
	local a = math.rad(DB.minimapAngle or 200)
	mm:ClearAllPoints()
	mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
end
mm:SetScript("OnDragStart", function()
	this:SetScript("OnUpdate", function()
		local mx, my = Minimap:GetCenter()
		local cx, cy = GetCursorPosition()
		local s = Minimap:GetEffectiveScale()
		DB.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
		PlaceMinimapButton()
	end)
end)
mm:SetScript("OnDragStop", function()
	this:SetScript("OnUpdate", nil)
end)
mm:SetScript("OnClick", function()
	if arg1 == "RightButton" then
		GUWOW_ToggleMod()
	elseif arg1 == "MiddleButton" or IsShiftKeyDown() then
		GUWOW_TogglePhoto()
	elseif IsControlKeyDown() then
		menu:Show()
		ShowPage(PAGE_SUPPORT)
	elseif menu:IsShown() then
		menu:Hide()
	else
		menu:Show()
	end
end)
mm:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:AddLine("GUWOW! " .. VERSION)
	GameTooltip:AddLine(T("Левая кнопка: меню", "Left click: menu"), 1, 1, 1)
	GameTooltip:AddLine(T("Правая кнопка: включить или выключить", "Right click: on or off"), 1, 1, 1)
	GameTooltip:AddLine(T("Shift + левая или средняя: фоторежим", "Shift + left or middle click: photo mode"), 1, 1, 1)
	GameTooltip:AddLine(T("Ctrl + левая: написать в поддержку", "Ctrl + left click: write to support"), 1, 1, 1)
	GameTooltip:Show()
end)
mm:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

-- The game menu (Esc) gets a «Third-party mods» button under «Macros»: 1.12 has no options window for addons. A
-- client that moved the buttons around gets it under «Return to game». A label wider than the button widens it.
local gmButton = CreateFrame("Button", "GameMenuButtonGUWOW", GameMenuFrame, "GameMenuButtonTemplate")
gmButton:SetText(T("Сторонние модификации", "Third-party mods"))
local gmTextWidth = gmButton.GetTextWidth and gmButton:GetTextWidth()
if gmTextWidth and gmTextWidth + 16 > gmButton:GetWidth() then
	gmButton:SetWidth(gmTextWidth + 16)
end
local _, below
if GameMenuButtonLogout then
	_, below = GameMenuButtonLogout:GetPoint(1)
end
if GameMenuButtonMacros and below == GameMenuButtonMacros then
	gmButton:SetPoint("TOP", GameMenuButtonMacros, "BOTTOM", 0, -1)
	GameMenuButtonLogout:ClearAllPoints()
	GameMenuButtonLogout:SetPoint("TOP", gmButton, "BOTTOM", 0, -1)
else
	gmButton:SetPoint("TOP", GameMenuButtonContinue, "BOTTOM", 0, -1)
end
GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + 22)
gmButton:SetScript("OnClick", function()
	PlaySound("igMainMenuOption")
	HideUIPanel(GameMenuFrame)
	menu:Show()
end)

-- ---------------------------------------------------------------------------------------------------------------
-- The clock, indoors, the map and the frame rate change on their own: look four times a second.
-- ---------------------------------------------------------------------------------------------------------------

local ticker = CreateFrame("Frame")
local elapsed, slowFor, fastFor, sinceLayout = 0, 0, 0, 0
ticker:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.25 or not DB then
		return
	end
	local step = elapsed
	elapsed = 0
	-- The window size changes without an event 1.12 is sure to have: the layout is looked at every two seconds.
	sinceLayout = sinceLayout + step
	if sinceLayout >= 2 then
		sinceLayout = 0
		Layout()
	end
	-- Esc and Enter to chat end photo mode: the game menu and the chat line open under the hidden interface.
	if photo and (GameMenuFrame:IsShown() or (ChatFrameEditBox and ChatFrameEditBox:IsShown())) then
		Photo(false)
	end
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
	local s, t = GameState()
	if changed or s ~= lastState or t ~= lastTime then
		Paint()
	end
end)

local events = CreateFrame("Frame")
local greeted
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

-- The panels' goals ten times a second: the mouse comes and goes without an event, and a frame the game made or
-- reshown since (a new party member, a reloaded bar) takes its transparency too. The fade runs every frame, a steady
-- panel costs nothing.
local panelWait = 0
local panelWatch = CreateFrame("Frame")
panelWatch:SetScript("OnUpdate", function()
	panelWait = panelWait - arg1
	if DB and panelWait <= 0 then
		panelWait = 0.1
		PanelGoals()
		PanelFade(arg1, true)
	elseif DB then
		PanelFade(arg1, false)
	end
end)
events:SetScript("OnEvent", function()
	if event == "ADDON_LOADED" then
		if arg1 ~= "LegionGU" then
			return
		end
		LegionGUDB = LegionGUDB or {}
		DB = LegionGUDB
		for k, v in pairs(DEFAULTS) do
			if DB[k] == nil then
				DB[k] = v
			end
			-- A corrupt or out-of-range number goes back to the default, so a broken save cannot wedge a slider.
			if type(v) == "number" then
				local lo = k == "targetFps" and 20 or 0
				local hi = k == "targetFps" and 120 or (k == "style" and 7 or 100)
				if type(DB[k]) ~= "number" or DB[k] < lo or DB[k] > hi then
					DB[k] = v
				end
			end
		end
		if type(DB.hide) ~= "table" then
			DB.hide = {}
		end
		-- The ticked panels of the first 1.7.3 builds become panels at 0.
		for k, v in pairs(DB.hide) do
			if v == true and DEFAULTS["ui_" .. k] then
				DB["ui_" .. k] = 0
			end
		end
		DB.hide = nil
		PlaceMinimapButton()
	end
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		fighting = event == "PLAYER_REGEN_DISABLED"
		-- Only the goal: the fight panels come up with the same soft fade as under the mouse.
		PanelGoals()
		return
	end
	if not DB then
		return
	end
	if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		UpdateZone()
	end
	if event == "PLAYER_ENTERING_WORLD" and DB.chatBack then
		ChatBack()
	end
	if event == "PLAYER_ENTERING_WORLD" and not photo then
		ApplyHide()
	end
	-- Once a session, the way to support in the chat: players of the old clients did not find it in the menu.
	if event == "PLAYER_ENTERING_WORLD" and not greeted then
		greeted = true
		Say(T("меню: /guwow или кнопка у миникарты. Написать в поддержку: /guwow report или Ctrl + щелчок по кнопке у миникарты.",
			"menu: /guwow or the minimap button. Write to support: /guwow report or Ctrl + click on the minimap button."))
		-- GU-WOW.addon32 finds the interface by the full screen glow's own pass. With the glow off the effects run
		-- over the finished picture and leave out whole rectangles around the windows: dark squares around the
		-- gryphons, the chat and the map (1.7.3). The player hears it at once, in the game.
		local ok, glow = pcall(GetCVar, "ffxGlow")
		if ok and glow == "0" then
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
