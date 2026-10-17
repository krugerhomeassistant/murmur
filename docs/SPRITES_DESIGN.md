# Sprite engine design

Goal: let art improve without rewriting code. Today every building is drawn in code (`client/scripts/art.gd`). The sprite engine lets a PNG replace any drawing, per age and per level, with the code drawing as the fallback.

## Built (S1)
- `Sprites` (`client/scripts/sprites.gd`): `Sprites.draw(ci, rect, id, level, age, ok)` returns false when there is no file, so `Art` draws as before. Lookup order: the town's age down to ancient, then `all/`; in each, `b<id>_<level>.png` then `b<id>.png`. Roots: `user://sprites` (mods, tests) before `res://art/sprites`. Results are cached, including misses.
- Hooks: `Main._building` and `Main._service` try a sprite before the procedural art. Services use level 1.
- `tools/bake_sprites.gd`: renders the 87 current building drawings (zones at levels 1 to 3, services) to PNG at 2x as templates, so a generator or artist starts from the right silhouette and palette. Needs a renderer (`xvfb-run`).
- `tests/sprites.gd` (in CI): file names, fallbacks, caching, misses.

## Not built yet
- S2: units, terrain, trees, water and roads as sprites (same lookup with another prefix); texture atlas to keep draw calls low; night-lit variant (lit windows as a second layer).
- S3: generation pipeline: prompt or Blender render per building and age in a consistent isometric-free top-down style, palette check, size and transparency validation script, then drop into `art/sprites/<age>/`.
- S4: per-age looks for the same building (a hut becoming a house), which needs the age content in `docs/AGES_DESIGN.md` A2.

## Decisions
- Animated art (smoke, turbines, boats) stays procedural until a frame-sheet format is chosen; a static sprite replaces the whole drawing, so do not replace animated buildings without that.
- Perf: sprites are drawn into the cached chunk canvases like the procedural art. Measure before the release pass.
