# LESSONS_LEARNED

Format: [Problem] -> [Root Cause] -> [Verified Solution]

- [Instagram reel links could not be read] -> [instagram.com disallows automated access] -> [Ask user to describe reels or paste captions.]
- [GitHub REST `/events` too slow for a live district] -> [Unauthenticated limit is 60 req/hour] -> [Use GH Archive hourly dumps (keyless) by default; optional token gives 5,000/hour for near-live.]
- [OpenSky username/password auth fails] -> [Basic auth removed 2026-03-18; OAuth2 client credentials only] -> [Anonymous (400 credits/day) for now; OAuth2 client if user creates account.]
- [Bluesky Jetstream endpoint names differ between sources] -> [Newer v2 path `/xrpc/network.bsky.jetstream.subscribeEvents` alongside older `jetstream{1,2}.../subscribe`] -> [Test both in Phase 4; keep whichever responds; log result here.]
- [X/Twitter as a social feed] -> [Paid API] -> [Bluesky Jetstream instead; revisit only with budget.]
- [godot-ai tools act on the wrong project] -> [Session is bound to the project open in the editor; only pebble-isles was open] -> [Check `session_manage list` project_path first; open Murmur via its own launcher.]
- [Original design was data-first] -> [A pure data city is a dashboard, not a game] -> [Base game is playable offline; live data is an optional toggle behind the Signals seam.]
- [Need to test GDScript without the PC] -> [Device shell is a Linux VM; cannot run Windows Godot] -> [Sandbox can download Linux Godot from GitHub releases (`4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`). Run `--headless --path client --import` once, then `--headless --path client --fixed-fps 60 -s res://tests/smoke.gd`.]
- [Launcher broke after moving project] -> [Used a relative path to tools (`%~dp0..\tools`)] -> [Use `%USERPROFILE%\workspace\tools\godot\...` absolute path.]

- [Problem] godot-ai bound to wrong project / Windows exe launch -> [Cause] session binds to the open editor; device_bash is Linux VM, PC locked blocks computer use -> [Fix] editor_manage quit closes old editor; user double-clicks launcher.

- [Problem] game too easy, cash floods -> [Cause] income linear, upkeep tiny, no failure state -> [Fix] superlinear upkeep, fires, demand gaps, bankruptcy.

- [Problem] Edited .gd on E: via device_bash, editor still showed old parse error -> [Cause] editor doesn't rescan external edits unfocused -> [Fix] godot-ai filesystem_manage op=scan before project_run.
- [Problem] var x := dict.get(...) < n fails to parse -> [Cause] Variant inference -> [Fix] explicit type (var ok: bool = ...).
- [Problem] Selfcheck 'fire destroys zone' failed -> [Cause] empty zones regrow within 1s -> [Fix] count City.burned instead of reading lvl.
- [Problem] game_eval aborts after 8s -> [Fix] set state, wait outside, read state in a second call.

- [Variant inference on const Array elems (DIRS[i])] -> [untyped const Array yields Variant, `:=` fails] -> [declare `const DIRS: Array[Vector2i]`; use explicit types for Dictionary/Array reads]
- [Control with set_anchors_preset(TOP_RIGHT) + position=960 went off-screen] -> [anchors move origin to right edge] -> [just set position, no preset, for fixed layouts]
- [match arm inside a lambda in .connect(func...) = parse error] -> [multi-line match inside parenthesised lambda unsupported] -> [use named method]

- [Bankrupt day 50 with auto-growth] -> [planner spent down to ~60 coins repeatedly, saved nothing for power plant (needs 285+), growth starved, need penalties cliff at pop 40 dropped mood <0.4 so immigration stopped; event coin losses could push below limit] -> [planner now checks upkeep sustainability, sets `saving_for` to pause other spending when a vital service is unaffordable, need penalties ramp in over 0.8*need_pop, immigration threshold 0.35, instant event losses clamped to -40]. Soak: day 52 pop 152 min coins -38.
- [Soak test via game_eval gave bogus results] -> [made a new Signals() per call; city kept the old one so news never decayed] -> [always tick `c.sig`]
- [Startup took 30s] -> [selfcheck + heavier _scan (per-cell crime/land loops)] -> [selfcheck opt-in via `--selfcheck`; crime/land computed once per sim second, only for non-empty/near cells]
- [Split a for-body when patching with replace -> orphan indented line] -> [str.replace on partial blocks] -> [re-read the whole loop body before patching; run scan+run after every patch to catch it]

## 2026-10-07 (v8)
- [project_run autosave=true overwrote city.gd with the editor's stale buffer] -> editor saves open scripts before play -> commit file, `filesystem_manage scan`, then `project_run(autosave=false)`; verify md5 on device.
- [selfcheck loop called _twister after the twister ended -> 'pos' on empty Dictionary] -> loop must break when `twister.is_empty()`.
- [Soak "p0 forever"] -> soak City needs `seed_start()`; `City.new()` needs a Signals arg.
- [Random-accept bot broke 9 promises -> voted out day 29] -> by design: accepting a petition you can't deliver costs approval. Passive play must stay >50%: approval base 0.35 + 0.5*mood.
- [`func _set` in a RefCounted script] -> clashes with Object._set(StringName,Variant) -> rename (`_shift`).
- [Blanket sed `for i in W * H` -> `cells`] -> also rewrote a loop inside static `selfcheck()` -> non-static var in static fn parse error; check statics.
- [Editor overwrote freshly committed files from its stale buffer after stop/run] -> sequence: stop -> commit -> scan -> md5 check -> run(autosave=false).
- [Soak after game over keeps calling Diplo.second] -> duplicate log lines; harmless, soak artifact.

[Control added in _ready sits top-left with 0 size] -> [set_anchors_preset doesn't set offsets] -> [use set_anchors_and_offsets_preset(PRESET_FULL_RECT)]

[Disk copy of a script reverted to stale version after device_commit+scan while editor had it open] -> [editor buffer wins] -> [stop game, edit via godot-ai script_patch (writes through editor), verify md5]
[python str.replace silently missed match arms] -> [wrong tab depth] -> [grep for the inserted symbol afterwards]

[Problem] script_patch reload_failed code 43 on art/hud after patch -> [Cause] transient editor reload ordering -> [Fix] ignore; run project and check game_status/logs.

[Problem] game_eval calling start_game twice -> [Cause] _begin frees nodes (null queue_free), game freezes -> [Solution] one start_game per eval/run; stop+rerun if frozen.

[Problem] input_mouse motion does not move the viewport cursor -> [Solution] test hover with get_viewport().warp_mouse(m.get_canvas_transform()*world_pos) in game_eval.

[Problem] 8 towns at 8x lag, zoomed-out dense map 7 fps -> [Cause] (1) _second ran _net (full-grid x3 flood fill) + _scan + _land for every town every sim second; (2) the whole visible map was re-recorded every frame, and retained draw commands cost per frame even if cached (GL Compat) -> [Solution] cache _net by hash of grid/lvl/layers; LOD for off-screen towns; chunk nodes + texture bake zoomed in + flat tiles zoomed out; measure with F3 overlay and tests/bench*.gd.

[Problem] place() 3-10 ms per tile (drag painting stalls) -> [Cause] every place() called a full _scan() -> [Solution] scan_dirty flag, City.flush() at tick start and in Main._process.

[Problem] Godot Linux binary usable in the cloud container for headless benches -> [Solution] download github release 4.7.2-stable zip to scratch; addon parse errors from godot_ai are expected (addon not in repo clone) and harmless.

[Problem] game_eval hangs >10s when building a big town -> [Solution] it is just slow; wait and re-eval, or build in smaller evals.

[Problem] godot-ai `input_key`/`debug_status` freeze the running game -> [Cause] they suspend it -> [Solution] call `game_manage resume` right after; read results through `@export` vars via `get_node_info` (files under user:// are not visible from the VM).

[Problem] GDScript parse errors after instrumenting city.gd -> [Cause] for-loop var shadowing a local, locals not visible across functions -> [Solution] rename, use member vars; parse-check with the local binary first: `/home/claude/godot-bin/godot --headless --path client -s tests/X.gd` from the repo root (not client/).

[Problem] Benchmark inflated (days_advanced 0) -> [Cause] the human town ended early -> [Solution] benchmark runs spectator mode and reports `towns_over`.

[Problem] Headless numbers disagreed with felt lag -> [Cause] stutter is CPU sim spikes (20 ms steps, batched off-screen towns), invisible to averages -> [Solution] judge by the windowed benchmark (F9), p99 and slow-frame count; per-frame `SIM_BUDGET_MS`, `MAX_BATCH`, layout-hash scan skipping.

- [Wars sometimes never ended (units parked in range along the front but could not hit each other)] -> [stop distance ignored the sideways lane offset that range checks include, so two units 88 px apart along the line with a 100 px lane gap were out of range forever] -> [stop distance now subtracts the lane gap and LANE is kept small (35 px per lane unit) so every weapon can close; tests/war.gd passed 6/6 afterwards. Flaky headless tests deserve a loop of runs, not one]

- [Planner never built military buildings under threat] -> [service scores are divided by cost/100+0.5 and must beat a 0.2 floor, so a bonus of ~1 times threat lost to cheap services] -> [bonus scaled to 3-6 times threat for barracks/base/radar/naval yard; test with a hostile pair and topped-up coins (tests/ai.gd)]

- [Game run on the device hit "Could not find type NetPlay"] -> [the editor's global class cache is stale after files are added by git/sync] -> [`filesystem_manage op=scan` in godot-ai, stop, then `project_run` again].
- [Start menu stays on screen after `start_game` via game_eval] -> [a fresh `Setup.new()` replaced `Main.setup`, orphaning the real panel in the HUD] -> [call `open_setup()` first, then `start_game`, then free the HUD child whose script is setup.gd].
- [Capturing media blocks eval with EVAL_HUNG] -> [a long fast-forward loop runs on the game thread; the call times out at 10 s but keeps running] -> [ignore the error, wait, then query state].
- [CI "Net cache and shared river tests" step hung 20+ min after adding the two-process mp test] -> [the test client only exits after it syncs; if the server was not listening yet (slow runner) it never connected, and `OS.execute` blocks forever] -> [the `--mp-test` client retries joins, has a 40 s deadline, and every CI test line runs under `timeout 600`]. Any test that spawns a process must have its own deadline.
- [CI "hung" at tests/pmine.gd for 10+ min on some runs] -> [the test was unseeded and ran a fixed 60000 steps; a town that grows to 600+ pop costs minutes per run on a slow runner, so it was slow, not stuck] -> [fixed seed and stop as soon as a mine and a foundry exist (3 s)]. Unseeded long sims in CI need a seed and an early exit.

- [Audit suggested lowering planner mood gates (zoning 0.38, immigration 0.35) to grow stalled towns] -> [measured over 3 runs x 4 towns x 4000 sim-s: lowering them cut average pop from ~142 to ~75; softening emigration/austerity did nothing measurable] -> [Only the tax controller helped (74 -> ~180). Always A/B sim changes with `tests/growth.gd` repeated 3x (it is not deterministic: single runs vary 100 to 220).]

- [Waited ~15 min on a benchmark that never started, polling a stale result file] -> [F9 sent to a suspended game (time_scale 0); the old `benchmark_result.json` was never removed, so "file exists" meant nothing] -> [Move the old result away first; verify the action started (`debug_status`: frames advancing, not suspended; `get_node_info`); poll liveness plus a fresh output; trigger with `call_deferred('run_benchmark')`; after two unchanged waits, change method or report instead of sleeping again.]
- [CI smoke failed on `main`-era code, passed locally] -> [selfcheck "planner did not grow" is probabilistic (~7%: mood gate stall, global `shuffle()`); one local pass proved nothing] -> [Measure flake rate with 25-40 repeat runs before and after; seeding `rng` alone did not help because `shuffle()` uses the global RNG.]
- [Merged a PR while smoke was still running because the poll timed out and I only grepped for failure] -> [absence of a failure is not success] -> [Merge only when all 3 checks are completed:success; pr.sh enforces it.]
