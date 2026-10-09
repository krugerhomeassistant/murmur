# Domination: the end goal, growth, war frequency and depth

Status: plan, approved for execution order by the owner on 2026-10-09. Nothing here is built yet unless a PLAN.md box says so.
Companion docs: [EMPIRE_DESIGN.md](EMPIRE_DESIGN.md) (world, empire mode, groups), [WAR_DESIGN.md](WAR_DESIGN.md) (battle model), [wiki/war.md](wiki/war.md) (how war works today).

## 1. Why this exists

The owner's goal: every city should aim at world domination, won by peace (economic, cultural, diplomatic) or by war (conquest). Today the game has no end state at all. Checked in the code on 2026-10-09:

- No victory condition. `Empire` only flags `GAME OVER` when a town's `over` is set (a disaster or bankruptcy style end). Nothing ends a game when one group holds the map.
- Towns never grow past the "annex when cramped" rule; there is no pressure to expand beyond that.
- War needs `temper < -0.7`, a military lead above 0.4, and then a 40% roll inside a 45 to 90 second event tick (`Diplo.second`, `_event`). Against a healthy neighbour that is rare, and it stops once treaties soften opinions. That is why it feels rare.
- Peace has no reward path: `pact`, `alliance` and `tribute` exist, but nothing converts influence into territory or a win.

## 2. Victory

Every game has a *domination* goal with two routes. A player or AI group wins when it meets either:

1. **Conquest:** controls at least 70% of the claimed land of all groups for 3 in-game years, or is the last group with a town.
2. **Hegemony (peace):** holds the top score for 5 in-game years with at least 40% of the land under treaty (alliance or vassal) and no war declared by its vassals. Score = population + trade volume + culture (see 5) + land. Vassals count as land for the overlord.

Rules:
- The win is shown in the Empire window as a progress bar per group, so every player sees the race.
- Game over is a screen with the winning route, not a silent flag. Continuing after a win is allowed (sandbox).
- Victory is only checked on the host in multiplayer and synced as an event.
- Constants live in `constants.md` (generated) so they can be tuned without code changes.

Open: whether a human can lose by being conquered (yes, when their last town falls; spectators keep watching).

## 3. Growth, faster

Diagnosis from the owner and the benchmark data: towns plateau (the spectate benchmark reaches about 780 people in 8 towns at 8x). Growth work must not break the sim cost budget (perf is the last step of each release, see `murmur-release`).

Targets (measured, not guessed; each is an A/B run three times, per LESSONS_LEARNED, because the sim is not deterministic):

- Time to 500 population in a fresh spectate town: measure first (headless `bench.gd` + windowed run), then cut it by a third.
- Growth rate: planner builds the next housing/job pair as soon as demand exceeds supply, not on a fixed timer. Check `planner.md` for the current gates; they are the first thing to loosen (lowering mood gates was tried and hurt, see LESSONS_LEARNED, so change one gate at a time).
- Land: when a town is cramped, annex earlier (the auto-annex threshold is a constant) and price annexing by distance from the centre, not flat.
- Expansion: AI groups found new towns on free plots once their own is at 70% housing use (the founding cost already grows with distance).

Each growth change needs: a test that the population curve rises (`tests/growth.gd`, new), and a benchmark row in the README table before the release.

## 4. War: more frequent, and with a purpose

Changes, in order:

1. **Ambition per town.** Each AI town gets `ambition` in 0..1 (derived from its planner's expansion goal and its military share). A high-ambition town with a military lead starts a war toward the weakest neighbour that blocks its expansion, instead of waiting for a random opinion crash.
2. **Border pressure.** Towns that share a border (road-linked, `Diplo.linked`) gain a "border tension" each day. Tension, not temper alone, gates war. The 40% roll stays but is per day, not per event.
3. **War goals.** A declared war states its goal: `tribute`, `land` (annex a strip, existing surrender path), or `total` (occupy). The goal decides when it ends and what the winner gets. This turns wars into steps toward domination instead of random fights.
4. **Peace routes.** Vassalage: a surrendered town may become a vassal (keeps its own coins and buildings, pays a fixed share of its trade to the overlord, cannot declare war). Alliances can end in a shared victory check.
5. **Visibility.** A war banner in the Empire window with the goal, progress and ETA; the owner should see why a war started (the message names the trigger).

Acceptance: over a 30 minute spectate run with 8 towns and default settings, at least 2 wars start and at least 1 ends in a result other than stalemate, measured 3 times. Benchmark `--war` must not regress.

## 5. Depth: each component gets its next layer

Each row is one or two PRs. Order is set by how much each unlocks the others.

| Component | Next layer | Why it matters for domination |
|---|---|---|
| Economy | more goods (wood, fuel, tools) and chains; regional price differences and trade routes (E4) | trade volume is a score and the hegemony route |
| Households | per-household view and families (E4 part 2) | population growth needs visible reasons to stay |
| Infrastructure | rail, ports, power tiers (E5) | conquest needs logistics; ports are the naval route |
| Military | war phases 2 to 4 (`WAR_DESIGN.md`), research, logistics (E6) | conquest route |
| Diplomacy | ambition, border tension, war goals, vassals (sections 4) | both routes |
| Culture (new, small) | a culture score from buildings (theatres, museums, schools) and civics; feeds hegemony score | the peaceful route needs a second currency |
| Civics | civic choices tied to the win route (militarist vs trade league) | identity per town |
| Multiplayer | group play (E3): owners share a group, group diplomacy and victory | domination is a group goal in multiplayer |

Culture is deliberately small: one score, fed by about five buildings and two civics, displayed in the Empire window. No new subsystem.

## 6. Code readability (do with every phase, not after)

`client/scripts/city.gd` is about 3,800 lines and holds almost everything. Split it, one module per concern, without changing behaviour (each split PR runs the full headless suite):

- `city_housing.gd`: homes, households, landlords (`_households`).
- `city_services.gd`: coverage, service trade (`_svc_trade`), planner service rules.
- `city_utilities.gd`: power, water, sewage, networks glue.
- `city_budget.gd`: taxes, focus (`focus`, `_auto_focus`), loans, savings tax.
- `city_war.gd`: the thin city side of military (arms, `_pay`), keeping `Military` as the logic.
- `city.gd` keeps the public facade and the save/load keys (`SAVE_KEYS`), so callers and saves do not change.

Rules: no file over about 1,200 lines; each module has a header comment with its job; names say what they do; every new rule has a test; the wiki page for the mechanic is updated in the same PR. `gdlint` stays clean.

## 7. Docs and portable build stay current

- Each release: CHANGELOG, README (benchmark table, run steps), wiki pages, `PLAN.md` boxes, `ACTIVE_CONTEXT.md`.
- The portable zip is produced by `build.yml` on every push to `main` and attached on tag push. Each release notes which build stamp it is.
- The README roadmap points at this document. `docs/README.md` indexes it.

## 8. Execution order

1. Add `tests/growth.gd` and a measured baseline (time to 500 pop, 3 runs). No behaviour change yet.
2. Victory conditions and the Empire progress bar (section 2), with tests for both routes.
3. War ambition, border tension, war goals (section 4, items 1 to 3). Measure war starts over 30 minutes.
4. Vassalage and peace route scoring (section 4, item 4; section 2 hegemony).
5. Growth tuning (section 3), one gate per PR, each with the A/B rule.
6. Culture score (section 5).
7. Split `city.gd` (section 6): start with `city_housing.gd`, then `city_services.gd`, then the rest. Can run in parallel with 3 to 6 only if each PR is a pure move.
8. Depth layers from section 5, in the table order.
9. Perf pass, benchmark table refresh, release (per `murmur-release`).

Each step is its own PR, updates PLAN.md and ACTIVE_CONTEXT.md, and ends with the full headless suite and `check_repo.py` green.

## 9. Risks

- Making war frequent can make towns unplayable. Guard: a war cannot start while the target has a treaty of alliance or vassal, and a town below 50% mood cannot declare wars.
- Growth tuning can raise sim cost. Guard: perf pass each step, not only at release.
- Victory can end a game too early. Guard: the 3-year and 5-year timers, and sandbox continue.
- The owner has not yet played the new systems on a real screen. Each phase ends with a short hand-play note in the PR.

## 10. Open questions for the owner

- Are 3 years (conquest) and 5 years (hegemony) the right lengths, or should they follow the game speed?
- Should vassals count as land for the hegemony route, or only as allies?
- Are human towns allowed to declare war on AI towns in spectate mode, or only in play mode?
