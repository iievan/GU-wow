# Builds GU-WOW.exe with the csc.exe that ships with Windows (.NET Framework 4.x). The payload goes in as resources.
# "build.sh lite" builds GU-WOW-Lite.exe: the same payload, the installer switches LEGIONGU_LITE on.
R="$(cd "$(dirname "$0")/.." && pwd -W)"
export MSYS2_ARG_CONV_EXCL="*" MSYS_NO_PATHCONV=1
OUT=GU-WOW.exe DEF=
[ "$1" = lite ] && OUT=GU-WOW-Lite.exe DEF=/define:LITE
/c/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe /nologo /target:winexe /optimize+ /platform:anycpu /out:$OUT $DEF \
 /r:System.Windows.Forms.dll /r:System.Drawing.dll \
 "/resource:$R/Shaders/LegionGUbylevan.fx,p~reshade-shaders~Shaders~LegionGUbylevan.fx" \
 "/resource:$R/Shaders/LegionGUNightsbylevan.fx,p~reshade-shaders~Shaders~LegionGUNightsbylevan.fx" \
 "/resource:$R/Textures/LegionGUMask.png,p~reshade-shaders~Textures~LegionGUMask.png" \
 "/resource:$R/LegionGUbylevan.ini,p~LegionGUbylevan.ini" \
 "/resource:$R/AddOn/LegionGU/LegionGU.lua,p~Interface~AddOns~LegionGU~LegionGU.lua" \
 "/resource:$R/AddOn/LegionGU/LegionGU.toc,toc" \
 "/resource:$R/AddOn/LegionGU/Bindings.xml,p~Interface~AddOns~LegionGU~Bindings.xml" \
 "/resource:$R/AddOn/LegionGU-Classic/LegionGU.lua,c~Interface~AddOns~LegionGU~LegionGU.lua" \
 "/resource:$R/AddOn/LegionGU-Classic/LegionGU.toc,c~Interface~AddOns~LegionGU~LegionGU.toc" \
 "/resource:$R/Installer/payload/ReshadeEffectShaderToggler.addon64,p~ReshadeEffectShaderToggler.addon64" \
 "/resource:$R/Installer/payload/ReshadeEffectShaderToggler.ini,p~ReshadeEffectShaderToggler.ini" \
 "/resource:$R/Installer/payload/GU-WOW.addon32,a~GU-WOW.addon32" \
 wowGU.cs
