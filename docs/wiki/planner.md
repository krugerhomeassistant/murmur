# The planner (auto-growth AI)

The planner is the built-in city builder that zones plots, lays roads, power and water lines, builds services, annexes land and toggles policies on its own. It runs for planner-only towns (neighbours, spectate mode, unclaimed multiplayer towns) and, depending on three switches, for the player's own town as well.

Everything described here is in `client/scripts/city.gd` (class `City`) unless noted. Function names are given so you can jump to them. The mechanics it acts on (road adjacency, networks, coverage, territory) are explained in [Networks and the town map](networks.md); per-building numbers are in [Buildings](buildings.md), [City stats](stats.md), [Policies](policies.md) and [Constants](constants.md).

## Contents

- [Settings and who runs it](#settings-and-who-runs-it)
- [When the planner runs](#when-the-planner-runs)
- [Order of decisions](#order-of-decisions)
- [Policies and taxes](#policies-and-taxes-city_plan_policy)
- [Border roads and gates](#border-roads-and-gates)
- [Ore roads](#ore-roads-city_plan_ore_road)
- [Power, water and sewer lines](#power-water-and-sewer-lines-city_plan_net)
- [Traffic: avenues](#traffic-avenues-city_plan_traffic)
- [Services](#services-city_plan_service)
- [Zoning](#zoning-the-end-of-city_planner)
- [Expansion and annexing](#expansion-and-annexing)
- [Military buildings and threat](#military-buildings-and-threat)
- [Spectate and empire mode](#spectate-and-empire-mode)
- [Known limitations](#known-limitations)
- [Where in the code](#where-in-the-code)
- [Open questions](#open-questions)

## Settings and who runs it

Three per-town settings control the planner. They are saved with the town (`SAVE_KEYS`) and can be changed from the HUD (City menu, Policy tab, Empire tab) through the commands `auto_mode`, `auto_policy` and `auto_expand` (`Cmd.run`).

| Setting | Values | Default (`City` field) | Meaning |
|---|---|---|---|
| `auto_mode` | 0, 1, 2 | 2 | 0 = off. 1 = "zones only" (see the caveat below). 2 = zones plus roads and extra annexing triggers |
| `auto_policy` | bool | true | The council flips policies and nudges the residential tax (`_plan_policy`) |
| `auto_expand` | bool | true | The planner may buy land strips (`_expand_auto`) |

What `auto_mode` actually gates (all in `City._planner` and `City._plan_*`):

| Behaviour | Mode 0 | Mode 1 | Mode 2 |
|---|---|---|---|
| Policy / tax changes (`auto_policy` only) | still runs | still runs | still runs |
| Border roads (`_plan_gate`, planner-only towns), ore roads, power/water/sewer lines, avenue widening, service buildings, zoning | no | yes | yes |
| New street stubs (`_extend_road`) and annexing from the zoning step (`_expand_auto`) | no | no | yes |

Caveat: the HUD tooltip says that in "zones only" mode the planner never lays roads. In the code, mode 1 still lays border, ore and avenue roads (they check only `auto_mode == 0`); what mode 1 never does is `_extend_road` and `_expand_auto`. See [Open questions](#open-questions).

Who is a planner town: `City.human` is false. In a normal game the first town is the player's and all neighbours are planner towns (`Main._fresh`, neighbours get `human = false`, 400 coins). In spectate mode every town is a planner town. In multiplayer, towns nobody has claimed are planner towns (`client/scripts/networld.gd`). A planner town differs from a player town in more than the planner (see [Spectate and empire mode](#spectate-and-empire-mode)).

## When the planner runs

`City._second` is the per-second simulation step. It increments `plan_t` and calls `City._planner()` when `plan_t >= 8`, then resets it. So each town plans once every 8 simulation seconds (not real seconds: it scales with game speed). The counter starts at `_seq % 8` for each new town so towns do not all plan on the same second. Off-screen towns are ticked in batches (`Main` sets `lod = 3`), which does not change the cadence.

One planner run does at most one action, with the exception of `_plan_policy` which runs before everything else. Most actions return right after succeeding. A town therefore adds at most one thing every 8 seconds, and growth also depends on `City._grow` (construction, see [Networks](networks.md#building-lifecycle)) paying for and finishing the plots the planner zones.

## Order of decisions

`City._planner` in order:

1. If `auto_policy`: `_plan_policy()` (always runs, whatever the other gates).
2. Return if `auto_mode == 0` or `coins < 60`.
3. If the town is not human: `_plan_gate()`; return if it laid a road.
4. `_plan_ore_road()`; return if it laid a road.
5. `_plan_net()`; return if it laid lines.
6. If `congestion > 0.25`, avenues are unlocked and a 30% roll passes: `_plan_traffic()`; return if it widened a street.
7. With 60% probability: `_plan_service()`; return if it built a service.
8. Return if `coins < saving_for` (see below).
9. **Mood gate**: if `mood < 0.38` (population 40 or more) or `mood < 0.25` (smaller towns): call `_plan_service(true)` (forced, ignoring its result) and return.
10. **Open plots cap**: count zone plots at level 0; return if `open >= 3 + pop / 80` (integer division). This stops the planner stacking up more unbuilt plots than the construction system can fund.
11. Pick a zone type by demand weights, find candidate tiles, optionally extend a road or annex land, then place one plot (see [Zoning](#zoning-the-end-of-city_planner)).

Because of this ordering, infrastructure and services take priority over new zoning, and a town with low mood only builds services until mood recovers. Small towns (under 40 people) have the lower mood threshold so they can bootstrap.

### `saving_for`

`City.saving_for` is a treasury target. `_plan_service` resets it to 0 on every call, then sets it to `cost * 1.5 + 60` of the building it wants but cannot afford yet. While it is set:

- the planner returns at step 8 without zoning (`coins < saving_for`);
- `City._grow` refuses to level up a plot unless `coins > GROW_COST * scale * 4 + saving_for`;
- `City._grow` adds `0.7 * saving_for` to the money a plot needs before construction may start, except for homes while `res_dem > 0.3` ("homes pay for themselves").

Because `_plan_service` only runs on 60% of planner runs (and not at all when an earlier step returned), `saving_for` keeps its last value in between.

## Policies and taxes (`City._plan_policy`)

Runs first, every planner run, if `auto_policy` is on. Two parts.

**Tax nudge** (residential rate `tax_r`): if `income < 4` and `mood > 0.3` raise `tax_r` by 0.01 up to a maximum of 0.18; else if `mood < 0.25` and `tax_r > 0.10` lower it by 0.01 down to 0.10. (Reason in the code: upkeep grows with town size, so a planner that never touched the rate would starve.) The commercial and industrial rates are not touched.

**Policy rules**: a table of `[turn on when, turn off when]` conditions, evaluated in this order. The loop stops after the first change, so at most one policy flips per run.

| Policy | Turn on when | Turn off when |
|---|---|---|
| `watch` | `pop >= 30` and police cov < 0.5 | police cov > 0.8 |
| `recycling` | `pop >=` the waste `need_pop` and waste cov < 0.5 and `coins > 150` | waste cov > 0.8 or `coins < 60` |
| `transit_free` | `pop >= 60`, transit cov < 0.4, `coins > 400`, `income > 1` | `income < 0.2` |
| `free_school` | `pop >= 50`, edu cov < 0.5, `coins > 400`, `income > 1` | edu cov > 0.8 or `income < 0.2` |
| `clean_air` | `pollution > 0.35` and `mood < 0.55` | `pollution < 0.15` |
| `austerity` | `coins < 60` and `income < 0` | `coins > 250` |
| `curfew` | protest and police cov < 0.5 | no protest |
| `fast_track` | `res_dem > 0.5` and `coins > 300` | `res_dem < 0.1` or `coins < 100` |
| `stop_search` | `crime > 0.5`, police cov > 0.5, `mood > 0.45` | `crime < 0.25` or `mood < 0.35` |
| `community_police` | `pop >= 60`, `crime > 0.3`, `coins > 300`, `income > 1` | `crime < 0.15` or `income < 0.2` |
| `tourism` | `tour_sum > 2` and `coins > 200` | `coins < 100` or `tour_sum <= 0` |
| `biz_subsidy` | `com_dem < -0.1` and `coins > 200` | `com_dem > 0.1` or `coins < 100` |

The planner never touches `garrison` or `insurance`. The gap between on and off thresholds is deliberate hysteresis. Each change is written to the event log ("Council enabled/ended: ..."). Policy effects are in [Policies](policies.md).

## Border roads and gates

Planner-only towns (`not human`) make sure that real roads reach the border facing each neighbour, because trade, power and water imports and commuting between towns need a road at both ends of the shared border (`Diplo.linked`, `Diplo.tmult`).

**Gate count**: `City._road_net` flood-fills road tiles into connected components, keeps the biggest as `road_comp`, and counts, for each side (N, E, S, W), how many tiles of that component lie in the 3-tile band along that border (`gate[k]`). A side is "open" when `gate[k] > 0`. Roads that are not part of the biggest component do not count.

**`City._plan_gate`**: for each partner town, `Diplo.side(self, p)` gives the side `k` where it lies (only the four orthogonal neighbours in the region grid are sides; others return -1 and are skipped). If `gate[k] > 0` it is already open. Otherwise it first tries a dry route (`wet_ok = false`) and then, if none exists, a route that may cross water (bridges, 4x price). The first route found is built with `place(..., T.ROAD)` for at most 12 tiles per call, stopping at the first tile that cannot be placed (usually lack of coins). The next call continues from the stub because the stub joins `road_comp`. When it laid anything it sets the message "Planners laid a road toward <town>." and ends the planner run.

**`City._gate_route(k, wet_ok)`**: a breadth-first search that starts from every tile of `road_comp` and walks through owned tiles that are empty or roads (and dry unless `wet_ok`). It returns the first tile found that lies in the 3-tile border band of side `k` and is empty or a road outside `road_comp`. The path is rebuilt backwards and only non-road tiles are returned. A straight line is not used because it would get stuck behind the first building.

Player towns do not get this: the player has to build the border road. The HUD shows "needs a road to this border" in the Region tab and on the map.

## Ore roads (`City._plan_ore_road`)

Lets mines be zoned by making sure an ore tile has a road beside it.

Gates, all required: mines unlocked (`unlocked(T.MINE)`, peak population 100), `pop >= 60`, `coins >= 200`, no mine jobs yet (`mine_jobs == 0`), and a 30% random roll (the code comment says the dice keep the search cheap when no road can reach ore). It returns immediately if any empty, dry ore tile already has a road neighbour (a roadside deposit exists) or if there is no ore on empty dry owned tiles at all.

Otherwise: breadth-first search from the main road component through empty dry owned land until it reaches a tile adjacent to an empty ore tile, then lay up to 12 tiles of road along that path (5 each). Message "Planners laid a road toward an ore deposit."

## Power, water and sewer lines (`City._plan_net`)

Gate: `coins >= 30`. The three networks are tried in random order. For each network `m`:

1. Skip it if there is no supply and no plant of that kind exists (`net_sup[m] <= 0` and `_has_plant(m)` false).
2. Candidates: every home or workplace (`homes + works`, so also services with jobs, including the plants themselves) that is not a road, is not currently served (`net_val[m][i] == 0`), and `pop >= need_pop[m] - 10` (power 30, water 15, sewage 30 as they unlock at 40, 25, 40).
3. Pick one candidate at random. Take its adjacent road tile as the start.
4. Breadth-first search along **road tiles only** from that road until it reaches a tile that is already live (`net_reach[m] == 1`) or that touches a source building of that network.
5. Lay a line along that path from the target back to the start: 2 coins per tile that is not already laid, at most 30 tiles per run, stopping if coins fall below 2. Message "Planners laid power lines / water pipes / sewers."

So planned lines follow roads, always connect to the existing live network or a plant, and extend by up to 30 tiles per run. The plants themselves are built by `_plan_service`.

## Traffic: avenues (`City._plan_traffic`)

Called at step 6 only if congestion (`congestion`, from `City._traffic`) exceeds 0.25, avenues are unlocked (peak population 25), and a 30% roll passes. It picks the plain road tile with the highest traffic above 3, finds the axis (east-west if a road lies east or west of it, else north-south) and converts that tile and the tiles within 2 along the axis to avenues, 7 coins each (the price difference), only for tiles that are plain roads. Returns true if at least one tile changed.

## Services (`City._plan_service`)

Chooses and sites one `svc` building. `force` lowers the acceptance threshold (used by the mood gate). Skipped entirely if the town has no homes.

### Candidate filter

For each catalog entry with `kind == "svc"` that is unlocked:

- **Limit**: `have = number built`. The limit `lim` is `4 + pop / 25` for anything with an `out` (power, water, sewage sources), otherwise `1 + pop / 60` for buildings with a `prov` entry or `1 + pop / 150` for the rest (integer division). Overrides: Food mill `1 + farm_jobs / 30`; Foundry `1 + mine_jobs / 12` (skipped completely when `mine_jobs == 0`); Barracks, Military base and Radar post raise to at least `1 + int(threat * 2 * (1 + pop / 250))`; Naval yard `1 + int(threat * 2)` when a naval threat exists. Skip if `have >= lim`. The street lamp counts as such a service with `lim = 1 + pop / 60`.
- **Water buildings** (`"water": true` service entries: port, fishing dock, naval yard) are skipped, except the Naval yard when `naval_threat()` is true. Ports and docks are never planner-built.
- **Upkeep check**: `newup = up * (1 + pop/60) * mod(upkeep_mult) * RATE`. The building is skipped if `income - newup < (0.15 if score < 0.6 else -0.25)` and `coins < 600`. In words: a town short of cash only builds what it can afford to run, and high-scoring (urgent) buildings may push income slightly negative.

### Score

The score `sc` is a sum of the following terms (each only if it applies):

| Term | Value |
|---|---|
| Food mill with farms and local food share < 0.7 | +0.9 |
| Foundry with ore stock > 4, or none built yet | +0.9 |
| Warehouse (chain "store") when any stock >= 90% of `cap` | +0.6 |
| Trade depot (chain "trade") when `pop >= 60` and export flow > 0.2 | +0.5 |
| Source building (has `out`) for network `mk`, if `pop >= need_pop[mk]` | +1.0 if `net_sup[mk] <= 0`, else `clamp((dem - sup) / max(dem, 1) * 2, 0, 1)` |
| Provider of metric `mk`: `gap = 1 - cov[mk]`; for `light` and `justice` `gap *= clamp(crime * 2, 0, 1)` | `bonus` metrics: `+ gap * 0.25 * strength`; other metrics, if `pop >= need_pop[mk]`: `+ gap * strength` |
| Fire station when something has burned or is burning and `cov.fire < 0.6` | +0.8 |
| Military (only if `threat > 0`) | see [Military buildings and threat](#military-buildings-and-threat) |
| `coins > 800` | +0.15 |
| Has a grant, `coins > 1000`, `income > 3`, `pop >= 150` | +0.3 |
| Belongs to a tribe (`faction`) with mood < 0.5 and share > 0.1 | +0.6 |
| Has `tour` and `mood > 0.5` | +0.15 |
| Has `poll` (pollutes) | -0.1 |

After the upkeep check the score is divided by cost: `sc = sc / (cost / 100 + 0.5) + rand(0, 0.05)`. The best-scoring building above the threshold wins; the threshold is 0.2 normally, 0.02 when forced. Note the division: a cheap fire station (80) scores against `1.3`, a hospital (450) against `5.0`, so cheap fixes beat expensive ones of equal need.

### Money and siting

After the loop `saving_for` is reset to 0. If nothing qualified, return false. If `coins < cost * 1.5 + 60`, set `saving_for` to that amount and return false (this is the "save up" behaviour).

Candidate tiles: for a street lamp, road tiles without a lamp and with no lamp within 2 tiles (`not _lamp_near(i, 3)`); for everything else, empty dry tiles with a road on one of their four sides (the Naval yard also needs a wet neighbour). Shuffle, then sample up to 24 tiles and score each:

```
site = rand(0, 0.5)
for each home h:
    if the building pollutes and dist(h, tile) <= poll radius:  site -= 0.6
    if dist(h, tile) <= building radius:
        for each metric it provides:  if raw_cov(h, metric) < 0.5:  site += 1.0
```

The tile with the best score is used. It is rejected (returns false) if the best score is below 0.5 for any building that provides a metric, unless it is a Barracks, Base or Radar under threat. Buildings with no `prov` (power plants, mills, warehouses...) are always accepted; they are only steered by the pollution penalty among the 24 samples. On success the tile is set directly (`grid[bi] = best`, or `lamp[bi] = 1`), the cost is deducted, the message "Planners built a ..." is set and the map is rescanned.

## Zoning (the end of `City._planner`)

Reached only when the earlier steps did nothing and the gates pass.

### Choosing a zone type

Types considered: Residential, Apartment, Commercial, Industrial, Office, Farm, Mine, each only if unlocked. Each gets a weight and one is picked by a weighted random draw.

- Weight: `max(dem_for(t), 0) * 3 + 0.5`, where `dem_for` returns the demand of the type's sector (`res_dem`, `com_dem`, `ind_dem`, `off_dem`; farm = `ind_dem * 0.5 + 0.1` plus up to `0.3 * (1 - food_local)` when a mill exists; mine = `ind_dem * 0.3`). For farms with a mill there is an extra `(1 - food_local) * 0.8`.
- Excluded: Apartments unless `res_dem >= 0.3` and `pop >= housing * 0.9`; any type with `dem_for < -0.2` (except Mine); Mines when `pop < 60` or `mine_jobs >= 8 + 12 * foundries` (mines wait for a foundry).
- If nothing is eligible, return.

The base 0.5 means even zero demand has a chance, with demand tilting the odds (a demand of 1.0 weighs 3.5).

Variants chosen after the draw:

- Farm becomes one of Farm (weight 3), Orchard (1), Ranch (1, plus 2 if local food share < 0.7 and no mill), Greenhouse (0.5, plus 2 if the current season's harvest factor < 0.6), Fish farm (1, only if `river_health > 0.4`), filtered by unlock (`City._farm_variant`).
- Residential becomes a housing style from the block's land value (`City._style_for`, using `land_val`): Residential (weight 1); Cottage (weight 2) if land value > 0.5; Townhouse (1) if > 0.42 and `pop >= 40`; Luxury condo (2) if > 0.68 and `pop >= 120`; Tenement (1) if land value < 0.5 and `res_dem > 0.5`. Each needs its building unlocked.

Land value (`City._land`, every 10th second) is `0.5 + (0.1 * mood - 0.2 * crime) - 0.6 * pollution_at_tile + sum(weight * coverage)` clamped to 0..1, over leisure 0.12, education 0.08, health 0.08, culture 0.06, transit 0.06, power 0.04, water 0.04, minus half the building's crime value.

### Candidate tiles and roads

Candidates are empty, dry, owned tiles with a road on one of the four sides (and, for a Mine, `ore > 0`; for a Fish farm, a wet neighbour). If a Mine has no candidate the run ends. If a Fish farm has none, a Farm is used instead.

In mode 2, for types other than Mine: if there are fewer than 6 candidates, or (`roads + avenues < 14 + pop * 0.6` and a 25% roll passes), the planner first tries `_extend_road()` and returns if it built. If that fails and there are fewer than 6 candidates and `auto_expand` is on, it tries `_expand_auto()` (see below) and returns on success. Then it proceeds with whatever candidates exist.

**`City._extend_road`** (needs `coins >= 40`): finds road tiles with two free tiles beyond them in a direction (the first inside the territory shrunk by 2, the second inside it), where the first has no road beside it on either side. Picks one such frontier at random and lays 3 to 6 road tiles (random) outward, 5 coins each, stopping at water, a building, the territory margin, another road to the side (after the first tile) or lack of coins (under 5). Message "City planners laid a new street."

### Siting

Shuffle candidates, score up to 16 with `City._site_score(t, i)` and take the best. The score starts at a random 0 to 0.6, then

- Residential / Apartment: `- 3 * pollution + leisure cov + 0.5 * (health + education + transit cov)`;
- Commercial / Office: `+ 2 - 0.2 * min(distance to nearest home, 10) + 0.5 * transit cov`;
- Industrial / Farm: `+ 0.25 * min(distance to nearest home, 12)` (pushed away from homes);
- everything else: random only.

If the type was Residential, the housing style is then chosen with `_style_for` at the best tile. The plot is placed directly in `grid` with no coin cost (the city pays when construction starts in `City._grow`), the message "Planners zoned a new ... plot." is set, and the map is rescanned.

## Financial focus (`City.focus`, Budget tab)
Five weights 0-2 (1 = neutral): industry, farming, mining, military, services. They multiply the zoning weight of industrial and office plots (industry), farms (farming) and mines (mining), and the score of military buildings (barracks, base, radar, naval yard, armoury) or service buildings that provide a metric (services). Make or buy: mining focus below 0.4 stops mines and foundries being built (the town buys ore and metal on the market); military focus below 0.4 stops armouries being built, and an existing armoury runs at `min(focus,1)` of capacity, so the town buys arms (`Military._pay`). With **Council sets focus** on (default, `auto_focus`), `City._auto_focus` sets farming from the local food price over base 1.5, mining from the ore price over 0.8 (both clamped 0.5-2) and military from `1 + 2*threat`; moving a slider (command `focus`, value 0-200) turns it off. Saved with the town (`focus`, `auto_focus`); hostile values read as 1.0. Test: `client/tests/focus.gd`.

## Ask before building (`City.ask_build`)
Policies tab, "Ask before planners build services" (command `ask_build`, saved with the town). On a human-run town, `_plan_service` no longer places the chosen service building; `City._propose` adds a decision of kind `build` (building id `bid`, cell, cost, expires in 3 days) to the Mayor's office list, at most two at a time and one per building type. Yes (Build) places it and charges the cost if the cell is still free and the treasury covers it; No (Veto), an expired decision, or an impossible build sets `vetoed[id] = day + 10`, and `_plan_service` skips that building until then. Zoning, roads and utility lines are not asked about. Test: `client/tests/propose.gd`.

## Expansion and annexing

`City._expand_auto` is called only from the zoning step (mode 2, `auto_expand`, fewer than 6 candidate tiles, `_extend_road` failed). Conditions and behaviour:

1. Return false unless `coins >= expand_cost() * 1.5`, where `expand_cost() = 120 * (1 + 0.5 * expansions)`.
2. For each side count the non-empty owned tiles in the 3-tile band along that edge (north: `y <= top + 2`, east: `x >= right - 3`, south: `y >= bottom - 3`, west: `x <= left + 2`). Roads and services count as well as zones.
3. Sort the sides by count, highest first, and annex the first side where `can_expand(d)` is true (the strip must stay inside the 96 x 64 plot). `expand(d)` charges the cost, adds an 8-tile strip and rescans.

Towns that are enclosed on every side stop growing. Annexing from the player's side is manual (HUD buttons, command `expand`). See [Networks](networks.md#plots-territory-and-annexing) for what a strip is and how territory is lost in war.

## Military buildings and threat

Only planner towns (`not human`) react to threat; for a player town `thr` is 0 and military buildings are only scored by the normal coverage terms (their `defence` and `police` providers).

`City.threat()` returns 0 to 1:

- 1.0 if any partner is at war with the town;
- otherwise, for each partner without a treaty and with opinion `Diplo.rel(self, p) < -0.2`: `clamp(-rel * 0.8, 0, 0.8)`, multiplied by 1.0 if that partner's military power plus 0.3 exceeds the town's (`Military.power`), else 0.5. The highest value over partners is used.

`City.naval_threat()` is true if a partner connected by river (`Military.river`) is at war with the town or has opinion below -0.2.

In `_plan_service` with `thr > 0`:

| Building | Score bonus | Limit |
|---|---|---|
| Barracks | `+ thr * 3` if barracks count is at most twice the base count, else `+ thr * 1` | at least `1 + int(thr * 2 * (1 + pop/250))` |
| Military base | `+ thr * 5` | same |
| Radar post | `+ thr * 3` if fewer than 2 radars per base, else `+ thr * 0.5` | same |
| Naval yard (needs `naval_threat`) | `+ thr * 6` | `1 + int(thr * 2)` |

The large bonuses exist because scores are divided by cost, so military would otherwise never win. These buildings also pass the siting check even when no home is poorly covered. Unit production for planner towns is separate: `Military.econ` calls `Military.adapt` every 10 seconds to re-weight training toward counters of the enemy's unit classes (`client/scripts/military.gd`, see [Units](units.md)).

## Spectate and empire mode

**Spectate** (setup option, also the dedicated multiplayer server and the benchmark): `Main._fresh` sets, for every town, `human = false`, 400 coins, `auto_mode = 2`, `auto_policy = true`, `auto_expand = true`. There is no mayor. What `human = false` changes besides the planner steps already listed:

- Border roads (`_plan_gate`) and threat-driven military are active.
- `Civics` stages are skipped: no petitions, elections or civics milestones (`City._second`, `_raise_petition`, `_civics`).
- The treasury is floored at 30 each tick (`City.tick`: "neighbours are kept alive by the state") and the town can never go bankrupt or be abandoned; a human town ends the game below the debt limit (-150) or when everyone leaves.
- `Military.econ` re-weights unit training automatically.
- Diplomacy: only a non-human town acts as an AI aggressor (`Diplo`, requires opinion below -0.7 and a military lead).

**Empire mode** uses the same planner. `client/scripts/empire.gd` only adds a dashboard row per town, treasury transfers (`Empire.send`, `Empire.rebalance`) and bulk setting changes: the command `apply_all` can set `auto_mode`, `auto_policy`, `auto_expand`, `train` and `tax` on every town on your side (`Empire.BULK`, `Empire.mine`; the same side means the same multiplayer owner, or all human towns offline). `Empire.row` flags problems using the first two `needs()` hints. The empire dashboard does not have its own build queue; delegating a town means leaving it on the planner (`auto_mode` 2).

## Known limitations

- **One action per 8 seconds**, no look-ahead. Roads are single straight stubs of 3 to 6 tiles; there is no block or grid design, so layouts are loose and can leave plots without a second road.
- **No demolition or replacement.** The planner never bulldozes and never rebuilds a lost building except by zoning anew. Roads are never upgraded except by `_plan_traffic` widening.
- **Lines follow roads only.** `_plan_net` searches along road tiles, serves one random unserved building per run and lays at most 30 tiles, so large unserved areas take many runs.
- **Few lamps.** A lamp counts as a service with `lim = 1 + pop / 60`, so the planner lights only a handful of tiles in a large town.
- **No ports, fishing docks or other water buildings**, and only a Naval yard under river threat. The planner does not use bridges except in `_plan_gate`'s fallback route (and never to reach ore: `_plan_ore_road` avoids water completely).
- **Mood gate stall.** Under the mood gate the planner returns after `_plan_service(true)` whether or not it built anything. If no service passes the lowered threshold (0.02) and mood stays under 0.38 (0.25 for tiny towns), the town stops zoning. The self-check in `City.selfcheck` retries up to three fresh towns because of a known earlier stall.
- **Gates need an orthogonal neighbour.** `Diplo.side` only knows N, E, S, W, so diagonal neighbours never get a border road.
- **Policy decisions are threshold-based** and ignore their cost over time; the planner never uses `garrison`, `insurance`, or the commercial/industrial tax rates, and never takes loans.
- **Annex only on zoning shortage.** A walled-in town with free candidate tiles will not annex even if its roads are stuck; and with `auto_mode == 1` it never annexes.
- **Randomness.** Many choices use `City.rng`; two runs of the same layout differ unless seeded (the benchmark seeds with `bench_seed`).

## Where in the code

| Topic | Function (`client/scripts/city.gd` unless noted) |
|---|---|
| Entry point and ordering | `City._planner`, called from `City._second` (`plan_t`) |
| Settings | `auto_mode`, `auto_policy`, `auto_expand`; commands in `client/scripts/cmd.gd`; UI in `client/scripts/hud.gd`; defaults for new games in `Main._fresh` (`client/scripts/main.gd`) |
| Policies and tax | `City._plan_policy`, `City.set_policy` |
| Gates | `City._plan_gate`, `City._gate_route`, `City._road_net`; `Diplo.side`, `Diplo.linked`, `Diplo.tmult` (`client/scripts/diplomacy.gd`) |
| Ore road | `City._plan_ore_road` |
| Lines | `City._plan_net`, `City._has_plant` |
| Avenues | `City._plan_traffic`, `City._traffic` |
| Services | `City._plan_service`, `City.threat`, `City.naval_threat`, `City._lamp_near` |
| Zoning | `City.dem_for`, `City._farm_variant`, `City._style_for`, `City._site_score`, `City._extend_road`, `City._land` |
| Annexing | `City._expand_auto`, `City.expand`, `City.expand_cost`, `City.can_expand` |
| Funds handoff | `City.saving_for`, `City._grow` |
| Spectate / human flag | `Main._fresh`, `City.human`, `City.tick`, `City._second`, `client/scripts/networld.gd` |
| Empire tools | `client/scripts/empire.gd`, `Cmd.run` (`apply_all`) |
| Unit training for planner towns | `Military.econ`, `Military.adapt` in `client/scripts/military.gd` |
| Regression check | `City.selfcheck` (planner growth test) |

## Open questions

- **"Zones only" tooltip.** The Policy tab tooltip says zones-only mode never lays roads, yet `_plan_gate`, `_plan_ore_road` and `_plan_traffic` run in mode 1. Is the tooltip out of date, or should those steps check `auto_mode == 2`?
- **Mode 1 and annexing.** `_expand_auto` is nested under the mode-2 check, so "Auto-annex" does nothing in mode 1 even when ticked. Probably unintended.
- **Policy rule order.** The rules table is iterated in insertion order and only the first change per run is applied, so earlier rules (watch, recycling) can delay later ones. Whether this ordering is intended was not documented.
- **Tax nudge scope.** Only the residential rate is adjusted; commercial and industrial taxes stay at their initial values. Intent unknown.
- **Lamp limit.** `1 + pop / 60` lamps for the whole town looks very low next to the lamp radius of 4; check against the design before tuning.
- **Planner `human` coupling.** `human` is overloaded: it decides planner extras, civics, bankruptcy and treasury floor all at once. In multiplayer, a player who has not joined leaves a town on the full planner behaviour.
- **Threat numbers.** The 0.8 factor, the 0.3 power margin and the 0.5 discount in `City.threat()` are not commented; the effect on garrison size was not measured.
