class_name City
extends RefCounted
## Pure city rules + citizen agents. No drawing, no I/O. Reads Signals, never feeds.
## Data (buildings, stats, policies, events) lives in catalog.gd / events.gd.
## Numbers are first guesses; tune from playtest (GAME_DESIGN.md section 4).

const T = Catalog.Id

const W := 96  # whole map; you only own `terr` (starts 48x32 in the middle) and buy more
const H := 64
const OX := 24  # seed offset: the starting town sits in the middle of the map
const OY := 16
const START_W := 48
const START_H := 32
const EXPAND := 8
const RATE := 0.08  # global income scale
const DEBT_LIMIT := -150.0
const WEATHER_PENALTY := {"clear": 0.0, "rain": 0.05, "heatwave": 0.1, "storm": 0.2, "snow": 0.05, "fog": 0.02}
const DAY_SECS := 60.0  # sim seconds per day
const BRIDGE_X := 4.0  # a road tile over water costs this much more
const WALK := 2.4  # cells per sim second
const GROW_COST := 25.0
const BUILD_SECS := 8.0
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


class Citizen:
	var id := 0
	var home := -1
	var work := -1
	var fav := -1  # leisure spot
	var fav_day := 0
	var at := -1  # building/road cell index we are inside/on, -1 while walking
	var goal := -1
	var pos := Vector2.ZERO  # in cell units
	var path := PackedVector2Array()
	var pi := 0
	var off := Vector2.ZERO
	var shift := 0.0
	var spd := 1.0
	var fast := false
	var bias := 0.0
	var mood := 0.6
	var commute := 0
	var retry := 0.0
	var bubble := ""
	var bubble_t := 0.0
	var protesting := false
	var doing := "at home"
	var tribe := "club"
	var nm := ""
	var sick := 0.0  # seconds of illness left
	var car := false  # drives (long commute, no transit)


var sig: Signals
var rng := RandomNumberGenerator.new()
var grid := PackedInt32Array()
var lvl := PackedByteArray()  # zone building level, 0 = empty zone
var build := PackedFloat32Array()  # construction progress 0..1
var connected := PackedByteArray()
var burn := PackedFloat32Array()  # 0 = no fire, else fire age in s
var flames: Array[int] = []
var citizens: Array[Citizen] = []
var astar := AStarGrid2D.new()
var roads_dirty := true

var coins := 300.0
var mood := 0.6
var tax_r := 0.10
var tax_c := 0.10
var tax_i := 0.10
var clock := 6.0  # hours
var day := 1
var protest := false
var over := ""
var msg := ""
var murmurs: Array[String] = []
var event_log: Array[String] = []
var active: Array[Dictionary] = []  # {id, left, mods}
var recent := {}  # event id -> day last fired
var policies := {}  # key -> bool
var mods := {}
var auto_mode := 2  # 0 off, 1 plots, 2 plots + roads
var peak := 0.0
var announced := {}
var next_id := 1
var acc := 0.0
var murmur_t := 6.0
var next_fire := 60.0
var ev_t := 50.0
var ev_scale := 1.0
var land_t := 0
var plan_t := 0
var wire := PackedByteArray()
var pipe := PackedByteArray()
var lamp := PackedByteArray()  # street lamps sit on road tiles
var water := PackedByteArray()  # 1 = river; only roads (bridges) and wires/pipes can cross it
var net_reach := {}  # "power"/"water" -> PackedByteArray of live line cells
var net_val := {}  # metric -> PackedFloat32Array per cell: satisfaction 0..1 where served
const NETS := ["power", "water", "sewage"]
var sewer := PackedByteArray()
var river_health := 1.0  # 1 = clean; falls when sewage goes untreated, kills fish
var net_sup := {"power": 0.0, "water": 0.0, "sewage": 0.0}
var net_dem := {"power": 0.0, "water": 0.0, "sewage": 0.0}
var auto_policy := true
var crime := 0.0
var town_name := "Murmur"
var partners: Array = []  # other towns in the region (City)
var imports := {"power": 0.0, "water": 0.0, "sewage": 0.0}
var net_own := {"power": 0.0, "water": 0.0, "sewage": 0.0}
var trade_net := 0.0
var commuters_in := 0
var grant_sum := 0.0
var tribe_mood := {}
var tribe_share := {}
var tribe_mods := {}
var tribe_note := []
var land_val := PackedFloat32Array()
var land_avg := 0.5
var res_mult := 1.0
var tier_sum := 0.0
var avg_commute := 0.0  # tiles to work
var avg_shop := 0.0  # tiles to the nearest shop
var crime_val := PackedFloat32Array()
var unemp := 0.0
var saving_for := 0.0  # treasury target for a needed service; pauses other spending
var burning := 0
var burned := 0  # buildings lost to fire, lifetime
var plaza := -1
# territory + diplomacy
var terr := Rect2i(OX, OY, START_W, START_H)
var cells := PackedInt32Array()  # indices of owned cells: every whole-map loop runs over these
var expansions := 0
var auto_expand := true
var human := true  # false = run by the planner alone, cannot be lost
var temper := 0.0  # baseline attitude to other towns
var rel := {}  # town_name -> this town's opinion (-1..1)
var treaty := {}  # town_name -> "", "pact", "alliance", "embargo"
var dipl_t := 70.0
var gpos := Vector2i.ZERO  # position in the region (towns are laid out on a grid)
var gate := [0, 0, 0, 0]  # road tiles at the border facing N, E, S, W (a link needs one)
var war_n := {}  # town_name -> battles fought in the current war
var war_sc := {}  # town_name -> battles I won in the current war
var war_t := 25.0
# mayor
var approval := 0.6
var rep := 0.0  # reputation from promises, decays slowly
var favor := {}  # tribe -> petition favour
var petitions: Array = []  # open decisions: petitions and recovery offers
var promises: Array = []  # accepted petitions awaiting delivery
var pet_t := 40.0
var pet_ver := 0
var pet_recent := {}
var kept := 0
var broken := 0
var next_election := Civics.YEAR_DAYS + 1
var elections_won := 0
var rally_used := false
var last_vote := 0.0
var season := 0
# economy
var stock := {"crops": 0.0, "food": 0.0, "goods": 0.0}
var flow := {}
var cap := 60.0
var exported := 0.0
var loans: Array = []
# streets and disasters
var traffic := PackedFloat32Array()
var congestion := 0.0
var drivers := 0
var sick_n := 0
var offline := {}  # plant cell -> seconds left
var ruins: Array = []  # [cell, type, level] since the last recovery decision
var twister := {}
var disasters_survived := 0
var done_ms := {}
var buses: Array = []
var sounds: Array[String] = []  # cues for the sound system, drained by main

# per-scan stats
var roads := 0
var avenues := 0
var blds := 0
var housing := 0
var shop_jobs := 0
var fac_jobs := 0
var off_jobs := 0
var farm_jobs := 0
var svc_jobs := 0
var jobs := 0
var up_zone := 0.0
var up_svc := 0.0
var tour_sum := 0.0
var homes: Array[int] = []
var works: Array[int] = []
var spots: Array[int] = []
var bt := {}  # building id -> Array[int] of connected cells
var prov := {}  # metric -> Array of [x, y, strength, radius]
var polluters: Array = []  # [x, y, strength, radius]
var cov := {}  # metric -> avg coverage over homes (0..1, incl. mods)
var need_pop := {}
var pollution := 0.0
var home_load := {}
var work_load := {}
var pop := 0
var employed := 0
var res_dem := 0.0
var com_dem := 0.0
var ind_dem := 0.0
var off_dem := 0.0
var shop_gap := 0.0

# money, per sim second (already scaled)
var income := 0.0
var budget_lines: Array = []  # [label, value]
var inc_tax := 0.0  # kept for tests: all revenue lines summed
var hist_coins: Array[float] = []
var hist_pop: Array[float] = []
var hist_t := 0


func _init(s: Signals) -> void:
	sig = s
	_rebuild_cells()
	grid.resize(W * H)
	lvl.resize(W * H)
	build.resize(W * H)
	connected.resize(W * H)
	burn.resize(W * H)
	wire.resize(W * H)
	crime_val.resize(W * H)
	land_val.resize(W * H)
	pipe.resize(W * H)
	sewer.resize(W * H)
	lamp.resize(W * H)
	water.resize(W * H)
	traffic.resize(W * H)
	for m in NETS:
		net_reach[m] = PackedByteArray()
		net_reach[m].resize(W * H)
		net_val[m] = PackedFloat32Array()
		net_val[m].resize(W * H)
	rng.randomize()
	gen_river(rng.randi())
	for m in Catalog.METRICS:
		need_pop[m] = Catalog.need_pop(m)
		cov[m] = 0.0
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()


func _rebuild_cells() -> void:
	cells.clear()
	for y in range(terr.position.y, terr.end.y):
		for x in range(terr.position.x, terr.end.x):
			cells.append(y * W + x)


func owns(x: int, y: int) -> bool:
	return terr.has_point(Vector2i(x, y))


func expand_cost() -> float:
	return 120.0 * (1.0 + 0.5 * expansions)


## dir: 0 north, 1 east, 2 south, 3 west
func can_expand(dir: int) -> bool:
	match dir:
		0:
			return terr.position.y - EXPAND >= 0
		1:
			return terr.end.x + EXPAND <= W
		2:
			return terr.end.y + EXPAND <= H
	return terr.position.x - EXPAND >= 0


## War loss: give up the outermost strip on this side. Buildings in it are lost.
func cede(dir: int) -> bool:
	var r := terr
	var strip: Rect2i
	match dir:
		0:
			strip = Rect2i(r.position, Vector2i(r.size.x, EXPAND))
			r = Rect2i(r.position.x, r.position.y + EXPAND, r.size.x, r.size.y - EXPAND)
		1:
			strip = Rect2i(r.end.x - EXPAND, r.position.y, EXPAND, r.size.y)
			r = Rect2i(r.position, Vector2i(r.size.x - EXPAND, r.size.y))
		2:
			strip = Rect2i(r.position.x, r.end.y - EXPAND, r.size.x, EXPAND)
			r = Rect2i(r.position, Vector2i(r.size.x, r.size.y - EXPAND))
		_:
			strip = Rect2i(r.position, Vector2i(EXPAND, r.size.y))
			r = Rect2i(r.position.x + EXPAND, r.position.y, r.size.x - EXPAND, r.size.y)
	if r.size.x < 24 or r.size.y < 16:
		return false
	for y in range(strip.position.y, strip.end.y):
		for x in range(strip.position.x, strip.end.x):
			var i := y * W + x
			grid[i] = T.EMPTY
			lvl[i] = 0
			lamp[i] = 0
	terr = r
	_rebuild_cells()
	roads_dirty = true
	msg = "Enemy troops seize the %s strip of your land." % ["north", "east", "south", "west"][dir]
	_log(msg)
	sounds.append("alarm")
	_scan()
	return true


func expand(dir: int, free := false) -> bool:
	if not can_expand(dir) or (not free and coins < expand_cost()):
		return false
	if not free:
		coins -= expand_cost()
	match dir:
		0:
			terr = Rect2i(terr.position.x, terr.position.y - EXPAND, terr.size.x, terr.size.y + EXPAND)
		1:
			terr = Rect2i(terr.position, Vector2i(terr.size.x + EXPAND, terr.size.y))
		2:
			terr = Rect2i(terr.position, Vector2i(terr.size.x, terr.size.y + EXPAND))
		_:
			terr = Rect2i(terr.position.x - EXPAND, terr.position.y, terr.size.x + EXPAND, terr.size.y)
	expansions += 1
	_rebuild_cells()
	msg = "Annexed new land to the %s. The town can grow again." % ["north", "east", "south", "west"][dir]
	_log(msg)
	sounds.append("chime")
	_scan()
	return true


## Picks the side whose edge is most built-up and buys it.
func _expand_auto() -> bool:
	if coins < expand_cost() * 1.5:
		return false
	var score := [0, 0, 0, 0]
	for i in cells:
		if grid[i] == T.EMPTY:
			continue
		var c := cell(i)
		if c.y <= terr.position.y + 2:
			score[0] += 1
		if c.x >= terr.end.x - 3:
			score[1] += 1
		if c.y >= terr.end.y - 3:
			score[2] += 1
		if c.x <= terr.position.x + 2:
			score[3] += 1
	var order := [0, 1, 2, 3]
	order.sort_custom(func(a: int, b: int) -> bool: return score[a] > score[b])
	for d in order:
		if can_expand(d):
			return expand(d)
	return false


func partner(name_: String) -> City:
	for p in partners:
		if p.town_name == name_:
			return p
	return null


static func cell(i: int) -> Vector2i:
	return Vector2i(i % W, floori(i / float(W)))


static func center(i: int) -> Vector2:
	return Vector2(i % W + 0.5, floori(i / float(W)) + 0.5)


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H


func at(x: int, y: int) -> int:
	return grid[y * W + x] if inside(x, y) else -1


func def(t: int) -> Dictionary:
	return Catalog.DEFS[t]


func is_zone(t: int) -> bool:
	return t > T.EMPTY and String(Catalog.DEFS[t]["kind"]) == "zone"


func is_road(t: int) -> bool:
	return t == T.ROAD or t == T.AVENUE


func clock_str() -> String:
	return "Day %d  %02d:%02d" % [day, int(clock), int((clock - floorf(clock)) * 60.0)]


func stamp() -> String:
	return "D%d %02d:%02d" % [day, int(clock), int((clock - floorf(clock)) * 60.0)]


func mod(k: String) -> float:
	return float(mods.get(k, 1.0 if k.ends_with("_mult") else 0.0))


func unlocked(t: int) -> bool:
	return peak >= float(Catalog.DEFS[t]["unlock"])


func cost_of(t: int) -> float:
	return float(Catalog.DEFS[t]["cost"])


func _road_next_to(i: int) -> int:
	if is_road(grid[i]):
		return i
	var x := i % W
	var y := i / W
	if x > 0 and is_road(grid[i - 1]):
		return i - 1
	if x < W - 1 and is_road(grid[i + 1]):
		return i + 1
	if y > 0 and is_road(grid[i - W]):
		return i - W
	if y < H - 1 and is_road(grid[i + W]):
		return i + W
	return -1


func _netm(t: int) -> String:
	return "power" if t == T.WIRE else ("sewage" if t == T.SEWER else "water")


func _nl(m: String) -> PackedByteArray:
	return wire if m == "power" else (sewer if m == "sewage" else pipe)


## Lay one cell of a network line (explicit writes: packed arrays are not safe to mutate through a returned alias).
func _lay(m: String, i: int, v: int) -> void:
	if m == "power":
		wire[i] = v
	elif m == "sewage":
		sewer[i] = v
	else:
		pipe[i] = v


func place(x: int, y: int, t: int) -> bool:
	if not inside(x, y) or not owns(x, y) or coins < cost_of(t) or not unlocked(t):
		return false
	if t == T.LIGHT:
		var li := y * W + x
		if not is_road(grid[li]) or lamp[li] == 1 or _lamp_near(li, 2):
			return false
		lamp[li] = 1
		coins -= cost_of(t)
		_scan()
		return true
	if String(Catalog.DEFS[t]["kind"]) == "net":
		var ni := y * W + x
		var nm := _netm(t)
		if _nl(nm)[ni] == 1:
			return false
		_lay(nm, ni, 1)
		coins -= cost_of(t)
		_scan()
		return true
	if at(x, y) != T.EMPTY:
		return false
	var wet := water[y * W + x] == 1
	if wet and (not is_road(t) or coins < cost_of(t) * BRIDGE_X):
		return false
	if Catalog.DEFS[t].get("water", false) and not wet_next(x, y):
		return false
	grid[y * W + x] = t
	coins -= cost_of(t) * (BRIDGE_X if wet else 1.0)
	if is_road(t):
		roads_dirty = true
	_scan()
	return true


func _lamp_near(i: int, d: int) -> bool:
	var c := cell(i)
	for dy in range(-d + 1, d):
		for dx in range(-d + 1, d):
			if absi(dx) + absi(dy) < d and inside(c.x + dx, c.y + dy) and lamp[(c.y + dy) * W + c.x + dx] == 1:
				return true
	return false


func bulldoze(x: int, y: int) -> bool:
	if not inside(x, y) or not owns(x, y):
		return false
	var i := y * W + x
	if lamp[i] == 1:
		lamp[i] = 0
		_scan()
		return true
	if grid[i] == T.EMPTY:
		if wire[i] == 0 and pipe[i] == 0 and sewer[i] == 0:
			return false
		wire[i] = 0
		pipe[i] = 0
		sewer[i] = 0
		_scan()
		return true
	if is_road(grid[i]):
		roads_dirty = true
	grid[i] = T.EMPTY
	lvl[i] = 0
	build[i] = 0.0
	_clear_burn(i)
	_scan()
	return true


func _log(text: String) -> void:
	event_log.push_front("%s  %s" % [stamp(), text])
	if event_log.size() > 30:
		event_log.pop_back()


## Index of a seed-relative cell (the starting town is drawn around (24, 16) of a 48x32 plan).
static func sidx(x: int, y: int) -> int:
	return (y + OY) * W + x + OX


func set_start(w: int, h: int) -> void:
	terr = Rect2i(W / 2 - w / 2, H / 2 - h / 2, w, h)
	gen_river(rng.randi())
	dry_built()
	_rebuild_cells()
	_scan()


## Random river across the whole map, beside the starting plan. mode 0 = none. Water cells are 1 in `water`.
func gen_river(sd: int, mode := 1) -> void:
	water.fill(0)
	if mode == 0:
		return
	var r := RandomNumberGenerator.new()
	r.seed = sd
	var vert := r.randf() < 0.5
	var sgn := 1.0 if r.randf() < 0.5 else -1.0
	var mid := (terr.position.x + terr.size.x * 0.5) if vert else (terr.position.y + terr.size.y * 0.5)
	var span := terr.size.x if vert else terr.size.y
	var base := mid + sgn * span * r.randf_range(0.3, 0.4)
	var c := base
	for a in (H if vert else W):
		c = clampf(c + r.randf_range(-0.45, 0.45), base - 4.0, base + 4.0)
		var wd := 2 + int(1.5 + sin(a * 0.15 + sd % 7))
		for k in wd:
			var x := int(c) + k if vert else a
			var y := a if vert else int(c) + k
			if inside(x, y):
				water[y * W + x] = 1


## True if a river cell touches (x, y) on one of its four sides.
func wet_next(x: int, y: int) -> bool:
	for d in DIRS:
		if inside(x + d.x, y + d.y) and water[(y + d.y) * W + x + d.x] == 1:
			return true
	return false


## World editor: paint or clear a river cell (free; only on empty ground).
func set_water(x: int, y: int, v: int) -> bool:
	if not inside(x, y) or grid[y * W + x] != T.EMPTY or wire[y * W + x] + pipe[y * W + x] + sewer[y * W + x] + lamp[y * W + x] > 0:
		return false
	water[y * W + x] = v
	return true


## Water never sits under existing buildings.
func dry_built() -> void:
	for i in W * H:
		if grid[i] != T.EMPTY:
			water[i] = 0


func seed_start() -> void:
	for x in range(18, 31):
		grid[sidx(x, 16)] = T.ROAD
	for x in [20, 22]:
		grid[sidx(x, 15)] = T.RES
		lvl[sidx(x, 15)] = 1
	grid[sidx(25, 15)] = T.COM
	lvl[sidx(25, 15)] = 1
	grid[sidx(28, 17)] = T.IND
	lvl[sidx(28, 17)] = 1
	grid[sidx(23, 17)] = T.PARK
	dry_built()
	roads_dirty = true
	_rebuild_astar()
	_scan()
	for i in 4:
		_spawn()
	_second()


func _rebuild_astar() -> void:
	astar.fill_solid_region(astar.region, true)
	for i in cells:
		if is_road(grid[i]):
			var c := cell(i)
			astar.set_point_solid(c, false)
			astar.set_point_weight_scale(c, 0.6 if grid[i] == T.AVENUE else 1.0)
	roads_dirty = false


# ---------- scanning ----------

func _add_prov(m: String, c: Vector2i, s: float, r: int) -> void:
	if not prov.has(m):
		prov[m] = []
	prov[m].append([c.x, c.y, s, r])


## Recount everything that depends on the map.
func _scan() -> void:
	roads = 0
	avenues = 0
	blds = 0
	housing = 0
	shop_jobs = 0
	fac_jobs = 0
	off_jobs = 0
	farm_jobs = 0
	svc_jobs = 0
	up_zone = 0.0
	tier_sum = 0.0
	grant_sum = 0.0
	up_svc = 0.0
	tour_sum = 0.0
	homes.clear()
	works.clear()
	spots.clear()
	bt.clear()
	prov.clear()
	polluters.clear()
	plaza = -1
	gate = [0, 0, 0, 0]
	var best := 1e9
	for i in cells:
		var t := grid[i]
		if t == T.EMPTY:
			connected[i] = 0
			continue
		var ok := _road_next_to(i) >= 0
		connected[i] = 1 if ok else 0
		if not ok:
			continue
		var d: Dictionary = Catalog.DEFS[t]
		var kind: String = d["kind"]
		var c := cell(i)
		if kind == "road":
			roads += 1
			var gx := i % W
			var gy := i / W
			if gy < terr.position.y + 3:
				gate[0] += 1
			if gx >= terr.end.x - 3:
				gate[1] += 1
			if gy >= terr.end.y - 3:
				gate[2] += 1
			if gx < terr.position.x + 3:
				gate[3] += 1
			if t == T.AVENUE:
				avenues += 1
			var dist := center(i).distance_to(Vector2(W, H) * 0.5)
			if dist < best:
				best = dist
				plaza = i
		elif kind == "zone":
			var L: int = lvl[i]
			if L > 0:
				blds += L
				up_zone += float(d["up"]) * L
				var hp: int = d["home"]
				var jp: int = d["jobs"]
				if hp > 0:
					homes.append(i)
					housing += hp * L
					tier_sum += hp * L * float(d.get("tier", 1.0))
				if jp > 0:
					works.append(i)
					match String(d["sector"]):
						"com":
							shop_jobs += jp * L
						"ind":
							fac_jobs += jp * L
						"office":
							off_jobs += jp * L
						"farm":
							farm_jobs += jp * L
				if d.has("poll"):
					polluters.append([c.x, c.y, float(d["poll"][1]) * L, int(d["poll"][0])])
				if t == T.COM:
					spots.append(i)
		else:
			up_svc += float(d["up"])
			if not bt.has(t):
				bt[t] = []
			bt[t].append(i)
			var sj: int = d.get("jobs", 0)
			if sj > 0:
				works.append(i)
				svc_jobs += sj
			if d.get("spot", false):
				spots.append(i)
			if d.has("tour"):
				tour_sum += float(d["tour"])
			grant_sum += float(d.get("grant", 0.0))
			for m in d["prov"]:
				_add_prov(m, c, float(d["prov"][m]), int(d["r"]))
			if d.has("poll"):
				polluters.append([c.x, c.y, float(d["poll"][1]), int(d["poll"][0])])
	for i in cells:
		if lamp[i] == 1 and is_road(grid[i]):
			if not bt.has(T.LIGHT):
				bt[T.LIGHT] = []
			bt[T.LIGHT].append(i)
			_add_prov("light", cell(i), 0.7, 4)
			up_svc += 0.1
	jobs = shop_jobs + fac_jobs + off_jobs + farm_jobs + svc_jobs
	res_mult = tier_sum / maxf(housing, 1)
	_net()
	for m in Catalog.METRICS:
		var sum := 0.0
		for h in homes:
			sum += cov_at(cell(h), m)
		cov[m] = sum / maxi(homes.size(), 1) if not homes.is_empty() else 0.0
	var ps := 0.0
	for h in homes:
		ps += minf(1.0, poll_at(cell(h)))
	pollution = ps / maxi(homes.size(), 1) * mod("poll_mult") if not homes.is_empty() else 0.0


## Power and water networks: plants feed connected lines; buildings touching a live line share the supply.
func _net() -> void:
	var nets := 0
	for m in NETS:
		var layer: PackedByteArray = _nl(m)
		var reach: PackedByteArray = net_reach[m]
		reach.fill(0)
		var q: Array[int] = []
		var sup := 0.0
		for id in bt:
			var out: Dictionary = Catalog.DEFS[id].get("out", {})
			if not out.has(m):
				continue
			for i in bt[id]:
				if offline.has(i):
					continue
				var hit := false
				for j in _near(i):
					if layer[j] == 1:
						hit = true
						if reach[j] == 0:
							reach[j] = 1
							q.append(j)
				if hit:
					sup += float(out[m]) * (1.0 + mod(m + "_out"))
		while not q.is_empty():
			var cur: int = q.pop_back()
			for d in DIRS:
				var n: Vector2i = cell(cur) + d
				if inside(n.x, n.y):
					var ni := n.y * W + n.x
					if layer[ni] == 1 and reach[ni] == 0:
						reach[ni] = 1
						q.append(ni)
		var dem := 0.0
		for i in cells:
			nets += layer[i]
			var t: int = grid[i]
			if t == T.EMPTY or connected[i] == 0 or is_road(t):
				continue
			var d: Dictionary = Catalog.DEFS[t]
			if d.has("out") or (is_zone(t) and lvl[i] == 0):
				continue
			if _live(i, reach):
				dem += 0.5 * lvl[i] * (1.0 + (int(d["home"]) + int(d["jobs"])) * 0.1) if is_zone(t) else 1.0
		if m == "power":
			dem *= 1.0 + mod("power_dem")
		net_own[m] = sup
		imports[m] = 0.0
		if sup < dem:
			for p in partners:
				var surplus: float = float(p.net_own[m]) - float(p.net_dem[m])
				var take := minf(maxf(surplus, 0.0) * 0.6 * Diplo.tmult(self, p), dem - sup)
				if take > 0.0:
					sup += take
					imports[m] = float(imports[m]) + take
		net_sup[m] = sup
		net_dem[m] = dem
		var sat := 1.0 if dem <= 0.001 else clampf(sup / dem, 0.0, 1.0)
		if sup <= 0.0:
			sat = 0.0
		var val: PackedFloat32Array = net_val[m]
		for i in cells:
			val[i] = sat if _live(i, reach) else 0.0
	up_svc += nets * 0.015
	var raw := maxf(pop - 20.0, 0.0) * 0.15  # sewage produced; what the plants don't treat goes in the river
	var clean := 1.0 if raw <= 0.0 else clampf(float(net_own["sewage"]) / raw, 0.0, 1.0)
	river_health = move_toward(river_health, clean, 0.02)


func _near(i: int) -> Array[int]:
	var r: Array[int] = [i]
	var c := cell(i)
	for d in DIRS:
		var n: Vector2i = c + d
		if inside(n.x, n.y):
			r.append(n.y * W + n.x)
	return r


func _live(i: int, reach: PackedByteArray) -> bool:
	if reach[i] == 1:
		return true
	var x := i % W
	var y := i / W
	return (x > 0 and reach[i - 1] == 1) or (x < W - 1 and reach[i + 1] == 1) or (y > 0 and reach[i - W] == 1) or (y < H - 1 and reach[i + W] == 1)


## Crime per block: unemployment, density and weak police drive it; lights and courts cut it.
func _crime() -> void:
	var base := 0.08 + 0.5 * unemp + mod("crime_add")
	var sz := clampf(pop / 50.0, 0.1, 1.0)  # small towns have little crime
	var tot := 0.0
	crime_val.fill(0.0)
	for i in cells:
		if grid[i] == T.EMPTY or is_road(grid[i]):
			continue
		var c := cell(i)
		var dens := 0
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if absi(dx) + absi(dy) <= 2 and inside(c.x + dx, c.y + dy) and grid[(c.y + dy) * W + c.x + dx] != T.EMPTY:
					dens += 1
		var v := base + sz * (0.3 * float(dens) / 13.0 + 0.3 * (1.0 - cov_at(c, "police")) + float(Catalog.DEFS[grid[i]].get("crime", 0.0)))
		v *= 1.0 - 0.25 * cov_at(c, "light")
		v *= 1.0 - 0.35 * cov_at(c, "justice")
		v = clampf(v * mod("crime_mult"), 0.0, 1.0)
		crime_val[i] = v if dens > 0 else 0.0
	for h in homes:
		tot += crime_val[h]
	crime = tot / maxf(homes.size(), 1) if not homes.is_empty() else 0.0


func raw_cov(c: Vector2i, m: String) -> float:
	if net_val.has(m):
		return net_val[m][c.y * W + c.x]
	var s := 0.0
	var arr: Array = prov.get(m, [])
	for p in arr:
		if absi(p[0] - c.x) + absi(p[1] - c.y) <= p[3]:
			s += p[2]
	return minf(s, 1.0)


func cov_at(c: Vector2i, m: String) -> float:
	return clampf(raw_cov(c, m) + mod("cov_" + m), 0.0, 1.0)


func poll_at(c: Vector2i) -> float:
	var s := 0.0
	for p in polluters:
		var d := absi(p[0] - c.x) + absi(p[1] - c.y)
		if d <= p[3]:
			s += p[2] * (1.0 - float(d) / (p[3] + 1.0))
	return s


func _need(m: String) -> float:
	if String(Catalog.METRICS[m]["kind"]) != "need" or pop < int(need_pop[m]):
		return 0.0
	var np := float(need_pop[m])
	return (1.0 - float(cov[m])) * clampf((pop - np) / (np * 0.8 + 5.0) + 0.25, 0.0, 1.0)  # ramps in as the city outgrows the need


func _hcap(i: int) -> int:
	return int(Catalog.DEFS[grid[i]]["home"]) * lvl[i]


func _cap(i: int) -> int:
	var d: Dictionary = Catalog.DEFS[grid[i]]
	return int(d["jobs"]) * lvl[i] if String(d["kind"]) == "zone" else int(d.get("jobs", 0))


func _spawn() -> bool:
	var opts: Array[int] = []
	for i in homes:
		if home_load.get(i, 0) < _hcap(i):
			opts.append(i)
	if opts.is_empty():
		return false
	var c := Citizen.new()
	c.id = next_id
	next_id += 1
	c.home = opts[rng.randi() % opts.size()]
	c.at = c.home
	c.pos = center(c.home)
	c.off = Vector2(rng.randf_range(-0.14, 0.14), rng.randf_range(-0.14, 0.14))
	c.bias = rng.randf_range(-0.08, 0.08)
	c.nm = Catalog.FIRST_NAMES[rng.randi() % Catalog.FIRST_NAMES.size()]
	c.tribe = _roll_tribe()
	c.shift = rng.randf_range(-1.2, 1.2)
	c.spd = rng.randf_range(0.8, 1.25)
	home_load[c.home] = home_load.get(c.home, 0) + 1
	citizens.append(c)
	return true


func _roll_tribe() -> String:
	var tot := 0.0
	for k in Catalog.TRIBES:
		tot += float(Catalog.TRIBES[k]["w"])
	var r := rng.randf() * tot
	for k in Catalog.TRIBES:
		r -= float(Catalog.TRIBES[k]["w"])
		if r <= 0.0:
			return String(k)
	return "club"


## Tribe opinion = half citizen mood, half how well the city meets their demands. Strong tribes change the rules.
func _tribes() -> void:
	var cnt := {}
	var ms := {}
	for k in Catalog.TRIBES:
		cnt[k] = 0
		ms[k] = 0.0
	for c in citizens:
		cnt[c.tribe] += 1
		ms[c.tribe] += c.mood
	var mk := sig.get_f("market")
	var sat := {
		"church": 0.5 + (0.3 if bt.has(T.CHURCH) else -0.2) - crime * 0.3,
		"union": 0.6 - unemp * 1.5 - (tax_i - 0.1) * 2.0 + (0.15 if bt.has(T.UNION_HALL) else 0.0),
		"business": 0.6 - (tax_c - 0.1) * 3.0 - (tax_i - 0.1) * 2.0 + com_dem * 0.1 + mk * 0.2 + (0.15 if bt.has(T.CHAMBER) else 0.0),
		"artists": 0.3 + float(cov["culture"]) * 0.7,
		"rebels": 0.6 - (0.25 if is_policy("curfew") else 0.0) - (0.25 if is_policy("stop_search") else 0.0) - (0.2 if protest else 0.0) + sig.get_f("news") * 0.2,
		"club": 0.3 + float(cov["leisure"]) * 0.6,
	}
	for k in sat:
		sat[k] = float(sat[k]) + float(favor.get(k, 0.0))
	tribe_mods = {}
	var old: Array = tribe_note
	tribe_note = []
	for k in Catalog.TRIBES:
		var share: float = float(cnt[k]) / maxf(pop, 1)
		var avg: float = float(ms[k]) / maxi(cnt[k], 1) if cnt[k] > 0 else 0.6
		var op: float = clampf(0.5 * avg + 0.5 * float(sat[k]), 0.0, 1.0)
		tribe_mood[k] = op
		tribe_share[k] = share
		if pop < 20 or share < 0.08:
			continue
		var hi: bool = op > 0.65
		var lo: bool = op < 0.38
		if not hi and not lo:
			continue
		tribe_note.append("%s %s" % [Catalog.TRIBES[k]["n"], "content" if hi else "angry"])
		match k:
			"church":
				_tm({"mood": 0.02 if hi else -0.02})
			"union":
				_tm({"prod_mult": 1.05 if hi else 0.9})
			"business":
				_tm({"sales_mult": 1.08 if hi else 0.9, "goods_mult": 1.0 if hi else 0.9})
			"artists":
				_tm({"tour_mult": 1.2 if hi else 0.8})
			"rebels":
				if lo:
					_tm({"crime_add": 0.1})
			"club":
				_tm({"mood": 0.02 if hi else -0.02})
	for t in tribe_note:
		if not old.has(t) and String(t).ends_with("angry"):
			_log("%s." % t)


func _tm(m: Dictionary) -> void:
	for key in m:
		if String(key).ends_with("_mult"):
			tribe_mods[key] = float(tribe_mods.get(key, 1.0)) * float(m[key])
		else:
			tribe_mods[key] = float(tribe_mods.get(key, 0.0)) + float(m[key])


func is_policy(k: String) -> bool:
	return bool(policies.get(k, false))


# ---------- events ----------

## Wars this town is fighting, and battles fought in them: war weariness grows with both.
func wars() -> int:
	var n := 0
	for k in treaty:
		if treaty[k] == "war":
			n += 1
	return n


func war_battles() -> float:
	var n := 0.0
	for k in treaty:
		if treaty[k] == "war":
			n += float(war_n.get(k, 0))
	return n


func _add_mods(m: Dictionary) -> void:
	for key in m:
		var v: float = float(m[key])
		if String(key).ends_with("_mult"):
			mods[key] = float(mods.get(key, 1.0)) * v
		else:
			mods[key] = float(mods.get(key, 0.0)) + v


func _collect_mods() -> void:
	mods.clear()
	for k in policies:
		if policies[k]:
			_add_mods(Catalog.POLICIES[k]["mods"])
	for a in active:
		_add_mods(a["mods"])
	_add_mods(tribe_mods)
	_add_mods(Civics.SEASONS[season]["mods"])
	if wars() > 0:
		_add_mods({"mood": -0.03 * wars() - 0.004 * minf(war_battles(), 15.0)})
	for k in treaty:
		if treaty[k] == "alliance":
			_add_mods({"cov_defence": 0.25})


func set_policy(k: String, on: bool) -> void:
	policies[k] = on
	_collect_mods()
	_scan()


func is_active(id: String) -> bool:
	for a in active:
		if a["id"] == id:
			return true
	return false


func trigger(id: String) -> bool:
	var e: Dictionary = WorldEvents.EVENTS[id]
	if e.has("needs") and not bt.has(int(e["needs"])):
		return false
	if id == "prison_break" and not bt.has(T.PRISON):
		return false
	if e.has("cost"):
		if coins < float(e["cost"]) or is_active(id):
			return false
		coins -= float(e["cost"])
	var k := 1.0
	if e.has("scale"):
		k = 1.0 - 0.7 * float(cov.get(e["scale"], 0.0))
	var dur := float(e["dur"])
	if dur > 0.0 and e.has("mods"):
		var scaled := {}
		for key in e["mods"]:
			var v: float = float(e["mods"][key])
			scaled[key] = (1.0 + (v - 1.0) * k) if String(key).ends_with("_mult") else v * k
		var found := false
		for a in active:
			if a["id"] == id:
				a["left"] = dur
				a["mods"] = scaled
				found = true
		if not found:
			active.append({"id": id, "left": dur, "mods": scaled})
		_collect_mods()
	if e.has("weather"):
		sig.set_weather(String(e["weather"]), dur)
	var inst: Dictionary = e.get("inst", {})
	if inst.has("coins"):
		coins = maxf(coins + float(inst["coins"]) * k, minf(coins, -40.0))
	if inst.has("coins_pop"):
		coins = maxf(coins + float(inst["coins_pop"]) * maxi(pop, 5) * k, minf(coins, -40.0))
	if inst.has("ignite"):
		for n in maxi(0, roundi(float(inst["ignite"]) * k)):
			ignite()
	if inst.has("damage"):
		_damage(float(inst["damage"]) * k)
	if inst.has("destroy"):
		_destroy(int(inst["destroy"]))
	if inst.has("damage") or inst.has("destroy"):
		_offer_recovery(String(e["n"]).to_lower())
	if inst.has("tornado"):
		var y0 := rng.randi_range(4, H - 5)
		var left := rng.randf() < 0.5
		twister = {"pos": Vector2(0.5 if left else W - 0.5, y0), "vel": Vector2(3.0 if left else -3.0, rng.randf_range(-1.0, 1.0)), "last": -1}
		sounds.append("alarm")
	if inst.has("infect"):
		for n in mini(int(inst["infect"]), citizens.size()):
			citizens[rng.randi() % citizens.size()].sick = rng.randf_range(25.0, 40.0)
	if inst.has("blackout"):
		var plants: Array = []
		for id2 in bt:
			if Catalog.DEFS[id2].get("out", {}).has("power"):
				plants += bt[id2]
		if not plants.is_empty():
			offline[plants[rng.randi() % plants.size()]] = 40.0
			_scan()
	if inst.has("citizens"):
		var n: int = int(inst["citizens"])
		if n > 0:
			for i in n:
				_spawn()
		else:
			for i in mini(-n, citizens.size()):
				citizens.remove_at(rng.randi() % citizens.size())
	if inst.has("news"):
		sig.bump("news", float(inst["news"]))
	if inst.has("market"):
		sig.bump("market", float(inst["market"]))
	recent[id] = day
	msg = String(e["msg"])
	_log("%s: %s" % [e["n"], e["msg"]])
	return true


func _burnables() -> Array[int]:
	var out: Array[int] = []
	for i in cells:
		if burnable(i):
			out.append(i)
	return out


func _damage(frac: float) -> void:
	for i in _burnables():
		if rng.randf() < frac:
			_hit(i)
	_scan()


func _destroy(n: int) -> void:
	var opts := _burnables()
	opts.shuffle()
	for k in mini(n, opts.size()):
		_ruin(opts[k])
	_scan()


## Destroys a building. rec: remember it for a recovery decision. Insurance pays out either way.
func _ruin(i: int, rec := true) -> void:
	if rec:
		ruins.append([i, grid[i], lvl[i]])
	if mod("insured") > 0.0:
		coins += 30.0
	if is_zone(grid[i]):
		lvl[i] = 0
		build[i] = 0.0
	else:
		grid[i] = T.EMPTY
	_clear_burn(i)
	burned += 1


func _hit(i: int) -> void:
	ruins.append([i, grid[i], lvl[i]])
	if is_zone(grid[i]):
		lvl[i] = maxi(0, lvl[i] - 1)
	else:
		lvl[i] = 0


# ---------- per second ----------

func _second() -> void:
	var sn := int((day - 1) / 7) % 4
	if sn != season:
		season = sn
		msg = "%s has arrived. %s" % [Civics.SEASONS[season]["n"], Civics.SEASONS[season]["txt"]]
		_log("%s begins." % Civics.SEASONS[season]["n"])
	for k in offline.keys():
		offline[k] = float(offline[k]) - 1.0
		if float(offline[k]) <= 0.0:
			offline.erase(k)
			_log("The power plant is back online.")
	_scan()
	_crime()
	land_t -= 1
	if land_t <= 0:
		land_t = 3
		_land()
	_tribes()
	_collect_mods()
	home_load.clear()
	work_load.clear()
	var keep: Array[Citizen] = []
	for c in citizens:
		var h := c.home
		if h >= 0 and is_zone(grid[h]) and lvl[h] > 0 and connected[h] == 1 and int(Catalog.DEFS[grid[h]]["home"]) > 0 and home_load.get(h, 0) < _hcap(h):
			home_load[h] = home_load.get(h, 0) + 1
			keep.append(c)
	if keep.size() < citizens.size():
		msg = "Residents left after losing their homes."
		citizens = keep
	for c in citizens:
		var w := c.work
		if w >= 0:
			var ok: bool = grid[w] != T.EMPTY and connected[w] == 1 and (not is_zone(grid[w]) or lvl[w] > 0) and work_load.get(w, 0) < _cap(w)
			if ok:
				work_load[w] = work_load.get(w, 0) + 1
			else:
				c.work = -1
				c.commute = 0
	for c in citizens:
		if c.work >= 0:
			continue
		var best := -1
		var bd := 1 << 30
		var hc := cell(c.home)
		for w in works:
			if work_load.get(w, 0) >= _cap(w):
				continue
			var wc := cell(w)
			var d := absi(wc.x - hc.x) + absi(wc.y - hc.y)
			if d < bd:
				bd = d
				best = w
		if best >= 0:
			c.work = best
			c.commute = bd
			work_load[best] = work_load.get(best, 0) + 1
	pop = citizens.size()
	employed = 0
	for c in citizens:
		if c.work >= 0 and c.sick <= 0.0:
			employed += 1
		c.fast = cov_at(cell(c.home), "transit") > 0.5
		c.car = c.work >= 0 and c.commute > 9 and not c.fast
	var open_other := 0
	for p in partners:
		open_other += int(maxi(int(p.jobs) - int(p.employed), 0) * Diplo.tmult(self, p))
	commuters_in = mini(pop - employed, int(open_other * 0.4))
	employed += commuters_in

	var cs := 0.0
	var cn := 0
	for c in citizens:
		if c.work >= 0:
			cs += c.commute
			cn += 1
	avg_commute = cs / maxf(cn, 1)
	var ss := 0.0
	var shops: Array[int] = []
	for i in works:
		if grid[i] == T.COM:
			shops.append(i)
	for h in homes:
		var best := 40
		var hc := cell(h)
		for sidx in shops:
			var sc := cell(sidx)
			best = mini(best, absi(sc.x - hc.x) + absi(sc.y - hc.y))
		ss += best
	avg_shop = ss / maxf(homes.size(), 1) if not homes.is_empty() else 0.0
	var market := sig.get_f("market")
	unemp = 0.0 if pop == 0 else 1.0 - float(employed) / pop
	shop_gap = clampf(1.0 - shop_jobs / maxf(pop * 0.5, 3.0), 0.0, 1.0)
	var target := 0.72 - shop_gap * 0.15 - minf(burning * 0.03, 0.2) - (tax_r - 0.10) * 2.0 - unemp * 0.3
	target += sig.get_f("news") * 0.3 - float(WEATHER_PENALTY.get(sig.weather(), 0.0))
	for m in Catalog.METRICS:
		var M: Dictionary = Catalog.METRICS[m]
		if String(M["kind"]) == "need":
			target -= float(M["w"]) * _need(m)
		elif String(M["kind"]) == "bonus":
			target += float(M["w"]) * float(cov[m])
	_sickness()
	_traffic()
	target -= 0.08 * congestion + 0.25 * float(sick_n) / maxf(pop, 1)
	if pop >= 40 and float(flow.get("food_local", 1.0)) < 0.3:
		target -= 0.03
	target -= 0.15 * pollution + 0.25 * maxf(crime - 0.1, 0.0) + 0.1 * clampf((avg_commute - 12.0) / 30.0, 0.0, 1.0) + 0.04 * clampf((avg_shop - 8.0) / 20.0, 0.0, 1.0)
	target += mod("mood")
	mood = move_toward(mood, clampf(target, 0.0, 1.0), 0.05)
	protest = mood < 0.2
	for c in citizens:
		c.mood = clampf(mood + c.bias - (0.15 if c.work < 0 else 0.0) - (0.08 if c.commute > 28 else 0.0), 0.0, 1.0)
		c.protesting = protest and c.mood < 0.35

	var tc := (tax_c - 0.10) * 4.0
	var ti := (tax_i - 0.10) * 4.0
	res_dem = clampf((jobs + 4.0 - housing) / 8.0 + (mood - 0.5) + mod("dem_res"), -1.0, 1.0)
	com_dem = clampf((pop * 0.5 + 2.0 - shop_jobs) / 6.0 + market * 0.2 - tc + mod("dem_com"), -1.0, 1.0)
	ind_dem = clampf((pop * 0.9 + 2.0 - jobs) / 6.0 + market * 0.2 - ti + mod("dem_ind"), -1.0, 1.0)
	off_dem = clampf((pop * 0.25 - off_jobs) / 6.0 * (0.4 + 0.6 * float(cov["edu"])) - tc + mod("dem_off"), -1.0, 1.0)

	if mood > 0.35 and pop < housing:
		for i in (2 if res_dem > 0.5 else 1):
			if rng.randf() < mod("immig_mult") / 1.0 * 0.9:
				_spawn()
	elif mood < 0.2 and pop > 0:
		citizens.remove_at(rng.randi() % citizens.size())
		msg = "A family packs up and leaves."
	pop = citizens.size()
	_grow()
	plan_t += 1
	if plan_t >= 8:
		plan_t = 0
		_planner()
	_money(market)
	for l in loans.duplicate():
		l["left"] = float(l["left"]) - float(l["pay"])
		if float(l["left"]) <= 0.0:
			loans.erase(l)
			_log("%s repaid." % l["n"])
	_unlocks()
	if human:
		_civics()
		_milestones()
	_sync_buses()

	hist_t += 1
	if hist_t >= 2:
		hist_t = 0
		hist_coins.append(coins)
		hist_pop.append(float(pop))
		if hist_coins.size() > 90:
			hist_coins.pop_front()
			hist_pop.pop_front()


func _money(market: float) -> void:
	var econ := 1.0 + 0.5 * market
	var prodm := (1.0 - 0.2 * _need("health")) * (1.0 - 0.25 * _need("power")) * (1.0 - 0.15 * _need("water")) * mod("prod_mult")
	var wise := 1.0 + 0.3 * float(cov["edu"])
	var fin := (1.0 + 0.12 * float(cov["finance"])) * mod("tax_mult")
	var f := (0.5 if protest else 1.0) * RATE
	var emp := float(employed) / maxf(jobs, 1)
	var laf_c := (tax_c / 0.10) * (1.0 - maxf(0.0, tax_c - 0.10) * 3.0)
	var laf_i := (tax_i / 0.10) * (1.0 - maxf(0.0, tax_i - 0.10) * 3.0)
	var r_tax := employed * tax_r * 12.0 * econ * prodm * wise * fin * f * res_mult * (0.75 + 0.5 * land_avg)
	var sales := minf(pop * 0.6, shop_jobs * 2.0) * (1.0 + 0.25 * float(cov["commerce"])) * mod("sales_mult") * (1.0 - 0.3 * clampf((avg_shop - 8.0) / 20.0, 0.0, 1.0))
	var r_com := sales * 0.8 * econ * prodm * laf_c * fin * f
	var goods := (fac_jobs * 0.6 * emp + farm_jobs * 0.3) * mod("goods_mult")
	var r_ind := goods * 1.2 * econ * prodm * wise * laf_i * fin * f
	var r_off := off_jobs * emp * 1.6 * econ * prodm * (0.5 + 0.5 * float(cov["edu"])) * mod("office_mult") * laf_c * fin * f
	var r_tour := tour_sum * 3.0 * econ * mood * mod("tour_mult") * f
	var mult := 1.0 + pop / 60.0  # size has a cost
	var um := mod("upkeep_mult")
	var e_roads := (roads * 0.08 + avenues * 0.12) * mult * um * RATE
	var e_zone := up_zone * mult * um * RATE
	var e_svc := up_svc * mult * um * RATE
	var e_pol := 0.0
	for k in policies:
		if policies[k]:
			e_pol += float(Catalog.POLICIES[k]["up"])
	e_pol *= RATE
	var e_staff := pop * 0.3 * RATE
	trade_net = 0.0
	for m in ["power", "water"]:
		trade_net -= float(imports[m]) * 0.4 * RATE
	for p in partners:
		for m in ["power", "water"]:
			trade_net += float(p.imports[m]) * 0.2 * RATE
	var e_crime := crime * pop * 0.3 * RATE
	var tr := _trade(market)
	var e_loan := 0.0
	for l in loans:
		e_loan += float(l["pay"])
	budget_lines = [
		["Residential tax", r_tax], ["Commercial tax", r_com], ["Industrial tax", r_ind], ["Office tax", r_off],
		["Tourism", r_tour], ["Events", mod("income_add") * RATE], ["Military funding", grant_sum * RATE * mod("grant_mult")], ["Regional trade", trade_net],
		["Roads", -e_roads], ["Buildings", -e_zone], ["Services", -e_svc], ["Policies", -e_pol],
		["City staff", -e_staff], ["Crime losses", -e_crime],
		["Exports", tr[0]], ["Imports (food, goods)", -tr[1]], ["Loan repayments", -e_loan],
	]
	income = 0.0
	for l in budget_lines:
		income += float(l[1])
	inc_tax = r_tax + r_com + r_ind + r_off


func _unlocks() -> void:
	for id in Catalog.DEFS:
		var u := float(Catalog.DEFS[id]["unlock"])
		if u > 0.0 and peak >= u and not announced.has(id):
			announced[id] = true
			msg = "Unlocked: %s" % Catalog.DEFS[id]["n"]
			_log("Unlocked: %s" % Catalog.DEFS[id]["n"])


# ---------- growth ----------

func dem_for(t: int) -> float:
	match String(Catalog.DEFS[t]["sector"]):
		"res":
			return res_dem
		"com":
			return com_dem
		"ind":
			return ind_dem
		"office":
			return off_dem
		"farm":
			return ind_dem * 0.5 + 0.1 + (0.3 * (1.0 - float(flow.get("food_local", 1.0))) if bt.has(T.MILL) else 0.0)
	return 0.0


func _grow() -> void:
	var empties: Array[int] = []
	var scale := (1.0 + blds / 15.0) * mod("build_cost_mult")
	for i in cells:
		var t := grid[i]
		if not is_zone(t) or connected[i] == 0:
			continue
		var dd: float = dem_for(t)
		if lvl[i] == 0:
			if build[i] > 0.0:
				build[i] += maxf(mod("build_mult"), 1.0) / BUILD_SECS
				if build[i] >= 1.0:
					build[i] = 0.0
					lvl[i] = 1
					msg = "A new %s opened." % String(Catalog.DEFS[t]["n"]).to_lower().replace(" zone", "")
			else:
				empties.append(i)
		elif lvl[i] < int(Catalog.DEFS[t]["max"]) and dd > 0.15 and mood > 0.45 and coins > GROW_COST * scale * 4.0 + saving_for and rng.randf() < 0.08:
			lvl[i] += 1
			coins -= GROW_COST * scale * 1.6
			msg = "A building was upgraded."
	empties.shuffle()
	var starts := 0
	for i in empties:
		var cost := GROW_COST * scale * (float(Catalog.DEFS[grid[i]]["cost"]) / 15.0)
		var hold := 0.0 if (int(Catalog.DEFS[grid[i]]["home"]) > 0 and res_dem > 0.3) else saving_for * 0.7  # homes pay for themselves
		if starts >= 3 or coins < cost + 40.0 + hold:
			continue
		coins -= cost
		build[i] = 0.01
		starts += 1


## City planners: when needs arise the city lays plots, and new streets, by itself.
func _planner() -> void:
	if auto_policy:
		_plan_policy()
	if auto_mode == 0 or coins < 60.0:
		return
	if _plan_net():
		return
	if congestion > 0.25 and unlocked(T.AVENUE) and rng.randf() < 0.3 and _plan_traffic():
		return
	if rng.randf() < 0.6 and _plan_service():
		return
	if coins < saving_for:
		return
	if mood < 0.38:
		return
	var open := 0
	for i in cells:
		if is_zone(grid[i]) and lvl[i] == 0:
			open += 1
	if open >= 3 + pop / 80:
		return
	var kinds: Array[int] = []
	var ws: Array[float] = []
	var total := 0.0
	for t in [T.RES, T.APT, T.COM, T.IND, T.OFFICE, T.FARM]:
		if not unlocked(t):
			continue
		var dd := dem_for(t)
		if t == T.APT and (res_dem < 0.3 or pop < housing * 0.9):
			continue
		if dd < -0.2:
			continue
		var wgt := maxf(dd, 0.0) * 3.0 + 0.5
		if t == T.FARM and bt.has(T.MILL):
			wgt += (1.0 - float(flow.get("food_local", 1.0))) * 0.8
		kinds.append(t)
		ws.append(wgt)
		total += wgt
	if kinds.is_empty():
		return
	var r := rng.randf() * total
	var t: int = kinds[kinds.size() - 1]
	for k in kinds.size():
		r -= ws[k]
		if r <= 0.0:
			t = kinds[k]
			break
	var cand: Array[int] = []
	for i in cells:
		if grid[i] == T.EMPTY and water[i] == 0 and _road_next_to(i) >= 0:
			cand.append(i)
	if auto_mode == 2 and (cand.size() < 6 or (roads + avenues < 14 + pop * 0.6 and rng.randf() < 0.25)):
		if _extend_road():
			return
		if cand.size() < 6 and auto_expand and _expand_auto():
			return
	if cand.is_empty():
		return
	cand.shuffle()
	var bi := -1
	var bs := -1e9
	for k in mini(16, cand.size()):
		var sc := _site_score(t, cand[k])
		if sc > bs:
			bs = sc
			bi = cand[k]
	if t == T.RES:
		t = _style_for(bi)
	grid[bi] = t
	msg = "Planners zoned a new %s plot." % String(Catalog.DEFS[t]["n"]).to_lower().replace(" zone", "")
	_scan()


## Picks the service building that best fixes an uncovered need (or adds a bonus), and sites it.
func _plan_service() -> bool:
	if homes.is_empty():
		return false
	var best := -1
	var bsc := 0.2
	for id in Catalog.DEFS:
		var d: Dictionary = Catalog.DEFS[id]
		if String(d["kind"]) != "svc" or not unlocked(id):
			continue
		var newup := float(d["up"]) * (1.0 + pop / 60.0) * mod("upkeep_mult") * RATE
		var have: int = (bt.get(id, []) as Array).size()
		var prov: Dictionary = d.get("prov", {})
		var ch: String = d.get("chain", "")
		var lim: int = 4 + pop / 25 if d.has("out") else 1 + pop / (60 if not prov.is_empty() else 150)
		if ch == "mill":
			lim = 1 + farm_jobs / 30
		if have >= lim:
			continue
		if d.get("water", false):
			continue  # ports and naval yards are placed by the player
		var sc := 0.0
		if ch == "mill" and farm_jobs > 0 and float(flow.get("food_local", 1.0)) < 0.7:
			sc += 0.9
		if ch == "store":
			for sk in stock:
				if float(stock[sk]) >= cap * 0.9:
					sc += 0.6
					break
		if ch == "trade" and pop >= 60 and float(flow.get("export", 0.0)) > 0.2:
			sc += 0.5
		var out: Dictionary = d.get("out", {})
		for mk in out:
			if pop >= int(need_pop.get(mk, 0)):
				sc += 1.0 if float(net_sup[mk]) <= 0.0 else clampf((float(net_dem[mk]) - float(net_sup[mk])) / maxf(float(net_dem[mk]), 1.0) * 2.0, 0.0, 1.0)
		for mk in prov:
			var M: Dictionary = Catalog.METRICS[mk]
			var gap: float = 1.0 - float(cov.get(mk, 0.0))
			if mk == "light" or mk == "justice":
				gap *= clampf(crime * 2.0, 0.0, 1.0)
			if String(M["kind"]) == "bonus":
				sc += gap * 0.25 * float(prov[mk])
			elif pop >= int(need_pop.get(mk, 0)):
				sc += gap * float(prov[mk])
		if id == T.FIRE and (burned > 0 or burning > 0) and float(cov["fire"]) < 0.6:
			sc += 0.8
		if coins > 800.0:
			sc += 0.15
		if d.has("grant") and coins > 1000.0 and income > 3.0 and pop >= 150:
			sc += 0.3
		var fk: String = d.get("faction", "")
		if fk != "" and float(tribe_mood.get(fk, 1.0)) < 0.5 and float(tribe_share.get(fk, 0.0)) > 0.1:
			sc += 0.6
		if d.has("tour") and mood > 0.5:
			sc += 0.15
		if d.has("poll"):
			sc -= 0.1
		if income - newup < (0.15 if sc < 0.6 else -0.25) and coins < 600.0:
			continue
		sc = sc / (float(d["cost"]) / 100.0 + 0.5) + rng.randf() * 0.05
		if sc > bsc:
			bsc = sc
			best = id
	saving_for = 0.0
	if best < 0:
		return false
	var d: Dictionary = Catalog.DEFS[best]
	if coins < float(d["cost"]) * 1.5 + 60.0:
		saving_for = float(d["cost"]) * 1.5 + 60.0
		return false
	var r := int(d.get("r", 0))
	var prov: Dictionary = d.get("prov", {})
	var cand: Array[int] = []
	for i in cells:
		if best == T.LIGHT:
			if is_road(grid[i]) and lamp[i] == 0 and not _lamp_near(i, 3):
				cand.append(i)
		elif grid[i] == T.EMPTY and water[i] == 0 and _road_next_to(i) >= 0:
			cand.append(i)
	if cand.is_empty():
		return false
	cand.shuffle()
	var bi := -1
	var bs := -1e9
	for k in mini(24, cand.size()):
		var c := cell(cand[k])
		var sc := rng.randf() * 0.5
		for h in homes:
			var hc := cell(h)
			var dist := absi(hc.x - c.x) + absi(hc.y - c.y)
			if d.has("poll") and dist <= int(d["poll"][0]):
				sc -= 0.6
			if dist <= r:
				for mk in prov:
					if raw_cov(hc, mk) < 0.5:
						sc += 1.0
		if sc > bs:
			bs = sc
			bi = cand[k]
	if bi < 0 or (bs < 0.5 and not prov.is_empty()):
		return false
	if best == T.LIGHT:
		lamp[bi] = 1
	else:
		grid[bi] = best
	coins -= float(d["cost"])
	msg = "Planners built a %s." % String(d["n"]).to_lower()
	_scan()
	return true


## Runs power lines / water pipes along roads from the grid to the nearest unserved building.
func _plan_net() -> bool:
	if coins < 30.0:
		return false
	var ms := NETS.duplicate()
	ms.shuffle()
	for m in ms:
		if float(net_sup[m]) <= 0.0 and not _has_plant(m):
			continue
		var val: PackedFloat32Array = net_val[m]
		var reach: PackedByteArray = net_reach[m]
		var cand: Array[int] = []
		for hb in homes + works:
			if val[hb] == 0.0 and not is_road(grid[hb]) and pop >= int(need_pop.get(m, 0)) - 10:
				cand.append(hb)
		if cand.is_empty():
			continue
		var b: int = cand[rng.randi() % cand.size()]
		var goals := {}
		for id in bt:
			if Catalog.DEFS[id].get("out", {}).has(m):
				for p in bt[id]:
					for j in _near(p):
						if is_road(grid[j]):
							goals[j] = true
		var s := _road_next_to(b)
		if s < 0:
			continue
		var prev := {s: -1}
		var q: Array[int] = [s]
		var end := -1
		while not q.is_empty() and end < 0:
			var cur: int = q.pop_front()
			if reach[cur] == 1 or goals.has(cur):
				end = cur
				break
			for d in DIRS:
				var n: Vector2i = cell(cur) + d
				if inside(n.x, n.y):
					var ni := n.y * W + n.x
					if is_road(grid[ni]) and not prev.has(ni):
						prev[ni] = cur
						q.append(ni)
		if end < 0:
			continue
		var laid := 0
		var w := end
		while w >= 0 and coins >= 2.0 and laid < 30:
			if _nl(m)[w] == 0:
				_lay(m, w, 1)
				coins -= 2.0
				laid += 1
			w = int(prev[w])
		if laid > 0:
			msg = "Planners laid %s." % {"power": "power lines", "water": "water pipes", "sewage": "sewers"}[m]
			_scan()
			return true
	return false


func _has_plant(m: String) -> bool:
	for id in bt:
		if Catalog.DEFS[id].get("out", {}).has(m):
			return true
	return false


## Auto-policies: flips policies on when the city needs them and off again with hysteresis.
func _plan_policy() -> void:
	var c: Dictionary = cov
	var rules := {
		"watch": [pop >= 30 and float(c["police"]) < 0.5, float(c["police"]) > 0.8],
		"recycling": [pop >= int(need_pop["waste"]) and float(c["waste"]) < 0.5 and coins > 150.0, float(c["waste"]) > 0.8 or coins < 60.0],
		"transit_free": [pop >= 60 and float(c["transit"]) < 0.4 and coins > 400.0 and income > 1.0, income < 0.2],
		"free_school": [pop >= 50 and float(c["edu"]) < 0.5 and coins > 400.0 and income > 1.0, float(c["edu"]) > 0.8 or income < 0.2],
		"clean_air": [pollution > 0.35 and mood < 0.55, pollution < 0.15],
		"austerity": [coins < 60.0 and income < 0.0, coins > 250.0],
		"curfew": [protest and float(c["police"]) < 0.5, not protest],
		"fast_track": [res_dem > 0.5 and coins > 300.0, res_dem < 0.1 or coins < 100.0],
		"stop_search": [crime > 0.5 and float(c["police"]) > 0.5 and mood > 0.45, crime < 0.25 or mood < 0.35],
		"community_police": [pop >= 60 and crime > 0.3 and coins > 300.0 and income > 1.0, crime < 0.15 or income < 0.2],
		"tourism": [tour_sum > 2.0 and coins > 200.0, coins < 100.0 or tour_sum <= 0.0],
		"biz_subsidy": [com_dem < -0.1 and coins > 200.0, com_dem > 0.1 or coins < 100.0],
	}
	for k in rules:
		var on: bool = bool(policies.get(k, false))
		if not on and rules[k][0]:
			set_policy(k, true)
			_log("Council enabled: %s" % Catalog.POLICIES[k]["n"])
			return
		if on and rules[k][1]:
			set_policy(k, false)
			_log("Council ended: %s" % Catalog.POLICIES[k]["n"])
			return


## Land value 0..1 per block: services and parks raise it, pollution and crime lower it.
func _land() -> void:
	var tot := 0.0
	var n := 0
	land_val.fill(0.45)
	for i in cells:
		if grid[i] == T.EMPTY and not _touch(i):
			continue
		var c := cell(i)
		var v := 0.5 + 0.12 * cov_at(c, "leisure") + 0.08 * cov_at(c, "edu") + 0.08 * cov_at(c, "health") + 0.06 * cov_at(c, "culture") + 0.06 * cov_at(c, "transit")
		v += 0.04 * cov_at(c, "power") + 0.04 * cov_at(c, "water") - 0.6 * poll_at(c) - 0.2 * crime + mood * 0.1
		if grid[i] != T.EMPTY and not is_road(grid[i]):
			v -= float(Catalog.DEFS[grid[i]].get("crime", 0.0)) * 0.5
		land_val[i] = clampf(v, 0.0, 1.0)
		if is_zone(grid[i]) and lvl[i] > 0 and int(Catalog.DEFS[grid[i]]["home"]) > 0:
			tot += land_val[i]
			n += 1
	land_avg = tot / n if n > 0 else 0.5


func _touch(i: int) -> bool:
	var x := i % W
	var y := i / W
	return grid[i] != T.EMPTY or (x > 0 and grid[i - 1] != T.EMPTY) or (x < W - 1 and grid[i + 1] != T.EMPTY) or (y > 0 and grid[i - W] != T.EMPTY) or (y < H - 1 and grid[i + W] != T.EMPTY)


## Picks a housing style for a new residential plot from the block's land value.
func _style_for(i: int) -> int:
	var lv: float = land_val[i]
	var opts: Array[int] = [T.RES]
	if lv > 0.5 and unlocked(T.COTTAGE):
		opts.append(T.COTTAGE)
		opts.append(T.COTTAGE)
	if lv > 0.42 and unlocked(T.TOWNHOUSE) and pop >= 40:
		opts.append(T.TOWNHOUSE)
	if lv > 0.68 and unlocked(T.CONDO) and pop >= 120:
		opts.append(T.CONDO)
		opts.append(T.CONDO)
	if lv < 0.5 and res_dem > 0.5 and unlocked(T.TENEMENT):
		opts.append(T.TENEMENT)
	return opts[rng.randi() % opts.size()]


func _site_score(t: int, i: int) -> float:
	var c := cell(i)
	var s := rng.randf() * 0.6
	var nh := 99.0
	for h in homes:
		var hc := cell(h)
		nh = minf(nh, float(absi(hc.x - c.x) + absi(hc.y - c.y)))
	match t:
		T.RES, T.APT:
			s -= poll_at(c) * 3.0
			s += cov_at(c, "leisure") + cov_at(c, "health") * 0.5 + cov_at(c, "edu") * 0.5 + cov_at(c, "transit") * 0.5
		T.COM, T.OFFICE:
			s += 2.0 - minf(nh, 10.0) * 0.2 + cov_at(c, "transit") * 0.5
		T.IND, T.FARM:
			s += minf(nh, 12.0) * 0.25
	return s


## Extends a street outward from a road that has open land beyond it. Returns true if it built.
func _extend_road() -> bool:
	if coins < 40.0:
		return false
	var fr: Array = []
	for i in cells:
		if not is_road(grid[i]):
			continue
		var c := cell(i)
		for d in DIRS:
			var n1: Vector2i = c + d
			var n2: Vector2i = c + d * 2
			if not terr.grow(-2).has_point(n1) or not terr.has_point(n2):
				continue
			if grid[n1.y * W + n1.x] == T.EMPTY and grid[n2.y * W + n2.x] == T.EMPTY:
				var perp := Vector2i(d.y, d.x)
				if not is_road(at(n1.x + perp.x, n1.y + perp.y)) and not is_road(at(n1.x - perp.x, n1.y - perp.y)):
					fr.append([c, d])
	if fr.is_empty():
		return false
	var pick: Array = fr[rng.randi() % fr.size()]
	var c0: Vector2i = pick[0]
	var dir: Vector2i = pick[1]
	var perp := Vector2i(dir.y, dir.x)
	var built := 0
	for k in range(1, rng.randi_range(3, 6) + 1):
		var p := c0 + dir * k
		if not terr.grow(-2).has_point(p) or grid[p.y * W + p.x] != T.EMPTY or water[p.y * W + p.x] == 1:
			break
		if k > 1 and (is_road(at(p.x + perp.x, p.y + perp.y)) or is_road(at(p.x - perp.x, p.y - perp.y))):
			break
		if coins < 5.0:
			break
		grid[p.y * W + p.x] = T.ROAD
		coins -= 5.0
		built += 1
	if built == 0:
		return false
	roads_dirty = true
	msg = "City planners laid a new street."
	_scan()
	return true


# ---------- fire ----------

func burnable(i: int) -> bool:
	var t := grid[i]
	if t == T.EMPTY or is_road(t):
		return false
	if is_zone(t):
		return lvl[i] > 0
	return t != T.PARK and t != T.PLAYGROUND and t != T.PLAZA and t != T.WIND and t != T.SOLAR


func covered(i: int) -> bool:
	return raw_cov(cell(i), "fire") > 0.0


func _clear_burn(i: int) -> void:
	burn[i] = 0.0
	flames.erase(i)


func _light(i: int) -> void:
	if burn[i] <= 0.0:
		burn[i] = 0.01
		flames.append(i)


## Sets a random building alight. Returns a headline ("" if nothing to burn).
func ignite() -> String:
	var opts: Array[int] = []
	for i in _burnables():
		if burn[i] <= 0.0:
			opts.append(i)
	if opts.is_empty():
		return ""
	_light(opts[rng.randi() % opts.size()])
	return "Fire! A building is ablaze. Build a fire station, or bulldoze a firebreak."


func _fires(dt: float) -> void:
	next_fire -= dt
	if next_fire <= 0.0:
		next_fire = rng.randf_range(60.0, 110.0) / (1.0 + blds / 80.0) / maxf(mod("fire_mult"), 0.2) / clampf(blds / 14.0, 0.2, 1.0)  # tiny towns rarely burn
		msg = ignite()
	burning = 0
	var wet := sig.weather() == "rain" or sig.weather() == "storm"
	for i in flames.duplicate():
		if not burnable(i):
			_clear_burn(i)
			continue
		burn[i] += dt
		if (covered(i) and burn[i] > 3.0) or (wet and burn[i] > 9.0):
			_clear_burn(i)
		elif burn[i] > 14.0:
			_ruin(i, false)
			msg = "A building burned to the ground."
			sounds.append("bad")
			_scan()
		else:
			burning += 1
			if rng.randf() < dt * 0.12:
				var n := cell(i) + DIRS[rng.randi() % 4]
				if inside(n.x, n.y) and burnable(n.y * W + n.x):
					_light(n.y * W + n.x)


# ---------- citizens ----------

func _fav(c: Citizen) -> int:
	if c.fav_day != day:
		c.fav = -1
		c.fav_day = day
	if c.fav >= 0 and connected[c.fav] == 1 and grid[c.fav] != T.EMPTY and (not is_zone(grid[c.fav]) or lvl[c.fav] > 0):
		return c.fav
	c.fav = spots[rng.randi() % spots.size()] if not spots.is_empty() else -1
	return c.fav


func _want(c: Citizen) -> int:
	var h := clock - c.shift
	if protest and c.protesting and h >= 9.0 and h < 20.0 and plaza >= 0:
		return plaza
	if c.sick > 0.0:
		return c.home
	var f := _fav(c)
	var out: int = f if f >= 0 else c.home
	if day % 7 >= 5 or c.work < 0:  # weekend or jobless: errands
		if (h >= 10.0 and h < 13.0) or (h >= 15.0 and h < 19.0):
			return out
		return c.home
	if h >= 7.5 and h < 16.0:
		return c.work
	if h >= 16.0 and h < 19.0 and (c.id + day) % 3 != 0:  # some go straight home
		return out
	return c.home


func _label(c: Citizen, i: int) -> String:
	if i == c.home:
		return "home"
	if i == c.work:
		return "work"
	if grid[i] == T.EMPTY:
		return "somewhere"
	if is_road(grid[i]):
		return "the square"
	return "the " + String(Catalog.DEFS[grid[i]]["n"]).to_lower().replace(" zone", "")


func _route(c: Citizen, want: int) -> bool:
	var a := _road_next_to(c.at) if c.at >= 0 else -1
	var b := _road_next_to(want)
	if a < 0 or b < 0:
		return false
	var ids := astar.get_id_path(cell(a), cell(b))
	if ids.is_empty():
		return false
	var pts := PackedVector2Array()
	pts.append(center(c.at))
	for p in ids:
		pts.append(Vector2(p) + Vector2(0.5, 0.5) + c.off)
	if not is_road(grid[want]):
		pts.append(center(want))
	c.path = pts
	c.pi = 1
	c.goal = want
	c.at = -1
	c.doing = "walking to " + _label(c, want)
	return true


func _move(dt: float) -> void:
	var sm := mod("speed_mult")
	for c in citizens:
		c.bubble_t = maxf(0.0, c.bubble_t - dt)
		c.retry = maxf(0.0, c.retry - dt)
		if c.path.size() > 0:
			var step := WALK * dt * c.spd * sm * (1.3 if c.fast else 1.0)
			var cx := floori(c.pos.x)
			var cy := floori(c.pos.y)
			if inside(cx, cy) and grid[cy * W + cx] == T.AVENUE:
				step *= 1.5
			if c.car and inside(cx, cy):
				var jam := maxf(0.0, traffic[cy * W + cx] - (8.0 if grid[cy * W + cx] == T.AVENUE else 3.0))
				step *= 2.2 / (1.0 + jam * 0.25)
			while step > 0.0 and c.pi < c.path.size():
				var d := c.path[c.pi] - c.pos
				var l := d.length()
				if l <= step:
					c.pos = c.path[c.pi]
					step -= l
					c.pi += 1
				else:
					c.pos += d / l * step
					step = 0.0
			if c.pi >= c.path.size():
				c.at = c.goal
				c.goal = -1
				c.path = PackedVector2Array()
				c.doing = "at " + _label(c, c.at)
			continue
		var want := _want(c)
		if want >= 0 and want != c.at and c.retry <= 0.0:
			if not _route(c, want):
				c.retry = 5.0
	for b in buses:
		var path: PackedVector2Array = b["path"]
		if path.is_empty():
			b["wait"] = float(b["wait"]) - dt
			if float(b["wait"]) <= 0.0:
				_bus_route(b)
			continue
		var step := WALK * 2.2 * dt * sm
		var pi: int = b["pi"]
		var pos: Vector2 = b["pos"]
		while step > 0.0 and pi < path.size():
			var d := path[pi] - pos
			var l := d.length()
			if l <= step:
				pos = path[pi]
				step -= l
				pi += 1
			else:
				b["dir"] = d / l
				pos += d / l * step
				step = 0.0
		b["pos"] = pos
		b["pi"] = pi
		if pi >= path.size():
			b["path"] = PackedVector2Array()
			b["wait"] = 2.0


func thought(c: Citizen) -> String:
	var hc := cell(c.home)
	for i in flames:
		var fc := cell(i)
		if absi(fc.x - hc.x) + absi(fc.y - hc.y) <= 4:
			return "Fire near my street!"
	if protest and c.protesting:
		return "Enough! Something has to change."
	if c.sick > 0.0:
		return ["I've caught that flu.", "Staying in bed today.", "Can someone fetch a doctor?"][c.id % 3]
	if c.car and congestion > 0.35 and rng.randf() < 0.5:
		return "Stuck in traffic again."
	if next_election - day <= 3 and rng.randf() < 0.4:
		return "I'm voting for the mayor." if approval > 0.5 else "Time for a new mayor."
	if broken > kept and rng.randf() < 0.3:
		return "The mayor never keeps a promise."
	if not active.is_empty() and rng.randf() < 0.35:
		var a: Dictionary = active[rng.randi() % active.size()]
		return String(WorldEvents.EVENTS[a["id"]]["say"])
	if rng.randf() < 0.3:
		var tl: Array = Catalog.TRIBE_LINES[c.tribe]
		return tl[rng.randi() % tl.size()]
	var pains: Array[String] = []
	for m in Catalog.METRICS:
		if _need(m) > 0.4:
			pains.append(String(Catalog.METRICS[m]["say"]))
	if pollution > 0.3:
		pains.append("The air round here stinks.")
	if not pains.is_empty() and rng.randf() < 0.6:
		return pains[rng.randi() % pains.size()]
	if c.work < 0:
		return "I can't find a job."
	if tax_r > 0.16:
		return "Taxes are crushing us."
	if shop_gap > 0.4:
		return "Nowhere to shop around here."
	if c.commute > 25:
		return "My commute takes forever."
	var w := sig.weather()
	if w == "storm" or w == "rain":
		return "Miserable weather today."
	if w == "heatwave":
		return "It's far too hot."
	if sig.get_f("news") < -0.4:
		return "Did you see the headlines?"
	if sig.get_f("news") > 0.4:
		return "Heard some good news today."
	if c.mood > 0.65:
		return ["Nice day for a walk.", "Can't complain.", "Good to live here."][rng.randi() % 3]
	return "Same as always."


func _murmur() -> void:
	murmur_t = rng.randf_range(5.0, 11.0)
	if citizens.is_empty():
		return
	var c := citizens[rng.randi() % citizens.size()]
	c.bubble = thought(c)
	c.bubble_t = 5.0
	murmurs.push_front("%02d:%02d  %s (%s): %s" % [int(clock), int((clock - floorf(clock)) * 60.0), c.nm, String(Catalog.TRIBES[c.tribe]["n"]).split(" ")[0].to_lower(), c.bubble])
	if murmurs.size() > 20:
		murmurs.pop_back()


func needs() -> Array[String]:
	var n: Array[String] = []
	if burning > 0:
		n.append("%d building(s) on fire%s" % [burning, "" if cov["fire"] > 0.0 else " - no fire station!"])
	if not twister.is_empty():
		n.append("TORNADO crossing the city!")
	if not offline.is_empty():
		n.append("%d power plant(s) offline" % offline.size())
	if sick_n > 0:
		n.append("%d citizens sick. Clinics cure them faster." % sick_n)
	if not petitions.is_empty():
		n.append("%d decision(s) waiting in the Mayor's office" % petitions.size())
	if next_election - day <= 5:
		n.append("Election in %d day(s): polling %d%%" % [next_election - day, int(approval * 100.0)])
	if congestion > 0.3:
		n.append("Traffic jams (%d%%). Avenues and buses help." % int(congestion * 100.0))
	if pop >= 30 and float(flow.get("food_local", 1.0)) < 0.4:
		n.append("Most food is imported. Farms + a food mill save money.")
	if protest:
		n.append("Protest in the streets!")
	if pop - employed >= 2:
		n.append("%d citizens without work" % (pop - employed))
	for m in Catalog.METRICS:
		if _need(m) > 0.3:
			n.append("%s covers only %d%% of homes" % [Catalog.METRICS[m]["n"], int(float(cov[m]) * 100.0)])
	if avg_commute > 22.0:
		n.append("Commutes are long (avg %d tiles). Build homes near jobs or avenues." % int(avg_commute))
	if avg_shop > 14.0:
		n.append("Shops are far from homes (avg %d tiles)" % int(avg_shop))
	if crime > 0.35:
		n.append("Crime is high (%d%% of blocks affected)" % int(crime * 100.0))
	if pollution > 0.2:
		n.append("Pollution is bothering %d%% of residents" % int(pollution * 100.0))
	if res_dem > 0.3:
		n.append("Homes in demand")
	if com_dem > 0.3:
		n.append("Shops in demand")
	if ind_dem > 0.3:
		n.append("Jobs in demand (Industrial)")
	var waiting := 0
	var off := 0
	for i in cells:
		if is_zone(grid[i]) and lvl[i] == 0 and connected[i] == 1 and build[i] <= 0.0:
			waiting += 1
		if grid[i] != T.EMPTY and not is_road(grid[i]) and connected[i] == 0:
			off += 1
	if waiting > 0:
		n.append("%d plot(s) waiting for funds" % waiting)
	if off > 0:
		n.append("%d plot(s) have no road access" % off)
	if coins < 40.0:
		n.append("Funds are low")
	if n.is_empty():
		n.append("All quiet. Plan the next district.")
	return n


func goal_text() -> String:
	var nxt := 1 << 30
	var names: Array[String] = []
	for id in Catalog.DEFS:
		var u := int(Catalog.DEFS[id]["unlock"])
		if u > peak and u < nxt:
			nxt = u
	if nxt < (1 << 30):
		for id in Catalog.DEFS:
			if int(Catalog.DEFS[id]["unlock"]) == nxt:
				names.append(String(Catalog.DEFS[id]["n"]))
		return "Reach pop %d to unlock: %s  (best so far %d)" % [nxt, ", ".join(names), int(peak)]
	for m in [300, 500, 800, 1200]:
		if peak < m:
			return "Grow to pop %d  (best so far %d)" % [m, int(peak)]
	return "A true metropolis. Keep it alive."


func tick(dt: float) -> void:
	if over != "":
		return
	clock += dt * 24.0 / DAY_SECS
	if clock >= 24.0:
		clock -= 24.0
		day += 1
		_new_day()
	if roads_dirty:
		_rebuild_astar()
	acc += dt
	if acc >= 1.0:
		acc -= 1.0
		_second()
	_fires(dt)
	if not twister.is_empty():
		_twister(dt)
	_move(dt)
	murmur_t -= dt
	if murmur_t <= 0.0:
		_murmur()
	ev_t -= dt
	if ev_t <= 0.0:
		ev_t = rng.randf_range(35.0, 75.0) * ev_scale
		var ids: Array[String] = []
		for a in active:
			ids.append(String(a["id"]))
		var id := WorldEvents.pick(rng, pop, ids, recent, day, bt, Civics.SEASONS[season]["ev"])
		if id != "":
			trigger(id)
	var expired := false
	for a in active:
		a["left"] = float(a["left"]) - dt
		if float(a["left"]) <= 0.0:
			expired = true
	if expired:
		var keep: Array[Dictionary] = []
		for a in active:
			if float(a["left"]) > 0.0:
				keep.append(a)
			else:
				_log("%s ended." % WorldEvents.EVENTS[a["id"]]["n"])
		active = keep
		_collect_mods()
	coins += (income) * dt
	peak = maxf(peak, float(pop))
	if not human:
		coins = maxf(coins, 30.0)  # neighbours are kept alive by the state
	elif coins < DEBT_LIMIT:
		over = "Bankrupt. The city could not pay its bills."
	elif peak >= 10.0 and pop < 1:
		over = "Everyone left. The city is empty."


# ---------- mayor: petitions, promises, approval, elections ----------

func _met(n: Dictionary, have := 0) -> bool:
	if n.has("build"):
		return (bt.get(int(n["build"]), []) as Array).size() > have
	if n.has("cov"):
		return float(cov.get(n["cov"][0], 0.0)) >= float(n["cov"][1])
	if n.has("tax"):
		return float(get("tax_" + String(n["tax"][0]))) <= float(n["tax"][1]) + 0.001
	if n.has("policy"):
		return is_policy(n["policy"])
	if n.has("policy_off"):
		return not is_policy(n["policy_off"])
	if n.has("unemp"):
		return unemp <= float(n["unemp"])
	if n.has("event"):
		return is_active(n["event"])
	return false


func _open_ids() -> Dictionary:
	var o := {}
	for p in petitions + promises:
		o[String(p.get("id", ""))] = true
	return o


func _raise_petition() -> void:
	if not human or pop < 12 or petitions.size() >= 3:
		return
	var open := _open_ids()
	var opts: Array = []
	for p in Civics.PETITIONS:
		var id: String = p["id"]
		var n: Dictionary = p["need"]
		if open.has(id) or day - int(pet_recent.get(id, -99)) < 6 or pop < int(p.get("minpop", 15)):
			continue
		if float(tribe_share.get(p["tribe"], 0.0)) < 0.05 or crime < float(p.get("crime", 0.0)) or pollution < float(p.get("poll", 0.0)):
			continue
		if n.has("build"):
			if not unlocked(int(n["build"])) or (bt.get(int(n["build"]), []) as Array).size() >= 1 + pop / 100:
				continue
		elif _met(n):
			continue
		if n.has("event") and mood > 0.55:
			continue
		opts.append(p)
	if opts.is_empty():
		return
	var p: Dictionary = opts[rng.randi() % opts.size()].duplicate(true)
	p["kind"] = "petition"
	p["expires"] = day + 2
	pet_recent[p["id"]] = day
	petitions.append(p)
	pet_ver += 1
	msg = "Petition from the %s: %s" % [Catalog.TRIBES[p["tribe"]]["n"], p["t"]]
	_log(msg)
	sounds.append("petition")


## Answers decision idx. yes = accept the petition / fund the rebuild.
func answer(idx: int, yes: bool) -> void:
	if idx < 0 or idx >= petitions.size():
		return
	var p: Dictionary = petitions[idx]
	petitions.remove_at(idx)
	pet_ver += 1
	if p["kind"] == "offer" or p["kind"] == "demand":
		Diplo.resolve(self, p, yes)
		return
	if p["kind"] == "recover":
		disasters_survived += 1
		if yes and coins >= float(p["cost"]):
			coins -= float(p["cost"])
			_rebuild()
			rep += 0.04
			_log("You funded the rebuild ($%d)." % int(p["cost"]))
			msg = "Crews rebuild the damaged blocks overnight."
		else:
			ruins.clear()
			_log("The city will recover on its own.")
		return
	var tb: String = p["tribe"]
	if yes:
		p["deadline"] = day + int(p["days"])
		var n: Dictionary = p["need"]
		p["have"] = (bt.get(int(n["build"]), []) as Array).size() if n.has("build") else 0
		promises.append(p)
		favor[tb] = float(favor.get(tb, 0.0)) + 0.05
		_log("You promised the %s: %s (by day %d)." % [Catalog.TRIBES[tb]["n"], Civics.need_text(n), p["deadline"]])
	else:
		favor[tb] = float(favor.get(tb, 0.0)) - 0.12
		rep -= 0.02
		_log("You turned down the %s." % Catalog.TRIBES[tb]["n"])


func _civics() -> void:
	for p in promises.duplicate():
		var tb: String = p["tribe"]
		if _met(p["need"], int(p.get("have", 0))):
			promises.erase(p)
			kept += 1
			favor[tb] = float(favor.get(tb, 0.0)) + 0.2
			rep += 0.06
			msg = "Promise kept: %s. The %s cheer." % [p["t"], Catalog.TRIBES[tb]["n"]]
			_log(msg)
			sounds.append("good")
			pet_ver += 1
		elif day > int(p["deadline"]):
			promises.erase(p)
			broken += 1
			favor[tb] = float(favor.get(tb, 0.0)) - 0.3
			rep -= 0.1
			msg = "Promise broken: %s. The %s are furious." % [p["t"], Catalog.TRIBES[tb]["n"]]
			_log(msg)
			sounds.append("bad")
			pet_ver += 1
	for p in petitions.duplicate():
		if day > int(p["expires"]):
			answer(petitions.find(p), false)
	pet_t -= 1.0
	if pet_t <= 0.0:
		pet_t = rng.randf_range(70.0, 130.0)
		_raise_petition()
	for k in favor:
		favor[k] = clampf(move_toward(float(favor[k]), 0.0, 0.0008), -0.4, 0.4)
	rep = clampf(move_toward(rep, 0.0, 0.0004), -0.3, 0.3)
	var op := 0.0
	for k in tribe_mood:
		op += float(tribe_share.get(k, 0.0)) * (float(tribe_mood[k]) - 0.5)
	var target := 0.35 + 0.5 * mood + 0.08 * clampf(income / 2.0, -1.0, 1.0) - (0.1 if coins < 0.0 else 0.0) - 0.1 * crime + 0.3 * op + rep
	if tax_r > 0.12:
		target -= (tax_r - 0.12) * 1.5
	target -= 0.04 * wars() + 0.012 * minf(war_battles(), 12.0)  # war weariness
	approval = clampf(move_toward(approval, target, 0.004), 0.0, 1.0)


func rally() -> bool:
	if rally_used or coins < Civics.RALLY_COST or next_election - day > 7:
		return false
	coins -= Civics.RALLY_COST
	rally_used = true
	rep += 0.07
	_log("Campaign rally in the square.")
	msg = "Your rally fills the square. Approval rises."
	return true


func _new_day() -> void:
	if next_election - day == 3:
		msg = "Election in 3 days. Polls put you at %d%%." % int(approval * 100.0)
		_log(msg)
	if day < next_election or not human:
		return
	var vote := clampf(approval + rng.randf_range(-0.04, 0.04), 0.0, 1.0)
	last_vote = vote
	next_election += Civics.YEAR_DAYS
	rally_used = false
	if vote >= 0.5:
		elections_won += 1
		msg = "Re-elected with %d%% of the vote!" % int(vote * 100.0)
		_log(msg)
		sounds.append("chime")
	else:
		_log("Lost the election with %d%%." % int(vote * 100.0))
		over = "Voted out. You won only %d%% of the vote on day %d." % [int(vote * 100.0), day]


func _milestones() -> void:
	for ms in Civics.MILESTONES:
		if not done_ms.has(ms["id"]) and float(get(ms["stat"])) >= float(ms["v"]):
			done_ms[ms["id"]] = day
			coins += float(ms["reward"])
			msg = "Milestone: %s%s" % [ms["n"], ("  (+$%d)" % ms["reward"]) if int(ms["reward"]) > 0 else ""]
			_log(msg)
			sounds.append("chime")


func take_loan(k: int) -> bool:
	var L: Dictionary = Civics.LOANS[k]
	if loans.size() >= 3 or peak < float(L["minpop"]):
		return false
	var total := float(L["amt"]) * (1.0 + float(L["rate"]))
	loans.append({"n": L["n"], "left": total, "pay": total / (float(L["days"]) * DAY_SECS)})
	coins += float(L["amt"])
	_log("Took a %s: $%d, repay $%d over %d days." % [String(L["n"]).to_lower(), L["amt"], int(total), L["days"]])
	return true


## Advisors: [name, advice, happy]
func advisors() -> Array:
	var a: Array = []
	var t := "Income is %+.2f a second. Keep taxes near 10%% unless we need the money." % income
	if income < -0.2:
		t = "We're losing $%.2f a second. Raise taxes, end a policy or take a loan." % -income
	elif coins > 1500.0:
		t = "We're sitting on $%d. Spend it on services, or cut taxes to win votes." % int(coins)
	elif not loans.is_empty():
		var pay := 0.0
		for l in loans:
			pay += float(l["pay"])
		t = "We're repaying %d loan(s) at $%.2f a second. No new borrowing, please." % [loans.size(), pay]
	a.append(["Treasurer", t, income >= 0.0])
	t = "The streets are calm and the fire crews are bored."
	if burning > 0:
		t = "%d building(s) on fire! Fire stations within 7 tiles put fires out in seconds." % burning
	elif crime > 0.3:
		t = "Crime is at %d%%. Street lamps, police stations and courts in the red blocks (Crime overlay)." % int(crime * 100.0)
	elif float(cov["fire"]) < 0.6 and pop > 30:
		t = "Only %d%% of homes have fire cover. One spark and we lose a street." % int(float(cov["fire"]) * 100.0)
	a.append(["Police & fire chief", t, burning == 0 and crime <= 0.3])
	t = "Growth is steady. Demand: homes %+d, shops %+d, industry %+d." % [int(res_dem * 10), int(com_dem * 10), int(ind_dem * 10)]
	if congestion > 0.3:
		t = "Traffic is jammed (%d%%). Upgrade busy roads to avenues and add bus stops." % int(congestion * 100.0)
	elif avg_commute > 18.0:
		t = "Commutes average %d tiles. Zone jobs nearer homes, or add avenues." % int(avg_commute)
	elif pop - employed > 4:
		t = "%d people can't find work. Zone industry or offices." % (pop - employed)
	a.append(["City planner", t, congestion <= 0.3 and avg_commute <= 18.0])
	t = "People are healthy and fed."
	if sick_n > 0:
		t = "%d citizens are sick. Clinics and hospitals cure them faster and slow the spread." % sick_n
	elif pop >= 30 and float(flow.get("food_local", 1.0)) < 0.4:
		t = "We import most of our food. Farms plus a food mill would save money."
	else:
		for m in Catalog.METRICS:
			if _need(m) > 0.3:
				t = "%s reaches only %d%% of homes. That is hurting mood." % [Catalog.METRICS[m]["n"], int(float(cov[m]) * 100.0)]
				break
	a.append(["Health & welfare", t, sick_n == 0])
	var dl := next_election - day
	t = "Election in %d days. We poll at %d%%." % [dl, int(approval * 100.0)]
	if approval < 0.5:
		t += " We'd lose today! Keep promises, lift mood%s." % (", hold a rally" if dl <= 7 and not rally_used else "")
	elif tax_r > 0.12:
		t += " Voters hate the household tax. Cut it."
	if not petitions.is_empty():
		t += " %d petition(s) await your answer." % petitions.size()
	a.append(["Campaign manager", t, approval >= 0.5])
	if wars() > 0:
		a.append(["General", "We are at war (%d battles so far). Voters are tiring: mood and approval fall the longer it lasts. Win it, or sue for peace after 3 battles. The Garrison policy and barracks cut raid damage and win battles." % int(war_battles()), false])
	return a


# ---------- disasters ----------

func _offer_recovery(cause: String) -> void:
	if ruins.size() < 2:
		return
	var cost := 20.0 * ruins.size()
	for p in petitions:
		if p["kind"] == "recover":
			p["cost"] = cost
			p["txt"] = "%d buildings lost or damaged. Fund a fast rebuild for $%d, or let the city recover on its own (zones regrow slowly; destroyed services are gone)." % [ruins.size(), int(cost)]
			pet_ver += 1
			return
	petitions.append({"kind": "recover", "id": "recover", "tribe": "", "t": "Rebuild after the " + cause,
		"txt": "%d buildings lost or damaged. Fund a fast rebuild for $%d, or let the city recover on its own (zones regrow slowly; destroyed services are gone)." % [ruins.size(), int(cost)],
		"cost": cost, "expires": day + 2})
	pet_ver += 1
	sounds.append("bad")


func _rebuild() -> void:
	for r in ruins:
		var i: int = r[0]
		var t: int = r[1]
		if grid[i] == T.EMPTY:
			grid[i] = t
			if is_road(t):
				roads_dirty = true
		if grid[i] == t and is_zone(t):
			lvl[i] = maxi(lvl[i], int(r[2]))
			build[i] = 0.0
	ruins.clear()
	_scan()


func _twister(dt: float) -> void:
	var p: Vector2 = twister["pos"]
	var v: Vector2 = twister["vel"]
	v = v.rotated(rng.randf_range(-0.6, 0.6) * dt)
	p += v * dt
	twister["pos"] = p
	twister["vel"] = v
	var c := Vector2i(p.floor())
	if not inside(c.x, c.y):
		twister = {}
		_scan()
		_offer_recovery("tornado")
		return
	var ci := c.y * W + c.x
	if ci == int(twister["last"]):
		return
	twister["last"] = ci
	for j in _near(ci):
		if burnable(j) and rng.randf() < (0.8 if j == ci else 0.3):
			_ruin(j)
		if rng.randf() < 0.5:
			wire[j] = 0
			pipe[j] = 0
			sewer[j] = 0
	_scan()


func _sickness() -> void:
	sick_n = 0
	var hot := {}
	for c in citizens:
		if c.sick > 0.0:
			sick_n += 1
			hot[c.home] = true
			if c.work >= 0:
				hot[c.work] = true
	if sick_n == 0:
		return
	var gone: Array[Citizen] = []
	for c in citizens:
		var h := cov_at(cell(c.home), "health")
		if c.sick > 0.0:
			c.sick -= 1.0 + 2.0 * h
			if rng.randf() < 0.002 * (1.0 - h):
				gone.append(c)
		elif (hot.has(c.home) or (c.work >= 0 and hot.has(c.work))) and rng.randf() < 0.03 * (1.0 - 0.7 * h):
			c.sick = rng.randf_range(20.0, 35.0)
	for c in gone:
		citizens.erase(c)
		msg = "%s did not survive the illness." % c.nm
		_log(msg)


## Cars leave a trail on each road cell they cross; jams form where it piles up.
func _traffic() -> void:
	drivers = 0
	for i in cells:
		traffic[i] *= 0.7
	for c in citizens:
		if c.car and c.path.size() > 0:
			var q := Vector2i(c.pos.floor())
			if inside(q.x, q.y):
				traffic[q.y * W + q.x] += 1.0
				drivers += 1
	var cs := 0.0
	var n := 0
	for i in cells:
		if traffic[i] > 0.3:
			n += 1
			cs += clampf((traffic[i] - (8.0 if grid[i] == T.AVENUE else 3.0)) / 4.0, 0.0, 1.0)
	congestion = cs / maxf(n, 1)


## Upgrades the busiest plain road (and up to 3 neighbours in line) to an avenue.
func _plan_traffic() -> bool:
	var best := -1
	var bv := 3.0
	for i in cells:
		if grid[i] == T.ROAD and traffic[i] > bv:
			bv = traffic[i]
			best = i
	if best < 0:
		return false
	var c := cell(best)
	var axis := Vector2i(1, 0) if is_road(at(c.x + 1, c.y)) or is_road(at(c.x - 1, c.y)) else Vector2i(0, 1)
	var n := 0
	for k in range(-2, 3):
		var q := c + axis * k
		if inside(q.x, q.y) and grid[q.y * W + q.x] == T.ROAD and coins >= 7.0:
			grid[q.y * W + q.x] = T.AVENUE
			coins -= 7.0
			n += 1
	roads_dirty = true
	msg = "Planners widened a jammed street into an avenue."
	_scan()
	return n > 0


func _sync_buses() -> void:
	var stops: Array = bt.get(T.BUS, [])
	var keep: Array = []
	for b in buses:
		if stops.has(b["stop"]):
			keep.append(b)
	buses = keep
	for s in stops:
		var has := false
		for b in buses:
			if b["stop"] == s:
				has = true
		var r := _road_next_to(s)
		if not has and r >= 0:
			buses.append({"stop": s, "pos": center(r), "path": PackedVector2Array(), "pi": 0, "wait": 1.0, "out": false, "dir": Vector2.RIGHT})


func _bus_route(b: Dictionary) -> void:
	var goal: int = b["stop"]
	if not b["out"]:
		var opts: Array = spots.duplicate()
		if plaza >= 0:
			opts.append(plaza)
		if opts.is_empty():
			b["wait"] = 5.0
			return
		goal = opts[rng.randi() % opts.size()]
	var gr := _road_next_to(goal)
	var p: Vector2 = b["pos"]
	var fr := Vector2i(p.floor())
	if gr < 0 or not inside(fr.x, fr.y) or not is_road(grid[fr.y * W + fr.x]):
		var r := _road_next_to(b["stop"])
		if r >= 0:
			b["pos"] = center(r)
		b["wait"] = 3.0
		return
	var ids := astar.get_id_path(fr, cell(gr))
	if ids.size() < 2:
		b["wait"] = 4.0
		b["out"] = not b["out"]
		return
	var pts := PackedVector2Array()
	for q in ids:
		pts.append(Vector2(q) + Vector2(0.5, 0.5))
	b["path"] = pts
	b["pi"] = 1
	b["out"] = not b["out"]


# ---------- economy: crops -> food, goods, storage, trade ----------

## Returns [export income, import cost] per second.
func _trade(market: float) -> Array:
	var emp := float(employed) / maxf(jobs, 1)
	var mills := (bt.get(T.MILL, []) as Array).size()
	var deps := (bt.get(T.DEPOT, []) as Array).size() + 2 * (bt.get(T.PORT, []) as Array).size()
	cap = 60.0 + 250.0 * (bt.get(T.WAREHOUSE, []) as Array).size()
	var crops := farm_jobs * emp * 0.12 * float(Civics.SEASONS[season]["harvest"])
	var milled := minf(float(stock["crops"]) + crops, mills * 3.0)
	var goods := fac_jobs * emp * 0.06 * mod("goods_mult")
	var fish := (bt.get(T.FISHDOCK, []) as Array).size() * 6.0 * emp * 0.15 * river_health
	stock["crops"] = float(stock["crops"]) + crops - milled
	stock["food"] = float(stock["food"]) + milled + fish
	stock["goods"] = float(stock["goods"]) + goods
	var fneed := pop * 0.05
	var gneed := pop * 0.03 + shop_jobs * 0.02
	var fl := minf(float(stock["food"]), fneed)
	var gl := minf(float(stock["goods"]), gneed)
	stock["food"] = float(stock["food"]) - fl
	stock["goods"] = float(stock["goods"]) - gl
	var price := 1.0 + 0.3 * market
	var imp := ((fneed - fl) * 1.5 + (gneed - gl) * 2.0) * RATE * price
	var ex := 0.0
	var sold := 0.0
	var xp := price * 0.8 * (1.0 + 0.25 * deps)
	for k in stock:
		var lim := cap * (0.2 if deps > 0 else 0.8)
		if float(stock[k]) > lim:
			var sell := (float(stock[k]) - lim) * (0.25 if deps > 0 else 0.5)
			ex += sell * float({"crops": 0.6, "food": 1.5, "goods": 2.0}[k]) * RATE * xp
			stock[k] = float(stock[k]) - sell
			sold += sell
		stock[k] = minf(float(stock[k]), cap)
	exported += sold
	flow = {"crops": crops, "food": milled + fish, "goods": goods, "food_need": fneed, "goods_need": gneed,
		"food_local": fl / fneed if fneed > 0.0 else 1.0, "goods_local": gl / gneed if gneed > 0.0 else 1.0,
		"export": sold, "price": price, "imp": imp, "ex": ex}
	return [ex, imp]


# ---------- save / load ----------

func to_dict() -> Dictionary:
	var cs: Array = []
	for c in citizens:
		cs.append([c.id, c.home, c.work, c.tribe, c.nm, c.bias, c.shift, c.spd, c.commute, c.sick])
	var d := {"v": 1, "cit": cs}
	for k in ["town_name", "grid", "lvl", "build", "wire", "pipe", "sewer", "lamp", "water", "coins", "mood", "tax_r", "tax_c", "tax_i", "clock", "day",
			"policies", "auto_mode", "auto_policy", "peak", "announced", "next_id", "recent", "active", "approval", "rep", "favor",
			"petitions", "promises", "pet_recent", "kept", "broken", "next_election", "elections_won", "rally_used", "last_vote",
			"season", "stock", "exported", "loans", "done_ms", "disasters_survived", "burned", "hist_coins", "hist_pop", "ruins", "offline", "lamp", "terr", "expansions", "auto_expand", "human", "temper", "rel", "treaty", "ev_scale", "gpos", "war_n", "war_sc"]:
		d[k] = get(k)
	return d


func from_dict(d: Dictionary) -> void:
	if not d.has("water"):
		water.fill(0)  # saves from before rivers
	for k in d:
		if k == "cit" or k == "v":
			continue
		var cur: Variant = get(k)
		if cur is Array:
			(cur as Array).assign(d[k])
		else:
			set(k, d[k])
	citizens.clear()
	for a in d.get("cit", []):
		var c := Citizen.new()
		c.id = a[0]
		c.home = a[1]
		c.work = a[2]
		c.tribe = a[3]
		c.nm = a[4]
		c.bias = a[5]
		c.shift = a[6]
		c.spd = a[7]
		c.commute = a[8]
		c.sick = a[9]
		c.at = c.home
		c.pos = center(c.home)
		c.off = Vector2(rng.randf_range(-0.14, 0.14), rng.randf_range(-0.14, 0.14))
		citizens.append(c)
	pop = citizens.size()
	_rebuild_cells()
	roads_dirty = true
	_rebuild_astar()
	_collect_mods()
	_scan()
	pet_ver += 1


## One runnable check: returns "SELFCHECK_OK" or "SELFCHECK_FAIL: ...".
static func selfcheck() -> String:
	var errs: Array[String] = []

	var a := City.new(Signals.new())
	a.next_fire = 9999.0
	a.ev_t = 9999.0
	a.auto_mode = 0
	a.water[(OY + 6) * W + OX + 6] = 1
	if a.place(OX + 6, OY + 6, T.RES):
		errs.append("zoned on water")
	a.water[(OY + 6) * W + OX + 6] = 0
	a.water.fill(0)
	a.place(OX + 5, OY + 5, T.RES)
	for i in 100:
		a.tick(0.1)
	if a.lvl[(OY + 5) * W + OX + 5] != 0:
		errs.append("grew without road")
	a.place(OX + 5, OY + 6, T.ROAD)
	for i in 900:
		a.tick(0.1)
	if a.lvl[(OY + 5) * W + OX + 5] == 0:
		errs.append("zone never grew")

	var d := City.new(Signals.new())
	d.seed_start()
	d.next_fire = 9999.0
	d.ev_t = 9999.0
	d.auto_mode = 0
	var walked := false
	var bad_path := false
	for i in 1200:
		d.tick(0.1)
		for c in d.citizens:
			if c.path.size() > 0:
				walked = true
				for k in range(1, c.path.size() - 1):
					var q := Vector2i(c.path[k].floor())
					if not d.is_road(d.grid[q.y * W + q.x]):
						bad_path = true
	if not walked:
		errs.append("nobody walked")
	if bad_path:
		errs.append("citizen left the road")
	if is_nan(d.coins) or d.pop < 1 or d.pop > d.housing:
		errs.append("start city unstable pop=%s housing=%s" % [d.pop, d.housing])

	var g := City.new(Signals.new())
	g.seed_start()
	g.next_fire = 9999.0
	g.ev_t = 9999.0
	g.auto_mode = 0
	g._light(sidx(20, 15))
	for i in 200:
		g.tick(0.1)
	if g.burned == 0:
		errs.append("unattended fire must destroy")
	var h := City.new(Signals.new())
	h.seed_start()
	h.next_fire = 9999.0
	h.ev_t = 9999.0
	h.auto_mode = 0
	h.grid[sidx(18, 15)] = T.FIRE
	h._scan()
	h._light(sidx(20, 15))
	for i in 100:
		h.tick(0.1)
	if h.burned > 0:
		errs.append("station must save house")

	var j := City.new(Signals.new())
	j.coins = -200.0
	j.tick(0.1)
	if j.over == "":
		errs.append("bankruptcy must end game")

	var l := City.new(Signals.new())
	l.coins = 999.0
	if l.place(OX + 3, OY + 3, T.POLICE):
		errs.append("police must be locked at start")

	var ev := City.new(Signals.new())
	ev.seed_start()
	ev.next_fire = 9999.0
	ev.ev_t = 9999.0
	ev.coins = 100.0
	ev.trigger("festival")
	if ev.coins > 61.0 or ev.mod("mood") < 0.19:
		errs.append("festival must cost coins and lift mood")
	ev.trigger("boom")
	if ev.sig.get_f("market") < 0.5:
		errs.append("boom must raise market")

	var pl := City.new(Signals.new())
	pl.seed_start()
	pl.next_fire = 9999.0
	pl.ev_t = 9999.0
	pl.auto_mode = 2
	pl.coins = 2000.0
	var zones0 := 0
	for i in 3000:
		pl.tick(0.1)
	var zones1 := 0
	for i in W * H:
		if pl.is_zone(pl.grid[i]):
			zones1 += 1
	if zones1 < 8 or pl.roads < 14:
		errs.append("planner did not grow city zones=%d roads=%d" % [zones1, pl.roads])

	var s2 := Signals.new()
	var e := City.new(s2)
	e.seed_start()
	e.next_fire = 9999.0
	e.ev_t = 9999.0
	e.auto_mode = 0
	e.tick(1.0)
	var base := e.inc_tax
	s2.bump("market", -1.0)
	e.tick(1.0)
	if e.inc_tax >= base:
		errs.append("crash must lower income")

	var s3 := Signals.new()
	var f := City.new(s3)
	f.seed_start()
	f.next_fire = 9999.0
	f.ev_t = 9999.0
	f.auto_mode = 0
	f.coins = 1000.0
	f.tax_r = 0.3
	s3.set_weather("storm", 999.0)
	s3.bump("news", -1.0)
	for i in 600:
		f.tick(0.1)
	if not f.protest:
		errs.append("expected protest")

	var sv := City.new(Signals.new())
	sv.seed_start()
	sv.coins = 777.0
	sv.policies["watch"] = true
	var rt := City.new(Signals.new())
	rt.from_dict(sv.to_dict())
	if rt.coins != 777.0 or rt.citizens.size() != sv.citizens.size() or rt.grid != sv.grid or not rt.is_policy("watch"):
		errs.append("save/load roundtrip")
	var pt := City.new(Signals.new())
	pt.seed_start()
	pt.petitions.append({"kind": "petition", "id": "tax_r", "tribe": "rebels", "t": "x", "need": {"tax": ["r", 0.08]}, "days": 2, "expires": 9})
	pt.answer(0, true)
	pt.tax_r = 0.05
	pt._civics()
	if pt.kept != 1:
		errs.append("kept promise not counted")
	var tw := City.new(Signals.new())
	tw.seed_start()
	tw.coins = 5000.0
	tw.twister = {"pos": Vector2(18.5 + OX, 15.5 + OY), "vel": Vector2(3.0, 0.0), "last": -1}
	tw.rng.seed = 1
	for i in 200:
		if tw.twister.is_empty():
			break
		tw._twister(0.1)
	if tw.burned == 0 or not tw.twister.is_empty():
		errs.append("tornado must destroy and leave")
	return "SELFCHECK_OK" if errs.is_empty() else "SELFCHECK_FAIL: " + ", ".join(errs)
