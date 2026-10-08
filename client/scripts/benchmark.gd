class_name Benchmark
extends Node
## Standard windowed benchmark: 8 towns, 8x speed, "all" overlay, vsync off.
## Run: `godot --path client -- --benchmark` (or press F9 in game). Fast-forward ~50 sim-min, warm-up 15 s, sample 30 s,
## prints a markdown table and writes user://benchmark.json (and res://benchmark_result.json from the editor), then quits when started with --benchmark.
const FAST_FORWARD := 30000  # 0.1 s steps simulated before the window opens: about 50 sim-minutes, so towns are grown
const WARM := 15.0
const SAMPLE := 30.0
var m
var quit_after := false
var t := 0.0
var last_us := 0
var ft: Array[float] = []
var cpu := 0.0
var gpu := 0.0
var calls := 0.0
var calls_max := 0.0
var sim := 0.0
var draw := 0.0
var n := 0
var day0 := 0
var steps0 := 0
var slow := [0, 0.0, 0.0, 0.0, 0.0]  # frames over 25 ms: count, sum of frame, sim, chunk, draw ms
@export var status := ""  # readable through the editor's remote inspector while running
@export var result_json := ""
var beat := -1
var war := "--war" in OS.get_cmdline_user_args()  # `-- --benchmark --war`
var watch := "--watch" in OS.get_cmdline_user_args()  # camera follows the busiest town (not the standard measurement; numbers are tagged)
var phase := 0  # 0 warm-up, 1 sampling, 2 done


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	seed(20261007)
	m.bench_seed = 20261007
	m.open_setup()
	m.start_game({"name": "Bench", "towns": 8, "mood": 1, "diff": 1, "land": 1, "river": 3, "auto": 2, "policy": true, "expand": true, "guide": false, "spectate": true, "temp": true})
	for _i in FAST_FORWARD:  # same cadence as the main loop: viewed town every step, others in 0.5 s batches
		m.sig.tick(0.1)
		if _i % 10 == 0:
			Diplo.second(m.towns, m.city.rng)
		for c in m.towns:
			if c == m.city:
				c.tick(0.1)
			else:
				c.pend += 0.1
				if c.pend >= 0.5:
					c.tick(c.pend)
					c.pend = 0.0
	if war:  # four wars (0v1, 2v3, 4v5, 6v7) declared once the towns have grown, each side with a mixed army, so the marches and battles fall inside the sample
		for k in range(0, 8, 2):
			for t in [m.towns[k], m.towns[k + 1]]:
				t.coins = 5000.0
				for u in ["inf", "inf", "tank", "art", "inf", "gren", "tank", "art"]:
					t.army.append(Military._unit(u))
			Diplo.act(m.towns[k], m.towns[k + 1], "war")
	m.speed = 8.0
	m.overlay = "all"
	m.follow = watch
	m.cam.zoom = Vector2.ONE
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - last_us) / 1000.0 if last_us > 0 else 0.0
	last_us = now
	t += dt / 1000.0
	m.speed = 8.0
	m.overlay = "all"
	if int(Time.get_ticks_msec() / 5000) != beat:  # progress heartbeat so a stalled run is visible
		beat = int(Time.get_ticks_msec() / 5000)
		status = "phase %d t %.1f samples %d day %d fps %d" % [phase, t, n, m.towns[0].day, Engine.get_frames_per_second()]
	if phase == 0 and t >= WARM:
		phase = 1
		t = 0.0
		day0 = m.towns[0].day
		steps0 = m.steps_done
		City.prof.clear()
	elif phase == 1:
		var vp := get_viewport().get_viewport_rid()
		ft.append(dt)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		var c := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		calls += c
		calls_max = maxf(calls_max, c)
		sim += m.sim_ms
		if dt > 25.0:
			slow[0] += 1
			slow[1] += dt
			slow[2] += m.last_sim
			slow[3] += m.last_chunk
			slow[4] += m.last_draw
		draw += m.draw_ms
		n += 1
		if t >= SAMPLE:
			phase = 2
			_report()


func _pct(a: Array[float], p: float) -> float:
	return a[mini(int(a.size() * p), a.size() - 1)]


func _report() -> void:
	var s := ft.duplicate()
	s.sort()
	var avg := 0.0
	for v in s:
		avg += v
	avg /= s.size()
	var pop := 0
	for c in m.towns:
		pop += c.pop
	var r := {
		"hardware": "%s | %s | %d threads | %d MB RAM" % [OS.get_processor_name(), RenderingServer.get_video_adapter_name(), OS.get_processor_count(), int(OS.get_memory_info().get("physical", 0)) / 1048576],
		"build": "Godot %s, %s build, %s, window %s" % [Engine.get_version_info().string, "debug (editor/debugger)" if OS.is_debug_build() else "release", RenderingServer.get_current_rendering_method(), str(DisplayServer.window_get_size())],
		"war": war,
		"watch": watch,
		"scenario": ("war: four pairs declared war after the growth fast-forward, " if war else "") + "8 towns grown by %d sim-s fast-forward, then 8x speed, all overlays, zoom 1.0, vsync off, %ds warm-up, %ds sample" % [FAST_FORWARD / 10, int(WARM), int(SAMPLE)],
		"fps_avg": 1000.0 / avg, "frame_ms_avg": avg, "frame_ms_p50": _pct(s, 0.5), "frame_ms_p95": _pct(s, 0.95), "frame_ms_p99": _pct(s, 0.99), "frame_ms_max": s[-1],
		"render_cpu_ms": cpu / n, "render_gpu_ms": gpu / n, "draw_calls_avg": calls / n, "draw_calls_max": calls_max,
		"sim_ms_avg": sim / n, "draw_ms_avg": draw / n,
		"ram_static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"vram_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"texture_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"second_stage_us_total": City.prof.duplicate(), "slow_frames": slow[0], "slow_avg_ms": slow[1] / maxf(slow[0], 1), "slow_sim_ms": slow[2] / maxf(slow[0], 1), "slow_chunk_ms": slow[3] / maxf(slow[0], 1), "slow_draw_ms": slow[4] / maxf(slow[0], 1), "effective_speed": (m.steps_done - steps0) * 0.1 / SAMPLE, "days_advanced": m.towns[0].day - day0, "total_pop": pop, "towns_over": m.towns.filter(func(c): return c.over != "").size(), "pop_each": m.towns.map(func(c): return c.pop),
	}
	result_json = JSON.stringify(r)
	print("BENCHMARK_JSON " + result_json)
	for path in ["user://benchmark.json", "res://benchmark_result.json"]:  # res:// is writable only when run from the editor
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(r, "  "))
	if quit_after:
		get_tree().quit()
