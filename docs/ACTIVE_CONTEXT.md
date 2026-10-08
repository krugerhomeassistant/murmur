# ACTIVE CONTEXT (read first)

**2026-10-08 late:** branch `perf/net-growth` (PR pending): net re-solve 10x cheaper, `--war` benchmark, blast-position fix, lane/pavement rendering, rivers meet at borders, shelling visual, showcase media (`tests/showcase.gd`, `tests/reel.gd`, README GIF retaken). Next: finish perf pass, audit, v0.2.0 release. Then the war rework (docs/PLAN.md). Planner towns stall near 100 pop (audit item).

Last updated 2026-10-08.

## State
`main` is green. Done since the last refresh: release pipeline (docs/RELEASING.md; `murmur-release` and `murmur-benchmark` skills saved), README screenshots + hero GIF (docs/media, retake with scripts/MEDIA.md and `--capture`), multiplayer P0-P3 (docs/MULTIPLAYER.md): transport, `Cmd` command layer, owner-checked commands, snapshot sync, lobby UI, `--server` dedicated mode, mp test (tests/mp.gd). Land-value pass sped up (PR #29).
User authorised merging my own PRs. The proxy blocks branch deletion and GraphQL (use REST). The device repo (`E:\Projects\Personal\game\murmur`) is a real git clone: fetch/checkout over there (run godot-ai `filesystem_manage scan` after adding scripts). Standing rule: the performance pass is the LAST step before each release.

## Next (in order)
1. Multiplayer P4 (chat, disconnect/rejoin), P5 (human-vs-human treaties/war: `Diplo` assumes one human), P6 (server polish/docs). Then re-measure snapshot size with 500+ pop towns.
2. Release v0.2.0 when the user says: perf pass first (stage costs: scan_net, jobs, planner; add a war benchmark scenario), then `murmur-release`.
3. Smaller: lint (gdtoolkit) in CI, ferries/cargo ships (unclear value), threading only if the benchmark improves.
4. Waiting on user: hand-play tuning at 500+ pop, repo description/topics on GitHub, deleting merged remote branches (proxy cannot).

## Gotchas learned
See LESSONS_LEARNED.md. Latest: lambdas capture variables by value (mutate arrays/dicts instead of assigning); zstd cannot decompress dynamically (use gzip with a size cap); `start_game` via eval needs `open_setup()` first and the real Setup panel freed.
