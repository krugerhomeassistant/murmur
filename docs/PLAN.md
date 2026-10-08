# PLAN

Goal: Murmur, a cozy interactive city-builder (Godot) with an optional Live Data layer. Design: `GAME_DESIGN.md`. Replaced Pebble Isles as Game 2 (mini-golf parked).

## Phase 0: Foundation
- [x] Research feeds, runtime, Godot networking (RESOURCES.md)
- [x] GAME_DESIGN.md + seven living docs
- [x] Project on user PC at `E:\Projects\Personal\game\murmur\` (moved from C: workspace), Pebble Isles parked
- [x] HUMAN: Godot/Blender tool setup (user confirmed working 2026-10-07)
- [x] Redesign: interactive base game first, Live Data optional, Earth view later

## Phase 1: Playable offline prototype (2D top-down, Godot)
- [x] Rewrite design docs around the new direction
- [x] Scaffold `client/` (project.godot, `addons/godot_ai`, launcher `Open Murmur in Godot.bat`)
- [x] `scripts/signals.gd` (the seam), `events.gd` (simulated world), `city.gd` (rules + selfcheck), `main.gd` (draw, input, UI)
- [x] `scenes/main.tscn`, set as main scene
- [x] Selfcheck passes: headless Linux Godot printed SELFCHECK_OK; `tests/smoke.gd` printed SMOKE_OK (5 sim minutes at 3x, every event fired)
- [ ] HUMAN (1 click): double-click `Open Murmur in Godot.bat`
- [x] Run via godot-ai, logs, screenshot (2026-10-07)
- [ ] User plays 3 sessions; note what feels off in ACTIVE_CONTEXT.md

## Phase 2: Depth and feel
- [ ] Tune economy from playtest; difficulty curve table in WIKI.md
- [ ] Day/night tint, rain/heat/storm visuals polish, sound (WebAudio-style generated tones or Godot AudioStreamGenerator)
- [x] Save/load city (`user://murmur_save.bin`, autosave daily)
- [ ] More verbs: police/subsidy response to protests, building upgrades
- [ ] Stress mode: 5,000 citizens, read FPS

## Phase 3: Live Data v1 (client-direct HTTP, no server)
- [ ] Settings screen: per-signal Simulated/Live toggle, LIVE badge in HUD
- [ ] Weather via Open-Meteo `current` (HTTPRequest, 15 min)
- [ ] Quakes via USGS `all_hour.geojson` (60 s)
- [ ] News mood via GDELT tone (15 min)
- [ ] Fallback to simulated if a feed fails; log in LESSONS_LEARNED

## Phase 4: Location picker + seeding
- [ ] Open-Meteo geocoding search box
- [ ] Procedural map seeded per launch; feeds filtered by coarse location with local -> country -> world fallback

## Phase 5: Firehose feeds via server
- [ ] `server/` Node 24 LTS + `ws`: Wikipedia SSE, Coinbase WS, Bluesky Jetstream, GH Archive hourly
- [ ] Signals computed with EMA decay, broadcast to client over WebSocket
- [ ] Measure events/sec per feed in WIKI.md

## Phase 6: Art pass
- [ ] 2D vs isometric vs 3D decision (ARCHITECTURE.md)
- [ ] Blender MCP assets, real-event props (headline signs, book titles)

## Phase 7: Always-on Live cities
- [ ] Host choice (user creates account), deploy, restart policy
- [ ] Live vs Paused city modes

## Phase 8: Earth view (separate mode)
- [ ] Look-only real-time planet on the same data server

## v5-v7 rewrite (done, 2026-10)
- [x] Data-driven Catalog/WorldEvents/City; auto-growth builds any building; auto-policies
- [x] Wires/pipes power+water nets; crime; land value; commute/shop; housing tiers
- [x] Tribes/factions; military; multi-town (4) + regional trade
- [x] Floating windows (move/min/close, Windows menu, saved to user://ui.cfg)
- [x] tests/smoke.gd rewritten (selfcheck + soak)
- [ ] Balance: pop 40-60 plateau, fire frequency
- [ ] Art polish: lamp/fort/radar/terrace/condo shapes
- [ ] Cars/traffic on roads, petitions, persist minimized state

## v8 wave (2026-10-07)
- [x] Save/load + autosave
- [x] Living streets: cars, traffic/jams, avenue upgrades, buses, night lights, traffic overlay
- [x] Mayor: petitions/promises, approval, elections (28 d), rally, advisors
- [x] Seasons + disasters (tornado, epidemic, blackout), insurance, recovery decisions
- [x] Economy: crops/food/goods, mill/warehouse/depot, imports/exports, loans
- [x] Milestones + ranks; generated sound
- [ ] Hand-play pass on the new Mayor window and loans UI
- [ ] Live Data (deferred by user)

## v9 (2026-10-07)
- [x] Growable map (96x64, territory strips, auto-annex), endless
- [x] Default neighbour + relations/treaties/diplomatic events/raids/tribute
- [x] Street lamps on road tiles, spaced
- [ ] Hand-play diplomacy UI; tune hostile-event harshness; found-town cost vs planner spending
- [ ] Ideas: see neighbours on the map edge, war/peace treaties with terms, shared projects

- [x] Art pass 2 (zone buildings, build icons, ground) verified by showcase screenshot.

## Rivers / world / boats
- [x] v1 rivers: water grid, random gen, bridges, animated water+fish, setup toggle
- [ ] World editor: paint rivers/lakes on a preview before starting (setup screen)
- [ ] Boats: cargo ships boost export income; ferries (navy in wars is done, see Military)
- [ ] Economy hooks: fishing dock (food), waterfront land value, river pollution
- [x] Rivers continue across neighbouring towns (setup option 'One river through neighbouring towns', default)
- [x] Sewage network (plant, sewers, planner, HUD)
- [x] Always-visible demand + utility strip; map hover card
- [x] World editor (custom river painting), Port + Naval yard + ships
- [ ] Later: fishing dock (food), river pollution from sewage, rivers shared across neighbouring towns, ferries
- [x] Fishing dock, river health (sewage pollution)

## Performance (priority 1)
- [x] Cache _net, LOD off-screen towns, deferred scan, chunked/baked/LOD render, F3 overlay (perf/frame-cost)
- [ ] Split animated tiles (water, fans) from static ones so baked chunks refresh only when changed
- [ ] Citizen/car/boat draw culling; overlay passes via chunks; _plan_* candidate scans
- [ ] Profile real late-game save (pop 500+) with bench2

## Backlog added 2026-10-07 (user ideas, do not lose)
- [x] Spectator / no-mayor mode
- [x] Mining and materials: mines (ore/stone/coal by terrain), metals and materials (iron, copper, stone, timber), smelter and workshop/factory chain feeding construction cost, goods and exports; mine pollution and safety events; trade value with neighbours.
- [x] Farm variants: grain, orchard, ranch, greenhouse, fish farm (planner uses them)..
- [ ] README performance table with measured numbers (fps, CPU/GPU ms, memory) for old vs new builds, method and hardware stated.
- [x] README screenshots and GIF (docs/media). [x] Tag v0.2.0 with portable zip release (2026-10-08).
- [ ] Ferries; split animated tiles from static baked chunks; hand-play tuning at 500+ pop.
- [ ] Install notes: godot-claude-skills live in .claude/skills (done).
- [ ] Threading (perf): no threads today. Tick off-screen towns on WorkerThreadPool with a start-of-tick snapshot of partner net_own/net_dem/treaty state (the only cross-town reads); join before Diplo.second. Keep only if the 6-8 town benchmark improves.

## World view (user, 2026-10-07) - DONE (merged)
- [x] One continuous world: every town drawn at its grid offset; pan/scroll between towns, no toggling. The "map" is just this view zoomed out (live), replacing RegionMap overlay.
- [x] Viewed town = town under camera centre (HUD follows); clicking another town glides the camera to it
- [x] Far-zoom LOD 3: per-town live thumbnail textures + town name labels (cheap at 8 towns)
- [x] Visible off-screen towns tick faster (0.25 s batches) so they look alive
- [x] M = fit-the-whole-world toggle; update README controls, WIKI, benchmark second scenario (world view)
- [x] Links must be real: a border link needs a road in the town's biggest connected road network reaching the border; planner towns lay that road themselves (`_plan_gate`); no more "linked" without roads (user screenshot, spectator mode).
- [x] REAL ARMIES done (feat/armies): trained units (infantry/tanks/jets) with hp, range, damage; fight on the front, occupation forces surrender; T toggles auto-training. 
- [x] AI ARMIES done (feat/ai-armies): threat-driven military building, counter-training, naval yards for river enemies.
- [ ] Perf: Military.fight is O(n^2) per pair (6 ms at 110 units a side, army cap 150); spatial bucketing by gpos when the spike pass starts.
- [x] WARSHIPS + RAID DAMAGE done (feat/navy): patrol boat/destroyer/transport on shared rivers, bombers and raids destroy border buildings with visible blasts and smoke.
- [x] UNIT VARIETY done (feat/unit-variants): 13 types, vet ranks, Army window with training priorities.
- [x] WAR VISUALS v1 done (infantry/tanks/jets/blasts on the front); still to do: warships on shared rivers, buildings visibly damaged by raids (user asked "no armies, tanks, planes, boats fighting?"): war is currently abstract (Diplo._battle every 20-35 s, soldier dots only at your border). Add visible armies marching across the shared border in the world view, tanks/planes by military tier, naval units on shared rivers (navy yards exist), battle effects and damage to buildings, so a declared war is something you see.
- Do NOT drop the other backlog above (mining planner, v0.2.0, screenshots, lint in CI (done), spike work, threading, ferries, farm variants); this sits alongside it.

## Multiplayer: design decided 2026-10-08, see docs/MULTIPLAYER.md (competitive, 2-8 players, LAN/direct IP + dedicated server)
- [x] (done: competitive towns, one ENet code path; phases P0-P6 shipped, see MULTIPLAYER.md) Research + decide model before any code: (a) co-op shared world (one host sim, clients send build/diplomacy commands, host streams state) vs (b) each player runs own town(s) in the one world with diplomacy/war between players vs (c) async/visit. Godot 4 high-level multiplayer (ENet/WebSocket, RPC) is the likely base.
- [x] Prereqs checked: sim uses randf()/global RNG and wall-clock (Time.get_ticks_msec) in places, so it is not deterministic: host-authoritative state sync is the realistic route, not lockstep. Saves already serialise towns (`to_dict`), a snapshot format exists. World view already has one human-owned town flag (`human`), so multi-owner needs per-town owner id and per-player HUD.

## Priority notes (user, 2026-10-07)
- [x] BENCHMARK STANDARD: real windowed run (not headless), 8 towns, 8x speed, ALL overlays on; report fps/p99/CPU/GPU/RAM/VRAM for that. README table must use it. Headless sim numbers are secondary only.
- [ ] REPO PROFESSIONALISM pass: screenshots/GIF in README, consistent docs structure, docs/ folder, CONTRIBUTING/CODE_OF_CONDUCT/SECURITY, release notes, badges accurate, remove dev clutter, LICENSE check, tidy PLAN/WIKI/LESSONS layout.
- STANDING RULE: README/docs must never claim anything untrue or stale; scripts/check_repo.py runs in CI (hygiene job).

## Empire / endless world (user, 2026-10-08): NEXT MAJOR FEATURE, design in docs/EMPIRE_DESIGN.md
- [ ] E1 Endless procedural world: `world.gd` generator + chunk cache, plots anchored by world position (replace `gpos`), fog of war, found-a-town on the map with distance cost (replaces flat $300), claim adjacent land, save v2 + migration, `tests/world.gd`.
- [ ] E2 Empire mode (upgraded spectator): dashboard, bulk policies, planner delegate with approve/veto queue, empire treasury, sim level of detail.
- [ ] E3 Group multiplayer: owner + group per town, shared group economy, group diplomacy/war, join mid-game. Prereqs: rejoin token, snapshot backpressure.
- [ ] E4 Economy depth: goods chains, regional prices, trade routes, upkeep, loans.
- [ ] E5 Infrastructure: rail, highways, ports, airports, power and water tiers.
- [ ] E6 Military variety: war phases 2-4 plus new buildings/units, research, logistics.

## War rework (user, 2026-10-08): "full Age of Empires / Empire Earth style war" - NEXT MAJOR FEATURE (v0.3)
Today: armies fight on one abstract line between two towns; unopposed units at the edge raid and shell from a distance (`Military.fight/_occupy`, `Main.draw_fx`). User feedback from watching it:
- [x] Armies march INTO the enemy town (world positions, phase 1). [ ] Fight among the buildings: buildings take damage (phase 2).
- [x] Ground units cannot cross water; a road bridge opens the way (phase 1, `tests/warmap.gd`). [ ] Transports ferry troops across.
- [x] Boats sail along connected river water (phase 1). [ ] Naval gunfire on shore buildings.
- [ ] Air: heli, fighter, jet, bomber exist in `Military.KIND` but are drawn as small icons; give them flight paths, dogfights, bombing runs and AA fire.
- [ ] Sieges: units attack and capture/destroy buildings; capture points, rally, retreat; production queues and a command UI.
- [ ] Battle footage for the README (second GIF) once the above exists.
Rules: keep `Military` deterministic enough for `tests/war.gd`; the host simulates wars (multiplayer); perf must not regress (`--benchmark --war`).

## Known issues
- [ ] Planner stall: an isolated early town (no policy, ~0.3 mood) can sit under the `mood < 0.38` zone gate for 600 sim-s with 2000 coins and never grow (about 7% of fresh towns, seen in `City.selfcheck`). CI now allows 3 fresh towns; the real fix is to have `_plan_service` raise mood first when the gate is the blocker.
## Audit 2026-10-08 follow-ups (not yet done)
- [ ] Rejoin token: claims are keyed by name only, so anyone can take a dropped player's town by using their name; also a fast rejoin gets a different town while the old peer lingers.
- [ ] Snapshot backpressure: reliable per-second snapshots can queue without bound for a stalled client.
- [ ] Server: password, bind address, kick/ban, world persistence; `SECURITY.md` should say the dedicated server is not hardened.
- [ ] Tests missing: save/load round trip, elections/game-over, diplomacy single-player, events, hud/setup wiring, net abuse (silent peers, command floods).
- [ ] CI: cache the Godot binary, `set -o pipefail`, export job, tag-triggered release workflow (smoke step once hung 25 min on a runner; per-step timeouts now exist).
- [ ] UX: hotkey help (F1), settings and pause menu, volume persistence, multiple save slots, UI scale, colour-blind overlays.
- [ ] Planner economy: utilities lag demand (score ignores output), overbuilt jobs vs housing, annexation unbounded (all 6144 cells at pop 78), `to_dict` omits a few runtime fields.
