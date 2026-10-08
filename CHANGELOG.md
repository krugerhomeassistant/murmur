# Changelog

All notable changes to Murmur are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Multiplayer: treaties, ceasefires and tribute between two players are proposals the other player answers; planner towns still answer instantly.
- Multiplayer playable in the game: lobby (host or join by address), `--server` dedicated mode, client mirror world, networked games never overwrite the single-player save.
- Multiplayer phase 3a: town snapshot sync and owner-checked commands between a host and clients (test: two processes).
- README screenshots and a hero GIF (docs/media), captured from the game.
- `--capture DIR` saves the window as PNG frames for README media.
- Player actions all go through one validated command path (`Cmd`), groundwork for multiplayer; no gameplay change.
- Multiplayer phase 0: `--server`/`--join` flags, lobby player table with ping, two-process test.
- Multiplayer design doc (docs/MULTIPLAYER.md): host-authoritative, competitive towns, 2-8 players, LAN/direct IP and dedicated server.
- Release process documented end to end (docs/RELEASING.md); performance pass is the last step before every release.
- Perf: land value recompute splats coverage and pollution fields once per pass (headless 8-town profile: land stage 5.0 s to 2.5 s over 30000 steps, worst step 19 to 14 ms).
- World view: all towns live in one continuous, pannable map (replaces the separate region map and town switching). The viewed town is the one under the camera; far zoom shows live per-town thumbnails and names; M fits the whole world.
- Border links need a road that belongs to the town's biggest connected road network; planner towns lay it themselves (previously planner towns were always counted as linked).
- Performance: each town staggers its planner/crime/land cadence so periodic stages no longer coincide across towns (headless p99 step 9.8 to 8.5 ms; planner and land-value passes are still the largest single spikes).
- Performance: standard benchmark (8 towns, 8x, all overlays; F9 or `--benchmark`): 77 to 128 fps, p99 46.5 to 23.4 ms, slow frames 426 to 28. Per-frame sim budget, at most 2 off-screen town batches per step, unchanged cell/coverage scans skipped, growth zone list, net flood split from demand.
- Repo layout: living docs moved to `docs/`, added LICENSE (MIT), SECURITY, CODE_OF_CONDUCT, CLAUDE.md; launcher honours `GODOT` and PATH; README no longer claims unmeasured performance.
- README: measured performance table (hardware, fps, CPU/GPU ms, memory).
- Performance: utility-network solve is cached by layout signature (sim tick about 2x cheaper); off-screen towns tick in 0.5 s batches and refresh crime/land value every 3rd second; `place()`/`bulldoze()` defer the rescan to once per frame (2.8 ms to 2 us per tile); land-value pass hoists modifier lookups; sim catch-up per frame is capped.
- Rendering: the map is split into 16x16-tile chunks. Zoomed in they are baked to textures, mid zoom draws simple blocks, far zoom draws flat tiles (dense 96x64 test town: 7 fps to 300+ fps zoomed out, 26 to 66 fps at zoom 1.25).
- Rendering: chunk textures are allocated lazily (VRAM about 220 MB to 22 MB zoomed out), bake work uses a leaky time budget, painting only re-bakes the touched chunk.
- HUD updates skip no-op theme overrides and throttle the Build menu button refresh.

### Added
- Real armies (`client/scripts/military.gd`): barracks and bases train infantry, tanks and jets (radar allows jets) that cost coins and upkeep, deploy to the front at war, fight with hit points, range and damage, die in explosions, and decide the war: a wiped army plus a held border means surrender. Replaces the old dice-roll battles; war visuals now draw the real units (`tests/war.gd`). **T** toggles auto-training.
- Unit variety: 13 unit types (rifleman, grenadier, sniper, medic; light, battle and heavy tank, artillery, anti-air; strike jet, fighter, bomber, helicopter) with counters, veteran ranks (recruit to legend) and an Army window (Windows menu) with the roster and per-kind training priorities. Replaces the 3 fixed unit types.
- Warships: patrol boats, destroyers and transports from Naval yards fight where a river crosses the border between two towns at war. Bombers and raids now destroy the buildings nearest the attacker's border with visible blasts and smoke.
- AI armies: planner towns build barracks, bases, radar posts and (against river enemies) naval yards when a neighbour is hostile, and train the unit types that counter what the enemy fields.
- Farm variants: greenhouses (steady winter crops) and fish farms (waterside, food on the spot) join fields, orchards and ranches; planner towns now zone orchards, ranches, greenhouses and fish farms too (`tests/farms.gd`).
- Planner towns now mine: they lay a road to ore, zone mines beside it and build foundries for the ore (`tests/pmine.gd`).
- Orchards, ranches, greenhouses and fish farms each have their own building art.
- War visuals: towns at war show infantry, tanks (military bases) and aircraft (radar) on the front between them, a front line that the last battle's winner pushes forward, and blasts after each battle.
- Mining: ore deposits (dark flecks), Mine zone (deposits only), Foundry (ore to metal; metal boosts factory goods), ore/metal stock and exports; Orchard (+50% crops) and Ranch (food without a mill) farm variants (`tests/mining.gd`).
- Farm variants: Orchard (50% more crops) and Ranch (food without a mill).
- Spectator mode (setup checkbox): no mayor, every town runs on the planner, up to 8x speed; Tab switches town, F toggles 30 s auto-follow (`tests/spectate.gd`).
- Godot Claude Skills (MIT, alexmeckes/godot-claude-skills) installed under `.claude/skills/` for GDScript, scene, shader and live-edit guidance.
- README rewrite with feature table, run instructions, performance notes and repo map; issue templates.
- Shared rivers: new setup option (default) runs one river through the row or column of towns containing yours; neighbours agree where it crosses each border (`tests/rivers.gd`).
- Click a tile with the Inspect tool to pin its info card (live updating, click again to close).
- F3 overlay: fps, sim ms, draw ms, towns. `tests/bench*.gd`, `tests/region.gd` (8 towns), `tests/netcache.gd`, `tests/place.gd` for headless profiling.

### Fixed
- Map chunks prefetch half a chunk beyond the view so panning at full zoom never shows an unbaked tile.
- Top bar clock clipped ("Day 33 04:21 S") and the RCIO/utility strip overlapping the menu row.

## [0.1.0] - 2026-10-07

### Added
- Start menu with game setup (towns, neighbour temper, difficulty, land, auto-growth, rivers) and a new-player guide.
- Region of neighbouring towns on a grid with a region map; trade, commuters and utilities flow through border roads.
- Diplomacy and war: pacts, alliances, embargoes, battles with land capture, garrison and war weariness.
- Art pass: service buildings, grown zone buildings, Build menu icons, ground detail.
- Rivers (random or painted in the world editor), bridges, animated water with fish, ports, naval yards and ships, fishing docks, river health.
- Sewage network (plant and sewer pipes), always-visible demand and utility strip, map hover card.
