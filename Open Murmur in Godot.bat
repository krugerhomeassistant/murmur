@echo off
set GODOT_AI_DISABLE_TELEMETRY=true
set PATH=%USERPROFILE%\.local\bin;%PATH%
start "" "%USERPROFILE%\workspace\tools\godot\Godot_v4.7.2-stable_win64.exe" --editor --path "%~dp0client"
