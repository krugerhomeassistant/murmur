extends Node2D
## Murmur: input, camera, drawing, sim loop. Rules in city.gd, data in catalog.gd/events.gd, UI in hud.gd.

const TILE := 32
const STEP := 0.1
const WATER_ADD := 96  # world editor tools
const WATER_DEL := 97
const INSPECT := 98
const BULLDOZE := 99
const GRASS := Color("8fae78")
const GRASS_B := Color("8aab74")
const T = Catalog.Id
## 'All' overlay dots, left to right: power, water, fire, police, health, leisure
const ALL_DOTS := ["power", "water", "fire", "police", "health", "leisure"]

var sig := Signals.new()
var city: City
var towns: Array[City] = []
const TOWN_NAMES := ["Brookfield", "Ashby", "Northgate", "Eastmoor", "Wexford", "Stonebridge", "Hollin", "Marlow"]
var started := false
var setup: Setup
var has_save := false
const TEMPERS := [0.0, 0.2, -0.25, 0.05]  # baseline attitude of each town to the others
var dacc := 0.0
const FOUND_COST := 300.0
var tool: int = INSPECT
var speed := 1.0
var follow := true  # spectator: auto-cycle the viewed town
var follow_t := 0.0
var bench_seed := 0
var steps_done := 0  # sim steps run, for measuring the effective speed
const MAX_BATCH := 2
const SIM_BUDGET_MS := 6.0  # max sim work per frame; the game slows below the chosen speed instead of dropping frames
var acc := 0.0
var headline := "Welcome to Murmur. Lay roads, zone homes, shops and jobs beside them. The city will grow on its own as needs arise."
var sel: City.Citizen = null
var sel_cell := -1
var overlay := ""
var cam: Camera2D
var mod: CanvasModulate
var hud: Hud
var net: NetPlay
var remote := false  # multiplayer client: a mirror of the host's world, nothing simulates here
var mirror_ready := false
var net_mine := -1
var net_apply_ms := 0.0  # last snapshot apply cost
var sfx: Sfx
const SAVE := "user://murmur_save.bin"
var last_day := -1
const CAR_COLS := [Color("c0392b"), Color("2e86c1"), Color("f4f1e8"), Color("2c3e50"), Color("27ae60"), Color("d68910")]


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("5d7552"))
	has_save = load_game()
	if not has_save:
		_fresh({})
	sfx = Sfx.new()
	sfx.m = self
	add_child(sfx)
	if "--selfcheck" in OS.get_cmdline_user_args():
		print(City.selfcheck())  # slow: run from game_eval otherwise
	cam = Camera2D.new()
	cam.position = _center(city)
	city_view = city
	add_child(cam)
	fxn = WorldFx.new()
	fxn.m = self
	fxn.z_index = 5
	add_child(fxn)
	mod = CanvasModulate.new()
	add_child(mod)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.m = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	net = NetPlay.new()
	net.name = "Net"
	get_tree().root.add_child.call_deferred(net)
	net.world.connect(_net_world)
	net.state.connect(_net_state)
	net.failed.connect(_net_failed)
	open_setup()
	_net_args.call_deferred()
	_capture_args.call_deferred()
	if "--benchmark" in OS.get_cmdline_user_args():
		run_benchmark(true)


## `--server [--port N]` hosts a dedicated game, `--join host[:port]` joins one (transport only until multiplayer phase 3).
func _net_args() -> void:
	var a := OS.get_cmdline_user_args()
	var port := int(a[a.find("--port") + 1]) if "--port" in a and a.find("--port") + 1 < a.size() else NetPlay.PORT
	if "--server" in a:
		var n := clampi(int(a[a.find("--towns") + 1]) if "--towns" in a and a.find("--towns") + 1 < a.size() else 6, 2, 8)
		start_game({"name": "Server", "towns": n, "river": 3, "spectate": true, "mp": true, "guide": false})
		net.serve(towns)
		print("Murmur server: ", "listening on UDP %d with %d towns" % [port, n] if net.host(port, "Server", true) else "failed to start")
	elif "--join" in a and a.find("--join") + 1 < a.size():
		var hp: PackedStringArray = a[a.find("--join") + 1].split(":")
		net.join(hp[0], int(hp[1]) if hp.size() > 1 else NetPlay.PORT, "Player")


## `--capture DIR [--every SECONDS]`: saves the window as numbered PNGs (README screenshots and GIFs; scripts/make_media.py).
func _capture_args() -> void:
	var a := OS.get_cmdline_user_args()
	if not "--capture" in a or a.find("--capture") + 1 >= a.size():
		return
	capture(a[a.find("--capture") + 1], float(a[a.find("--every") + 1]) if "--every" in a and a.find("--every") + 1 < a.size() else 0.25)


func capture(path: String, every := 0.25) -> void:
	var dir := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(dir)
	var t := Timer.new()
	t.wait_time = maxf(every, 0.05)
	var n := [0]
	t.timeout.connect(func() -> void:
		if started:
			get_viewport().get_texture().get_image().save_png("%s/f%04d.png" % [dir, n[0]])
			n[0] += 1)
	add_child(t)
	t.start()


func run_benchmark(quit_after := false) -> void:
	var b := Benchmark.new()
	b.name = "Benchmark"
	b.m = self
	b.quit_after = quit_after
	add_child(b)


## Square spiral from the first town: every town sits next to the previous one.
static func spiral(n: int) -> Vector2i:
	var p := Vector2i.ZERO
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var k := 0
	var run := 1
	var di := 0
	while k < n:
		for rep in 2:
			for s in run:
				if k >= n:
					return p
				p += dirs[di % 4]
				k += 1
			di += 1
		run += 1
	return p


func _free_name() -> String:
	for n in TOWN_NAMES:
		if towns.all(func(t: City) -> bool: return t.town_name != n):
			return n
	return "Town %d" % (towns.size() + 1)


func _new_town(nm := "") -> City:
	var t := City.new(sig)
	if bench_seed != 0:  # reproducible worlds for the benchmark
		t.rng.seed = bench_seed + towns.size()
		t._gen_ore()
	t.town_name = nm if nm != "" else _free_name()
	t.temper = TEMPERS[towns.size() % TEMPERS.size()]
	t.gpos = spiral(towns.size())
	t.seed_start()
	for o in towns:
		o.partners.append(t)
		t.partners.append(o)
	towns.append(t)
	return t


## Build a fresh region from setup options (empty dict = defaults).
func _fresh(o: Dictionary) -> void:
	towns.clear()
	var diff: int = o.get("diff", 1)
	var land: int = o.get("land", 1)
	var lw: int = [40, 48, 64][land]
	var lh: int = [24, 32, 40][land]
	var mood: int = o.get("mood", 1)
	city = _new_town(o.get("name", "Murmur"))
	city.temper = 0.0
	var n: int = o.get("towns", 2)
	for k in range(1, n):
		var nb := _new_town()
		nb.human = false
		nb.coins = 400.0
		nb.temper = [0.2, TEMPERS[k % TEMPERS.size()], -0.25, randf_range(-0.3, 0.3)][mood]
	var rmode: int = o.get("river", 0)
	var rsd := randi()
	var rhoriz := randf() < 0.5
	for k in towns.size():
		towns[k].acc = 0.3 * k
		if rmode == 3:  # one river through the whole row/column of towns that contains the player's town
			var g := towns[k].gpos
			var same_line: bool = (g.y == towns[0].gpos.y) if rhoriz else (g.x == towns[0].gpos.x)
			if same_line:
				var idx := g.x if rhoriz else g.y
				towns[k].river_plan = {"horiz": rhoriz, "a": _edge_frac(rsd, idx), "b": _edge_frac(rsd, idx + 1)}
		towns[k].set_start(lw, lh)
		if rmode == 1 or rmode == 2 or (rmode == 3 and towns[k].river_plan.is_empty()):
			towns[k].water.fill(0)
		towns[k].ev_scale = [1.5, 1.0, 0.7][diff]
	city.coins = [600.0, 300.0, 150.0][diff]
	city.auto_mode = o.get("auto", 2)
	city.auto_policy = o.get("policy", true)
	city.auto_expand = o.get("expand", true)
	if o.get("spectate", false):  # no mayor: every town runs on the planner alone
		for t in towns:
			t.human = false
			t.coins = 400.0
			t.auto_mode = 2
			t.auto_policy = true
			t.auto_expand = true
	if o.get("spectate", false):
		headline = "Spectating: no mayor. Tab or the Towns menu switches town, F toggles auto-follow, 8x speeds it up."
		return
	headline = "Welcome to %s. %s Lay roads and zone beside them; the city grows as needs arise." % [city.town_name, ("Your neighbour %s runs itself (Region tab)." % towns[1].town_name) if n > 1 else "You are on your own."]


## Where the shared river crosses the border with index k, as a fraction of the territory's cross span (same for both towns).
static func _edge_frac(sd: int, k: int) -> float:
	return 0.3 + 0.4 * float(hash([sd, k]) % 1000) / 1000.0


func open_setup() -> void:
	started = false
	if setup != null:
		setup.queue_free()
	setup = Setup.new()
	setup.m = self
	setup.has_save = has_save or FileAccess.file_exists(SAVE)
	hud.add_child(setup)


## Multiplayer host from the lobby: a normal world where you own the first town; others join into the free towns.
func host_game(port: int, towns_n: int, pname: String) -> void:
	start_game({"name": pname, "towns": clampi(towns_n, 2, 8), "river": 3, "mood": 1, "mp": true, "guide": false, "spectate": false, "auto": 2, "policy": true, "expand": true})
	for t in towns:
		if t != city:
			t.human = false
	city.owner = 1
	net.serve(towns)
	net.host(port, pname)
	headline = "Hosting on UDP %d. Friends join with your address; each takes a free town." % port


func join_game(ip: String, port: int, pname: String) -> void:
	net.join(ip, port, pname)


func _net_world(meta: Dictionary) -> void:
	remote = true
	mirror_ready = false
	towns = NetWorld.mirror(sig, int(meta["n"]))
	net_mine = int(meta["mine"])
	city = towns[maxi(net_mine, 0)]
	_begin()
	headline = "Joined. You run %s." % city.town_name if net_mine >= 0 else "Joined as a spectator: every town is taken."


func _net_state(i: int, d: Dictionary) -> void:
	if not remote or i >= towns.size():
		return
	var t0 := Time.get_ticks_usec()
	towns[i].from_dict(d)
	net_apply_ms = (Time.get_ticks_usec() - t0) / 1000.0
	if not mirror_ready and i == maxi(net_mine, 0):
		mirror_ready = true
		cam.position = _center(towns[i])
		chunk_kick = true
		print("MP_CLIENT world=%d mine=%d town=%s pop=%d apply_ms=%.1f" % [towns.size(), net_mine, towns[i].town_name, towns[i].pop, net_apply_ms])
		if "--mp-test" in OS.get_cmdline_user_args():
			_mp_test()


## `--mp-test` (tests/mp.gd): as a client, change the tax rate through the host and wait to see it come back in a snapshot.
func _mp_test() -> void:
	cmd("tax", ["r", 0.2])
	for i in 100:
		await get_tree().create_timer(0.1).timeout
		if is_equal_approx(city.tax_r, 0.2):
			print("MP_CLIENT_OK pop=%d" % city.pop)
			get_tree().quit()
			return
	print("MP_CLIENT_FAIL tax_r=%s" % city.tax_r)
	get_tree().quit(1)


func _net_failed(reason: String) -> void:
	if remote:
		remote = false
		started = false
		towns.clear()
		open_setup()
	if setup != null and setup.note != null:
		setup.note.text = reason
	headline = reason


func start_game(o: Dictionary) -> void:
	if not o.get("mp", false):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_fresh(o)
	_begin()
	hud.guide.visible = false
	if o.get("river", 0) == 2:
		tool = WATER_ADD
		speed = 0.0
		headline = "World editor: drag to paint rivers and lakes (Build menu: Remove water erases). Press 1x when ready to play."
	if o.get("guide", false):
		hud.guide.restart()


func continue_game() -> void:
	if towns.is_empty() or not load_game():
		return
	headline = "Welcome back to %s. Day %d." % [city.town_name, city.day]
	_begin()


func _begin() -> void:
	pin_cell = -1
	chunk_kick = true
	if setup != null:
		setup.queue_free()
		setup = null
	started = true
	speed = 1.0
	last_day = -1
	tool = INSPECT
	sel = null
	sel_cell = -1
	city_view = city
	fit_prev = 0.0
	glide = Vector2.INF
	cam.position = _center(city)
	hud.reset()


func save_game() -> void:
	if remote or (net != null and net.active):
		return  # a networked world is never written over your single-player save
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f == null:
		return
	var ts: Array = []
	for t in towns:
		ts.append(t.to_dict())
	f.store_var({"v": 2, "cur": towns.find(city), "towns": ts, "sig": sig.v.duplicate()})


func load_game() -> bool:
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return false
	var d: Variant = f.get_var()
	if not (d is Dictionary) or int((d as Dictionary).get("v", 0)) != 2 or (d["towns"] as Array).is_empty():
		return false  # older saves used a smaller map
	towns.clear()
	for td in d["towns"]:
		var t := City.new(sig)
		for o in towns:
			o.partners.append(t)
			t.partners.append(o)
		t.from_dict(td)
		if towns.size() > 0 and t.gpos == Vector2i.ZERO:
			t.gpos = spiral(towns.size())
		towns.append(t)
	sig.v = d.get("sig", sig.v)
	city = towns[clampi(int(d.get("cur", 0)), 0, towns.size() - 1)]
	return true


func new_game() -> void:
	if started and city.over == "":
		save_game()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	has_save = FileAccess.file_exists(SAVE)
	open_setup()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and started and city.over == "":
		save_game()


func found_town() -> void:
	if city.coins < FOUND_COST:
		headline = "Founding a town costs $%d." % int(FOUND_COST)
	else:
		city.coins -= FOUND_COST
		var t := _new_town()
		t.coins = 300.0
		headline = "%s founded! Neighbouring towns now trade power, water and commuters." % t.town_name
		switch_town(towns.size() - 1)


## M: zoom out to see the whole region live, press again to come back.
func toggle_map() -> void:
	chunk_kick = true
	if fit_prev > 0.0:
		cam.zoom = Vector2.ONE * fit_prev
		fit_prev = 0.0
		glide = _center(city)
		return
	fit_prev = cam.zoom.x
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for t in towns:
		lo = lo.min(origin(t))
		hi = hi.max(origin(t) + Vector2(City.W, City.H) * TILE)
	cam.zoom = Vector2.ONE * clampf(minf(get_viewport_rect().size.x / (hi.x - lo.x), get_viewport_rect().size.y / (hi.y - lo.y)) * 0.9, 0.03, 2.5)
	glide = (lo + hi) * 0.5


func _center(t: City) -> Vector2:
	return origin(t) + Vector2(City.W, City.H) * TILE * 0.5


## Glide the camera to a town (the viewed town follows the camera).
func switch_town(i: int) -> void:
	glide = _center(towns[i])


func _set_city(t: City) -> void:
	pin_cell = -1
	city = t
	city_view = t
	sel = null
	sel_cell = -1
	if hud != null:
		hud.sync_town()


# ---------- input ----------

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F9 and get_node_or_null("Benchmark") == null:
		run_benchmark()
	if not started:
		return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_paint(true)
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom = (cam.zoom * 1.1).clamp(Vector2(0.03, 0.03), Vector2(2.5, 2.5))
			fit_prev = 0.0
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom = (cam.zoom / 1.1).clamp(Vector2(0.03, 0.03), Vector2(2.5, 2.5))
			fit_prev = 0.0
	elif e is InputEventMouseMotion:
		if e.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			cam.position -= e.relative / cam.zoom.x
			glide = Vector2.INF
		elif e.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_paint(false)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_R:
				if city.over != "":
					new_game()
			KEY_TAB:
				if spectating():
					follow_t = 0.0
					switch_town((towns.find(city) + 1) % towns.size())
			KEY_F:
				follow = not follow
				headline = "Auto-follow %s." % ("on" if follow else "off")
			KEY_T:
				cmd("train", [not city.train_on])
				headline = "Auto-train troops %s." % ("on" if city.train_on else "off")
			KEY_F3:
				perf_on = not perf_on
			KEY_SPACE:
				speed = 1.0 if speed == 0.0 else 0.0
			KEY_Q, KEY_ESCAPE:
				tool = INSPECT
			KEY_M:
				toggle_map()
			KEY_B:
				tool = BULLDOZE
			KEY_1:
				tool = T.ROAD
			KEY_2:
				tool = T.RES
			KEY_3:
				tool = T.COM
			KEY_4:
				tool = T.IND
			KEY_5:
				tool = T.PARK
			KEY_6:
				tool = T.FIRE


func cell() -> Vector2i:
	var m := mouse_tile()
	return Vector2i(floori(m.x), floori(m.y))


## Every player action goes through Cmd (validated; the multiplayer host runs the same call for clients).
func cmd(n: String, a: Array = []) -> Variant:
	if net != null and net.active:  # multiplayer: the host decides (and refuses commands for towns you don't own)
		if city.owner != net.my_id():
			headline = "That town is not yours."
			return null
		return net.command(towns.find(city), n, a)
	return Cmd.run(towns, city, n, a)


func say(n: String, a: Array) -> String:
	var r: Variant = cmd(n, a)
	return r if r is String else ""


func _paint(click: bool) -> void:
	_dirty_cell(cell())
	var c := cell()
	if not city.inside(c.x, c.y):
		var other := _town_at(get_global_mouse_position())
		if click and other != null and other != city:
			switch_town(towns.find(other))  # click another town: glide there
		return
	match tool:
		INSPECT:
			if click:
				_select(c)
		BULLDOZE:
			if cmd("bulldoze", [c.x, c.y]):
				sfx.cue("bulldoze")
		WATER_ADD:
			cmd("water", [c.x, c.y, 1])
		WATER_DEL:
			cmd("water", [c.x, c.y, 0])
		_:
			if not city.unlocked(tool):
				if click:
					headline = "%s unlocks at population %d." % [Catalog.DEFS[tool]["n"], Catalog.DEFS[tool]["unlock"]]
			elif cmd("place", [c.x, c.y, tool]):
				sfx.cue("place")
			elif remote:
				pass  # the host answers asynchronously; the town updates when its next snapshot arrives
			elif click and not city.owns(c.x, c.y):
				headline = "That land isn't yours yet. Annex it from the Region tab."
			elif click and tool == T.LIGHT:
				headline = "Street lamps go on a road tile, at least 2 tiles from another lamp."
			elif city.at(c.x, c.y) == T.EMPTY and click:
				headline = "Not enough coins."


var pin_cell := -1  # tile whose info card is pinned (click with the Inspect tool)


func _select(c: Vector2i) -> void:
	var m := mouse_tile()
	var best: City.Citizen = null
	var bd := 0.7
	for z in city.citizens:
		if z.path.size() > 0:
			var d := z.pos.distance_to(m)
			if d < bd:
				bd = d
				best = z
	sel = best
	sel_cell = -1 if best != null else c.y * City.W + c.x
	var ci2 := c.y * City.W + c.x
	pin_cell = -1 if best != null or pin_cell == ci2 or not city.inside(c.x, c.y) else ci2


# ---------- loop ----------

const FAR_ZOOM := 0.7  # below this, tiles are flat colour (level of detail 2)
const MID_ZOOM := 1.2  # below this, simple block buildings (level of detail 1); above, full art
const CH := 16  # chunk size in tiles
var chunk_hz := 4.0  # re-record rate of a visible chunk (animation smoothness)
const CHUNK_MS := 3.0  # recording budget per frame; under load chunks refresh slower instead of dropping fps
var chunk_ms := 3.0  # smoothed cost of recording one chunk
const WORLD_ZOOM := 0.25  # below this: live thumbnails and names instead of tiles (level of detail 3)
var layers := {}  # City -> TownLayer (chunks, thumbnail, overlay)
var city_view: City  # the town the camera is over
var glide := Vector2.INF  # camera target while gliding to a town
var vis := {}  # City -> on screen last frame
var town_rr := 0
var fxn: WorldFx
var fit_prev := 0.0  # zoom before 'fit world'
var chunk_kick := true  # set when the map changes: re-record visible chunks now
var bake_debt := 0.0
var far_mode := 0
var ci: CanvasItem = self  # target of the tile-drawing helpers (a chunk while one is being recorded)
var perf_on := false  # F3: fps / sim ms / draw ms overlay
var sim_ms := 0.0
var draw_ms := 0.0
var last_sim := 0.0  # unsmoothed per-frame costs (ms) for spike analysis
var last_chunk := 0.0
var last_draw := 0.0
var draw_acc := 0.0


## Marks the chunks around a tile for an immediate re-bake (edits, painting) without refreshing the whole view.
func _dirty_cell(c: Vector2i) -> void:
	var L: TownLayer = layers.get(city)
	if L == null or L.chunks.is_empty():
		return
	var per_row := ceili(City.W / float(CH))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cx := (c.x + dx) / CH
			var cy := (c.y + dy) / CH
			if c.x + dx >= 0 and c.y + dy >= 0 and cx < per_row and cy * per_row + cx < L.chunks.size():
				L.chunks[cy * per_row + cx].stamp = -1


func _lod() -> int:
	return 3 if cam.zoom.x < WORLD_ZOOM else (2 if cam.zoom.x < FAR_ZOOM else (1 if cam.zoom.x < MID_ZOOM else 0))


## World position of a town's top-left corner: towns sit edge to edge on the region grid.
func origin(t: City) -> Vector2:
	return Vector2(t.gpos) * Vector2(City.W, City.H) * TILE


func mouse_tile() -> Vector2:  # mouse in the viewed town's tile coordinates
	return (get_global_mouse_position() - origin(city)) / TILE


func _town_at(p: Vector2) -> City:
	var g := Vector2i((p / (Vector2(City.W, City.H) * TILE)).floor())
	for t in towns:
		if t.gpos == g:
			return t
	return null


func _chunks() -> void:
	for t in towns:
		if not layers.has(t):
			var L := TownLayer.new()
			L.m = self
			L.town = t
			L.position = origin(t)
			add_child(L)
			L.build()
			layers[t] = L
	for t in layers.keys():
		if not towns.has(t):
			(layers[t] as TownLayer).queue_free()
			layers.erase(t)
			vis.erase(t)
	var lv := _lod()
	if lv != far_mode:
		far_mode = lv
		chunk_kick = true
	var vp := get_viewport_rect().size / cam.zoom
	var view := Rect2(cam.position - vp * 0.5, vp)
	var pre := view.grow(TILE * CH * 0.5)  # half a chunk of prefetch so panning never shows an unbaked chunk
	var now := Time.get_ticks_msec()
	bake_debt = maxf(bake_debt - CHUNK_MS, 0.0)  # leaky budget: average spend stays under CHUNK_MS per frame
	var nt := towns.size()
	var thumbs := 0
	for ti in nt:
		var t: City = towns[(ti + town_rr) % nt]
		var L: TownLayer = layers[t]
		var o := origin(t)
		var on := view.intersects(Rect2(o, Vector2(City.W, City.H) * TILE))
		vis[t] = on
		L.visible = on
		L.cr.visible = on and lv < 3
		L.spr_thumb.visible = on and lv == 3
		if not on:
			continue
		L.queue_redraw()
		if lv == 3:
			if thumbs < 1 and (now - L.thumb_stamp >= 700 or chunk_kick):
				thumbs += 1
				L.thumb_stamp = now
				L.refresh_thumb()
			continue
		var n := L.chunks.size()
		for k in n:
			var l: TileLayer = L.chunks[(k + L.rr) % n]
			var seen := pre.intersects(Rect2(o + Vector2(l.x0, l.y0) * TILE, Vector2(l.x1 - l.x0 + 1, l.y1 - l.y0 + 1) * TILE))
			l.visible = seen
			if seen and (chunk_kick or l.stamp < 0 or (bake_debt < CHUNK_MS and now - l.stamp >= 1000.0 / chunk_hz)):
				l.stamp = now
				l.refresh(far_mode)
				bake_debt += chunk_ms
		L.rr = (L.rr + 3) % n
	town_rr += 1
	chunk_kick = false


func spectating() -> bool:
	return towns.all(func(t: City) -> bool: return not t.human)


func _process(delta: float) -> void:
	delta = minf(delta, 0.25)
	if started and follow and towns.size() > 1 and spectating() and _lod() < 3:  # not while looking at the whole world
		follow_t += delta
		if follow_t > 30.0:
			follow_t = 0.0
			switch_town((towns.find(city) + 1) % towns.size())
	var p0 := Time.get_ticks_usec()
	var v := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	cam.position += v * 700.0 * delta / cam.zoom.x
	if v != Vector2.ZERO:
		glide = Vector2.INF
	if glide != Vector2.INF:
		cam.position = cam.position.lerp(glide, 1.0 - exp(-6.0 * delta))
		if cam.position.distance_to(glide) < 2.0:
			glide = Vector2.INF
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for t in towns:
		lo = lo.min(origin(t))
		hi = hi.max(origin(t) + Vector2(City.W, City.H) * TILE)
	cam.position = cam.position.clamp(lo, hi)
	var under := _town_at(cam.position)
	if under != null and under != city and started:
		_set_city(under)
	if started and not remote:
		acc = minf(acc + delta * speed, STEP * 20.0)  # never owe more than 20 steps: slow down instead of freezing
		while acc >= STEP:
			if Time.get_ticks_usec() - p0 > SIM_BUDGET_MS * 1000.0:  # out of frame budget: run slower than asked rather than stutter
				acc = minf(acc, STEP)
				break
			acc -= STEP
			steps_done += 1
			sig.tick(STEP)
			dacc += STEP
			if dacc >= 1.0:
				dacc -= 1.0
				Diplo.second(towns, city.rng)
				net.broadcast()
			var batched := 0
			for t in towns:
				if t == city:
					t.lod = 1
					t.tick(STEP)
				else:  # off-screen towns tick in 0.5s batches and refresh slow analyses less often
					t.lod = 3
					t.pend += STEP
					if t.pend >= (0.25 if vis.get(t, false) else 0.5) and batched < MAX_BATCH:  # towns in view tick faster so they look alive  # at most MAX_BATCH towns per step so batches never pile into one 30 ms frame
						t.tick(t.pend)
						t.pend = 0.0
						batched += 1
					t.msg = ""
			if city.msg != "":
				headline = city.msg
				city.msg = ""
		for t in towns:
			if t == city:
				for snd in t.sounds:
					sfx.cue(snd)
			t.sounds.clear()
		if city.day != last_day:
			last_day = city.day
			if city.over == "":
				save_game()
	last_sim = (Time.get_ticks_usec() - p0) / 1000.0
	sim_ms = lerpf(sim_ms, last_sim, 0.1)
	var c0 := Time.get_ticks_usec()
	var b := 0.78 + 0.22 * cos((city.clock - 13.0) / 24.0 * TAU)
	mod.color = Color(b, b, minf(1.0, b + 0.1))
	city.flush()
	fxn.queue_redraw()
	last_draw = draw_acc  # overlay cost of last frame, summed over the towns drawn
	draw_acc = 0.0
	draw_ms = lerpf(draw_ms, last_draw, 0.1)
	_chunks()
	last_chunk = (Time.get_ticks_usec() - c0) / 1000.0
	queue_redraw()


# ---------- drawing ----------

## Label each side of the territory with the town that lies there; gold bars mark border roads.
func _draw_borders(tr: Rect2i) -> void:
	var font := ThemeDB.fallback_font
	var mids := [Vector2(tr.position.x + tr.size.x * 0.5, tr.position.y), Vector2(tr.end.x, tr.position.y + tr.size.y * 0.5), Vector2(tr.position.x + tr.size.x * 0.5, tr.end.y), Vector2(tr.position.x, tr.position.y + tr.size.y * 0.5)]
	var arrows := ["^", ">", "v", "<"]
	for p in city.partners:
		var k := Diplo.side(city, p)
		if k < 0:
			continue
		var war := Diplo.treaty(city, p) == "war"
		var linked := Diplo.linked(city, p)
		var col := Color("d9382a") if war else (Color("9fd3a0") if linked else Color("f2cf4a"))
		var txt := "%s %s  %s" % [arrows[k], p.town_name, "WAR" if war else ("linked" if linked else "needs a road to this border")]
		var pos: Vector2 = mids[k] * TILE
		var off: Vector2 = [Vector2(-170, -14), Vector2(10, 5), Vector2(-170, 28), Vector2(-350, 5)][k]
		ci.draw_string(font, pos + off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		if linked or war:
			ci.draw_rect(Rect2(pos - Vector2(4, 4) * 2, Vector2(16, 16)), col, false, 2.0)
	for k in 4:
		if int(city.gate[k]) > 0:
			ci.draw_circle(mids[k] * TILE, 6.0, Color("f2cf4a"))

func _draw() -> void:  # world level: weather and the links between towns; every town draws itself in its TownLayer
	ci = self
	var vp := get_viewport_rect().size / cam.zoom
	var view := Rect2(cam.position - vp * 0.5, vp)
	if _lod() < 3:
		match sig.weather():
			"rain":
				ci.draw_rect(view, Color(0.2, 0.25, 0.35, 0.22))
				_rain(view, 120)
			"storm":
				ci.draw_rect(view, Color(0.1, 0.12, 0.2, 0.4))
				_rain(view, 220)
			"heatwave":
				ci.draw_rect(view, Color(0.9, 0.55, 0.15, 0.14))
			"snow":
				ci.draw_rect(view, Color(0.85, 0.9, 1.0, 0.16))
				_snow(view)
			"fog":
				ci.draw_rect(view, Color(0.8, 0.82, 0.85, 0.3))
			"cold_snap":
				ci.draw_rect(view, Color(0.6, 0.75, 1.0, 0.12))


## Every unit of every army at the front between two towns at war, with tracers and explosions.
func draw_fx(node: CanvasItem) -> void:
	var now := Time.get_ticks_msec()
	var sz := clampf(1.1 / cam.zoom.x, 1.6, 10.0)  # keep units readable when zoomed out
	for ai in towns.size():
		var a: City = towns[ai]
		for b in a.partners:
			if towns.find(b) < ai or Diplo.treaty(a, b) != "war" or not (vis.get(a, false) or vis.get(b, false)):
				continue
			var l := Military.line(a, b)
			var u := (l[1] - l[0]).normalized()
			var nv := Vector2(-u.y, u.x)
			for side in 2:
				var c: City = a if side == 0 else b
				var foe: City = b if side == 0 else a
				var col := Color("5b8de0") if side == 0 else Color("d9382a")
				var dir := 1.0 if side == 0 else -1.0
				var base: Vector2 = l[0] if side == 0 else l[1]
				for un in c.army:
					if un["tgt"] != foe.town_name:
						continue
					var pos := base + u * dir * float(un["s"]) + nv * float(un["l"]) * 70.0 * sz
					var ang := u.angle() + (0.0 if side == 0 else PI)
					var fresh: bool = now - int(un.get("ft", -9999)) < 700
					match String(un["k"]):
						"inf", "gren", "snip", "medic":
							var k := String(un["k"])
							node.draw_circle(pos, (3.8 if k == "gren" else 3.2) * sz, Color.WHITE if k == "medic" else col)
							if k == "medic":
								node.draw_rect(Rect2(pos + Vector2(-1, -2.4) * sz, Vector2(2, 4.8) * sz), Color("d9382a"))
								node.draw_rect(Rect2(pos + Vector2(-2.4, -1) * sz, Vector2(4.8, 2) * sz), Color("d9382a"))
							else:
								node.draw_line(pos, pos + Vector2.from_angle(ang) * (14.0 if k == "snip" else 8.0) * sz, Color.WHITE, (0.8 if k == "snip" else 1.2) * sz)
								if k == "gren":
									node.draw_rect(Rect2(pos + Vector2(-1.5, -6) * sz, Vector2(3, 3) * sz), Color("e0a030"))
						"ltank", "tank", "htank", "art", "aa":
							var k := String(un["k"])
							var f := 0.75 if k == "ltank" else (1.25 if k == "htank" else 1.0)
							node.draw_set_transform(pos, ang)
							node.draw_rect(Rect2(-8 * sz * f, -5 * sz * f, 16 * sz * f, 10 * sz * f), col.darkened(0.35))
							node.draw_rect(Rect2(-4 * sz * f, -3 * sz * f, 8 * sz * f, 6 * sz * f), col)
							if k == "aa":
								node.draw_line(Vector2(0, -2) * sz, Vector2(7, -9) * sz, Color("2a2a2a"), 1.6 * sz)
								node.draw_line(Vector2(0, 2) * sz, Vector2(7, 9) * sz, Color("2a2a2a"), 1.6 * sz)
							elif k == "art":
								node.draw_line(Vector2.ZERO, Vector2(22, 0) * sz, Color("2a2a2a"), 2.4 * sz)
							else:
								node.draw_rect(Rect2(2 * sz * f, -1 * sz, 12 * sz * f, 2 * sz), Color("2a2a2a"))
								if k == "htank":
									node.draw_rect(Rect2(2 * sz * f, -3.5 * sz, 12 * sz * f, 1.6 * sz), Color("2a2a2a"))
							node.draw_set_transform(Vector2.ZERO)
						"jet", "fighter", "bomber", "heli":
							var k := String(un["k"])
							node.draw_circle(pos + Vector2(0, 16 * sz), 5.0 * sz, Color(0, 0, 0, 0.25))
							if k == "heli":
								var rot := now / 60.0
								node.draw_circle(pos, 4.0 * sz, col.lightened(0.2))
								node.draw_line(pos + Vector2.from_angle(rot) * 10.0 * sz, pos - Vector2.from_angle(rot) * 10.0 * sz, Color(1, 1, 1, 0.7), 1.2 * sz)
							else:
								var f := 1.4 if k == "bomber" else (0.8 if k == "fighter" else 1.0)
								node.draw_set_transform(pos, ang)
								node.draw_colored_polygon(PackedVector2Array([Vector2(12, 0) * sz * f, Vector2(-8, -8 if k != "fighter" else -5) * sz * f, Vector2(-4, 0) * sz * f, Vector2(-8, 8 if k != "fighter" else 5) * sz * f]), col.lightened(0.2))
								node.draw_set_transform(Vector2.ZERO)
						"patrol", "destroyer", "transport":
							var k := String(un["k"])
							var f := 0.8 if k == "patrol" else (1.4 if k == "destroyer" else 1.2)
							node.draw_circle(pos, 13.0 * sz * f, Color(0.25, 0.5, 0.8, 0.35))  # water under the hull
							node.draw_set_transform(pos, ang)
							node.draw_colored_polygon(PackedVector2Array([Vector2(14, 0) * sz * f, Vector2(8, -5) * sz * f, Vector2(-12, -5) * sz * f, Vector2(-12, 5) * sz * f, Vector2(8, 5) * sz * f]), col.darkened(0.3))
							if k == "transport":
								node.draw_rect(Rect2(-8 * sz * f, -3 * sz * f, 12 * sz * f, 6 * sz * f), Color("c9b98a"))
							else:
								node.draw_rect(Rect2(-2 * sz * f, -2.5 * sz * f, 6 * sz * f, 5 * sz * f), col)
								node.draw_line(Vector2(2, 0) * sz * f, Vector2(13, 0) * sz * f, Color("2a2a2a"), 1.8 * sz)
								if k == "destroyer":
									node.draw_line(Vector2(-7, 0) * sz * f, Vector2(-1, 0) * sz * f, Color("2a2a2a"), 1.8 * sz)
							node.draw_set_transform(Vector2.ZERO)
					var mx: float = Military.max_hp(un)
					for rk in Military.rank(un):  # veteran chevrons
						node.draw_rect(Rect2(pos + Vector2(-8 + rk * 4, 8) * sz, Vector2(3, 1.6) * sz), Color("f2cf4a"))
					if float(un["hp"]) < mx * 0.99:
						node.draw_rect(Rect2(pos + Vector2(-8, -10) * sz, Vector2(16 * sz, 2.0 * sz)), Color(0, 0, 0, 0.6))
						node.draw_rect(Rect2(pos + Vector2(-8, -10) * sz, Vector2(16 * sz * float(un["hp"]) / mx, 2.0 * sz)), Color("6fd06f") if float(un["hp"]) / mx > 0.4 else Color("e0a030"))
					if fresh:  # tracer to the unit it fired at
						var tgp := float(un["fg"])
						var tpos: Vector2 = l[0] + u * tgp + nv * float(un["fl"]) * 70.0 * sz
						node.draw_line(pos, tpos, Color(1.0, 0.45, 0.2, 0.9) if un["k"] == "art" else (Color(1, 1, 1, 0.9) if un["k"] == "snip" else Color(1.0, 0.9, 0.4, 0.9)), (3.0 if un["k"] == "art" else 1.5) * sz)
						node.draw_circle(pos + Vector2.from_angle(ang) * 10.0 * sz, 3.0 * sz, Color(1.0, 0.8, 0.3, 0.9))
			for e in Military.booms:
				if e["a"] != a.town_name or e["b"] != b.town_name:
					continue
				var ph := clampf((now - int(e["t"])) / 1500.0, 0.0, 1.0)
				var bp: Vector2 = l[0] + u * float(e["g"]) + nv * float(e["l"]) * 70.0 * sz
				node.draw_circle(bp, (8.0 + 24.0 * ph) * sz, Color(1.0, 0.55 - 0.3 * ph, 0.1, (1.0 - ph) * 0.85))
				node.draw_circle(bp + Vector2(0, -18.0 * ph * sz), (5.0 + 14.0 * ph) * sz, Color(0.25, 0.25, 0.25, (1.0 - ph) * 0.55))
	_draw_blasts(node)


## Buildings hit by raids and bombs: a fireball, then a column of smoke for a few seconds.
func _draw_blasts(node: CanvasItem) -> void:
	var now := Time.get_ticks_msec()
	var sz := clampf(1.1 / cam.zoom.x, 1.0, 8.0)
	for e in Military.blasts:
		var t: City = null
		for c in towns:
			if c.town_name == e["t"]:
				t = c
		if t == null or not vis.get(t, false):
			continue
		var ph := clampf((now - int(e["ts"])) / 9000.0, 0.0, 1.0)
		var p: Vector2 = origin(t) + e["p"]
		if ph < 0.15:
			node.draw_circle(p, (10.0 + 60.0 * ph) * sz, Color(1.0, 0.6 - ph, 0.1, 0.9 - ph * 4.0))
		for k in 4:
			node.draw_circle(p + Vector2(sin(k * 2.1 + ph * 3.0) * 6.0, -16.0 * (k + 1) * ph * sz), (6.0 + 5.0 * k) * sz * (0.5 + ph), Color(0.2, 0.2, 0.2, (1.0 - ph) * 0.5))


## Line from this town to its east and south neighbours: green = a road reaches the shared border, grey = not yet, red = war.
func _links(t: City) -> void:
	var font := ThemeDB.fallback_font
	var z := cam.zoom.x
	for d in t.partners:
		var k: int = Diplo.side(t, d)
		if k != 1 and k != 2:
			continue  # each pair once, from its west/north member
		var ok := Diplo.linked(t, d)
		var war := Diplo.treaty(t, d) == "war"
		var lc := Color("d9382a") if war else (Color("9fd3a0") if ok else Color("8a8a7a"))
		var c0 := Vector2(t.terr.get_center())
		var c1 := Vector2(d.terr.get_center())
		var p0 := (Vector2(t.terr.end.x, c0.y) if k == 1 else Vector2(c0.x, t.terr.end.y)) * TILE  # edge to edge: the line crosses the gap, not the towns
		var p1 := origin(d) - origin(t) + (Vector2(d.terr.position.x, c1.y) if k == 1 else Vector2(c1.x, d.terr.position.y)) * TILE
		ci.draw_line(p0, p1, lc, (4.0 if ok else 2.0) / z)
		ci.draw_string(font, (p0 + p1) * 0.5 + Vector2(-30, -6) / z, "WAR" if war else ("road" if ok else "no road"), HORIZONTAL_ALIGNMENT_CENTER, 60.0 / z, int(12.0 / z), lc)


func _town_col(c: City) -> Color:
	if c == city:
		return Color("f2cf4a")
	match Diplo.treaty(city, c):
		"war":
			return Color("d9382a")
		"alliance":
			return Color("6fd0e8")
		"pact":
			return Color("9fd3a0")
		"embargo":
			return Color("e08a3a")
	var r := Diplo.avg(city, c)
	return Color("9fd3a0") if r > 0.2 else (Color("e07a5f") if r < -0.2 else Color("9aa88f"))


## Everything live in one town that is not baked into its chunks: overlays, fire, lights, traffic, people, rim, cursor.
func draw_overlay(node: CanvasItem, t: City) -> void:
	var d0 := Time.get_ticks_usec()
	var tcol := _town_col(t)  # relative to the viewed town, so before `city` is swapped
	var keep := city
	city = t
	ci = node
	var o := origin(t)
	var lod := _lod()
	var vp := get_viewport_rect().size / cam.zoom
	var tl := cam.position - vp * 0.5 - o
	var x0 := maxi(0, floori(tl.x / TILE))
	var y0 := maxi(0, floori(tl.y / TILE))
	var x1 := mini(City.W - 1, floori((tl.x + vp.x) / TILE))
	var y1 := mini(City.H - 1, floori((tl.y + vp.y) / TILE))
	var night := city.clock >= 19.0 or city.clock < 6.0
	var tr := city.terr
	var dim := Color(0.05, 0.08, 0.04, 0.42)
	ci.draw_rect(Rect2(0, 0, City.W * TILE, tr.position.y * TILE), dim)
	ci.draw_rect(Rect2(0, tr.end.y * TILE, City.W * TILE, (City.H - tr.end.y) * TILE), dim)
	ci.draw_rect(Rect2(0, tr.position.y * TILE, tr.position.x * TILE, tr.size.y * TILE), dim)
	ci.draw_rect(Rect2(tr.end.x * TILE, tr.position.y * TILE, (City.W - tr.end.x) * TILE, tr.size.y * TILE), dim)
	var rim := Rect2(Vector2(tr.position) * TILE, Vector2(tr.size) * TILE)
	ci.draw_rect(rim, tcol if lod == 3 else Color(1.0, 0.82, 0.4, 0.5), false, 3.0 / cam.zoom.x if lod == 3 else 3.0)
	if lod == 3:  # world view: just the name and the rim
		var fs := int(22.0 / cam.zoom.x)
		var lab := "%s  pop %d" % [t.town_name, t.pop]
		var font0 := ThemeDB.fallback_font
		var lp := Vector2(rim.get_center().x - font0.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, rim.position.y - fs * 0.4)
		ci.draw_string(font0, lp + Vector2(2, 2) / cam.zoom.x, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
		ci.draw_string(font0, lp, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)
		_links(t)
		city = keep
		ci = self
		draw_acc += (Time.get_ticks_usec() - d0) / 1000.0
		return
	if lod == 2:
		_links(t)
	if t == city_view:
		_draw_borders(tr)
	_boats()
	if overlay != "":
		_overlay(x0, y0, x1, y1)
	var tt := Time.get_ticks_msec() * 0.001
	for i in city.flames:
		if city.burn[i] > 0.0:
			var fr := Rect2((i % City.W) * TILE, floori(i / float(City.W)) * TILE, TILE, TILE).grow(-3)
			ci.draw_rect(fr, Color(1.0, 0.45, 0.1, 0.6 + 0.25 * sin(tt * 14.0 + i)))
			ci.draw_circle(fr.get_center() + Vector2(sin(tt * 9.0 + i) * 3.0, -6), 4.0, Color(1, 0.85, 0.2, 0.8))

	for k in city.offline:
		var oc := City.cell(k)
		ci.draw_rect(Rect2(oc.x * TILE, oc.y * TILE, TILE, TILE), Color(0, 0, 0, 0.5))
		ci.draw_string(ThemeDB.fallback_font, Vector2(oc.x * TILE, oc.y * TILE + 20), "OFF", HORIZONTAL_ALIGNMENT_CENTER, TILE, 11, Color("f2cf4a"))
	if lod < 2:  # cars, people and lamps are sub-pixel when zoomed out
		if night:
			for li in city.bt.get(T.LIGHT, []):
				ci.draw_circle(City.center(li) * TILE, TILE * 1.6, Color(1.0, 0.9, 0.5, 0.12))
		for li in city.bt.get(T.LIGHT, []):
			var lc := City.center(li) * TILE + Vector2(9, -9)
			ci.draw_line(lc + Vector2(0, 8), lc, Color("555555"), 2.0)
			ci.draw_circle(lc, 3.0, Color("ffe9a0") if night else Color("d8c88a"))
		for b in city.buses:
			var bp: Vector2 = b["pos"]
			var bd: Vector2 = b["dir"]
			ci.draw_set_transform(bp * TILE, bd.angle())
			ci.draw_rect(Rect2(-9, -4, 18, 8), Color("f2c14e"))
			for k in 3:
				ci.draw_rect(Rect2(-6 + k * 5, -3, 3, 2), Color("3a4a5a"))
			if night:
				ci.draw_circle(Vector2(9, -2), 1.5, Color("fff3b0"))
				ci.draw_circle(Vector2(9, 2), 1.5, Color("fff3b0"))
			ci.draw_set_transform(Vector2.ZERO, 0.0)
		for c in city.citizens:
			if c.car and c.path.size() > 0 and c != sel:
				var dv := c.path[mini(c.pi, c.path.size() - 1)] - c.pos
				ci.draw_set_transform(c.pos * TILE, dv.angle() if dv.length() > 0.01 else 0.0)
				ci.draw_rect(Rect2(-5, -3, 10, 6), CAR_COLS[c.id % CAR_COLS.size()])
				ci.draw_rect(Rect2(0, -2, 3, 4), Color(0.6, 0.75, 0.85))
				if night:
					ci.draw_circle(Vector2(6, -2), 1.2, Color("fff3b0"))
					ci.draw_circle(Vector2(6, 2), 1.2, Color("fff3b0"))
				ci.draw_set_transform(Vector2.ZERO, 0.0)
				continue
			if c.path.size() == 0 and c != sel:
				continue
			var p := c.pos * TILE
			ci.draw_circle(p + Vector2(0, 1.5), 4.2, Color(0, 0, 0, 0.3))
			var col := Color("f3e7cf") if c.mood > 0.6 else (Color("e0a458") if c.mood > 0.35 else Color("c0392b"))
			if c.sick > 0.0:
				col = Color("8fc46a")
			ci.draw_circle(p, 3.4, col)
			if c.protesting and city.protest:
				ci.draw_line(p, p + Vector2(0, -9), Color.WHITE, 1.0)
				ci.draw_rect(Rect2(p + Vector2(-4, -14), Vector2(8, 5)), Color("f3e7cf"))
			if c == sel:
				ci.draw_arc(p, 8.0, 0.0, TAU, 20, Color.WHITE, 1.5)
		var font := ThemeDB.fallback_font
		for c in city.citizens:
			if c.bubble_t <= 0.0:
				continue
			var p := c.pos * TILE + Vector2(0, -14)
			var sz := font.get_string_size(c.bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
			ci.draw_rect(Rect2(p + Vector2(-sz.x * 0.5 - 4, -sz.y), sz + Vector2(8, 4)), Color(0.08, 0.1, 0.09, 0.85))
			ci.draw_string(font, p + Vector2(-sz.x * 0.5, -2), c.bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f3e7cf"))

	if not city.twister.is_empty():
		var tp: Vector2 = city.twister["pos"] * TILE
		for k in 6:
			var a := tt * 9.0 + k * 1.05
			ci.draw_arc(tp + Vector2(sin(tt * 3.0 + k) * 3.0, -k * 7.0), 8.0 + k * 4.0, a, a + 4.0, 12, Color(0.35, 0.35, 0.38, 0.75), 3.0)
	if city.protest:
		ci.draw_rect(rim, Color("b03a2e"), false, 4.0)

	if t == city_view:
		var hc := cell()
		if city.inside(hc.x, hc.y):
			ci.draw_rect(Rect2(hc.x * TILE, hc.y * TILE, TILE, TILE), Color(1, 1, 1, 0.9), false, 2.0)
			if tool < INSPECT and Catalog.DEFS.has(tool) and Catalog.DEFS[tool].has("r"):
				ci.draw_circle(City.center(hc.y * City.W + hc.x) * TILE, float(Catalog.DEFS[tool]["r"]) * TILE * 0.9, Color(1, 1, 1, 0.12))
		if sel_cell >= 0 and sel == null:
			var sc := City.cell(sel_cell)
			ci.draw_rect(Rect2(sc.x * TILE, sc.y * TILE, TILE, TILE), Color("ffd166"), false, 2.0)
	city = keep
	ci = self
	draw_acc += (Time.get_ticks_usec() - d0) / 1000.0

## Static tile layer for one chunk (grass, ground, water, roads, buildings, wires). Re-recorded by _chunks(), not every frame.
func draw_chunk(c_item: CanvasItem, t_: City, x0: int, y0: int, x1: int, y1: int) -> void:
	var c0 := Time.get_ticks_usec()
	var keep := city
	city = t_  # the helpers below read `city`: point it at the town being drawn
	ci = c_item
	var grass: Color = Civics.SEASONS[city.season]["grass"]
	var grass_b := grass.darkened(0.05)
	var lod := _lod()
	var far := lod >= 1
	ci.draw_rect(Rect2(x0 * TILE, y0 * TILE, (x1 - x0 + 1) * TILE, (y1 - y0 + 1) * TILE), grass)
	var night := city.clock >= 19.0 or city.clock < 6.0
	var lane := Color(0.92, 0.85, 0.5, 0.55)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i := y * City.W + x
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			if (x * 7 + y * 13) % 11 == 0:
				ci.draw_rect(r, grass_b)
			var t: int = city.grid[i]
			var wet: bool = city.water[i] == 1
			if wet:
				var wn := 0
				if y > 0 and city.water[i - City.W] == 0:
					wn |= 1
				if x + 1 < City.W and city.water[i + 1] == 0:
					wn |= 2
				if y + 1 < City.H and city.water[i + City.W] == 0:
					wn |= 4
				if x > 0 and city.water[i - 1] == 0:
					wn |= 8
				if far:
					ci.draw_rect(r, Color("3f7fb8") if not night else Color("27507a"))
				else:
					Art.water(ci, x, y, wn, night, city.river_health)
			if t == T.EMPTY:
				if not wet and not far:
					Art.ground(ci, x, y, city.owns(x, y), city.season)
				if city.ore[i] > 0 and not wet:
					Art.ore(ci, x, y, int(city.ore[i]), far)
				continue
			var d: Dictionary = Catalog.DEFS[t]
			if far:  # zoomed out: one flat rect per tile, detail is sub-pixel anyway
				var fc: Color = d["col"]
				var kind := String(d["kind"])
				if kind == "zone":
					fc = fc.darkened(0.12 * city.lvl[i]) if city.lvl[i] > 0 else fc.lerp(grass, 0.6)
				ci.draw_rect(r.grow(-1.0) if kind != "road" else r, fc)
				if lod == 1 and kind != "road":  # block roof so buildings still read as buildings
					ci.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(26, 9)), fc.darkened(0.35))
					if kind != "zone" or city.lvl[i] > 0:
						ci.draw_rect(Rect2(r.position + Vector2(8, 17), Vector2(5, 6)), Color(1, 0.92, 0.6, 0.8 if night else 0.45))
				continue
			match String(d["kind"]):
				"road":
					ci.draw_rect(r, d["col"])
					var c := r.get_center()
					ci.draw_circle(c, 1.5, lane)
					if x + 1 < City.W and city.is_road(city.grid[i + 1]):
						ci.draw_line(c, c + Vector2(TILE, 0), lane, 1.0 if t == T.ROAD else 2.5)
					if y + 1 < City.H and city.is_road(city.grid[i + City.W]):
						ci.draw_line(c, c + Vector2(0, TILE), lane, 1.0 if t == T.ROAD else 2.5)
					if wet:
						Art.bridge(ci, r, x > 0 and city.is_road(city.grid[i - 1]) or x + 1 < City.W and city.is_road(city.grid[i + 1]))
				"zone":
					if city.lvl[i] == 0:
						_zone(r, t, i)
					else:
						_building(r, d, city.lvl[i], city.connected[i] == 1, night)
				_:
					_service(r, d, city.connected[i] == 1, night, t)
	if lod == 0:
		_nets(x0, y0, x1, y1)
	ci = self
	city = keep
	chunk_ms = lerpf(chunk_ms, (Time.get_ticks_usec() - c0) / 1000.0, 0.1)


func _overlay(x0: int, y0: int, x1: int, y1: int) -> void:
	var font := ThemeDB.fallback_font
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i := y * City.W + x
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			if overlay == "pollution":
				var p := clampf(city.poll_at(Vector2i(x, y)) * 2.0, 0.0, 1.0)
				if p > 0.02:
					ci.draw_rect(r, Color(0.45, 0.3, 0.1, p * 0.6))
			elif overlay == "land":
				var lv: float = city.land_val[i]
				ci.draw_rect(r, Color(1.0 - lv, lv, 0.2, 0.5))
			elif overlay == "traffic":
				if city.is_road(city.grid[i]):
					var tv := clampf(city.traffic[i] / (8.0 if city.grid[i] == T.AVENUE else 3.0), 0.0, 1.5)
					ci.draw_rect(r, Color(tv, 1.0 - minf(tv, 1.0), 0.1, 0.55))
			elif overlay == "crime":
				if city.crime_val[i] > 0.0:
					ci.draw_rect(r, Color(0.85, 0.1, 0.1, city.crime_val[i] * 0.7))
			elif overlay == "all":
				var p := clampf(city.poll_at(Vector2i(x, y)) * 2.0, 0.0, 1.0)
				if p > 0.05:
					ci.draw_rect(r, Color(0.45, 0.3, 0.1, p * 0.4))
				if city.crime_val[i] > 0.0:
					ci.draw_rect(r, Color(0.85, 0.1, 0.1, city.crime_val[i] * 0.4))
				var t: int = city.grid[i]
				if t != T.EMPTY and not city.is_road(t):
					var k := 0
					for mk in ALL_DOTS:
						var ok := city.raw_cov(Vector2i(x, y), mk) > 0.3
						ci.draw_rect(Rect2(x * TILE + 2 + (k % 3) * 9, y * TILE + 2 + (k / 3) * 5, 7, 4), Color("5fbf6a") if ok else Color("d9534f"))
						k += 1
					if city.burn[i] > 0.0:
						ci.draw_string(font, r.position + Vector2(0, 30), "FIRE", HORIZONTAL_ALIGNMENT_CENTER, TILE, 9, Color.WHITE)
			else:
				var c := clampf(city.raw_cov(Vector2i(x, y), overlay), 0.0, 1.0)
				ci.draw_rect(r, Color(0.2, 0.8, 0.4, c * 0.45) if c > 0.0 else Color(0.8, 0.2, 0.2, 0.18))


func _building(r: Rect2, d: Dictionary, lv: int, ok: bool, night: bool) -> void:
	if Art.building(ci, r, String(d.get("shape", "")), d["col"], lv, ok, night, int(r.position.x / 32.0) * 7 + int(r.position.y / 32.0) * 13):
		if not ok:
			ci.draw_string(ThemeDB.fallback_font, r.position + Vector2(12, 20), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.3, 0.2))
		return
	var body: Color = d["col"]
	if not ok:
		body = body.darkened(0.35)
	var h := 3.0 * lv
	ci.draw_rect(r.grow(-1), Color(body, 0.25))
	var base := Rect2(r.position + Vector2(4, 7), Vector2(TILE - 8, TILE - 10))
	ci.draw_rect(base, body.darkened(0.3))
	var up := Rect2(base.position - Vector2(0, h), base.size)
	if d["shape"] == "tower":
		up = Rect2(base.position + Vector2(3, -h * 1.8), base.size - Vector2(6, 0) + Vector2(0, h * 1.8))
	ci.draw_rect(up, body)
	ci.draw_rect(Rect2(up.position, Vector2(up.size.x, 5)), body.lightened(0.25))
	match String(d["shape"]):
		"house":
			var y := up.position.y
			ci.draw_colored_polygon(PackedVector2Array([Vector2(up.position.x - 1, y), Vector2(up.end.x + 1, y), Vector2(r.position.x + TILE * 0.5, y - 7)]), Color("9a5a4a") if ok else Color("5a3a30"))
		"terrace":
			for k in 3:
				var gx := up.position.x + k * (up.size.x / 3.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(gx, up.position.y), Vector2(gx + up.size.x / 3.0, up.position.y), Vector2(gx + up.size.x / 6.0, up.position.y - 6)]), Color("9a5a4a") if ok else Color("5a3a30"))
		"condo":
			ci.draw_rect(Rect2(up.position.x + 2, up.position.y - 4, up.size.x - 4, 6), Color("7fb2d4"))
			ci.draw_line(Vector2(up.position.x + 4, up.position.y + 6), Vector2(up.end.x - 4, up.end.y - 2), Color(1, 1, 1, 0.35), 1.0)
		"shop":
			ci.draw_rect(Rect2(up.position.x, up.end.y - 6, up.size.x, 4), Color("e8e2d0") if ok else Color("8a8678"))
		"factory":
			ci.draw_rect(Rect2(up.end.x - 7, up.position.y - 8, 5, 9), body.darkened(0.2))
			ci.draw_rect(Rect2(up.position.x + 3, up.position.y - 4, 5, 5), body.darkened(0.2))
		"office":
			ci.draw_rect(Rect2(up.position.x + 4, up.position.y - 5, up.size.x - 8, 5), body.lightened(0.15))
		"farm":
			ci.draw_rect(Rect2(r.position + Vector2(3, 18), Vector2(TILE - 6, 10)), Color("a89850"))
			for k in 4:
				ci.draw_line(r.position + Vector2(5 + k * 7, 19), r.position + Vector2(5 + k * 7, 27), Color("7f7a3a"), 1.0)
	var wc := Color("ffd98a") if (night and ok) else body.darkened(0.45)
	for k in lv:
		ci.draw_rect(Rect2(up.position.x + 4 + k * 7, up.position.y + 8, 3, 4), wc)
	if not ok:
		ci.draw_string(ThemeDB.fallback_font, r.position + Vector2(12, 24), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b03a2e"))


func _rain(area: Rect2, n: int) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in n:
		var x := area.position.x + fmod(i * 97.0 + 13.0, area.size.x)
		var y := area.position.y + fmod(i * 53.0 + t * 380.0, area.size.y)
		ci.draw_line(Vector2(x, y), Vector2(x - 3, y + 10), Color(0.8, 0.85, 1.0, 0.5), 1.0)


func _snow(area: Rect2) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in 100:
		var x := area.position.x + fmod(i * 97.0 + 13.0 + sin(t + i) * 12.0, area.size.x)
		var y := area.position.y + fmod(i * 53.0 + t * 60.0, area.size.y)
		ci.draw_circle(Vector2(x, y), 1.6, Color(1, 1, 1, 0.8))


func _zone(r: Rect2, t: int, i: int) -> void:
	var d: Dictionary = Catalog.DEFS[t]
	var zc: Color = d["col"]
	var ok := city.connected[i] == 1
	Art.zone(ci, r, String(d.get("shape", "")), zc, ok)
	if not ok:
		ci.draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), Color("b03a2e"), 2.0)
		ci.draw_line(r.position + Vector2(TILE - 4, 4), r.position + Vector2(4, TILE - 4), Color("b03a2e"), 2.0)
	elif city.build[i] > 0.0:
		ci.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(TILE - 6, TILE - 6)), Color(1, 1, 1, 0.3))
		ci.draw_rect(Rect2(r.position + Vector2(3, TILE - 8), Vector2((TILE - 6) * city.build[i], 4)), Color("ffd166"))
		ci.draw_line(r.position + Vector2(8, 5), r.position + Vector2(8, 20), Color("5a4a3a"), 2.0)
		ci.draw_line(r.position + Vector2(8, 5), r.position + Vector2(24, 5), Color("5a4a3a"), 2.0)


func _service(r: Rect2, d: Dictionary, ok: bool, night: bool, id := -1) -> void:
	if id >= 0 and Art.service(ci, r, id, ok, night):
		if not ok:
			ci.draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), Color("b03a2e"), 2.0)
		return
	var col: Color = d["col"]
	var sh: String = d.get("shape", "")
	var c := r.get_center()
	if sh == "park":
		ci.draw_rect(r.grow(-2), col)
		ci.draw_circle(r.position + Vector2(10, 11), 5.0, Color("3f6b3a"))
		ci.draw_circle(r.position + Vector2(21, 20), 6.0, Color("4a7a43"))
		return
	ci.draw_rect(r.grow(-2), col.darkened(0.25))
	ci.draw_rect(r.grow(-4), col)
	match sh:
		"cross":
			ci.draw_rect(Rect2(r.position + Vector2(13, 7), Vector2(6, 18)), Color.WHITE)
			ci.draw_rect(Rect2(r.position + Vector2(7, 13), Vector2(18, 6)), Color.WHITE)
		"dome":
			ci.draw_circle(c + Vector2(0, 2), 9.0, col.lightened(0.3))
			ci.draw_rect(Rect2(c + Vector2(-9, 2), Vector2(18, 7)), col.darkened(0.1))
		"turbine":
			var a := Time.get_ticks_msec() * 0.004
			ci.draw_line(c + Vector2(0, 10), c + Vector2(0, -2), Color.WHITE, 2.0)
			for k in 3:
				ci.draw_line(c + Vector2(0, -2), c + Vector2(0, -2) + Vector2.from_angle(a + k * TAU / 3.0) * 11.0, Color.WHITE, 1.5)
		"panels":
			for k in 2:
				ci.draw_rect(Rect2(r.position + Vector2(6, 7 + k * 10), Vector2(20, 7)), Color("2c4a7a"))
		"fort":
			ci.draw_rect(Rect2(r.position + Vector2(6, 10), Vector2(20, 14)), col.darkened(0.2))
			for k in 3:
				ci.draw_rect(Rect2(r.position + Vector2(6 + k * 8, 7), Vector2(4, 4)), col.darkened(0.2))
			ci.draw_line(r.position + Vector2(16, 10), r.position + Vector2(16, 2), Color.WHITE, 1.0)
			ci.draw_rect(Rect2(r.position + Vector2(16, 2), Vector2(6, 4)), Color("c04030"))
		"radar":
			var ra := Time.get_ticks_msec() * 0.003
			ci.draw_line(c + Vector2(0, 10), c, Color.WHITE, 2.0)
			ci.draw_arc(c, 9.0, ra, ra + 2.2, 10, Color("9fe0a0"), 2.0)
		"lamp":
			ci.draw_line(c + Vector2(0, 10), c + Vector2(0, -6), Color("555555"), 2.0)
			ci.draw_circle(c + Vector2(0, -8), 4.0, Color("ffe9a0"))
		"chimney":
			ci.draw_rect(Rect2(r.position + Vector2(18, 4), Vector2(7, 20)), col.darkened(0.4))
			ci.draw_circle(r.position + Vector2(21, 2 - fmod(Time.get_ticks_msec() * 0.01, 6.0)), 3.0, Color(0.7, 0.7, 0.7, 0.5))
		_:
			ci.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, 23), d["g"], HORIZONTAL_ALIGNMENT_CENTER, TILE, 18, Color.WHITE if col.get_luminance() < 0.5 else Color("2a2a20"))
	if not ok:
		ci.draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), Color("b03a2e"), 2.0)


## Free water extent (up to 9 cells each way) through `w` along one axis, as (lo, hi) offsets.
func _run(w: Vector2i, vert: bool) -> Vector2i:
	var d := Vector2i(0, 1) if vert else Vector2i(1, 0)
	var lo := 0
	var hi := 0
	while hi < 9 and _wet(w + d * (hi + 1)):
		hi += 1
	while lo > -9 and _wet(w + d * (lo - 1)):
		lo -= 1
	return Vector2i(lo, hi)


func _wet(p: Vector2i) -> bool:
	return city.inside(p.x, p.y) and city.water[p.y * City.W + p.x] == 1 and city.grid[p.y * City.W + p.x] == T.EMPTY


## Cargo ships (ports) and warships (naval yards) patrol the river stretch beside their dock.
func _boats() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for id in [T.PORT, T.NAVYARD]:
		for i in city.bt.get(id, []):
			var x: int = i % City.W
			var y: int = i / City.W
			var w := Vector2i(-1, -1)
			for d in City.DIRS:
				if city.inside(x + d.x, y + d.y) and city.water[(y + d.y) * City.W + x + d.x] == 1:
					w = Vector2i(x + d.x, y + d.y)
					break
			if w.x < 0:
				continue
			var rv := _run(w, true)
			var rh := _run(w, false)
			var vert: bool = rv.y - rv.x > rh.y - rh.x
			var lo: int = (rv if vert else rh).x
			var hi: int = (rv if vert else rh).y
			var ph := t * 0.2 + float(i % 13)
			var s := lo + (hi - lo) * (0.5 + 0.5 * sin(ph)) + 0.5
			var dir := 1.0 if cos(ph) >= 0.0 else -1.0
			var pos := (Vector2(w.x + 0.5, w.y + s) if vert else Vector2(w.x + s, w.y + 0.5)) * TILE
			Art.boat(ci, pos, vert, dir, id == T.NAVYARD)


func _nets(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i := y * City.W + x
			var c := Vector2(x + 0.5, y + 0.5) * TILE
			for k in 3:
				var layer: PackedByteArray = [city.wire, city.pipe, city.sewer][k]
				if layer[i] == 0:
					continue
				var m: String = City.NETS[k]
				var live: bool = city.net_reach[m][i] == 1
				var col: Color = [Color("f2cf4a"), Color("4fa3e0"), Color("a07a4a")][k]
				if not live:
					col = col.darkened(0.5)
				var off: Vector2 = [Vector2(-5, -5), Vector2(5, 5), Vector2(5, -5)][k]
				ci.draw_circle(c + off, 2.0, col)
				if x + 1 < City.W and layer[i + 1] == 1:
					ci.draw_line(c + off, c + off + Vector2(TILE, 0), col, 1.5)
				if y + 1 < City.H and layer[i + City.W] == 1:
					ci.draw_line(c + off, c + off + Vector2(0, TILE), col, 1.5)
