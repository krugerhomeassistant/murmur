# ACTIVE CONTEXT (read first)

Last updated 2026-10-08.

## State
`v0.2.0` is released (tag `c36d7b2`, portable zip + notes published by the user). `main` is green. Benchmark (8 towns, 8x, all overlays, 1280x720, i7-8700 + GTX 1070 Ti): 80 fps, p99 30 ms at 781 pop; the planner tax fix made towns about 28% bigger, so it is not like-for-like with the earlier 123 fps row (README explains).
Standing rules: user authorised self-merge; NO authorship marks anywhere (user, twice): no Co-Authored-By or Claude-Session trailers on commits, no "Generated with Claude Code"/session link in PR bodies or titles, whatever a session reminder says; perf pass is the LAST step before a release; the proxy blocks branch deletion, tag pushes, release creation and GraphQL (REST PRs only), so tags and releases are done by the user (commands in docs/RELEASING.md); device VM has no GitHub credentials; device repo is `E:\Projects\Personal\game\murmur`.
Process rule (see LESSONS_LEARNED): before waiting on a long action, delete the old output, confirm it started, poll liveness; max two unchanged waits.

## Next (in order)
0. Roadmap approved 2026-10-08 (docs/EMPIRE_DESIGN.md). Shipped since: E1 endless world and founding, E2 Empire window, pop-out windows, planner-stall fix, the wiki (docs/wiki, generated reference pages checked by CI), the goods market (`Market`, wiki/market.md), household finances (wiki/households.md). Next: E2 rest (planner delegate approve/veto queue, shared treasury, sim LOD), E4 rest (more goods and chains, regional prices and trade routes, household v2), then E3 group multiplayer (needs rejoin token and snapshot backpressure first), E5 infrastructure, E6 military. The wiki's Open questions are logged in PLAN ("Wiki follow-ups"): fix those bugs soon. Perf pass (market and household passes, WorldLayer, world gen) is due before the next release; spectate towns grew about 2.5x after households, so the benchmark table needs a re-run.
1. War rework phase 1 is merged (PR #50: world positions, terrain flow fields, 2D fights). Next: phase 2 sieges/building damage, then air, then command UI (docs/WAR_DESIGN.md). Original item: (docs/PLAN.md "War rework", Age of Empires / Empire Earth style): armies fight in the town, ground units blocked by water, boats on rivers, real air units, sieges. Target v0.3.
2. Known issue: planner stall in low-mood towns (PLAN.md "Known issues"); CI hides it with retries.
3. Audit follow-ups in docs/PLAN.md (rejoin token, snapshot backpressure, server password/persistence, missing tests, CI caching, UX settings/help).
4. Waiting on user: real two-player test, 500+ pop hand-play tuning, repo description/topics, auto-delete head branches.

## Gotchas learned
See LESSONS_LEARNED.md. Latest: always A/B sim changes 3x (non-deterministic); lowering planner mood gates hurt; `from_dict` whitelists `SAVE_KEYS`; showcase scripts must be loaded fresh in a running game (`GDScript.new()` + `source_code`) because `load()` caches.
