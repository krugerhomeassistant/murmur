@echo off
rem Imports the project (first run only needs it) and starts the game.
rem Uses %GODOT% if set (full path to the Godot 4.7 exe), else "godot" from PATH.
set "G=%GODOT%"
if not defined G set "G=godot"
"%G%" --headless --path "%~dp0client" --import --quit
start "" "%G%" --path "%~dp0client"
