/*
 * LegionGUNightsbylevan.fx for ReShade 6.8 (Direct3D 11), part of LegionGU by levan.
 * GU-WOW by levan, based on comfyatmosphere by aloofbit, GPL-3.0 with additional terms under section 7 (NOTICE.txt), modified in 2026. ReShade is not included.
 * Made for the Tauri World of Warcraft client: Legion 7.3.5, build 26972, Wow-64.exe.
 *
 * One self-contained technique, LegionGUNights (no #include, reads COLOR and DEPTH itself, needs no other file):
 *   "Темнота ночи" (NightDarkness) darkens the ambient and the moonlight when the sky in view is a night sky
 *   (a dark, cold sky at the far plane, eased over time with hysteresis), and keeps the lights and what they
 *   light. Without a sky (dungeons, houses) nothing is darkened. "Свет огней" (LightGlow) finds torches, lamps,
 *   windows and fires as pixels much brighter than their surroundings and lets them light the land at their
 *   depth and glow in the air. Both switch off by day and without depth; with both at 0 the frame is untouched.
 *   The fog itself is drawn by LegionGUbylevan.fx; this file only borrows its sky, horizon and depth logic.
 *
 * Licence: new work in the LegionGU package, built on the depth and sky code of LegionGUbylevan.fx, which is
 * derived from comfyatmosphere by aloofbit (https://github.com/aloofbit/comfyatmosphere, GPL-3.0). This file
 * is licensed under the GNU General Public License, version 3 (see LICENSE next to this pack).
 *
 * Player controls: only the category "Ночь" (night darkness, light of the fires). Every other setting is hidden,
 * keeps its tuned default and still loads from the preset. Toggle key: Alt+F11 (in LegionGUbylevan.ini).
 */

// Settings that need a recompile. ReShade lists them under "Preprocessor definitions" of this effect.

// The rays work at 1/N resolution per axis: 2 = half (as the original), 4 = quarter (cheaper). Whole numbers
// 2..8. Even values average every pixel of their block; odd values above 2 read only part of it. 1 is not
// offered: the light buffer has a fixed size, so full resolution gives no sharper shafts, and without the
// averaging thin bright gaps between leaves pass for the sun.
#ifndef LEGIONGU_RAYS_DOWNSCALE
	#define LEGIONGU_RAYS_DOWNSCALE 2
#endif
#if LEGIONGU_RAYS_DOWNSCALE < 2 || LEGIONGU_RAYS_DOWNSCALE > 8
	#error "LEGIONGU_RAYS_DOWNSCALE must be a whole number from 2 to 8"
#endif

// 1 = load Textures/LegionGUMask.png. White means "UI here", black means "world": no fog is drawn on white, and
// white pixels cast no rays. The light of the rays itself falls on the UI too, so the glow around the sun has
// no edge where a mask area begins. The shipped mask is soft and fits the standard Legion layout at 21:9: the
// bars at the bottom centre, the chat, the frames at the top left, the minimap and one row of buffs at the top
// right, each with a soft edge of 0.04 screen heights. A fifth of the fog stays on the bars, the frames, the
// minimap and the buffs. The chat is masked only by a little under half: the world shows through it, and a
// stronger mask left a patch of clearer ground there in open views. Check it with the view "Сколько тумана":
// the UI is dark there. On by default (the lead's decision, round 3). The sun finder reads the frame without
// the mask, so a sun under or next to a masked corner is found as with 0 (round 3 lost it there, and with it
// the rays and the sunlit side of the fog). Outside the painted areas the fog is the same as with 0; the rays
// may differ slightly, because masked pixels cast no rays. 0 turns the mask off, for another layout or another
// aspect ratio (see the README: the mask is stretched to the screen).
#ifndef LEGIONGU_UI_MASK
	#define LEGIONGU_UI_MASK 1
#endif

// The global depth input settings of ReShade.fxh, honoured the same way. RESHADE_DEPTH_INPUT_IS_REVERSED is
// not used: the "Depth type" setting of this effect replaces it and can detect the type by itself.
#ifndef RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
	#define RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN 0
#endif
#ifndef RESHADE_DEPTH_INPUT_IS_MIRRORED
	#define RESHADE_DEPTH_INPUT_IS_MIRRORED 0
#endif
#ifndef RESHADE_DEPTH_INPUT_IS_LOGARITHMIC
	#define RESHADE_DEPTH_INPUT_IS_LOGARITHMIC 0
#endif
#ifndef RESHADE_DEPTH_MULTIPLIER
	#define RESHADE_DEPTH_MULTIPLIER 1
#endif
#ifndef RESHADE_DEPTH_INPUT_Y_SCALE
	#define RESHADE_DEPTH_INPUT_Y_SCALE 1
#endif
#ifndef RESHADE_DEPTH_INPUT_X_SCALE
	#define RESHADE_DEPTH_INPUT_X_SCALE 1
#endif
#ifndef RESHADE_DEPTH_INPUT_Y_OFFSET
	#define RESHADE_DEPTH_INPUT_Y_OFFSET 0
#endif
#ifndef RESHADE_DEPTH_INPUT_Y_PIXEL_OFFSET
	#define RESHADE_DEPTH_INPUT_Y_PIXEL_OFFSET 0
#endif
#ifndef RESHADE_DEPTH_INPUT_X_OFFSET
	#define RESHADE_DEPTH_INPUT_X_OFFSET 0
#endif
#ifndef RESHADE_DEPTH_INPUT_X_PIXEL_OFFSET
	#define RESHADE_DEPTH_INPUT_X_PIXEL_OFFSET 0
#endif

// Size of the downsampled scene the rays work on.
#define LEGIONGU_SCENE_W (BUFFER_WIDTH / LEGIONGU_RAYS_DOWNSCALE)
#define LEGIONGU_SCENE_H (BUFFER_HEIGHT / LEGIONGU_RAYS_DOWNSCALE)

// The light buffer (source, softening, radial blur, arc blur) has a fixed number of rows at any resolution, so
// the shafts have the same shape at 720p and at 1440p and the blur costs the same.
#define LEGIONGU_LIGHT_H 180
#define LEGIONGU_LIGHT_W (LEGIONGU_LIGHT_H * BUFFER_WIDTH / BUFFER_HEIGHT)
// Scene texels per light texel and axis, at most 4 point taps per axis.
#if (BUFFER_HEIGHT / (LEGIONGU_LIGHT_H * LEGIONGU_RAYS_DOWNSCALE)) >= 4
	#define LEGIONGU_SRC_TAPS 4
#elif (BUFFER_HEIGHT / (LEGIONGU_LIGHT_H * LEGIONGU_RAYS_DOWNSCALE)) >= 1
	#define LEGIONGU_SRC_TAPS (BUFFER_HEIGHT / (LEGIONGU_LIGHT_H * LEGIONGU_RAYS_DOWNSCALE))
#else
	#define LEGIONGU_SRC_TAPS 1
#endif

// The lights (see LightsAt): the glow buffer where light sources are found, 90 rows at any resolution, and the
// light field at three widths: L0 on the glow buffer, L1 at a third of it, L2 at a ninth. Colour taps per axis of
// the glow downsample: bilinear taps of 2 x 2 pixels over the BUFFER_HEIGHT / 90 pixels of a block, at most 4
// (at 1440p they sit 4 pixels apart and read a quarter of the frame: the search costs the same at any size).
#define LEGIONGU_GLOW_H 90
#define LEGIONGU_GLOW_W (LEGIONGU_GLOW_H * BUFFER_WIDTH / BUFFER_HEIGHT)
#define LEGIONGU_L1_H 30
#define LEGIONGU_L1_W (LEGIONGU_L1_H * BUFFER_WIDTH / BUFFER_HEIGHT)
#define LEGIONGU_L2_H 10
#define LEGIONGU_L2_W (LEGIONGU_L2_H * BUFFER_WIDTH / BUFFER_HEIGHT)
#if (BUFFER_HEIGHT / (LEGIONGU_GLOW_H * 2)) >= 4
	#define LEGIONGU_GLOW_TAPS 4
#elif (BUFFER_HEIGHT / (LEGIONGU_GLOW_H * 2)) >= 1
	#define LEGIONGU_GLOW_TAPS (BUFFER_HEIGHT / (LEGIONGU_GLOW_H * 2))
#else
	#define LEGIONGU_GLOW_TAPS 1
#endif

// Taps per axis of the downsample. A bilinear colour tap averages 2 x 2 pixels, so N / 2 of them cover a
// block of N x N. The sky share takes single depth taps, at most 4 x 4.
#define LEGIONGU_COLOUR_TAPS (LEGIONGU_RAYS_DOWNSCALE / 2)
#if LEGIONGU_RAYS_DOWNSCALE >= 4
	#define LEGIONGU_SKY_TAPS 4
#else
	#define LEGIONGU_SKY_TAPS LEGIONGU_RAYS_DOWNSCALE
#endif

// ---------------------------------------------------------------------------------------------------
// The in-game panel (the GU-WOW addon, folder LegionGU: Interface > AddOns > GU-WOW, or /gu). The addon paints a strip of
// coded cells in the top left corner; LegionGUBridge (in LegionGUbylevan.fx) reads it after the interface is
// drawn and keeps the values in LegionGUCtlTex. Both effect files declare the texture with the same name, so
// ReShade shares it, and the effects read it on the next frame. Without the addon, or two seconds after the
// strip was last seen, every setting falls back to its ReShade slider.
// Texel 0: x = 1 while the panel is live, y = seconds since the strip was last read, z = 1 if read this frame.
// Texels 1 to 17: the settings and what the game tells, 0..1, in the order of LEGIONGU_CTL_* below.
// ---------------------------------------------------------------------------------------------------

#define LEGIONGU_CTL_FLAGS 1     // 1 the whole mod, 2 fog, 4 rays, 8 night and lights, 16 weather mood, 32 eye adaptation
#define LEGIONGU_CTL_FOG 2
#define LEGIONGU_CTL_REACH 3
#define LEGIONGU_CTL_MIST 4
#define LEGIONGU_CTL_RAYS 5
#define LEGIONGU_CTL_NIGHT 6
#define LEGIONGU_CTL_GLOW 7
#define LEGIONGU_CTL_CAVE 8
#define LEGIONGU_CTL_SHARP 9
#define LEGIONGU_CTL_GRADE 10
#define LEGIONGU_CTL_VIGNETTE 11
#define LEGIONGU_CTL_MIST_DENSITY 12
#define LEGIONGU_CTL_STATE 13    // from the game: 1 live, 2 indoors, 4 flying, 8 photo mode, 16 wet ground on, 32 world map open
#define LEGIONGU_CTL_TIME 14     // the game's time of day, 0..1 for 0..24 hours
#define LEGIONGU_CTL_NIGHT_DEPTH 15
#define LEGIONGU_CTL_AO 16
#define LEGIONGU_CTL_STYLE 17    // the colour style 0..7, plus 8 for the cinema frame in photo mode
#define LEGIONGU_CTL_GRAIN 18    // film grain
#define LEGIONGU_CTL_PHOTO_BLUR 19 // the photo mode blur
#define LEGIONGU_CTL_EXTRA 20    // 1 heat haze, 2 a hot zone (desert, fire), 4 cinema HDR, 8 bokeh in photo mode
#define LEGIONGU_CTL_CELL 4      // pixels per cell side
#define LEGIONGU_CTL_CELLS 45    // black, white, the signature, two cells per setting, two for the checksum

// 1: the effects run only while the addon's strip is seen, that is in the game world. The login and character screens
// and the loading screens have their own scenes the effects are not made for. The installer sets 0 for clients
// without the addon (Classic 1.12, TBC 2.4.3).
#ifndef LEGIONGU_NEED_PANEL
#define LEGIONGU_NEED_PANEL 1
#endif

texture2D LegionGUCtlTex { Width = 21; Height = 1; Format = RGBA32F; };
sampler2D LegionGUCtl { Texture = LegionGUCtlTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };

// The strip's corner. Every effect leaves these pixels as they are, so the strip reaches LegionGUBridge unchanged
// whatever runs before it.
bool LegionGUInStrip(float2 p)
{
	return p.x < float(LEGIONGU_CTL_CELLS * LEGIONGU_CTL_CELL) && p.y < float(LEGIONGU_CTL_CELL);
}

bool LegionGUPanel()
{
	return tex2Dfetch(LegionGUCtl, int2(0, 0)).x > 0.5;
}

// A player setting 0..100: the panel's value while it is live, else the ReShade slider.
float LegionGUValue(int i, float slider)
{
	return LegionGUPanel() ? tex2Dfetch(LegionGUCtl, int2(i, 0)).x * 100.0 : slider;
}

// A part switched on in the panel: the whole mod and the part. Without the panel the technique's own switch
// (its ReShade checkbox and hotkey) decides, so this is true, unless LEGIONGU_NEED_PANEL asks for the addon.
bool LegionGUOn(uint bit)
{
	if (!LegionGUPanel())
		return LEGIONGU_NEED_PANEL == 0;
	// With the world map open (state bit 32) everything is off: part of the map was drawn before REST started the
	// effects, and the night darkened it along the hidden land behind it.
	if ((uint(tex2Dfetch(LegionGUCtl, int2(LEGIONGU_CTL_STATE, 0)).x * 63.0 + 0.5) & 32u) != 0u)
		return false;
	uint f = uint(tex2Dfetch(LegionGUCtl, int2(LEGIONGU_CTL_FLAGS, 0)).x * 63.0 + 0.5);
	return (f & 1u) != 0u && (f & bit) != 0u;
}

// A part with a ReShade checkbox of its own: the panel while it is live, else the checkbox.
bool LegionGUFlag(uint bit, bool checkbox)
{
	return LegionGUPanel() ? LegionGUOn(bit) : checkbox;
}

// What the game tells (see LEGIONGU_CTL_STATE); false without the panel.
bool LegionGUState(uint bit)
{
	if (!LegionGUPanel())
		return false;
	uint s = uint(tex2Dfetch(LegionGUCtl, int2(LEGIONGU_CTL_STATE, 0)).x * 63.0 + 0.5);
	return (s & bit) != 0u;
}

// The game's time of day in hours, while LegionGUState(1u).
float LegionGUHour()
{
	return tex2Dfetch(LegionGUCtl, int2(LEGIONGU_CTL_TIME, 0)).x * 24.0;
}

// The raw style value 0..63 from the panel (see LEGIONGU_CTL_STYLE), -1 without it.
int LegionGUStyleValue()
{
	return LegionGUPanel() ? int(tex2Dfetch(LegionGUCtl, int2(LEGIONGU_CTL_STYLE, 0)).x * 63.0 + 0.5) : -1;
}

// A switch of LEGIONGU_CTL_EXTRA; all off without the panel.
bool LegionGUExtra(uint bit)
{
	return LegionGUPanel() && (uint(tex2Dfetch(LegionGUCtl, int2(LEGIONGU_CTL_EXTRA, 0)).x * 63.0 + 0.5) & bit) != 0u;
}

// How much it is night by the game's clock, 0..1 (indoors too: the street is seen through the door): 21 to 5 o'clock with an hour of fade; 0 without the panel.
float LegionGUNight()
{
	if (!LegionGUState(1u))
		return 0.0;
	float h = LegionGUHour();
	return saturate(1.0 - smoothstep(4.5, 6.0, h) + smoothstep(20.0, 21.5, h));
}

namespace LegionGUNights
{
	// ---------------------------------------------------------------------------------------------------
	// Settings: the player controls. Only these five and the two install check combos below are shown.
	// Every other setting is hidden, keeps its tuned default and still loads from the preset.
	// ---------------------------------------------------------------------------------------------------

	// The original's dial. At the shipped 60, under trees: about 34% fog at 40 yards, 58% at 100, 89% at 250 and
	// 91% at 1500 (with the shipped reach, see FogAt); in the open 25%, 52%, 88%, 90%. More adds haze at the camera
	// and pulls the wall in. The slider is reshaped by FogDial, so equal steps give similar steps on screen.
	uniform float FogThickness <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 100.0; ui_step = 1.0;
		ui_category = "Атмосфера";
		ui_label = "Густота тумана";
		ui_tooltip = "Насколько густой туман: 0 без тумана, 100 очень густой.";
	> = 60.0;

	// Moves the solid wall nearer or farther around the tuned FogReach, see FogNearness: 50 keeps it.
	uniform float FogDistance <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 100.0; ui_step = 1.0;
		ui_category = "Атмосфера";
		ui_label = "Дальность тумана";
		ui_tooltip = "Где начинается сплошной туман: левее ближе, правее дальше.";
	> = 50.0;

	uniform float RaysStrength <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 100.0; ui_step = 1.0;
		ui_category = "Атмосфера";
		ui_label = "Сила лучей";
		ui_tooltip = "Яркость солнечных лучей: 0 без лучей.";
	> = 35.0;

	// Night and lights (see NightStateTexel and NightApply). Both work only with depth, like the fog, and both are
	// drawn by LegionGUFog: Shift+F11 switches them off together with the fog. With both at 0 the output is the fog
	// alone, bit for bit.
	uniform float NightDarkness <
		ui_type = "slider"; ui_min = 0.0; ui_max = 100.0; ui_step = 1.0;
		ui_category = "Ночь";
		ui_label = "Темнота ночи";
		ui_tooltip = "Насколько ночь темнее, чем в игре: 0 как в игре, 100 очень тёмная ночь.\n"
		             "Ночь я узнаю по тёмному холодному небу. В подземельях и домах неба нет, там я ничего не затемняю.\n"
		             "Огни и освещённые ими места остаются яркими, тени не проваливаются в черноту.\n"
		             "Интерфейс не темнеет.\n"
		             "NightIllusion лучше выключить, иначе ночь затемнится дважды.";
	> = 50.0;

	// Beyond «Темнота ночи»: the night multiplier times NIGHT_DEEP^depth, the floor and the toe that keep shadows
	// out of black fade out, the sky darkens as much as the land, and the lights glow more (see NIGHT_DEEP).
	uniform float NightDepth <
		ui_type = "slider"; ui_min = 0.0; ui_max = 100.0; ui_step = 1.0;
		ui_category = "Ночь";
		ui_label = "Глубина ночи";
		ui_tooltip = "Сверх «Темноты ночи», до непроглядной ночи на 100.\n"
		             "Огни, окна, факелы и всё светящееся продолжают светить, их свет даже заметнее.";
	> = 0.0;

	uniform float LightGlow <
		ui_type = "slider"; ui_min = 0.0; ui_max = 100.0; ui_step = 1.0;
		ui_category = "Ночь";
		ui_label = "Свет огней";
		ui_tooltip = "Насколько факелы, жаровни, фонари, окна и костры светят вокруг себя в темноте: 0 как в игре.\n"
		             "Работает ночью, в подземельях и в тёмных помещениях. Под светлым дневным небом не действует.\n"
		             "Светится всё яркое и цветное: огни, кристаллы, руны, окна, светящиеся глаза и оружие.\n"
		             "Имена и полосы здоровья над головами не светятся.";
	> = 50.0;

	// Caves and interiors (see CAVE_HOLD): the night curve without the moonlight tint, only where the frame is dark and
	// no sky has been seen for CAVE_HOLD seconds, so a look at the ground by day never darkens.
	uniform float CaveDarkness <
		ui_type = "slider"; ui_min = 0.0; ui_max = 100.0; ui_step = 1.0;
		ui_category = "Ночь";
		ui_label = "Темнота подземелий";
		ui_tooltip = "Насколько подземелья, пещеры и тёмные дома темнее, чем в игре: 0 как в игре.\n"
		             "Огни и освещённые ими места остаются яркими.\n"
		             "Включается, только если кадр тёмный и неба не видно несколько секунд.\n"
		             "Днём взгляд под ноги ничего не затемняет.";
	> = 30.0;

	uniform float Sharpness <
		ui_type = "slider"; ui_min = 0.0; ui_max = 100.0; ui_step = 1.0;
		ui_category = "Картинка";
		ui_label = "Резкость";
		ui_tooltip = "Чётче текстуры, листва и броня: 0 как в игре.";
	> = 40.0;

	uniform float ColourGrade <
		ui_type = "slider"; ui_min = 0.0; ui_max = 100.0; ui_step = 1.0;
		ui_category = "Картинка";
		ui_label = "Цвет по времени суток";
		ui_tooltip = "Золотистый вечер и прохладная синяя ночь: 0 как в игре. Огни ночью остаются тёплыми.";
	> = 50.0;

	uniform bool EyeAdapt <
		ui_category = "Картинка";
		ui_label = "Привыкание глаз";
		ui_tooltip = "В пещере первые секунды темнее, на выходе на миг слепит, потом глаз привыкает.";
	> = true;

	uniform float Vignette <
		ui_type = "slider"; ui_min = 0.0; ui_max = 100.0; ui_step = 1.0;
		ui_category = "Картинка";
		ui_label = "Виньетка";
		ui_tooltip = "Края кадра чуть темнее: 0 без неё.";
	> = 30.0;

	uniform int ColourStyle <
		ui_type = "combo";
		ui_items = "Нет\0Тёплый\0Холодный\0Плёнка\0Сочный\0Закат\0Сказка\0Нуар\0";
		ui_category = "Картинка";
		ui_label = "Цветовой стиль";
		ui_tooltip = "Общий характер цвета, как фильтр фотоаппарата. В игре выбирается в меню GU-WOW.";
	> = 0;

	uniform float FilmGrain <
		ui_type = "slider"; ui_min = 0; ui_max = 100; ui_step = 1;
		ui_category = "Картинка";
		ui_label = "Плёночное зерно";
		ui_tooltip = "Лёгкое зерно плёнки, сильнее в средних тонах. В игре настраивается в меню GU-WOW.";
	> = 0;

	uniform float PhotoBlur <
		ui_type = "slider"; ui_min = 0; ui_max = 100; ui_step = 1;
		ui_category = "Картинка";
		ui_label = "Размытие в фоторежиме";
		ui_tooltip = "Насколько размыт фон в фоторежиме. В игре настраивается в меню GU-WOW.";
	> = 35;

	uniform float GUTimer < source = "timer"; >;

	uniform bool PhotoMode <
		ui_category = "Картинка";
		ui_label = "Фоторежим";
		ui_tooltip = "Персонаж в фокусе, фон размыт. В игре включается клавишей GU-WOW, интерфейс тогда прячется.";
	> = false;

	// ---------------------------------------------------------------------------------------------------
	// Settings: fog (hidden)
	// ---------------------------------------------------------------------------------------------------

	uniform float FogHaze <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 0.9; ui_step = 0.01;
		ui_category = "Туман";
		ui_label = "Дымка у камеры";
		ui_tooltip = "Сколько тумана уже у самой камеры при густоте около 77, где ручка тумана равна 1.\n"
		             "При густоте 60 её в 0.6 раза меньше.\n"
		             "На открытом месте, где виден горизонт, дымка в 2.5 раза слабее: трава у ног не выцветает.";
	> = 0.30;

	uniform float FogReach <
		hidden = true;
		ui_type = "slider"; ui_min = 20.0; ui_max = 3000.0; ui_step = 5.0; ui_units = " ярд";
		ui_category = "Туман";
		ui_label = "Сплошной туман с";
		ui_tooltip = "С этого расстояния туман почти сплошной при густоте около 77 и дальности 50.\n"
		             "При густоте 60 стена дальше в 1.3 раза.\n"
		             "За стеной земля закрыта туманом почти на девять десятых, самые дальние горы чуть сильнее.\n"
		             "Так дальние горы не сливаются в одно пятно.\n"
		             "Меньше: стена тумана ближе.\n"
		             "Родной туман игры остаётся под этим слоем. Работает только с глубиной.";
	> = 160.0;

	uniform float FogDesaturate <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
		ui_category = "Туман";
		ui_label = "Обесцвечивание";
		ui_tooltip = "Тянет цвет тумана к серому. Растёт вместе с густотой.";
	> = 0.15;

	uniform float FogDarken <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
		ui_category = "Туман";
		ui_label = "Затемнение";
		ui_tooltip = "Тянет цвет тумана к чёрному. Растёт вместе с густотой.\n"
		             "0: туман светлый, как небо у горизонта.";
	> = 0.0;

	uniform float3 FogTint <
		hidden = true;
		ui_type = "color";
		ui_category = "Туман";
		ui_label = "Оттенок";
		ui_tooltip = "Цвет, к которому тянет туман ручка «Сила оттенка». По умолчанию холодный сланцевый.";
	> = float3(0.352941, 0.392157, 0.439216);

	uniform float FogTintAmount <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
		ui_category = "Туман";
		ui_label = "Сила оттенка";
		ui_tooltip = "0: оттенок не используется. Растёт вместе с густотой.";
	> = 0.0;

	uniform float FogSky <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
		ui_category = "Туман";
		ui_label = "Туман на небе";
		ui_tooltip = "0: небо не трогается, как в оригинале.\n"
		             "Больше 0: небо тоже слегка тонет в тумане.";
	> = 0.0;

	uniform int FogColourMode <
		hidden = true;
		ui_type = "combo"; ui_items = "Авто, по кадру\0Вручную\0";
		ui_category = "Туман";
		ui_label = "Цвет тумана";
		ui_tooltip = "Авто: цвет берётся с неба у горизонта над дальней землёй и меняется плавно.\n"
		             "WoW красит там небо в цвет своего тумана.\n"
		             "Самый яркий горизонт у солнца я пропускаю: это свечение солнца, его туман добавляет сам.\n"
		             "Если горизонта не видно, цвет берётся с самой дальней и светлой земли.\n"
		             "Если и дальней земли почти нет, как в густом лесу, цвет берётся с видимого неба, наполовину обесцвеченного.\n"
		             "Если видно небо, туман не темнее трёх четвертей его яркости: днём воздух светлый и в лесу.\n"
		             "В помещении неба и дальней земли нет, и туман берёт тон самого кадра.\n"
		             "Вручную: цвет из поля ниже.\n"
		             "В обоих режимах туман к солнцу светлее и теплее. Солнце ищут лучи, без них этого нет.";
	> = 0;

	uniform float3 FogColourManual <
		hidden = true;
		ui_type = "color";
		ui_category = "Туман";
		ui_label = "Ручной цвет";
		ui_tooltip = "Работает в режиме «Вручную».\n"
		             "Обесцвечивание, затемнение и оттенок применяются и к нему.";
	> = float3(0.501961, 0.650980, 0.800000);

	uniform float FogSampleFrom <
		hidden = true;
		ui_type = "slider"; ui_min = 20.0; ui_max = 2000.0; ui_step = 5.0; ui_units = " ярд";
		ui_category = "Туман";
		ui_label = "Дальняя геометрия с";
		ui_tooltip = "Геометрия дальше этого расстояния считается дальней.\n"
		             "Небо прямо над ней я считаю горизонтом и беру с него цвет тумана.\n"
		             "Без горизонта цвет берётся с земли дальше четверти этого расстояния: туман игры её уже окрасил.";
	> = 250.0;

	uniform float FogColourAdapt <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 10.0; ui_step = 0.1; ui_units = " с";
		ui_category = "Туман";
		ui_label = "Сглаживание цвета";
		ui_tooltip = "За сколько секунд автоцвет догоняет новую картинку.\n"
		             "Меньше: быстрее, но цвет может дёргаться при повороте камеры.";
	> = 2.0;

	// ---------------------------------------------------------------------------------------------------
	// Settings: rays (hidden). RaysStrength (with the player controls above) scales them: 100 gives
	// RaysMaxExposure. The rays live in the air: brighter on the far haze, weaker on near objects. In the open
	// only a soft glow is left, under leaves they run at full strength. Without depth leaves cannot be told
	// from text over the sky, and the soft glow is left.
	// ---------------------------------------------------------------------------------------------------

	uniform float RaysMaxExposure <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 20.0; ui_step = 0.1;
		ui_category = "Лучи";
		ui_label = "Яркость на 100";
		ui_tooltip = "Во сколько раз усилены лучи при силе 100.";
	> = 2.0;

	uniform float RaysRelThreshold <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 0.99; ui_step = 0.01;
		ui_category = "Лучи";
		ui_label = "Порог от самого яркого";
		ui_tooltip = "Пиксель даёт луч, если он не темнее этой доли от самого яркого места у солнца.\n"
		             "Так просветы неба в тёмном лесу тоже светят.\n"
		             "Меньше: светится больше.";
	> = 0.60;

	uniform float RaysThreshold <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 0.99; ui_step = 0.01;
		ui_category = "Лучи";
		ui_label = "Порог яркости";
		ui_tooltip = "Абсолютный минимум яркости.\n"
		             "Не даёт тусклым огням в тёмных сценах тянуть полосы.";
	> = 0.20;

	uniform float RaysRadius <
		hidden = true;
		ui_type = "slider"; ui_min = 0.05; ui_max = 10.0; ui_step = 0.01;
		ui_category = "Лучи";
		ui_label = "Радиус у солнца";
		ui_tooltip = "До какого расстояния от солнца пиксели ещё дают лучи. Меряется в высотах экрана.\n"
		             "Шире: яркие облака в стороне от солнца тоже начнут светить.";
	> = 0.8;

	uniform float RaysFalloff <
		hidden = true;
		ui_type = "slider"; ui_min = 0.25; ui_max = 8.0; ui_step = 0.05;
		ui_category = "Лучи";
		ui_label = "Спад к краю радиуса";
		ui_tooltip = "1: ровный спад.\n"
		             "2 и больше: лучи жмутся к солнцу.";
	> = 2.0;

	uniform float RaysLength <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
		ui_category = "Лучи";
		ui_label = "Длина";
		ui_tooltip = "Длина луча как доля пути от пикселя до солнца.";
	> = 0.85;

	uniform float RaysMaxLength <
		hidden = true;
		ui_type = "slider"; ui_min = 0.05; ui_max = 3.0; ui_step = 0.01;
		ui_category = "Лучи";
		ui_label = "Предел длины";
		ui_tooltip = "Лучи не длиннее этого числа высот экрана.\n"
		             "Это важно, когда солнце далеко за краем.";
	> = 0.6;

	uniform float RaysParallel <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
		ui_category = "Лучи";
		ui_label = "Параллельность";
		ui_tooltip = "0: лучи расходятся от солнца, как настоящие.\n"
		             "1: параллельные полосы в одну сторону, это стилизация.";
	> = 0.0;

	uniform float RaysAdaptTime <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 10.0; ui_step = 0.05; ui_units = " с";
		ui_category = "Лучи";
		ui_label = "Привыкание к свету";
		ui_tooltip = "За сколько секунд порог яркости догоняет сцену.\n"
		             "0: сразу, лучи будут мигать.";
	> = 0.5;

	uniform float RaysDecay <
		hidden = true;
		ui_type = "slider"; ui_min = 0.5; ui_max = 1.0; ui_step = 0.005;
		ui_category = "Лучи";
		ui_label = "Затухание вдоль луча";
		ui_tooltip = "Меньше: лучи короче и мягче.";
	> = 0.96;

	uniform float3 RaysColour <
		hidden = true;
		ui_type = "color";
		ui_category = "Лучи";
		ui_label = "Цвет света";
		ui_tooltip = "По умолчанию тёплый свет позднего утра.";
	> = float3(1.000000, 0.901961, 0.745098);

	uniform float RaysDefinition <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.05;
		ui_category = "Лучи";
		ui_label = "Чёткость лучей";
		ui_tooltip = "0: мягкое свечение в дымке.\n"
		             "1: отдельные широкие лучи с тенью между ними.\n"
		             "Тонкие спицы я убираю при любом значении.\n"
		             "Чем чётче лучи, тем заметнее дрожат их края при повороте камеры.";
	> = 0.25;

	uniform bool RaysSkyOnly <
		hidden = true;
		ui_category = "Лучи";
		ui_label = "Лучи только от неба";
		ui_tooltip = "Лучи дают только пиксели неба по глубине.\n"
		             "Так не светятся снег, вода и блики на броне.\n"
		             "Без глубины настройка не действует.";
	> = true;

	uniform bool RaysNeedDepth <
		hidden = true;
		ui_category = "Лучи";
		ui_label = "Лучи только с глубиной";
		ui_tooltip = "Включить в сборке с аддонами, когда глубина работает.\n"
		             "Тогда лучи гаснут, если глубины нет или она пустая дольше секунды.\n"
		             "Обычно так бывает на экранах загрузки и в роликах.\n"
		             "Если игра держит там глубину прошлого кадра, лучи останутся.\n"
		             "Экраны входа и выбора персонажа в Legion это 3D-сцены с глубиной, лучи на них есть.\n"
		             "Чистое небо без земли в центре кадра тоже гасит лучи через секунду.\n"
		             "В обычной сборке не включать: там глубины нет, и лучи пропадут совсем.";
	> = false;

	uniform int SunMode <
		hidden = true;
		ui_type = "combo"; ui_items = "Авто\0Закреплено\0";
		ui_category = "Лучи";
		ui_label = "Солнце";
		ui_tooltip = "Авто: я ищу солнце как самое плотное яркое пятно неба. Для этого нужна глубина.\n"
		             "Если солнца нет на экране, лучи идут из точки ниже и слабее.\n"
		             "Без глубины «Авто» работает как «Закреплено».\n"
		             "Закреплено: лучи всегда идут из точки ниже, на полной силе.";
	> = 0;

	uniform float SunX <
		hidden = true;
		ui_type = "slider"; ui_min = -2.0; ui_max = 3.0; ui_step = 0.01;
		ui_category = "Лучи";
		ui_label = "Точка солнца X";
		ui_tooltip = "0: левый край экрана, 1: правый.";
	> = 0.5;

	uniform float SunY <
		hidden = true;
		ui_type = "slider"; ui_min = -3.0; ui_max = 2.0; ui_step = 0.01;
		ui_category = "Лучи";
		ui_label = "Точка солнца Y";
		ui_tooltip = "0: верхний край экрана, 1: нижний.\n"
		             "-0.30 это «12 часов» над краем: лучи падают сверху, как сквозь кроны.";
	> = -0.30;

	uniform float SunMinLuma <
		hidden = true;
		ui_type = "slider"; ui_min = 0.5; ui_max = 1.0; ui_step = 0.01;
		ui_category = "Лучи";
		ui_label = "Авто: яркость солнца";
		ui_tooltip = "С какой яркости пиксель неба считается частью солнца.\n"
		             "Середина пятна должна быть ещё ярче, почти белой.\n"
		             "Так освещённое облако не сходит за солнце.";
	> = 0.9;

	uniform float SunMinFill <
		hidden = true;
		ui_type = "slider"; ui_min = 0.05; ui_max = 1.0; ui_step = 0.01;
		ui_category = "Лучи";
		ui_label = "Авто: плотность солнца";
		ui_tooltip = "Какая доля клетки экрана должна быть залита ярким небом.\n"
		             "Отсекает белый текст и таблички имён.";
	> = 0.3;

	uniform float SunAdapt <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 5.0; ui_step = 0.05; ui_units = " с";
		ui_category = "Лучи";
		ui_label = "Авто: сглаживание солнца";
		ui_tooltip = "За сколько секунд лучи переходят от солнца к запасной точке и обратно.\n"
		             "Лучи гаснут в старой точке и загораются в новой, поэтому не скользят по пустому небу.\n"
		             "За солнцем на экране точка идёт почти сразу, с задержкой в десятую долю секунды.";
	> = 0.3;

	uniform float RaysNoSunGain <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
		ui_category = "Лучи";
		ui_label = "Авто: сила без солнца";
		ui_tooltip = "Доля силы лучей, когда солнца на экране нет.\n"
		             "В оригинале лучи тоже слабели, когда камера смотрит от солнца, в среднем до 0.4.\n"
		             "Работает только с глубиной. Без неё «Авто» работает как «Закреплено».";
	> = 0.45;

	// ---------------------------------------------------------------------------------------------------
	// Settings: install check (a closed category). The first four views are drawn by the fog, the last three
	// by the rays. "Где солнце" also shows the radius (white ring: where it is measured from, yellow circle:
	// its edge) and the canopy estimate as a bar along the top edge: left of the left red tick the rays are
	// weak, right of the right tick at full strength.
	// ---------------------------------------------------------------------------------------------------

	uniform int DebugView <
		hidden = true;
		ui_type = "combo";
		ui_items = "Выкл\0Глубина\0Полосы по 25 ярдов\0Сколько тумана\0Цвет тумана\0"
		           "Что даёт лучи\0Только лучи\0Где солнце\0Ночь и огни\0";
		ui_category = "Проверка установки"; ui_category_closed = true;
		ui_label = "Вид проверки";
		ui_tooltip = "Глубина: близкое светлое, дальнее темнее, небо чёрное.\n"
		             "Полосы по 25 ярдов: земля в серых полосах, небо сплошь синее.\n"
		             "Сколько тумана: чем белее, тем гуще туман.\n"
		             "Где солнце: зелёная точка на солнце. Оранжевая точка значит, что солнца не видно.\n"
		             "Ночь и огни: цветом то, что я считаю огнями, и их свет. Слева вверху шесть квадратов:\n"
		             "ночь, день, видна ли земля, яркость земли, яркость неба и насколько небо синее.\n"
		             "Белый квадрат значит «да». Снимок этого вида ночью и днём нужен мне для настройки.\n"
		             "Красная рамка в первых трёх видах: глубины нет, и тумана не будет.\n"
		             "Остальные виды нужны для разбора ошибок. После проверки вернуть «Выкл».";
	> = 0;

	uniform int DepthType <
		ui_type = "combo"; ui_items = "Авто\0Обычная\0Обратная\0";
		ui_category = "Проверка установки"; ui_category_closed = true;
		ui_label = "Тип глубины";
		ui_tooltip = "«Авто» подходит почти всегда.\n"
		             "Если в виде «Глубина» почти весь экран белый, выбрать «Обычная» или «Обратная».\n"
		             "Верная та, где небо чёрное.";
	> = 0;

	// ---------------------------------------------------------------------------------------------------
	// Settings: debug and depth (hidden)
	// ---------------------------------------------------------------------------------------------------

	uniform float DebugRange <
		hidden = true;
		ui_type = "slider"; ui_min = 25.0; ui_max = 2000.0; ui_step = 5.0; ui_units = " ярд";
		ui_category = "Отладка";
		ui_label = "Полосы до";
		ui_tooltip = "Вид «Полосы по 25 ярдов» рисует полосы до этого расстояния.";
	> = 150.0;

	uniform float DepthNear <
		hidden = true;
		ui_type = "slider"; ui_min = 0.01; ui_max = 2.0; ui_step = 0.01; ui_units = " ярд";
		ui_category = "Глубина";
		ui_label = "Ближняя плоскость";
		ui_tooltip = "Масштаб всех расстояний.\n"
		             "Вдвое меньше: все ярды вдвое меньше.\n"
		             "Если полосы по 25 ярдов не сходятся с игрой, подстроить здесь.";
	> = 0.2;

	uniform float DepthFar <
		hidden = true;
		ui_type = "slider"; ui_min = 0.0; ui_max = 20000.0; ui_step = 10.0; ui_units = " ярд";
		ui_category = "Глубина";
		ui_label = "Дальняя плоскость";
		ui_tooltip = "0: бесконечная.\n"
		             "Влияет только на дальнюю половину расстояния.";
	> = 0.0;

	uniform float SkyFrom <
		hidden = true;
		ui_type = "slider"; ui_min = 500.0; ui_max = 100000.0; ui_step = 100.0; ui_units = " ярд";
		ui_category = "Глубина";
		ui_label = "Небо с";
		ui_tooltip = "С этого расстояния всё считается небом.\n"
		             "Это нужно, если небо Legion пишет глубину.\n"
		             "Проверка: в виде «Полосы по 25 ярдов» небо должно быть сплошь синим.\n"
		             "Небо серое: уменьшить. Дальние горы стали синими: увеличить.";
	> = 10000.0;

	uniform float FrameTime < source = "frametime"; >;
	uniform uint FrameCount < source = "framecount"; >;

	// ---------------------------------------------------------------------------------------------------
	// Constants
	// ---------------------------------------------------------------------------------------------------

	static const float ASPECT = BUFFER_WIDTH * BUFFER_RCP_HEIGHT;
	static const float3 LUMA601 = float3(0.299, 0.587, 0.114);

	// A pixel is sky when its depth is the far-plane clear value (next to the far plane one D24 step already
	// means millions of yards, so no real geometry is caught), or when it is at SkyFrom or beyond, in case
	// the sky writes depth. The fog fades to the sky's treatment over the last SKY_RAMP share before SkyFrom,
	// so far land that crosses the limit gets no hard edge.
	static const float SKY_EPSILON = 1e-7;
	static const float SKY_RAMP = 0.2;

	// Grid over the centre of the frame used to probe depth and estimate the fog colour. It skips most of
	// the default UI: action bars, unit frames, minimap and chat.
	static const int GRID_X = 32;
	static const int GRID_Y = 18;

	// Seconds for the depth-present fade and for the automatic depth type decision.
	static const float DEPTH_FADE_TIME = 1.0;
	static const float DEPTH_TYPE_TIME = 1.0;
	// "Rays only with depth" keeps the rays this many seconds after the depth last differed across the grid,
	// then fades them out over DEPTH_FADE_TIME. A cleared buffer (a loading screen) then gets no rays.
	static const float DEPTH_HOLD_TIME = 1.0;

	// The sun statistics grid: each cell holds the brightest pixel and the share of bright sky.
	static const int STATS_W = 64;
	static const int STATS_H = 32;
	static const int STATS_TAPS = 16;

	// A bright patch counts as the sun only when all of these hold, in screen heights:
	//   its weighted spread (RMS radius) is at most SUN_MAX_SPREAD, so glimpses of glow scattered behind a
	//   canopy are not a sun. A patch that fills at least SUN_SOLID of the disc its spread describes is one
	//   solid glow (the sun in a bright hazy sky) and may spread up to SUN_MAX_SPREAD_SOLID;
	//   no cell with at least SunMinFill lies farther than SUN_STRAY spreads (at least SUN_STRAY_MIN) from
	//   its centre, so it is the only dense patch in view;
	//   its brightest cell reaches lerp(SunMinLuma, 1, SUN_CORE), 0.97 by default: the sun disc clips to
	//   white, a sunlit cloud usually does not.
	static const float SUN_MAX_SPREAD = 0.10;
	static const float SUN_MAX_SPREAD_SOLID = 0.20;
	static const float SUN_SOLID = 0.6;
	static const float SUN_STRAY = 3.0;
	static const float SUN_STRAY_MIN = 0.15;
	static const float SUN_CORE = 0.7;
	static const float STATS_CELL_AREA = ASPECT / float(STATS_W * STATS_H);
	// A found patch is the sun in open sky when the ring from SUN_RING_IN to SUN_RING_OUT spreads around it
	// (at least SUN_RING_IN_MIN and SUN_RING_OUT_MIN screen heights) is at least SUN_RING_SKY sky. Otherwise
	// it is a bright hole in leaves or rock next to the hidden sun, and the rays converge GAP_LIFT screen
	// heights above it; the lift eases in and out over GAP_LIFT_TIME seconds.
	static const float SUN_RING_IN = 1.5;
	static const float SUN_RING_IN_MIN = 0.05;
	static const float SUN_RING_OUT = 3.0;
	static const float SUN_RING_OUT_MIN = 0.12;
	static const float SUN_RING_SKY = 0.45;
	static const float GAP_LIFT = 0.2;
	static const float GAP_LIFT_TIME = 0.3;

	// Auto sun. The share of frames with a found sun is smoothed over SUN_FOUND_TIME seconds. The rays start
	// following the sun when the share rises above SUN_FOLLOW_ON and go back to the pinned point only when it
	// drops below SUN_FOLLOW_OFF, so a sun that flickers behind leaves keeps one target.
	static const float SUN_FOUND_TIME = 0.3;
	static const float SUN_FOLLOW_ON = 0.7;
	static const float SUN_FOLLOW_OFF = 0.3;
	// A found sun within max(SUN_TRACK_STEP, SUN_TRACK_SPEED * frame time) screen heights of the followed one
	// is the same sun: a camera turn moves it a little each frame, more at a low frame rate. A farther one must
	// hold for SUN_JUMP_TIME seconds, like the original's 10 frames, so a stray bright patch does not pull the
	// rays away.
	static const float SUN_TRACK_STEP = 0.08;
	static const float SUN_TRACK_SPEED = 6.0;
	static const float SUN_JUMP_TIME = 0.15;
	// The point the rays use eases after the followed sun over SUN_SMOOTH_TIME seconds, so a sun glimpsed
	// through moving leaves does not make the rays wander.
	static const float SUN_SMOOTH_TIME = 0.1;
	// A sun lost for SUN_LOST_TIME seconds within SUN_EDGE screen heights of the edge has left the screen: the
	// followed point moves out to SUN_EXIT times its edge crossing, so the rays keep coming from beyond the
	// edge. A sun lost farther inside is behind a tree or a cloud, and the point stays.
	static const float SUN_LOST_TIME = 0.1;
	static const float SUN_EDGE = 0.15;
	static const float SUN_EXIT = 1.1;

	// Fog opacity. Beyond the old solid wall far land is never quite solid, so a range of mountains keeps a hint of
	// its relief and its layers instead of one flat colour: Legion draws much farther than the original's client.
	// The distance fog is capped at FOG_FAR_CAP up to the climb FOG_FAR_FROM (250 yards at the shipped settings),
	// and the cap rises by FOG_FAR_RISE per doubling of the distance up to FOG_FAR_TOP (1500 yards): a farther
	// range is a little paler than a nearer one. The sliders scale these distances like the wall. The rise is
	// small on purpose. The dusk bench view has nearer hills at its left edge under a bright sky and the farthest
	// hills at its right edge under a darker one, and one fog colour meets both only near 0.88: a cap of 0.80 at
	// 250 yards rising to 0.95 at 1500 left the far right hills 12.5 levels lighter than the sky above them (limit
	// 10). With this cap the worst far ridge away from the sun is within 10 levels on field, snow, dusk, offscreen
	// and nameplates, with and without the rays (the flat 0.88 of round 3 gave 10.1 on nameplates). The climb bends into the
	// cap over FOG_FAR_KNEE (a smooth minimum), so no ring shows where it stops growing. In the open, when the
	// horizon is in view, the haze at the camera is FOG_HAZE_OPEN of FogHaze: open air is clear near the camera,
	// and the grass at the player's feet keeps its colour (bench field: saturation 0.46 in round 2, now 0.51,
	// before 0.65; dusk ground +44% in round 2, now +29%). Under trees and indoors it keeps the full haze.
	static const float FOG_FAR_CAP = 0.87;
	static const float FOG_FAR_FROM = 1.2;
	static const float FOG_FAR_RISE = 0.01;
	static const float FOG_FAR_TOP = 0.895;
	static const float FOG_FAR_KNEE = 0.15;
	static const float FOG_HAZE_OPEN = 0.4;
	// Fog colour estimate. Far land starts at FAR_LAND_SHARE of FogSampleFrom and counts with a weight that
	// grows with distance, capped at FAR_WEIGHT_CAP times that start, and with the square of its brightness,
	// so the farthest and brightest land (the most fogged by the engine, not the shaded side of a tree) wins.
	// HORIZON_FULL horizon taps (grid columns) give full confidence in the horizon colour. The second pass over
	// the horizon taps leaves out a tap more than FOG_OUTLIER (RGB length) from the first average (a window over
	// the sky) and a tap more than FOG_GLOW_KEEP brighter than it: the glow of the sun. The fog colour is then
	// the horizon away from the sun, where far land has to meet the sky, and SunInFog adds the glow back toward
	// the sun. If less than FOG_KEPT_MIN of the weight is kept, the first average stays. Bench: the far hills on
	// the side away from the sun sit within 9 levels of the sky above them in field and snow, with and without
	// the rays (round 2: 23 levels without, 55 with the rays).
	static const float FAR_LAND_SHARE = 0.25;
	static const float FAR_WEIGHT_CAP = 16.0;
	static const float HORIZON_FULL = 3.0;
	static const float FOG_OUTLIER = 0.2;
	static const float FOG_GLOW_KEEP = 0.02;
	static const float FOG_KEPT_MIN = 0.25;
	// Daylight in the air. Without a horizon the fog takes the far land, and where little far land is in view
	// (a dense forest) the sky in view, paled by FOG_SKY_PALE toward its own grey: the sky near the horizon is
	// paler than the sky overhead. The colour is lifted to at least FOG_SKY_FLOOR of the mean brightness of the
	// sky in view, at most FOG_LIFT_MAX times: dark trees seen through the engine fog carry its hue but not its
	// brightness. Sky taps at SKY_WHITE and brighter (the sun and its glow) are left out, SKY_TAPS_FULL sky taps
	// give full confidence. Bench: the canopy's far wall (62, 77, 57) becomes (133, 166, 122) against the
	// scene's engine fog (128, 153, 117); the forest (141, 159, 190) against (143, 161, 178), where round 2 took
	// the lifted frame average (105, 128, 144).
	static const float FOG_SKY_FLOOR = 0.75;
	static const float FOG_LIFT_MAX = 5.0;
	static const float SKY_WHITE = 0.95;
	static const float SKY_TAPS_FULL = 8.0;
	static const float FOG_SKY_PALE = 0.5;
	// The haze layer (see FogHazeColour) goes HAZE_SHADE of the way to the key, the mean colour of the land
	// nearer than NEAR_LAND yards. It needs more than FOG_KEY_TAPS grid taps of such land, else it keeps the
	// fog colour.
	static const float HAZE_SHADE = 0.5;
	static const float NEAR_LAND = 30.0;
	static const float FOG_KEY_TAPS = 2.0;
	// Sunlight in the fog: toward the sun the fog colour rises by up to INSCATTER_GAIN and takes on the light
	// colour (share INSCATTER_WARM). The closeness falls from 1 at the sun to 0 at INSCATTER_RADIUS screen
	// heights as (1 - d / radius)^INSCATTER_POWER, about like the sky's own glow (bench field, sky above the
	// ridge against the far side: 1.21 at 0.25 and 1.13 at 0.36 screen heights; the fog gets 1.38 and 1.23).
	// Away from the sun the haze layer drops by INSCATTER_DIM and turns a little cooler (INSCATTER_COOL). The
	// distance fog does not: it is what far land dissolves into, and it has to meet the horizon sky. The pinned
	// point, when no sun is found, gives INSCATTER_PINNED of it. The lit colour stays below INSCATTER_KNEE
	// luminance (or the fog's own), so the haze next to the sun never clips to white. The rays state is fresh
	// when it was written at most STAMP_LAG frames ago. STAMP_MOD is 2^23: the stamp is kept in a float, exact
	// up to there. A small modulus wraps while LegionGURays is switched off, and the old sun would then flash in
	// the fog for a few frames every STAMP_MOD frames.
	static const float INSCATTER_RADIUS = 1.0;
	static const float INSCATTER_POWER = 3.0;
	static const float INSCATTER_GAIN = 0.9;
	static const float INSCATTER_WARM = 0.6;
	static const float INSCATTER_DIM = 0.2;
	static const float INSCATTER_COOL = 0.5;
	static const float INSCATTER_PINNED = 0.4;
	static const float INSCATTER_KNEE = 0.9;
	static const float3 COOL_TINT = float3(0.93, 1.0, 1.10);
	static const uint STAMP_MOD = 8388608u;
	static const float STAMP_LAG = 2.0;

	// Rays as light in the air. The added light is scaled by the air in front of the pixel: for land none up
	// to AIR_NEAR yards and AIR_LAND from AIR_FULL yards on, 1 for the sky, AIR_NO_DEPTH without depth. A shaft
	// from a gap high in the canopy crosses the line of sight far from the camera, so the ground at the
	// player's feet (the third-person camera stands 5 to 15 yards behind him) stays out of the light, while a
	// mound 20 yards out still catches it. AIR_GAIN offsets the air and the screen blend, so the beams below a
	// canopy gap are as bright as the old additive rays.
	static const float AIR_NEAR = 7.0;
	static const float AIR_FULL = 18.0;
	static const float AIR_LAND = 0.55;
	static const float AIR_NO_DEPTH = 0.6;
	static const float AIR_GAIN = 5.0;
	// Canopy estimate: sky edges between neighbouring stats taps per tap pair, weighted by the proximity to the
	// sun like the mask. Below CANOPY_LO the view is open and the rays keep RAYS_OPEN_GAIN of their strength,
	// above CANOPY_HI the view is under leaves and they run at full strength. Bench values: canopy 0.0131,
	// forest 0.0039, field 0.0023, snow and dusk 0.0020, offscreen 0.0016. Without depth no tap is known to be
	// sky, the estimate is 0 and the rays keep the open strength: brightness alone took text over the sky for
	// leaves. The debug bar of "Где солнце" shows the estimate times BAR_SCALE.
	static const float CANOPY_LO = 0.0045;
	static const float CANOPY_HI = 0.0105;
	static const float RAYS_OPEN_GAIN = 0.22;
	static const float BAR_SCALE = 50.0;
	// Arc blur around the point the rays converge on, half widths in degrees. A spoke narrower than the fine
	// arc spreads out and fades; the wide arc is the glow the beams stand out of (see RaysDefinition).
	static const float ARC_FINE_DEG = 3.0;
	static const float ARC_WIDE_DEG = 15.0;

	static const int DBG_OFF = 0;
	static const int DBG_DEPTH = 1;
	static const int DBG_BANDS = 2;
	static const int DBG_AMOUNT = 3;
	static const int DBG_COLOUR = 4;
	static const int DBG_MASK = 5;
	static const int DBG_RAYS = 6;
	static const int DBG_SUN = 7;
	static const int DBG_NIGHT = 8;

	// Night. ReShade cannot read the game clock, so the night is read from the frame: the sky (depth at the far
	// plane) over the fog grid, its luminance as a geometric mean, so the moon and the stars barely count, and its
	// colour. A sky at NIGHT_SKY_DARK or darker is full night, at NIGHT_SKY_LIGHT or brighter no night (dusk skies
	// are brighter still). A night sky is also cold: its blue is at least NIGHT_COLD_FULL times its red and its
	// green, and at NIGHT_COLD_FROM or less it is no night, so a dark grey storm sky or a green or red fel sky by
	// day (Stormheim, Argus) does not darken the day. The day, which keeps the lights off, rises from DAY_SKY_FROM
	// to DAY_SKY_FULL. The sky counts fully from NIGHT_SKY_HI of the grid taps on, not at all below NIGHT_SKY_LO.
	// The night eases over NIGHT_TIME seconds and moves only when the reading differs from it by more than
	// NIGHT_BAND (hysteresis), except at 0 and 1, so turning the camera from the horizon to the zenith does not pump
	// the darkness. Without sky in view (a dungeon, a house, the camera looking down) night and day fade to 0 over
	// NIGHT_NOSKY_TIME seconds: a glance at the ground keeps the night, a dungeon is not darkened. With less than
	// NIGHT_LAND_MIN of the taps on land (a loading screen, the camera straight up) nothing is read, and night and
	// lights fade out over NIGHT_LAND_TIME.
	static const float NIGHT_SKY_DARK = 0.07;
	static const float NIGHT_SKY_LIGHT = 0.20;
	static const float NIGHT_COLD_FROM = 1.2;
	static const float NIGHT_COLD_FULL = 1.45;
	static const float DAY_SKY_FROM = 0.22;
	static const float DAY_SKY_FULL = 0.40;
	static const float NIGHT_SKY_LO = 0.01;
	static const float NIGHT_SKY_HI = 0.05;
	static const float NIGHT_TIME = 3.0;
	static const float NIGHT_BAND = 0.08;
	static const float NIGHT_NOSKY_TIME = 10.0;
	static const float NIGHT_LAND_MIN = 0.10;
	static const float NIGHT_LAND_TIME = 0.5;
	// The ambient: the geometric mean of the land's luminance over the grid, eased over AMBIENT_TIME seconds and
	// never taken below AMBIENT_MIN. The curve and the lights are relative to it.
	static const float AMBIENT_TIME = 3.0;     // slow: the light and dark parts must not swap as the view turns between sky and land
	static const float AMBIENT_MIN = 0.01;
	// «Темнота ночи» s (the slider times the night): the light of the moon and the ambient is scaled by
	// m = NIGHT_M100^s, 0.2 at 100 and 0.45 at 50, so equal steps of the slider give equal ratios. On the brightest
	// channel v the curve is v (m + (1 - m) h) with h = x^2 / (1 + x^2) and x = v / (NIGHT_KNEE ambient): land lit
	// like the land around (x below 0.5) scales almost by m, a pixel lit by a lamp or a window (x above 2) keeps
	// most of its value, so the pools under the lamps stay pools. The toe keeps the darkest NIGHT_TOE (3 levels):
	// shadows keep their detail and nothing turns black. m never drops below NIGHT_FLOOR over the ambient, so a frame
	// already that dark is darkened less. The sky gets NIGHT_SKY_SHARE of the darkening. The darkened land turns
	// MOON_SHIFT of the way toward a cool moonlit grey of its own luminance (MOON_TINT), less where a light keeps it
	// (h), so the fires stay warm.
	static const float NIGHT_M100 = 0.23;
	static const float NIGHT_KNEE = 3.0;
	static const float NIGHT_TOE = 0.018;
	static const float NIGHT_DEEP = 0.12;       // the extra night multiplier at «Глубина ночи» 100: with «Темнота» 100 about 3% of the light
	static const float SKY_KNEE = 4.0;          // a sky pixel this many times the sky mean counts half as a light (moon, stars)
	static const float INDOOR_REACH = 20.0;     // yards: indoors, what lies farther is the street outside
	static const float NIGHT_FAR_FROM = 150.0;  // yards: from here far land goes over to the night curve of the sky
	static const float NIGHT_FAR_SKY = 450.0;   // and from here it is fully on it
	static const float LIGHT_FAR = 60.0;        // yards: a light this far glows half as much, at twice the distance a fifth
	static const float2 LIGHT_WHITE = float2(0.75, 0.9);    // peak at which any colour counts as a light
	static const float2 LIGHT_SAT = float2(0.3, 0.5);       // saturation at which a less bright source counts
	static const float2 LIGHT_COLOURED = float2(0.3, 0.45); // and the peak it needs then
	static const float LIGHT_SELF_CUT = 0.9;    // glow taken from cold light on the player's own model (see LightFindPS)
	static const float LIGHT_AREA_CUT = 0.7;    // glow taken from a block of cold light all over (a glowing wing, not a flame)
	static const float DEEP_GLOW = 0.25;        // the lights glow this share more at «Глубина ночи» 100
	static const float NIGHT_FLOOR = 0.012;
	static const float NIGHT_SKY_SHARE = 0.6;
	static const float MOON_SHIFT = 0.6;
	static const float3 MOON_TINT = float3(0.86, 1.01, 1.30);
	// The night fog: the fog colour goes NIGHT_FOG_GREY of the way toward the moonlit grey of its own luminance and
	// takes NIGHT_FOG_DARK of the sky's darkening, so the distance dissolves into a dull grey-blue that stays lighter
	// than the dark trees in it, and tree lines pale one behind the other. The haze at the camera takes the colour
	// of the darkened land around the player.
	static const float NIGHT_FOG_GREY = 0.6;
	static const float NIGHT_FOG_DARK = 0.5;
	// Light sources (see LightFindPS) on the glow buffer: a tap is a light when its brightest
	// channel, eroded over about 4 x 4 pixels (the smallest of itself and its right and lower neighbours: text strokes
	// are narrower), exceeds SRC_AMBIENT times the ambient and SRC_MIN, fully SRC_SOFT above that. A block must also be
	// SRC_SURROUND times as bright as the mean around it (two rings of SRC_RING1 and SRC_RING2 blocks), so an evenly
	// lit area counts by its edge, not its area: a big window near the camera gives about the light of a small one,
	// and a facade lit by the game gives none. A run of at least STRIP_RUN blocks in a row, at most STRIP_TALL blocks
	// tall, is a health bar or a cast bar and not a light. The sky is never a light (the moon has the rays), nor
	// anything where the UI mask reaches UI_SRC_FROM.
	static const float SRC_AMBIENT = 4.0;
	static const float SRC_SURROUND = 2.0;
	static const float SRC_MIN = 0.25;       // in a dark night everything not quite black passed for a light at 0.12
	static const float SRC_SOFT = 0.5;
	static const float SRC_RING1 = 2.0;
	static const float SRC_RING2 = 4.5;
	static const float STRIP_RUN = 4.5;
	static const float STRIP_TALL = 2.5;
	static const float UI_SRC_FROM = 0.2;
	static const float UI_SRC_FULL = 0.4;
	// The UI at night: under the UI mask, what is brighter than UI_KEEP_FROM times the ambient (fully from
	// UI_KEEP_FULL) keeps its brightness and gets no light from the lights: the icons, the text and the bars. The
	// night land under the mask is darker than that and is darkened like the land around it, so the painted areas of
	// the mask, larger than the UI, leave no lighter patches on the night ground and sky.
	static const float UI_KEEP_FROM = 2.5;
	static const float UI_KEEP_FULL = 5.0;
	// The light field: the sources blurred at three widths, LIGHT_SIG0 (L0), LIGHT_SIG1 (L1) and LIGHT_SIG2 (L2)
	// screen heights (see L0PS and DownBlur). Each field keeps the light-weighted log2 yards of its lights
	// in alpha, so a pixel knows how far the lights around it are. A light lights about LIGHT_R yards around it in
	// the world, which is LIGHT_R / (z FOV_TAN2) screen heights at depth z (60 degrees of vertical view assumed): a
	// near torch lights a wide patch, a far fire a small one. Each field takes its share of that width (a tent
	// between the widths in log scale, clamped to the range) scaled to the same peak, so a pool keeps its brightness
	// when the camera walks up to it. Land within about MATCH_YD yards of the lights' depth gets their light (a
	// Gaussian in the depth difference): the ground and the wall around a torch, not a hill far behind it. The lift
	// is LIFT_GAIN times that light over the ambient, eased into LIFT_MAX, on the colour before the night curve,
	// the albedo seen under the ambient.
	static const float LIGHT_SIG0 = 0.0224;
	static const float LIGHT_SIG1 = 0.0709;
	static const float LIGHT_SIG2 = 0.214;
	static const float LIGHT_R = 2.5;
	static const float FOV_TAN2 = 1.1547;
	static const float MATCH_YD = 3.5;
	static const float POOL_YD = 10.0;         // yards in depth a light keeps the game's lighting around it (see NightApply)
	static const float POOL_FROM = 0.05;       // light field (in multiples of the pixel) where a pool begins
	static const float POOL_FULL = 0.5;        // and where it is full
	static const float POOL_KEEP = 0.85;       // share of the game's own light kept in a full pool
	static const float POOL_TINT = 0.6;        // share of the light's own colour in a full pool
	static const float POOL_LIFT = 0.8;        // a full pool is this much brighter than the game made it
	static const float3 FIRE_COLOUR = float3(1.0, 0.5, 0.18); // the colour of firelight
	static const float FIRE_LEAN = 0.75;       // how far a warm light's tint leans toward it
	static const float LIFT_GAIN = 7.5;
	static const float LIFT_MAX = 2.0;
	static const float LIFT_LIT_CUT = 0.8;
	// The glow in the air: the same fields at a width of GLOW_AIR_R yards (times 1 + GLOW_AIR_R_FOG times the fog dial: wider
	// in thick fog), times GLOW_AIR_BASE plus GLOW_AIR_FOG times the fog between the camera and the lights, so everything
	// behind a light, the sky included, gets the same glow and no edge shows on the horizon. Nothing more than
	// GLOW_AIR_GATE octaves in front of the light gets it. GLOW_AIR_GAIN scales it, eased into GLOW_AIR_MAX, added as a screen
	// blend. The lights run at full strength in the night or where the ambient is at GLOW_AMB_DARK or darker, fade
	// out by GLOW_AMB_LIGHT, and the day (a bright sky) switches them off. Below LIGHT_EPS in the widest field no
	// light is near, and the pixel skips the rest.
	static const float GLOW_AIR_WIDE = 0.15;     // halved: in fog the wide levels spread the glow into a soapy haze
	static const float GLOW_AIR_TAIL = -0.6;     // the wide levels weigh less: a tighter halo
	static const float GLOW_AIR_BASE = 0.5;
	static const float GLOW_AIR_FOG = 1.0;       // halved for the same reason
	static const float GLOW_AIR_GATE_LO = 0.62;
	static const float GLOW_AIR_GATE_HI = 0.87;
	static const float GLOW_AIR_GAIN = 1.2;
	static const float GLOW_AIR_MAX = 0.32;
	// The air glow is eased as GLOW_AIR_MAX (1 - exp(-(a / GLOW_AIR_KNEE)^GLOW_AIR_POW)): below 1 the power lifts weak
	// light more than strong, so small lights (glowing eyes, a blade) get a visible halo and a big fire does not flood.
	static const float GLOW_AIR_KNEE = 0.045;
	static const float GLOW_AIR_POW = 0.6;
	static const float GLOW_AMB_DARK = 0.05;
	static const float GLOW_AMB_LIGHT = 0.14;
	static const float LIGHT_EPS = 4e-4;
	// Many lights in view (a street of lit windows) share the light: the glow strength is divided by 1 plus the light
	// of all of them (the mean of the widest field over the screen) over LIGHT_TOTAL_REF, eased over LIGHT_TOTAL_TIME
	// seconds. A few lamps in a field keep almost all of theirs, a town at night gets no brighter than the game.
	static const float LIGHT_TOTAL_REF = 0.064;
	static const float LIGHT_TOTAL_POW = 1.5;
	static const float LIGHT_TOTAL_TIME = 0.5;
	// «Темнота подземелий»: after CAVE_HOLD seconds without sky (the sky share below NIGHT_SKY_LO) the cave factor
	// eases to 1 over CAVE_TIME, and back to 0 over CAVE_TIME as soon as sky is seen. It works only where the ambient is
	// CAVE_AMB_DARK or darker, fading out by CAVE_AMB_LIGHT: a bright frame is never darkened.
	static const float CAVE_HOLD = 4.0;
	static const float CAVE_TIME = 1.0;
	static const float CAVE_AMB_DARK = 0.04;
	static const float CAVE_AMB_LIGHT = 0.10;
	// Moonlit mist at night: the fog of LegionGUFog is lifted toward MIST_COLOUR (never darkened) by its own opacity,
	// the sky by MIST_SKY of the far fog, and the land by no more than the sky, so far hills and the sky above them meet
	// without a step. Toward the moon (the
	// brightest sky of the night grid) it is up to 1 + MIST_MOON brighter, over MIST_MOON_R screen heights. Full from
	// «Темнота ночи» 50, less below, none at 0.
	static const float3 MIST_COLOUR = float3(0.100, 0.120, 0.155);
	static const float MIST_SKY = 0.5;
	static const float MIST_MOON = 0.8;
	static const float MIST_NIGHT_SHARE = 0.5;   // the moonlit mist at half: at full it laid a milky veil over the night
	static const float MIST_MOON_R = 0.35;

	// ---------------------------------------------------------------------------------------------------
	// Textures and samplers
	// ---------------------------------------------------------------------------------------------------

	texture2D ColorTex : COLOR;
	texture2D DepthTex : DEPTH;

	sampler2D ColorPoint { Texture = ColorTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };
	sampler2D ColorLinear { Texture = ColorTex; };
	// Point sampling, so depths are never blended across silhouettes.
	sampler2D DepthPoint { Texture = DepthTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };

	// Fog state, persistent between frames (ping-pong: Cur is written from Prev, then copied to Prev).
	// Texel 0: estimated engine fog colour, seeded flag. Texel 1: depth state (see DepthDecide).
	// Texel 2: the key, the colour of the land around the player, and its confidence (see FogHazeColour).
	// Texel 3: how open the view is, the horizon confidence eased like the colour (see FogAmount).
	// Texels 4 to 8: the night state (see NightStateTexel).
	texture2D FogCurTex { Width = 9; Height = 1; Format = RGBA32F; };
	texture2D FogPrevTex { Width = 9; Height = 1; Format = RGBA32F; };
	sampler2D FogCur { Texture = FogCurTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };
	sampler2D FogPrev { Texture = FogPrevTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };

	// Rays: the downsampled scene (rgb = colour, the UI not masked, a = how much of it is sky).
	texture2D RaysSceneTex { Width = LEGIONGU_SCENE_W; Height = LEGIONGU_SCENE_H; Format = RGBA8; };
	sampler2D RaysScenePoint { Texture = RaysSceneTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };

	// Rays: per cell of the frame, R = brightest pixel, G = share of bright sky, B = share of sky.
	texture2D RaysStatsTex { Width = STATS_W; Height = STATS_H; Format = RGBA16F; };
	sampler2D RaysStats { Texture = RaysStatsTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };

	// Rays: air along the line of sight per scene texel (0..1), for the composite.
	texture2D RaysAirTex { Width = LEGIONGU_SCENE_W; Height = LEGIONGU_SCENE_H; Format = R8; };
	sampler2D RaysAir { Texture = RaysAirTex; };

	// Rays state, persistent between frames. Texel 0: sun point xy the rays use, found share, seeded flag.
	// Texel 1: smoothed peak brightness. Texel 2: depth state (see DepthDecide).
	// Texel 3: followed sun xy, blend from the pinned point (0) to it (1), follow flag.
	// Texel 4: jump candidate xy, seconds it has held, seconds the sun has been lost.
	// Texel 5: the followed sun eased over SUN_SMOOTH_TIME. Texel 6: seconds since the depth last differed, and
	// the frame it was written in (FrameCount modulo STAMP_MOD), so the fog knows the sun is current.
	// Texel 7: the canopy estimate, eased over RaysAdaptTime, and this frame's value.
	texture2D RaysCurTex { Width = 8; Height = 1; Format = RGBA32F; };
	texture2D RaysPrevTex { Width = 8; Height = 1; Format = RGBA32F; };
	sampler2D RaysCur { Texture = RaysCurTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };
	sampler2D RaysPrev { Texture = RaysPrevTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };

	// Rays: the light buffer ping-pong (source, softening, radial and arc blur), LEGIONGU_LIGHT_H rows, bilinear
	// like the original's StretchRect and blur taps.
	texture2D RaysPingTex { Width = LEGIONGU_LIGHT_W; Height = LEGIONGU_LIGHT_H; Format = RGBA16F; };
	texture2D RaysPongTex { Width = LEGIONGU_LIGHT_W; Height = LEGIONGU_LIGHT_H; Format = RGBA16F; };
	sampler2D RaysPing { Texture = RaysPingTex; };
	sampler2D RaysPong { Texture = RaysPongTex; };

#if LEGIONGU_UI_MASK
	// A quarter of the screen size per axis, read bilinear: a mask edge is soft anyway, and a full-size mask read
	// by two full-screen passes cost 0.08 ms at 3440 x 1440.
	texture2D UIMaskTex < source = "LegionGUMask.png"; > { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = R8; };
	sampler2D UIMaskSampler { Texture = UIMaskTex; };
#endif

	// Lights (see LightFindPS): per block of the glow buffer the light (rgb = light, a = its luminance times log2
	// yards, so a blur keeps the light-weighted depth). The light field at three widths (rgb = light,
	// a = the light-weighted log2 yards of the lights in it), and what a pixel needs of it, combined on the glow
	// buffer: the light that falls on land (LitTex) and the glow in the air (AirTex), each with its lights' log2
	// yards in alpha.
	texture2D LightSrcTex { Width = LEGIONGU_GLOW_W; Height = LEGIONGU_GLOW_H; Format = RGBA16F; };
	// What LightFind sees this frame, and last frame's steady field (see LightSteadyPS).
	texture2D LightRawTex { Width = LEGIONGU_GLOW_W; Height = LEGIONGU_GLOW_H; Format = RGBA16F; };
	texture2D LightPrevTex { Width = LEGIONGU_GLOW_W; Height = LEGIONGU_GLOW_H; Format = RGBA16F; };
	sampler2D LightRaw { Texture = LightRawTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };
	sampler2D LightPrev { Texture = LightPrevTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };
	texture2D L0Tex { Width = LEGIONGU_GLOW_W; Height = LEGIONGU_GLOW_H; Format = RGBA16F; };
	texture2D L1Tex { Width = LEGIONGU_L1_W; Height = LEGIONGU_L1_H; Format = RGBA16F; };
	texture2D L2Tex { Width = LEGIONGU_L2_W; Height = LEGIONGU_L2_H; Format = RGBA16F; };
	texture2D LitTex { Width = LEGIONGU_GLOW_W; Height = LEGIONGU_GLOW_H; Format = RGBA16F; };
	texture2D AirTex { Width = LEGIONGU_GLOW_W; Height = LEGIONGU_GLOW_H; Format = RGBA16F; };
	sampler2D LightSrc { Texture = LightSrcTex; AddressU = BORDER; AddressV = BORDER; };
	// The night grid (see NightGridPS), 32 x 16 with its mips down to 1 x 1.
	texture2D NightGridATex { Width = 32; Height = 16; Format = RGBA16F; MipLevels = 6; };
	texture2D NightGridBTex { Width = 32; Height = 16; Format = RGBA16F; MipLevels = 6; };
	sampler2D NightGridA { Texture = NightGridATex; };
	sampler2D NightGridB { Texture = NightGridBTex; };
	sampler2D L0 { Texture = L0Tex; AddressU = BORDER; AddressV = BORDER; };
	sampler2D L1 { Texture = L1Tex; AddressU = BORDER; AddressV = BORDER; };
	sampler2D L2 { Texture = L2Tex; AddressU = BORDER; AddressV = BORDER; };
	sampler2D LitS { Texture = LitTex; AddressU = BORDER; AddressV = BORDER; };
	sampler2D AirS { Texture = AirTex; AddressU = BORDER; AddressV = BORDER; };

	// ---------------------------------------------------------------------------------------------------
	// Helpers
	// ---------------------------------------------------------------------------------------------------

	void FullscreenVS(uint id : SV_VertexID, out float4 pos : SV_Position, out float2 uv : TEXCOORD0)
	{
		uv.x = (id == 2) ? 2.0 : 0.0;
		uv.y = (id == 1) ? 2.0 : 0.0;
		pos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
	}

	// Share of the way to a new value this frame for a time constant tau, the same easing as the
	// original's peak adaptation. tau 0 means instant.
	float Rate(float dt, float tau)
	{
		return tau > 0.0 ? 1.0 - exp(-dt / tau) : 1.0;
	}

	// Last frame's duration in seconds, clamped like the original (0..0.5 s).
	float FrameSeconds()
	{
		return clamp(FrameTime * 0.001, 0.0, 0.5);
	}

	// 1 where the painted mask says "UI", 0 on the world.
	float UIMask(float2 uv)
	{
#if LEGIONGU_UI_MASK
		return saturate(tex2Dlod(UIMaskSampler, float4(uv, 0.0, 0.0)).x);
#else
		return 0.0;
#endif
	}

	// Raw depth with the same coordinate fixes as ReShade::GetLinearizedDepth, without its linearisation.
	float RawDepth(float2 texcoord)
	{
#if RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
		texcoord.y = 1.0 - texcoord.y;
#endif
#if RESHADE_DEPTH_INPUT_IS_MIRRORED
		texcoord.x = 1.0 - texcoord.x;
#endif
		texcoord.x /= RESHADE_DEPTH_INPUT_X_SCALE;
		texcoord.y /= RESHADE_DEPTH_INPUT_Y_SCALE;
#if RESHADE_DEPTH_INPUT_X_PIXEL_OFFSET
		texcoord.x -= RESHADE_DEPTH_INPUT_X_PIXEL_OFFSET * BUFFER_RCP_WIDTH;
#else
		texcoord.x -= RESHADE_DEPTH_INPUT_X_OFFSET / 2.000000001;
#endif
#if RESHADE_DEPTH_INPUT_Y_PIXEL_OFFSET
		texcoord.y += RESHADE_DEPTH_INPUT_Y_PIXEL_OFFSET * BUFFER_RCP_HEIGHT;
#else
		texcoord.y += RESHADE_DEPTH_INPUT_Y_OFFSET / 2.000000001;
#endif
		float depth = tex2Dlod(DepthPoint, float4(texcoord, 0.0, 0.0)).x * RESHADE_DEPTH_MULTIPLIER;
#if RESHADE_DEPTH_INPUT_IS_LOGARITHMIC
		const float C = 0.01;
		depth = (exp(depth * log(C + 1.0)) - 1.0) / C;
#endif
		return depth;
	}

	// The depth type in use: 1 = reversed (near 1, far 0), 0 = normal. autoReversed is the detected type.
	float EffectiveReversed(float autoReversed)
	{
		if (DepthType == 1)
			return 0.0;
		if (DepthType == 2)
			return 1.0;
		return autoReversed;
	}

	// u is 1 at the near plane and 0 at the far plane for either depth type.
	float DepthU(float raw, float reversed)
	{
		return reversed > 0.5 ? raw : 1.0 - raw;
	}

	// Planar view distance in yards: z = n f / (n + u (f - n)), or n / u with an infinite far plane.
	float Yards(float u)
	{
		float n = DepthNear;
		float f = DepthFar;
		if (f > n)
			return n * f / (n + u * (f - n));
		return n / max(u, 1e-9);
	}

	bool IsSky(float u)
	{
		return u <= SKY_EPSILON || Yards(u) >= SkyFrom;
	}

	// 1 for sky, 0 for geometry, with the soft ramp before SkyFrom (see SKY_RAMP). Used by the fog only.
	float SkyShare(float u)
	{
		if (u <= SKY_EPSILON)
			return 1.0;
		return saturate((Yards(u) / SkyFrom - (1.0 - SKY_RAMP)) / SKY_RAMP);
	}

	float2 GridUV(int i, int j)
	{
		return float2(0.10 + 0.80 * (i + 0.5) / GRID_X, 0.05 + 0.70 * (j + 0.5) / GRID_Y);
	}

	// Raw depth over the grid, gathered once per state texel.
	struct DepthScan
	{
		float rawMin;
		float rawMax;
		float hiShare;  // share of taps above 0.9: normal depth puts everything past about 10 near planes there
		float loShare;  // share of taps below 0.1: the same for reversed depth
		float ones;     // taps exactly 1, the normal clear value
		float zeros;    // taps exactly 0, the reversed clear value
	};

	DepthScan ScanDepth()
	{
		DepthScan d;
		d.rawMin = 1e30;
		d.rawMax = -1e30;
		float hi = 0.0;
		float lo = 0.0;
		d.ones = 0.0;
		d.zeros = 0.0;
		[loop]
		for (int j = 0; j < GRID_Y; ++j)
		{
			[unroll]
			for (int i = 0; i < GRID_X; ++i)
			{
				float raw = RawDepth(GridUV(i, j));
				d.rawMin = min(d.rawMin, raw);
				d.rawMax = max(d.rawMax, raw);
				hi += raw > 0.9 ? 1.0 : 0.0;
				lo += raw < 0.1 ? 1.0 : 0.0;
				d.ones += raw == 1.0 ? 1.0 : 0.0;
				d.zeros += raw == 0.0 ? 1.0 : 0.0;
			}
		}
		d.hiShare = hi / float(GRID_X * GRID_Y);
		d.loShare = lo / float(GRID_X * GRID_Y);
		return d;
	}

	// ReShade bound a real depth buffer (the signed build and MSAA leave a 1x1 empty view) and the grid taps
	// differ this frame.
	bool DepthVaried(DepthScan d)
	{
		int2 size = tex2Dsize(DepthPoint);
		return size.x > 1 && size.y > 1 && d.rawMax > d.rawMin;
	}

	// Depth state, stored in one texel of each technique's state texture:
	//   x = depth present, faded over DEPTH_FADE_TIME (the fog fades in over it)
	//   y = depth present this frame, 0 or 1 (without it there is no fog and, if asked, no rays)
	//   z = 0 until the type is decided, then 1 + the smoothed evidence for normal depth (0..1)
	//   w = detected type, 1 = reversed
	// "Present" means the taps differ (DepthVaried) and, with the type set to Auto, the type is decided. A
	// frame of nothing but far-plane values (looking straight at the sky, or a buffer that is cleared) keeps
	// the last decision, so a look at the sky does not switch the fog off.
	// The type: the far-plane clear value is exactly 1 only in normal depth and exactly 0 only in reversed
	// depth, so frames that show the sky are the evidence. The first decision, when no sky is in view, needs a
	// clear majority: more than 80% of the taps above 0.9 (normal) or below 0.1 (reversed). A camera pressed
	// against a wall gives values in between and waits for a later frame. Frames without sky never change the
	// decision, so a wall right in front of the camera cannot flip it, and the smoothed evidence must cross
	// 0.2 or 0.8 before the type flips, so it never flickers.
	float4 DepthDecide(DepthScan d, float4 prev, bool seeded, float dt)
	{
		int2 size = tex2Dsize(DepthPoint);
		bool sizeOk = size.x > 1 && size.y > 1;
		bool varied = DepthVaried(d);
		bool clearValue = !(d.rawMax > d.rawMin) && (d.rawMin == 0.0 || d.rawMin == 1.0);
		bool wasPresent = seeded && prev.y > 0.5;
		bool present = varied || (sizeOk && wasPresent && clearValue);

		float score = prev.z;
		float reversed = prev.w;
		if (present)
		{
			float evidence = -1.0;
			// A lone exact 1 or 0 can also be geometry clamped at the near plane (a cloak or a staff right at the camera
			// while looking down); it counts only when the bulk of the taps agrees with that type.
			if (d.ones > 0.0 && d.zeros == 0.0 && d.hiShare > 0.5)
				evidence = 1.0;
			else if (d.zeros > 0.0 && d.ones == 0.0 && d.loShare > 0.5)
				evidence = 0.0;

			if (score < 0.5)
			{
				float share = evidence >= 0.0 ? evidence : (d.hiShare > 0.8 ? 1.0 : (d.loShare > 0.8 ? 0.0 : -1.0));
				if (share >= 0.0)
				{
					score = 1.0 + share;
					reversed = share < 0.5 ? 1.0 : 0.0;
				}
			}
			else if (evidence >= 0.0)
			{
				score = lerp(score, 1.0 + evidence, Rate(dt, DEPTH_TYPE_TIME));
				if (score < 1.2)
					reversed = 1.0;
				else if (score > 1.8)
					reversed = 0.0;
			}
		}

		// Until the automatic type is decided, depth is not used at all: a wrong guess would fog the frame
		// as if everything were at the near plane.
		bool typeKnown = DepthType != 0 || score >= 0.5;
		float presentNow = (present && typeKnown) ? 1.0 : 0.0;
		float fade = seeded ? lerp(prev.x, presentNow, Rate(dt, DEPTH_FADE_TIME)) : presentNow;
		fade = fade > 0.999 ? 1.0 : (fade < 0.001 ? 0.0 : fade);
		return float4(fade, presentNow, score, reversed);
	}

	// The dial t from «Густота тумана» s. The climb grows with sqrt(t), so on a linear slider the first tenth
	// changed the picture 5 to 10 times as much as a later tenth (bench, canopy and field). The slider is
	// therefore squared: t = s^2 / 6000, 0.6 at the shipped 60 and 1.67 at 100. It is written as s / 100 plus
	// a term that is exactly 0 at 60, so the shipped default keeps the exact value of the linear dial.
	float FogDial()
	{
		float t = FogThickness * 0.01;
		return t + t * (FogThickness - 60.0) * (1.0 / 60.0);
	}

	// «Дальность тумана» scales 1 / FogReach: the climb is distance / reach, so even steps of 1 / reach change
	// the fog on every object by the same amount (bench: even steps under the canopy, where a log scale of the
	// reach made the near end 9 times as sensitive as the far end). 50 keeps FogReach, 0 brings the wall
	// 1.8 times nearer, 100 moves it 5 times farther. A multiplier, so at 50 the value stays exact. With the
	// shipped 160 yards and density 60 the wall stands at 115 yards at 0, 206 at 50 and 1030 at 100.
	static const float REACH_STEP = 0.016;
	float FogNearness()
	{
		return 1.0 + REACH_STEP * (50.0 - FogDistance);
	}

	// The original's OutColor: desaturate, tint and darken the fog colour, each scaled by the dial. The dial
	// goes up to 1.67, so each share is clamped to 1 for any value in the preset.
	float3 FogColourOut(float3 src, float t)
	{
		float lum = dot(src, LUMA601);
		float3 v = lerp(src, float3(lum, lum, lum), saturate(FogDesaturate * t));
		v = lerp(v, FogTint, saturate(FogTintAmount * t));
		return saturate(v * (1.0 - saturate(FogDarken * t)));
	}

	float3 FogSourceColour(float4 state0)
	{
		return FogColourMode == 1 ? FogColourManual : state0.rgb;
	}

	// The distance fog of a climb s, where s = 1 is the old solid wall: s itself up to the cap, then the cap
	// that rises slowly with the distance, joined by a quadratic smooth minimum over FOG_FAR_KNEE (see
	// FOG_FAR_CAP).
	float FarCap(float s)
	{
		float cap = min(FOG_FAR_CAP + FOG_FAR_RISE * log2(max(s / FOG_FAR_FROM, 1.0)), FOG_FAR_TOP);
		float h = saturate(1.0 - abs(s - cap) / FOG_FAR_KNEE);
		return min(s, cap) - h * h * FOG_FAR_KNEE * 0.25;
	}
	// The fog of one depth tap at dial t: the haze haze0 at the camera (see FogAmount), a linear climb that would
	// reach a solid wall at FogReach / sqrt(t) (scaled by «Дальность тумана») but bends into the far cap before it
	// (see FarCap), and FogSky t on the sky. Like the original's dial, more thickness adds haze and pulls the wall
	// in: at 60 the haze is 0.6 of the setting and the wall stands 1.29 times farther than at 100. With the shipped
	// 0.30 and 160 yards, at 60, under trees: 18% at the camera, 34% at 40 yards, 58% at 100, 89% at 250 and 91% at
	// 1500. In the open the haze is weaker: 7%, 25%, 52%, 88%, 90%. The original at 60 gave 18%, 29% at 42 yards,
	// 46% at 104 and solid from 307; the owner and the judge asked for a denser middle distance, like the reference
	// frames. The opacity comes in two layers that add up to that: x = the distance fog, the climb, in the fog
	// colour, over y = the haze, h (1 - x), in the haze colour (see FogHazeColour). The haze is all
	// of the fog at the camera and fades out of it with distance. Haze and sky shares are clamped to 1.
	float2 FogAt(float2 uv, float reversed, float t, float haze0)
	{
		float u = DepthU(RawDepth(uv), reversed);
		float sky = SkyShare(u);
		float dist = FarCap(Yards(u) * sqrt(t) / FogReach * FogNearness());
		float haze = haze0 * (1.0 - dist);
		return float2(lerp(dist, saturate(FogSky * t), sky), haze * (1.0 - sky));
	}

	// The fog opacity at a pixel for dial t, split as in FogAt. Four depth taps near the pixel corners are
	// averaged, so the fog edge on a silhouette against the sky is as soft as the colour edge (render scale and
	// CMAA blend it) and does not crawl. The taps sit 0.45 pixel from the centre, not 0.5: at render scale 1 a corner lies exactly
	// on a depth texel boundary, and point sampling would then pick either neighbour by float rounding, pixel by
	// pixel. Without depth this frame there is no fog at all: the empty view reads as the near plane and would
	// haze the whole frame, loading screens included. depthState.x fades the fog in when depth appears.
	// open is the eased horizon confidence (fog state texel 3): with the horizon in view the haze at the camera
	// is FOG_HAZE_OPEN of FogHaze t.
	float2 FogAmount(float2 uv, float t, float4 depthState, float open)
	{
		if (depthState.y < 0.5 || depthState.x <= 0.0)
			return float2(0.0, 0.0);
		float reversed = EffectiveReversed(depthState.w);
		float haze0 = saturate(FogHaze * t) * lerp(1.0, FOG_HAZE_OPEN, open);
		float2 o = 0.45 * float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
		float2 a = 0.25 * (FogAt(uv + float2(-o.x, -o.y), reversed, t, haze0) + FogAt(uv + float2(o.x, -o.y), reversed, t, haze0)
		                 + FogAt(uv + float2(-o.x, o.y), reversed, t, haze0) + FogAt(uv + float2(o.x, o.y), reversed, t, haze0));
		return a * (depthState.x * (1.0 - UIMask(uv)));
	}

	// Closeness of a pixel to a point, 1 at the point and 0 from INSCATTER_RADIUS screen heights on, falling
	// with INSCATTER_POWER like the glow of the sky.
	float SunGlow(float2 uv, float2 p)
	{
		float d = length((uv - p) * float2(ASPECT, 1.0));
		float g = saturate(1.0 - d / INSCATTER_RADIUS);
		return pow(g, INSCATTER_POWER);
	}

	// The fog colour lit by the sun: g is the closeness to the sun times its strength, k the strength. The
	// colour rises and warms toward the sun and drops and cools away from it, and stays below the knee. With
	// k = g it only rises and warms.
	float3 FogLitMix(float3 fogColour, float g, float k)
	{
		float3 warm = RaysColour / max(dot(RaysColour, LUMA601), 0.1);
		float3 cool = COOL_TINT / dot(COOL_TINT, LUMA601);
		float3 tint = 1.0 + (warm - 1.0) * (INSCATTER_WARM * g) + (cool - 1.0) * (INSCATTER_COOL * (k - g));
		float3 lit = fogColour * tint * (1.0 + INSCATTER_GAIN * g - INSCATTER_DIM * (k - g));
		float l = dot(lit, LUMA601);
		float knee = max(INSCATTER_KNEE, dot(fogColour, LUMA601));
		return saturate(lit * min(1.0, knee / max(l, 1e-4)));
	}

	// Sunlight in the fog. Haze scatters sunlight mostly forward, so the air is brighter and warmer toward the
	// sun, and that is what makes fog read as lit air and not as a filter. The sun is last frame's from
	// LegionGURays: the followed sun (or the bright gap it hides behind) at full strength, the pinned point at
	// INSCATTER_PINNED, blended the way the rays blend. x = closeness times strength, y = strength; (0, 0),
	// the colour unchanged, when the rays state is not current (LegionGURays off).
	float2 SunInFog(float2 uv)
	{
		float4 r0 = tex2Dfetch(RaysPrev, int2(0, 0));
		uint stamp = uint(tex2Dfetch(RaysPrev, int2(6, 0)).y + 0.5);
		float age = float((FrameCount + STAMP_MOD - stamp % STAMP_MOD) % STAMP_MOD);
		if (r0.w < 0.5 || age > STAMP_LAG)
			return float2(0.0, 0.0);
		float blend = SunMode == 0 ? saturate(tex2Dfetch(RaysPrev, int2(3, 0)).z) : 0.0;
		float gSun = SunGlow(uv, tex2Dfetch(RaysPrev, int2(5, 0)).xy);
		float gPin = SunGlow(uv, float2(SunX, SunY));
		return float2(lerp(INSCATTER_PINNED * gPin, gSun, blend), lerp(INSCATTER_PINNED, 1.0, blend));
	}

	// The colour of the haze layer. The distance fog keeps the fog colour, so the distance dissolves into it.
	// The haze at the camera is light scattered on the last few yards, and it takes HAZE_SHADE of the way from
	// the fog colour to the colour of the land around the player (key, see FogStatePS): at dusk or under dense
	// trees a haze as bright as the horizon would flood the dark ground, and in the open a haze of the sky's
	// blue would wash the colour out of the grass at the player's feet.
	float3 FogHazeColour(float3 fogColour, float4 key)
	{
		return lerp(fogColour, key.rgb, HAZE_SHADE * key.a);
	}

	// The fogged pixel: the frame under the two layers of FogAmount, each lit by the sun (see SunInFog). Both
	// layers are brighter and warmer toward the sun. Only the haze turns dimmer and cooler away from it: the
	// distance fog is what far land dissolves into, and a dimmed one left the far hills darker than the sky
	// right above them, like cardboard (judge, round 2: 37 to 49 levels on field and snow).
	float3 FogBlend(float3 c, float2 a, float3 fogColour, float4 key, float2 sun)
	{
		float3 lit = FogLitMix(fogColour, sun.x, sun.x);
		float3 haze = FogLitMix(FogHazeColour(fogColour, key), sun.x, sun.y);
		return c * (1.0 - a.x - a.y) + lit * a.x + haze * a.y;
	}

	bool OnBorder(float2 uv)
	{
		float2 h = float2(uv.x * ASPECT, uv.y);
		float2 hFar = float2((1.0 - uv.x) * ASPECT, 1.0 - uv.y);
		return min(min(h.x, h.y), min(hFar.x, hFar.y)) < 0.015;
	}

	// ---------------------------------------------------------------------------------------------------
	// LegionGUFog
	// ---------------------------------------------------------------------------------------------------

	// The share the lights give up when many are in view (see LIGHT_TOTAL_REF): x^LIGHT_TOTAL_POW.
	float LightTotalPow(float x)
	{
		return exp2(LIGHT_TOTAL_POW * log2(max(x, 1e-6)));
	}

	// How strongly the lights glow in this frame, 0..1: in the night, or where the ambient is dark (a dungeon), and
	// never under a bright sky.
	float LightsDarkness(float night, float day, float ambient)
	{
		float dark = 1.0 - smoothstep(GLOW_AMB_DARK, GLOW_AMB_LIGHT, ambient);
		return saturate(max(night, dark)) * (1.0 - day);
	}

	// The night grid: one texel per tap of a 32 x 16 grid over the centre of the frame (the fog grid's area), all read in
	// parallel, and their means in the last mip level, which ReShade builds after the pass. A: x = log2 luminance on
	// the sky, y = 1 on the sky, z = log2 luminance on land, w = 1 on land. B: rgb = log2 colour on the sky, a = the
	// light of last frame's widest field there, before any strength (see LIGHT_TOTAL_REF). Without depth (last frame's depth state) all zeros.
	void NightGridPS(float4 pos : SV_Position, float2 uv : TEXCOORD0, out float4 a : SV_Target0, out float4 b : SV_Target1)
	{
		a = float4(0.0, 0.0, 0.0, 0.0);
		b = float4(0.0, 0.0, 0.0, 0.0);
		float4 depthPrev = tex2Dfetch(FogPrev, int2(1, 0));
		if (depthPrev.y < 0.5)
			return;
		float2 g = float2(0.10 + 0.80 * uv.x, 0.05 + 0.70 * uv.y);
		float3 c = max(tex2Dlod(ColorPoint, float4(g, 0.0, 0.0)).rgb, 1.0 / 255.0);
		float l = log2(max(dot(c, LUMA601), 1.0 / 255.0));
		bool sky = IsSky(DepthU(RawDepth(g), EffectiveReversed(depthPrev.w)));
		a = sky ? float4(l, 1.0, 0.0, 0.0) : float4(0.0, 0.0, l, 1.0);
		b = float4(sky ? log2(c) : float3(0.0, 0.0, 0.0), dot(tex2Dlod(L2, float4(g, 0.0, 0.0)).rgb, LUMA601));
	}

	// The night texels of the fog state, written by FogStatePS from the night grid (see NIGHT_SKY_DARK and
	// AMBIENT_TIME). Texel 4: night, day, land in view (eased), seeded flag. Texel 5: the ambient, this frame's
	// darkening s and glow g with the sliders, the depth fade and the land in view in them, and the scale m of the
	// ambient light (see NIGHT_M100). Texel 6: this frame's sky luminance, its coldness and its share of the grid, for the view «Ночь и огни», and
	// the eased light of all the lights. Without depth s and g are 0. The state is seeded on the first frame with depth
	// and land in view, so it starts at the right value.
	float4 NightStateTexel(int texel, float4 depthState, float dt)
	{
		float4 prev4 = tex2Dfetch(FogPrev, int2(4, 0));
		float4 prev5 = tex2Dfetch(FogPrev, int2(5, 0));
		bool seeded = prev4.w > 0.5;
		bool present = depthState.y > 0.5;

		float4 ga = tex2Dlod(NightGridA, float4(0.5, 0.5, 0.0, 5.0));
		float4 gb = tex2Dlod(NightGridB, float4(0.5, 0.5, 0.0, 5.0));
		float conf = present ? smoothstep(NIGHT_SKY_LO, NIGHT_SKY_HI, ga.y) : 0.0;
		bool landOk = present && ga.w >= NIGHT_LAND_MIN;
		float skyL = exp2(ga.x / max(ga.y, 1e-4));
		float3 skyC = exp2(gb.rgb / max(ga.y, 1e-4));
		float cold = skyC.b / max(max(skyC.r, skyC.g), 1e-4);
		float ambient = exp2(ga.z / max(ga.w, 1e-4));
		float lights = seeded ? lerp(tex2Dfetch(FogPrev, int2(6, 0)).w, gb.a, Rate(dt, LIGHT_TOTAL_TIME)) : gb.a;
		if (texel == 6)
			return float4(skyL, cold, ga.y, lights);
		if (texel == 8)
		{
			// the moon side: the centroid of the night grid's sky taps weighted steeply by their luminance
			float3 mw = float3(0.0, 0.0, 0.0);
			float peak = 0.0;
			[loop]
			for (int j = 0; j < 16; ++j)
			{
				[loop]
				for (int i = 0; i < 32; ++i)
				{
					float4 q = tex2Dfetch(NightGridA, int2(i, j));
					float w = q.y > 0.5 ? exp2(4.0 * q.x) : 0.0;
					mw += float3(0.10 + 0.80 * (i + 0.5) / 32.0, 0.05 + 0.70 * (j + 0.5) / 16.0, 1.0) * w;
					peak = max(peak, q.y > 0.5 ? q.x : -20.0);
				}
			}
			float4 prev8 = tex2Dfetch(FogPrev, int2(8, 0));
			float4 moon = float4(mw.xy / max(mw.z, 1e-12), smoothstep(-3.5, -2.0, peak), 1.0);
			if (mw.z <= 0.0)
				moon = float4(prev8.xy, 0.0, 1.0);
			return prev8.w > 0.5 ? lerp(prev8, moon, Rate(dt, 0.5)) : moon;
		}
		bool seedNow = !seeded && landOk;

		float nm = (1.0 - smoothstep(NIGHT_SKY_DARK, NIGHT_SKY_LIGHT, skyL)) * smoothstep(NIGHT_COLD_FROM, NIGHT_COLD_FULL, cold);
		float dm = smoothstep(DAY_SKY_FROM, DAY_SKY_FULL, skyL);
		// With the addon the game's clock decides, not the sky: a night sky in WoW is often a bright grey blue, and the
		// fog lifts it further, so the owner saw no night at all. Night from 21 to 5 o'clock, fading over about an hour
		// on each side; indoors none (the dungeon darkness below works on its own).
		if (LegionGUState(1u))
		{
			float h = LegionGUHour();
			nm = saturate(1.0 - smoothstep(4.5, 6.0, h) + smoothstep(20.0, 21.5, h));
			dm = 1.0 - nm;
			conf = 1.0;
			landOk = present;
		}
		float n = prev4.x;
		float d = prev4.y;
		float land = prev4.z;
		if (seedNow)
		{
			n = nm * conf;
			d = dm * conf;
			land = 1.0;
		}
		else if (seeded)
		{
			if (landOk)
			{
				float target = (nm <= 0.0 || nm >= 1.0) ? nm : clamp(n, nm - NIGHT_BAND, nm + NIGHT_BAND);
				float r = Rate(dt, NIGHT_TIME) * conf;
				n = lerp(n, target, r);
				d = lerp(d, dm, r);
				float q = Rate(dt, NIGHT_NOSKY_TIME) * (1.0 - conf);
				n = lerp(n, 0.0, q);
				d = lerp(d, 0.0, q);
			}
			land = lerp(land, landOk ? 1.0 : 0.0, Rate(dt, NIGHT_LAND_TIME));
		}
		n = n > 0.999 ? 1.0 : (n < 0.001 ? 0.0 : n);
		d = d > 0.999 ? 1.0 : (d < 0.001 ? 0.0 : d);
		land = land > 0.999 ? 1.0 : (land < 0.001 ? 0.0 : land);
		if (texel == 5 || texel == 7)
		{
			float a = landOk ? ambient : prev5.x;
			a = (seeded && landOk) ? lerp(prev5.x, a, Rate(dt, AMBIENT_TIME)) : a;
			float live = present ? land * depthState.x : 0.0;
			float sNight = LegionGUValue(LEGIONGU_CTL_NIGHT, NightDarkness) * 0.01 * n * live;
			float deep = LegionGUValue(LEGIONGU_CTL_NIGHT_DEPTH, NightDepth) * 0.01 * n * live;
			// Indoors the room itself gets no night; the night outside rides in texel 7 for what is seen through doors and
			// windows (see NightApply).
			float sOut = sNight;
			float deepOut = deep;
			bool inside = LegionGUState(2u);
			if (inside)
			{
				sNight = 0.0;
				deep = 0.0;
			}
			// the cave: seconds without sky, and the factor eased toward 1 after CAVE_HOLD of them (see CAVE_HOLD)
			float4 prev7 = tex2Dfetch(FogPrev, int2(7, 0));
			float noSky = (present && ga.y < NIGHT_SKY_LO) ? prev7.x + dt : 0.0;
			float cave = lerp(prev7.y, noSky >= CAVE_HOLD ? 1.0 : 0.0, Rate(dt, CAVE_TIME));
			cave = cave > 0.999 ? 1.0 : (cave < 0.001 ? 0.0 : cave);
			if (texel == 7)
				return float4(min(noSky, 100.0), cave, sOut, deepOut);
			float sCave = LegionGUValue(LEGIONGU_CTL_CAVE, CaveDarkness) * 0.01 * cave * (1.0 - smoothstep(CAVE_AMB_DARK, CAVE_AMB_LIGHT, max(a, AMBIENT_MIN))) * live;
			float s = max(sNight, sCave);
			float g = LegionGUValue(LEGIONGU_CTL_GLOW, LightGlow) * 0.01 * LightsDarkness(inside ? 0.0 : n, d, max(a, AMBIENT_MIN)) * live / (1.0 + LightTotalPow(lights / LIGHT_TOTAL_REF));
			g *= 1.0 + DEEP_GLOW * deep;
			float m = max(exp2(s * log2(NIGHT_M100) + deep * log2(NIGHT_DEEP)), min(1.0, NIGHT_FLOOR * (1.0 - deep) / max(a, AMBIENT_MIN)));
			return float4(a, s, g, m);
		}
		return float4(n, d, land, (seeded || seedNow) ? 1.0 : 0.0);
	}
	// The horizon tap of grid column i: the sky tap right above the column's topmost geometry, when that
	// geometry is far. Far land sits low in the view, so the sky above it is the band at the horizon, which
	// WoW paints in its fog colour. A near tree or roof gives nothing: the sky above it is high sky.
	// weight is 0 for a column without such a tap (geometry at the top of the grid, or only sky). Next to the
	// sun the horizon glows in its light, and SunInFog adds that glow back to the fog, so a tap counts less
	// the closer it is to the sun.
	void HorizonTap(int i, float reversed, out float3 colour, out float weight)
	{
		colour = float3(0.0, 0.0, 0.0);
		weight = 0.0;
		float seen = 0.0;
		float2 above = float2(0.0, 0.0);
		[loop]
		for (int j = 0; j < GRID_Y; ++j)
		{
			float2 g = GridUV(i, j);
			float u = DepthU(RawDepth(g), reversed);
			if (!IsSky(u))
			{
				weight = saturate(Yards(u) / FogSampleFrom - 1.0) * seen * (1.0 - SunInFog(above).x);
				break;
			}
			colour = tex2Dlod(ColorPoint, float4(g, 0.0, 0.0)).rgb;
			seen = 1.0;
			above = g;
		}
	}

	// Texel 0 keeps the colour, texel 1 the depth state, texel 2 the key: the mean colour of the land nearer
	// than NEAR_LAND and 1 in alpha, alpha 0 without such land. Texel 3 keeps how open the view is: the horizon
	// confidence. Colour, key and openness are eased over FogColourAdapt.
	float4 FogStatePS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		int texel = int(pos.x);
		float4 prev0 = tex2Dfetch(FogPrev, int2(0, 0));
		float4 prev1 = tex2Dfetch(FogPrev, int2(1, 0));
		bool seeded = prev0.w > 0.5;
		float dt = FrameSeconds();

		float4 depthState = DepthDecide(ScanDepth(), prev1, seeded, dt);
		if (texel == 1)
			return depthState;
		if (texel >= 4)
			return NightStateTexel(texel, depthState, dt);

		float reversed = EffectiveReversed(depthState.w);
		float farFrom = FogSampleFrom * FAR_LAND_SHARE;

		// The frame's average; the far land weighted by distance and by the square of its brightness, so the
		// farthest and brightest land wins (farN counts it without the weights, for the confidence); the mean
		// brightness of the sky without the sun.
		float3 sumC = float3(0.0, 0.0, 0.0);
		float3 farWC = float3(0.0, 0.0, 0.0);
		float farW = 0.0;
		float farN = 0.0;
		float3 skyC = float3(0.0, 0.0, 0.0);
		float skyN = 0.0;
		float3 nearC = float3(0.0, 0.0, 0.0);
		float nearN = 0.0;
		[loop]
		for (int j = 0; j < GRID_Y; ++j)
		{
			[unroll]
			for (int i = 0; i < GRID_X; ++i)
			{
				float2 g = GridUV(i, j);
				float3 c = tex2Dlod(ColorPoint, float4(g, 0.0, 0.0)).rgb;
				float l = dot(c, LUMA601);
				sumC += c;

				float u = DepthU(RawDepth(g), reversed);
				float z = Yards(u);
				bool sky = IsSky(u);
				float n = sky ? 0.0 : saturate(z / farFrom - 1.0);
				float w = n * min(z / farFrom, FAR_WEIGHT_CAP) * (l * l + 1e-4);
				farN += n;
				farW += w;
				farWC += c * w;
				float s = (sky && l < SKY_WHITE) ? 1.0 : 0.0;
				skyC += c * s;
				skyN += s;
				float near = (!sky && z < NEAR_LAND) ? 1.0 : 0.0;
				nearC += c * near;
				nearN += near;
			}
		}
		float3 average = sumC / float(GRID_X * GRID_Y);
		if (texel == 2)
		{
			bool known = nearN > FOG_KEY_TAPS && depthState.y > 0.5;
			float4 key = known ? float4(nearC / nearN, 1.0) : float4(tex2Dfetch(FogPrev, int2(2, 0)).rgb, 0.0);
			return seeded ? lerp(tex2Dfetch(FogPrev, int2(2, 0)), key, Rate(dt, FogColourAdapt)) : key;
		}

		// The horizon colour, from the sky right above far land in each grid column.
		float3 horWC = float3(0.0, 0.0, 0.0);
		float horW = 0.0;
		[loop]
		for (int i1 = 0; i1 < GRID_X; ++i1)
		{
			float3 hc;
			float hw;
			HorizonTap(i1, reversed, hc, hw);
			horWC += hc * hw;
			horW += hw;
		}
		float3 horizon = horWC / max(horW, 1e-6);
		float horConf = saturate(horW / HORIZON_FULL) * depthState.y;
		if (texel == 3)
		{
			float open = seeded ? lerp(tex2Dfetch(FogPrev, int2(3, 0)).x, horConf, Rate(dt, FogColourAdapt)) : horConf;
			// y and z: the night's darkening and glow strengths (see NightStateTexel), so FogApplyPS knows from the
			// texel it reads anyway whether the night is on.
			float4 night = NightStateTexel(5, depthState, dt);
			return float4(open, night.y, night.z, 1.0);
		}

		// Second pass over the horizon taps: taps more than FOG_OUTLIER from the first average are left out,
		// so the glow of a low sun or a window over the sky does not pull the colour. If less than half the
		// weight is kept, the first average stays.
		if (horW > 1e-6)
		{
			float3 keptWC = float3(0.0, 0.0, 0.0);
			float keptW = 0.0;
			[loop]
			for (int i2 = 0; i2 < GRID_X; ++i2)
			{
				float3 hc;
				float hw;
				HorizonTap(i2, reversed, hc, hw);
				hw *= (length(hc - horizon) <= FOG_OUTLIER && dot(hc - horizon, LUMA601) <= FOG_GLOW_KEEP) ? 1.0 : 0.0;
				keptW += hw;
				keptWC += hc * hw;
			}
			if (keptW >= FOG_KEPT_MIN * horW)
				horizon = keptWC / keptW;
		}

		// Without a horizon: the far land (3% of the taps is full confidence), else the frame's own average
		// (indoors, or no depth). Its colour is the engine fog's hue, but trees seen through the fog are darker
		// than the fog itself, so it is lifted to FOG_SKY_FLOOR of the sky's brightness: daylight in the air.
		// Where no sky is seen (indoors, a closed canopy) the land keeps its own tone.
		float farConf = saturate(farN / (0.03 * GRID_X * GRID_Y)) * depthState.y;
		float skyConf = saturate(skyN / SKY_TAPS_FULL) * depthState.y;
		float3 skyMean = skyC / max(skyN, 1.0);
		float skyLum = dot(skyMean, LUMA601);
		float3 skyPale = lerp(skyMean, float3(skyLum, skyLum, skyLum), FOG_SKY_PALE);
		float3 land = lerp(lerp(average, skyPale, skyConf), farWC / max(farW, 1e-8), farConf);
		float floorL = FOG_SKY_FLOOR * skyLum * skyConf;
		land *= clamp(floorL / max(dot(land, LUMA601), 1e-4), 1.0, FOG_LIFT_MAX);

		// The horizon wins when it is in view (HORIZON_FULL columns are full confidence).
		float3 target = saturate(lerp(land, horizon, horConf));

		float3 colour = seeded ? lerp(prev0.rgb, target, Rate(dt, FogColourAdapt)) : target;
		return float4(colour, 1.0);
	}

	float4 FogSavePS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		return tex2Dfetch(FogCur, int2(pos.xy));
	}

	// ---------------------------------------------------------------------------------------------------
	// Night and lights (drawn by LegionGUFog, see NightApply)
	// ---------------------------------------------------------------------------------------------------


	// In the day, or with «Свет огней» at 0, the glow passes below write nothing but zeros and cost almost nothing.
	bool LightsNeeded()
	{
		return tex2Dfetch(FogCur, int2(5, 0)).z > 0.0;
	}

	// The light pass: per block of the glow buffer, the light sources. A 2 x 2 average is a light when its brightest
	// channel (a flame or a crystal is a saturated colour), eroded to the smallest of itself and its right and lower
	// neighbours (2 x 2 averages 1 / LEGIONGU_GLOW_TAPS of a block apart), is SRC_AMBIENT times the ambient or more. Each
	// one adds its own share, so a light counts by its area and keeps its strength when it slides across the blocks
	// under a turning camera. The block must also pass the surround test: its eroded peak SRC_SURROUND times the mean
	// luminance of 16 taps on two rings SRC_RING1 and SRC_RING2 blocks out. And it must not be part of a bar: a light
	// at the block's brightest tap and 1, 2 and 3 blocks along it to either side, with no light 2 blocks above and below
	// it, is a health bar or a cast bar (at least 4 blocks wide, at most about 2 tall). Alpha: the luminance times log2
	// yards at the block's brightest light. A block whose brightest light lies on the sky gives none, and none under the
	// UI mask.
	float LightTap(float2 uv, float thr)
	{
		float3 c = tex2Dlod(ColorLinear, float4(uv, 0.0, 0.0)).rgb;
		return saturate((max(max(c.r, c.g), c.b) - thr) / (thr * SRC_SOFT));
	}

	// A light a few pixels small is found in one frame and lost in the next as it slides across the taps of a block,
	// and its glow blinked. Here a found light stays and eases in and out (see LightSteadyPS): the
	// block and last frame's, faded. Short enough that a turning camera leaves no visible trail.
	static const float LIGHT_HOLD_NEAR = 0.04;  // seconds for a light near the player to rise and fade: a shot's flash is gone at once
	static const float LIGHT_HOLD_FAR = 0.25;   // seconds for a far light: a small far light is found and lost as it slides
	                                            // across the taps, and must rise and fade softly instead of flickering
	static const float2 LIGHT_HOLD_YD = float2(30.0, 120.0); // yards over which the time goes from near to far

	// Each block eases toward this frame's light, the faster the nearer the light (the yards come from alpha / luminance,
	// see LightFindPS); a light rises twice as fast as it fades.
	float4 LightSteadyPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		float4 now = tex2Dfetch(LightRaw, int2(pos.xy));
		float4 prev = tex2Dfetch(LightPrev, int2(pos.xy));
		float ln = dot(now.rgb, LUMA601);
		float lp = dot(prev.rgb, LUMA601);
		float yards = max(ln > 1e-5 ? exp2(now.a / ln) : 0.0, lp > 1e-5 ? exp2(prev.a / lp) : 0.0);
		float tau = lerp(LIGHT_HOLD_NEAR, LIGHT_HOLD_FAR, smoothstep(LIGHT_HOLD_YD.x, LIGHT_HOLD_YD.y, yards));
		return lerp(prev, now, Rate(FrameSeconds(), ln > lp ? 0.5 * tau : tau));
	}

	float4 LightKeepPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		return tex2Dfetch(LightSrc, int2(pos.xy));
	}

	float4 LightFindPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		if (!LightsNeeded())
			return float4(0.0, 0.0, 0.0, 0.0);
		float ui = 1.0 - smoothstep(UI_SRC_FROM, UI_SRC_FULL, UIMask(uv));
		if (ui <= 0.0)
			return float4(0.0, 0.0, 0.0, 0.0);
		float ambient = max(tex2Dfetch(FogCur, int2(5, 0)).x, AMBIENT_MIN);
		float thr = max(SRC_AMBIENT * ambient, SRC_MIN);
		float2 step = float(BUFFER_HEIGHT) / float(LEGIONGU_GLOW_H) * float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
		float3 col[(LEGIONGU_GLOW_TAPS + 1) * (LEGIONGU_GLOW_TAPS + 1)];
		float val[(LEGIONGU_GLOW_TAPS + 1) * (LEGIONGU_GLOW_TAPS + 1)];
		[unroll]
		for (int j = 0; j <= LEGIONGU_GLOW_TAPS; ++j)
		{
			[unroll]
			for (int i = 0; i <= LEGIONGU_GLOW_TAPS; ++i)
			{
				float3 c = tex2Dlod(ColorLinear, float4(uv + ((float2(i, j) + 0.5) / float(LEGIONGU_GLOW_TAPS) - 0.5) * step, 0.0, 0.0)).rgb;
				col[j * (LEGIONGU_GLOW_TAPS + 1) + i] = c;
				val[j * (LEGIONGU_GLOW_TAPS + 1) + i] = max(max(c.r, c.g), c.b);
			}
		}
		float3 light = float3(0.0, 0.0, 0.0);
		float best = 0.0;
		float peak = 0.0;
		float2 bestUV = uv;
		[unroll]
		for (int j2 = 0; j2 < LEGIONGU_GLOW_TAPS; ++j2)
		{
			[unroll]
			for (int i2 = 0; i2 < LEGIONGU_GLOW_TAPS; ++i2)
			{
				int k0 = j2 * (LEGIONGU_GLOW_TAPS + 1) + i2;
				float v = min(val[k0], min(val[k0 + 1], val[k0 + LEGIONGU_GLOW_TAPS + 1]));
				float e = saturate((v - thr) / (thr * SRC_SOFT));
				light += col[k0] * (e * v / max(val[k0], 1e-5));
				if (e * v > best)
				{
					best = e * v;
					peak = v;
					bestUV = uv + ((float2(i2, j2) + 0.5) / float(LEGIONGU_GLOW_TAPS) - 0.5) * step;
				}
			}
		}
		if (best <= 0.0)
			return float4(0.0, 0.0, 0.0, 0.0);
		float u = DepthU(RawDepth(bestUV), EffectiveReversed(tex2Dfetch(FogCur, int2(1, 0)).w));
		if (IsSky(u))
			return float4(0.0, 0.0, 0.0, 0.0);

		float around = 0.0;
		[unroll]
		for (int k = 0; k < 8; ++k)
		{
			float a = 0.785398 * k;
			float2 dir = float2(cos(a), sin(a)) * step;
			around += dot(tex2Dlod(ColorLinear, float4(uv + dir * SRC_RING1, 0.0, 0.0)).rgb, LUMA601);
			around += dot(tex2Dlod(ColorLinear, float4(uv + dir * SRC_RING2, 0.0, 0.0)).rgb, LUMA601);
		}
		float thrS = SRC_SURROUND * around / 16.0;
		float keep = saturate((peak - thrS) / max(thrS * SRC_SOFT, 1e-6));

		float2 dx = float2(step.x, 0.0);
		float2 dy = float2(0.0, step.y);
		float along = max(LightTap(bestUV - dx, thr), LightTap(bestUV + dx, thr))
		            * max(LightTap(bestUV - 2.0 * dx, thr), LightTap(bestUV + 2.0 * dx, thr))
		            * max(LightTap(bestUV - 3.0 * dx, thr), LightTap(bestUV + 3.0 * dx, thr));
		float across = max(LightTap(bestUV - 2.0 * dy, thr), LightTap(bestUV + 2.0 * dy, thr));
		keep *= 1.0 - along * (1.0 - across);

		// Only real light counts: very bright, or bright and of a strong colour (a flame, a lit window, a crystal, glowing
		// eyes). Pale fur or grey armour stands out of a dark night too, and each character got a halo of its own.
		float lmax = max(light.r, max(light.g, light.b));
		float lsat = (lmax - min(light.r, min(light.g, light.b))) / max(lmax, 1e-5);
		keep *= saturate(max(smoothstep(LIGHT_WHITE.x, LIGHT_WHITE.y, peak), smoothstep(LIGHT_SAT.x, LIGHT_SAT.y, lsat) * smoothstep(LIGHT_COLOURED.x, LIGHT_COLOURED.y, peak)));
		// A farther light glows less (see LIGHT_FAR): a torch a hundred yards off is a spark, not the lamp at the door.
		float yards = Yards(u);
		keep /= 1.0 + (yards / LIGHT_FAR) * (yards / LIGHT_FAR);
		// A surface lit all over, like the wings of a glowing mount, is not a point of light: the more of the block's taps
		// are lights, the less it glows (see LIGHT_AREA_CUT).
		float cover = 0.0;
		[unroll]
		for (int k3 = 0; k3 < (LEGIONGU_GLOW_TAPS + 1) * (LEGIONGU_GLOW_TAPS + 1); ++k3)
			cover += val[k3] > thr ? 1.0 : 0.0;
		// Only cold light, blue, violet and pink (blue over green), is cut: fire, lava, fel, torches and lamps keep
		// their glow however much of the screen they fill.
		float cold = saturate((light.b - light.g) / max(light.b, 1e-5) * 3.0);
		// The player's own glowing mount or armour: cold light near the camera in the middle of the frame, where the
		// character always is. Each flap of a glowing wing was found anew and flashed the land blue like a police car.
		float2 dc = (bestUV - float2(0.5, 0.55)) * float2(ASPECT, 1.0);
		keep *= 1.0 - LIGHT_SELF_CUT * cold * (1.0 - smoothstep(0.1, 0.3, length(dc))) * (1.0 - smoothstep(30.0, 60.0, yards));
		keep *= 1.0 - LIGHT_AREA_CUT * cold * smoothstep(0.4, 0.9, cover / float((LEGIONGU_GLOW_TAPS + 1) * (LEGIONGU_GLOW_TAPS + 1)));

		light *= keep * ui / float(LEGIONGU_GLOW_TAPS * LEGIONGU_GLOW_TAPS);
		return float4(light, dot(light, LUMA601) * log2(max(yards, 0.01)));
	}

	// The 7 bilinear taps of a 13-tap Gaussian of sigma 2 texels: offsets and weights. Their 7 x 7 products blur in
	// both directions in one pass.
	static const float G2_OFF[7] = { -5.2018, -3.2941, -1.4072, 0.0, 1.4072, 3.2941, 5.2018 };
	static const float G2_W[7] = { 0.01098, 0.09185, 0.29733, 0.19968, 0.29733, 0.09185, 0.01098 };

	// L0: the lights blurred on the glow buffer (sigma 2 texels, LIGHT_SIG0 screen heights).
	float4 L0PS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		if (!LightsNeeded())
			return float4(0.0, 0.0, 0.0, 0.0);
		float2 texel = float2(1.0 / LEGIONGU_GLOW_W, 1.0 / LEGIONGU_GLOW_H);
		float4 sum = float4(0.0, 0.0, 0.0, 0.0);
		[unroll]
		for (int j = 0; j < 7; ++j)
		{
			[unroll]
			for (int i = 0; i < 7; ++i)
				sum += tex2Dlod(LightSrc, float4(uv + float2(G2_OFF[i], G2_OFF[j]) * texel, 0.0, 0.0)) * (G2_W[i] * G2_W[j]);
		}
		return float4(sum.rgb, sum.a / max(dot(sum.rgb, LUMA601), 1e-8));
	}

	// L1 and L2: the field before, down by 3 (a box of four bilinear taps 0.75 of its texels from each point) and
	// blurred by sigma 2 of the new texels, in one pass. The depth is averaged weighted by the light.
	float4 DownBlur(sampler2D src, float2 uv, float2 srcTexel, float2 dstTexel)
	{
		float3 rgb = float3(0.0, 0.0, 0.0);
		float lz = 0.0;
		float2 o = 0.75 * srcTexel;
		[unroll]
		for (int j = 0; j < 7; ++j)
		{
			[unroll]
			for (int i = 0; i < 7; ++i)
			{
				float2 q = uv + float2(G2_OFF[i], G2_OFF[j]) * dstTexel;
				float w = 0.25 * G2_W[i] * G2_W[j];
				float4 a = tex2Dlod(src, float4(q + float2(-o.x, -o.y), 0.0, 0.0));
				float4 b = tex2Dlod(src, float4(q + float2(o.x, -o.y), 0.0, 0.0));
				float4 c = tex2Dlod(src, float4(q + float2(-o.x, o.y), 0.0, 0.0));
				float4 d = tex2Dlod(src, float4(q + float2(o.x, o.y), 0.0, 0.0));
				rgb += (a.rgb + b.rgb + c.rgb + d.rgb) * w;
				lz += (dot(a.rgb, LUMA601) * a.a + dot(b.rgb, LUMA601) * b.a + dot(c.rgb, LUMA601) * c.a + dot(d.rgb, LUMA601) * d.a) * w;
			}
		}
		return float4(rgb, lz / max(dot(rgb, LUMA601), 1e-8));
	}

	float4 L1PS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		return LightsNeeded() ? DownBlur(L0, uv, float2(1.0 / LEGIONGU_GLOW_W, 1.0 / LEGIONGU_GLOW_H), float2(1.0 / LEGIONGU_L1_W, 1.0 / LEGIONGU_L1_H)) : float4(0.0, 0.0, 0.0, 0.0);
	}

	float4 L2PS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		return LightsNeeded() ? DownBlur(L1, uv, float2(1.0 / LEGIONGU_L1_W, 1.0 / LEGIONGU_L1_H), float2(1.0 / LEGIONGU_L2_W, 1.0 / LEGIONGU_L2_H)) : float4(0.0, 0.0, 0.0, 0.0);
	}

	// The fog opacity of land z yards away at dial t with the haze haze0 at the camera, as FogAt gives it.
	float FogAtYards(float z, float t, float haze0)
	{
		float dist = FarCap(z * sqrt(t) / FogReach * FogNearness());
		return dist + haze0 * (1.0 - dist);
	}

	// The night curve on a colour c with the brightest channel v and h = NightLit (see NIGHT_M100): m is the scale of
	// the ambient light, the sky gets NIGHT_SKY_SHARE of it and no moonlight tint. s is the darkening strength, for the
	// tint. The toe v NIGHT_TOE / (v + NIGHT_TOE) keeps the darkest values.
	// The share of field k (0, 1, 2) in a light at lz log2 yards: it wants a width of LIGHT_R yards, LIGHT_R / (z
	// FOV_TAN2) screen heights, and gets a tent in log2 of the width between the three widths, the width clamped to
	// their range, times (sigma_k / width)^2, so every light has the same peak whatever its width.
	float LevelWeight(int k, float lz)
	{
		float p0 = log2(LIGHT_SIG0);
		float p1 = log2(LIGHT_SIG1);
		float p2 = log2(LIGHT_SIG2);
		float p = clamp(log2(LIGHT_R / FOV_TAN2) - lz, p0, p2);
		float lod = p < p1 ? (p - p0) / (p1 - p0) : 1.0 + (p - p1) / (p2 - p1);
		float pk = k == 0 ? p0 : (k == 1 ? p1 : p2);
		return saturate(1.0 - abs(lod - float(k))) * exp2(2.0 * (pk - p));
	}

	// What a pixel needs of the three fields, on the glow buffer, with this frame's strength g in it. lit: the light
	// that falls on land at the lights' depth (see LevelWeight) as a lift over the ambient (see LIFT_GAIN). air: the
	// glow in the air, the fields weighted (sigma_k / LIGHT_SIG0)^GLOW_AIR_TAIL, so it falls off about as one over the
	// distance from the light like light scattered in haze, the wider fields GLOW_AIR_WIDE more per step at fog dial
	// 1 (wider in thick fog), times the fog between the camera and the lights (see GLOW_AIR_BASE), eased into
	// GLOW_AIR_MAX. Alpha: the luminance times the lights' distance in yards, so a pixel gets the distance back where
	// the light is, also between texels at the edge of a light.
	void LightCombinePS(float4 pos : SV_Position, float2 uv : TEXCOORD0, out float4 lit : SV_Target0, out float4 air : SV_Target1)
	{
		lit = float4(0.0, 0.0, 0.0, 0.0);
		air = float4(0.0, 0.0, 0.0, 0.0);
		if (!LightsNeeded())
			return;
		float wide = GLOW_AIR_WIDE * FogDial();
		float4 f[3] = { tex2Dlod(L0, float4(uv, 0.0, 0.0)), tex2Dlod(L1, float4(uv, 0.0, 0.0)), tex2Dlod(L2, float4(uv, 0.0, 0.0)) };
		float litZ = 0.0;
		float airZ = 0.0;
		[unroll]
		for (int k = 0; k < 3; ++k)
		{
			float l = dot(f[k].rgb, LUMA601);
			float ws = LevelWeight(k, f[k].a);
			float wa = exp2(GLOW_AIR_TAIL * (k == 0 ? 0.0 : (k == 1 ? log2(LIGHT_SIG1 / LIGHT_SIG0) : log2(LIGHT_SIG2 / LIGHT_SIG0)))) * (1.0 + wide * float(k));
			lit.rgb += f[k].rgb * ws;
			litZ += l * ws * f[k].a;
			air.rgb += f[k].rgb * wa;
			airZ += l * wa * f[k].a;
		}
		// One hue for the whole glow of a place, the hue of the widest level: each level had its own mix of the flame's
		// colours, and a campfire shimmered in three of them from its core outward.
		float3 hue = f[2].rgb / max(dot(f[2].rgb, LUMA601), 1e-8);
		if (dot(f[2].rgb, LUMA601) > 1e-8)
		{
			lit.rgb = dot(lit.rgb, LUMA601) * hue;
			air.rgb = dot(air.rgb, LUMA601) * hue;
		}
		float4 nt = tex2Dfetch(FogCur, int2(5, 0));
		float4 depthState = tex2Dfetch(FogCur, int2(1, 0));
		float t = FogDial();
		float zLit = exp2(litZ / max(dot(lit.rgb, LUMA601), 1e-8));
		float zAir = exp2(airZ / max(dot(air.rgb, LUMA601), 1e-8));
		lit.rgb *= LIFT_GAIN * nt.z / max(nt.x, AMBIENT_MIN);
		float haze0 = saturate(FogHaze * t) * lerp(1.0, FOG_HAZE_OPEN, tex2Dfetch(FogCur, int2(3, 0)).x);
		float fogL = t > 0.0 ? FogAtYards(zAir, t, haze0) * depthState.x : 0.0;
		air.rgb *= GLOW_AIR_GAIN * nt.z * (GLOW_AIR_BASE + GLOW_AIR_FOG * fogL);
		float al = dot(air.rgb, LUMA601);
		air.rgb *= GLOW_AIR_MAX * (1.0 - exp(-exp2(GLOW_AIR_POW * log2(max(al, 1e-12) / GLOW_AIR_KNEE)))) / max(al, 1e-12);
		lit.a = dot(lit.rgb, LUMA601) * zLit;
		air.a = dot(air.rgb, LUMA601) * zAir;
	}

	// h: how much the pixel is lit by a light rather than by the ambient, 0..1 (see NIGHT_M100).
	float NightLit(float v, float ambient)
	{
		// A soft knee (square, not cube): with a deep night the lit and the dark differ some 35 times, and a steep knee
		// turned every soft gradient of the game into a hard edge.
		float x = v / (NIGHT_KNEE * ambient);
		return x * x / (1.0 + x * x);
	}

	// On the sky the knee stays steep: the moon and the stars are points of light and must keep shining.
	// The reference is the sky's own luminance (night texel 6), not the dark land: against the land the whole glow at the
	// horizon counted as a light and stayed a bright purple band. The moon and the stars are many times the sky mean.
	float NightLitSky(float v, float skyLum)
	{
		float x = v / (SKY_KNEE * max(skyLum, 1e-3));
		return x * x * x / (1.0 + x * x * x);
	}

	float3 NightCurve(float3 c, float v, float h, float m, bool sky, float s, float deep)
	{
		float ms = sky ? lerp(1.0, m, lerp(NIGHT_SKY_SHARE, 1.0, deep)) : m;
		float toe = NIGHT_TOE * (1.0 - 0.6 * deep);
		// Lit and dark blend in log space, so the brightness falls off evenly from a light into the night instead of
		// holding and then dropping.
		float o = min(v, max(v * exp2(log2(max(ms, 1e-4)) * (1.0 - h)), v * toe / (v + toe)));
		float3 d = c * (o / max(v, 1e-6));
		return sky ? d : lerp(d, dot(d, LUMA601) * MOON_TINT, MOON_SHIFT * s * (1.0 - h));
	}

	// The night fog colour (see NIGHT_FOG_GREY).
	float3 NightFog(float3 fogColour, float m, float s)
	{
		float l = dot(fogColour, LUMA601);
		return lerp(fogColour, l * MOON_TINT, NIGHT_FOG_GREY * s) * lerp(1.0, m, NIGHT_SKY_SHARE * NIGHT_FOG_DARK);
	}

	// The night and the lights on the input colour c at uv (fog dial t), with the fog:
	// 1. «Темнота ночи»: the night curve on the land and the sky (see NIGHT_M100) and a cool moonlit tint on the land.
	// 2. «Свет огней»: the lights around the pixel lift the land at their depth, on the colour before the curve (see
	//    LIGHT_R).
	// 3. The fog as always, with the night fog colour and the darkened land as the haze (see NIGHT_FOG_GREY).
	// 4. The glow of the lights in the air in front of the pixel, with the fog between the camera and the lights,
	//    as a screen blend (see GLOW_AIR_R).
	// Under the UI mask none of it is drawn on what is brighter than the night land (see UI_KEEP_FROM), so the icons,
	// the text and the bars keep their brightness. nt is the night texel 5 (see
	// NightStateTexel). With both strengths at 0 FogApplyPS does not come here.
	float3 NightApply(float3 c, float2 uv, float t, float4 state0, float4 depthState, float4 nt, float open)
	{
		float ambient = max(nt.x, AMBIENT_MIN);
		float v = max(max(c.r, c.g), c.b);
		float keepUI = 1.0 - UIMask(uv) * smoothstep(UI_KEEP_FROM, UI_KEEP_FULL, v / ambient);
		float s = nt.y * keepUI;
		float m = lerp(1.0, nt.w, keepUI);
		float u = DepthU(RawDepth(uv), EffectiveReversed(depthState.w));
		bool sky = IsSky(u);
		float z = Yards(u);
		// Indoors (the game's word) the room keeps its own curve; the sky and what lies beyond INDOOR_REACH (the street
		// through a door or a window) get the night outside from texel 7. Before, the street seen from a tavern had none.
		float4 n7o = tex2Dfetch(FogCur, int2(7, 0));
		float outside = LegionGUState(2u) ? (sky ? 1.0 : smoothstep(0.6 * INDOOR_REACH, INDOOR_REACH, z)) : 1.0;
		if (LegionGUState(2u) && outside > 0.0)
		{
			float mOut = exp2(n7o.z * log2(NIGHT_M100) + n7o.w * log2(NIGHT_DEEP));
			m = lerp(m, min(m, lerp(1.0, mOut, keepUI)), outside);
			s = lerp(s, max(s, n7o.z * keepUI), outside);
		}
		float skyLum = tex2Dfetch(FogCur, int2(6, 0)).x;
		float h = sky ? NightLitSky(v, skyLum) : NightLit(v, ambient);
		float4 n7 = tex2Dfetch(FogCur, int2(7, 0));
		float sTint = n7.z * keepUI * outside;
		// The pools of light: near a light (in the screen and within POOL_YD in depth) the night leaves the game's own
		// lighting almost alone and adds no moonlight tint. The engine lights the character and the ground by a campfire;
		// darkening that and tinting it blue made a fire give cold light and leave the model dark.
		float pool = 0.0;
		float3 poolHue = float3(1.0, 1.0, 1.0);
		if (nt.z > 0.0 && !sky)
		{
			float4 Lp = tex2Dlod(LitS, float4(uv, 0.0, 0.0));
			float lp = dot(Lp.rgb, LUMA601);
			if (lp > LIGHT_EPS)
			{
				float dzp = (z - Lp.a / lp) / POOL_YD;
				pool = smoothstep(POOL_FROM, POOL_FULL, lp) * exp2(-dzp * dzp) * keepUI;
				poolHue = Lp.rgb / lp;
			}
		}
		float mp = lerp(m, 1.0, POOL_KEEP * pool);
		float3 o = NightCurve(c, v, h, mp, sky, sTint * (1.0 - pool), n7.w * outside);
		// Far land goes over to the sky's curve by degrees between NIGHT_FAR_FROM and NIGHT_FAR_SKY: distant mountains are
		// mostly fog colour and, darkened as land, stood as flat grey cut-outs against the night sky; now they fade into
		// it, and the glow at the horizon does not stay a bright band either.
		float farSky = sky ? 0.0 : smoothstep(NIGHT_FAR_FROM, NIGHT_FAR_SKY, z);
		if (farSky > 0.0)
			o = lerp(o, NightCurve(c, v, NightLitSky(v, skyLum), mp, true, 0.0, n7.w * outside), farSky);
		// A pool takes the colour of its light, softly (POOL_TINT): the game's moonlit night is blue, and the firelight
		// on the ground and on the character read cold next to a campfire.
		// Only as much as the night (or a dark cave) darkens here: in a lit tavern the game's own torches and candles need
		// nothing, and the tint of a room full of lights drowned it in red.
		float poolFx = pool * saturate(s * 3.0);
		if (poolFx > 0.0)
		{
			// Fire reads orange: a warm light (red over blue) leans its tint toward FIRE_COLOUR, since the flame itself is
			// nearly white-yellow and its own hue gave a pale, brownish light. And the pool is brighter than the game made
			// it (POOL_LIFT), as firelight is in a dark night.
			float warm = saturate((poolHue.r - poolHue.b) / max(poolHue.r, 1e-5) * 2.0);
			float3 hue = lerp(poolHue, FIRE_COLOUR / dot(FIRE_COLOUR, LUMA601), FIRE_LEAN * warm);
			o *= 1.0 + POOL_LIFT * poolFx;
			o = lerp(o, dot(o, LUMA601) * hue, POOL_TINT * poolFx);
		}

		float3 air = float3(0.0, 0.0, 0.0);
		if (nt.z > 0.0)
		{
			float4 L = tex2Dlod(LitS, float4(uv, 0.0, 0.0));
			float4 A = tex2Dlod(AirS, float4(uv, 0.0, 0.0));
			[branch]
			if (dot(L.rgb, LUMA601) > LIGHT_EPS || dot(A.rgb, LUMA601) > LIGHT_EPS)
			{
			float dz = (z - L.a / max(dot(L.rgb, LUMA601), 1e-8)) / MATCH_YD;
			float3 lit = sky ? float3(0.0, 0.0, 0.0) : L.rgb * (exp2(-dz * dz) * keepUI * (1.0 - LIFT_LIT_CUT * h));
			o += c * lit * (LIFT_MAX / (LIFT_MAX + dot(lit, LUMA601)));
			float zl = A.a / max(dot(A.rgb, LUMA601), 1e-8);
			air = A.rgb * (keepUI * (sky ? 1.0 : smoothstep(GLOW_AIR_GATE_LO, GLOW_AIR_GATE_HI, z / zl)));
			}
		}

		float2 a = t > 0.0 ? FogAmount(uv, t, depthState, open) : float2(0.0, 0.0);
		if (a.x + a.y > 0.0)
		{
			float3 fogColour = NightFog(FogColourOut(FogSourceColour(state0), t), m, s);
			float4 key = tex2Dfetch(FogCur, int2(2, 0));
			float kv = max(max(key.r, key.g), key.b);
			key.rgb = NightCurve(key.rgb, kv, NightLit(kv, ambient), m, false, s, n7.w * outside);
			o = FogBlend(o, a, fogColour, key, SunInFog(uv));
		}

		// the moonlit mist over LegionGUFog's fog (see MIST_COLOUR)
		float km = MIST_NIGHT_SHARE * saturate(2.0 * n7.z) * keepUI * outside;
		if (km > 0.0)
		{
			float tf = FogDial();
			float haze0 = saturate(FogHaze * tf) * lerp(1.0, FOG_HAZE_OPEN, open);
			float2 fa = tf > 0.0 ? FogAt(uv, EffectiveReversed(depthState.w), tf, haze0) : float2(0.0, 0.0);
			float fs = MIST_SKY * FOG_FAR_CAP * saturate(tf * 2.0);
			float fm = sky ? fs : min(saturate(fa.x + fa.y), fs);
			float4 n8 = tex2Dfetch(FogCur, int2(8, 0));
			float2 dm = (uv - n8.xy) * float2(ASPECT, 1.0);
			float3 mist = MIST_COLOUR * (1.0 + MIST_MOON * n8.z * exp(-dot(dm, dm) / (2.0 * MIST_MOON_R * MIST_MOON_R)));
			o += max(mist - o, 0.0) * (fm * km * depthState.x);
		}
		return o + air * (1.0 - saturate(o));
	}

	// "Ночь и огни": the frame at a third, the lights that count in colour and the light field L0, and six squares at
	// the top left, 24 pixels each, 8 apart: night, day, land in view, the ambient times 4, the sky's luminance times 2
	// (0.14: full night, 0.40: no night) and its coldness minus 1 (0.2: the night starts to count, 0.45: fully).
	float4 NightDebug(float4 c, float2 uv, float2 xy)
	{
		float4 n4 = tex2Dfetch(FogCur, int2(4, 0));
		float4 n5 = tex2Dfetch(FogCur, int2(5, 0));
		float4 n6 = tex2Dfetch(FogCur, int2(6, 0));
		float3 o = c.rgb * 0.33 + tex2Dlod(LightSrc, float4(uv, 0.0, 0.0)).rgb + 0.3 * tex2Dlod(LitS, float4(uv, 0.0, 0.0)).rgb;
		if (xy.y >= 8.0 && xy.y < 32.0 && xy.x >= 8.0 && xy.x < 232.0)
		{
			int k = int((xy.x - 8.0) / 32.0);
			float inside = (xy.x - 8.0) - 32.0 * k < 24.0 ? 1.0 : 0.0;
			float v = k == 0 ? n4.x : (k == 1 ? n4.y : (k == 2 ? n4.z : (k == 3 ? 4.0 * n5.x : (k == 4 ? 2.0 * n6.x : (k == 5 ? n6.y - 1.0 : n6.w * 100.0)))));
			if (inside > 0.5)
				o = float3(v, v, v);
		}
		return float4(saturate(o), c.a);
	}

	float4 FogDebug(float4 c, float2 uv, float4 state0, float4 depthState)
	{
		float3 o = c.rgb;
		float reversed = EffectiveReversed(depthState.w);

		if (DebugView == DBG_DEPTH)
		{
			// Log scale, so near and far both show without knowing the planes: near white, sky black.
			float u = DepthU(RawDepth(uv), reversed);
			float g = IsSky(u) ? 0.0 : saturate(1.0 + log2(max(u, 1e-12)) / 20.0);
			o = float3(g, g, g);
		}
		else if (DebugView == DBG_BANDS)
		{
			float u = DepthU(RawDepth(uv), reversed);
			if (IsSky(u))
			{
				o = float3(0.25, 0.45, 0.90);
			}
			else
			{
				float z = Yards(u);
				float g = 0.12;
				if (z < DebugRange)
				{
					g = frac(floor(z / 25.0) * 0.5) < 0.25 ? 0.90 : 0.50;
					g *= 1.0 - 0.5 * z / DebugRange;
				}
				o = float3(g, g, g) * (0.6 + 0.4 * dot(c.rgb, LUMA601));
			}
		}
		else if (DebugView == DBG_AMOUNT)
		{
			float t = FogDial();
			float2 a = t > 0.0 ? FogAmount(uv, t, depthState, tex2Dfetch(FogCur, int2(3, 0)).x) : float2(0.0, 0.0);
			o = float3(a.x + a.y, a.x + a.y, a.x + a.y);
		}
		else
		{
			// The normal fogged image, with four swatches: the source colour, the fog after desaturate and
			// darken, the haze at the camera, and the fog right at the sun.
			float t = FogDial();
			float3 srcColour = FogSourceColour(state0);
			float3 fogColour = FogColourOut(srcColour, t);
			float4 key = tex2Dfetch(FogCur, int2(2, 0));
			if (t > 0.0)
				o = FogBlend(c.rgb, FogAmount(uv, t, depthState, tex2Dfetch(FogCur, int2(3, 0)).x), fogColour, key, SunInFog(uv));
			float2 h = float2(uv.x * ASPECT, uv.y);
			if (h.y > 0.03 && h.y < 0.13)
			{
				if (h.x > 0.03 && h.x < 0.13)
					o = srcColour;
				else if (h.x > 0.14 && h.x < 0.24)
					o = fogColour;
				else if (h.x > 0.25 && h.x < 0.35)
					o = FogHazeColour(fogColour, key);
				else if (h.x > 0.36 && h.x < 0.46)
					o = FogLitMix(fogColour, 1.0, 1.0);
			}
		}

		if (DebugView != DBG_COLOUR && depthState.y < 0.5 && OnBorder(uv))
			o = float3(1.0, 0.1, 0.1);
		return float4(o, c.a);
	}

	float4 FogApplyPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		float4 c = tex2Dfetch(ColorPoint, int2(pos.xy));
		float4 state0 = tex2Dfetch(FogCur, int2(0, 0));
		float4 depthState = tex2Dfetch(FogCur, int2(1, 0));

		if (DebugView >= DBG_DEPTH && DebugView <= DBG_COLOUR)
			return FogDebug(c, uv, state0, depthState);

		if (DebugView == DBG_NIGHT)
			return NightDebug(c, uv, pos.xy);

		if (!LegionGUOn(8u) || LegionGUInStrip(pos.xy))
			return c;

		// At night, or with the lights on in a dark place, the night and the lights with the fog (see NightApply).
		// Otherwise the fog alone, exactly as without them.
		float t = FogDial();
		float4 s3 = tex2Dfetch(FogCur, int2(3, 0));
		[branch]
		if (s3.y > 0.0 || s3.z > 0.0)
			return float4(NightApply(c.rgb, uv, 0.0, state0, depthState, tex2Dfetch(FogCur, int2(5, 0)), s3.x), c.a);

		return c;
	}

	// ---------------------------------------------------------------------------------------------------
	// LegionGURays
	// ---------------------------------------------------------------------------------------------------

	struct SunInfo
	{
		float2 p;          // where the blur converges, texture space, clamped to 3 units from the centre
		float2 e;          // where "near the sun" is measured from: the sun on screen, else the edge crossing
		float2 away;       // unit direction away from the sun, in screen heights mapped back to texture space
		float par;         // share of the blur that runs parallel along 'away'
		float lengthFrac;  // blur length as a share of each pixel's way to p
	};

	// The original's Finish() for a sun at texture-space point p in front of the camera (gather +1).
	SunInfo Finish(float2 sun)
	{
		SunInfo s;
		float2 p = sun;
		float2 t = sun - 0.5;
		float2 d = t;
		float dl = length(d);
		if (dl > 3.0)
		{
			p = 0.5 + d * (3.0 / dl);
			d = p - 0.5;
		}

		bool onScreen = p.x >= 0.0 && p.x <= 1.0 && p.y >= 0.0 && p.y <= 1.0;
		float ax = abs(t.x) > 1e-6 ? 0.5 / abs(t.x) : 1e9;
		float ay = abs(t.y) > 1e-6 ? 0.5 / abs(t.y) : 1e9;
		s.p = p;
		s.e = onScreen ? p : 0.5 + t * min(ax, ay);

		float2 h = float2(t.x * ASPECT, t.y);
		float hl = length(h);
		s.away = hl > 1e-5 ? float2(-(h.x / hl) / ASPECT, -(h.y / hl)) : float2(0.0, 1.0);
		s.par = RaysParallel * saturate(hl / 0.05);

		float dh = length(float2(d.x * ASPECT, d.y));
		s.lengthFrac = RaysLength;
		if (dh > 1e-4 && RaysMaxLength / dh < s.lengthFrac)
			s.lengthFrac = RaysMaxLength / dh;
		return s;
	}

	// This frame's sun. While Auto follows a bright hole in geometry the rays converge the eased lift above it
	// (see SunStep), and "near the sun" is still measured from the hole.
	SunInfo CurrentSun()
	{
		float2 sun = float2(SunX, SunY);
		float lift = 0.0;
		if (SunMode == 0)
		{
			sun = tex2Dfetch(RaysCur, int2(0, 0)).xy;
			lift = tex2Dfetch(RaysCur, int2(3, 0)).z >= 0.5 ? tex2Dfetch(RaysCur, int2(5, 0)).z : 0.0;
		}
		SunInfo s = Finish(sun - float2(0.0, lift));
		s.e = Finish(sun).e;
		return s;
	}

	// Air along the line of sight of one depth tap (see AIR_NEAR): land from 0 at AIR_NEAR to AIR_LAND at
	// AIR_FULL yards, and 1 for the sky, an endless line of air. In-scattered light grows with the air in front
	// of the pixel, so near trunks stay dark in front of the lit haze.
	float AirAt(float u)
	{
		float land = AIR_LAND * smoothstep(AIR_NEAR, AIR_FULL, Yards(u));
		return lerp(land, 1.0, SkyShare(u));
	}

	// Pass 1: the downsampled scene, without the UI mask: the sun finder, the peak and the sky ring see the sky
	// as it is, so a sun under a masked corner is still found. Only the ray source (pass 4) applies the mask.
	// The colour is the average of the pixel block (LEGIONGU_COLOUR_TAPS bilinear taps per axis), so thin sky
	// gaps in foliage count on every frame at any even downscale. Alpha is the sky share from depth. Without
	// depth it is 0: nothing is known to be sky, so Auto finds no sun (a torch or a spell in the upper half of
	// a dark dungeon would pass for one) and the sky gate stays off. The second target is the mean air of the
	// block's depth taps (AirAt), AIR_NO_DEPTH without depth.
	void RaysDownPS(float4 pos : SV_Position, float2 uv : TEXCOORD0, out float4 sceneOut : SV_Target0, out float airOut : SV_Target1)
	{
		float2 px = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
		float3 c = float3(0.0, 0.0, 0.0);
		[unroll]
		for (int j = 0; j < LEGIONGU_COLOUR_TAPS; ++j)
		{
			[unroll]
			for (int i = 0; i < LEGIONGU_COLOUR_TAPS; ++i)
			{
				float2 o = ((float2(i, j) + 0.5) / float(LEGIONGU_COLOUR_TAPS) - 0.5) * float(LEGIONGU_RAYS_DOWNSCALE);
				c += tex2Dlod(ColorLinear, float4(uv + o * px, 0.0, 0.0)).rgb;
			}
		}
		c /= float(LEGIONGU_COLOUR_TAPS * LEGIONGU_COLOUR_TAPS);

		float4 depthState = tex2Dfetch(RaysPrev, int2(2, 0));
		float sky = 0.0;
		float air = AIR_NO_DEPTH;
		if (depthState.y > 0.5)
		{
			float reversed = EffectiveReversed(depthState.w);
			air = 0.0;
			[unroll]
			for (int j2 = 0; j2 < LEGIONGU_SKY_TAPS; ++j2)
			{
				[unroll]
				for (int i2 = 0; i2 < LEGIONGU_SKY_TAPS; ++i2)
				{
					float2 o = ((float2(i2, j2) + 0.5) / float(LEGIONGU_SKY_TAPS) - 0.5) * float(LEGIONGU_RAYS_DOWNSCALE);
					float u = DepthU(RawDepth(uv + o * px), reversed);
					sky += IsSky(u) ? 1.0 : 0.0;
					air += AirAt(u);
				}
			}
			sky /= float(LEGIONGU_SKY_TAPS * LEGIONGU_SKY_TAPS);
			air /= float(LEGIONGU_SKY_TAPS * LEGIONGU_SKY_TAPS);
		}
		sceneOut = float4(c, sky);
		airOut = air;
	}

	// Brightness of a scene texel for the peak: luminance, times the sky share when the sky gate is on.
	float PeakLuma(int2 xy, bool skyGate)
	{
		float4 s = tex2Dfetch(RaysScenePoint, xy);
		float l = dot(s.rgb, LUMA601);
		return skyGate ? l * s.a : l;
	}

	// Pass 2: statistics per cell, 16 x 16 point taps over the cell's share of the scene.
	// R is the brightest tap after a 2 x 2 erosion (the darkest of the tap and its right, lower and diagonal
	// neighbours). Names, damage numbers and other text over the sky are strokes one or two pixels wide, so
	// they cannot set the peak and switch off the real sky; sky gaps and the sun are wider and still can.
	// G is the share of bright sky, counted after the same erosion: a block of quest text over the sky filled
	// cells as densely as the sun and vetoed it as a second patch (bench ui scene at 3440 x 1440, with the mask
	// on or off). B is the share of sky, A the sky edges between each tap and the next tap to
	// the right and down, per tap pair. The neighbour is a fixed share of the screen away, so A does not depend
	// on the resolution.
	float4 RaysStatsPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		float4 depthState = tex2Dfetch(RaysPrev, int2(2, 0));
		bool skyGate = RaysSkyOnly && depthState.y > 0.5;
		float2 cellSize = float2(LEGIONGU_SCENE_W / float(STATS_W), LEGIONGU_SCENE_H / float(STATS_H));
		float2 base = floor(pos.xy) * cellSize;
		float2 stride = cellSize / float(STATS_TAPS);
		int2 last = int2(LEGIONGU_SCENE_W - 1, LEGIONGU_SCENE_H - 1);

		float brightest = 0.0;
		float brightSky = 0.0;
		float skyAll = 0.0;
		float edges = 0.0;
		[loop]
		for (int j = 0; j < STATS_TAPS; ++j)
		{
			[unroll]
			for (int i = 0; i < STATS_TAPS; ++i)
			{
				int2 xy = int2(base + (float2(i, j) + 0.5) * stride);
				int2 xy1 = min(xy + 1, last);
				float4 s = tex2Dfetch(RaysScenePoint, xy);
				float l = dot(s.rgb, LUMA601);
				float eroded = min(min(skyGate ? l * s.a : l, PeakLuma(int2(xy1.x, xy.y), skyGate)),
				                   min(PeakLuma(int2(xy.x, xy1.y), skyGate), PeakLuma(xy1, skyGate)));
				brightest = max(brightest, eroded);
				brightSky += eroded >= SunMinLuma ? s.a : 0.0;
				skyAll += s.a;
				int2 xr = min(int2(base + (float2(i + 1, j) + 0.5) * stride), last);
				int2 xd = min(int2(base + (float2(i, j + 1) + 0.5) * stride), last);
				edges += abs(s.a - tex2Dfetch(RaysScenePoint, xr).a) + abs(s.a - tex2Dfetch(RaysScenePoint, xd).a);
			}
		}
		return float4(brightest, brightSky / float(STATS_TAPS * STATS_TAPS), skyAll / float(STATS_TAPS * STATS_TAPS), edges / float(2 * STATS_TAPS * STATS_TAPS));
	}

	// The sun this frame: xy = the weighted centre of the cells densest in bright sky (texture space),
	// z = 1 when that patch can be the sun: dense, compact, the only dense patch, and almost white at its
	// brightest cell (see SUN_MAX_SPREAD). Otherwise xy is the pinned point.
	// w = 1 when the found patch is a bright hole in geometry and not the sun in open sky: the ring around it
	// (SUN_RING_IN to SUN_RING_OUT) is less than SUN_RING_SKY sky. Behind leaves a near-white hole is the glow
	// right next to the hidden sun, and the rays then converge GAP_LIFT above it (see SunStep).
	float4 FindSun()
	{
		float gmax = 0.0;
		[loop]
		for (int y1 = 0; y1 < STATS_H; ++y1)
		{
			[unroll]
			for (int x1 = 0; x1 < STATS_W; ++x1)
				gmax = max(gmax, tex2Dfetch(RaysStats, int2(x1, y1)).y);
		}

		float cut = 0.5 * gmax;
		float sw = 0.0;
		float2 sp = float2(0.0, 0.0);
		float spp = 0.0;
		float cells = 0.0;
		float core = 0.0;
		[loop]
		for (int y2 = 0; y2 < STATS_H; ++y2)
		{
			[unroll]
			for (int x2 = 0; x2 < STATS_W; ++x2)
			{
				float2 st = tex2Dfetch(RaysStats, int2(x2, y2)).xy;
				float g = st.y;
				float w = (g > 0.0 && g >= cut) ? g * g : 0.0;
				float2 ph = float2((x2 + 0.5) / STATS_W * ASPECT, (y2 + 0.5) / STATS_H);
				sw += w;
				sp += ph * w;
				spp += dot(ph, ph) * w;
				cells += w > 0.0 ? 1.0 : 0.0;
				core = max(core, w > 0.0 ? st.x : 0.0);
			}
		}

		float4 result = float4(SunX, SunY, 0.0, 0.0);
		if (sw > 1e-6 && gmax >= SunMinFill)
		{
			float2 centre = sp / sw;
			float spread = sqrt(max(spp / sw - dot(centre, centre), 0.0));
			float solidity = cells * STATS_CELL_AREA / max(6.2831853 * spread * spread, STATS_CELL_AREA);
			float maxSpread = solidity >= SUN_SOLID ? SUN_MAX_SPREAD_SOLID : SUN_MAX_SPREAD;
			bool white = core >= lerp(SunMinLuma, 1.0, SUN_CORE);
			if (spread <= maxSpread && white)
			{
				// A second dense patch away from this one (a bright cloud, a white window over the sky)
				// makes the frame ambiguous, and the rays keep the pinned point.
				float reach = max(SUN_STRAY * spread, SUN_STRAY_MIN);
				float ringIn = max(SUN_RING_IN * spread, SUN_RING_IN_MIN);
				float ringOut = max(SUN_RING_OUT * spread, SUN_RING_OUT_MIN);
				float stray = 0.0;
				float ringSky = 0.0;
				float ringN = 0.0;
				[loop]
				for (int y3 = 0; y3 < STATS_H; ++y3)
				{
					[unroll]
					for (int x3 = 0; x3 < STATS_W; ++x3)
					{
						float4 st3 = tex2Dfetch(RaysStats, int2(x3, y3));
						float2 ph = float2((x3 + 0.5) / STATS_W * ASPECT, (y3 + 0.5) / STATS_H);
						float dc = length(ph - centre);
						stray += (st3.y >= SunMinFill && dc > reach) ? 1.0 : 0.0;
						float inRing = (dc >= ringIn && dc <= ringOut) ? 1.0 : 0.0;
						ringSky += st3.z * inRing;
						ringN += inRing;
					}
				}
				bool hole = ringN > 0.5 && ringSky < SUN_RING_SKY * ringN;
				if (stray < 0.5)
					result = float4(centre.x / ASPECT, centre.y, 1.0, hole ? 1.0 : 0.0);
			}
		}
		return result;
	}

	// Distance of a texture-space point to the nearest screen edge in screen heights, negative outside.
	float EdgeDistance(float2 p)
	{
		return min(min(p.x, 1.0 - p.x) * ASPECT, min(p.y, 1.0 - p.y));
	}

	// A point moved out along its direction from the screen centre to SUN_EXIT times its edge crossing.
	// A point already that far out stays.
	float2 BeyondEdge(float2 p)
	{
		float2 d = p - 0.5;
		float ax = abs(d.x) > 1e-6 ? 0.5 / abs(d.x) : 1e9;
		float ay = abs(d.y) > 1e-6 ? 0.5 / abs(d.y) : 1e9;
		return 0.5 + d * max(min(ax, ay) * SUN_EXIT, 1.0);
	}

	// One step of the auto sun, shared by state texels 0, 3, 4 and 5:
	//   share    the smoothed share of frames with a found sun
	//   follow   whether the rays follow the sun, switched with hysteresis on share
	//   tracked  the followed sun: a found sun near it is taken at once, a far one only after SUN_JUMP_TIME.
	//            A sun lost near the edge has left the screen, and tracked moves out beyond that edge.
	//   shown    tracked eased over SUN_SMOOTH_TIME; a jump or a fresh start is taken at once
	//   blend    eases from the pinned point (0) to the followed sun (1) over SunAdapt seconds. The rays use
	//            the pinned point below 0.5 and the sun from 0.5 on, and the composite dims them to 0 at 0.5,
	//            so they fade out at one point and in at the other instead of sliding over empty sky.
	//   lift     how far above the followed patch the rays converge: GAP_LIFT for a bright hole in geometry,
	//            0 for the sun in open sky, eased over GAP_LIFT_TIME so a patch that changes its kind does
	//            not swing the beams. Light then falls down through the hole toward the ground, as it does
	//            through a gap in a canopy, instead of bursting out of the hole in every direction. The patch
	//            itself stays the point "near the sun" is measured from.
	// Without depth no sun is ever found (the sky share is 0), so Auto stays on the pinned point.
	void SunStep(float4 prev0, bool seeded, float dt, out float4 t0, out float4 t3, out float4 t4, out float4 t5)
	{
		float4 prev3 = tex2Dfetch(RaysPrev, int2(3, 0));
		float4 prev4 = tex2Dfetch(RaysPrev, int2(4, 0));
		float4 prev5 = tex2Dfetch(RaysPrev, int2(5, 0));
		float2 pinned = float2(SunX, SunY);
		float4 sun = FindSun();
		bool found = sun.z > 0.5;

		float share = seeded ? lerp(prev0.z, sun.z, Rate(dt, SUN_FOUND_TIME)) : sun.z;
		bool follow = seeded ? prev3.w > 0.5 : found;
		float blendPrev = seeded ? prev3.z : 0.0;
		float2 tracked = seeded ? prev3.xy : sun.xy;
		float2 cand = seeded ? prev4.xy : sun.xy;
		float held = seeded ? prev4.z : 0.0;
		float lost = (seeded && !found) ? min(prev4.w + dt, 10.0) : 0.0;
		bool snap = !seeded;

		float2 toHeights = float2(ASPECT, 1.0);
		float trackStep = max(SUN_TRACK_STEP, SUN_TRACK_SPEED * dt);
		if (found)
		{
			bool closeBy = length((sun.xy - tracked) * toHeights) <= trackStep;
			// Idle: the rays aim at the pinned point and the old followed sun no longer shows.
			bool idle = !follow && blendPrev < 0.05;
			if (idle || closeBy)
			{
				tracked = sun.xy;
				held = 0.0;
				snap = snap || idle;
			}
			else
			{
				// A far patch must stay in one place for SUN_JUMP_TIME seconds of found frames.
				bool same = held > 0.0 && length((sun.xy - cand) * toHeights) <= trackStep;
				held = same ? held + dt : dt;
				cand = sun.xy;
				if (held >= SUN_JUMP_TIME)
				{
					tracked = cand;
					held = 0.0;
					snap = true;
				}
			}
		}
		else if (lost >= SUN_LOST_TIME && EdgeDistance(tracked) < SUN_EDGE)
		{
			tracked = BeyondEdge(tracked);
		}

		float2 shown = snap ? tracked : lerp(prev5.xy, tracked, Rate(dt, SUN_SMOOTH_TIME));
		// A lost patch keeps its kind, so the point does not drop into the hole while the sun hides.
		float liftTarget = found ? sun.w * GAP_LIFT : (seeded ? prev5.w : 0.0);
		float lift = snap ? liftTarget : lerp(prev5.z, liftTarget, Rate(dt, GAP_LIFT_TIME));

		follow = follow ? share >= SUN_FOLLOW_OFF : share > SUN_FOLLOW_ON;
		float target = follow ? 1.0 : 0.0;
		float blend = seeded ? lerp(blendPrev, target, Rate(dt, SunAdapt)) : target;
		blend = blend > 0.999 ? 1.0 : (blend < 0.001 ? 0.0 : blend);

		t0 = float4(blend >= 0.5 ? shown : pinned, share, 1.0);
		t3 = float4(tracked, blend, target);
		t4 = float4(cand, held, lost);
		t5 = float4(shown, lift, liftTarget);
	}

	// Pass 3: the state. Texels 0, 3, 4 and 5 hold the auto sun, texel 1 smooths the peak, texel 2 holds the
	// depth state, texel 6 the seconds since the depth last differed across the grid and texel 7 the canopy
	// estimate.
	float4 RaysStatePS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		int texel = int(pos.x);
		float4 prev0 = tex2Dfetch(RaysPrev, int2(0, 0));
		bool seeded = prev0.w > 0.5;
		float dt = FrameSeconds();

		if (texel == 2)
			return DepthDecide(ScanDepth(), tex2Dfetch(RaysPrev, int2(2, 0)), seeded, dt);

		if (texel == 6)
		{
			float since = seeded ? tex2Dfetch(RaysPrev, int2(6, 0)).x : DEPTH_HOLD_TIME + DEPTH_FADE_TIME;
			since = DepthVaried(ScanDepth()) ? 0.0 : min(since + dt, 10.0);
			return float4(since, float(FrameCount % STAMP_MOD), 0.0, 1.0);
		}

		if (texel == 7)
		{
			// The canopy estimate: the sky edges of the stats cells (A), weighted by the same proximity to where
			// the sun enters (last frame's sun) as the mask. In the open there is nothing to cut the light into
			// shafts, under leaves the sky breaks into many small gaps, and their edges are what this counts.
			// The original faded its world shafts out in the open by a canopy estimate as well.
			float2 sunPrev = (SunMode == 0 && seeded) ? prev0.xy : float2(SunX, SunY);
			SunInfo s = Finish(sunPrev);
			float num = 0.0;
			float den = 0.0;
			[loop]
			for (int y = 0; y < STATS_H; ++y)
			{
				[unroll]
				for (int x = 0; x < STATS_W; ++x)
				{
					float2 cell = float2((x + 0.5) / STATS_W, (y + 0.5) / STATS_H);
					float2 d = (cell - s.e) * float2(ASPECT, 1.0);
					float w = pow(saturate(1.0 - length(d) / max(RaysRadius, 0.05)), RaysFalloff);
					num += w * tex2Dfetch(RaysStats, int2(x, y)).w;
					den += w;
				}
			}
			float canopyNow = num / max(den, 1e-6);
			float4 prev7 = tex2Dfetch(RaysPrev, int2(7, 0));
			float eased = seeded ? lerp(prev7.x, canopyNow, Rate(dt, RaysAdaptTime)) : canopyNow;
			return float4(eased, canopyNow, 0.0, 1.0);
		}

		if (texel == 1)
		{
			// The peak for the relative threshold: the brightest cell within Radius of where the sun enters
			// (last frame's sun), plus half a cell diagonal. White UI elsewhere cannot set it this way.
			float2 sunPrev = (SunMode == 0 && seeded) ? prev0.xy : float2(SunX, SunY);
			SunInfo s = Finish(sunPrev);
			float reach = max(RaysRadius, 0.05) + 0.5 * length(float2(ASPECT / STATS_W, 1.0 / STATS_H));
			float peak = 0.0;
			[loop]
			for (int y = 0; y < STATS_H; ++y)
			{
				[unroll]
				for (int x = 0; x < STATS_W; ++x)
				{
					float2 cell = float2((x + 0.5) / STATS_W, (y + 0.5) / STATS_H);
					float2 d = (cell - s.e) * float2(ASPECT, 1.0);
					float r = tex2Dfetch(RaysStats, int2(x, y)).x;
					peak = max(peak, dot(d, d) <= reach * reach ? r : 0.0);
				}
			}
			float4 prev1 = tex2Dfetch(RaysPrev, int2(1, 0));
			float eased = seeded ? lerp(prev1.x, peak, Rate(dt, RaysAdaptTime)) : peak;
			return float4(eased, 0.0, 0.0, 1.0);
		}

		// Texels 0, 3, 4 and 5 run the same auto sun step and each keeps its part.
		float4 t0, t3, t4, t5;
		SunStep(prev0, seeded, dt, t0, t3, t4, t5);
		if (texel == 0)
			return t0;
		if (texel == 3)
			return t3;
		return texel == 4 ? t4 : t5;
	}

	float4 RaysSavePS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		return tex2Dfetch(RaysCur, int2(pos.xy));
	}

	// Pass 4: the light source in the light buffer. The original mask (kMaskHlsl) of every scene texel, gated to
	// the sky when depth allows, averaged over the light texel's block. A sky gap then counts by its area and
	// not by where it falls on the grid, so a gap that slides by a pixel does not switch a spoke on or off. The
	// colour stays, so dusk shafts keep the orange of the sky.
	// The sky gate opens fully once a quarter of a scene texel is sky. Its colour is already the average of its
	// pixels, so a texel half sky, half leaves is already darker, as in the original. Snow and water with no
	// sky stay shut. The UI mask applies here, once per light texel: masked pixels cast no rays.
	float4 RaysSourcePS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		float peak = tex2Dfetch(RaysCur, int2(1, 0)).x;
		float thr = max(RaysThreshold, peak * RaysRelThreshold);
		float span = max(peak - thr, 0.02);
		SunInfo sun = CurrentSun();
		float4 depthState = tex2Dfetch(RaysCur, int2(2, 0));
		bool skyGate = RaysSkyOnly && depthState.y > 0.5;
		float2 block = float2(1.0 / LEGIONGU_LIGHT_W, 1.0 / LEGIONGU_LIGHT_H);

		float3 acc = float3(0.0, 0.0, 0.0);
		[unroll]
		for (int j = 0; j < LEGIONGU_SRC_TAPS; ++j)
		{
			[unroll]
			for (int i = 0; i < LEGIONGU_SRC_TAPS; ++i)
			{
				float2 t = uv + ((float2(i, j) + 0.5) / float(LEGIONGU_SRC_TAPS) - 0.5) * block;
				float4 s = tex2Dlod(RaysScenePoint, float4(t, 0.0, 0.0));
				float3 lit = s.rgb * saturate((dot(s.rgb, LUMA601) - thr) / span);
				float2 d = (t - sun.e) * float2(ASPECT, 1.0);
				float f = pow(saturate(1.0 - length(d) / max(RaysRadius, 0.05)), RaysFalloff);
				float gate = skyGate ? saturate(4.0 * s.a) : 1.0;
				acc += lit * (f * gate);
			}
		}
		return float4(acc * ((1.0 - UIMask(uv)) / float(LEGIONGU_SRC_TAPS * LEGIONGU_SRC_TAPS)), 1.0);
	}

	// Passes 5 and 6: penumbra. A 9-tap binomial blur (sigma 1.4 light texels, 0.8% of the screen height) as
	// 5 bilinear taps, across then down. The sun is a disc of about half a degree, so real shaft edges are
	// soft; this also takes out the grid-level detail the arc blur alone would leave.
	float4 Soft(sampler2D src, float2 uv, float2 dir)
	{
		float2 o1 = dir * 1.3846153846;
		float2 o2 = dir * 3.2307692308;
		float3 c = tex2Dlod(src, float4(uv, 0.0, 0.0)).rgb * 0.2270270270;
		c += (tex2Dlod(src, float4(uv + o1, 0.0, 0.0)).rgb + tex2Dlod(src, float4(uv - o1, 0.0, 0.0)).rgb) * 0.3162162162;
		c += (tex2Dlod(src, float4(uv + o2, 0.0, 0.0)).rgb + tex2Dlod(src, float4(uv - o2, 0.0, 0.0)).rgb) * 0.0702702703;
		return float4(c, 1.0);
	}

	float4 RaysSoftHPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		return Soft(RaysPing, uv, float2(1.0 / LEGIONGU_LIGHT_W, 0.0));
	}

	float4 RaysSoftVPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		return Soft(RaysPong, uv, float2(0.0, 1.0 / LEGIONGU_LIGHT_H));
	}

	// Passes 7 to 9: radial blur (the original kBlurHlsl) on the light buffer. Pass q has 16 taps and its reach
	// is 1 / 16^(2 - q) of the ray, so the three passes span L/256, L/16 and L. The taps are spaced
	// geometrically: tap i sits at ratio^i of the pixel's way to p and weighs ratio^i, the share of the ray it
	// stands for, with ratio^(16^(3 - q)) = 1 - L. Each tap of a pass then covers exactly the stretch the pass
	// before averaged, so the three passes are one even average over the whole ray and leave no gaps that
	// would repeat bright blobs along it. With Parallel 1 the ratio is 1 and the taps step along 'away'. Only
	// the last pass decays, and the weights are normalised, so the composite alone sets the brightness.
	// At this size all three passes cost almost nothing, and fewer passes only bring back banding.
	float4 Blur(sampler2D src, float2 uv, int q)
	{
		float4 c0 = tex2Dlod(src, float4(uv, 0.0, 0.0));
		if (DebugView == DBG_MASK)
			return c0;

		float k = q == 0 ? 4096.0 : (q == 1 ? 256.0 : 16.0);
		SunInfo s = CurrentSun();
		float lr = min(s.lengthFrac * (1.0 - s.par), 0.98);
		float ratio = exp2(log2(1.0 - lr) / k);
		float2 stepP = s.away * (s.par * RaysMaxLength / k);
		float decay = q == 2 ? RaysDecay : 1.0;

		float2 v = uv - s.p;
		float3 sum = float3(0.0, 0.0, 0.0);
		float wsum = 0.0;
		float w = 1.0;
		float scale = 1.0;
		[unroll]
		for (int i = 0; i < 16; ++i)
		{
			sum += tex2Dlod(src, float4(s.p + v * scale - stepP * i, 0.0, 0.0)).rgb * w;
			wsum += w;
			w *= ratio * decay;
			scale *= ratio;
		}
		return float4(sum / wsum, 1.0);
	}

	float4 RaysBlur0PS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		return Blur(RaysPing, uv, 0);
	}

	float4 RaysBlur1PS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		return Blur(RaysPong, uv, 1);
	}

	float4 RaysBlur2PS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		return Blur(RaysPing, uv, 2);
	}

	// One arc blur around the point the rays converge on, in screen heights: 13 taps on the circle through the
	// pixel, Gaussian in angle, half width halfDeg = 2 sigma, the rotation stepped by one sine and cosine pair.
	float3 Arc(float2 uv, float2 p, float halfDeg)
	{
		float2 toH = float2(ASPECT, 1.0);
		float2 v = (uv - p) * toH;
		const int K = 6;
		float step = radians(halfDeg) / K;
		float cs = cos(step);
		float sn = sin(step);
		float3 sum = tex2Dlod(RaysPong, float4(uv, 0.0, 0.0)).rgb;
		float wsum = 1.0;
		float2 a = v;
		float2 b = v;
		[unroll]
		for (int k = 1; k <= K; ++k)
		{
			a = float2(a.x * cs - a.y * sn, a.x * sn + a.y * cs);
			b = float2(b.x * cs + b.y * sn, -b.x * sn + b.y * cs);
			float x = float(k) / float(K) * 2.0;
			float w = exp(-0.5 * x * x);
			sum += (tex2Dlod(RaysPong, float4(p + a / toH, 0.0, 0.0)).rgb + tex2Dlod(RaysPong, float4(p + b / toH, 0.0, 0.0)).rgb) * w;
			wsum += 2.0 * w;
		}
		return sum / wsum;
	}

	// Pass 10: no spokes, broad beams. The ripple is angular detail, so the cure is a blur in angle: a spoke
	// narrower than ARC_FINE_DEG spreads out and fades, a beam wider than that survives. An angle is the same
	// near the sun and far from it and does not depend on the resolution. The wide arc is the glow; the
	// difference between the fine and the wide arc, amplified by 1 + 4 RaysDefinition, makes separate beams
	// stand out of it.
	float4 RaysArcPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		if (DebugView == DBG_MASK)
			return tex2Dlod(RaysPong, float4(uv, 0.0, 0.0));
		SunInfo s = CurrentSun();
		float3 fine = Arc(uv, s.p, ARC_FINE_DEG);
		float3 wide = Arc(uv, s.p, ARC_WIDE_DEG);
		float k = 1.0 + 4.0 * RaysDefinition;
		return float4(max(wide + (fine - wide) * k, 0.0), 1.0);
	}

	float3 SunMarker(float3 o, float2 uv)
	{
		float4 follow = tex2Dfetch(RaysCur, int2(3, 0));
		SunInfo s = CurrentSun();
		float2 toHeights = float2(ASPECT, 1.0);
		float dp = length((uv - s.p) * toHeights);
		float de = length((uv - s.e) * toHeights);
		float3 dotColour = (SunMode == 0 && follow.z >= 0.5) ? float3(0.2, 1.0, 0.3) : float3(1.0, 0.6, 0.1);
		if (abs(de - max(RaysRadius, 0.05)) < 0.003)
			o = lerp(o, float3(1.0, 0.9, 0.2), 0.7);
		if (abs(de - 0.03) < 0.004)
			o = float3(1.0, 1.0, 1.0);
		if (dp < 0.012)
			o = dotColour;
		// The canopy estimate as a bar along the top edge (full width = 1 / BAR_SCALE), red ticks at CANOPY_LO
		// and CANOPY_HI. It is the only way to calibrate the two limits in the game.
		float canopy = tex2Dfetch(RaysCur, int2(7, 0)).x;
		if (uv.y < 0.015)
			o = uv.x < canopy * BAR_SCALE ? float3(1.0, 1.0, 1.0) : float3(0.0, 0.0, 0.0);
		if (uv.y < 0.03 && (abs(uv.x - CANOPY_LO * BAR_SCALE) < 0.002 || abs(uv.x - CANOPY_HI * BAR_SCALE) < 0.002))
			o = float3(1.0, 0.0, 0.0);
		return o;
	}

	// Pass 11: the composite, over the whole frame (see LEGIONGU_UI_MASK). The original added the rays (kCompHlsl with ONE, ONE blending);
	// here the light is scaled by the air in front of the pixel and added as a screen blend, c + add (1 - c):
	// light cannot make a pixel brighter than white, so the sky near the sun keeps its own size.
	// Auto with depth: full strength at the sun, RaysNoSunGain at the pinned point and a dip to 0 while the
	// point changes (see SunStep). Without depth Auto is the pinned mode, like the original's sunMode 0, and
	// the canopy estimate is 0, so only the open strength is left. With "rays only with depth" the rays go out a second after the depth stopped differing (a
	// cleared buffer on a loading screen, no depth in a cinematic, like the original's placement 0), and they
	// fade back in with depth. The canopy estimate leaves RAYS_OPEN_GAIN of the strength in the open.
	float4 RaysCompositePS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		float4 c = tex2Dfetch(ColorPoint, int2(pos.xy));
		if ((DebugView >= DBG_DEPTH && DebugView <= DBG_COLOUR) || DebugView == DBG_NIGHT)
			return c;

		float3 rays = tex2Dlod(RaysPing, float4(uv, 0.0, 0.0)).rgb;
		if (DebugView == DBG_MASK || DebugView == DBG_RAYS)
			return float4(rays, 1.0);

		float gain = RaysStrength * 0.01 * RaysMaxExposure;
		float4 depthState = tex2Dfetch(RaysCur, int2(2, 0));
		float depthLive = depthState.x * depthState.y;
		if (SunMode == 0)
		{
			float blend = tex2Dfetch(RaysCur, int2(3, 0)).z;
			float autoGain = blend >= 0.5 ? 2.0 * blend - 1.0 : (1.0 - 2.0 * blend) * RaysNoSunGain;
			gain *= lerp(1.0, autoGain, depthLive);
		}
		if (RaysNeedDepth)
		{
			float since = tex2Dfetch(RaysCur, int2(6, 0)).x;
			gain *= depthLive * saturate((DEPTH_HOLD_TIME + DEPTH_FADE_TIME - since) / DEPTH_FADE_TIME);
		}
		// Open view: a mild glow only. Under leaves: the full shafts.
		float canopy = saturate((tex2Dfetch(RaysCur, int2(7, 0)).x - CANOPY_LO) / (CANOPY_HI - CANOPY_LO));
		gain *= lerp(RAYS_OPEN_GAIN, 1.0, canopy);
		// The light is in the air: as much as there is air in front of the pixel.
		float air = lerp(AIR_NO_DEPTH, tex2Dlod(RaysAir, float4(uv, 0.0, 0.0)).x, depthLive);
		gain *= air * AIR_GAIN;
		float3 add = rays * RaysColour * gain;
		float3 o = c.rgb + add * (1.0 - saturate(c.rgb));
		if (DebugView == DBG_SUN)
			o = SunMarker(o, uv);
		return float4(o, c.a);
	}

	// ---------------------------------------------------------------------------------------------------
	// Techniques. Fog first, rays on the fogged image, the original's order.
	// ---------------------------------------------------------------------------------------------------

	technique LegionGUNights <
		ui_label = "GU-WOW: ночь и огни";
		ui_tooltip = "Тёмная ночь под ночным небом и свет вокруг факелов, фонарей, окон и костров.\n"
		             "В подземельях и домах ночь не затемняется, а огни светят.\n"
		             "Alt+F11 включает и выключает ночь и огни.\n"
		             "F11 включает и выключает весь мод, если F11 стоит в поле «Клавиша активации эффекта» на вкладке «Настройки».";
	>
	{
		pass NightGrid { VertexShader = FullscreenVS; PixelShader = NightGridPS; RenderTarget0 = NightGridATex; RenderTarget1 = NightGridBTex; }
		pass NightState { VertexShader = FullscreenVS; PixelShader = FogStatePS; RenderTarget = FogCurTex; }
		pass NightSave { VertexShader = FullscreenVS; PixelShader = FogSavePS; RenderTarget = FogPrevTex; }
		pass LightFind { VertexShader = FullscreenVS; PixelShader = LightFindPS; RenderTarget = LightRawTex; }
		pass LightSteady { VertexShader = FullscreenVS; PixelShader = LightSteadyPS; RenderTarget = LightSrcTex; }
		pass LightKeep { VertexShader = FullscreenVS; PixelShader = LightKeepPS; RenderTarget = LightPrevTex; }
		pass L0 { VertexShader = FullscreenVS; PixelShader = L0PS; RenderTarget = L0Tex; }
		pass L1 { VertexShader = FullscreenVS; PixelShader = L1PS; RenderTarget = L1Tex; }
		pass L2 { VertexShader = FullscreenVS; PixelShader = L2PS; RenderTarget = L2Tex; }
		pass LightCombine { VertexShader = FullscreenVS; PixelShader = LightCombinePS; RenderTarget0 = LitTex; RenderTarget1 = AirTex; }
		pass NightApply { VertexShader = FullscreenVS; PixelShader = FogApplyPS; }
	}

	// ---------------------------------------------------------------------------------------------------
	// LegionGUPicture: sharpening, the colour of the time of day, eye adaptation and a light vignette, in one
	// pass over the finished frame: after the fog, the night and the rays, before the interface with REST.
	// ---------------------------------------------------------------------------------------------------

	static const float SHARP_MAX = 0.2;          // the CAS weight at «Резкость» 100, AMD's full strength
	static const float EYE_STRENGTH = 0.45;      // share of a change of brightness shown before the eye adapts
	static const float EYE_DEAD = 0.3;           // log units: a camera turn changes the frame less than this
	static const float EYE_MAX = 0.7;            // the adaptation stays within e^-0.7 .. e^0.7
	static const float EYE_TO_DARK = 1.5;        // seconds to get used to a dark place
	static const float EYE_TO_BRIGHT = 0.5;      // seconds to get used to daylight
	static const float EYE_KNEE = 0.8;           // while it dazzles, highlights above this roll off
	static const float EYE_FLOOR = 0.04;         // luminance floor of the mean, so a dark night does not swing it
	static const float GRADE_WARM_FROM = 0.12;   // warmth (r - b) / max of the fog colour where the evening starts
	static const float GRADE_WARM_GAIN = 4.0;
	static const float3 GRADE_GOLD = float3(1.06, 1.0, 0.9);
	static const float3 GRADE_MOON = float3(0.93, 0.98, 1.07);
	static const float VIGNETTE_MAX = 0.22;      // darkening of the corners at «Виньетка» 100
	static const float HAZE_FROM = 60.0;         // heat haze starts at this many yards: the character and the near world stay still
	static const float HAZE_FULL = 250.0;        // and is full from here on
	static const float HAZE_PX = 1.2;            // the largest waver in pixels at 1080 lines
	static const float GRAIN_MAX = 0.06;         // film grain at «Плёночное зерно» 100

	texture2D PicLumTex { Width = 64; Height = 32; Format = RG16F; MipLevels = 7; };
	sampler2D PicLum { Texture = PicLumTex; };
	texture2D PicEyeCurTex { Width = 1; Height = 1; Format = RGBA32F; };
	texture2D PicEyePrevTex { Width = 1; Height = 1; Format = RGBA32F; };
	sampler2D PicEyeCur { Texture = PicEyeCurTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };
	sampler2D PicEyePrev { Texture = PicEyePrevTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };

	// Log luminance weighted toward the middle of the frame (the eye looks at the land ahead), and the weight;
	// the top mip is the weighted mean.
	float2 PicLumPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		float2 d = uv - 0.5;
		float w = 1.0 - 0.75 * saturate(dot(d, d) * 4.0);
		float l = dot(tex2Dlod(ColorLinear, float4(uv, 0.0, 0.0)).rgb, LUMA601);
		// The floor keeps a dark night steady: a lit mount or a torch coming into a nearly black frame no longer moves
		// the mean by a lot.
		return float2(log(max(l, EYE_FLOOR)) * w, w);
	}

	// x = the adapted log luminance, y = seeded, z = this frame's.
	float4 PicEyePS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		float2 m = tex2Dlod(PicLum, float4(0.5, 0.5, 0.0, 6.0)).xy;
		float now = m.x / max(m.y, 1e-4);
		float4 prev = tex2Dfetch(PicEyePrev, int2(0, 0));
		if (prev.y < 0.5)
			return float4(now, 1.0, now, 1.0);
		float tau = now < prev.x ? EYE_TO_DARK : EYE_TO_BRIGHT;
		return float4(lerp(prev.x, now, Rate(FrameSeconds(), tau)), 1.0, now, 1.0);
	}

	float4 PicEyeSavePS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		return tex2Dfetch(PicEyeCur, int2(0, 0));
	}

	float4 PicApplyPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		int2 p = int2(pos.xy);
		float4 c4 = tex2Dfetch(ColorPoint, p);
		if (!LegionGUOn(1u) || LegionGUInStrip(pos.xy))
			return c4;
		float3 c = c4.rgb;

		// Heat haze over hot land (the addon's switch, in a desert or fire zone): the far ground wavers a pixel or so,
		// the sky and everything nearer than HAZE_FROM stay still.
		if (LegionGUExtra(1u) && LegionGUExtra(2u))
		{
			float4 hs = tex2Dfetch(FogCur, int2(1, 0));
			float hu = DepthU(RawDepth(uv), EffectiveReversed(hs.w));
			float hz = IsSky(hu) ? 0.0 : smoothstep(HAZE_FROM, HAZE_FULL, Yards(hu));
			if (hz > 0.0)
			{
				float ht = GUTimer * 0.001;
				float2 wob = float2(sin(uv.y * 700.0 + ht * 5.0 + sin(uv.x * 37.0 + ht * 1.7) * 2.0), 0.5 * sin(uv.y * 530.0 - ht * 4.1 + uv.x * 23.0));
				float2 off = wob * hz * HAZE_PX * (float(BUFFER_HEIGHT) / 1080.0) * float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
				c = tex2Dlod(ColorLinear, float4(uv + off, 0.0, 0.0)).rgb;
			}
		}

		// Sharpening, AMD's contrast adaptive kind: soft detail gains, hard edges and flat areas stay as they are.
		float sharp = LegionGUValue(LEGIONGU_CTL_SHARP, Sharpness) * 0.01;
		if (sharp > 0.0)
		{
			int2 lim = int2(BUFFER_WIDTH - 1, BUFFER_HEIGHT - 1);
			float3 n = tex2Dfetch(ColorPoint, clamp(p + int2(0, -1), int2(0, 0), lim)).rgb;
			float3 s = tex2Dfetch(ColorPoint, clamp(p + int2(0, 1), int2(0, 0), lim)).rgb;
			float3 e = tex2Dfetch(ColorPoint, clamp(p + int2(1, 0), int2(0, 0), lim)).rgb;
			float3 w = tex2Dfetch(ColorPoint, clamp(p + int2(-1, 0), int2(0, 0), lim)).rgb;
			float3 mn = min(c, min(min(n, s), min(e, w)));
			float3 mx = max(c, max(max(n, s), max(e, w)));
			float3 amp = sqrt(saturate(min(mn, 1.0 - mx) / max(mx, 1e-4)));
			float3 k = -amp * (SHARP_MAX * sharp);
			c = saturate((c + (n + s + e + w) * k) / (1.0 + 4.0 * k));
		}

		// Eye adaptation: a change of brightness shows at first and fades as the eye gets used to it, so the
		// steady picture stays the game's own.
		if (LegionGUFlag(32u, EyeAdapt))
		{
			float4 eye = tex2Dfetch(PicEyeCur, int2(0, 0));
			float r = eye.z - eye.x;
			r = sign(r) * max(abs(r) - EYE_DEAD, 0.0);
			// At night no dazzle: bright things come and go in the dark (lights, a glowing mount) and each one flashed the
			// whole frame. Getting used to the dark stays.
			if (r > 0.0)
				r *= 1.0 - tex2Dfetch(FogCur, int2(4, 0)).x;
			float f = exp(clamp(EYE_STRENGTH * r, -EYE_MAX, EYE_MAX));
			c *= f;
			if (f > 1.0)
			{
				float3 over = max(c - EYE_KNEE, 0.0);
				c = min(c, EYE_KNEE) + (1.0 - EYE_KNEE) * (1.0 - exp(-over / (1.0 - EYE_KNEE)));
			}
		}

		// The colour of the time of day: a little more colour by day, gold in the lights in the evening, cool
		// shadows at night. The torches stay warm: the night tint only reaches the darker tones.
		float g = LegionGUValue(LEGIONGU_CTL_GRADE, ColourGrade) * 0.01;
		if (g > 0.0)
		{
			float night = tex2Dfetch(FogCur, int2(4, 0)).x;
			float3 f0 = tex2Dfetch(FogCur, int2(0, 0)).rgb;
			float warm = saturate(((f0.r - f0.b) / max(max(f0.r, f0.b), 1e-3) - GRADE_WARM_FROM) * GRADE_WARM_GAIN)
					   * smoothstep(0.05, 0.15, dot(f0, LUMA601)) * (1.0 - night);
			// With the addon the game's clock decides: night 21 to 5 o'clock, evening 18 to 21, morning 5 to 8. Indoors
			// neither, a lit house at night is not moonlit.
			if (LegionGUState(1u))
			{
				float h = LegionGUHour();
				float nightT = saturate(1.0 - smoothstep(4.5, 6.0, h) + smoothstep(20.0, 21.5, h));
				float duskT = saturate(smoothstep(17.5, 19.0, h) - smoothstep(20.5, 22.0, h)) + saturate(smoothstep(4.5, 5.5, h) - smoothstep(6.5, 8.0, h));
				bool indoors = LegionGUState(2u);
				night = indoors ? 0.0 : nightT;
				warm = indoors ? 0.0 : max(saturate(duskT), 0.5 * warm) * (1.0 - night);
			}
			float l = dot(c, LUMA601);
			float3 grey = float3(l, l, l);
			float3 graded = lerp(grey, c, 1.05);
			graded = lerp(graded, graded * GRADE_GOLD, warm * smoothstep(0.1, 0.7, l));
			graded = lerp(graded, lerp(grey, graded, 0.9) * GRADE_MOON, night * (1.0 - smoothstep(0.3, 0.8, l)));
			c = saturate(lerp(c, graded, g));
		}

		// The colour style: 1 warm, 2 cold, 3 film (lifted blacks, softer colour, warm lights over cool shadows), 4 vivid,
		// 5 sunset (golden light, violet shadows), 6 fairy tale (soft pastel, bright middle), 7 noir (nearly black and white).
		int styleValue = LegionGUStyleValue();
		int style = styleValue >= 0 ? styleValue % 8 : ColourStyle;
		if (style > 0)
		{
			float ls = dot(c, LUMA601);
			if (style == 1)
				c = lerp(float3(ls, ls, ls), c, 1.05) * float3(1.06, 1.0, 0.9);
			else if (style == 2)
				c *= float3(0.93, 1.0, 1.08);
			else if (style == 3)
			{
				c = lerp(float3(ls, ls, ls), c, 0.85);
				c = 0.03 + c * 0.97;
				c *= lerp(float3(0.95, 1.0, 1.05), float3(1.05, 1.0, 0.94), smoothstep(0.2, 0.7, ls));
			}
			else if (style == 4)
				c = lerp(float3(ls, ls, ls), c, 1.2) * 1.02;
			else if (style == 5)
			{
				c = lerp(float3(ls, ls, ls), c, 1.1) * float3(1.08, 0.98, 0.86);
				c += float3(0.02, 0.0, 0.035) * (1.0 - smoothstep(0.0, 0.4, ls));
			}
			else if (style == 6)
			{
				c = 0.04 + lerp(float3(ls, ls, ls), c, 0.9) * 0.94;
				c = pow(saturate(c), 0.93) * lerp(float3(1.0, 1.0, 1.03), float3(1.04, 1.0, 1.02), smoothstep(0.4, 0.9, ls));
			}
			else if (style == 7)
				c = (lerp(float3(ls, ls, ls), c, 0.15) - 0.5) * 1.15 + 0.5 * float3(0.98, 1.0, 1.03);
			c = saturate(c);
		}

		// Cinema HDR (the addon's switch): the shadows a little deeper, the highlights rolled off before white and a touch
		// more colour, like a film print. On the luminance, so the hues stay.
		if (LegionGUExtra(4u))
		{
			float hl = max(dot(c, LUMA601), 1e-4);
			float tl = hl < 0.25 ? hl * lerp(0.8, 1.0, hl / 0.25) : hl;
			tl = tl > 0.65 ? 0.65 + (tl - 0.65) * (1.0 - 0.25 * (tl - 0.65) / 0.35) : tl;
			c = saturate(lerp(float3(tl, tl, tl), c * (tl / hl), 1.08));
		}

		// A light vignette: the corners a little darker, the middle as it is.
		float v = LegionGUValue(LEGIONGU_CTL_VIGNETTE, Vignette) * 0.01;
		if (v > 0.0)
		{
			float2 d = uv * 2.0 - 1.0;
			c *= 1.0 - v * VIGNETTE_MAX * smoothstep(0.5, 2.0, dot(d, d));
		}

		// Film grain (the slider): a new pattern every frame, strongest in the middle tones.
		float grain = LegionGUValue(LEGIONGU_CTL_GRAIN, FilmGrain) * 0.01;
		if (grain > 0.0)
		{
			uint gh = uint(p.x) * 1973u + uint(p.y) * 9277u + FrameCount * 26699u;
			gh = (gh ^ (gh >> 13u)) * 1274126177u;
			gh ^= gh >> 16u;
			float gn = float(gh & 65535u) / 65535.0 - 0.5;
			float gl = dot(c, LUMA601);
			c = saturate(c + gn * grain * GRAIN_MAX * (0.3 + 2.8 * gl * (1.0 - gl)));
		}
		return float4(c, c4.a);
	}

	technique LegionGUPicture <
		ui_label = "GU-WOW: картинка";
		ui_tooltip = "Резкость, цвет по времени суток, привыкание глаз и лёгкая виньетка.\n"
					 "Стоит последним в списке, после тумана, ночи и лучей.";
	>
	{
		pass PicLumPass { VertexShader = FullscreenVS; PixelShader = PicLumPS; RenderTarget = PicLumTex; }
		pass PicEyePass { VertexShader = FullscreenVS; PixelShader = PicEyePS; RenderTarget = PicEyeCurTex; }
		pass PicEyeSave { VertexShader = FullscreenVS; PixelShader = PicEyeSavePS; RenderTarget = PicEyePrevTex; }
		pass PicApply { VertexShader = FullscreenVS; PixelShader = PicApplyPS; }
	}

	// ---------------------------------------------------------------------------------------------------
	// LegionGUPhoto: the photo mode. The character in focus, the land behind and before it softly blurred like
	// through a camera lens. Switched by the addon's key (the interface hides with it), or by the checkbox without
	// the panel. Off, every pass returns at once.
	// ---------------------------------------------------------------------------------------------------

	static const float DOF_MAX_PX = 12.0;      // largest blur radius in half-resolution pixels at «Размытие» 100
	static const float BOKEH_GAIN = 8.0;       // bright taps weigh up to this much more with bokeh on: lights open into discs
	static const float DOF_SPAN = 1.2;         // this share of the focus distance behind the focus is fully blurred
	static const float DOF_NEAR = 3.0;         // in front of the focus the blur grows this much faster
	static const float DOF_FOCUS_TIME = 0.3;   // seconds for the focus to follow the character

	texture2D DofTex { Width = BUFFER_WIDTH / 2; Height = BUFFER_HEIGHT / 2; Format = RGBA16F; };
	texture2D DofBlurTex { Width = BUFFER_WIDTH / 2; Height = BUFFER_HEIGHT / 2; Format = RGBA16F; };
	texture2D DofFocusCurTex { Width = 1; Height = 1; Format = RGBA32F; };
	texture2D DofFocusPrevTex { Width = 1; Height = 1; Format = RGBA32F; };
	sampler2D Dof { Texture = DofTex; };
	sampler2D DofPoint { Texture = DofTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };
	sampler2D DofBlur { Texture = DofBlurTex; };
	sampler2D DofFocusCur { Texture = DofFocusCurTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };
	sampler2D DofFocusPrev { Texture = DofFocusPrevTex; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };

	bool PhotoOn()
	{
		return LegionGUPanel() ? LegionGUState(8u) : PhotoMode;
	}

	float DofYards(float2 uv, float4 depthState)
	{
		float u = DepthU(RawDepth(uv), EffectiveReversed(depthState.w));
		return IsSky(u) ? 1e5 : Yards(u);
	}

	// x = the focus distance in yards, eased; y = seeded. The focus is the nearest of five taps around the character,
	// a little below the middle of the frame.
	float4 DofFocusPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		float4 prev = tex2Dfetch(DofFocusPrev, int2(0, 0));
		float4 depthState = tex2Dfetch(FogCur, int2(1, 0));
		if (!PhotoOn() || depthState.y < 0.5)
			return float4(prev.x, 0.0, 0.0, 1.0);
		float f = min(min(DofYards(float2(0.5, 0.55), depthState), DofYards(float2(0.47, 0.62), depthState)),
					  min(min(DofYards(float2(0.53, 0.62), depthState), DofYards(float2(0.5, 0.7), depthState)), DofYards(float2(0.5, 0.48), depthState)));
		f = clamp(f, 1.0, 500.0);
		return float4(prev.y > 0.5 ? lerp(prev.x, f, Rate(FrameSeconds(), DOF_FOCUS_TIME)) : f, 1.0, 0.0, 1.0);
	}

	float4 DofFocusSavePS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		return tex2Dfetch(DofFocusCur, int2(0, 0));
	}

	// Half resolution: rgb = the colour, a = the blur radius 0..1 of DOF_MAX_PX.
	float4 DofPrepPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		if (!PhotoOn())
			return float4(0.0, 0.0, 0.0, 0.0);
		float f = tex2Dfetch(DofFocusCur, int2(0, 0)).x;
		float z = DofYards(uv, tex2Dfetch(FogCur, int2(1, 0)));
		float coc = z >= f ? saturate((z - f) / (f * DOF_SPAN)) : saturate((f - z) / f * DOF_NEAR);
		return float4(tex2Dlod(ColorLinear, float4(uv, 0.0, 0.0)).rgb, coc);
	}

	// A disk of 24 taps. A tap counts only where its own blur reaches this pixel, so the sharp character does not
	// bleed into the blurred land behind it.
	float4 DofBlurPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		if (!PhotoOn())
			return float4(0.0, 0.0, 0.0, 0.0);
		float4 centre = tex2Dlod(DofPoint, float4(uv, 0.0, 0.0));
		float2 px = 2.0 * float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
		float maxPx = DOF_MAX_PX * LegionGUValue(LEGIONGU_CTL_PHOTO_BLUR, PhotoBlur) * 0.01;
		bool bokeh = LegionGUExtra(8u);
		float r = centre.a * maxPx;
		float3 sum = centre.rgb;
		float wsum = 1.0;
		[unroll]
		for (int i = 1; i <= 24; ++i)
		{
			float d = sqrt(float(i) / 24.0);
			float a = float(i) * 2.3999632;
			float4 t = tex2Dlod(Dof, float4(uv + float2(cos(a), sin(a)) * d * r * px, 0.0, 0.0));
			float w = saturate(t.a * maxPx - d * r + 1.0);
			if (bokeh)
				w *= 1.0 + BOKEH_GAIN * pow(saturate((dot(t.rgb, LUMA601) - 0.55) / 0.45), 2.0);
			sum += t.rgb * w;
			wsum += w;
		}
		return float4(sum / wsum, centre.a);
	}

	float4 DofApplyPS(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
	{
		float4 c = tex2Dfetch(ColorPoint, int2(pos.xy));
		if (!PhotoOn() || LegionGUInStrip(pos.xy))
			return c;
		float4 b = tex2Dlod(DofBlur, float4(uv, 0.0, 0.0));
		// The cinema frame (the addon's option): black bars to 2.39 : 1 on a narrower screen.
		float bar = 0.5 * saturate(1.0 - float(BUFFER_WIDTH) / float(BUFFER_HEIGHT) / 2.39);
		if (LegionGUStyleValue() >= 8 && (uv.y < bar || uv.y > 1.0 - bar))
			return float4(0.0, 0.0, 0.0, c.a);
		return float4(lerp(c.rgb, b.rgb, smoothstep(0.05, 0.3, b.a)), c.a);
	}

	technique LegionGUPhoto <
		ui_label = "GU-WOW: фоторежим";
		ui_tooltip = "Персонаж в фокусе, фон мягко размыт, как на фотоаппарате.\n"
					 "В игре включается клавишей: Меню > Назначение клавиш > GU-WOW. Интерфейс тогда прячется.\n"
					 "Стоит последним в списке.";
	>
	{
		pass DofFocus { VertexShader = FullscreenVS; PixelShader = DofFocusPS; RenderTarget = DofFocusCurTex; }
		pass DofFocusSave { VertexShader = FullscreenVS; PixelShader = DofFocusSavePS; RenderTarget = DofFocusPrevTex; }
		pass DofPrep { VertexShader = FullscreenVS; PixelShader = DofPrepPS; RenderTarget = DofTex; }
		pass DofBlurPass { VertexShader = FullscreenVS; PixelShader = DofBlurPS; RenderTarget = DofBlurTex; }
		pass DofApply { VertexShader = FullscreenVS; PixelShader = DofApplyPS; }
	}
}
