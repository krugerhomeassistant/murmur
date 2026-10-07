@echo off
rem Opens the Murmur project in the Godot 4.7 editor.
rem Uses %GODOT% if set (full path to the Godot exe), else the Godot at the old default location, else "godot" from PATH.
set GODOT_AI_DISABLE_TELEMETRY=true
set "G=%GODOT%"
if not defined G if exist "%USERPROFILE%\workspace\tools\godot\Godot_v4.7.2-stable_win64.exe" set "G=%USERPROFILE%\workspace\tools\godot\Godot_v4.7.2-stable_win64.exe"
if not defined G set "G=godot"
start "" "%G%" --editor --path "%~dp0client"
