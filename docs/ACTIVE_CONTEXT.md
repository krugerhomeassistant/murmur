# ACTIVE CONTEXT (read first)

Last updated 2026-10-08.

## State
`main` is green. Shipped since the last refresh: multiplayer P0-P6 (host-authoritative ENet, chat, rejoin, PvP diplomacy, dedicated `--server`), security hardening (#44), planner tax controller (avg planner pop 74 -> ~180), growth-only net re-solve (~10x cheaper), rivers meet at borders, blast position fix, lane/pavement rendering, README media from a hand-built showcase town (`tests/showcase.gd`, `tests/reel.gd`, `scripts/MEDIA.md`), measured benchmark table (A/B at 1280x720 on the i7-8700 + GTX 1070 Ti, plus `--war`).
Standing rules: user authorised self-merge; PR bodies carry NO "Generated with Claude Code"/session-link footer (user asked to stop); perf pass is the LAST step before a release; proxy blocks branch deletion and GraphQL (REST only); device VM has no GitHub credentials; device repo is `E:\Projects\Personal\game\murmur` (git clone, fetch/checkout there, then godot-ai `filesystem_manage scan`).

## Next (in order)
1. v0.2.0 release: perf re-check (benchmark again after the planner change), `murmur-release` skill, portable zip on the device, GitHub release (confirm with user before publishing).
2. War rework (docs/PLAN.md "War rework", user wants Age of Empires / Empire Earth style): armies fight in the town, ground units blocked by water, boats on rivers, real air units, sieges.
3. Audit follow-ups in docs/PLAN.md (rejoin token, snapshot backpressure, server password/persistence, missing tests, CI caching, UX settings/help).
4. Waiting on user: real two-player test, 500+ pop hand-play tuning, repo description/topics, deleting merged branches (command given), enabling auto-delete of head branches.

## Gotchas learned
See LESSONS_LEARNED.md. Latest: always A/B sim changes 3x (non-deterministic); lowering planner mood gates hurt; `from_dict` whitelists `SAVE_KEYS`; showcase scripts must be loaded fresh in a running game (`GDScript.new()` + `source_code`) because `load()` caches.
