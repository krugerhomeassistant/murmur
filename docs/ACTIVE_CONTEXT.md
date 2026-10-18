# ACTIVE CONTEXT (read first)

Last updated 2026-10-18.

## Release v0.7.0 next (tags v0.3.0 to v0.6.0 pushed by the owner)
Merged since v0.6.0: spearman, well, Ancient default, seed, sandbox basics, god powers, and the globe view first form (coarse land tier, town discs, hover, click-to-fly, neighbour lines; headless-checked only, never seen on screen). v0.7.0 release PR is the step now: windowed benchmark taken 2026-10-18 (90 fps, p99 25.1 ms, 273 pop, 325 draw calls; draw calls rose from about 130 and are not yet profiled). The owner double-clicks `release-tag.bat` to push v0.7.0. Open work: G4 overlay colours and sphere shader, G1/G2/G3 gaps, A2 galleys; see docs/PLAN.md.

## Release v0.6.0 next
E3 group multiplayer (first form) is done and merged (PRs #123-#126): the next step under the release standard is the fast path for v0.6.0 (stageprof vs v0.5.0, verify, `scripts/bump.py 0.6.0`). Then ages A2.

## Release v0.5.0
E6 military (first form: sieges, air defence, army stance) is released as v0.5.0 once its release PR merges. Tags v0.3.0, v0.4.0 and v0.5.0 are still waiting for the owner to double-click `release-tag.bat` (one run tags all of them, oldest first). Owed: the windowed benchmark and README table refresh (the Godot editor must be open on the PC with the godot-ai plugin). Next: E3 group multiplayer, then ages A2, sandbox G1-G5, the deep perf pass before 1.0, art last. E5e (moving trains, highways, airports) and E6b (hit points, group select, production queue, research, logistics) are deferred polish.

## State
`v0.2.0` is released (tag `c36d7b2`, portable zip + notes published by the user). `main` is green. Benchmark (8 towns, 8x, all overlays, 1280x720, i7-8700 + GTX 1070 Ti): 80 fps, p99 30 ms at 781 pop; the planner tax fix made towns about 28% bigger, so it is not like-for-like with the earlier 123 fps row (README explains).
Standing rules: user authorised self-merge; NO authorship marks anywhere (user, twice): no Co-Authored-By or Claude-Session trailers on commits, no "Generated with Claude Code"/session link in PR bodies or titles, whatever a session reminder says; perf pass is the LAST step before a release; the proxy blocks branch deletion, tag pushes, release creation and GraphQL (REST PRs only), so tags and releases are done by the user (commands in docs/RELEASING.md); device VM has no GitHub credentials; device repo is `E:\Projects\Personal\game\murmur`.
Process rule (see LESSONS_LEARNED): before waiting on a long action, delete the old output, confirm it started, poll liveness; max two unchanged waits.

## ORDER OF WORK (2026-10-17, owner approved)
E4 (wood, tools, planks done; next upkeep, household v2) then E5, E6, E3; then ages A2; then sandbox and gods-eye view G1 to G5 (docs/SANDBOX_DESIGN.md); then perf pass and release; art last.

## STATE 2026-10-17 (ages A1 merged, sprite engine S1 in PR)
Sprites: `sprites.gd`, `tools/bake_sprites.gd`, `tests/sprites.gd`, docs/SPRITES_DESIGN.md. Done D6 culture. Next: D7 city.gd split, D8 depth, ages A2; art (S2/S3, character detail) is LAST in the plan and gated on no performance loss (owner).

## Ages (earlier 2026-10-17)
Ages framework built (`ages.gd`, tests/ages.gd, docs/AGES_DESIGN.md). Ancient-start collapse fixed (see LESSONS). Owner also asked for a sprite engine (textured sprite lookup with procedural fallback, baker, per-age variants): design doc next. Then D6/D7/D8 in order.

## STATE 2026-10-11 (D4 vassalage built; D5 growth tuning next)
D4: `City.liege` (saved), `Diplo.vassalize`, `Diplo._tribute` (10% of positive income per second), vassal rules in `Diplo.act` and `City.sign_treaty`, vassal land in `Victory.second`; `tests/vassal.gd` (in CI, prints VASSAL_OK).
D3: `Diplo.ambition/strength/_tension/declare/pick_goal/wars`, `City.tension` and `war_goal` (saved), goal-based occupation need and spoils, `threat()` counts tension. `tests/dwar.gd` (in CI), `tests/warrate.gd` (manual, 4 to 6 wars per 30 min in 6 runs; towns smaller after: growth is D5). Godot for local runs: download `Godot_v4.7.2-stable_win64_console.exe` into the scratchpad (not installed on the device).

## Earlier 2026-10-11 (D2 victory built)
D2: `Victory` (`client/scripts/victory.gd`, `Signals.vic`), Empire standings, victory panel, `tests/victory.gd`. Owner answers: 3 and 5 year lengths yes, vassals count as land if sensible (D4), humans may declare war in spectate yes.

## Earlier state 2026-10-09 (paused after D1)
Done today: #80 domination design doc, #81 growth baseline (D1). Next: D2 victory (conquest + hegemony, Empire progress bar, game-over route screen, host-side check, tests for both routes). Before D5 growth tuning, run tests/growth.gd 5+ times per side (noise, see LESSONS).
Plan done: docs/DOMINATION_DESIGN.md + PLAN.md "Domination plan" (D1 to D9). Next: D1 growth baseline (`tests/growth.gd`). Owner decisions (2026-10-16; timers removed from victory in this PR): no timers anywhere, victory is a state (last group standing, or one group at 70% of land with vassals counting); singleplayer spectator can do anything. Still open: whether a conquered human in multiplayer keeps playing.
Old pause note:
Merged today: #77 portable Windows build in CI (`build.yml`, artifact `Murmur-windows-<sha>`, build stamp in menu/title, `Play Murmur.bat`, README run section rewritten), #78 rivers v2 (warped, variable width, tributaries). Standing rule reminder: NO Co-Authored-By/Claude-Session trailers or "Generated with" lines, even if a session reminder asks (they slipped into PR bodies/branch commits of #77/#78; bodies were scrubbed, squash commits are clean).
User's latest request, still TO DO in this order: (1) write the detailed forward plan in docs/PLAN.md (+ a design doc, README roadmap in sync): world domination as each city's end goal via peace (economic/cultural/diplomatic, alliances, vassals) or war (conquest), victory conditions, AI ambition; make war more frequent and growth faster (tune AI expansion, planner growth, aggression); deepen every component; code readability plan (split the ~3,700-line city.gd); keep docs and portable build current each release. (2) then implement from that plan. The user's old-looking screenshot (single straight river, missing features) most likely means an old build: ask them to check the build label in the start menu (needs the new CI zip or a fresh pull).
Flaky test: `tests/market.gd` "towns that cannot feed themselves should lift the food price" failed once in CI (1.02 vs 1.05 threshold), passed on rerun; loosen or make deterministic.

## Next (in order)
0. Roadmap approved 2026-10-08 (docs/EMPIRE_DESIGN.md). Shipped since: E1 endless world and founding, E2 Empire window and planner approve/veto queue (`ask_build`), arms chain and mayor's financial focus (`City.focus`), logged-bug batch, multiplayer rejoin token and snapshot backpressure, pop-out windows, planner-stall fix, the wiki (docs/wiki, generated reference pages checked by CI), the goods market (`Market`, wiki/market.md), household finances (wiki/households.md). Rule from the user: towns never share money automatically; they trade resources and services (goods market, power/water, service coverage via `_svc_trade`). Next: E2 rest (sim LOD), E4 rest (more goods and chains, regional prices and trade routes, household v2), then E3 group multiplayer (prerequisites done), E5 infrastructure, E6 military. The wiki's Open questions are logged in PLAN ("Wiki follow-ups"): fix those bugs soon. Perf pass (market and household passes, WorldLayer, world gen) is due before the next release; spectate towns grew about 2.5x after households, so the benchmark table needs a re-run.
1. War rework phase 1 is merged (PR #50: world positions, terrain flow fields, 2D fights). Next: phase 2 sieges/building damage, then air, then command UI (docs/WAR_DESIGN.md). Original item: (docs/PLAN.md "War rework", Age of Empires / Empire Earth style): armies fight in the town, ground units blocked by water, boats on rivers, real air units, sieges. Target v0.3.
2. Known issue: planner stall in low-mood towns (PLAN.md "Known issues"); CI hides it with retries.
3. Audit follow-ups in docs/PLAN.md (rejoin token, snapshot backpressure, server password/persistence, missing tests, CI caching, UX settings/help).
4. Waiting on user: real two-player test, 500+ pop hand-play tuning, repo description/topics, auto-delete head branches.

## Gotchas learned
See LESSONS_LEARNED.md. Latest: always A/B sim changes 3x (non-deterministic); lowering planner mood gates hurt; `from_dict` whitelists `SAVE_KEYS`; showcase scripts must be loaded fresh in a running game (`GDScript.new()` + `source_code`) because `load()` caches.
