# Sandbox and gods-eye view: design

Status: planned (owner vision, 2026-10-17), not built. Phases G1 to G5 below; each ships behind the usual CI and has its own acceptance tests. This is the document to work towards.

## The vision (owner's words, condensed)
A gods-eye-view world, in the spirit of [gods-eye-view](https://github.com/bilawalsidhu/gods-eye-view), combined with the game Black & White. The player can set the world to any age, place any number of units, and start with any number of villages or towns in any age. The default game starts you in control of your own area (a continent, province or state), and that area can also be a selector.

## What it is, and what it is not
It is the Murmur simulation seen from above, with a sandbox layer on top. Everything placed or triggered runs through the normal rules: towns have citizens, mood, money, planners and wars; ages gate buildings and units; victory is a state of the map. That is the difference from a pure toy sandbox such as WorldBox: the powers act on a living city-builder, and the end goal (domination by conquest or peace) still applies in normal games.

## What already exists
- Endless world, plots, founding (`World`, `WorldLayer`, `Main.found_town_at`), the M map view and four zoom levels.
- Ages with a starting-age option and a `set_age` command (`docs/AGES_DESIGN.md`, `Ages`).
- Empire window, bulk control, spectating, pop-out windows; planner towns; victory with a "keep playing" sandbox state.
- `Cmd` as the single path for every change, so sandbox actions work in multiplayer as host-only commands.
- Singleplayer spectator already allows everything (owner decision).

## Phases

### G1 Scenario setup (needs ages A2)
Progress: world seed option done (`tests/scenario.gd`); starting age and town count already existed. Left: per-town age and size, player-controlled count, area presets, world size.
The new-game screen gains a Scenario section:
- Starting age for the whole world (exists), and per-town age override.
- Number of towns, their starting size (hamlet, village, town, city) and how many are player controlled.
- Area to control: a selector for the region the player owns. Default is the start plot and its neighbours; larger areas give several towns to run at once (the existing empire mode). Presets: "One town", "Province", "Continent".
- Seed and world size.
Acceptance: `tests/scenario.gd` builds three scenarios headless (1 town Ancient, 6 towns Industrial, province of 4 towns) and checks town count, age, ownership and that the planner grows each for 10 simulated minutes without collapse.
Depends on: ages A2 (without early-age content an Ancient world is empty).

### G2 Sandbox editor
A Sandbox mode (`Main.sandbox`, saved) with a toolbar:
- Place or remove towns of a chosen size and age anywhere on a free plot (no cost, no distance rule).
- Place units (any type of the town's age or a chosen age) singly or by the dozen, owned by any town.
- Set any town's age, treasury, population and tribe mix; set the world clock and season.
- Terrain brush: sea, river, plain, forest, hills, rock, ore (uses `World` kinds; edits stored as a per-seed overlay so the generator stays deterministic).
All actions are `Cmd`s (host only in multiplayer), logged, undoable once (last action).
Acceptance: `tests/sandbox.gd` runs each command, checks the state change, that a save and load round-trip keeps them, and that a client without host rights is refused.

### G3 God powers (Black & White flavour)
Powers cost "belief" (a regenerating pool that rises with the towns' mood and culture, so a well-run world has more) and act through the simulation:
- Benevolent: rain on crops (harvest bonus), heal (cure sickness), bless a town (mood), grant knowledge (age progress).
- Wrathful: lightning strike (fire), tornado and earthquake (existing disaster code), plague (sickness), famine (market shock), incite war (raises tension).
- Passive: a creature or avatar is out of scope for now.
Powers are events (`Events`) with a target, a radius and a cooldown; they reuse the existing disaster and event code, so they are tested like events. Unavailable in competitive multiplayer unless the host enables it.
Acceptance: `tests/powers.gd` per power: effect applied, belief spent, cooldown respected.

### G4 Globe and gods-eye view
A new top zoom tier above the M view:
- A whole-world view: terrain colour, town markers sized by population, borders coloured by side, wars and trade lines; click a marker to drop into that town.
- Overlays: age, population, wealth, military, culture score, victory progress.
- Design question to settle with a prototype first: flat map with a globe shader versus a true sphere. The flat map is the baseline and ships first; the sphere is an option if it costs no performance.
Needs its own design pass (rendering budget, LOD for thousands of towns) and a measured benchmark before it ships.

### G5 Real-world map mode
Start from a real map: pick a continent, country or state; towns are seeded at real cities with real coastlines and rivers.
- Data: open datasets only (for example Natural Earth for coastlines and country borders, public city lists), baked offline into a compact heightless land mask and city table shipped with the game, so the game needs no network.
- The planner and world generator must handle real coastlines (long thin land, islands); tested by `tests/realmap.gd`.
- Licensing review before any data is committed (docs note on each dataset).
Riskiest phase; last.

## Order in the plan
After E4 to E6 and ages A2: G1, G2, G3, G4, G5, then the performance pass and release, then art (last, owner decision). G1 and G2 can move up right after E4 if the owner wants this earlier: they need only ages A2.

## Risks
- Scope: every phase is several PRs; none starts before the previous phase's tests exist.
- Performance: hundreds of placed units or many towns stress the sim; the performance pass (and sim LOD from E2) must cover sandbox worlds. G4 needs a rendering benchmark first.
- Multiplayer: sandbox and powers are host-only commands; clients only see results in snapshots.
- Saves: new state (sandbox flag, belief, terrain overlay) goes in new save keys with defaults so old saves load.
