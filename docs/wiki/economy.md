# Economy

How money works in Murmur: where income comes from, what it costs to run a town, how demand and construction are paid for, and how the goods and trade chain feeds into it. Everything here is read from the code; function names are given as `City._xyz` (file `client/scripts/city.gd`) so the rule can be found quickly. Line numbers refer to the code at the time of writing and will drift.

Summary:

- The treasury (`City.coins`) changes once per simulated second by `City.income`, which `City._money` recomputes every second as the sum of the seventeen lines of `City.budget_lines`.
- Every revenue line and most expense lines are scaled by `City.RATE` (0.08), so catalogue numbers such as "upkeep 0.6/s" are not the coins actually lost per second.
- Revenue per sector depends on employment, the tax rate for that sector, education, power/water/health coverage, the market signal and land value. Expenses scale with `1 + pop / 60`.
- Zones are built and upgraded by the city itself and paid from the treasury; the player pays only for the zone paint, services, roads, network lines and land.
- Food and goods are produced into a stock, consumed by the population, and the shortfall is bought at a price; the surplus is sold. Warehouses, depots and ports change how much is sold and at what price.
- Debt is allowed down to `City.DEBT_LIMIT` (-150). Below that the game ends for a human-controlled town.

Related generated pages: [Buildings](buildings.md), [City stats](stats.md), [Policies](policies.md), [World events](events.md), [Civics](civics.md), [Constants](constants.md). See also [Citizens](citizens.md) for mood, unemployment and population, which feed back into the numbers below.

## Time and units

| Quantity | Value | Source |
|---|---|---|
| Simulation step | 0.1 s (`STEP` in `main.gd`) | `Main._process` |
| City rules tick | once per accumulated 1.0 s of simulated time (`City._second`) | `City.tick` |
| Day length | 60 sim seconds (`DAY_SECS`), the clock runs 24 h per day | `City.tick` |
| Season length | 7 days (420 s); year 28 days (`Civics.YEAR_DAYS`) | `City._second`, `civics.gd` |
| Income scale | `RATE` = 0.08 | `city.gd` constants |

"Per second" always means per simulated second. The game speed buttons change how many sim seconds pass per real second, not the rates. Off-screen towns run the same rules in 0.5 s batches (`City.lod`, `City.pend`); only the slow analyses (crime, land value) run less often there.

`City.tick(dt)` does `coins += income * dt` every step, using the `income` value computed at the last `_second`. So between two `_money` evaluations the income is held constant.

## The income formula

`City._money(market)` (line 1641) builds `budget_lines`, an array of `[label, value]` pairs. `income` is the plain sum of the values (revenue positive, costs negative). `inc_tax` (kept for tests) is only the four tax lines summed.

| Line | Value |
|---|---|
| Residential tax | `r_tax` |
| Commercial tax | `r_com` |
| Industrial tax | `r_ind` |
| Office tax | `r_off` |
| Tourism | `r_tour` |
| Events | `mod("income_add") * RATE` |
| Military funding | `grant_sum * RATE * mod("grant_mult")` |
| Regional trade | `trade_net` |
| Roads | `-e_roads` |
| Buildings | `-e_zone` |
| Services | `-e_svc` |
| Policies | `-e_pol` |
| City staff | `-e_staff` |
| Crime losses | `-e_crime` |
| Exports | `+ex` from `City._trade` |
| Imports (food, goods) | `-imp` from `City._trade` |
| Loan repayments | `-e_loan` |

### Shared factors

These are computed at the top of `_money` and reused by several lines.

| Name | Formula | Meaning |
|---|---|---|
| `econ` | `1 + 0.5 * market` | The market signal (-1..1, see Market and news below). Range 0.5 to 1.5. |
| `prodm` | `(1 - 0.2*_need("health")) * (1 - 0.25*_need("power")) * (1 - 0.15*_need("water")) * mod("prod_mult")` | Productivity. Each `_need` is 0 until the town is big enough to care and then ramps up to the uncovered share (see Citizens, mood). Worst case from coverage alone is 0.8 x 0.75 x 0.85 = 0.51. |
| `wise` | `1 + 0.3 * cov["edu"]` | Education coverage bonus, up to +30%. |
| `fin` | `(1 + 0.12 * cov["finance"]) * mod("tax_mult")` | Banking coverage bonus, up to +12%, and event multipliers on tax. |
| `f` | `RATE`, halved while `protest` is true | `protest` is true when mood is below 0.2. |
| `emp` | `employed / max(jobs, 1)` | Filled share of all jobs. `employed` includes commuters from neighbouring towns. |
| `laf_c` | `(tax_c/0.10) * (1 - max(0, tax_c - 0.10) * 3)` | Laffer-style curve for the commercial rate. |
| `laf_i` | the same with `tax_i` | Industrial rate. |

`cov[m]` is the average coverage of metric `m` over all homes, including policy and event modifiers (`City._scan`, see [City stats](stats.md)).

The Laffer factor equals 1.0 at the default 10%. It peaks at about 1.41 near a 21.7% rate and then falls; at 40% it is 0.4 and at 50% it is negative. Sample values:

| Rate | 5% | 10% | 15% | 20% | 25% | 30% | 40% | 50% |
|---|---|---|---|---|---|---|---|---|
| `laf` | 0.50 | 1.00 | 1.28 | 1.40 | 1.38 | 1.20 | 0.40 | -1.00 |

The tax slider in the Budget tab runs 0 to 30 percent (`hud.gd`, `HSlider.max_value = 30`). The command layer (`Cmd`, `cmd.gd`, "tax") clamps to 0..0.5, so a multiplayer or scripted client can set a rate where `laf` is negative.

### Tax lines per sector

All use the factors above. `jobs`, `shop_jobs`, `fac_jobs`, `off_jobs`, `farm_jobs`, `orch_jobs`, `ranch_jobs`, `green_jobs`, `fish_jobs`, `mine_jobs` are sums of `jobs * level` over built, road-connected zones, counted in `City._scan`.

Residential:

```
r_tax = employed * tax_r * 12 * econ * prodm * wise * fin * f * res_mult * (0.75 + 0.5 * land_avg)
```

- Only employed citizens pay. Unemployed and sick citizens pay nothing; commuters from neighbouring towns count as employed (`commuters_in`).
- `res_mult` is `tier_sum / max(housing, 1)`, the housing-weighted average of the `tier` of the residential zone types (default 1.0; Cottage 1.35, Townhouse 1.1, Tenement 0.6, Condo 2.0; see [Buildings](buildings.md)).
- `land_avg` is the mean land value of occupied homes (0..1, default 0.5). The land-value factor therefore runs from 0.75 (land value 0) to 1.25 (land value 1). See [Citizens](citizens.md#land-value).
- There is no Laffer curve: revenue is linear in `tax_r`. The cost of a high rate is paid in mood, see below.

Commercial:

```
sales = min(pop * 0.6, shop_jobs * 2) * (1 + 0.25 * cov["commerce"]) * mod("sales_mult")
        * (1 - 0.3 * clamp((avg_shop - 8) / 20, 0, 1))
r_com = sales * 0.8 * econ * prodm * laf_c * fin * f
```

- Sales are capped either by customers (0.6 per citizen) or by shop capacity (2 per shop job). Demand for shops is `com_dem`, see below.
- `avg_shop` is the mean walking distance in tiles from homes to the nearest shop (flood fill in `_second`, capped at 40). Beyond 8 tiles the sales fall, up to -30% at 28 tiles or more.
- Markets and malls raise `cov["commerce"]`.

Industrial:

```
goods = (fac_jobs * 0.6 * emp
        + (farm_jobs + orch_jobs + ranch_jobs + green_jobs + fish_jobs) * 0.3
        + mine_jobs * 0.4 * emp) * mod("goods_mult")
r_ind = goods * 1.2 * econ * prodm * wise * laf_i * fin * f
```

- Farm-type jobs earn a flat 0.3 per job whether or not they are filled (they are not multiplied by `emp`); factories and mines scale with `emp`.
- This `goods` variable is a tax-income figure and is unrelated to the physical `stock["goods"]` produced in `_trade` (see the goods chain below).

Office:

```
r_off = off_jobs * emp * 1.6 * econ * prodm * (0.5 + 0.5 * cov["edu"]) * mod("office_mult") * laf_c * fin * f
```

Offices use the commercial rate (`laf_c`) and have no `wise` factor but a stronger education dependency: half speed with no education coverage.

Tourism:

```
r_tour = tour_sum * 3 * econ * mood * mod("tour_mult") * f
```

`tour_sum` adds the `tour` value of each connected service building that has one (stadium 2.0, theme park 3.5, museum 1.0, hotel 1.5 and so on, see [Buildings](buildings.md)). Note it multiplies the current city `mood` (0..1), so unhappy towns earn less from visitors. `tour_mult` merges the Tourism campaign policy (x2), summer (x1.3), the Arts collective tribe (x1.2 content or x0.8 angry) and event modifiers.

Events and military:

- `Events` line: `mod("income_add") * RATE`. Only the Troops deployed (+10) and Base review (-10) events use this key, so the effect is +0.8 or -0.8 per second.
- `Military funding`: `grant_sum * RATE * mod("grant_mult")`. `grant_sum` adds the `grant` of connected buildings (Military base 8, Barracks 3, Radar post 1.5, Naval yard 5). The generated [Buildings](buildings.md) page describes grants as "free coins per day"; in the code they are per second, scaled by `RATE` (a base pays 0.64 per second).

## Expenses

```
mult   = 1 + pop / 60
um     = mod("upkeep_mult")
e_roads = (roads * 0.08 + avenues * 0.12) * mult * um * RATE
e_zone  = up_zone * mult * um * RATE
e_svc   = up_svc  * mult * um * RATE
e_pol   = (sum of policy "up" for active policies) * RATE
e_staff = pop * 0.3 * RATE
e_crime = crime * pop * 0.3 * RATE
```

- `roads` counts every road tile including avenues, and `avenues` counts avenues only, so a plain road costs 0.08 and an avenue 0.20 (0.08 + 0.12) before the multipliers, matching the catalogue.
- `up_zone` is the sum of `up * level` of every built, road-connected zone. Empty zone paint costs no upkeep.
- `up_svc` is the sum of `up` over connected service buildings, plus 0.1 per street lamp, plus 0.015 per power/water/sewer line tile (`nets * 0.015`, added in `City._net`). The catalogue lists 0.03 for line tiles but the code charges 0.015 (see Open questions).
- Policy upkeep is not multiplied by `mult` or `um`. Austerity has a negative `up` (-1.0) and therefore reduces `e_pol`.
- `mult` is the "size has a cost" term: a town of 120 pays three times the catalogue upkeep for every building.
- Buildings that are not connected to a road (`connected[i] == 0`) are skipped in `_scan` and pay no upkeep, but also do nothing.
- `upkeep_mult` comes from Austerity (0.85), winter (1.1), and events such as Inflation (1.25), Oil shock (1.15), Snow (1.08), Blizzard (1.1), Road works (1.05). Multipliers combine by multiplication (`City._add_mods`).

Catalogue upkeep, as shown in the build menu ("Upkeep 0.6/s") is the value before `mult`, `um` and `RATE`. A Police station (up 1.0) in a town of 60 therefore costs `1.0 * 2 * 0.08 = 0.16` coins per second at default modifiers.

Crime losses: `crime` is the mean crime score of homes (0..1); see [Citizens](citizens.md#crime). At crime 0.4 and 100 citizens the loss is `0.4 * 100 * 0.3 * 0.08 = 0.96` per second.

## Worked example

A town of 40 citizens, all employed, default 10% taxes, neutral market, no coverage bonuses, land value 0.5, all housing standard (`res_mult` 1), 12 shop jobs, no protest:

- `r_tax = 40 * 0.1 * 12 * 0.08 = 3.84`
- `r_com`: `sales = min(24, 24) = 24`, `r_com = 24 * 0.8 * 0.08 = 1.54`
- `e_staff = 40 * 0.3 * 0.08 = 0.96`
- `mult = 1.667`; 30 road tiles cost `30 * 0.08 * 1.667 * 0.08 = 0.32`
- Revenue 3.84 + 1.54 minus staff 0.96 and roads 0.32 leaves about +4.10 per second before building and service upkeep

## Policies and money

`City._collect_mods` merges the modifiers of active policies, active events, tribe opinions, the season and wars into `City.mods`, every second. Keys ending in `_mult` multiply (default 1.0); all others add (default 0.0). The money-related keys:

| Key | Read in | Effect |
|---|---|---|
| `upkeep_mult` | `_money`, `_plan_service` | multiplies roads/zone/service upkeep |
| `tax_mult` | `fin` in `_money` | multiplies all four tax lines |
| `sales_mult` | `sales` | commercial sales |
| `goods_mult` | `goods` in `_money` and `_trade` | industrial income and physical goods output |
| `office_mult` | `r_off` | office income |
| `tour_mult` | `r_tour` | tourism |
| `prod_mult` | `prodm` | productivity factor of all tax lines except tourism |
| `income_add` | Events line | flat coins per second times `RATE` |
| `grant_mult` | Military funding | multiplier on grants |
| `crime_mult`, `crime_add` | `_crime` | crime score, thus `e_crime` |
| `dem_res`, `dem_com`, `dem_ind`, `dem_off` | demand | added to the demand figures |
| `build_mult`, `build_cost_mult` | `_grow` | construction speed and cost; see Construction |
| `insured` | `_ruin` | +30 coins per destroyed building |
| `power_dem` | `_net_solve` | raises power demand (winter +25%) |
| `cov_<metric>` | `cov_at` | adds to coverage of that metric |

Full per-policy and per-event lists are in [Policies](policies.md) and [World events](events.md). Money effects worth knowing:

- Business subsidies: sales and goods x1.12 for a policy upkeep of 1.5 (0.12 coins per second after `RATE`).
- Tourism campaign: tourism x2 for a policy upkeep of 1.5.
- Clean air rules: goods x0.9 (the price of halving pollution).
- Austerity: upkeep x0.85 and saves 1.0 per second of policy upkeep, but mood -0.05.
- Policies with a mood term (curfew -0.04, stop and search -0.03) are a trade of coins against mood, because mood drives growth, protests (which halve revenue) and approval.
- An auto-policy council exists, see Planner behaviour.

## Demand

`City._second` computes four demand figures in -1..1 each second (lines 1596-1601):

```
tc = (tax_c - 0.10) * 4          ti = (tax_i - 0.10) * 4
res_dem = clamp((jobs + 4 - housing) / 8 + (mood - 0.5) + mod("dem_res"), -1, 1)
com_dem = clamp((pop*0.5 + 2 - shop_jobs) / 6 + market*0.2 - tc + mod("dem_com"), -1, 1)
ind_dem = clamp((pop*0.9 + 2 - jobs) / 6 + market*0.2 - ti + mod("dem_ind"), -1, 1)
off_dem = clamp((pop*0.25 - off_jobs) / 6 * (0.4 + 0.6*cov["edu"]) - tc + mod("dem_off"), -1, 1)
```

- Housing demand is high when there are more jobs than homes and when the city is happy.
- Commercial demand wants one shop job per two citizens and falls with the commercial tax above 10% (-0.04 per percentage point).
- Industrial demand wants about 0.9 jobs per citizen in total, counting every job type (`jobs`), not only industrial ones, and falls with the industrial tax.
- Office demand needs education coverage to open up and shares the commercial tax term.
- The residential tax does not enter demand directly; it enters mood (see [Citizens](citizens.md#mood)).

`City.dem_for(t)` maps a zone's `sector` to a figure:

| Sector | Demand |
|---|---|
| res | `res_dem` |
| com | `com_dem` |
| ind | `ind_dem` |
| office | `off_dem` |
| orchard, ranch, green, fishfarm | `ind_dem * 0.4 + 0.05` |
| mine | `ind_dem * 0.3` |
| farm | `ind_dem * 0.5 + 0.1` plus `0.3 * (1 - food_local)` if a mill exists |

Demand gates two things:

- Upgrading a built zone one level (`_grow`): needs `dem_for(t) > 0.15`, `mood > 0.45`, coins above the threshold in Construction, and passes a 8% per-second dice roll per zone.
- The planner's choice of what to zone next (`_planner`): a kind is skipped if its demand is below -0.2 (mines are exempt), and the pick is random with weight `max(dem, 0) * 3 + 0.5`. Apartments are only offered when `res_dem >= 0.3` and `pop >= housing * 0.9`; mines need a pop of 60 and wait for foundry capacity (`mine_jobs < 8 + 12 * foundries`).

Demand does not gate the first building on a freshly painted zone: any connected empty zone starts construction when the treasury allows (next section).

## Construction

Painting and placing (`City.place`):

- The coin cost is `Catalog.DEFS[t]["cost"]`, deducted immediately. The tile must be owned (`terr`), unlocked (`peak >= unlock`, where `peak` is the highest population ever reached), empty and, for a road on water, `cost * BRIDGE_X` (4.0). Only roads may be built on water; ports, fish farms, fishing docks and naval yards must touch water (`wet_next`); a Mine needs an ore tile.
- Street lamps go on road tiles (min spacing check `_lamp_near(i, 2)`), network lines (power/water/sewer) cost 2 per tile.
- Zone paint is cheap (Residential 10, Commercial 15, Industrial 20, Office 25, Farm 8 ...). The building itself is paid later by the city.

Building a zone (`City._grow`, called every second):

```
scale = (1 + blds / 15) * mod("build_cost_mult")      # blds = total built levels
start cost   = GROW_COST * scale * (zone cost / 15)   # GROW_COST = 25
upgrade cost = GROW_COST * scale * 1.6
```

- Each second, up to 3 empty connected zone cells (random order) are started if `coins >= cost + 40 + hold`. `hold` is `saving_for * 0.7`, except that homes ignore it while `res_dem > 0.3`.
- Construction takes `BUILD_SECS` = 8 seconds: `build[i]` rises by `max(mod("build_mult"), 1.0) / 8` per second from 0.01, and at 1.0 the zone becomes level 1. With Fast-track permits (`build_mult` 1.6) it takes 5 seconds.
- An upgrade to the next level (max level 3, or 2 for farm-type zones, see [Buildings](buildings.md)) is bought instantly at `GROW_COST * scale * 1.6` when `coins > GROW_COST * scale * 4 + saving_for`.
- The cost grows with the size of the town (`blds / 15`). With 30 built levels, `scale` is 3: a Residential start costs `25 * 3 * (10/15) = 50` and an upgrade `120`.
- `mod("build_cost_mult")` is read but no policy or event in `catalog.gd`, `events.gd` or `civics.gd` sets it, so it is always 1.0 at present.
- Service buildings are paid at once by whoever places them (the player, or the planner in `_plan_service`).

Other one-off costs:

| Item | Cost | Code |
|---|---|---|
| Land expansion (+8 tiles on one side) | `120 * (1 + 0.5 * expansions)` | `City.expand_cost` |
| Auto-expansion | only when `coins >= 1.5 * expand_cost()` | `City._expand_auto` |
| Planner road extension | 5 per tile, 40 coins minimum in the treasury | `City._extend_road` |
| Planner wires/pipes | 2 per tile, up to 30 per run | `City._plan_net` |
| Planner avenue upgrade | 7 per tile | `City._plan_traffic` |
| Disaster rebuild | `20 * ruins` | `City._offer_recovery` |
| Campaign rally | 150 (`Civics.RALLY_COST`) | `City.rally` |
| Festival (player event) | 40 | event `festival` |

## Planner behaviour (spending without the player)

Every 8 seconds `City._planner` runs for every town, human or not, while `auto_mode` is 1 or 2 (default 2: plots and roads). In order it may: apply auto-policies, lay a road to a neighbour (planner towns only), lay a road toward ore, lay power/water/sewer lines, widen a jammed road, build the best-scoring service, then zone a new plot. It requires `coins >= 60` (auto-policies run before that check) and stops before zoning while `coins < saving_for`.

`saving_for` is set by `City._plan_service` (line 2058): the planner scores every unlocked service building by how much it would lift an uncovered need, divided by `cost / 100 + 0.5`. If the winner costs more than `coins` allows (`coins < cost * 1.5 + 60`), `saving_for` becomes `cost * 1.5 + 60`; otherwise it is 0. While set, it pauses upgrades (they need coins above `saving_for` too), reserves 70% of it against non-home plots, and stops the planner zoning. A service is also skipped if `income - newup < 0.15` (or `-0.25` for a strong candidate) and the town has under 600 coins, where `newup` is the building's upkeep after `mult`, `um` and `RATE`.

`City._plan_policy` also adjusts taxes and policies for you when `auto_policy` is on (it is on by default, `City.auto_policy`): if `income < 4` and `mood > 0.3` it raises `tax_r` by 0.01 up to 0.18; if `mood < 0.25` and `tax_r > 0.10` it lowers it by 0.01. It switches policies such as Austerity (`coins < 60 and income < 0`), Free transport, Recycling and Business subsidies on and off with hysteresis (rules in the `rules` table in the function). The auto-policy council can be turned off in the City menu.

## Jobs, housing and unemployment

All from `City._scan` and `City._second`.

- `housing` = sum of `home * level` over built connected residential zones. `jobs` = zone jobs (`jobs * level`) + `svc_jobs` (staff of connected service buildings, the `jobs` field in the catalogue).
- A citizen is employed if `work >= 0` and not sick. Job assignment is explained in [Citizens](citizens.md#homes-and-jobs).
- `commuters_in = min(pop - employed, int(open_other * 0.4))`, where `open_other` is the sum over neighbouring towns of `max(jobs - employed, 0) * Diplo.tmult(self, p)`. Commuters are added to `employed`, so they count for the unemployment rate and for the residential tax.
- `unemp = 1 - employed / pop` (0 if no citizens). It lowers mood (`0.3 * unemp`), raises crime (`0.5 * unemp`) and drives the union tribe's opinion.
- Employment only counts for money through `employed` (residential tax) and through `emp = employed / jobs`, the fill rate used by factory, mine and office lines.

Practical consequences: too many jobs and too few citizens lowers `emp` and revenue from factories and offices; too many citizens and too few jobs leaves taxpayers at zero and mood falling.

## Goods chain, stock and flow

> The fixed unit prices below are now base prices: the live price of each good comes from the shared [market](market.md). Import and export lines use `Signals.mk.price`.

`City._trade(market)` (line 3235) runs inside `_money` every second. It keeps `stock = {crops, food, goods, ore, metal}`, a storage `cap`, and reports `flow` (per-second values for the UI and for `food_local`).

Storage and trade infrastructure:

```
cap  = 60 + 250 * warehouses
deps = depots + 2 * ports
```

Crops, mining and food:

```
crops = (farm_jobs + 1.5*orch_jobs) * emp * 0.12 * season_harvest + green_jobs * emp * 0.12 * 0.85
mined = mine_yield * emp * 0.05          # mine_yield = sum of level x ore richness (1-3) over mines
smelt = min(stock.ore + mined, foundries * 2)
stock.ore   += mined - smelt
stock.metal += smelt * 0.5
mused = min(stock.metal, fac_jobs * emp * 0.02);  stock.metal -= mused
milled = min(stock.crops + crops, mills * 3)
fish  = fishing docks * 6 * emp * 0.15 * river_health
stock.crops += crops - milled
stock.food  += milled + fish + ranch_jobs*emp*0.1 + fish_jobs*emp*0.12*river_health
goods = (fac_jobs * emp * 0.06 + mused * 3) * mod("goods_mult");  stock.goods += goods
```

- `season_harvest` is `Civics.SEASONS[season]["harvest"]`: Spring 0.6, Summer 1.0, Autumn 1.8, Winter 0.2. Greenhouses ignore the season (flat 0.85).
- Crops are inedible until a Food mill turns them into food at up to 3 units per second per mill. Orchards give 1.5 times the crops of a field; ranches, fish farms and fishing docks produce food directly and need no mill.
- `river_health` falls when sewage is untreated (`City._net`: `raw = max(pop - 20, 0) * 0.15`; health moves 0.02 per second toward `clamp(sewage_treated / raw, 0, 1)`). Polluted rivers reduce fish output.
- Ore can be sold raw or smelted into metal by a Foundry (2 ore per second each, yielding 0.5 metal per ore). Metal is consumed by factories to make extra goods (each metal used makes 3 goods) and sells at the highest price.

Consumption and imports:

```
fneed = pop * 0.05                 gneed = pop * 0.03 + shop_jobs * 0.02
fl = min(stock.food, fneed)        gl = min(stock.goods, gneed)    # taken from stock
price = 1 + 0.3 * market
imp = ((fneed - fl) * 1.5 + (gneed - gl) * 2.0) * RATE * price     # coins per second spent buying the shortfall
```

The share satisfied locally is `flow["food_local"] = fl / fneed` and `flow["goods_local"]`. Low food self-sufficiency has three consequences: the import bill; mood -0.03 once `pop >= 40` and `food_local < 0.3`; and planner bias toward farms and a mill (`dem_for` farm term, `_plan_service` mill score when `food_local < 0.7`).

Exports:

```
xp  = price * 0.8 * (1 + 0.25 * deps)
lim = cap * (0.2 if deps > 0 else 0.8)
for each stock k above lim:
    sell = (stock[k] - lim) * (0.25 if deps > 0 else 0.5)
    ex  += sell * unit_price[k] * RATE * xp
    stock[k] -= sell
stock[k] = min(stock[k], cap)      # overflow is lost
```

Unit prices: crops 0.6, food 1.5, goods 2.0, ore 0.8, metal 3.0.

- Without depots or ports the town sells only what is above 80% of its storage, half of the excess per second. With a Warehouse the 80% line is higher in absolute terms; without one the cap is 60, so the line is 48 units.
- With at least one depot (or port, which counts as two), selling starts at 20% of storage, so stock is exported continuously, and each depot-equivalent adds 25% to the price.
- Stock above `cap` is discarded every second (`stock[k] = minf(stock[k], cap)`), so harvests are wasted when there is no warehouse space. Autumn harvests are the main case: the Warehouse description recommends storing them for winter.
- `exported` accumulates the units sold and feeds the First exports and Trading hub milestones (50 and 500 units, rewards 150 and 500; `Civics.MILESTONES`).

Because local use is taken before selling, a town that consumes everything it grows never exports; a surplus is needed.

### Regional trade lines

Between neighbouring towns of a multi-town world only power, water (and sewage, uncharged) move, see `City._net`:

```
surplus = partner.net_own[m] - partner.net_dem[m]
take    = min(max(surplus, 0) * 0.6 * Diplo.tmult(self, partner), demand - supply)
```

and the money (`_money`):

```
trade_net = -(imports.power + imports.water) * 0.4 * RATE            # you pay for what you import
            + sum over partners of (partner.imports.power + partner.imports.water) * 0.2 * RATE   # you earn for what you export
```

`Diplo.tmult` (diplomacy.gd) is 0 for embargo, war or an unlinked border; otherwise `clamp(0.6 + 0.5 * avg_relation, 0.2, 1.3)`, times 1.25 under a trade pact or 1.4 under an alliance. A border link needs a road from each town reaching the shared edge (`City._road_net` sets `gate`). The same multiplier governs commuters.

Sewage imports are tracked in `imports["sewage"]` but only power and water are charged or paid for in `trade_net`.

## Power, water and sewage in money terms

Networks matter for money mainly through coverage: `_need("power")` and `_need("water")` appear in `prodm` (see above), `_need("health")` too. Each lost point of power coverage costs up to 25% of the productivity of all tax lines (except tourism); water 15%; health 20%.

`City._net` and `_net_solve` compute supply and demand per line type:

- Supply: each working plant that touches a line adds `out * (1 + mod(m + "_out"))` (Wind 8, Solar 14, Coal 40, Water tower 14, Sewage plant 16 units). A plant is "working" if it has an adjacent or own-tile line cell and is not in `offline`.
- Demand: for each live building, zones need `0.5 * level * (1 + (home + jobs) * 0.1)`, services need 1.0, plants and empty zones need nothing; power demand is multiplied by `1 + mod("power_dem")`.
- Satisfaction is `clamp(supply / demand, 0, 1)` (1 if demand is nearly zero, 0 if there is no supply) and is written to every live cell as `net_val`, which `raw_cov` returns as coverage for `power`, `water` and `sewage`.

## Debt, loans and failure

- `City.DEBT_LIMIT` = -150. In `City.tick`, a human town whose `coins` fall below it ends the game with "Bankrupt." Towns with `human == false` are floored at 30 coins.
- Instant event losses (`coins`, `coins_pop` in `City.trigger`) cannot push the treasury below -40: `coins = max(coins + x, min(coins, -40))`.
- Negative coins also stop growth (growth thresholds above), and approval takes -0.1 while `coins < 0` (`City._civics`).
- Loans (`City.take_loan`, data in `Civics.LOANS`; up to 3 open, town must have reached `minpop` as `peak`):

| Loan | Amount | Term | Rate | Min peak pop | Total repaid | Per second |
|---|---|---|---|---|---|---|
| Small loan | 500 | 8 days | 10% | 0 | 550 | 1.146 |
| Bank loan | 1500 | 16 days | 18% | 60 | 1770 | 1.844 |
| City bond | 4000 | 40 days | 25% | 150 | 5000 | 2.083 |

`pay = amount * (1 + rate) / (days * 60)` is deducted every second through the "Loan repayments" budget line and from the loan's `left` balance until zero; no early repayment exists in the code. The interest is simple, charged up front on the total. The Treasurer advisor warns against new borrowing while loans are active (`City.advisors`).

## Market and news signals

`Signals` (signals.gd) holds two global values in -1..1, `market` and `news`, plus the current weather. One `Signals` object is shared by all towns of a world (`Main.sig`), so a boom in one town benefits all. Both values move toward 0 at 0.02 per second (`Signals.tick`), so a +0.7 boom fades in 35 s and a -0.8 scandal in 40 s.

Only events write them (`inst.market`, `inst.news` in `City.trigger`): Market boom +0.7, Market crash -0.7, plus news changes by social, crime and military events (see [World events](events.md)). Live data feeds are described as future work in `signals.gd`.

Market effects: `econ = 1 + 0.5 * market` multiplies all four tax lines and tourism; `com_dem` and `ind_dem` get `+0.2 * market`; trade `price = 1 + 0.3 * market` for both imports and exports; the Business tribe's opinion gets `+0.2 * market`.

News effects: mood `+0.3 * news` (see [Citizens](citizens.md#mood)) and the Reform movement's opinion `+0.2 * news`.

## What a player can do to improve income

Each item follows directly from the formulas above.

1. Keep everyone employed. `r_tax` is proportional to `employed`, and `emp` scales factories, mines and offices. Match jobs to citizens: `jobs` should be near `pop`, not far above.
2. Raise coverage of Education (up to +30% on residential and industrial tax, up to doubling office income from the 0.5 base), Banking (+12% on all taxes), and keep Health, Power and Water covered to avoid the `prodm` loss (up to 49%).
3. Place Markets or a Mall near homes (`commerce` coverage, +25% sales) and keep shops within 8 tiles of homes (`avg_shop`).
4. Mind the tax rates. Residential revenue is linear in `tax_r` but each point above 10% lowers the mood target by 0.02 and, over 12%, approval by 1.5 per unit (`City._civics`). Commercial and industrial revenue peak near 21.7%, but demand for those zones falls 0.04 per point.
5. Avoid protests (mood under 0.2): every tax and tourism line is halved.
6. Land value raises `r_tax` by up to +25% (see [Citizens](citizens.md#land-value)); mixed housing tiers matter via `res_mult`.
7. Produce food locally (farms plus a mill, ranches, fish farms, fishing docks) to avoid the import bill and mood penalty.
8. Build a Warehouse and a Trade depot (or Port) to sell surplus continuously; the Foundry and a Mine turn ore into metal worth 3 per unit.
9. Add tourism buildings (stadium, theme park, museum, hotel) together with the Tourism campaign; keep mood high because tourism scales with it.
10. Cut waste in upkeep: avoid services nobody needs, since each pays `up * (1 + pop/60) * RATE`; use Austerity when mood allows; do not let crime run (it costs `0.3 * crime * pop * RATE` per second plus the mood penalty).
11. Trade power and water surplus with neighbours at a good relation (earns 0.2 per imported unit times `RATE`).
12. Take a loan only if the new buildings return more than the interest; the repayment is a fixed line item.
13. Use Fast-track permits during booms to cut construction time to 5 s.

## Where in the code

| What | Where |
|---|---|
| Income lines, upkeep, taxes | `City._money` (city.gd, ~1641) |
| Constants `RATE`, `DEBT_LIMIT`, `GROW_COST`, `BUILD_SECS`, `BRIDGE_X`, `DAY_SECS` | top of `city.gd` |
| Per-second driver | `City._second` (~1442), `City.tick` (~2752) |
| Demand | `City._second` (~1596), `City.dem_for` (~1703) |
| Construction and upgrades | `City._grow` (~1722), `City.place` (~507) |
| Planner and saving | `City._planner` (~1924), `City._plan_service` (~2058), `City._plan_policy` (~2257) |
| Goods, stock, trade | `City._trade` (~3235) |
| Utilities | `City._net`, `City._net_solve`, `City._flood` (~893-1010) |
| Modifier merging | `City._collect_mods` (~1249), `City._add_mods` |
| Loans | `City.take_loan` (~2985), `Civics.LOANS` |
| Signals | `signals.gd`; events in `events.gd` |
| Border trade multiplier | `Diplo.tmult` (diplomacy.gd) |
| Building data | `Catalog.DEFS` (catalog.gd); policies `Catalog.POLICIES` |
| Seasons | `Civics.SEASONS` (civics.gd) |
| Army upkeep and training costs | `Military.econ` (military.gd), see [Units](units.md) |

## Open questions

- Line tile `up` in `Catalog.DEFS` is now 0.015, matching `nets * 0.015` in `City._net`; avenue `up` is 0.12, matching the budget.
- The generated Buildings page says a grant is paid "per day"; the code pays `grant * RATE` per second.
- `mod("build_cost_mult")` is read in `_grow` but no data file sets it.
- The old design notes said protests cut income by 30%; the code uses `f = 0.5 * RATE`, so the tax and tourism lines halve (trade, exports, imports and expenses are unaffected).
- `trade_net` and the neighbour supply code ignore sewage imports, although they are computed.
- The `immigration` expression in `City._second` is written `mod("immig_mult") / 1.0 * 0.9`; the `/ 1.0` has no effect.
- `City.auto_policy` defaults to true for human towns too, so the council moves the player's residential tax between 10% and 18% and toggles policies unless the player disables auto-policies. Whether that is intended for human towns is not stated in the code comments.
- Military unit upkeep (`Military.econ`) is subtracted directly from `coins` once per second and does not appear in `budget_lines`, so it is invisible in the Budget tab.
