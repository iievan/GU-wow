// GU-WOW for the Direct3D 9 clients (1.12 and 3.3.5): runs the effects before the interface is drawn, so the fog, the
// rays, the night and the picture lie under the game's windows and never over them.
//
// The client with the full screen glow blurs the world at a quarter of the screen and lays the glow over it in one
// quad onto the back buffer: no lighting, no blending, the whole screen, the fixed function vertex format 0x242. The
// interface follows on the back buffer. The effects run right before the first draw after that quad. 1.12 draws the
// world into a texture of its own and 3.3.5 straight onto the back buffer, so the quad is the one mark both share
// (the probes of 28.09); a count of the draws before it held for 1.12 only. The minimap of 3.3.5 is the same format,
// yet blended and in a corner, so it never passes. The panel's strip is part of the interface, so LegionGUBridge,
// which reads it, runs once more at the end of the frame over the finished picture; the effects of the next frame
// take the settings from there, one frame late. A frame without that quad (the glow off, the login screen) keeps
// ReShade's own order: every effect at the end of the frame, around the interface rectangles the addon reports.
#include <reshade.hpp>
#include <d3d9.h>

using namespace reshade::api;


static effect_runtime *runtime = nullptr;
static effect_technique bridge = {};
static bool onBack = false;
static bool copied = false;
static bool rendered = false;

static resource_view BackBufferView()
{
	return resource_view { runtime->get_current_back_buffer().handle };
}

static void OnInitRuntime(effect_runtime *r)
{
	runtime = r;
}

static void OnDestroyRuntime(effect_runtime *r)
{
	if (runtime == r)
		runtime = nullptr;
	bridge = {};
}

static void OnReloaded(effect_runtime *r)
{
	if (runtime == r)
		bridge = r->find_technique("LegionGUbylevan.fx", "LegionGUBridge");
}

static void OnBindTargets(command_list *, uint32_t count, const resource_view *rtvs, resource_view)
{
	onBack = runtime != nullptr && count > 0 && (rtvs[0].handle & ~1ull) == runtime->get_current_back_buffer().handle;
}

// The glow quad: the format 0x242 (position, colour, two texture sets), no blending, the viewport over the whole
// target.
static bool IsGlowQuad(command_list *cmd_list)
{
	auto dev = reinterpret_cast<IDirect3DDevice9 *>(cmd_list->get_device()->get_native());
	DWORD fvf = 0, blend = 1;
	dev->GetFVF(&fvf);
	if (fvf != (D3DFVF_XYZ | D3DFVF_DIFFUSE | D3DFVF_TEX2))
		return false;
	dev->GetRenderState(D3DRS_ALPHABLENDENABLE, &blend);
	if (blend != 0)
		return false;
	D3DVIEWPORT9 vp = {};
	dev->GetViewport(&vp);
	IDirect3DSurface9 *rt = nullptr;
	if (FAILED(dev->GetRenderTarget(0, &rt)) || rt == nullptr)
		return false;
	D3DSURFACE_DESC rd = {};
	rt->GetDesc(&rd);
	rt->Release();
	return vp.X == 0 && vp.Y == 0 && vp.Width == rd.Width && vp.Height == rd.Height;
}

static void BeforeDraw(command_list *cmd_list)
{
	if (runtime == nullptr || rendered || !onBack)
		return;
	if (!copied)
	{
		copied = IsGlowQuad(cmd_list);
		return;
	}
	rendered = true;
	const resource_view rtv = BackBufferView();
	runtime->render_effects(cmd_list, rtv, rtv);
}

static bool OnDraw(command_list *cmd_list, uint32_t, uint32_t, uint32_t, uint32_t)
{
	BeforeDraw(cmd_list);
	return false;
}

static bool OnDrawIndexed(command_list *cmd_list, uint32_t, uint32_t, uint32_t, int32_t, uint32_t)
{
	BeforeDraw(cmd_list);
	return false;
}

static void OnPresent(command_queue *queue, swapchain *, const rect *, const rect *, uint32_t, const rect *)
{
	// The effects ran under the interface: ReShade skips them at the end of this frame, so the bridge reads the
	// strip here.
	if (rendered && runtime != nullptr && runtime->get_effects_state() && bridge != 0 && runtime->get_technique_state(bridge))
	{
		const resource_view rtv = BackBufferView();
		runtime->render_technique(bridge, queue->get_immediate_command_list(), rtv, rtv);
	}
	copied = false;
	rendered = false;
}

extern "C" __declspec(dllexport) const char *NAME = "GU-WOW";
extern "C" __declspec(dllexport) const char *DESCRIPTION = "Runs the GU-WOW effects under the game's interface in the 1.12 and 3.3.5 clients.";

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID)
{
	if (reason == DLL_PROCESS_ATTACH)
	{
		if (!reshade::register_addon(module))
			return FALSE;
		reshade::register_event<reshade::addon_event::init_effect_runtime>(OnInitRuntime);
		reshade::register_event<reshade::addon_event::destroy_effect_runtime>(OnDestroyRuntime);
		reshade::register_event<reshade::addon_event::reshade_reloaded_effects>(OnReloaded);
		reshade::register_event<reshade::addon_event::bind_render_targets_and_depth_stencil>(OnBindTargets);
		reshade::register_event<reshade::addon_event::draw>(OnDraw);
		reshade::register_event<reshade::addon_event::draw_indexed>(OnDrawIndexed);
		reshade::register_event<reshade::addon_event::present>(OnPresent);
	}
	else if (reason == DLL_PROCESS_DETACH)
	{
		reshade::unregister_addon(module);
	}
	return TRUE;
}
