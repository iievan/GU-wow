// GU-WOW by levan: installs and removes GU-WOW (ReShade effects, the REST add-on, the in-game panel) for a
// World of Warcraft client. C# 5, .NET Framework 4.x, built with the csc.exe that ships with Windows.
// ReShade itself is not bundled: it is downloaded from reshade.me and checked against a pinned SHA-256.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

class ShotForm : Form
{
	public static bool quiet;
	protected override bool ShowWithoutActivation { get { return quiet; } }
}

static class WowGU
{
	const string Version = "1.6.0-release";
	// Ctrl + Scroll Lock opens the ReShade window: key, Ctrl, Shift, Alt.
	const string OverlayKey = "145,1,0,0";
	// Releases of GU-WOW: the window says when a newer one is out and opens its page; it never downloads by itself.
	const string ReleasesApi = "https://api.github.com/repos/iievan/GU-wow/releases/latest";
	const string ReShadeUrl = "https://reshade.me/downloads/ReShade_Setup_6.8.0_Addon.exe";
	const string ReShadeSha256 = "afe4c8f13048306307983b8b3d41d5bf00a86820440b0e57dea10950e1176445";
	const string Marker = "wowGU.txt";
	const string Preset = "LegionGUbylevan.ini";
	static readonly string[] Exes = { "Wow-64.exe", "Wow64.exe", "WowT-64.exe", "WowB-64.exe", "Wow.exe", "WowClassic.exe", "WowClassicT.exe" };

	static Form form;
	static TextBox pathBox, log;
	static Label found;
	static Button install, remove;

	[DllImport("user32.dll")] static extern bool SetProcessDPIAware();

	static string cliLog;

	// wowGU.exe --install|--uninstall <game folder> <log file>: the same steps without the window.
	[STAThread]
	static void Main(string[] args)
	{
		SetProcessDPIAware();
		if (args.Length == 3)
		{
			cliLog = args[2];
			current = Inspect(args[1]);
			if (current == null) { Say("no game"); return; }
			try { if (args[0] == "--install") Install(); else Uninstall(); }
			catch (Exception e) { Say("Ошибка: " + e); }
			return;
		}
		Application.EnableVisualStyles();
		form = new ShotForm { Text = "GU-WOW " + Version, ClientSize = new Size(660, 620), Font = new Font("Segoe UI", 10f), FormBorderStyle = FormBorderStyle.FixedSingle, MaximizeBox = false, StartPosition = FormStartPosition.CenterScreen };
		var title = new Label { Text = "GU-WOW", Location = new Point(16, 12), Size = new Size(630, 28), Font = new Font("Segoe UI", 13f, FontStyle.Bold) };
		var head = new Label
		{
			Text = "Графическое улучшение World of Warcraft, созданное специально для сообщества Brothers of Turtle.\n\n" +
			       "Добавляет в игру лучи солнца, туман и дымку, ночь по игровым часам и тёплый свет огней. " +
			       "Сразу после установки работает с настройками по умолчанию. Изменить их можно в меню игры: " +
			       "Интерфейс > Модификации > GU-WOW.\n\n" +
			       "Создано на основе ReShade. © 2026 levan. Эффекты распространяются по лицензии GPL-3.0. " +
			       "Меню в игре, установщик и готовая настройка распространяются по лицензии автора: изменённые версии и клоны только с его согласия.\n\n" +
			       "Неофициальный любительский проект. Не связан с Blizzard Entertainment и не претендует на её " +
			       "интеллектуальную собственность. World of Warcraft является товарным знаком Blizzard Entertainment, Inc.",
			Location = new Point(16, 44), AutoSize = true, MaximumSize = new Size(630, 0), Font = new Font("Segoe UI", 10f)
		};
		// Everything below the text follows its real height, which depends on the screen scale.
		int y = 44 + head.PreferredSize.Height + 10;
		var hint = new Label { Text = "Укажите папку игры с Wow.exe или Wow-64.exe и нажмите «Установить».", Location = new Point(16, y), Size = new Size(630, 24) };
		pathBox = new TextBox { Location = new Point(16, y + 28), Size = new Size(520, 26) };
		var browse = new Button { Text = "Обзор…", Location = new Point(544, y + 26), Size = new Size(100, 30) };
		found = new Label { Location = new Point(16, y + 62), Size = new Size(630, 24), ForeColor = Color.DimGray };
		install = new Button { Text = "Установить", Location = new Point(16, y + 92), Size = new Size(200, 40), Font = new Font("Segoe UI", 11f, FontStyle.Bold) };
		remove = new Button { Text = "Удалить", Location = new Point(228, y + 92), Size = new Size(140, 40) };
		log = new TextBox { Location = new Point(16, y + 144), Size = new Size(628, 230), Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, BackColor = Color.White };
		form.Controls.AddRange(new Control[] { title, head, hint, pathBox, browse, found, install, remove, log });
		form.ClientSize = new Size(660, y + 390);
		var update = new LinkLabel { Location = new Point(390, y + 92), Size = new Size(254, 50), Visible = false };
		form.Controls.Add(update);
		new Thread(() => CheckUpdate(update)) { IsBackground = true }.Start();

		pathBox.TextChanged += delegate { Detect(); };
		browse.Click += delegate
		{
			using (var d = new FolderBrowserDialog { Description = "Папка игры (где лежит Wow.exe или Wow-64.exe)" })
				if (d.ShowDialog(form) == DialogResult.OK) pathBox.Text = d.SelectedPath;
		};
		install.Click += delegate { RunJob(Install); };
		remove.Click += delegate
		{
			if (MessageBox.Show(form, "Удалить GU-WOW из этой папки игры?", "GU-WOW", MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes)
				RunJob(Uninstall);
		};
		pathBox.Text = FindGame() ?? "";
		Detect();
		if (args.Length == 2 && args[0] == "--shot")
		{
			// A picture of the window for checking the layout: shown for a moment without taking the focus.
			ShotForm.quiet = true;
			form.ShowInTaskbar = false;
			var timer = new System.Windows.Forms.Timer { Interval = 600 };
			timer.Tick += delegate
			{
				timer.Stop();
				using (var b = new Bitmap(form.Width, form.Height)) { form.DrawToBitmap(b, new Rectangle(0, 0, form.Width, form.Height)); b.Save(args[1]); }
				form.Close();
			};
			form.Shown += delegate { timer.Start(); };
		}
		Application.Run(form);
	}

	// A newer release on GitHub: the tag of the latest release, like "v1.6.0-release", against Version.
	// Only the numbers are compared; the whole name is what the window shows.
	static void CheckUpdate(LinkLabel link)
	{
		try
		{
			ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072;
			string json;
			using (var w = new WebClient())
			{
				w.Headers.Add("User-Agent", "GU-WOW-installer");
				w.Encoding = Encoding.UTF8;
				json = w.DownloadString(ReleasesApi);
			}
			var m = Regex.Match(json, "\"tag_name\"\\s*:\\s*\"v?(([0-9]+(?:\\.[0-9]+)*)[^\"]*)\"");
			var name = m.Groups[1].Value;
			var tag = m.Groups[2].Value;
			var page = Regex.Match(json, "\"html_url\"\\s*:\\s*\"([^\"]+/releases/tag/[^\"]+)\"").Groups[1].Value;
			Version have, got;
			if (!System.Version.TryParse(Regex.Match(Version, "^[0-9]+(?:\\.[0-9]+)*").Value, out have) || !System.Version.TryParse(tag, out got) || got <= have || page.Length == 0)
				return;
			form.BeginInvoke((Action)(() =>
			{
				link.Text = "Новая сборка " + name + "\nNew build " + name;
				link.LinkClicked += delegate { Process.Start(page); };
				link.Visible = true;
			}));
		}
		catch { }
	}

	// ------------------------------------------------------------------ client detection

	class Client { public string Dir, Exe, Name, Api; public int Major, Minor, Patch; public bool X64; }

	static Client current;

	static string FindGame()
	{
		string[] rel = { @"Games\Tauri Launcher\Legion", @"Tauri Launcher\Legion", @"Games\World of Warcraft", @"World of Warcraft", @"Program Files (x86)\World of Warcraft\_retail_", @"Program Files (x86)\World of Warcraft\_classic_" };
		foreach (var drive in DriveInfo.GetDrives())
		{
			if (drive.DriveType != DriveType.Fixed) continue;
			foreach (var r in rel)
			{
				var d = Path.Combine(drive.Name, r);
				if (Directory.Exists(d) && Exes.Any(e => File.Exists(Path.Combine(d, e)))) return d;
			}
		}
		return null;
	}

	static void Detect()
	{
		current = Inspect(pathBox.Text.Trim());
		install.Enabled = remove.Enabled = current != null;
		found.Text = current == null ? "В этой папке нет Wow.exe или Wow-64.exe." :
			string.Format("Найдено: {0}, версия {1}.{2}.{3}, {4}, {5}.", current.Name, current.Major, current.Minor, current.Patch, current.X64 ? "64 бит" : "32 бит", current.Api == "dxgi" ? "DirectX 11" : "DirectX 9");
	}

	static Client Inspect(string dir)
	{
		if (dir.Length == 0 || !Directory.Exists(dir)) return null;
		var exe = Exes.Select(e => Path.Combine(dir, e)).FirstOrDefault(File.Exists);
		if (exe == null) return null;
		var c = new Client { Dir = dir, Exe = exe, X64 = IsX64(exe) };
		var v = FileVersionInfo.GetVersionInfo(exe);
		c.Major = v.FileMajorPart; c.Minor = v.FileMinorPart; c.Patch = v.FileBuildPart;
		string[] names = { "Classic", "Classic", "The Burning Crusade", "Wrath of the Lich King", "Cataclysm", "Mists of Pandaria", "Warlords of Draenor", "Legion", "Battle for Azeroth", "Shadowlands" };
		c.Name = c.Major >= 0 && c.Major < names.Length ? names[c.Major] : "современный клиент";
		var api = ConfigValue(dir, "gxApi").ToLowerInvariant();
		c.Api = api.Contains("11") || api.Contains("12") ? "dxgi" : api.Contains("9") ? "d3d9" : (c.Major >= 5 && c.X64) || c.Major >= 6 ? "dxgi" : "d3d9";
		return c;
	}

	static bool IsX64(string exe)
	{
		using (var f = File.OpenRead(exe))
		using (var r = new BinaryReader(f))
		{
			f.Position = 0x3C;
			f.Position = r.ReadInt32() + 4;
			return r.ReadUInt16() == 0x8664;
		}
	}

	static bool Legion { get { return current.Major == 7 && current.X64 && current.Api == "dxgi"; } }

	// ------------------------------------------------------------------ jobs

	static void RunJob(Action job)
	{
		install.Enabled = remove.Enabled = false;
		log.Clear();
		new Thread(() =>
		{
			try { job(); }
			catch (Exception e) { Say("Ошибка: " + e.Message); }
			form.BeginInvoke((Action)(() => { install.Enabled = remove.Enabled = true; }));
		}) { IsBackground = true }.Start();
	}

	static void Say(string s)
	{
		if (cliLog != null) { File.AppendAllText(cliLog, s + Environment.NewLine); return; }
		form.BeginInvoke((Action)(() => log.AppendText(s + Environment.NewLine)));
	}

	static string G(string rel) { return Path.Combine(current.Dir, rel); }

	static void Install()
	{
		if (Process.GetProcessesByName(Path.GetFileNameWithoutExtension(current.Exe)).Length > 0)
		{
			Say("Закройте игру и нажмите «Установить» ещё раз.");
			return;
		}
		// An update over an earlier GU-WOW: the player's own choices in ReShade.ini stay.
		bool updating = File.Exists(G(Marker));
		var marker = ReadMarker();
		string dll = current.Api + ".dll";

		// 1. ReShade with add-on support, unless it is already there.
		if (IsReShade(G("dxgi.dll")) || IsReShade(G("d3d9.dll")))
			Say("ReShade уже установлен, оставляю его.");
		else
		{
			Say("Скачиваю ReShade с reshade.me…");
			var setup = Path.Combine(Path.GetTempPath(), "ReShade_Setup_6.8.0_Addon.exe");
			var local = Path.Combine(Path.GetDirectoryName(Application.ExecutablePath), "ReShade_Setup_6.8.0_Addon.exe");
			if (File.Exists(local)) File.Copy(local, setup, true);
			else
			{
				ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072;
				using (var w = new WebClient()) w.DownloadFile(ReShadeUrl, setup);
			}
			if (Sha256(setup) != ReShadeSha256) { Say("Файл ReShade не совпал с проверенным, установка остановлена."); return; }
			Say("Устанавливаю ReShade…");
			var p = Process.Start(new ProcessStartInfo(setup, "\"" + current.Exe + "\" --api " + current.Api + " --headless") { UseShellExecute = false, CreateNoWindow = true });
			p.WaitForExit();
			if (p.ExitCode != 0 || !IsReShade(G(dll))) { Say("ReShade не установился (код " + p.ExitCode + ")."); return; }
			marker["reshade"] = dll;
		}

		// 2. Effects, textures, the in-game panel.
		foreach (var name in Assembly.GetExecutingAssembly().GetManifestResourceNames())
		{
			if (!name.StartsWith("p~")) continue;
			var rel = name.Substring(2).Replace('~', '\\');
			if (rel.StartsWith(@"Interface\") && current.Major < 3) continue;
			if (rel.StartsWith("ReshadeEffectShader") || rel == Preset) continue;
			Directory.CreateDirectory(Path.GetDirectoryName(G(rel)));
			File.WriteAllBytes(G(rel), Resource(name));
		}
		if (current.Major >= 3)
		{
			int iface = current.Major * 10000 + current.Minor * 100 + (current.Major >= 10 ? current.Patch : 0);
			var toc = Encoding.UTF8.GetString(Resource("toc")).Replace("70300", iface.ToString());
			File.WriteAllText(G(@"Interface\AddOns\LegionGU\LegionGU.toc"), toc, new UTF8Encoding(false));
			Say("Меню в игре: Интерфейс > Модификации > GU-WOW, или команда /gu.");
		}
		else Say("Меню в игре для этого клиента не ставится: настройки в окне ReShade (Scroll Lock).");
		MergePreset();
		Say("Эффекты и пресет на месте.");

		// 3. REST: the effects go under the interface. Its ini carries the Legion 7.3.5 interface shader.
		if (Legion)
		{
			File.WriteAllBytes(G("ReshadeEffectShaderToggler.addon64"), Resource("p~ReshadeEffectShaderToggler.addon64"));
			var ini = G("ReshadeEffectShaderToggler.ini");
			if (!File.Exists(ini)) File.WriteAllBytes(ini, Resource("p~ReshadeEffectShaderToggler.ini"));
			else
			{
				var t = File.ReadAllText(ini).Replace("TechniqueExceptions=False", "TechniqueExceptions=True");
				// REST knows a technique by its name and file, "LegionGUBridge [LegionGUbylevan.fx]"; the first 1.3 build wrote the name alone.
				const string bridge = "Techniques=LegionGUBridge [LegionGUbylevan.fx],LegionGUBridge";
				t = Regex.Replace(t, @"^Techniques=LegionGUBridge(?=\r?$)", bridge, RegexOptions.Multiline);
				if (!Regex.IsMatch(t, @"^Techniques=", RegexOptions.Multiline)) t = Regex.Replace(t, @"^\[Group0\]\r?\n", "[Group0]\r\n" + bridge + "\r\n", RegexOptions.Multiline);
				File.WriteAllText(ini, t);
			}
			marker["rest"] = "1";
			Say("Интерфейс остаётся чистым: туман и солнце его не трогают.");
		}
		else Say("Для этого клиента туман ложится и на интерфейс: чистый интерфейс пока есть только для Legion 7.3.5.");

		// 4. ReShade.ini: paths, the preset, the keys, the depth buffer.
		var rs = G("ReShade.ini");
		IniSet(rs, "GENERAL", "EffectSearchPaths", @".\reshade-shaders\Shaders\**", true);
		IniSet(rs, "GENERAL", "TextureSearchPaths", @".\reshade-shaders\Textures\**", true);
		IniSet(rs, "GENERAL", "PresetPath", @".\" + Preset, true);
		// The keys only on the first install. ReShade leaves them unset (0,0,0,0) there; on an update the same value
		// means the player cleared the key on purpose.
		if (!updating)
		{
			IniSet(rs, "INPUT", "KeyOverlay", OverlayKey, false);
			IniSet(rs, "INPUT", "KeyEffects", "122,0,0,0", false);
		}
		IniSet(rs, "OVERLAY", "TutorialProgress", "4", true);
		// Home (1.2) and the bare Scroll Lock (1.3 to 1.5.3) were GU-WOW's own keys: with the 1 px font the ReShade
		// window opens unreadable and holds the mouse, so a stray key press must not open it. Ctrl + Scroll Lock now.
		var overlay = IniGet(rs, "INPUT", "KeyOverlay");
		if (overlay == "36,0,0,0" || overlay == "145,0,0,0") IniSet(rs, "INPUT", "KeyOverlay", OverlayKey, true);
		// The ReShade banner at the game start. ReShade shows it while the effects compile and 5 s after, always opaque;
		// its height is fixed paddings plus three lines of text. With the default font size 13 it also scales the font
		// by the screen height, 1.5 at 1440 lines and 2 at 4K. A 1 px font (8 at scale 0.125, ImGui draws no smaller)
		// leaves a thin empty strip, about 37 px. The OSD (FPS, clock) keeps ReShade's default size through FPSScale:
		// its text is FontSize x FPSScale x FontScale. The compiled effects kept in the game folder, not in Temp that
		// disk cleaners wipe, keep the compile to a second, so the banner stays about 5 s. A font size or a cache
		// folder the player chose stays as it is; the 10 px of 1.5.2 is ours.
		var fontSize = IniGet(rs, "STYLE", "FontSize");
		bool ours152 = fontSize != null && fontSize.StartsWith("10") && (IniGet(rs, "STYLE", "FontScale") ?? "").StartsWith("1.0");
		if (string.IsNullOrEmpty(fontSize) || fontSize.StartsWith("13") || ours152)
		{
			int h = WindowSize().Height;
			double auto = h >= 2160 ? 2.0 : h >= 1440 ? 1.5 : 1.0;
			IniSet(rs, "STYLE", "FontSize", "8.000000", true);
			IniSet(rs, "STYLE", "FontScale", "0.125000", true);
			var osd = IniGet(rs, "STYLE", "FPSScale");
			if (string.IsNullOrEmpty(osd) || osd.StartsWith("1.0"))
				IniSet(rs, "STYLE", "FPSScale", (13 * auto).ToString("0.000000", System.Globalization.CultureInfo.InvariantCulture), true);
		}
		const string cache = @".\reshade-shaders\Cache";
		var cachePath = IniGet(rs, "GENERAL", "IntermediateCachePath");
		if (string.IsNullOrEmpty(cachePath) || cachePath.IndexOf(@"\Temp\", StringComparison.OrdinalIgnoreCase) >= 0)
			IniSet(rs, "GENERAL", "IntermediateCachePath", cache, true);
		if (IniGet(rs, "GENERAL", "IntermediateCachePath") == cache)
			Directory.CreateDirectory(G(@"reshade-shaders\Cache"));
		Say("Надпись ReShade при запуске игры сжата до тонкой полосы, собранные эффекты хранятся в папке игры.");
		// Without the addon there is no signal from the game world: the effects must not wait for it.
		if (current.Major < 3)
		{
			var defs = IniGet(rs, "GENERAL", "PreprocessorDefinitions") ?? "";
			if (!defs.Contains("LEGIONGU_NEED_PANEL"))
				IniSet(rs, "GENERAL", "PreprocessorDefinitions", (defs.Length > 0 ? defs + "," : "") + "LEGIONGU_NEED_PANEL=0", true);
		}
		if (Legion)
		{
			var size = RenderSize();
			IniSet(rs, "DEPTH", "UseAspectRatioHeuristics", "4", true);
			IniSet(rs, "DEPTH", "FilterResolutionWidth", size.Width.ToString(), true);
			IniSet(rs, "DEPTH", "FilterResolutionHeight", size.Height.ToString(), true);
			IniSet(rs, "DEPTH", "DepthCopyBeforeClears", "0", true);
			Say("Буфер глубины: " + size.Width + "x" + size.Height + ". Если поменяете разрешение или масштаб отрисовки, запустите GU-WOW снова.");
		}

		// 5. Config.wtf: MSAA off, the effects need the depth buffer.
		var cfg = G(@"WTF\Config.wtf");
		if (File.Exists(cfg))
		{
			if (!File.Exists(cfg + ".wowgu-backup")) File.Copy(cfg, cfg + ".wowgu-backup");
			if (current.Major >= 6) ConfigSet(cfg, "MSAAQuality", "0"); else ConfigSet(cfg, "gxMultisample", "1");
			Say("Сглаживание MSAA выключено, копия настроек: WTF\\Config.wtf.wowgu-backup.");
		}
		WriteMarker(marker);
		Say("");
		// Only the keys the player really has.
		var done = "Готово. Запустите игру.";
		if (IniGet(rs, "INPUT", "KeyEffects") == "122,0,0,0") done += " F11 включает и выключает весь мод.";
		if (IniGet(rs, "INPUT", "KeyOverlay") == OverlayKey) done += " Ctrl + Scroll Lock открывает окно ReShade.";
		Say(done);
	}

	static void Uninstall()
	{
		var marker = ReadMarker();
		foreach (var f in new[] { @"reshade-shaders\Shaders\LegionGUbylevan.fx", @"reshade-shaders\Shaders\LegionGUNightsbylevan.fx", @"reshade-shaders\Textures\LegionGUMask.png", Preset })
			if (File.Exists(G(f))) File.Delete(G(f));
		if (Directory.Exists(G(@"Interface\AddOns\LegionGU"))) Directory.Delete(G(@"Interface\AddOns\LegionGU"), true);
		// The effect cache is always GU-WOW's; a ReShade that stays falls back to Temp without it.
		if (Directory.Exists(G(@"reshade-shaders\Cache"))) Directory.Delete(G(@"reshade-shaders\Cache"), true);
		if (marker.ContainsKey("rest"))
			foreach (var f in new[] { "ReshadeEffectShaderToggler.addon64", "ReshadeEffectShaderToggler.ini" })
				if (File.Exists(G(f))) File.Delete(G(f));
		string dll;
		if (marker.TryGetValue("reshade", out dll))
		{
			foreach (var f in new[] { dll, "ReShade.ini", "ReShade.log", "ReShadePreset.ini" })
				if (File.Exists(G(f)) && (f != dll || IsReShade(G(f)))) File.Delete(G(f));
			foreach (var d in new[] { @"reshade-shaders\Shaders", @"reshade-shaders\Textures", "reshade-shaders" })
				if (Directory.Exists(G(d)) && !Directory.EnumerateFileSystemEntries(G(d)).Any()) Directory.Delete(G(d));
			Say("ReShade удалён.");
		}
		else Say("ReShade ставили не через GU-WOW, он остаётся.");
		var cfg = G(@"WTF\Config.wtf");
		if (File.Exists(cfg + ".wowgu-backup"))
		{
			foreach (var key in new[] { "MSAAQuality", "gxMultisample" })
			{
				var old = ConfigValue(Path.GetDirectoryName(cfg + ".wowgu-backup"), key, Path.GetFileName(cfg + ".wowgu-backup"));
				if (old.Length > 0) ConfigSet(cfg, key, old); else ConfigRemove(cfg, key);
			}
			Say("Сглаживание вернулось как было.");
		}
		if (File.Exists(G(Marker))) File.Delete(G(Marker));
		Say("GU-WOW удалён.");
	}

	// ------------------------------------------------------------------ helpers

	static byte[] Resource(string name)
	{
		using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
		using (var m = new MemoryStream()) { s.CopyTo(m); return m.ToArray(); }
	}

	static bool IsReShade(string path)
	{
		return File.Exists(path) && (FileVersionInfo.GetVersionInfo(path).ProductName ?? "").Contains("ReShade");
	}

	static string Sha256(string path)
	{
		using (var h = SHA256.Create()) using (var f = File.OpenRead(path))
			return string.Concat(h.ComputeHash(f).Select(b => b.ToString("x2")));
	}

	static Dictionary<string, string> ReadMarker()
	{
		var d = new Dictionary<string, string>();
		if (File.Exists(G(Marker)))
			foreach (var line in File.ReadAllLines(G(Marker)))
			{
				int i = line.IndexOf('=');
				if (i > 0) d[line.Substring(0, i)] = line.Substring(i + 1);
			}
		return d;
	}

	static void WriteMarker(Dictionary<string, string> d)
	{
		File.WriteAllLines(G(Marker), new[] { "# Установлено GU-WOW. Нужен для удаления." }.Concat(d.Select(p => p.Key + "=" + p.Value)));
	}

	// The preset: a fresh copy, or the new techniques and settings added to the player's own values.
	static void MergePreset()
	{
		var fresh = Encoding.UTF8.GetString(Resource("p~" + Preset)).Replace("\r\n", "\n").TrimEnd('\n') + "\n";
		var path = G(Preset);
		if (!File.Exists(path)) { File.WriteAllText(path, fresh.Replace("\n", "\r\n")); return; }
		var mine = File.ReadAllText(path).Replace("\r\n", "\n").TrimEnd('\n') + "\n";
		foreach (var key in new[] { "Techniques", "TechniqueSorting" })
		{
			var m = Regex.Match(fresh, "^" + key + "=.*$", RegexOptions.Multiline);
			mine = Regex.IsMatch(mine, "^" + key + "=", RegexOptions.Multiline) ? Regex.Replace(mine, "^" + key + "=.*$", m.Value, RegexOptions.Multiline) : m.Value + "\n" + mine;
		}
		foreach (Match sec in Regex.Matches(fresh, @"^\[([^\]]+)\]\n((?:(?!\[)[^\n]*\n)*)", RegexOptions.Multiline))
			foreach (Match kv in Regex.Matches(sec.Groups[2].Value, @"^([^=\n]+)=(.*)$", RegexOptions.Multiline))
				if (IniGetText(mine, sec.Groups[1].Value, kv.Groups[1].Value) == null)
					mine = IniSetText(mine, sec.Groups[1].Value, kv.Groups[1].Value, kv.Groups[2].Value);
		File.WriteAllText(path, mine.Replace("\n", "\r\n"));
	}

	static string IniGetText(string text, string section, string key)
	{
		var sec = Regex.Match(text, @"^\[" + Regex.Escape(section) + @"\]\n((?:(?!\[)[^\n]*\n)*)", RegexOptions.Multiline);
		if (!sec.Success) return null;
		var kv = Regex.Match(sec.Groups[1].Value, "^" + Regex.Escape(key) + "=(.*)$", RegexOptions.Multiline);
		return kv.Success ? kv.Groups[1].Value : null;
	}

	static string IniSetText(string text, string section, string key, string value)
	{
		var sec = Regex.Match(text, @"^\[" + Regex.Escape(section) + @"\]\n((?:(?!\[)[^\n]*\n)*)", RegexOptions.Multiline);
		if (!sec.Success) return text.TrimEnd('\n') + "\n\n[" + section + "]\n" + key + "=" + value + "\n";
		var body = sec.Groups[1].Value;
		var line = new Regex("^" + Regex.Escape(key) + "=.*$", RegexOptions.Multiline);
		body = line.IsMatch(body) ? line.Replace(body, key + "=" + value, 1) : key + "=" + value + "\n" + body;
		return text.Substring(0, sec.Groups[1].Index) + body + text.Substring(sec.Groups[1].Index + sec.Groups[1].Length);
	}

	static string IniGet(string path, string section, string key)
	{
		return File.Exists(path) ? IniGetText(File.ReadAllText(path).Replace("\r\n", "\n"), section, key) : null;
	}

	// Sets a key; with force false only when it is missing or empty.
	static void IniSet(string path, string section, string key, string value, bool force)
	{
		var text = File.Exists(path) ? File.ReadAllText(path).Replace("\r\n", "\n").TrimEnd('\n') + "\n" : "";
		var old = IniGetText(text, section, key);
		if (!force && !string.IsNullOrEmpty(old) && old != "0,0,0,0") return;
		File.WriteAllText(path, IniSetText(text, section, key, value).Replace("\n", "\r\n"));
	}

	static string ConfigValue(string dir, string key, string file = null)
	{
		var path = file == null ? Path.Combine(dir, @"WTF\Config.wtf") : Path.Combine(dir, file);
		if (!File.Exists(path)) return "";
		var m = Regex.Match(File.ReadAllText(path), "^SET " + key + " \"([^\"]*)\"", RegexOptions.Multiline | RegexOptions.IgnoreCase);
		return m.Success ? m.Groups[1].Value : "";
	}

	static void ConfigSet(string path, string key, string value)
	{
		var text = File.ReadAllText(path);
		var line = "SET " + key + " \"" + value + "\"";
		var re = new Regex("^SET " + key + " \"[^\"]*\"", RegexOptions.Multiline | RegexOptions.IgnoreCase);
		File.WriteAllText(path, re.IsMatch(text) ? re.Replace(text, line, 1) : text.TrimEnd('\r', '\n') + "\r\n" + line + "\r\n");
	}

	static void ConfigRemove(string path, string key)
	{
		File.WriteAllText(path, Regex.Replace(File.ReadAllText(path), "^SET " + key + " \"[^\"]*\"\r?\n?", "", RegexOptions.Multiline | RegexOptions.IgnoreCase));
	}

	// The size the world is drawn at: the window (the screen when maximized) times the render scale.
	// The game window as Config.wtf sets it, the screen when the window is maximized.
	static Size WindowSize()
	{
		var size = Screen.PrimaryScreen.Bounds.Size;
		bool windowed = ConfigValue(current.Dir, "gxWindow") != "0";
		bool maximized = ConfigValue(current.Dir, "gxMaximize") == "1";
		var res = ConfigValue(current.Dir, windowed ? "gxWindowedResolution" : "gxFullscreenResolution");
		var m = Regex.Match(res, @"(\d+)x(\d+)");
		if (m.Success && !(windowed && maximized)) size = new Size(int.Parse(m.Groups[1].Value), int.Parse(m.Groups[2].Value));
		return size;
	}

	static Size RenderSize()
	{
		var size = WindowSize();
		double scale;
		if (!double.TryParse(ConfigValue(current.Dir, "RenderScale"), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out scale) || scale <= 0) scale = 1.0;
		return new Size((int)Math.Round(size.Width * scale), (int)Math.Round(size.Height * scale));
	}
}
