# War rework design (v0.3)

Goal (user, 2026-10-08): Age of Empires / Empire Earth style war. Armies march across the real map, fight among the buildings, ground units respect water, boats sail the rivers, aircraft fly, sieges destroy and capture.

## Model change
Before: every unit has `s`, the distance it has marched along one line between two towns. After: every unit at war has a world position `p` (pixels, same frame as `Main.origin(town) + tile * 32`) and a heading `h`. Units without `p` are at home. `Military.fight(a, b)` runs once per sim second per war and stays host-authoritative (multiplayer snapshots already carry `army`).

## Movement
- Ground (soft/armor): breadth-first flow field over the tiles of the two towns (and any town between), walkable = not river, or a road over the river (a bridge). Field per goal, cached 20 s. Unreachable goal (a river with no bridge): the unit holds at the shore and shoots across.
- Ships: flow field over river tiles; goal = river tile nearest the enemy centre. Transports wait for the enemy fleet to die, then run for the shore.
- Air: straight flight, ignores terrain.
- Everyone advances on the enemy territory centre and engages the best target in weapon range, or chases the nearest foe within aggro range.

## Phases
1. **Foundation (this PR line):** world positions, terrain-aware movement, 2D range fights, drawing from `p`, tests (`tests/war.gd`, new `tests/warmap.gd` for rivers and boats).
2. **Sieges:** units damage and destroy buildings, capture points, retreat, building hit points.
3. **Air:** take-off and landing at bases, dogfights, bombing runs, AA.
4. **Command UI and rally:** group select, move/attack orders, production queue.
5. **Battle footage** for the README (second GIF) and a benchmark update.

## Rules
`Military` stays deterministic enough for `tests/war.gd`; wars are host-simulated; perf must not regress `--benchmark --war`.

## Known limits of phase 1
Units go home instantly when peace comes. Defenders do not hold a position; both sides advance and meet. Buildings do not block movement.
