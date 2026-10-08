# Murmur wiki

The complete reference for how Murmur works: what every building, unit, policy and event does, and the rules and formulas behind the simulation. Players use it to learn the game; developers use it to find the code that implements a rule.

## Reference (generated from the game data; never edit by hand)
| Page | Contents |
|---|---|
| [Buildings](buildings.md) | Every placeable building and tile: cost, upkeep, unlock, radius, outputs |
| [City stats](stats.md) | The coverage stats and which buildings provide them |
| [Policies](policies.md) | All policies and their modifiers |
| [World events](events.md) | Every event with weight, duration and effects |
| [Military units](units.md) | Every unit type with stats and counters |
| [Civics data](civics.md) | Seasons, tribes, petitions, milestones, loans, diplomacy costs, tutorial steps |
| [Constants](constants.md) | Tuning constants read from the code |

## Mechanics (hand-written, verified against the code)
| Page | Contents |
|---|---|
| [Economy](economy.md) | Income, taxes, upkeep, demand, trade, goods chains, loans |
| [Citizens](citizens.md) | Citizens, tribes, mood, crime, health, immigration, walking and traffic |
| [Networks and building](networks.md) | Roads, power, water, sewage, coverage, building lifecycle, fires, territory |
| [Planner AI](planner.md) | How automatic towns decide what to build |
| [Mayor, elections and events](civics-mechanics.md) | Approval, petitions, elections, loans, event scheduling |
| [Diplomacy and war](war.md) | Neighbours, treaties, armies, combat, raids, occupation |
| [World and founding](world.md) | The endless world generator, plots, founding towns, zoom levels |
| [Empire mode](empire.md) | The Empire window, bulk control, spectating, pop-out windows |
| [Multiplayer](multiplayer.md) | Hosting, joining, commands, snapshots |
| [Controls and settings](controls.md) | Hotkeys, mouse, menus, windows, setup options, saves, command-line flags |
| [Performance notes](performance.md) | Simulation caching and renderer level of detail |

Each mechanics page ends with **Where in the code** and **Open questions**; the latter lists places where text, data and code disagree, and feeds [docs/PLAN.md](../PLAN.md).

## Glossary
- **Tile**: one grid square (32 px). Towns are arrays of tiles.
- **Plot**: a town's fixed 96 x 64 tile array placed on the region grid (`gpos`). Your territory is the part of it you own.
- **Town / city**: one simulated `City`. A game has several towns; each has an owner (`human`).
- **Zone**: a painted area that the city fills with buildings (residential, commercial, industrial, farm, ...).
- **Service**: a building that provides coverage of a stat (fire, police, health, ...) within a radius.
- **Coverage (`cov`)**: share of homes inside the radius of the services that provide a stat.
- **Mood**: 0..1 town happiness; drives growth, income and protests.
- **Approval**: the mayor's rating; it decides elections.
- **Tribe**: a citizen group with its own mood and petitions.
- **Petition / promise**: a tribe request; accepting it creates a promise with a deadline.
- **Planner**: the AI that builds for non-player towns (and for yours with auto-growth on).
- **Gate**: a road crossing at a plot border that links two towns for trade, power and water.
- **Region**: the grid of plots; the endless **world** is drawn behind it.
- **Sim second / day / year**: 1 s of simulated time; 60 s; 28 days.
- **RATE**: global income scale (0.08).

## Keeping the wiki current
Every pull request that changes behaviour updates the wiki in the same commit:
1. Data changes (buildings, units, policies, events, seasons, petitions, constants): run `GODOT=<path> python3 scripts/gen_wiki.py` and commit `docs/wiki/`. CI fails if the generated pages are stale.
2. Rule changes: edit the matching mechanics page (formula, constant, function name) and its **Open questions**.
3. New feature without a page: add one here, list it in this index (CI checks that every page is listed).
