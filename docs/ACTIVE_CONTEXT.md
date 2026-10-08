# ACTIVE CONTEXT (read first)

Last updated 2026-10-07 (night, user asleep; will playtest in the morning).

## State
`main` is green. Merged this session: #18 world view + real border roads, #19-#20 war visuals and real armies, #21 unit variety (16 kinds incl. ships, vet ranks, Army window), #22 warships + bomber/raid damage, #23 AI armies, #24 farm variants, #25 planner mining/foundry, #26 farm art.
User explicitly authorised merging PRs myself. Proxy blocks branch deletion and GraphQL (use REST); device repo is NOT a git mirror of main: files are pushed over by hand (SendUserFile + device_commit_files); restore it to clean `main` when convenient.

## Next (in order)
1. Performance pass (user: after the additions): remaining sim spikes (planner, jobs, shops, traffic, scan_net); benchmark scenario for the world view with a war running; Military.fight is O(n^2) per pair (6 ms at 110 a side, army cap 150). Standard benchmark: F9 or --benchmark, 8 towns, 8x, all overlays; README table must stay true.
2. Ferries / cargo ships (unclear value, ponytail question).
3. Waiting on user: v0.2.0 release (`scripts/bump.py`, rebuild `dist/Murmur-portable.zip`), README screenshots/GIF, hand-play tuning at 500+ pop, multiplayer design is decided (docs/MULTIPLAYER.md), P0 next.
4. Smaller: lint (gdtoolkit) in CI, `murmur-release` / `murmur-benchmark` skills via propose_skills, threading (only if benchmark improves).

## Gotchas learned
See LESSONS_LEARNED.md. Latest: CI hung 35+ min on huge armies (fixed by flat-array fight + ARMY_MAX); planner needs big score bonuses to compete (scores are divided by cost); `place()` needs a road neighbour so tests must pick roadside tiles.
