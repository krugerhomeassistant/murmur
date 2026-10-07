Branch perf/frame-cost: sim caching + chunked LOD render + deferred scan done and measured (8 towns x 8x: 55 -> 230 fps avg). PR next. Backlog: click-to-pin popup, shared rivers, ferries, hand-play tuning (PLAN.md).

## Update (spectator)
- Merged #10 lazy bake, #11 README perf table, #12 spectator mode (CI green incl. tests/spectate.gd).
- Next: mining/metals/materials + farm variants (PLAN backlog), ferries, animated-tile split, worker threads, screenshots, v0.2.0 tag.
- Outstanding measurement: S1 (8 towns 8x) render on device; old-build baseline.

## Update (benchmark)
- Merged #14 mining, #15 repo polish, #16 benchmark + sim budget (128 fps, p99 23.4 ms). README table uses the standard benchmark.
- Next: remaining ~22 ms spikes (planner, jobs, shops, traffic), planner support for mines, README screenshots, v0.2.0, lint in CI.
