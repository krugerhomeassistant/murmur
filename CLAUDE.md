# Murmur (agent notes)
Godot 4.7 GDScript project in `client/`. Read `docs/ACTIVE_CONTEXT.md`, `docs/PLAN.md`, `docs/LESSONS_LEARNED.md`, `docs/TOOLING_AND_MCP.md` first; update them as you work (see `docs/README.md`).
Workflow: feature branch, CHANGELOG [Unreleased] entry, PR, CI (`smoke` job) green, merge commit. Tests: `godot --headless --path client -s tests/<name>.gd`.
Standing rule: the repo must always look professional and be accurate. README claims (paths, features, numbers) must be true and measured; run `python3 scripts/check_repo.py` before every PR; keep CHANGELOG, docs/ and README in sync with every change.
Benchmark standard: windowed, 8 towns, 8x speed, all overlays on; report fps/p99/CPU/GPU/RAM/VRAM and hardware.
Release rule: performance pass (profile, fix, re-run the standard benchmark, update the README table) is always the LAST step before a release; see `docs/RELEASING.md`.
