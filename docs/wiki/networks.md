# Networks, coverage and the town map

How the map of one town works: what a tile can hold, how roads connect buildings, how the power, water and sewage networks are solved, how service coverage is computed and where it ends up in the stats, plus the building lifecycle, fire and disaster rules, territory and terrain.

All of this lives in `client/scripts/city.gd` (class `City`) unless another file is named. Numbers are read from the code; function names are given so you can jump to them. Per-building values (costs, radii, outputs) are in the generated reference pages: [Buildings](buildings.md), [City stats](stats.md), [Policies](policies.md), [Events](events.md), [Constants](constants.md). The computer-controlled builder that lays most of this out for you is described in [Planner](planner.md).

## Contents

- [The map model](#the-map-model)
- [Roads, avenues and bridges](#roads-avenues-and-bridges)
- [Road adjacency: when a building works](#road-adjacency-when-a-building-works)
- [Power, water and sewage networks](#power-water-and-sewage-networks)
- [Service coverage (`cov`)](#service-coverage-cov)
- [Street lamps](#street-lamps)
- [How coverage feeds the stats and the economy](#how-coverage-feeds-the-stats-and-the-economy)
- [Building lifecycle](#building-lifecycle)
- [Fires](#fires)
- [Disasters and recovery](#disasters-and-recovery)
- [Overlays](#overlays)
- [The `needs()` hints](#the-needs-hints)
- [Plots, territory and annexing](#plots-territory-and-annexing)
- [Ground, ore and water tiles](#ground-ore-and-water-tiles)
- [Where in the code](#where-in-the-code)
- [Open questions](#open-questions)

## The map model

Every town owns one fixed array size: `City.W` x `City.H` = 96 x 64 tiles (the "plot" of the region). Every per-tile array is a flat `W * H` array indexed by `i = y * W + x`. The town can only build inside its territory `terr` (a `Rect2i`), which starts at 48 x 32 in the middle of the plot (`START_W`, `START_H`, offset `OX` = 24, `OY` = 16) and grows by annexing (see [Plots, territory and annexing](#plots-territory-and-annexing)).

| Array | Type | Meaning |
|---|---|---|
| `grid` | int32 | `Catalog.Id` of the building on the tile (`EMPTY` = 0) |
| `lvl` | byte | Zone building level, 0 = empty zone plot |
| `build` | float | Construction progress 0..1 for a zone plot |
| `connected` | byte | 1 if the tile has a road on it or beside it (see below) |
| `wire`, `pipe`, `sewer` | byte | 1 where a power line, water pipe or sewer pipe is laid |
| `lamp` | byte | 1 where a street lamp stands (only on road tiles) |
| `water` | byte | 1 on river or sea tiles |
| `ore` | byte | Ore deposit richness 0..3, 0 = none |
| `ground` | byte | `World.K` terrain kind (cosmetic) |
| `burn` | float | 0 = not burning, otherwise seconds the fire has burned |
| `net_reach[m]` | byte | 1 on every line tile that is live for network `m` |
| `net_val[m]` | float | Satisfaction 0..1 of every tile that is served by network `m` |
| `road_comp` | byte | 1 on every road tile of the town's biggest connected road network |

`cells` is the list of owned tile indexes; every whole-map loop in the simulation runs over `cells`, not over all 6144 tiles. Services, zones and roads share the `grid` layer (one building per tile). The three line layers and the lamp layer are separate, so a wire, a pipe and a sewer can all run under the same road or building tile.

`City.DIAMOND` is the 13-tile Manhattan diamond of radius 2 as index offsets. It is used for local density in the crime calculation, not for service radii.

## Roads, avenues and bridges

Two road types exist, and `City.is_road(t)` is true for both:

| | Road | Avenue |
|---|---|---|
| Placement cost | 5 | 12 |
| Unlocks at (peak population) | 0 | 25 |
| Upkeep per tile in the budget (`City._money`) | 0.08 | 0.12 |
| Citizen walking speed | 1x | 1.5x on the tile (`City._move`) |
| Path-finding weight (`City._rebuild_astar`) | 1.0 | 0.6 (preferred) |
| Congestion threshold per tile (`City._traffic`) | 3 | 8 |

Notes:

- The Avenue's catalog `up` value is 0.2, but the budget line in `City._money` uses `roads * 0.08 + avenues * 0.12` (both then multiplied by `1 + pop/60`, the policy upkeep multiplier and `RATE` 0.08). The 0.12 figure is what is actually charged. See [Open questions](#open-questions).
- `City.place` does not upgrade a road in place: placing onto any non-empty tile fails. Bulldoze the road first, or let the planner widen a jammed street (`City._plan_traffic`, which pays 7 per tile).
- A road is only ever "connected" to itself; roads are never idle.
- Citizens use an `AStarGrid2D` (`City.astar`) with no diagonal moves; only road tiles are walkable. The grid is rebuilt when `roads_dirty` is set (any road placed, removed, or rebuilt).

### Bridges

Water tiles (`water[i] == 1`) accept roads and avenues only. In `City.place`, a road on a wet tile costs `cost * BRIDGE_X` where `BRIDGE_X` = 4, so a bridge is 20 for a road and 48 for an avenue. The affordability check is made against the multiplied price. Nothing else can be placed on water: zones, services and everything else are refused (`"zoned on water"` is a self-check). Wire, pipe and sewer lines can cross water at their normal price of 2 per tile (`place` does not look at `water` for line layers).

Placing or bulldozing a bridge calls `Military.terrain_changed()` because armies walk over water only where a bridge exists.

Buildings flagged `"water": true` in the catalog (port, naval yard, fishing dock, fish farm) must be placed on a dry tile with a water tile on one of its four sides (`City.wet_next`).

## Road adjacency: when a building works

`City._road_next_to(i)` returns the index of a road tile that serves tile `i`, or -1:

1. If tile `i` is itself a road, it returns `i`.
2. Otherwise it checks the four orthogonal neighbours in the order west, east, north, south and returns the first that is a road.

Diagonal neighbours do not count. `City._scan` writes the result into `connected[i]` for every non-empty owned tile. This is an adjacency test only: it does not require the road to join any larger network. A building beside a single isolated road tile counts as connected.

What `connected == 0` does:

| Effect | Where |
|---|---|
| The tile is skipped by the cell pass in `_scan`: no housing, no jobs, no upkeep recorded, no coverage provided, not added to `bt`, `homes`, `works` or `prov` | `City._scan` |
| Zone plots do not start construction or level up | `City._grow` |
| Residents whose home is unconnected are dropped ("Residents left after losing their homes") and workers lose the job | `City._second` |
| No power, water or sewage demand is counted for it | `City._net_solve` |
| It is drawn with a red "!" and darkened | `Main._building` |
| It is counted in the hint "N plot(s) have no road access" | `City.needs` |

Unconnected buildings are idle, not destroyed: levels and the building itself stay, and everything resumes when a road reaches them.

Job assignment (`City._second`) picks the nearest free workplace by Manhattan distance, not by path length. A worker can therefore be given a job in a part of town that is not joined to their home by road; `City._route` then fails and the citizen retries every 5 seconds without ever arriving. Build loops and keep one road network.

`City._road_net` separately finds the biggest connected road component (4-neighbour flood) into `road_comp`, and counts how many of its tiles lie within 3 tiles of each border into `gate[N, E, S, W]`. That is what the border-link logic uses (see [Planner](planner.md#border-roads-and-gates)); a stray road tile near the edge does not count.

## Power, water and sewage networks

`City.NETS` = `["power", "water", "sewage"]`. Each has its own line layer:

| Network | Line tile (`Catalog.Id`) | Layer array | Source building(s) | Output per source |
|---|---|---|---|---|
| power | Power line (`WIRE`), unlock 15 | `wire` | Wind turbine, Solar farm, Coal power plant | 8, 14, 40 |
| water | Water pipe (`PIPE`), unlock 15 | `pipe` | Water tower | 14 |
| sewage | Sewer pipe (`SEWER`), unlock 30 | `sewer` | Sewage plant | 16 |

A line tile costs 2 to place and has no restriction on what is under it: lines may run under roads, buildings, or water. `City.place` handles any catalog entry of kind `"net"` by writing the layer through `City._lay`; you cannot place the same layer twice on one tile. Network line upkeep is charged as `0.015` per laid tile per layer, added to the service upkeep in `City._net` (`up_svc += nets * 0.015`); the catalog value 0.03 is not used. The source buildings are normal `svc` buildings and must themselves be road-connected to count (an unconnected plant never reaches `bt`).

### Bulldozing lines

`City.bulldoze` works in layers. On a tile with a lamp, it removes only the lamp. On an empty tile it clears the wire, pipe and sewer of that tile together (all three at once). On a tile with a building it removes only the building; lines under it remain. Removing the building does not refund anything. To cut a line under a building, bulldoze the building first and then the empty tile.

### Connectivity flood fill

`City._net` runs once per `_scan` for each network, calling `City._net_solve`, which calls `City._flood`:

1. For every source building of that network (from `bt`), skip it if it is in `offline` (a tripped plant, see blackout events).
2. Look at the source tile and its four neighbours (`City._near`). Every line tile found there is marked live in `net_reach[m]` and queued. If at least one line tile was found, the source contributes its output: `out * (1 + mod(m + "_out"))` to the total supply. A plant that touches no line contributes nothing.
3. Flood fill from the queue through line tiles that are orthogonally adjacent. Everything reached is live.

A tile is served ("live") when `City._live` is true: it is a live line tile or has a live line tile on one of its four sides. So a building is powered when a live line touches one of its four sides or lies under it. `nc["idx"]` is the list of served tiles.

Separate islands of line with no plant never become live; a single plant powers only the line connected to it.

### Demand and supply

For every served tile, `City._net_solve` adds demand, skipping tiles that are unconnected, roads, empty zone plots, and source buildings themselves (those with an `out` entry):

- Zone with level L: `0.5 * L * (1 + (home + jobs) * 0.1)` where `home` and `jobs` are the catalog per-level values.
- Any other building (a service): 1.0.

The same function is used for all three networks. For power only, the total is multiplied by `1 + mod("power_dem")` (an event modifier).

Satisfaction is then, in `City._net`:

```
sat = 1.0                          if dem <= 0.001
sat = clamp(sup / dem, 0, 1)       otherwise
sat = 0                            if sup <= 0
```

The value `sat` is written into `net_val[m]` for every served tile, so everyone on the network gets the same share: a network that is 20% short browns out for every building on it, not only the ones furthest away. Unserved tiles hold 0.

### Imports from neighbours

If `sup < dem` after the local supply, `_net` goes through `partners` (the other towns in the region) and takes

```
take = min( max(partner.net_own - partner.net_dem, 0) * 0.6 * Diplo.tmult(self, partner), dem - sup )
```

`Diplo.tmult` is 0 for embargo, war, or when the two towns are not road-linked at their shared border; otherwise it is `clamp(0.6 + 0.5 * avg_opinion, 0.2, 1.3)` and then x1.25 for a pact or x1.4 for an alliance. Imported amounts are stored in `imports[m]`. In `City._money`, imports of power and water cost `0.4 * RATE` per unit and a town earns `0.2 * RATE` per unit for what each partner imports. Sewage can be imported by the same code, but no money is exchanged for it.

### Sewage and the river

Sewage supply is the plant output reachable through sewers. In addition, `_net` computes the river health target: `raw = max(pop - 20, 0) * 0.15` is sewage produced; `clean = clamp(net_own.sewage / raw, 0, 1)` (1.0 if `raw <= 0`). `river_health` moves toward `clean` by at most 0.02 per second. River health scales fish dock and fish farm output (`City._trade`) and gates the planner's choice of a fish farm (> 0.4).

### Caching

Solving is cached per network in `net_cache` keyed on the layout, lines, outages, territory size and relevant modifiers. If only the building levels changed (growth), the flood fill is kept and only demand is recomputed. When satisfaction changes, only the served tiles are rewritten. You do not need to call anything; `place`/`bulldoze` set `scan_dirty` and `flush()` (called at the start of every `tick`) triggers `_scan`.

## Service coverage (`cov`)

Coverage is computed per metric (the 17 metrics in `Catalog.METRICS`, see [City stats](stats.md)) in two steps.

### Per tile: `raw_cov` and `cov_at`

- For `power`, `water` and `sewage`, `City.raw_cov` simply returns `net_val[m]` for that tile (satisfaction, 0 for unserved).
- For every other metric it sums the strengths of all providers whose service diamond contains the tile and caps the sum at 1.0:

```
raw_cov(c, m) = min( sum of strength  for each [x, y, strength, radius] in prov[m]
                     with |x - c.x| + |y - c.y| <= radius , 1.0 )
```

The service area is a Manhattan **diamond** of radius `r`, with equal strength anywhere inside it (no falloff). Two clinics of strength 0.6 overlap to 1.0 (capped). `prov[m]` is rebuilt in `City._scan` from every connected `svc` building (`prov` and `r` in the catalog) plus lamps.
- `City.cov_at(c, m)` adds the policy and event modifier `mod("cov_" + m)` and clamps to 0..1. Policies such as free transport add a flat amount everywhere, including to homes with no provider at all.

### Per town: `cov[m]`

`cov[m]` is the average of `cov_at` over all homes (`homes`, the connected residential plots with level > 0). If there are no homes it is 0. It is recomputed in `_scan` only when the layout or the modifiers change (`cov_sig`). `City.cov_home(i, m)` is a cached per-home lookup for citizen logic.

`City.raw_cov` is also what the overlays (green/red tiles) and the planner's site scoring read.

The pollution stat is separate: `City.poll_at(c)` sums, over all `polluters`, `strength * (1 - d / (radius + 1))` for tiles within `radius` (this one does fall off). The town value `pollution` is the average over homes of `min(1, poll_at)`, times `mod("poll_mult")`.

## Street lamps

Street lamps (`Id.LIGHT`, cost 25, unlock 30, upkeep 0.1 hard-coded in `_scan`) live in the separate `lamp` layer, on road tiles only:

- `City.place` rejects a lamp unless the tile is a road, has no lamp yet, and no other lamp stands within Manhattan distance 1 (`_lamp_near(i, 2)`). Planner-placed lamps use `_lamp_near(i, 3)`, so they keep at least 3 tiles apart.
- In `_scan` every lamp on a road adds a provider `light`, strength 0.7, radius 4, to `prov`; two overlapping lamps reach 1.0.
- Bulldozing a lamp tile removes the lamp only; bulldozing again removes the road.
- Effect: crime in the lit block is multiplied by `1 - 0.25 * clamp(raw_cov(light) + mod, 0, 1)` in `City._crime`. There is no direct mood effect. Lamps are also drawn as a glow at night.

Crime itself (`City._crime`, recomputed every 3rd second) per built non-road tile: `v = base + sz * (0.3 * dens/13 + 0.3 * (1 - police) + building crime)`, where `base = 0.08 + 0.5 * unemployment + mod("crime_add")` and `sz = clamp(pop/50, 0.1, 1)`; then `v *= 1 - 0.25 * light`, `v *= 1 - 0.35 * justice`, `v = clamp(v * mod("crime_mult"), 0, 1)`. `dens` counts non-empty tiles in the radius-2 diamond.

## How coverage feeds the stats and the economy

Each metric has a `kind` in `Catalog.METRICS` (`need`, `bonus`, `safety`) and a weight `w`.

**Mood** (`City._second`): the mood target starts from 0.72 and subtracts and adds many terms. The coverage terms are

- for each `need` metric: `target -= w * _need(m)`, where `City._need(m)` is zero until population reaches that metric's `need_pop` (the lowest unlock population among buildings that provide it), then `(1 - cov[m]) * clamp((pop - np) / (np * 0.8 + 5) + 0.25, 0, 1)`: the penalty ramps in as the city outgrows the need.
- for each `bonus` metric: `target += w * cov[m]`.
- `safety` metrics have no direct mood term.

The weights are in [City stats](stats.md). Real mood then moves toward the target by at most 0.05 per second.

**Money** (`City._money`): coverage multiplies the tax lines.

| Coverage | Effect |
|---|---|
| health, power, water | Productivity `prodm = (1 - 0.2 * need(health)) * (1 - 0.25 * need(power)) * (1 - 0.15 * need(water))` on residential, commercial, industrial and office income |
| edu | Residential and industrial tax x `1 + 0.3 * cov[edu]`; office tax x `0.5 + 0.5 * cov[edu]`; office demand also scales with it |
| finance | All tax x `1 + 0.12 * cov[finance]` |
| commerce | Sales x `1 + 0.25 * cov[commerce]` |
| police, light, justice | Through crime: theft loss `crime * pop * 0.3 * RATE`, plus a mood term `0.25 * max(crime - 0.1, 0)` |
| transit | Citizens in a home with `cov_home(transit) > 0.5` walk 1.3x faster and are less likely to drive |
| health | Sickness: sick citizens recover `1 + 2 * h` per second, spread at `0.03 * (1 - 0.7 * h)`, die at `0.002 * (1 - h)` per second |
| fire | Fire safety, see [Fires](#fires) |

Land value (`City._land`, every 10th second) also reads the coverage fields of leisure, edu, health, culture, transit, power and water; this drives which housing style the planner chooses.

## Building lifecycle

### Zone plots (residential, commercial, industrial, office, farm and variants, mine)

1. **Placement** (`City.place`): the player pays the placement cost (e.g. 10 for a residential zone). The tile must be owned, empty, dry, and unlocked. A mine also needs `ore > 0` under it. The plot starts with `lvl = 0`, `build = 0`. Planner towns place plots the same way at the city's expense (see [Planner](planner.md)).
2. **Waiting**: while `lvl == 0` and `build == 0` the plot is "waiting for funds". It must be `connected`.
3. **Construction start** (`City._grow`, once per second): each second, up to 3 empty connected plots (shuffled) may start construction, each only if `coins >= cost + 40 + hold`, where
   - `cost = GROW_COST * scale * (zone catalog cost / 15)`, with `GROW_COST` = 25 and `scale = (1 + blds/15) * mod("build_cost_mult")` (`blds` = total building levels),
   - `hold = 0` for a home when `res_dem > 0.3`, otherwise `0.7 * saving_for`.
   The cost is paid immediately and `build` is set to 0.01.
4. **Construction**: each second `build += max(mod("build_mult"), 1) / BUILD_SECS` with `BUILD_SECS` = 8, so 8 seconds, or 5 seconds with the Fast-track policy (build_mult 1.6). At 1.0 the plot becomes level 1 ("A new ... opened").
5. **Levelling up**: a built plot below its catalog `max` level (3 for most housing and industry, 2 for farm types) rolls each second: it levels up with probability 0.08 if `mood > 0.45`, the sector demand `dem_for(t) > 0.15`, and `coins > GROW_COST * scale * 4 + saving_for`. The upgrade costs `GROW_COST * scale * 1.6`.
6. **Effects**: housing is `home * level`, jobs `jobs * level`, upkeep and income scale with level.

Demand values (`res_dem`, `com_dem`, `ind_dem`, `off_dem`) are computed in `_second` from population, jobs, housing, mood, market and tax rates; farm-type zones use `dem_for` as a fraction of industrial demand.

Services (`kind == "svc"`) do not have levels or a construction phase: they appear at once when placed and work as soon as they are road-connected. Their upkeep is charged whenever they exist and are connected.

### Level loss, abandonment and removal

- **No road**: see above; the plot is idle but intact.
- **Damage**: `City._hit` removes one level from a zone (floor 0), used by storm, flood, quake and blizzard events. A level-0 plot remains as an empty zone.
- **Destruction**: `City._ruin` sets a zone's level to 0 (the zone plot stays and can regrow) and deletes any other building. Insurance pays 30 per ruined building if the policy is on.
- **Homes**: residents are removed when their home is unconnected, at level 0, or full (`home_load` over `_hcap`). Workers lose jobs the same way.
- **Bulldoze** (`City.bulldoze`): clears the tile (grid, level, build progress, fire) at no cost and with no refund.
- **Starvation of demand**: nothing demolishes a building because demand is low; levels are never reduced except by damage.

## Fires

Constants and rules from `City._fires`, `City.ignite`, `City.burnable`:

- A building is **burnable** if it is not empty, not a road, a zone with `lvl > 0`, and not a park, playground, plaza, wind turbine or solar farm. Parks and roads therefore act as firebreaks.
- **Spontaneous fires**: a timer `next_fire` is reset to `rand(60, 110) / (1 + blds/80) / max(mod("fire_mult"), 0.2) / clamp(blds/14, 0.2, 1)` seconds; when it runs out one random burnable building (not already burning) is lit. Small towns therefore rarely burn; event fires use `ignite` too.
- **Spread**: each burning tile, every frame, has probability `dt * 0.12` (about 0.12 per second) to ignite one random orthogonal neighbour if burnable.
- **Burning time**: `burn[i]` counts seconds. The fire is put out when
  - the tile is covered by a fire station (`raw_cov(fire) > 0`, i.e. within station radius 7) and `burn > 3`, or
  - the weather is rain or storm and `burn > 9`.
  
  Otherwise at `burn > 14` the building is ruined (`_ruin(i, false)`: zone back to level 0, others deleted), counted in `burned`, and the sound `bad` plays.
- Each burning tile lowers the mood target: `-min(burning * 0.03, 0.2)`.
- `needs()` reports burning buildings, noting "no fire station!" when `cov["fire"]` is 0.
- Fire coverage is binary at the tile level (any value above 0).

## Disasters and recovery

Events are listed in [Events](events.md); this is what the engine does with their `inst` and `mods` fields (`City.trigger`):

| Instant effect | Implementation |
|---|---|
| `ignite n` | `City.ignite` n times (scaled by the event's coverage factor) |
| `damage f` | `City._damage`: each burnable building loses a level with probability f (zones only lose levels; the lvl write on other buildings has no effect) |
| `destroy n` | `City._destroy`: n random burnable buildings are ruined |
| `tornado` | Spawns `twister` at the left or right edge moving at speed 3 tiles/s; `City._twister` each frame: on each new tile it ruins burnable buildings in that tile (80%) and its 4 neighbours (30% each) and clears wire, pipe and sewer on each of those 5 tiles with 50% chance. When it leaves the map, a recovery offer is made. |
| `blackout` | One random power plant is put in `offline` for 40 seconds. `_flood` skips offline sources, so its supply is lost until it returns ("The power plant is back online.") |
| `infect n` | n random citizens become sick for 25-40 seconds |

Event `mods` such as `cov_water -0.6` (burst main) or `cov_power -0.2` (storm) are added in `cov_at`, so they apply to every home equally for the event's duration.

A damaging event scales with the matching coverage: `k = 1 - 0.7 * cov[scale]` multiplies its effect (for example fire safety softens fires).

**Recovery offer** (`City._offer_recovery`): after `damage`/`destroy` (and after a tornado leaves), if at least 2 buildings were recorded in `ruins`, a "recover" petition is added: fund a fast rebuild for `20 * ruins.size()` coins, valid for 2 days. Accepting with enough coins calls `City._rebuild` (restores empty tiles to their old type and zones to at least their old level, instantly) and gives +0.04 reputation; declining or ignoring clears the list (zones regrow slowly via normal growth, destroyed services stay gone). Either way `disasters_survived` increases when answered. Fire damage (`_ruin(i, false)`) is not recorded in `ruins`.

Territory loss in war (`City.cede`) clears the outermost 8-tile strip on that side, including roads.

## Overlays

Selected from the Overlays menu in the HUD (`Hud`), stored in `Main.overlay`, drawn per visible tile by `Main._overlay`:

| Overlay | What it draws |
|---|---|
| None | nothing |
| Pollution | brown tint of `clamp(poll_at * 2, 0, 1)`, alpha 0.6 |
| Land value | red-to-green by `land_val`, alpha 0.5 |
| Traffic | on road tiles, green to red by `traffic / 3` (avenue: `/ 8`) |
| Crime | red by `crime_val`, alpha 0.7 |
| ALL | pollution and crime tints at lower alpha, and on every building a row of six small boxes (power, water, fire, police, health, leisure; `ALL_DOTS`) green if `raw_cov > 0.3`, red otherwise; burning tiles show "FIRE" |
| Coverage: X | green (alpha `0.45 * raw_cov`) where `raw_cov(X) > 0`, a faint red where it is 0; for power, water and sewage this shows the satisfaction, so a short network shows pale green |

Plants that are `offline` are drawn dark with "OFF". The line layers (wires, pipes, sewers) are drawn at close zoom, with live lines distinguished from dead ones by `net_reach`.

## The `needs()` hints

`City.needs()` builds the list shown in the HUD in this order (each only when true):

1. N building(s) on fire (with "no fire station!" if `cov.fire` is 0)
2. Tornado crossing the city
3. N power plant(s) offline
4. N citizens sick
5. Decisions waiting in the Mayor's office
6. Election within 5 days (with polling)
7. Traffic jams, if `congestion > 0.3`
8. Most food is imported (`pop >= 30` and local food share < 0.4)
9. Protest in the streets
10. N citizens without work (`pop - employed >= 2`)
11. For each metric with `_need(m) > 0.3`: "X covers only N% of homes"
12. Long commutes (`avg_commute > 22`), shops far (`avg_shop > 14`)
13. High crime (`crime > 0.35`), pollution (`pollution > 0.2`)
14. Homes / shops / jobs in demand (`res_dem`, `com_dem`, `ind_dem` each > 0.3)
15. N plot(s) waiting for funds (connected zone plot, level 0, not started)
16. N plot(s) have no road access (any non-road building with `connected == 0`)
17. Funds are low (`coins < 40`)
18. "All quiet. Plan the next district." if nothing else applies

`City.goal_text()` gives the next unlock target. `Empire.row` uses the first two hints as dashboard flags.

## Plots, territory and annexing

Two scales of "plot" are used in the code and the UI:

- A **zone plot** is one tile of a zone type (see the lifecycle).
- A **region plot** is one town's whole 96 x 64 tile array. Towns are laid out on a grid by `gpos`, with `Main.spiral(n)` giving the n-th plot position; `Diplo.side(a, b)` tells which side of `a` the neighbour `b` lies on (only the four orthogonal neighbours count). Land from the shared `World` is copied into each town's arrays by `City.apply_world`.

### Territory

The town only owns the rectangle `terr`. Outside it `owns()` is false, the tiles are dimmed in the view, nothing can be placed (`place`, `bulldoze` both check `owns`), and they are not in `cells`.

### Annexing (EXPAND)

- `City.expand_cost()` = `120 * (1 + 0.5 * expansions)`: 120, 180, 240, ...
- `City.expand(dir, free)` (dir 0 north, 1 east, 2 south, 3 west) adds a strip of `EXPAND` = 8 tiles on that side if `can_expand(dir)` (the strip stays inside the 96 x 64 plot), charges the cost unless `free`, increments `expansions`, rebuilds `cells`, and rescans. From the default start (24, 16, 48 x 32) the town can annex north twice, east three times, south twice and west three times. Smaller or larger starts (setup option: 40x24, 48x32, 64x40) change this.
- The player does it from the HUD (command `expand`, `Cmd.run`); the planner does it automatically (`City._expand_auto`, see [Planner](planner.md#expansion-and-annexing)). Winning a war can annex a free strip from the loser (`Diplo.surrender`, which calls `cede` on the loser and `expand(k, true)` on the winner).
- `City.cede(dir)` is the reverse for a war loss: the outermost 8-tile strip is wiped (buildings, levels, lamps) and `terr` shrinks, unless the result would fall below 24 x 16.

### Founding a new town

`Main.found_town_at` / `Main.found_cost`: `FOUND_COST` 300 plus `FOUND_STEP` 120 per plot of distance (Chebyshev distance in region plots minus 1) from the nearest town. A site is refused if a town already stands there, if water touches the 13 x 3 strip where the seed road would go, or if the starting footprint has more than 35% water (`Main._site_ok`, `Main.found_block`). A new town starts with 300 coins. Not available in multiplayer.

## Ground, ore and water tiles

Terrain comes from the shared `World` (`client/scripts/world.gd`), a deterministic function of the world seed, when the town is created through `Main._new_town` (`City.apply_world`). `World.K` kinds are `SEA, RIVER, SAND, PLAIN, FOREST, HILL, ROCK`.

| Kind | Rule in the game |
|---|---|
| SEA, RIVER | Set `water[i] = 1` and clear any ore. Only roads (bridges) and lines may cross; water buildings need a wet neighbour |
| SAND, PLAIN, FOREST, HILL, ROCK | Plain buildable ground. These are stored in `ground` for drawing only (`Main`, `Art.terrain`, the town thumbnail); they have no gameplay effect |

World generation thresholds (`World._gen`): elevation below `SEA_LEVEL` 0.36 is sea; just above sea level (`< 0.39`) sand; above 0.64 hill; above 0.72 rock; otherwise forest if moisture > 0.58, else plain. Rivers follow the 0.5 line of a river field and only appear between elevation 0.38 and 0.64.

If the setup option "river" is none or painted, `apply_world(..., rivers=false)` turns all water into plain. In that case the world editor (`Cmd` command `water`, `City.set_water`) can paint or clear water on empty owned tiles; it refuses tiles that already have a building, line or lamp. `City.dry_built` clears water under existing buildings.

For a town without a shared world (tests, old saves) `City.gen_river` makes one random river across the plot: 2 to 4 tiles wide, wobbling within +-4 tiles of a base line placed 30 to 40% of the territory span from the middle.

### Ore

Ore is stored per tile as richness 1 to 3. From `World._gen`: on non-water ground, noise above 0.90 (plain, sand, forest) or 0.80 (hill, rock) places ore; richness 1, 2 or 3 as noise exceeds the threshold by 0, 0.03, 0.06. The built-in generator `City._gen_ore` (used in tests and fallback) makes 12 blobs of radius 2-3, three of them inside the starting area, each tile kept with 85% chance, richness `3 - d*3/(rad+1)` (integer division) by Manhattan distance `d` from the centre.

A Mine can only be placed where `ore > 0`. Its output scales with `mine_yield`, the sum of `level * max(ore, 1)` over mines. Ore under any building stays but is unreachable until the tile is empty again.

## Where in the code

| Topic | File and function |
|---|---|
| Constants (`W`, `H`, `EXPAND`, `BRIDGE_X`, `DIAMOND`, `BUILD_SECS`, `GROW_COST`) | `client/scripts/city.gd` top |
| Placement, bulldoze | `City.place`, `City.bulldoze`, `City._lamp_near`, `City._lay`, `City._nl`, `City._netm`, `City.wet_next` |
| Road adjacency | `City._road_next_to`; `connected` in `City._scan` |
| Road network, gates | `City._road_net`, `City._rebuild_astar` |
| Scan (counts, `prov`, `polluters`, `bt`) | `City._scan` |
| Networks | `City._net`, `City._net_solve`, `City._flood`, `City._near`, `City._live` |
| Coverage | `City.raw_cov`, `City.cov_at`, `City.cov_home`, `City.poll_at`, `City._need` |
| Crime, land value | `City._crime`, `City._land` |
| Growth and construction | `City._grow`, `City.dem_for` |
| Fire | `City._fires`, `City.ignite`, `City._light`, `City.burnable`, `City.covered`, `City._ruin` |
| Disasters | `City.trigger`, `City._damage`, `City._destroy`, `City._hit`, `City._twister`, `City._offer_recovery`, `City._rebuild`, `City.strike` |
| Money and productivity | `City._money` |
| Hints | `City.needs`, `City.goal_text` |
| Territory | `City.expand`, `City.expand_cost`, `City.can_expand`, `City.cede`, `City._rebuild_cells` |
| Terrain | `City.apply_world`, `City.gen_river`, `City._gen_ore`, `City.set_water`, `client/scripts/world.gd` |
| Overlays | `Main._overlay`, menu in `client/scripts/hud.gd` |
| Border links | `Diplo.side`, `Diplo.linked`, `Diplo.tmult` in `client/scripts/diplomacy.gd` |
| Founding | `Main.found_town_at`, `Main.found_cost`, `Main._site_ok` |

## Open questions

- Avenue upkeep: the catalog says 0.2 and the Buildings page shows 0.2, but `City._money` charges 0.12 per avenue tile. Is the catalog value stale or the budget line?
- Line upkeep: the catalog says 0.03 per wire, pipe and sewer tile; the budget charges 0.015 per tile through `up_svc`.
- Sewage description: the catalog text for the Sewage metric says uncovered homes "make people sick more often", but `City._sickness` does not read sewage coverage. The only gameplay links found are the mood term and `river_health`.
- Regional trade credit: in `City._money`, a town earns `0.2 * RATE` for each unit that every partner imports (`p.imports`), not only the units it exported. With three or more towns this may over-credit a town. Not verified against intent.
- `City._hit` writes `lvl[i] = 0` for non-zone buildings, which has no visible effect; the buildings are listed in `ruins` and `_rebuild` only restores them if they were erased. Intended behaviour for damaged services is unclear.
- A lamp placed by the player can be 2 tiles from another (only adjacency is refused), while the planner keeps lamps 3 apart. Probably intentional.
- Jobs are assigned by Manhattan distance, regardless of road connectivity, so workers can be assigned to unreachable workplaces. No handling beyond the 5-second retry was found.
