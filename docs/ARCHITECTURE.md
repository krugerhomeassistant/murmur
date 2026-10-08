# ARCHITECTURE

## Stack
- **Client (the game):** Godot 4.7.2, GDScript, 2D, GL Compatibility renderer. Single-player works with no server and no network.
- **Live-data server (not built, Phase 5+; unrelated to multiplayer, which is host-authoritative ENet, see MULTIPLAYER.md):** Node 24 LTS, ESM, dependency `ws`. Aggregates firehose feeds into signals; hosts Live cities. Move to Node 26 after it enters LTS (2026-10-28).
- **Assets (art phase):** Blender 5.2.2 via MCP, exported glTF.
- **Persistence:** client `user://murmur_save.bin` (single slot); server `state.json` (atomic write) later.

## Core design: the signal seam
```
world sources                          city
 simulated  events.gd  --writes-->   Signals   --read-->  City.tick()  -->  main.gd (draw/UI)
 live       feeds      --writes-->   (market, news, weather, ...)
```
- `Signals` (`scripts/signals.gd`): the only thing the city reads. Values decay toward baseline.
- `WorldEvents` (`scripts/events.gd`): simulated source and the player's sandbox buttons, same code path.
- `City` (`scripts/city.gd`): pure rules, no drawing, no I/O. Selfcheck lives here.
- `World` (`scripts/world.gd`): endless terrain as a pure function of (seed, x, y) in world tiles: sea, rivers, sand, plains, forest, hills, rock, ore. Integer hashing and + - * / only, so all peers agree bit for bit. Chunked (32x32) with an LRU cache; slow fields are sampled every 4 tiles and interpolated. Not yet used by towns (docs/EMPIRE_DESIGN.md E1).
- `main.gd`: input, drawing, UI, citizen dots.
- Live sources (Phase 3+) replace calls into `Signals`; nothing in `City` changes.

## Invariants
- City never reads feeds, only Signals.
- A dead live feed falls back to simulated; the game never stops.
- Simulation uses fixed 0.1 s steps scaled by game speed; rendering is separate.
- No personal identifiers stored or shown.

## Wire protocol (Phase 5, draft, JSON text frames)
`{"type":"signals","t":..,"v":{"market":0.2,"news":-0.1,"weather":"rain"}}` per second. Compact format only if size hurts.

## Env vars (no secrets in repo)
`PORT`, optional `GITHUB_TOKEN`, optional `OPENSKY_CLIENT_ID`, `OPENSKY_CLIENT_SECRET` (server, later).

## Decision log
- 2026-10-07: City scale growing from a village; Earth view deferred to its own mode.
- 2026-10-07: Bluesky over X (cost). GH Archive over GitHub REST (rate limit).
- 2026-10-07: Location-seeded cities, player-picked via Open-Meteo geocoding; per-city Live/Paused. Now part of the optional Live layer.
- 2026-10-07: **Redesign: interactive base game first, live data optional.** Reason: fun needs player agency; data alone is a dashboard. Signal seam makes live a toggle.
- 2026-10-07: Weather/quakes/news are plain HTTP polls, so Phase 3 is client-direct with no server. Server only for firehose feeds and Live cities.
- 2026-10-07: Prototype is 2D top-down (fastest to play). 2D vs isometric vs 3D decided after playtest.

## v5 layout
Signals (seam) <- City (engine, generic over defs) <- Catalog (buildings/metrics/policies data) + WorldEvents (event data). main.gd draws+loops; hud.gd (Hud) is all UI. Adding a building/event = add a dict entry; UI, codex, tooltips and engine pick it up.

## v8 additions
- `civics.gd` (class_name Civics): SEASONS, PETITIONS, MILESTONES, RANKS, LOANS, need_text(). Pure data.
- `sfx.gd` (class_name Sfx, Node): AudioStreamGenerator 22.05 kHz; main calls `sfx.cue(name)`; City pushes cue names to `city.sounds`, main drains them for the active town.
- City: `to_dict()/from_dict()` (save), `answer(idx, yes)`, `rally()`, `take_loan(k)`, `advisors()`; per-second `_civics() _milestones() _sync_buses() _sickness() _traffic()`; `_trade()` inside `_money`; `_new_day()` (elections); `_twister(dt)` in tick.
- New Ids: MILL, WAREHOUSE, DEPOT (cat "trade", field `chain`). Policy `insurance` (mod `insured`). Season mod `power_dem`.
- Events: tornado (inst tornado), epidemic (inst infect), power_outage (inst blackout), blizzard, spring_bloom, harvest_fair. `WorldEvents.pick(..., sw)` season weights.

## v9
- `diplomacy.gd` (class_name Diplo): static `rel/avg/treaty/stance/mil/tmult/act/resolve/second`. City fields: `rel`, `treaty`, `temper`, `human`, `dipl_t`; petitions kinds now petition | recover | offer | demand.
- City: map `W=96,H=64`, `terr` Rect2i + `cells` (owned indices; all whole-map loops use `for i in cells`), `expand(dir)`, `_expand_auto()`, `owns()`, `sidx(x,y)` (seed-relative index), `lamp` layer.
- main: two towns at start; `Diplo.second(towns)` every sim second; save format v2.

## Multiplayer transport (phase 0)
`NetPlay` (scripts/netplay.gd) is a Node named "Net" under the root so RPC paths match on all peers. Godot high-level multiplayer over `ENetMultiplayerPeer`; the host owns the player table and mirrors it to clients at 1 Hz and on change. Host-authoritative design and phases: docs/MULTIPLAYER.md.
