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
- [ ] Boats: Port building on a water-edge tile; cargo ships boost export income; ferries; patrol boats/navy in war battles (Diplo._battle)
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
- [ ] Spectator / no-mayor mode: setup option where every town runs on its planner (human=false), no bankruptcy for the viewed town, speed up to 8x, camera follow/cycle towns, event ticker, optional auto-save. Watch towns grow and interact.
- [ ] Mining and materials: mines (ore/stone/coal by terrain), metals and materials (iron, copper, stone, timber), smelter and workshop/factory chain feeding construction cost, goods and exports; mine pollution and safety events; trade value with neighbours.
- [ ] Farm variants: grain, orchard, livestock, greenhouse (winter), fish farm; each with different yield, season, water need and art.
- [ ] README performance table with measured numbers (fps, CPU/GPU ms, memory) for old vs new builds, method and hardware stated.
- [ ] README screenshots; tag v0.2.0 with portable zip release.
- [ ] Ferries; split animated tiles from static baked chunks; hand-play tuning at 500+ pop.
- [ ] Install notes: godot-claude-skills live in .claude/skills (done).
