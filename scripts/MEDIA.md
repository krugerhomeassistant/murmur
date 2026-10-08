# Retaking README media

The shots come from a hand-built dense town, because planner towns stall near 100 pop.

1. Run the game from the editor (godot-ai `project_run`), then in `game_eval`: `load("res://tests/showcase.gd").stage(get_tree().current_scene)`. It builds the town, utilities and residents, locks mood and summer. Wait about 8 s.
2. Add the director: a `Node` with `tests/reel.gd` as its script, `m` = the Main node, `out` = an absolute frame folder, child of Main. It flies the camera for 20 s and writes numbered PNGs (about 15 fps in practice).
3. Encode (ffmpeg). GIF for the README (about 7 MB):
   `ffmpeg -framerate 15 -i f%04d.png -vf "fps=10,scale=560:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=48:stats_mode=full[p];[b][p]paletteuse=dither=none" docs/media/murmur.gif`
   MP4 for sharing (not committed): `ffmpeg -framerate 15 -i f%04d.png -c:v libx264 -pix_fmt yuv420p -crf 19 -preset slow -movflags +faststart murmur.mp4`
4. Stills: `ffmpeg -i f0230.png -vf scale=1280:-1 docs/media/town.png` (pick frames by eye from a contact sheet: `-vf "select='not(mod(n,25))',scale=426:-1,tile=3x4"`).
