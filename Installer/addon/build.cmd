@echo off
rem Builds GU-WOW.addon32 into ..\payload with the 32-bit tools of Visual Studio 2022.
rem The first argument is the include folder of ReShade 6.8.0 (https://github.com/crosire/reshade, folder include).
if "%~1"=="" (echo Usage: build.cmd ^<ReShade include folder^> & exit /b 1)
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" amd64_x86 >nul
cd /d "%~dp0"
cl /nologo /std:c++17 /EHsc /O2 /MT /LD /I"%~1" GU-WOW.cpp /Fe:..\payload\GU-WOW.addon32 /Fo:%TEMP%\ /link d3d9.lib /IMPLIB:%TEMP%\GU-WOW.lib
