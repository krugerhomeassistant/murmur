# Retaking README media

1. Run the game in the editor (godot-ai `project_run`), start a spectator world and fast-forward it (see `tests/stageprof.gd` for the step loop).
2. Call `Main.capture("<abs dir>", 0.2)` (or launch with `-- --capture DIR --every 0.2`); it saves numbered PNG frames of the window. Free the Timer child of Main to stop.
3. Build the GIF (ffmpeg, 5 fps, 800 px, 128-colour palette):
   `ffmpeg -framerate 5 -i world/f%04d.png -vf "scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" docs/media/murmur.gif`
4. Stills: `ffmpeg -i frame.png -vf scale=1280:-1 docs/media/<name>.png`.
