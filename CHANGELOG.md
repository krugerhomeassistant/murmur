# Changelog

All notable changes to Murmur are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Globe view overlays (G4c): press O to cycle a colour ring (cool to hot) around each town disc by side, age, population, wealth or military. Checked on screen in the editor.

### Changed
- F3 performance panel: fps, average / p99 / worst frame time over the last 240 frames, sim and draw cost, draw calls, objects, nodes, memory, video memory, towns, population and speed, plus a frame-time bar graph (green under 16.7 ms, amber under 25, red above).
- Floating windows start minimised on a first launch and on every new game, leaving just the tutorial open.
- Open land has soft shading in patches instead of one flat green; drawn into the cached ground chunks, so it adds no per-frame cost.
- Globe view: the old town labels and shaded plots no longer draw underneath the town discs, discs have a minimum readable size, and lines join only towns that are at war or linked by road (the all-pairs lines were a hairball).
- The Windows build no longer ships the editor's debugging helper addon (it is excluded from the export and its autoload is removed in the build workflow).

## [0.7.0] - 2026-10-18

### Added
- Globe markers (G4c, first form): below zoom 0.06 each town is a disc (size by population, colour by relation to you: you, ally, war, vassal, pact, embargo) with its name, age and population under the mouse; the live thumbnails hide there. Clicking a disc flies to that town; lines join neighbouring towns (red at war, green with a road, grey without). Checked headless only, not yet on screen.
- Globe tier (G4b): zoomed out beyond the chunk view the land layer now draws coarse land and sea blocks (`World.coarse`, one sample per 8 tiles, about 2 ms per 128-tile block, same per-frame budget) instead of nothing. Checked headless only, not yet on screen.
- Globe data module (G4a): `Globe.markers` gives one marker per town (radius by population, side, overlay value for age, population, wealth and military), pure and fast (0.8 ms for 200 towns). No view yet. `tests/globe.gd` (in CI).
- God powers (G3 first form, sandbox games only): a belief pool that a happy town regenerates, and eight powers that spend it (bloom, boom, cure, lightning, earthquake, tornado, plague, famine), each reusing the matching event. Buttons in the Empire window. `Powers`, `tests/powers.gd` (in CI).
- Two more god powers: Bless (raises the town's mood) and Incite (raises border tension towards every neighbour, which can start a war). Sandbox games only.
- Sandbox option in the setup screen (G2 first piece): free money, instant troops and age jumps from the Empire window. Refused in normal games and in multiplayer. `tests/sandbox.gd` (in CI).
- World seed option in the setup screen (G1 first piece): a number gives the same world and town sites every time; empty is random. `tests/scenario.gd` (in CI).

### Changed
- New games start in the Ancient age by default (ages A2). Pick Modern in the setup screen for the classic start; saves keep their age.

### Added
- Ages A2, first piece: the Spearman, a cheap Ancient soldier trained at barracks, which are now an Ancient building. Riflemen still wait for the Industrial age. `tests/spear.gd` (in CI).
- Well: a cheap Ancient water source (6 units into the pipe network, cost $40), the first-age step below the water tower.

## [0.6.0] - 2026-10-18

### Added
- Groups (E3, first slice): a town can join a group (`group` command, saved). Towns in one group are allied automatically and cannot declare war on, embargo or cancel the treaty with each other. `Diplo.set_group`, `tests/group.gd` (in CI). Group members can send each other coins (aid). Declaring war on a group member brings the rest of its group into the war (`Diplo.defend`). The Empire window has a Group button to join or change group.

## [0.5.0] - 2026-10-18

## [0.5.0] - 2026-10-18

E6 military, first form: sieges, air defence and army orders.

### Added
- Army orders (E6 command UI, first slice): a stance for the whole army, set from the Army window or the `stance` command (works in multiplayer and is saved): advance marches on the enemy, hold stays home and fights what comes, retreat falls back home without chasing. `tests/stance.gd` (in CI).

### Changed
- Performance note: the changes are in the war code only (`_shell`, `_bomb`, the stance goal in `Military.fight`), which runs once per sim second per war and loops the army lists once more; the headless stage profile and the windowed benchmark were not re-run for this release (peacetime code is unchanged since v0.4.0, where the profile tracked town growth). The README table is still the v0.2.0 measurement.
- Bombing runs: any anti-air gun, fighter or jet used to stop them outright; now each guard slows the run to 1/(1 + 2 x guards) of its rate, so a defended town is hit more slowly instead of never. `tests/air.gd` (in CI).

### Added
- Sieges (E6, first slice): artillery, tanks and destroyers inside an enemy town with no defenders left there flatten its buildings (artillery 0.10 a second each, heavy tank 0.08, destroyer 0.08, battle tank 0.05, light tank 0.02). `tests/siege.gd` (in CI).

## [0.4.0] - 2026-10-18

## [0.4.0] - 2026-10-18

E5 infrastructure.

### Added
- Water tiers: reservoir (40 units, on the river, Industrial) and desalination plant (90 units, no river needed, Modern) above the water tower (14). `tests/power.gd` now covers water too.
- Fuel: a new good made by the Refinery (1 ore a second into 0.8 fuel). Coal plants burn 0.4 and gas plants 0.3 a second, and run at half output without it. Towns buy it from the market, and planner towns with mines and a fuel-burning plant build a refinery. `tests/fuel.gd`.
- Rail yard catchment: the freight discount and capacity boost scale with the share of farms, mines and factories within 14 tiles of a yard.
- Power tiers: hydro dam (55 units, on the river, Industrial age), gas plant (80 units, half the pollution of coal, Modern) and nuclear plant (200 units, clean, very costly, Modern), with `tests/power.gd`.

### Changed
- `scripts/release-tag.bat`: one double-click tags and pushes every release made since the last tag.
- Performance note: the headless 8-town stage profile per stage is within the growth in town size against v0.3.0 (about 1.2x total population, stages 1.05x to 1.25x); no stage regressed beyond that. The windowed benchmark was not re-run for this release; the README table is still the v0.2.0 measurement.
- Moving trains on laid track are deferred (E5e); the rail yard stands in for rail until then.

## [0.3.0] - 2026-10-18

### Added
- Release standard: every finished milestone is released (a minor release per roadmap milestone or about 40 commits, a patch per player-visible fix), with a fast path in `docs/RELEASING.md` and a rule in `CLAUDE.md`.
- Sea trade (E5c): two neighbouring towns that both have a port trade by sea even without a road (link strength 0.8), and a road link between two ports pays 30% less freight. Rail keeps its bigger discount. `tests/rail.gd` extended.
- Rail yard (E5b, first slice): a trade building from the Industrial age. When both towns of a trade link have one, freight costs 60% less and the link carries twice as much. Planner towns of 80 people with a neighbour build one. `tests/rail.gd` (in CI). The fuel good is dropped from E4 and folded into E5.
- Families (E4 household v2 part 2b): residents of one home share their savings (20% of the gap to the home average closes each second), so jobless members are carried by earning housemates. `tests/households.gd` extended.
- Infrastructure design: `docs/INFRASTRUCTURE_DESIGN.md` for E5 (rail, ports, power tiers), including which OpenTTD mechanics are adopted or skipped (ideas only, no code or assets). Design only.
- Household view (E4 household v2 part 2): hovering a home shows its residents' average savings and how many are broke. `tests/households.gd` checks the per-home totals.
- Maintenance and wear (E4 slice 3): road upkeep is split into upkeep and a Maintenance budget line (same total). While the treasury is empty, wear builds up to 1 in about 8 minutes, cutting production up to 20% and mood by up to 10%; funded crews recover it in about 4. `tests/wear.gd` (in CI).
- Planks (E4 slice 2): a ninth market good and the Sawmill, which turns wood into planks. Building sites with planks in stock finish up to 25% faster. Planners build sawmills after a lumber camp. `tests/tools.gd` extended.
- Sandbox and gods-eye view plan: `docs/SANDBOX_DESIGN.md` (phases G1 to G5: scenario setup, sandbox editor, god powers, globe view, real-world map) and an ordered work list in `docs/PLAN.md`. Design only; no gameplay change.
- Wood and tools chain (E4 slice 1): two new goods on the market, wood (0.7) and tools (3.5). Lumber camps cut the forest around them; toolworks turn wood and metal into tools; farms, mines and factories with tools in stock produce up to 15% more. Planners build both. `tests/tools.gd`.
- Culture score (D6): hegemony score now includes culture, population x (0.6 culture coverage + 0.4 education coverage) x 0.4 (20% more with free schools), the peaceful route's currency. The Empire standings show each side's culture part. `tests/victory.gd`.
- Sprite engine (S1): a PNG in `client/art/sprites/<age>/b<id>_<level>.png` replaces the procedural drawing of that building, with fallback through older ages and then the code art. `tools/bake_sprites.gd` renders all 87 current drawings to PNG templates. `tests/sprites.gd`, `docs/SPRITES_DESIGN.md`.
- Ages (A1): towns advance Ancient, Medieval, Industrial, Modern by knowledge (population, education, culture), peak population, treasury and mood. The age gates buildings and units, and opens needs (fire, police, education; then power, water, sewage, waste, transit, health) that fade in over a 400 s per step grace period that holds while mood is low. The planner builds ahead of new needs and no longer takes on upkeep the treasury cannot carry for ten minutes. Setup option "Starting age" (default Modern: classic behaviour, saves load as Modern) and command `set_age`. An Ancient start survived 6 of 6 runs of 4200 s. `tests/ages.gd`, `docs/AGES_DESIGN.md`, wiki page.
- Defeat choice: a player who loses every town sees the game-over panel with "Keep spectating" (the world plays on, Tab and auto-follow work) or "Quit". `tests/defeat.gd`.
- Vassalage (D4): a war with the total goal that ends by surrender now makes the loser a vassal of the winner instead of ending with no treaty. The vassal keeps its land, coins and buildings (no strip is annexed); the land goal still annexes a strip and the tribute goal takes tribute only. A vassal pays its overlord 10% of its positive income every second, trades at the alliance multiplier (x1.4), counts its land as allied land for hegemony, and is drawn in the alliance colour. A vassal cannot declare war or leave; the overlord releases it with "Cancel treaty", and signing any other treaty (embargo, war) ends vassalage. AI towns never declare war as a vassal or on one. `tests/vassal.gd` (in CI) prints VASSAL_OK.
- War drivers (D3): every town has an ambition (military strength and temper) and builds border tension towards road-linked neighbours it has no treaty with; ambitious towns arm as it builds, and at full tension a stronger AI town declares war and states a goal. Goals set the occupation needed to force a surrender (tribute 15, land 40, total 60) and the spoils (tribute and total take half the loser's treasury, up to $600; tribute takes no land). The war headline names the trigger and goal; the war panel and the Empire window's Domination text show goal and occupation progress. Measured over 30 minutes with 8 planner towns, 6 runs: 4 to 6 wars each, nearly all ending by surrender (before: 0 to 5 wars, none before 25 minutes). Towns end that run smaller (about 60 to 80 pop, against 100 to 160 without wars), which is the D5 growth work. `tests/dwar.gd`; `tests/warrate.gd` measures war frequency.
- Victory (D2): a side wins by conquest (70% of all claimed land, or the last side alive) or hegemony (score at least 1.5 times the next side's while its land plus its allies' land is at least 40%). No timers: the map state itself wins. The host checks once per sim second and syncs standings in every snapshot and save; the Empire window shows land, allied land, score and progress per side; a Victory or Defeat panel names the route and offers "Keep playing" (the game continues as a sandbox). `tests/victory.gd`.
- Market window rebuilt as a trading screen: candlestick chart per good (10 s, 1 min and 5 min candles) with 5 and 20 period moving averages, volume and offered/wanted panes, hover readout, status (shortage, glut, balanced), high, low, average, change and volatility, price spread between towns, per-town local prices and a trade tape of town-to-town trades and price events. Candles are saved and rebuilt by multiplayer clients. `tests/marketwin.gd`.
- `tests/growth.gd`: growth baseline printout (time to 100 and 300 people), for tuning the planner and households.
- Domination plan: `docs/DOMINATION_DESIGN.md` sets the end goal (conquest or hegemony), faster growth, more frequent war, the depth order and a `city.gd` split. Design only; no gameplay change yet.
- Rivers v2: main rivers are domain-warped (meanders, loops), vary between 3 and 5 tiles wide, and thin tributaries run through wet country. Same seed gives the same land; old saves keep the seed so their rivers change shape.
- Portable Windows build in CI (`build.yml`): every push to `main` produces `Murmur-windows-<commit>.zip`; tags attach it to the release. The start menu and window title show the build (`vX.Y.Z (commit abc1234)`), `-- --build-info` prints it, `Play Murmur.bat` imports and starts from source, README run steps rewritten. `tests/buildinfo.gd`.
- Household second pass: the best-off quarter of households are landlords and split everyone's rent; the town taxes part of the well-off spending outflow ("Savings tax" budget line, scaled by the residential rate). `tests/landlords.gd`.
- Service trade: a town short of health, police, fire, education or leisure coverage buys it from road-linked neighbours that have plenty, paying them (embargo and war stop it). Towns share by trade, not by automatic money top-ups. `tests/services.gd`.
- Planner approve/veto queue: "Ask before planners build services" turns each planned service building into a decision (Build or Veto; a veto pauses that building for 10 days). `tests/propose.gd`.
- Mayor's financial focus: five sliders in the Budget tab (industry, farming, mining, military, services) steer what planners zone and build and whether a town makes or buys ore, metal and arms; the council sets it from prices and threat unless you move a slider. `tests/focus.gd`.
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
- Wiki-vs-code mismatches: "zones only" planner mode no longer lays roads (border, ore, avenue, street stubs) and auto-annex now works in it; Balance on a multiplayer client shows the host's answer (the reply carries the float); damage events no longer log ruins for non-zone buildings; the Transit text says "more than half coverage".
- `tests/market.gd` no longer fails when a food-importing region's price sits just above base (it failed once in CI at 1.02 against a 1.05 threshold); it now checks the price is not below base.
- Small unhappy planner towns could stall at about 40 people (one police station for the whole town, crime keeping mood under the immigration threshold); they may now build more of a service they badly lack. Seen as `tests/ai.gd` building only 3-6 military buildings in about a quarter of runs; now about 1 in 30.
- Power and water between towns now cost the buyer exactly what the seller earns (0.3 per unit); before, the buyer paid 0.4 and the seller got 0.2 for each partner's imports, which lost money and could over-credit with three or more towns.
- Multiplayer: a dropped player's town is reclaimed with a secret per-install rejoin token instead of the display name, and a fast reconnect takes over its old seat; the host no longer queues snapshots for a stalled client (it skips rounds, then disconnects it after a minute). `tests/token.gd`, `netsync`, `mp`.
- Empire window column sorting was shifted by one column; founded towns now use the game's difficulty and stay planner-run while spectating; a dedicated server takes 8 clients; joining players draw the host's world between towns; WASD no longer pans the camera while typing; the benchmark (F9) no longer deletes your save; `leave` can no longer end a war for free; minimized windows come back minimized; the Declare WAR tooltip describes real fights.
- Planner stall: a tiny low-mood town no longer sits under the zoning mood gate forever; it now builds a service to lift mood first and small towns (pop < 40) use a lower gate (0 stalls in 96 fresh towns, was about 5%).
- Planner towns could never link a border: the border road was laid as a straight line and gave up for good at the first building in the way (`tests/spectate.gd` failed about 1 run in 4). It now finds a route around buildings, preferring dry land.

### Changed
- Performance note for this release: the headless 8-town stage profile (3000 sim-s) averages about 2.8 to 3.5 ms a step, against 1.66 ms at v0.2.0. Towns are about 40% bigger and the household, goods, maintenance and trade systems are new, so it is not like-for-like; the largest regression (service trade) is fixed above. The windowed benchmark was not re-run for this release; the README table is still the v0.2.0 measurement.
- Performance: the cross-town service trade no longer rescans every building definition each second (`Catalog.need_pop` is cached): that stage went from about 7.4 s to 1.2 s over the 3000 s, 8-town headless profile. Household accounting uses per-building tables and one loop fewer. `stageprof` now reports `m_households`, `m_svc_trade` and `m_trade` inside the money stage.
- `city.gd` split (D7): traffic, avenue widening and buses moved to `scripts/traffic.gd` (`Traffic`, `tests/traffic.gd`); petitions, promises, approval, elections, loans, milestones and advisors moved to `scripts/mayor.gd` (`Mayor`). `City.answer`, `rally`, `take_loan` and `advisors` stay as its API. Behaviour unchanged; city.gd is 3836 to 3504 lines.
- Efficiency engine: mood no longer halts building. `City.efficiency()` (mood / 0.5, at most 1) scales construction speed, the upgrade roll and how often the planner zones; only mood 0 stops it. Replaces the hard mood gates (planner 0.38, upgrades 0.35). Six fresh towns, two batches: 8 of 12 reach 300 people (before 5 to 7 of 12). `tests/efficiency.gd`.
- Growth (D5, gate 2): buildings may be upgraded from mood 0.35 (was 0.45); planner towns hover at 0.30 to 0.43 mood, so they almost never levelled up. Six fresh towns, two batches: time to 100 people 610 to 978 s (was 830 to 1050 s), mean population at the 4800 s cap 265 (was 238). Households test town now reaches 322 people.
- Growth (D5, gate 1): a town below the planner's mood gate that has no service left to build now keeps zoning when it needs homes, instead of sitting on its treasury. Six fresh towns: 0 of 6 reached 300 people in 4800 s before, 7 of 12 after.
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
