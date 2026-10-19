# Ages

A town's age (twelve ages in four eras: Ancient, Medieval, Industrial, Modern) decides which buildings and units it may use and which services people expect. Design notes: [AGES_DESIGN.md](../AGES_DESIGN.md).

## Advancing
Knowledge grows every second by `pop / 50 * 0.5 * (1 + education + 0.6 * culture)`. A town enters the next age when it has the knowledge, the peak population and the treasury below and a mood of at least 0.35, and it holds the materials in the last three columns in stock (spent on entering). Once it is 70% of the way on knowledge it buys and makes them ahead of time and holds them back from everyday use (`Ages.cost`, `Ages.missing`, `Ages.reserve`). Per-building upgrades are planned (docs/PLAN.md, H2 to H4).

| Age | Knowledge | Peak population | Coins | Planks | Tools | Metal |
|---|---|---|---|---|---|---|
| Bronze | 1800 | 10 | 100 | 20 | 0 | 0 |
| Classical | 4200 | 22 | 220 | 40 | 10 | 0 |
| Dark | 7200 | 40 | 400 | 60 | 20 | 0 |
| Medieval | 12000 | 65 | 650 | 80 | 30 | 0 |
| Renaissance | 19200 | 90 | 900 | 100 | 40 | 8 |
| Industrial | 28800 | 120 | 1200 | 120 | 50 | 16 |
| Electric | 42000 | 160 | 1600 | 140 | 60 | 24 |
| Atomic | 60000 | 200 | 2000 | 160 | 70 | 32 |
| Information | 84000 | 250 | 2500 | 180 | 80 | 40 |
| Digital | 114000 | 300 | 3500 | 200 | 90 | 48 |
| Future | 156000 | 360 | 5000 | 220 | 100 | 56 |

## Expectations
Fire, police and education count as met until Medieval; power, water, sewage, waste, transit and health until Industrial. When an age opens a need, the forgiveness fades by 25% every 400 s; the clock holds while mood is under 0.35. The planner counts such a need as at least half unmet and builds ahead.

## Building and unit ages
A building is available when the town's peak population reaches its unlock and its age reaches the building's age; the build menu shows what is missing. Units follow the same rule (infantry, grenadiers, artillery, patrol boats, destroyers and transports from Industrial; snipers, medics, tanks, AA, aircraft and helicopters from Modern).

## Start and commands
Setup option "Starting age" (default Modern: everything open). Command `set_age <0 to 3>` sets a town's age and its knowledge.

## Where in the code
`client/scripts/ages.gd`, `City.cov_at`, `City.unlocked`, `City._plan_service`, `Military` training loop, `client/tests/ages.gd`.

## Open questions
- Ancient has few buildings of its own; the default start stays Modern until A2 adds early content.


## Refitting buildings

Each cell remembers the era tier it was built in (`City.etier`, saved); a new age does not repaint existing buildings. A building behind the town's era holds and employs 6% less per era behind (`City.OBSOLETE`, up to 3 eras). Refit one with `U` on the inspected building or the `refit` command: it costs `City.refit_cost` (coins `cost * 0.8 * level * (era + 1)`, planks `4 * level`, tools `2 * level`, metal `2 * level` from the second era), needs a free crew (`City.crews`: 1 plus one per 60 people) and takes `REFIT_SECS` (90 s at full efficiency). While it is refitted the building is a construction site: it houses, employs and produces nothing. It steps up one era per refit. Planner towns refit their most outdated building when coins exceed its cost by 200 and the stock allows (`City._auto_refit`, every 10 s).

## Skill tree
Each town has its own tree of six branches (Economy, Industry, Knowledge, Society, Military, Infrastructure) with six nodes each (`research.gd`). A node costs 300 x tier squared research points (0.6 points per knowledge gained), needs the previous node of its branch or the same tier's predecessor in a neighbouring branch, and opens with the age (tier x 2, so tier 6 needs the Digital age). Effects are the same modifiers policies use (taxes, sales, production, goods, building cost, knowledge, mood, upkeep, crime, soldier health). The whole tree costs about 160,000 points; a town earns about 94,000 by the last age, so it never gets everything. Planner towns pick by a temper hashed from the town name. Take nodes with key K (full-screen tree) or in the Mayor's office, Policies tab.
