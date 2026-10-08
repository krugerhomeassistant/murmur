# Diplomacy and war: how it works

This page explains how neighbouring towns relate to each other and how wars are fought: relations, treaties, AI behaviour, the real-time army model, terrain, raids and occupation. Unit statistics are in the generated [units.md](units.md); buildings in [buildings.md](buildings.md); tuning constants in [constants.md](constants.md). The mayor-side rules (approval, petitions) are in [civics-mechanics.md](civics-mechanics.md).

Conventions: "per second" means once per simulated second. Function names are written `File.function` so you can jump to them. Code lives in `client/scripts/diplomacy.gd` (`Diplo`), `client/scripts/military.gd` (`Military`), with hooks in `city.gd`, `main.gd`, `cmd.gd` and `hud.gd`.

## Summary

- Towns of a region sit on a grid. Each has an opinion of every other town (`rel`, -1 to 1), a baseline `temper`, and a shared treaty state: none, pact, alliance, embargo or war.
- Opinions drift towards a target each second. Random neighbour events (festivals, spats, smuggling, tribute demands, raids) fire every 45 to 90 seconds.
- A war is fought by real units. Barracks, bases, radar posts and naval yards give the unit room; towns train units automatically and units march across the real map, respecting water, and shoot each other every second.
- A war ends by surrender (an occupation counter reaching 40), by a ceasefire you buy, by stalemate, or by treaty.
- Planner-run (AI) towns raise their garrison and counter-train according to the threat they perceive.
- Abstract "battles" are gone. `Diplo._battle` no longer exists; see Open questions.

## Region, neighbours and links

Towns are laid out on a grid by `gpos`. `Diplo.side(a, b)` returns 0 (north), 1 (east), 2 (south) or 3 (west) when `b` is directly adjacent, otherwise -1. Towns that are not adjacent can still have opinions and treaties (diplomacy only), but have no road link.

A road link needs a road tile on the border in both towns: `Diplo.linked(a, b)` is true when `a.gate[side]` and `b.gate[opposite side]` are both above 0. `gate` counts road tiles at the territory edge facing N, E, S or W. Without a link there is no trade or commuting; the gold border bars and labels drawn by `Main._draw_borders` show the state ("linked", "needs a road to this border", "WAR").

### Trade multiplier

`Diplo.tmult(a, b)` scales power and water imports and commuters between two towns:

```
0                                   if embargo, war, or not linked
clamp(0.6 + 0.5 * avg(a, b), 0.2, 1.3)
  x 1.25 if pact,  x 1.4 if alliance
```

It is used in `City._second` for commuters (`commuters_in = min(pop - employed, open_other_jobs * 0.4)` where open jobs are multiplied by `tmult`) and in the network solver for imports.

## Opinions and temper

Each `City` stores `rel[town_name]` (what it thinks of that town) and `temper` (its baseline). `Diplo.rel(a, b)` defaults to `a.temper * 0.5` when no opinion has formed. `Diplo.avg(a, b)` is the mean of both directions. `Diplo.stance(r)` names a value: Hostile under -0.6, Tense under -0.2, Neutral under 0.2, Friendly under 0.6, otherwise Warm.

### Temper

Temper comes from `Main` when towns are created:

- In `Main._new_town`: `temper = TEMPERS[town_count % 4]` with `TEMPERS = [0.0, 0.2, -0.25, 0.05]`.
- In `Main._fresh` (a new game), your own town has `temper = 0`. Each neighbour `k` gets one value from the setup option "Neighbours are": Friendly `0.2`; Mixed `TEMPERS[k % 4]`; Prickly `-0.25`; Random `randf_range(-0.3, 0.3)`.

### Drift

Every second `Diplo.second` moves each town's opinion of every other town by up to 0.003 towards a target:

```
target = temper
       + {none 0, pact +0.4, alliance +0.7, embargo -0.8, war -0.9}
       + min(0.3, 0.02 * (imports of power+water of both towns))
       - 0.2  if mil(other) > mil(self) + 0.5     (fear)
       - 0.1  if other.pop > 2 * self.pop         (envy)
target = clamp(target, -1, 1)
```

So opinion needs about 333 seconds (5.5 minutes) of play to cross 1.0 of distance. Gifts, wars and other actions give one-off shifts (`Diplo._shift(a, b, delta_a, delta_b)`, which changes both opinions, clamped to -1..1).

### Military strength

`Diplo.mil(c)` is the number the AI and the interface compare:

```
mil = Military.power(c) + cov["defence"] + 0.4 * bases + 0.15 * barracks + 0.1 * radar posts + 0.35 * naval yards
Military.power(c) = sum over units of  cost * 0.0012 * (1 + 0.1 * rank)
```

The Region tab of the City panel shows both values as "Military: theirs, yours".

## Player actions

The Region tab (City panel) has one block per neighbour; each button sends `Cmd.run("diplo", [town_index, verb])`, which validates the verb against `Cmd.DIPLO` and calls `Diplo.act(a, b, verb)`. `Diplo.COSTS` is `{gift 100, pact 200, alliance 400, peace 150}`. `act` first returns "That needs $N." if coins are short, even for verbs with a cost of zero.

| Verb | Cost | Requirements | Effect on opinions (self, other) | Other effects |
|---|---|---|---|---|
| `gift` | 100 | none | +0.03, +0.16 | other gets 50 coins |
| `pact` | 200 | no treaty (or an embargo); `avg` relation at least 0.15 | +0.05, +0.10 | trade pact: `tmult` x1.25 |
| `alliance` | 400 | an existing pact; `avg` at least 0.55 | +0.10, +0.10 | `tmult` x1.4, and `cov_defence +0.25` for each allied town for both (`City._collect_mods`) |
| `embargo` | 0 | none | -0.05, -0.30 | trade and commuting stop (`tmult` 0) |
| `lift` | 0 | an embargo | 0, +0.08 | treaty cleared |
| `peace` (in war) | 150 | you have fought at least 3 war counters (60 s) | +0.10, +0.30 | war ends; treaty cleared; log "Ceasefire..." |
| `peace` (not in war) | 150 | none | +0.05, +0.25 | clears an embargo |
| `tribute` | 0 | `mil(self) >= mil(other) + 0.3` | 0, -0.40 | other pays `min(max(coins*0.3, 0), 150)` |
| `tribute` (too weak) | 0 | `mil(self) < mil(other) + 0.3` | -0.05, -0.15 | refused |
| `war` | 0 | not already at war | -0.30, -0.60 | see War |
| `leave` | 0 | any treaty | -0.05, -0.15 | cancels the treaty |

Details:

- "At least 3 war counters" is `a.war_n[b] >= 3`. `war_n` rises by one every 20 war seconds (see Fighting), so you cannot buy peace in the first minute. The check uses the acting town's own counter.
- The peace verb deducts its cost on success only, and only in the branch that succeeds.
- `Diplo.act` has no cooldown. The HUD tooltips describe the numbers loosely (for example, the tooltip for the war button still describes the old abstract battles; see Open questions).

### Multiplayer proposals

If the other town is controlled by a different human (`Diplo._player`: `b.owner != 0 and b.owner != a.owner`), pacts, alliances, ceasefires and tribute above the other's strength do not apply at once. `Diplo._ask` creates a decision for the other player (kind `offer` or `demand`) and holds the money until they answer; `Diplo.resolve` completes it. A refusal returns a proposer's deposit (`pay`) and shifts opinion by -0.04 of the proposer. Accepting an offer shifts by +0.08 and +0.10 and signs the treaty; paying a demand costs the amount and shifts -0.02 / +0.15; refusing a demand shifts -0.10 / -0.02 and triggers a raid on the refuser (`Diplo._raid`).

In a single-player game the same decisions come from AI towns (below). Offers and demands appear in the Decisions tab of the Mayor's office and expire after 2 days (an expiry is treated as a refusal).

## AI neighbour behaviour

`Diplo.second` runs once per sim second with all towns (called from `Main` every `dacc >= 1.0`). It first calls `Military.register(towns)` and `Military.econ(c)` for every town, then handles each pair `(i, j)` with `i < j`: it moves both opinions, runs `Military.fight(a, b)` if they are at war, and counts down `a.dipl_t` (the timer belongs to the lower-indexed town of the pair) which, at zero, resets to a random 45 to 90 seconds and calls `Diplo._event(a, b, rng)`.

### Neighbour events

`Diplo._event` does nothing if the pair is at war or either town has fewer than 12 citizens. Let `r = avg(a, b)` and `t` the treaty. Cases are tested in order:

| Condition | Chance | Outcome |
|---|---|---|
| `r > 0.1` | 70% | one of three at random: joint festival (+40 coins each, +0.06 opinion); cultural exchange (both towns trigger the `parade` event, +0.05); aid (the richer town, if it has over 200 and the other has under 60% of its coins, sends 60, +0.05) |
| `r > 0.1`, with a human town, no treaty and `r > 0.35` | additionally 60% | the AI proposes a free trade pact as an `offer` decision |
| `-0.15 <= r <= 0.1` | 50% | trade fair, +20 coins each, +0.04 |
| `r < -0.15` and no embargo | always | the lower-opinion side is the aggressor; see below |

For `r < -0.15`: if `r < -0.7`, the aggressor is a planner town, `mil(aggressor) > mil(victim) + 0.4` and a 40% roll succeeds, the aggressor declares war (`act(aggressor, victim, "war")`). Otherwise one of four things happens at random: a diplomatic spat (-0.06 each); smuggling (the victim triggers `crime_wave`); a `border_incident` on the victim; or, if `r < -0.55` and `mil(aggressor) >= mil(victim) - 0.3`, a tribute demand on a human victim (60%; amount `min(150, max(30% of coins, 40))`) or an immediate raid (`Diplo._raid`) with -0.08 each; otherwise the river is diverted (`water_main` on the victim).

Raids in this path use `Diplo._raid`, described under Raids.

## Threat

`City.threat()` is the planner town's fear level, from 0 to 1:

```
if any neighbour is at war: 1.0
else for each neighbour with no treaty and rel(self, p) < -0.2:
         t = max(t, clamp(-rel * 0.8, 0, 0.8) * (1.0 if power(p) + 0.3 > power(self) else 0.5))
```

`naval_threat()` is true when a hostile neighbour (war, or `rel < -0.2`) is joined to you by a river (`Military.river`). Both are used in `City._plan_service` only when the town is not human (`thr = 0 if human`):

- `lim` (the number allowed) for barracks, bases and radar posts becomes `max(normal_limit, 1 + int(thr * 2 * (1 + pop/250)))`; for naval yards `1 + int(thr * 2)` while `nav`.
- Score bonuses (the planner divides score by cost): barracks `thr * 3` (or `thr * 1` once it has more than two barracks per base), base `thr * 5`, radar `thr * 3` (or `thr * 0.5` once it has two per base), naval yard `thr * 6`.
- When threatened, military buildings may be placed even with weak coverage gain (the placement check `bs < 0.5` is skipped for them).

Planner towns do not build ports (`water` buildings) unless a naval yard is needed.

## War

### Declaring

`Diplo.act(a, b, "war")` signs a `war` treaty on both sides, sets `war_n[other] = 0` and `war_sc[other] = 0` on both, calls `Military.conscript` for both, shifts opinions by -0.30 and -0.60, logs "X declares war on Y!" and queues the alarm sound on both. No cost. The war lasts until a treaty is signed.

`Military.conscript(c)` adds `clamp(pop / 15, 3, 12)` Riflemen at 70% hit points, so a town with no barracks still fields a militia. (This ignores the 150 army cap.)

### Consequences

While `wars() > 0` (`City.wars`, counting `treaty == "war"` entries):

- Trade and commuting between the two towns stops (`tmult` returns 0).
- Mood receives `-0.03 * wars - 0.004 * min(war_battles, 15)` through `_collect_mods` and approval receives `-0.04 * wars - 0.012 * min(war_battles, 12)`. `war_battles()` is the sum of `war_n` over wars; one unit is 20 seconds of war.
- Opinions drift towards -0.9 (the war term in `Diplo.second`).
- The General advisor appears in the Mayor's office.
- Unpaid troops desert (see Upkeep).

### Ending a war

| Way | Condition | Result | Code |
|---|---|---|---|
| Surrender | an attacker's occupation counter on your town reaches 40 | winner takes `min(30% of loser's coins, 300)`, treaty cleared, may annex a strip of land, `rep` +0.1 winner / -0.1 loser | `Military._occupy`, `Diplo.surrender` |
| Purchased ceasefire | `Diplo.act(.., "peace")` after at least 3 war counters; 150 coins | treaty cleared, opinions +0.10 / +0.30 | `Diplo.act` |
| Proposal accepted | multiplayer counterpart accepts a ceasefire offer | treaty cleared | `Diplo.resolve` |
| Stalemate | `war_n >= 30` (600 s of war) and fewer than 6 units in total on both sides | treaty cleared, "armies spent, agree to a ceasefire" | end of `Military.fight` |
| Cancel | `leave` cancels a treaty; during a war it is refused ("a war is ended with a peace treaty") | treaty cleared, -0.05 / -0.15 | `Diplo.act` |

The `leave` verb refuses to end a war; only `peace` does (150 coins, three war counters).

Annexing: `Diplo.surrender` calls `w.can_expand(k)` and `l.cede(opposite side)`; if both succeed, `w.expand(k, true)` gives the winner a free strip of land (`City.expand(k, true)`) and the loser loses the matching strip.

When a war ends, `Military.econ` clears each unit's target and erases its world position `p`, so units go home at once ("phase 1" behaviour in [WAR_DESIGN.md](../WAR_DESIGN.md)). The occupation counter of the loser against the winner is reset to 0 on surrender; after a peace by other means, it decays by 1 per second.

## The military model

### Units and classes

All unit data is in `Military.KIND` and listed in [units.md](units.md). Every unit has a class `t` for incoming fire: `soft`, `armor`, `air` or `ship` (`Military.TCLS` maps these to 0 to 3). A unit's `vs` table gives its damage multiplier against each class; a multiplier of 0 (or missing) means it cannot target that class at all. Per-unit fields: `hp`, `dmg` (per second), `rng` (pixels), `spd` (pixels per second), `cost`, `upk` (upkeep per second), `train` (seconds), `cap` (per building) and, for some units, `radar` (air), `heal` (Medic) and `lands` (Transport, 6).

Units that exist in an army are small dictionaries: `k` (kind), `hp`, `mx` (max hp), `xp`, `rk` (rank), `tgt` (name of the enemy town), `l` (a random -1..1 used for lane offset and speed jitter) and, only while deployed, `p` (world pixel position) and `h` (heading). They are saved with the town (`City.to_dict`); runtime keys `ft`, `fp` and `fl` (tracer data) are not.

### Housing and caps

`Military.caps(c)` returns how many units of each kind the town can hold:

```
cap[kind] = sum over building ids in KIND[kind].cap of  per_building_count * number_of_that_building
cap[kind] = min(cap[kind], 2 * radar_posts)    for kinds flagged radar (jets, fighters, bombers)
```

Barracks house infantry types and medics; bases also house armour, helicopters and air; naval yards house ships; radar limits air units to two per radar post, taken across all air kinds separately (each kind is limited to `2 * radar posts`, not their sum). The exact table of "housed by" is in [units.md](units.md).

A town also has a hard `ARMY_MAX = 150` units: training stops at this size (the comment cites upkeep and the O(n^2) cost of fights). Conscripts ignore it.

### Training

`Military.econ(c)` runs once per second per town (called by `Diplo.second`):

1. Upkeep: `coins -= sum(upk of all units)` (not scaled by `RATE`). If `coins < -50` and the army is not empty, the last unit in the list is removed (it deserts), one per second.
2. For planner towns (`human == false`), every 10 seconds `Military.adapt(c)` rewrites the training priorities (below).
3. If `train_on` (player toggle, key T or the Army window) and `army.size() < 150`: for every kind `k` with priority `w > 0`, `count < cap`, and `coins >= 3 * cost`: `train_t[k] += 0.5 * w`; when `train_t[k] >= train` seconds the timer resets, `cost` is deducted and a new full-hp unit is added.
4. Targets: each unit gets a target town, spread round-robin across enemies at war (ships only choose enemies reachable by river). With no enemy, the target is cleared and `p` is erased.

Consequences of the formulas:

- Every kind trains in parallel with its own timer; there is no single production queue. "Priority" is only the speed: priority 1 is half speed, 2 is normal, 3 is one and a half times (time to train is `train / (0.5 * w)`; a Rifleman with priority 2 takes 8 s, with priority 1 it takes 16 s, with 3 it takes about 5.3 s).
- Priority 0 stops training that kind.
- Training happens in peacetime too. The standing army costs upkeep for as long as it exists, and units are only counted against caps when alive.
- The coin test is `3 * cost`, not `cost`, so a Battle tank needs 420 coins in the treasury to start, and then costs 140.

Default priorities `Military.DEF_W`: Rifleman 2, Battle tank 2, every other kind 1. `Military.weights(c)` overlays the town's `train_w` (0 to 3 set from the Army window via `Cmd.run("train_w", [kind, value])`) on the defaults.

### Ranks

Units gain experience equal to the damage they deal (`Military._gain(u, dm)` in `fight`) or half the hit points they heal. Thresholds `RANK_XP = [250, 800, 2000]` give ranks 1, 2 and 3 (Recruit, Veteran, Elite, Legend; `Military.RANKS`). Each rank gives `+15%` damage (`RANK_DMG`) and `+10%` of base max hp (`RANK_HP`; the code re-derives `mx` so that three promotions add 10% of base each) and the extra hit points are also added to the current hp. Rank also counts in `Military.power` (`1 + 0.1 * rank`). Kills do not give extra experience; damage dealt does, including damage beyond what was left.

### Strength comparison

The Army window shows `Military.summary(c)`: total units, per-kind counts, and the total room for units (`sum(cap)`), and the rank counts. The Region tab shows both towns' `Diplo.mil`.

## Fighting

`Military.fight(a, b)` runs once per sim second for each pair at war (called in `Diplo.second`, lower-indexed town as `a`). It treats each side as the units whose `tgt` is the other town's name (`Military._of`).

### Per second

1. Units without a position are spawned: `_spawn(c, foe, u)` places them 90 px along the front line `Military.line(c, foe)` from their own side, offset sideways by `u.l * 70` px, snapped to the nearest standable tile (`nearest_ok`, radius 24 tiles) for the unit's class. `line` runs edge to edge for adjacent towns and centre to centre otherwise.
2. Every unit picks a behaviour (see below) using positions from the start of the second; all hits are accumulated and applied at the end, so the result does not depend on iteration order.
3. Damage: `hp = min(hp - hits + heals, max_hp)`.
4. Units at 0 hp or less are removed from their owner's `army`, the opposing town's `war_sc[owner]` increases by one, an explosion is queued (`Military.booms`, shown for 3 s) and the owner gets the alarm sound.
5. `a.war_t` counts down from 25 (initial) and then every 20 seconds both towns' `war_n` for each other rises by one (the "war counter").
6. `_occupy(a, b)`, `_occupy(b, a)`, `_bomb(a, b)`, `_bomb(b, a)`.
7. The stalemate check (`war_n >= 30` and fewer than 6 units in total) ends the war.

### Targeting and damage

For a combat unit (not Medic, not Transport) with position `p`:

- Among the enemy units it can damage (`vs > 0`), it finds those within its range and picks the one that minimises `distance / vs`, so it prefers high-multiplier targets (anti-air chooses aircraft; bombers choose armour and ships).
- If it has a target it deals `dmg * (1 + 0.15 * rank) * vs[target class]` to it, stays where it is (no movement), faces it and records a tracer.
- Otherwise, if the nearest damageable enemy is closer than `max(AGGRO, 1.5 * range)` (`AGGRO = 520` px), it advances to a standoff distance of `max(0.8 * range, 10)` from it; ground and ship units use `_slide`, air units move straight.
- Otherwise it marches towards the heart of the enemy territory (`terr_px(foe).get_center()`) using `_go`.

Damage is per second, so a Rifleman (2.4) kills a Rifleman (75 hp) in about 31 seconds alone, many rifles together kill much faster. Because a unit that is firing does not move, front lines stall naturally when ranges are matched.

Special units:

- Medic: finds up to three wounded allies within its range, sorted by lowest fraction of health, and heals each by up to `heal` (2.5 per second); it gains experience equal to half the healing. If it is more than 80 px from the centroid of its side's fighters (medics and transports excluded) it moves towards the centroid.
- Transport: has no weapon. It holds back while the enemy has ships (staying put if its side has one ship or fewer, otherwise following the fleet's centroid), and when no enemy ship remains runs for the enemy shore. Each transport counts as 6 attackers in the occupation count (`lands`).

Speed: each unit's step is `spd * (1 + 0.12 * l)`, with `l` fixed per unit, so a column does not arrive as one blob. A lateral wobble `jit` also spreads columns.

### Terrain, water and bridges

Walkability is decided per tile by `Military._tile_ok(city, index, class)`:

- Ground classes (`soft` and `armor`): walkable if the tile has no water, or a road on it (a bridge). Land buildings do not block movement.
- Ships: walkable if the tile is water and has no road (a bridge blocks boats).
- Air: ignores terrain (`passable` returns true).

`Military.passable(p, cls)` looks up the town at a pixel through the registry `Military.reg` (gpos to City, kept up to date by `Military.register`), then applies `_tile_ok`.

Pathfinding uses cached flow fields:

- `Military._field(a, b, goal, cls)` builds a breadth-first distance field (8-neighbour; diagonal steps cannot cut corners past a blocked tile) over the bounding rectangle of the two towns' grid positions. The key includes both corner towns, the class and the goal tile.
- If the goal tile itself is not standable (for example it is in a river), the nearest walkable tile is used as the goal. If there is none the field is marked not ok.
- Fields are cached for up to `FIELD_TTL = 3000` `fight` calls; `Military.terrain_changed()` clears the cache at once. It is called when a bridge is built or removed (`City.place`, `City.bulldoze`), when a world loads (`from_dict`) and when the registry changes.
- Builds are rate limited: at most one field per `BUILD_GAP_MS = 30` ms (disabled when headless). While waiting, units slide straight at the goal.
- `Military._follow` moves a unit up to `spd` pixels downhill along the field, choosing the neighbour with the lowest distance (ties go to the one that points at the goal), up to three steps per call.
- If the goal is cut off (a river with no bridge between the towns) the field is not ok: ground units use `_slide` and hold at the shore, shooting across the water if in range. `_slide` tries the direct heading, then turns up to about 105 degrees each way (0.6, 1.2, 1.8 rad) until a passable spot is found.

Boats follow a field over river tiles to the river tile nearest the enemy heart (`_shore`). Ships can only take part in a war when `Military.river(a, b)` holds: the two towns must be adjacent and both facing border edges must have a water tile. Otherwise they are given no target and stay home. A bridge removes the river from a ground unit's path but blocks boats on that tile.

### Air

Air units (`jet`, `fighter`, `bomber`, `heli`) fly straight (`p + (goal - p).limit_length(spd)`), with no pathing and no terrain. They are limited by radar posts if flagged (`radar: true`: jet, fighter, bomber; the helicopter is not flagged). Anti-air has `air` multiplier 3; fighters 2.2. Bombers have damage multipliers on armour and ships but 0 against air, so they cannot defend themselves against aircraft.

### Raids, bombing and buildings

War damage to buildings is not simulated per shot. Two mechanisms destroy buildings, through `City.strike(n, from)`:

- `Diplo._raid(from, to)`: severity `sev = 1 - 0.7 * clamp(cov["defence"], 0, 1)`; `n = round(3 * sev)` buildings are destroyed if `to.pop > 15`; a recovery offer is queued. Alarm sounds play. Defence coverage comes from bases (full strength within 25 tiles), radar posts (60% within 20), the Garrison policy (`cov_defence +0.3`), and alliances (`+0.25` each).
- `Military._bomb(att, vic)`: bombers inside the victim's territory add 0.15 each per second to a counter; the counter only advances if the victim has no Anti-air, Fighter or Strike jet in its army aimed at the attacker (their location does not matter). At 1.0 it destroys one building. One bomber destroys one building about every 6.7 seconds; ten about once per second.

`City.strike` chooses the `n` buildings closest to the attacker's border side (`_edge_dist`) with a random offset of 0 to 2 positions in that ordering, spawns a blast marker and calls `_ruin`, which empties non-zone tiles or resets zone level to 0, leaves a record in `ruins` (for recovery) and pays insurance (30 coins per building) if the `insured` modifier is above zero. The recovery decision costs `20 * ruins`.

### Occupation and surrender

After each fight `Military._occupy(attacker, victim)` runs for both directions. The zone is the victim's territory rectangle grown by 100 px.

```
n   = sum over attacker units with a position in the zone of  (lands if transport else 1)   [every unit counts, including medics]
def = number of the victim's units targeting the attacker with a position in the zone

if n >= 2 and n > def:
    victim.occ[attacker] += 1
    attacker.raid[victim] += n / 18
    if raid >= 1: raid = 0; Diplo._raid(attacker, victim); loot = min(max(victim.coins, 0) * 0.03, 30)
    if victim.occ[attacker] >= 40: Diplo.surrender(attacker, victim)
else:
    victim.occ[attacker] = max(occ - 1, 0)
```

So the attacker needs two or more units inside and more than the defender has inside; 40 seconds of that wins the war. A stack of 18 units inside produces a raid every second. The Region tab shows "Occupation of your border: N/40".

## AI armies

Planner towns (`human == false`) are armed by `City._plan_service` (buildings, see Threat) and by `Military.adapt`:

- Every 10 seconds `adapt(c)` totals the damage classes of all units belonging to neighbours that are at war with the town, or have no treaty and `rel(c, p) < -0.2` (what the town thinks of them).
- Training priorities are reset to the defaults and, only if at least 3 enemy units are counted, each class that makes up at least 25% of the total raises the priority of its counters by 1 (by 2 if at least 50%), capped at 3:

| Enemy class | Counters trained more |
|---|---|
| air | Anti-air, Fighter |
| armor | Grenadier, Artillery, Helicopter, Bomber, Heavy tank |
| soft | Battle tank, Sniper, Artillery, Light tank, Bomber |
| ship | Destroyer, Patrol boat, Bomber, Artillery |

Training itself follows the same rules and caps as the player's, so an AI town can only train a unit when `coins >= 3 * cost`. `City.tick` keeps planner towns at a minimum of 30 coins ("kept alive by the state"), which is the only subsidy found in the code.

## Army window

Opened from Windows > Army (`Hud._army`; key T toggles auto-train without opening it). It shows:

- Auto-train check box (`Cmd` verb `train`).
- The summary line (`Military.summary`) and the rank counts.
- One row per unit kind: name, `count / cap`, priority buttons (`-`/`+`) and a tooltip with hp, damage, range, cost, upkeep, class and strengths (`vs >= 1.3`). Buttons call `Cmd.run("train_w", [kind, clamp(current +/- 1, 0, 3)])`.

The Region tab shows the state of each war: elapsed time (`war_n * 20` s), enemies destroyed (`war_sc`), both army summaries and the occupation value.

## Multiplayer and performance notes

- `Military.fight` is host-authoritative; clients see army snapshots (see [MULTIPLAYER.md](../MULTIPLAYER.md)). Commands go through `Cmd.run`, which validates every number (rejecting non-finite floats) and clamps priorities to 0..3.
- Cost scales roughly with the square of the units in a war (targeting loops over each unit's foes), which is why `ARMY_MAX` is 150.
- Flow fields are cached and built at most once per 30 ms; building one walks every tile of every town spanned (96 x 64 per town). Fields are keyed by goal tile, class and the corner towns, so a war between non-adjacent towns builds large fields.
- Off-screen towns tick in batches (`lod`), but `Diplo.second` and the war run on the main thread every second regardless.
- `--benchmark --war` exists to guard performance (WAR_DESIGN.md "Rules").

## What is still planned

From [WAR_DESIGN.md](../WAR_DESIGN.md), phase 1 (foundation) is implemented. The document lists:

2. Sieges: units damage and destroy buildings, capture points, retreat, building hit points. Only the coarse raid and bomb mechanics above exist; units do not attack individual buildings.
3. Air: take-off and landing at bases, dogfights, bombing runs, AA. Dogfights and bombing runs exist in a simple form; take-off, landing and bases as air fields do not.
4. Command UI and rally: group select, move and attack orders, production queue. None of this exists; the only control is training priority and the declare war and peace buttons.
5. Battle footage for the README and a benchmark update.

Known limits listed by the design: units go home instantly when peace comes, defenders do not hold a position (both sides advance and meet) and buildings do not block movement.

## Where in the code

| Topic | Location |
|---|---|
| Opinions, treaties, actions, neighbour events | `client/scripts/diplomacy.gd`: `Diplo.act`, `second`, `_event`, `_raid`, `surrender`, `resolve`, `_ask`, `_offer`, `tmult`, `linked`, `side`, `mil`, `stance`, `COSTS` |
| Unit data, caps, training, ranks | `client/scripts/military.gd`: `KIND`, `DEF_W`, `caps`, `counts`, `weights`, `power`, `econ`, `conscript`, `adapt`, `_gain`, `RANK_XP`, `RANK_DMG`, `RANK_HP`, `ARMY_MAX` |
| Fighting | `Military.fight`, `_go`, `_follow`, `_slide`, `_spawn`, `_row` |
| Terrain and flow fields | `Military._field`, `_tile_ok`, `passable`, `nearest_ok`, `river`, `_wet_edge`, `_shore`, `terrain_changed`, `register`, `FIELD_TTL`, `BUILD_GAP_MS` |
| Occupation, bombing | `Military._occupy`, `_bomb` |
| Building damage | `City.strike`, `City._ruin`, `City._edge_dist`, `City._offer_recovery`, `City._rebuild` |
| Threat and planner military | `City.threat`, `City.naval_threat`, `City._plan_service` |
| War effects on the mayor | `City.wars`, `City.war_battles`, `City._collect_mods`, `City._civics`, `City.advisors` |
| Temper | `Main.TEMPERS`, `Main._new_town`, `Main._fresh` |
| Commands | `client/scripts/cmd.gd`: `diplo`, `train`, `train_w` |
| UI | `Hud._army`, `Hud._army_refresh`, `Hud._rebuild_dipl`, `Hud._side_text`, `Hud._act_btn`; war drawing in `Main` (tracers, booms, blasts) |
| Save keys | `City.SAVE_KEYS` (`rel`, `treaty`, `temper`, `war_n`, `war_sc`, `occ`, `train_on`, `train_t`, `train_w`) and `City.to_dict` (`army`) |

## Open questions

- `a.war_t` is the war counter timer and it lives on the lower-indexed town. If that town is at war with two neighbours, the timer is decremented once per war per second, so both wars' counters advance faster (about every 10 s instead of 20). The documentation above assumes one war.
- `Diplo.act` rejects any verb when `coins < cost`; with a cost of 0 that only fails for a town with negative coins, so a town in debt may be unable to declare war or cancel treaties. Not tested.
- The stalemate ceasefire counts `army.size()` of both sides, including units that are at home and not committed to this war; it is not specific to the pair of towns in a multi-war game.
- `Military.conscript` ignores `ARMY_MAX`, and re-declaring a war repeatedly adds more militia each time. Whether a limit is intended is not stated.
- It is not clear whether ground units are meant to shoot across a river with no bridge (they do hold at the shore; they can fire at targets in range) or whether this behaviour is incidental.
- Land buildings do not block movement, and the only damage to buildings comes from `strike` (raids and bombers). Whether buildings should gain hit points is a phase 2 design question.
