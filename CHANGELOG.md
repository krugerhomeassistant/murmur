# Changelog

All notable changes to Murmur are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Arms supply chain: new good Arms and Armoury building (metal to arms). Training units costs coins plus arms; a town uses its own stock first and buys the rest from the market, so war moves ore, metal and arms prices. Planner builds armouries. `tests/arms.gd`.
- Local prices and trade between towns: every town prices each good by its own scarcity (cheap ore in a mining town, dear food in a hungry one, always between selling abroad at 80% and buying abroad at 120% of the world price), households pay local prices, and towns joined by a road to their shared border trade goods when the price gap pays the freight. Embargo and war stop it. The Market window shows World and Here prices and goods moved by link.
- Household finances: every citizen has savings. Wages (by workplace and education), rent and the market price of food and goods flow through each household every second; a home upgrades only when its residents can pay; prices rise in a supply crisis while wages lag, so poor households run out of money, mood and crime worsen, and a town with over half its households broke riots. New policy Cost-of-living payments, new events Supply crisis and Price slump, household statistics in the Economy tab. `tests/households.gd`.
- A real goods market: crops, food, goods, ore and metal each have their own world price set by every town's offers and needs (price = base x (wanted / offered) ^ 0.6, between 0.35x and 3x, smoothed). Towns hold back cheap goods and push out dear ones, and mills, foundries and factories can buy missing inputs from the market's limited supply, so a chain across towns pays. New Market window (Windows > Market) with price history, offered and wanted per second and your town's position. `tests/market.gd`.
- The wiki (`docs/wiki/`): reference pages for every building, stat, policy, event, unit, season, tribe, petition and milestone generated from the game data (`scripts/gen_wiki.py`, CI fails when stale), plus hand-written mechanics pages (economy, citizens, networks, planner AI, mayor and events, diplomacy and war, world, empire, multiplayer, controls and settings). Replaces `docs/WIKI.md`.
- Pop-out windows: every HUD window has an "Out" button that moves it into its own OS window (drag it to another monitor). Closing that window docks it back; hotkeys still work in it; positions are remembered between sessions. `tests/popout.gd`.
- Empire window (Windows > Empire (all towns); opens by itself when spectating): every town's population, coins, net income, mood and alerts at a glance (sortable, "Go" to visit), empire totals, one-click settings for all your towns (auto-growth, policies, annexing, troop training, tax rates), "+$100" gifts between your towns and "Balance treasuries". New validated commands `send`, `balance` and `apply_all` (multiplayer-safe: they only touch towns of the same owner). `tests/empire.gd`.
- `World` (`scripts/world.gd`): deterministic endless terrain generator (sea, rivers, sand, plains, forest, hills, rock, ore) for the upcoming endless map; `tests/world.gd`. Not used by towns yet.
- Founding a town is a map action: Towns menu > Found a new town, then click any free plot (green = affordable, red = blocked or too dear; Esc cancels). The price is $300 plus $120 per plot of distance from the nearest town, and plots with too much water are refused. Not available in multiplayer yet.
- The land between and around the towns is drawn from the endless world (rivers, lakes, coast, forest, hills, rock, ore), generated a few milliseconds per frame near the camera, and the camera may roam 10 plots past the outermost town (it was clamped to the towns).

### Fixed
- Empire window column sorting was shifted by one column; founded towns now use the game's difficulty and stay planner-run while spectating; a dedicated server takes 8 clients; joining players draw the host's world between towns; WASD no longer pans the camera while typing; the benchmark (F9) no longer deletes your save; `leave` can no longer end a war for free; minimized windows come back minimized; the Declare WAR tooltip describes real fights.
- Planner stall: a tiny low-mood town no longer sits under the zoning mood gate forever; it now builds a service to lift mood first and small towns (pop < 40) use a lower gate (0 stalls in 96 fresh towns, was about 5%).
- Planner towns could never link a border: the border road was laid as a straight line and gave up for good at the first building in the way (`tests/spectate.gd` failed about 1 run in 4). It now finds a route around buildings, preferring dry land.

### Changed
- Rivers of the endless world rise at the foot of the hills instead of crossing mountains, and are smoother; your starting town is always placed with some water nearby.
- New games are cut from the shared procedural world: rivers, lakes, coast, sand, forest, hills, rock and ore now continue across neighbouring towns, and a start-site search keeps every starting town on dry land. The Rivers setup option is now Natural / None / Custom. The world seed is saved; older saves keep their terrain.
- Docs: README roadmap and docs index brought up to date; `scripts/check_repo.py` now fails when a `docs/*.md` file is missing from the docs index.
- War rework, phase 1 (docs/WAR_DESIGN.md): units at war have real map positions, march through the terrain on flow fields, and fight in 2D. Ground units cannot enter rivers (a road bridge opens the way), ships stay on river water, aircraft fly straight; armies advance on the enemy town and fight there instead of on a line between the towns. New `tests/warmap.gd`.

## [0.2.0] - 2026-10-08

### Changed
- Planner towns keep tax at 10% or more; `--watch` benchmark flag follows the action; cheaper coverage and shop-distance lookups in the per-second sim.

### Security
- Multiplayer hardening from the audit: NaN/INF numbers are refused (a NaN tax gave unlimited money and poisoned every client), per-peer command and chat rate limits, silent connections are dropped after 5 s, chat lines and names lose control characters, "Server" is reserved, `water` respects territory, snapshots accept only known keys and at most 4 MB.

### Fixed
- Planner (AI) towns stalled near 70 pop because they never touched taxes while upkeep grows with size; they now raise the residential rate while poor and ease it when unhappy (average pop at 4000 sim-s: 74 before, 107 to 220 after; `tests/growth.gd`).
- Rivers meet at town borders: outside its own territory a river now runs straight at the border height instead of drifting, so neighbouring towns no longer show a gap (new worlds only).
- Attackers standing unopposed at an enemy's edge visibly shell its buildings.
- Raid and bomb explosions were drawn in the top-left corner of the map instead of on the destroyed building (cell units were used as pixels); `tests/war.gd` now checks the position.
- Cars keep to the right-hand lane and pedestrians use the pavements, so traffic no longer piles up on the road centreline.

### Changed
- CI jobs have time limits, run with pipefail, and the smoke step has its own timeout.
- Docs brought back in line with the code (controls, file names, test lists, save path) after the audit; follow-ups are listed in docs/PLAN.md.
- Town growth no longer re-floods the utility networks: only demand is recomputed, about 10x cheaper per growth step (`tests/netbench.gd`).
- Benchmark: `-- --benchmark --war` runs the standard scenario with four wars going.
- CI: multiplayer tests run as their own parallel job.
- GDScript lint (gdtoolkit) in CI; style-only rules (line length, naming, ordering) are switched off in client/gdlintrc.
- Dedicated server options (`--towns`, `--speed`) with join/leave/chat logging; multiplayer run instructions.
- Multiplayer chat (Enter) and rejoin: a returning player gets their old town back.
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
