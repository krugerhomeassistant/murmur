# Ages

A town's age (twelve ages in four eras: Ancient, Medieval, Industrial, Modern) decides which buildings and units it may use and which services people expect. Design notes: [AGES_DESIGN.md](../AGES_DESIGN.md).

## Advancing
Knowledge grows every second by `pop / 50 * 0.5 * (1 + education + 0.6 * culture)`. A town enters the next age when it has the knowledge, the peak population and the treasury below and a mood of at least 0.35.

| Age | Knowledge | Peak population | Coins |
|---|---|---|---|
| Medieval | 600 | 40 | 400 |
| Industrial | 2400 | 120 | 1200 |
| Modern | 7000 | 250 | 2500 |

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
