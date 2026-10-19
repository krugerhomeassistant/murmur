# Sandbox and gods-eye view: design

Status: G1 to G3 partly built (first forms); G4 designed, G5 planned. Phases G1 to G5 below; each ships behind the usual CI and has its own acceptance tests. This is the document to work towards.

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
Progress: world seed option done (`tests/scenario.gd`); starting age and town count already existed. Also done: per-town age (`ages` option) and the number of towns you run ("Towns you run" on the new-game screen). Area presets (One town, Province, Continent) are done. Left: per-town starting size (needs a cheap way to pre-grow a town; fast-forwarding costs minutes at start) and world size.
The new-game screen gains a Scenario section:
- Starting age for the whole world (exists), and per-town age override.
- Number of towns, their starting size (hamlet, village, town, city) and how many are player controlled.
- Area to control: a selector for the region the player owns. Default is the start plot and its neighbours; larger areas give several towns to run at once (the existing empire mode). Presets: "One town", "Province", "Continent".
- Seed and world size.
Acceptance: `tests/scenario.gd` builds three scenarios headless (1 town Ancient, 6 towns Industrial, province of 4 towns) and checks town count, age, ownership and that the planner grows each for 10 simulated minutes without collapse.
Depends on: ages A2 (without early-age content an Ancient world is empty).

### G2 Sandbox editor
Progress: the `grant` and `spawn` commands (gated by `Cmd.sandbox`, set by the setup screen's Sandbox option, never in multiplayer) and three buttons in the Empire window (`tests/sandbox.gd`); `set_age` already existed. Free town placement (founding costs nothing in a sandbox) is done. Left: placing units on the map, terrain brush, population and tribe edits, clock and season, undo, saving the sandbox flag.
A Sandbox mode (`Main.sandbox`, saved) with a toolbar:
- Place or remove towns of a chosen size and age anywhere on a free plot (no cost, no distance rule).
- Place units (any type of the town's age or a chosen age) singly or by the dozen, owned by any town.
- Set any town's age, treasury, population and tribe mix; set the world clock and season.
- Terrain brush: sea, river, plain, forest, hills, rock, ore (uses `World` kinds; edits stored as a per-seed overlay so the generator stays deterministic).
All actions are `Cmd`s (host only in multiplayer), logged, undoable once (last action).
Acceptance: `tests/sandbox.gd` runs each command, checks the state change, that a save and load round-trip keeps them, and that a client without host rights is refused.

### G3 God powers (Black & White flavour)
Progress: built in a first form (`scripts/powers.gd`, `tests/powers.gd`): belief pool (`City.belief`, regenerates with mood), cooldowns, ten powers (bless and incite among them) reusing events, sandbox only. Left: radius and target on the map, rain and grant knowledge, enabling them in multiplayer by host option.
Powers cost "belief" (a regenerating pool that rises with the towns' mood and culture, so a well-run world has more) and act through the simulation:
- Benevolent: rain on crops (harvest bonus), heal (cure sickness), bless a town (mood), grant knowledge (age progress).
- Wrathful: lightning strike (fire), tornado and earthquake (existing disaster code), plague (sickness), famine (market shock), incite war (raises tension).
- Passive: a creature or avatar is out of scope for now.
Powers are events (`Events`) with a target, a radius and a cooldown; they reuse the existing disaster and event code, so they are tested like events. Unavailable in competitive multiplayer unless the host enables it.
Acceptance: `tests/powers.gd` per power: effect applied, belief spent, cooldown respected.

### G4 Globe and gods-eye view
Design pass (2026-10-18). Build on what exists instead of a second renderer:
- **Today.** Zoom below `Main.WORLD_ZOOM` (0.25) is level of detail 3: live town thumbnails, names and a rim per town, over `WorldLayer` (the endless `World` drawn one texel per tile, chunk textures, generated a few ms per frame, `KEEP` 700 chunks). `Main.fit_prev` and 'fit world' already jump to it.
- **New tier, "globe" (zoom below about 0.05).** `WorldLayer` samples one texel per 8x8 tiles (`World` is a pure function of seed and tile, so a coarse sample costs 1/64 of the work) and caches one small texture per 128x128-tile block. Same nearest filter, same per-frame budget, so no new hitch source. Cap: the number of blocks on screen (about 400 at the lowest zoom) bounds the work; beyond that the camera stops zooming out.
- **Flat first, sphere optional.** The flat map is the baseline and ships first. A sphere is only a shader on the same texture (equirectangular to orthographic) and is attempted last, behind a setting, and only if the benchmark shows no loss; it is not on the critical path.
- **Markers.** At globe zoom each town is a disc: area proportional to population (clamped), colour by side (you, ally, neutral, enemy, vassal), a ring while at war, a line to each trade partner (width by volume) and a crossed-swords mark per active war from `Diplo.wars`. Everything comes from data the sim already keeps; nothing new is simulated. Markers are drawn in one `_draw` pass with no per-town node, so 1000 towns is 1000 draw calls at most, and under a screen-space size of 3 px a town collapses to a dot and is batched.
- **Overlays** (key `O` cycles, a legend in the corner): age, population, wealth (treasury per person), military power (`Military.power`), culture score, victory progress (share of land per group, `Victory`). Each is a function City -> 0..1 mapped to the marker ring colour with the validated palette from the dataviz skill, in light and dark.
- **Interaction.** Hover shows a card (name, age, population, treasury, treaty with your town); click flies the camera to that town and drops to level of detail 0..2 by the existing `glide`; middle-drag pans, wheel zooms, as today. In multiplayer the globe is read-only for other players' towns (snapshots already carry what it needs).
- **Performance budget and acceptance.** `tests/globe.gd`: builds 200 headless towns and checks marker data (`Globe.markers(towns, overlay)`) is produced in under 5 ms and is pure (no sim state changes). Windowed benchmark: the standard 8-town scene with the globe tier open must hold the README numbers (no more than 5% fps loss at normal zoom, since the tier costs nothing when it is off screen); a 200-town sandbox scene is the new stress case.
- **Slices (G4a and G4b done).** G4a `Globe` data module (pure, tested): markers, overlays, legend. G4b globe zoom tier in `WorldLayer` (coarse texels, block cache). G4c (done) town discs coloured by relation, a hover name and click-to-fly in `Main`; neighbour lines (G4d, first form: war, road, none) are drawn; the O key cycles overlay rings (age, population, wealth, military); per-partner trade volume is not tracked yet, so line widths do not show it; the sphere shader follows. G4d trade and war lines, minimap link. G4e sphere shader (optional, last).
- **Out of scope.** Terrain editing from the globe, real-world data (G5), a creature or avatar.

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
