-- GU-WOW by levan: the in-game menu for Classic 1.12. © 2026 levan, the author's licence (LICENSE-GUWOW.txt).
-- The same strip as the main addon (AddOn/LegionGU): 81 cells of 4 by 4 pixels in the top left corner, one bit per
-- colour channel, read and covered by LegionGUBridge. 1.12 runs Lua 5.0 and has no options window for addons, so
-- this is a file of its own: the menu is a window opened by /gu and the minimap button. Lua 5.0 has no # and no %,
-- a loop variable is one for the whole loop, and the script handlers get this, event and arg1, not parameters.

local VERSION = "public-release-beta-1.0"
local CELL = 4
local CELLS = 81

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

-- The standard settings, the same as in the main addon.
local DEFAULTS = {
	master = true, fog = true, weather = true, wet = true, rays = true, night = true, eye = true,
	zones = true, autoQuality = false, targetFps = 45, orbit = false, hideNames = true, cinema = true, style = 0,
	chatBack = true,
	fogThickness = 10, fogDistance = 100, mist = 70, mistDensity = 45, raysStrength = 100,
	nightDarkness = 80, nightDepth = 70, lightGlow = 100, caveDarkness = 75,
	sharpness = 25, grade = 80, vignette = 55, ao = 90,
	hazeStrength = 30, hdrStrength = 15, grain = 10, bokeh = false, photoBlur = 50,
	mistHigh = 40, rayDefinition = 55, mistFlow = 10,
	bright = 60, contrast = 55, satur = 50, warmth = 50,
	raysOpen = 45, raysReach = 50, sunGlow = 50, mistNear = 25,
}
-- The order of the values in the strip, the same as LEGIONGU_CTL_* in the shaders (after the flags).
local VALUES = { "fogThickness", "fogDistance", "mist", "raysStrength", "nightDarkness", "lightGlow",
	"caveDarkness", "sharpness", "grade", "vignette", "mistDensity" }
-- The look a ready preset sets; the personal dials of the picture and the rays stay the player's.
local LOOK = { "fog", "rays", "night", "weather", "wet", "eye", "fogThickness", "fogDistance", "mist", "mistDensity",
	"raysStrength", "nightDarkness", "nightDepth", "lightGlow", "caveDarkness", "sharpness", "grade", "vignette", "ao",
	"style", "hazeStrength", "hdrStrength", "grain", "mistHigh", "rayDefinition", "mistFlow", "mistNear" }

-- The ready presets of the main addon.
local BASE_PRESETS = {
	{ "Default", {} },
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
local checkView = false
local lowQuality = false
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
	strip:SetScale(768 / h)
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
end

-- A value on screen: the preview's while one is on, the player's own otherwise.
local function V(key)
	if preview and preview[key] ~= nil then
		return preview[key]
	end
	return DB[key]
end

-- A value as the shader gets it: nudged by the zone, and off for the heavy parts in low quality.
local QUALITY_OFF = { ao = true, mist = true, sharpness = true }
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
		chatL, chatT, chatR, chatB }
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
-- ---------------------------------------------------------------------------------------------------------------

local UI_GROUPS = {}
for _, n in ipairs({ "GUWOWMenu", "GameMenuFrame", "OptionsFrame", "SoundOptionsFrame", "UIOptionsFrame",
	"KeyBindingFrame", "StaticPopup1", "StaticPopup2", "CharacterFrame", "SpellBookFrame", "TalentFrame",
	"QuestLogFrame", "FriendsFrame", "MacroFrame", "GossipFrame", "QuestFrame", "MerchantFrame", "TaxiFrame",
	"MailFrame", "BankFrame", "TradeFrame", "AuctionFrame", "TradeSkillFrame", "CraftFrame", "ClassTrainerFrame",
	"LootFrame", "HelpFrame", "DressUpFrame", "ItemTextFrame", "GameTooltip" }) do
	table.insert(UI_GROUPS, { n })
end
for _, g in ipairs({
	{ "ContainerFrame1", "ContainerFrame2", "ContainerFrame3", "ContainerFrame4", "ContainerFrame5", "ContainerFrame6",
		"ContainerFrame7", "ContainerFrame8", "ContainerFrame9", "ContainerFrame10", "ContainerFrame11", "ContainerFrame12" },
	{ "ChatFrame1", "ChatFrame2", "ChatFrame3", "ChatFrame4", "ChatFrame5", "ChatFrame6", "ChatFrame7", "ChatFrameEditBox" },
	{ "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "PetActionBarFrame", "ShapeshiftBarFrame" },
	{ "MultiBarRight", "MultiBarLeft" },
	{ "PlayerFrame", "PetFrame" },
	{ "TargetFrame", "TargetofTargetFrame" },
	{ "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4" },
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

-- A visible group's rectangle in screen shares, top down, with a few pixels of margin; nil if nothing is shown.
local UI_PAD = 3
local function GroupRect(names)
	local l, t, r, b
	for _, n in ipairs(names) do
		local f = getglobal(n)
		if f and f:IsVisible() and f:GetLeft() then
			local s = f:GetEffectiveScale()
			local fl, fr, ft, fb = f:GetLeft() * s, f:GetRight() * s, f:GetTop() * s, f:GetBottom() * s
			l, r = math.min(l or fl, fl), math.max(r or fr, fr)
			t, b = math.max(t or ft, ft), math.min(b or fb, fb)
		end
	end
	return l, t, r, b
end

local lastUI
local function PaintUI()
	local sw = UIParent:GetWidth() * UIParent:GetEffectiveScale()
	local sh = UIParent:GetHeight() * UIParent:GetEffectiveScale()
	local px = UI_PAD * sh / ScreenHeight()
	local coords = {}
	-- Photo mode hides the interface with alpha, so everything is still "visible": no rectangles then.
	if not photo and sw > 0 and sh > 0 then
		for _, g in ipairs(UI_GROUPS) do
			if table.getn(coords) >= UI_RECTS * 4 then
				break
			end
			local l, t, r, b = GroupRect(g)
			if l and r > l and t > b then
				table.insert(coords, math.max(0, math.floor((l - px) / sw * 511)))
				table.insert(coords, math.max(0, math.floor((1 - (t + px) / sh) * 511)))
				table.insert(coords, math.min(511, math.ceil((r + px) / sw * 511)))
				table.insert(coords, math.min(511, math.ceil((1 - (b - px) / sh) * 511)))
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

local function Photo(on)
	if on == photo then
		return
	end
	photo = on
	if on then
		if menu then
			menu:Hide()
		end
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
	end
	strip:Hide()
	After(0.15, function()
		Screenshot()
		After(0.3, function()
			strip:Show()
			if not wasPhoto and not photo then
				UIParent:SetAlpha(1)
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
local function Slider(parent, key, label, x, y, lo, hi, warn)
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
menu:SetWidth(600)
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
	T("Картинка", "Picture"), T("Фото", "Photo") }
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
	p:SetWidth(600)
	p:SetHeight(390)
	pages[n] = p
	tabs[n] = Button(menu, PAGE_NAMES[n], 20 + (n - 1) * 94, -44, 92, function()
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
Text(pMain, T("F11 включает и выключает весь мод, свою клавишу можно задать в назначении клавиш.\nКнопка у миникарты: левая открывает меню, правая включает и выключает, Shift + левая даёт фоторежим.\nКоманды чата: /gu меню · /gu photo · /gu shot · /gu check проверка глубины.",
	"F11 toggles the whole mod; your own key is in the key bindings.\nThe minimap button: left opens the menu, right toggles, Shift + left starts photo mode.\nChat commands: /gu menu · /gu photo · /gu shot · /gu check depth check."),
	24, -260, "GameFontHighlightSmall", 550)

-- Atmosphere.
local pAtmo = pages[2]
Check(pAtmo, "fog", T("Туман", "Fog"), L - 6, -4)
Slider(pAtmo, "fogThickness", T("Густота тумана", "Fog density"), L, -44)
Slider(pAtmo, "fogDistance", T("Дальность тумана", "Fog distance"), L, -86)
Slider(pAtmo, "mist", T("Низовой туман", "Ground mist"), L, -128)
Slider(pAtmo, "mistDensity", T("Плотность низового тумана", "Ground mist thickness"), L, -170, nil, nil, 86)
Slider(pAtmo, "mistHigh", T("Туман с высоты", "Mist from a height"), L, -212)
Slider(pAtmo, "mistNear", T("Туман у ног", "Mist at the feet"), L, -254, nil, nil, 71)
Slider(pAtmo, "mistFlow", T("Движение тумана", "Fog motion"), L, -296, nil, nil, 81)
Check(pAtmo, "weather", T("Погодное настроение", "Weather mood"), R - 6, -4)
Check(pAtmo, "wet", T("Мокрая земля в дождь", "Wet ground in rain"), R - 6, -28)
Slider(pAtmo, "ao", T("Тени в щелях", "Contact shadows"), R, -86)
Slider(pAtmo, "hazeStrength", T("Марево в пустынях", "Heat haze in deserts"), R, -128, nil, nil, 71)

-- Rays.
local pRays = pages[3]
Check(pRays, "rays", T("Лучи солнца", "Sun rays"), L - 6, -4)
Slider(pRays, "raysStrength", T("Сила лучей", "Ray strength"), L, -44)
Slider(pRays, "rayDefinition", T("Чёткость лучей", "Ray definition"), L, -86, nil, nil, 71)
Slider(pRays, "raysOpen", T("Лучи в открытом небе", "Rays in the open"), L, -128, nil, nil, 71)
Slider(pRays, "raysReach", T("Длина лучей", "Ray length"), R, -44, nil, nil, 81)
Slider(pRays, "sunGlow", T("Свечение солнца в тумане", "Sun glow in the fog"), R, -86, nil, nil, 76)

-- Night.
local pNight = pages[4]
Check(pNight, "night", T("Ночь и огни", "Night and lights"), L - 6, -4)
Slider(pNight, "nightDarkness", T("Темнота ночи", "Night darkness"), L, -44)
Slider(pNight, "nightDepth", T("Глубина ночи", "Night depth"), L, -86)
Slider(pNight, "lightGlow", T("Свет огней", "Light glow"), R, -44)
Slider(pNight, "caveDarkness", T("Темнота подземелий", "Dungeon darkness"), R, -86)

-- Picture.
local pPic = pages[5]
Check(pPic, "eye", T("Привыкание глаз", "Eye adaptation"), L - 6, -4)
Slider(pPic, "sharpness", T("Резкость", "Sharpness"), L, -44, nil, nil, 61)
Slider(pPic, "grade", T("Цвет по времени суток", "Time of day colour"), L, -86)
Slider(pPic, "vignette", T("Виньетка", "Vignette"), L, -128)
Slider(pPic, "bright", T("Яркость (50 — как в игре)", "Brightness (50 — the game's own)"), L, -170, nil, nil, 76)
Slider(pPic, "satur", T("Сочность цвета", "Colour richness"), L, -212, nil, nil, 81)
Slider(pPic, "hdrStrength", T("Кино-HDR", "Cinema HDR"), R, -44)
Slider(pPic, "grain", T("Плёночное зерно", "Film grain"), R, -86, nil, nil, 71)
Slider(pPic, "contrast", T("Контрастность", "Contrast"), R, -170, nil, nil, 76)
Slider(pPic, "warmth", T("Тепло картинки", "Picture warmth"), R, -212)
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
Button(pPhoto, T("Фоторежим", "Photo mode"), R, -34, 150, GUWOW_TogglePhoto)
Button(pPhoto, T("Чистый снимок", "Clean screenshot"), R, -62, 150, GUWOW_Screenshot)

ShowPage(1)

SLASH_LEGIONGU1 = "/gu"
SLASH_LEGIONGU2 = "/guwow"
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
			Say(T("вид проверки: близкое светлое, дальнее темнее, небо чёрное. Красная рамка = эффекты не видят глубину. Выключить: /gu check.",
				"check view: near is bright, far is darker, the sky is black. A red border means the effects see no depth. Turn off: /gu check."))
		else
			Say(T("вид проверки выключен.", "the check view is off."))
		end
	elseif msg == "help" or msg == "помощь" then
		Say(T("/gu меню · /gu photo фоторежим · /gu shot чистый снимок · /gu check проверка глубины",
			"/gu menu · /gu photo photo mode · /gu shot clean screenshot · /gu check depth check"))
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
	GameTooltip:Show()
end)
mm:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

-- The game menu (Esc) gets a GUWOW! button under «Macros»: 1.12 has no options window for addons. A client that
-- moved the buttons around gets it under «Return to game».
local gmButton = CreateFrame("Button", "GameMenuButtonGUWOW", GameMenuFrame, "GameMenuButtonTemplate")
gmButton:SetText("GUWOW!")
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
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
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
		PlaceMinimapButton()
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
	Layout()
	Paint()
end)
