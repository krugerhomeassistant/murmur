# EMPIRE DESIGN (v0.4+)

Status: design agreed with the user 2026-10-08, no code yet. Order of work: E1 world, E2 empire mode, E3 group multiplayer, E4 economy, E5 infrastructure, E6 military variety (continues `WAR_DESIGN.md`).

## Why
User feedback: the map "feels restricted". Today each town owns a fixed 96x64 grid (`City.W/H`), towns tile a rigid world grid by `gpos`, you own a 48x32 patch and buy more edges, and founding a town is a flat $300 button (`Main.found_town`). Spectator mode is a viewer, not a way to play.

Goals:
1. An endless, procedurally generated, explorable world; founding and growing are map actions.
2. "Empire" play: manage a group of towns as a whole (the upgraded spectator mode).
3. Multiplayer where each player or team owns a group of towns, with a shared economy per group.
4. Deeper economy, infrastructure and military on top.

## E1: Endless world (foundation)

### Terrain
- World coordinates are integer tiles `(wx, wy)`, unbounded. `World.tile(wx, wy)` is a pure function of `(seed, wx, wy)`: layered value noise for elevation, moisture and temperature gives deep water, rivers, coast, plains, forest, hills, mountains and ore/resource deposits. Rivers come from a flow pass on a coarse chunk grid so they stay continuous across chunks.
- Chunks are 32x32 tiles, generated on demand, cached with an LRU. Only player edits (roads, bridges, claims) are stored, as a sparse diff, so saves stay small and the world is reproducible from the seed.
- Fog of war: unexplored chunks draw as parchment until a town, road, unit or scout reveals them (explored set saved per group).

### Plots, not one giant array (decision)
`city.gd` is ~7,000 lines of `y * W + x` indexing over fixed arrays, and it carries the war, net and perf work. Rewriting its storage is the highest-risk path. Decision: keep each town's arrays but make them a **plot** anchored at a free world position:
- `City.wo: Vector2i` (world origin of the plot) replaces `gpos`; `Military.origin(c)` becomes `wo * TILE`. Plots may sit anywhere that does not overlap another plot, not on a rigid grid.
- A plot's `water`, ore and elevation arrays are filled from `World.tile` over its window instead of the old per-town river generator, so neighbouring plots share a coastline and a river runs through the gap.
- Bigger towns come from **claiming adjacent plots** into the same town (a town = 1..N plots joined by a shared road network) rather than growing one array. This keeps every existing per-town algorithm (planner, networks, war flow fields) valid per plot. If plots prove limiting we can raise `W/H` or move to chunked storage later; that is deliberately deferred.
- The land between plots is real, explorable wilderness drawn from `World.tile`: forests, lakes, resources. Roads, rail and wires may cross it (cost per tile by terrain; bridges over water as today).

### Founding and expansion model (replaces the flat $300)
- **Survey:** any explored free site shows a suitability score (flat land, water, resources nearby) and a cost.
- **Found:** pick a site on the map, pay `settlers` cost = base + distance from the nearest owned town + terrain penalty. A road/rail/sea link is required for the new town to join the shared network; unlinked towns run on their own.
- **Claim:** a town can claim the next plot or a wilderness tract bordering its plots for coins; claimed land can host buildings, farms, mines and outposts.
- **Frontier pressure:** unclaimed land is first-come; rival groups can claim up to a border with a no-man's strip; claims next to an enemy are contested in war.
- Auto-expand (`auto_expand`, `_expand_auto`) becomes an AI policy over the same claim/found actions.

### E1 deliverables
`scripts/world.gd` (generator + chunk cache), `tests/world.gd` (determinism: same seed -> same tiles; rivers continuous across chunk borders; plots never overlap), save v2 + migration of old saves (old towns become plots at their old `gpos * (W,H)`), camera free-pan with fog, minimap, the founding UI, benchmark scenario stays 8 towns.

## E2: Empire mode (upgraded spectator)
- Roll-up dashboard: treasury, population, income by town, alerts (unrest, shortage, war), sortable.
- Per-town policies and presets (tax, build focus, military stance) set in bulk or per town; the planner AI runs as a delegate, with a "what I'd build next" queue the player can approve or veto.
- Drill-down: click a town to take direct control for a moment and release it back.
- Shared **empire treasury** with transfer rules (auto-balance floor per town, grants, loans between towns).
- Sim level of detail: towns off-screen tick at a reduced rate and aggregate; on-screen and war towns tick fully. Budget target: 12 towns at 8x with no p99 regression vs the current README table.

## E3: Group multiplayer
- Today: one human per town, host-authoritative (`MULTIPLAYER.md`). New: an **owner** (player id) and a **group** (team) per town. A player commands only their own towns; teammates see and may use group resources.
- Shared economy per group: one treasury, shared stockpiles for goods routed over linked networks, shared research of building/unit unlocks (E6).
- Group vs group: diplomacy and war are group-level; allied groups can share vision. Win/lose: last group standing, score, or timed.
- Protocol: `Cmd.run` stays the single validated command route; add `owner`/`group` checks, group treasury commands, claim/found commands. Snapshots gain world-diff deltas (not whole chunks). Fixes the open audit items first: rejoin token, snapshot backpressure.
- Players can join mid-game and are placed on a free site by a start-site picker.

## E4: Economy depth
- Goods chain: raw (grain, wood, stone, ore, oil) -> processed (flour, planks, metal, fuel) -> finished/luxury (food, tools, goods). Buildings consume and produce per tick; shortages are visible and have remedies.
- Regional prices from supply and demand; trade routes between towns move goods along roads/rail/ships with capacity and transit time.
- Upkeep and maintenance (roads, rail, buildings), loans with interest, and a budget screen.
- Keep the planner fed: the economy must stay solvable for AI towns (see the planner-stall known issue before this lands).

## E5: Infrastructure
Rail (freight and passenger), highways, harbours and ports, airports, power tiers (coal/gas/solar/wind/hydro with grid balancing), water and sewage tiers. Each is a network type like the existing wires and pipes; rail and ports double as military logistics (E6).

## E6: Military variety
Continue `WAR_DESIGN.md` phases 2-4 (sieges and building damage, air, command UI). Add buildings and units: barracks tiers, armoury, shipyard, airfield, radar/AA, engineers, supply depots; unlocks via empire-level research; logistics (units need supply along linked networks).

## Risks and guards
- Save format break: save v2 with migration; keep a loader for v1; test with a v1 fixture.
- War/net regressions: `warmap`, `war`, `netsync`, `pvp`, `mp` stay green at every PR.
- Perf: performance pass is last before each release; world generation must not run in the frame budget (chunks generated spread across frames, as flow fields are today).
- Scope: each Ex ships as several PRs behind the existing CI; no Ex starts before the previous one's tests are in.
