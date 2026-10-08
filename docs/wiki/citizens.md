# Citizens

How the people of a town are created, where they live and work, how they move, and how the town's mood, crime, pollution, health, land value and traffic are computed. Everything is read from the code. Functions are named `City._xyz` (file `client/scripts/city.gd`) unless another file is given; line numbers are approximate and will drift.

Summary:

- A citizen is a `City.Citizen` object with a home, an optional workplace, a tribe, a name and a few random personality values. Citizens are created by immigration (`City._spawn`) when the town has free housing and is content, and removed by emigration, illness, or loss of their home.
- Homes are random, jobs are the nearest free workplace by Manhattan distance, and citizens walk along roads using A* path-finding with a daily schedule.
- The town has a single mood value (0..1) that moves 0.05 per second toward a target made of a base of 0.72 plus or minus many terms. Individual citizen mood is the town mood plus a personal bias.
- Crime, pollution and land value are computed per map cell and averaged over homes. Health coverage and an infection model drive sickness. Traffic comes from citizens who drive.
- Weather, seasons, events and policies enter through the shared modifier table (`City.mods`) and the weather penalty.

Related pages: [Economy](economy.md), and the generated references [City stats](stats.md), [Buildings](buildings.md), [Policies](policies.md), [World events](events.md), [Civics](civics.md), [Constants](constants.md).

## Where citizens come from

### Data

`City.Citizen` (city.gd top) holds: `id`, `home`, `work`, `fav` (today's leisure spot), `at` (cell they are inside, -1 while walking), `pos`, `path`, `shift`, `spd`, `fast`, `bias`, `mood`, `commute`, `tribe`, `nm`, `sick` (seconds of illness left), `car`, `protesting`.

### Creation

`City._spawn()` (~line 1117):

- Candidate homes are the entries of `homes` whose current load (`home_load`) is below capacity `_hcap(i) = home * level`. If none, no citizen is created.
- Home: uniformly random among candidates (not the nearest to jobs).
- `id`: the running counter `next_id`.
- Name `nm`: uniformly random from `Catalog.FIRST_NAMES` (25 first names: Ada, Ben, Cleo, Dev, Elif, Finn, Gus, Hana, Ivo, June, Kofi, Lena, Milo, Nadia, Omar, Pia, Quin, Rosa, Sam, Tara, Uma, Vic, Wren, Yara, Zed). Names repeat; only `id` is unique.
- `off`: a random offset in [-0.14, 0.14] on both axes so walkers on the same road do not overlap.
- `bias`: uniform in [-0.08, 0.08] (a personal mood offset, see Mood).
- `shift`: uniform in [-1.2, 1.2] hours (the citizen's daily schedule is offset by this amount).
- `spd`: uniform in [0.8, 1.25] (walking speed factor).
- `tribe`: `_roll_tribe()`, a weighted pick.

Four citizens are created at the start of a new town in `seed_start`.

### Tribes

Weights in `Catalog.TRIBES` (catalog.gd), which sum to 100:

| Tribe key | Name | Weight |
|---|---|---|
| `church` | Congregation | 14 |
| `union` | Workers' union | 30 |
| `business` | Chamber of commerce | 12 |
| `artists` | Arts collective | 8 |
| `rebels` | Reform movement | 10 |
| `club` | Social club | 26 |

A citizen keeps the same tribe for life. Each second `City._tribes()` computes each tribe's opinion:

```
opinion = clamp(0.5 * average citizen mood of the tribe + 0.5 * (satisfaction + favor[tribe]), 0, 1)
```

where `favor[tribe]` is the standing earned or lost by answering petitions (`City._civics`, clamped to -0.4..0.4, decaying 0.0008 per second toward 0) and `satisfaction` is:

| Tribe | Satisfaction |
|---|---|
| church | `0.5 + (0.3 if a Church exists else -0.2) - 0.3*crime` |
| union | `0.6 - 1.5*unemp - 2*(tax_i - 0.10) + (0.15 if a Union hall exists)` |
| business | `0.6 - 3*(tax_c - 0.10) - 2*(tax_i - 0.10) + 0.1*com_dem + 0.2*market + (0.15 if a Chamber exists)` |
| artists | `0.3 + 0.7 * cov["culture"]` |
| rebels | `0.6 - 0.25 (curfew) - 0.25 (stop and search) - 0.2 (protest) + 0.2*news` |
| club | `0.3 + 0.6 * cov["leisure"]` |

(An empty tribe uses an average mood of 0.6.) A tribe affects the town only if the town has at least 20 citizens and the tribe is at least 8% of them. An opinion above 0.65 is "content" and below 0.38 is "angry". The effects, added to `City.tribe_mods`, are:

| Tribe | Content | Angry |
|---|---|---|
| church | `mood` +0.02 | `mood` -0.02 |
| club | `mood` +0.02 | `mood` -0.02 |
| union | `prod_mult` x1.05 | `prod_mult` x0.9 |
| business | `sales_mult` x1.08 | `sales_mult` x0.9 and `goods_mult` x0.9 |
| artists | `tour_mult` x1.2 | `tour_mult` x0.8 |
| rebels | none | `crime_add` +0.1 |

An "angry" tribe is also written to the event log when it becomes angry. Tribe opinions also feed the mayor's approval rating (`City._civics`) and petitions (`City._raise_petition`); see [Civics](civics.md).

## Homes and jobs

Housing: `housing` is the sum of `home * level` over built, road-connected residential zones (`City._scan`); `_hcap(i)` is the capacity of one cell. Residents per level: Residential 4, Apartment 10, Cottage 2, Townhouse 6, Tenement 14, Condo 8 ([Buildings](buildings.md)).

Jobs: a workplace is a built connected zone with `jobs > 0` (capacity `jobs * level`) or a service building with a `jobs` value (capacity `jobs`, see `City._cap`). Both appear in `works`.

Each second, `City._second` does the following in order (lines ~1472-1515):

1. Evict citizens whose home is gone: a citizen is kept only if its home is still a built, connected residential cell with free capacity (capacity is checked in citizen order, so if a building was downgraded, the last citizens in the list lose their home). If any citizen is removed the message is "Residents left after losing their homes."
2. Keep jobs that are still valid (building exists, connected, level above 0, capacity not exceeded); otherwise set `work = -1` and `commute = 0`.
3. Build `open_works`, the workplaces with a free slot.
4. For every jobless citizen (list order), pick the workplace with the smallest Manhattan distance `|dx| + |dy|` to the home, store `commute` (that distance in tiles) and update the load. A full workplace leaves the list.

Consequences: there is no skill, tribe or wage matching; jobs are first-come by citizen order and nearest by straight Manhattan distance, not by path length; a citizen keeps a job until the building changes, so new jobs near a home do not pull an already employed citizen. The distance is the one stored in `commute` and used for the average, the mood penalty and the decision to drive.

Derived quantities (all recomputed each second):

```
employed   = citizens with work >= 0 and not sick, plus commuters_in
commuters_in = min(pop - employed, int(open_other * 0.4))      # open_other from partner towns, see Economy
unemp      = 0 if pop == 0 else 1 - employed / pop
avg_commute = mean of commute over citizens with a job (tiles)
shop_gap   = clamp(1 - shop_jobs / max(pop * 0.5, 3), 0, 1)
```

`avg_shop` is the mean over homes of the walking distance in tiles to the nearest shop (`shop_field`, a breadth-first flood over the map seeded from commercial zones, capped at 40 and rebuilt only when the layout changes).

Jobless citizens run errands on every day, not only at weekends; see the schedule below.

## Daily life: schedule and walking

### Clock

`DAY_SECS` = 60 sim seconds per day, so one sim second is 0.4 clock hours. Weekends are `day % 7 >= 5`. A citizen's local hour is `h = clock - shift`.

### What a citizen wants (`City._want`, ~2498)

In priority order:

1. If a protest is on (`protest`) and the citizen is `protesting`, and `9 <= h < 20`, go to the plaza (the road tile closest to the map centre, `plaza`).
2. If sick, stay home.
3. Weekend or jobless: errands at the favourite spot between 10-13 and 15-19; otherwise home.
4. Employed on a weekday: work from 7.5 to 16; from 16 to 19 two thirds go to the favourite spot (those with `(id + day) % 3 != 0`) and the rest home; otherwise home.

The favourite spot (`City._fav`) is rerolled every day: a random entry of `spots`, which holds built commercial zones and every service with `spot: true` (parks, plazas, cinemas, bars, churches, markets, malls, stadiums, theme parks, museums, union hall, chamber, town hall; see "Visited" in [Buildings](buildings.md)). It is reused only while the target still exists and is connected.

### Path-finding (`City._route`, `City._rebuild_astar`)

- The grid is an `AStarGrid2D` (96 x 64, 4-neighbour, no diagonals) whose only walkable cells are road tiles inside the owned territory. Avenue cells have weight 0.6, ordinary roads 1.0, so paths prefer avenues. `roads_dirty` triggers a rebuild on the next tick after any road is placed or bulldozed.
- A route goes from the road next to the citizen's current building (`_road_next_to`) to the road next to the destination, then the final leg into the building. Citizens only walk on roads; buildings without an adjacent road are unreachable and "work" nothing.
- If no path exists (disconnected road networks), `retry` is set to 5 seconds and the citizen tries again later.
- Paths are computed once and followed; a citizen already walking does not recompute if a road disappears (see Open questions).

### Speed (`City._move`, ~2551)

```
step = WALK(2.4) * dt * spd * mod("speed_mult") * (1.3 if fast)
if on an avenue tile: step *= 1.5
if car: step *= 2.2 / (1 + jam * 0.25)   with jam = max(0, traffic[cell] - (8 if avenue else 3))
```

- `fast` is true when the home's transit coverage exceeds 0.5 (`cov_home(home, "transit") > 0.5`), giving +30%. The stat text says "walk 30% faster" for covered homes; the code uses a threshold of 50% coverage.
- `speed_mult` comes from weather events and winter (see Weather and seasons).
- Buses are cosmetic vehicles that shuttle between a bus stop and a random spot (`_sync_buses`, `_bus_route`); they do not carry citizens, they only reflect the presence of stops. Transit effect comes from coverage.

### Driving

`car` is true when the citizen has a job, `commute > 9` tiles and the home is not in `fast` transit coverage. Cars move 2.2 times faster but leave traffic (next section).

## Traffic and congestion (`City._traffic`, ~3139)

Once per second:

```
traffic[i] *= 0.7                                   # decay on every owned cell
for each driving citizen currently walking: traffic[its cell] += 1
congestion = mean over cells with traffic > 0.3 of clamp((traffic - (8 if avenue else 3)) / 4, 0, 1)
```

- A plain road tolerates traffic 3 before it counts as jammed, an avenue 8. Congestion is 0 when no cell exceeds the limit and 1 when every busy cell is at the limit plus 4.
- `congestion` lowers the mood target by `0.08 * congestion` and shows in the needs list over 0.3.
- The planner widens the busiest plain road into an avenue (up to 5 tiles in line, 7 coins each) when `congestion > 0.25`, avenues are unlocked (population 25) and a 30% roll succeeds (`City._plan_traffic`).
- Avenues thus help twice: faster walking (1.5x) and a higher jam threshold (8 against 3).
- Free public transport and bus stops reduce the number of drivers because they set `fast`.

## Mood

### City mood

`City._second` (lines ~1569-1594) computes a target every second:

```
target = 0.72
       - 0.15 * shop_gap
       - min(0.03 * burning, 0.2)
       - 2.0 * (tax_r - 0.10)
       - 0.3 * unemp
       + 0.3 * news
       - WEATHER_PENALTY[weather]
       - sum over need metrics of  w * _need(metric)
       + sum over bonus metrics of w * cov[metric]
       - 0.08 * congestion
       - 0.25 * sick_n / max(pop, 1)
       - 0.03    if pop >= 40 and food_local < 0.3
       - 0.15 * pollution
       - 0.25 * max(crime - 0.1, 0)
       - 0.10 * clamp((avg_commute - 12) / 30, 0, 1)
       - 0.04 * clamp((avg_shop - 8) / 20, 0, 1)
       + mod("mood")
mood = move_toward(mood, clamp(target, 0, 1), 0.05)       # per second
```

Starting `mood` is 0.6. Each term:

| Term | Details |
|---|---|
| Base 0.72 | |
| `shop_gap` | 0 when shop jobs reach half the population (minimum divisor 3). |
| Fires | `burning` is the number of buildings currently on fire; each costs 0.03, capped at 0.2. |
| Residential tax | A rate of 10% is neutral; 0% gives +0.20, 20% gives -0.20, 30% gives -0.40. |
| Unemployment | 100% unemployment would cost 0.30. |
| News | `Signals.news` (-1..1), see [Economy](economy.md#market-and-news-signals). |
| Weather | Table below. |
| Needs | See below. |
| Bonuses | `cov["culture"]` x 0.05, `cov["defence"]` x 0.02, `cov["gov"]` x 0.04 (max +0.11). Retail and banking have weight 0. |
| Congestion | `City._traffic`. |
| Sickness | Share of citizens sick, up to 0.25. |
| Food | Only when most food is imported. |
| Pollution | Mean of homes' pollution, 0..1, see below. |
| Crime | The first 10% is free. |
| Commute | Zero up to 12 tiles, full 0.10 at 42 tiles. |
| Shops | Zero up to 8 tiles, full 0.04 at 28 tiles. |
| `mod("mood")` | The sum of all `mood` modifiers (policies, events, tribes, season, war). |

Note the speed: the mood changes at most 0.05 per second, so a 60 s event with `mood` -0.2 can move it by at most 0.2 and needs about 4 s to do so. Lasting changes show up within about 10 s.

Need metrics (`kind == "need"` in `Catalog.METRICS`) and their weights (`w`) with the population at which each starts to matter (`need_pop`, the smallest `unlock` value of any building that provides the metric, `Catalog.need_pop`):

| Metric | `w` | `need_pop` |
|---|---|---|
| Leisure | 0.12 | 8 |
| Water | 0.15 | 25 |
| Police | 0.06 | 30 |
| Waste | 0.08 | 35 |
| Power | 0.15 | 40 |
| Public transport | 0.06 | 40 |
| Sewage | 0.10 | 40 |
| Health | 0.10 | 50 |
| Education | 0.08 | 70 |

The need function is:

```
_need(m) = 0 if pop < need_pop
         = (1 - cov[m]) * clamp((pop - np) / (np * 0.8 + 5) + 0.25, 0, 1)
```

so the pull starts at one quarter strength when the town first reaches the need population and reaches full strength at `pop = 1.6 * np + 3.75` (for example 51 citizens for police, 86 for health, 116 for education). The maximum combined need penalty with zero coverage everywhere is 0.90. `cov[m]` is the average over homes of the coverage at the home cell, including policy, season and event modifiers (`cov_<metric>` keys), clamped to 0..1; power, water and sewage coverage is the network satisfaction (supply / demand) of the cell. Fire, light, justice, commerce and finance have `w = 0`, so they do not appear in the mood sum.

Weather penalty (`City.WEATHER_PENALTY`):

| Weather | clear | rain | heatwave | storm | snow | fog |
|---|---|---|---|---|---|---|
| Penalty | 0 | 0.05 | 0.10 | 0.20 | 0.05 | 0.02 |

### Individual mood and protests

```
citizen.mood = clamp(city mood + bias - (0.15 if jobless) - (0.08 if commute > 28), 0, 1)
protest = mood < 0.2                   # the city mood, not the individual
citizen.protesting = protest and citizen.mood < 0.35
```

Individual mood is shown in the citizen panel and used for the tribe averages; it does not feed back into city mood. During a protest the protesting citizens walk to the plaza from 9 to 20, and `_money` halves its revenue lines (see [Economy](economy.md)).

### What mood does

| Mood | Consequence | Where |
|---|---|---|
| > 0.45 | zones may be upgraded a level (together with demand and coins) | `_grow` |
| > 0.35 | immigration allowed if there is free housing | `_second` |
| < 0.2 | one random citizen leaves each second; protest begins | `_second` |
| < 0.25 (< 0.38 above pop 40) | the planner stops zoning and only builds services | `_planner` |
| any | residential demand gets `+(mood - 0.5)`, tourism income is proportional to mood, mayor approval target adds `0.5 * mood`, land value adds `0.1 * mood` | various |

## Population: immigration and emigration

`City._second` (~1603):

```
if mood > 0.35 and pop < housing:
    repeat (2 if res_dem > 0.5 else 1) times:
        with probability mod("immig_mult") * 0.9 : _spawn()
elif mood < 0.2 and pop > 0:
    remove one random citizen ("A family packs up and leaves.")
```

- Immigration therefore adds at most one or two citizens per second per town, only while homes are free. It does not depend on jobs, so a town with spare housing and mood above 0.35 keeps filling even without employment; unemployment then hurts through mood, crime and tax.
- `immig_mult` merges Spring (x1.15), Baby boom (x1.6), Tech boom (x1.5), Conscription (x0.7) and any others. A value above 1/0.9 saturates the probability at 1.
- Events can add or remove citizens directly (`inst.citizens`): Immigrant wave +8 if homes exist, Exodus -6.
- Citizens also leave when their home disappears, and die from illness (see Health).
- `peak` is the highest `pop` ever reached; it unlocks buildings and sets milestones. Losing citizens does not lock buildings.
- The game ends with "Everyone left" if `peak >= 10` and `pop < 1`.

The total population ceiling is `housing`, the sum of level capacities. Growth of housing is the economy's job: see [Economy](economy.md#demand) for `res_dem`.

## Land value

`City._land()` (~2291) recomputes `land_val` for every cell every 10 seconds (in towns with `lod` 1; off-screen towns do it every 10 *evaluations*, each happening on every `lod`-th second):

```
base = 0.1 * mood - 0.2 * crime
v    = 0.5 + base - 0.6 * pollution_field(cell) + sum_j wt_j * clamp(min(coverage_j(cell), 1) + cov_mod_j, 0, 1)
     - 0.5 * building crime value   (Tenement 0.18, Bar 0.08)
land_val[cell] = clamp(v, 0, 1)         # cells that are empty and not touching a building keep 0.45
```

Weights `wt_j` for the coverage metrics: leisure 0.12, education 0.08, health 0.08, culture 0.06, transit 0.06, power 0.04, water 0.04 (sum 0.48).

`land_avg` is the mean over built residential cells and is used in:

- `r_tax` (+/-25%, see [Economy](economy.md)),
- the housing style the planner picks (`City._style_for`: Cottage when land value is above 0.5, Townhouse above 0.42 and pop 40, Condo above 0.68 and pop 120, Tenement below 0.5 when `res_dem > 0.5`),
- the Desirable address milestone (land value 0.6).

The pollution field uses the same linear falloff as `poll_at` but sums over all polluters at once and is unaffected by the Clean air policy (`poll_mult` multiplies only the `pollution` average used for mood).

## Crime

`City._crime()` (~1031) runs every third second (every third *evaluation* in `lod` towns) and fills `crime_val` for every non-road building cell:

```
base = 0.08 + 0.5 * unemp + mod("crime_add")
sz   = clamp(pop / 50, 0.1, 1.0)                    # small towns have little crime
dens = number of non-empty cells in the 13-cell diamond (radius 2) around the cell, including itself
v = base + sz * (0.3 * dens/13 + 0.3 * (1 - clamp(police + cov_police_mod, 0, 1)) + building "crime" value)
v *= 1 - 0.25 * clamp(light + cov_light_mod, 0, 1)
v *= 1 - 0.35 * clamp(justice + cov_justice_mod, 0, 1)
crime_val = clamp(v * crime_mult, 0, 1)
```

`crime` is the average of `crime_val` over homes. The building "crime" values are Tenement 0.18 and Bar 0.08.

Effects of crime:

- Mood: `-0.25 * max(crime - 0.1, 0)`.
- Money: `e_crime = crime * pop * 0.3 * RATE` per second (see [Economy](economy.md)).
- Land value: `-0.2 * crime` in the base.
- Approval: `-0.1 * crime` in the target.
- The Congregation's satisfaction: `-0.3 * crime`.
- Reform movement angry: `+0.1` to the base (`crime_add`).
- Advisor text and the needs list over 0.35; a street-lamp and courthouse planner score scales with `crime`.

Ways to cut it: police coverage (reach per station is in [Buildings](buildings.md)), street lamps (up to -25%), justice coverage from courts and prisons (up to -35%), Neighbourhood watch (`crime_mult` 0.6), Curfew (0.5), Stop and search (0.7), Community policing (0.9), fewer unemployed, less dense building (the density term is up to 0.3 at full diamond density, scaled by town size), and avoiding Tenements. Fog multiplies crime by 1.4.

## Pollution

- Sources (`polluters`, filled in `_scan` for connected buildings): `[x, y, strength, radius]`. Zones: Industrial `[4, 0.35]` per level, Ranch `[2, 0.1]` per level, Mine `[4, 0.4]` per level. Services: Coal power plant `[10, 1.0]`, Landfill `[7, 0.6]`, Foundry `[3, 0.3]`, Sewage plant `[3, 0.3]`, Military base `[4, 0.2]`, Prison `[3, 0.15]`, Food mill `[2, 0.1]`.
- Exposure at a cell: `poll_at(c) = sum of strength * (1 - d / (radius + 1))` for sources within Manhattan distance `d <= radius`.
- `pollution = mean over homes of min(1, poll_at(home)) * mod("poll_mult")`. Clean air rules set `poll_mult` 0.5.
- Effects: mood `-0.15 * pollution`; land value `-0.6 * field`; planner site scores (`_site_score` -3x for homes); the needs list over 0.2; petitions from the Arts collective (clean air) when pollution exceeds 0.15.

## Health and sickness

Coverage of "health" (clinics 0.6, hospitals 1.0) enters in four places.

1. Mood: need weight 0.10.
2. Productivity: `prodm` factor `1 - 0.2 * _need("health")` (see [Economy](economy.md)).
3. Event scaling: Heatwave and Epidemic (`"scale": "health"`) shrink by `1 - 0.7 * cov["health"]` (`City.trigger`).
4. `City._sickness()` (~3112) each second:

```
sick citizens:  sick -= 1 + 2 * h              (h = health coverage at their home, 0..1)
                chance 0.002 * (1 - h) of dying that second
healthy citizens living or working at a building where someone is sick:
                chance 0.03 * (1 - 0.7 * h) of falling ill (20-35 s)
```

- Sickness is only started by events: Epidemic and similar events infect `inst.infect` random citizens (25-40 s). It then spreads only through shared home or workplace cells ("hot" cells), and stops when nobody is sick. There is no background illness.
- Sick citizens go home (`_want`), count as unemployed for `employed` (so they stop paying tax), and are not replaced at work.
- `sick_n / pop` lowers the mood target (0.25 per fraction). A death removes the citizen and logs "X did not survive the illness."
- Sewage coverage does not affect `_sickness`; the stat text no longer claims it does (fixed in the text pass).

## Weather and seasons

Weather is stored in the shared `Signals` object (`Signals.weather()`, set by events through `set_weather(name, seconds)`); it returns to "clear" when the timer ends, and a new weather event replaces the current one. Its effects on citizens:

- Mood: `WEATHER_PENALTY` (table above). Several events map to a weather: Drought and Heatwave to "heatwave", Cold snap and Blizzard to "snow", Flood to "rain".
- Walking speed: through `speed_mult` of the active weather events: Rain 0.9, Snow 0.7, Fog 0.85, Storm 0.75, Flood 0.7, Blizzard 0.6, plus Road works 0.8. Speeds multiply.
- Fire: while it rains or storms a fire is extinguished after 9 seconds instead of 14 (`City._fires`); coverage by a station still puts fires out after 3 s.
- Event modifiers: coverage drops (`cov_power` in Storm and Cold snap, `cov_water` in Heatwave, Drought and Water main, `cov_transit` in Blizzard), crime in Fog (x1.4), upkeep in Snow and Blizzard. Full list in [World events](events.md).
- Thoughts: citizens grumble about rain, storms and heat in `City.thought`.

Seasons (`Civics.SEASONS`, data in [Civics](civics.md)): `season = ((day - 1) / 7) % 4`, so days 1-7 are Spring, 8-14 Summer, 15-21 Autumn, 22-28 Winter. A year is 28 days (28 minutes of game time at normal speed). Each season adds modifiers while it lasts and reweights the random events:

| Season | Modifiers | Other |
|---|---|---|
| Spring | `immig_mult` 1.15, `mood` +0.02 | harvest x0.6; floods and rain likelier |
| Summer | `tour_mult` 1.3, `fire_mult` 1.3 | harvest x1.0; heatwave, drought, storm, wildfire likelier |
| Autumn | `mood` 0.0 (no effect) | harvest x1.8; harvest fair, storms, fog likelier |
| Winter | `upkeep_mult` 1.1, `power_dem` +0.25, `speed_mult` 0.9, `mood` -0.02 | harvest x0.2; snow, cold snap, blizzard likelier |

For citizens the direct effects are the mood terms, immigration in spring, and walking speed in winter. Indirect effects come through food (crops and thus `food_local`, see [Economy](economy.md#goods-chain-stock-and-flow)), power demand and upkeep.

## Other events that touch citizens

- Fires and tornadoes destroy buildings; the owners lose homes and are evicted at the next `_second`.
- A war removes mood: `-0.03` per active war and `-0.004` per battle fought (up to 15 battles) via `_collect_mods`.
- Insurance: +30 coins per ruined building (`City._ruin`).
- The mayor's petitions and elections (`City._raise_petition`, `City._civics`, `City._new_day`) are driven by tribe opinion and mood; details on [Civics](civics.md).

## Thoughts and murmurs

Every 5-11 s a random citizen shows a speech bubble from `City.thought(c)`. The first match wins: fire within 4 tiles of the home, protest, sickness, being stuck in traffic (50% when `congestion > 0.35`), an election within 3 days, a broken-promise majority, an active event line, a tribe line (30%), the text of a need with `_need > 0.4` or pollution above 0.3 (60%), no job, taxes above 16%, shop gap above 0.4, commute above 25, weather, news beyond +-0.4, a cheerful line if mood above 0.65, else "Same as always." They are for information only.

## Where in the code

| What | Where |
|---|---|
| Citizen class | `City.Citizen` (city.gd top) |
| Creation, tribe roll | `City._spawn` (~1117), `City._roll_tribe` (~1141) |
| Tribes and opinions | `City._tribes` (~1154), `Catalog.TRIBES` |
| Job and home assignment | `City._second` (~1472-1515), `City._hcap`, `City._cap` |
| Schedule and walking | `City._want`, `City._fav`, `City._route`, `City._move` (~2488-2610) |
| Path grid | `City._rebuild_astar` (~731), `City.astar` |
| Mood, demand, immigration | `City._second` (~1569-1610) |
| Need ramp and weights | `City._need` (~1101), `Catalog.METRICS`, `Catalog.need_pop` |
| Coverage | `City._scan`, `City.raw_cov`, `City.cov_at`, `City.cov_home` |
| Networks | `City._net`, `City._net_solve`, `City._flood` |
| Crime | `City._crime` (~1031) |
| Pollution | `City.poll_at` (~1092), `polluters` in `City._scan` |
| Land value | `City._land` (~2291) |
| Sickness | `City._sickness` (~3112) |
| Traffic | `City._traffic` (~3139), `City._plan_traffic` |
| Weather | `signals.gd`, `City.WEATHER_PENALTY`, `City.trigger` |
| Seasons | `Civics.SEASONS`, `City._second` season switch, `City._collect_mods` |
| Mod merging | `City._collect_mods` (~1249), `City._add_mods` |
| Speech bubbles | `City.thought` (~2613), `City._murmur` |
| Save format | `City.to_dict`, `City.from_dict` (citizens are saved as `[id, home, work, tribe, nm, bias, shift, spd, commute, sick]`) |

## Open questions

- A walking citizen follows the path calculated at departure. If a road on it is bulldozed after that, the code does not recompute or stop them; whether citizens can end up walking through removed road tiles is not checked here. Only the path at departure is verified in `City.selfcheck`.
- Policing stat text now says -6%, matching its weight 0.06.
- The Transit stat text says covered homes "walk 30% faster"; the code gives +30% to homes whose coverage exceeds 0.5.
- The Sewage text claims sewage coverage affects how often people fall ill; `_sickness` has no sewage term. Sewage affects river health, fishing and mood only.
- Wind turbine text says storms and cold snaps reduce its output; the code lowers power *coverage* through `cov_power` mods in those events, but plant output is only changed by `mod("power_out")`, which no data file sets.
- Weather mood penalties (`WEATHER_PENALTY`) apply as long as the weather lasts, and the descriptions of events (for example Snowfall "walk slower") do not mention the 0.05 snow penalty.
- Employment is assigned by nearest Manhattan distance, not by actual road path length, so a nearby building across a river or on a disconnected road network can be chosen and be unreachable (the citizen then retries every 5 s).
- Immigration does not check jobs, so housing alone can fill a town. The code comment does not say whether this is deliberate.
