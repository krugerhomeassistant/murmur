class_name Military
extends RefCounted
## Real armies. Towns train units from barracks and bases, deploy them to the front when at war, and the units fight
## with hit points, range and damage. A war ends when one side's army is gone and the other holds its border.
## Geometry: units at war have a world position `p` (pixels) and heading `h`; see docs/WAR_DESIGN.md. line() still gives the
## edge-to-edge axis between two towns, used to spawn units on the side facing the enemy.
## Every unit type lives in KIND: `t` is what it counts as when shot at (soft/armor/air), `vs` its damage multiplier
## against each of those, `cap` how many each building houses, `radar` that air capacity is also limited by radar posts.

const T = Catalog.Id
const TILE := 32.0
const KIND := {
	"inf": {"n": "Rifleman", "t": "soft", "hp": 75.0, "dmg": 2.4, "rng": 110.0, "spd": 9.0, "cost": 25.0, "upk": 0.02, "train": 8.0, "cap": {T.BARRACKS: 6, T.BASE: 4}, "vs": {"soft": 1.0, "armor": 0.25, "air": 0.15, "ship": 0.1}},
	"gren": {"n": "Grenadier", "t": "soft", "hp": 80.0, "dmg": 3.2, "rng": 90.0, "spd": 8.0, "cost": 40.0, "upk": 0.03, "train": 12.0, "cap": {T.BARRACKS: 2, T.BASE: 2}, "vs": {"soft": 0.8, "armor": 1.8, "air": 0.0, "ship": 0.3}},
	"snip": {"n": "Sniper", "t": "soft", "hp": 45.0, "dmg": 5.5, "rng": 330.0, "spd": 8.0, "cost": 50.0, "upk": 0.03, "train": 16.0, "cap": {T.BARRACKS: 2}, "vs": {"soft": 1.6, "armor": 0.1, "air": 0.2, "ship": 0.1}},
	"medic": {"n": "Medic", "t": "soft", "hp": 60.0, "dmg": 0.0, "rng": 110.0, "spd": 9.0, "cost": 40.0, "upk": 0.03, "train": 14.0, "cap": {T.BARRACKS: 1, T.BASE: 1}, "vs": {}, "heal": 2.5},
	"ltank": {"n": "Light tank", "t": "armor", "hp": 220.0, "dmg": 4.5, "rng": 220.0, "spd": 22.0, "cost": 100.0, "upk": 0.05, "train": 22.0, "cap": {T.BASE: 3}, "vs": {"soft": 1.4, "armor": 0.8, "air": 0.0, "ship": 0.3}},
	"tank": {"n": "Battle tank", "t": "armor", "hp": 350.0, "dmg": 6.5, "rng": 240.0, "spd": 14.0, "cost": 140.0, "upk": 0.08, "train": 35.0, "cap": {T.BASE: 3}, "vs": {"soft": 1.6, "armor": 1.0, "air": 0.0, "ship": 0.5}},
	"htank": {"n": "Heavy tank", "t": "armor", "hp": 650.0, "dmg": 8.5, "rng": 250.0, "spd": 9.0, "cost": 260.0, "upk": 0.14, "train": 60.0, "cap": {T.BASE: 1}, "vs": {"soft": 1.5, "armor": 1.3, "air": 0.0, "ship": 0.6}},
	"art": {"n": "Artillery", "t": "armor", "hp": 120.0, "dmg": 12.0, "rng": 600.0, "spd": 8.0, "cost": 200.0, "upk": 0.09, "train": 40.0, "cap": {T.BASE: 2}, "vs": {"soft": 1.5, "armor": 0.9, "air": 0.0, "ship": 1.0}},
	"aa": {"n": "Anti-air", "t": "armor", "hp": 140.0, "dmg": 5.0, "rng": 380.0, "spd": 10.0, "cost": 150.0, "upk": 0.07, "train": 28.0, "cap": {T.BASE: 1}, "vs": {"soft": 0.3, "armor": 0.2, "air": 3.0, "ship": 0.0}},
	"jet": {"n": "Strike jet", "t": "air", "hp": 150.0, "dmg": 9.0, "rng": 200.0, "spd": 45.0, "cost": 220.0, "upk": 0.12, "train": 50.0, "cap": {T.BASE: 2}, "radar": true, "vs": {"soft": 1.2, "armor": 1.5, "air": 0.8, "ship": 1.2}},
	"fighter": {"n": "Fighter", "t": "air", "hp": 120.0, "dmg": 6.0, "rng": 220.0, "spd": 55.0, "cost": 200.0, "upk": 0.1, "train": 45.0, "cap": {T.BASE: 2}, "radar": true, "vs": {"soft": 0.5, "armor": 0.4, "air": 2.2, "ship": 0.5}},
	"bomber": {"n": "Bomber", "t": "air", "hp": 220.0, "dmg": 10.0, "rng": 140.0, "spd": 38.0, "cost": 300.0, "upk": 0.16, "train": 65.0, "cap": {T.BASE: 1}, "radar": true, "vs": {"soft": 1.3, "armor": 1.8, "air": 0.0, "ship": 2.0}},
	"heli": {"n": "Helicopter", "t": "air", "hp": 160.0, "dmg": 7.0, "rng": 190.0, "spd": 30.0, "cost": 240.0, "upk": 0.13, "train": 50.0, "cap": {T.BASE: 1}, "vs": {"soft": 1.4, "armor": 1.6, "air": 0.3, "ship": 1.0}},
	"patrol": {"n": "Patrol boat", "t": "ship", "hp": 160.0, "dmg": 4.0, "rng": 200.0, "spd": 28.0, "cost": 120.0, "upk": 0.06, "train": 25.0, "cap": {T.NAVYARD: 3}, "vs": {"soft": 1.0, "armor": 0.5, "air": 0.3, "ship": 1.0}},
	"destroyer": {"n": "Destroyer", "t": "ship", "hp": 520.0, "dmg": 8.0, "rng": 320.0, "spd": 16.0, "cost": 320.0, "upk": 0.15, "train": 60.0, "cap": {T.NAVYARD: 2}, "vs": {"soft": 1.3, "armor": 1.0, "air": 1.0, "ship": 1.4}},
	"transport": {"n": "Transport", "t": "ship", "hp": 400.0, "dmg": 0.0, "rng": 100.0, "spd": 12.0, "cost": 200.0, "upk": 0.08, "train": 40.0, "cap": {T.NAVYARD: 1}, "vs": {}, "lands": 6},
}
const DEF_W := {"inf": 2, "gren": 1, "snip": 1, "medic": 1, "ltank": 1, "tank": 2, "htank": 1, "art": 1, "aa": 1, "jet": 1, "fighter": 1, "bomber": 1, "heli": 1, "patrol": 1, "destroyer": 1, "transport": 1}
const RANKS := ["Recruit", "Veteran", "Elite", "Legend"]
const RANK_XP := [250.0, 800.0, 2000.0]  # damage dealt (or healed) to reach rank 1, 2, 3
const RANK_DMG := 0.15  # per rank
const RANK_HP := 0.10
const ARMY_MAX := 150  # per town: training stops here (upkeep, and fights cost O(n^2))
const INF_D := 1 << 29
const BUILD_GAP_MS := 30  # at most one flow-field build per this many ms
const AGGRO := 520.0  # px: foes closer than this (or 1.5x weapon range) are chased instead of marching on
const FIELD_TTL := 3000  # fight calls a cached flow field lives at most; terrain_changed() (bridges built or removed) clears it at once
const TCLS := {"soft": 0, "armor": 1, "air": 2, "ship": 3}
static var _vsv := {}  # kind -> damage multipliers as a flat array indexed by target class, for the fight inner loop
static var booms: Array = []  # runtime only: explosions for the war visuals
static var reg := {}  # gpos -> City, every town (Diplo.second keeps it current): terrain lookups for units on the move
static var _ff := {}  # cached flow fields
static var _clock := 0  # counts fight() calls, the cache's idea of time
static var _last_build := 0  # ms of the last flow-field build: builds are spread out so a war's start is not one long frame
static var blasts: Array = []  # runtime only: buildings hit by raids and bombers {t: town, p: town-space pixel, ts: ms}


static func origin(c: City) -> Vector2:
	return Vector2(c.gpos) * Vector2(City.W, City.H) * TILE


## World-space ends of the front between two towns: edge to edge for neighbours, centre to centre otherwise.
static func line(a: City, b: City) -> PackedVector2Array:
	var ca := Vector2(a.terr.get_center())
	var cb := Vector2(b.terr.get_center())
	var p0 := origin(a) + ca * TILE
	var p1 := origin(b) + cb * TILE
	match Diplo.side(a, b):
		0:
			p0 = origin(a) + Vector2(ca.x, a.terr.position.y) * TILE
			p1 = origin(b) + Vector2(cb.x, b.terr.end.y) * TILE
		1:
			p0 = origin(a) + Vector2(a.terr.end.x, ca.y) * TILE
			p1 = origin(b) + Vector2(b.terr.position.x, cb.y) * TILE
		2:
			p0 = origin(a) + Vector2(ca.x, a.terr.end.y) * TILE
			p1 = origin(b) + Vector2(cb.x, b.terr.position.y) * TILE
		3:
			p0 = origin(a) + Vector2(a.terr.position.x, ca.y) * TILE
			p1 = origin(b) + Vector2(b.terr.end.x, cb.y) * TILE
	return PackedVector2Array([p0, p1])


## Ships can only fight where a river runs across the border between two neighbours (water on both edges).
static func river(a: City, b: City) -> bool:
	var d := Diplo.side(a, b)
	return d >= 0 and _wet_edge(a, d) and _wet_edge(b, (d + 2) % 4)


static func _wet_edge(c: City, d: int) -> bool:
	var r := c.terr
	var xs := range(r.position.x, r.end.x) if d % 2 == 0 else [r.end.x - 1 if d == 1 else r.position.x]
	var ys := range(r.position.y, r.end.y) if d % 2 == 1 else [r.position.y if d == 0 else r.end.y - 1]
	for y in ys:
		for x in xs:
			if c.water[y * City.W + x] == 1:
				return true
	return false


static func caps(c: City) -> Dictionary:
	var rd := (c.bt.get(T.RADAR, []) as Array).size()
	var r := {}
	for k in KIND:
		var n := 0
		for id in KIND[k]["cap"]:
			n += int(KIND[k]["cap"][id]) * (c.bt.get(id, []) as Array).size()
		r[k] = mini(n, 2 * rd) if KIND[k].get("radar", false) else n
	return r


static func counts(c: City) -> Dictionary:
	var n := {}
	for k in KIND:
		n[k] = 0
	for u in c.army:
		n[u["k"]] += 1
	return n


static func weights(c: City) -> Dictionary:
	var w := DEF_W.duplicate()
	for k in c.train_w:
		if w.has(k):
			w[k] = int(c.train_w[k])
	return w


## Military strength used by the AI and by tribute demands.
static func power(c: City) -> float:
	var p := 0.0
	for u in c.army:
		p += float(KIND[u["k"]]["cost"]) * 0.0012 * (1.0 + 0.1 * int(u.get("rk", 0)))
	return p


static func summary(c: City) -> String:
	var n := counts(c)
	var k := caps(c)
	var parts: PackedStringArray = []
	var room := 0
	for id in KIND:
		room += int(k[id])
		if int(n[id]) > 0:
			parts.append("%d %s" % [n[id], String(KIND[id]["n"]).to_lower()])
	return "%d units%s (room for %d)" % [c.army.size(), (": " + ", ".join(parts)) if not parts.is_empty() else "", room]


## Planner towns train what counters the enemy: sums the target classes of every unit a hostile neighbour has and bumps the weights of types that beat the big ones.
static func adapt(c: City) -> void:
	var tot := {"soft": 0, "armor": 0, "air": 0, "ship": 0}
	var n := 0
	for p in c.partners:
		if Diplo.treaty(c, p) == "war" or (Diplo.treaty(c, p) == "" and Diplo.rel(c, p) < -0.2):
			for u in p.army:
				tot[KIND[u["k"]]["t"]] += 1
				n += 1
	var w := DEF_W.duplicate()
	if n >= 3:
		var up := {"air": ["aa", "fighter"], "armor": ["gren", "art", "heli", "bomber", "htank"], "soft": ["tank", "snip", "art", "ltank", "bomber"], "ship": ["destroyer", "patrol", "bomber", "art"]}
		for cl in up:
			if float(tot[cl]) / n >= 0.25:
				for k in up[cl]:
					w[k] = mini(int(w[k]) + (2 if float(tot[cl]) / n >= 0.5 else 1), 3)
	c.train_w = w


static func rank(u: Dictionary) -> int:
	return int(u.get("rk", 0))


static func max_hp(u: Dictionary) -> float:
	return float(u.get("mx", KIND[u["k"]]["hp"]))


static func _unit(k: String, hp_scale := 1.0) -> Dictionary:
	var h := float(KIND[k]["hp"]) * hp_scale
	return {"k": k, "hp": h, "mx": h, "xp": 0.0, "rk": 0, "tgt": "", "l": randf_range(-1.0, 1.0)}


static func _gain(u: Dictionary, xp: float) -> void:
	u["xp"] = float(u.get("xp", 0.0)) + xp
	while rank(u) < 3 and float(u["xp"]) >= float(RANK_XP[rank(u)]):
		var m0 := max_hp(u)
		u["rk"] = rank(u) + 1
		u["mx"] = m0 * (1.0 + RANK_HP * 1.0 / (1.0 + RANK_HP * (rank(u) - 1)))
		u["hp"] = float(u["hp"]) + float(u["mx"]) - m0


## A declaration of war calls up a militia so even a town with no barracks fields something.
static func conscript(c: City) -> void:
	for i in clampi(c.pop / 15, 3, 12):
		c.army.append(_unit("inf", 0.7))


## Once per sim second per town: pay upkeep, train, send units to the front (or home when peace comes).
static func econ(c: City) -> void:
	var up := 0.0
	for u in c.army:
		up += float(KIND[u["k"]]["upk"])
	c.coins -= up
	if c.coins < -50.0 and not c.army.is_empty():
		c.army.pop_back()  # unpaid troops desert
	if not c.human:
		c.train_t["_a"] = float(c.train_t.get("_a", 0.0)) + 1.0
		if float(c.train_t["_a"]) >= 10.0:
			c.train_t["_a"] = 0.0
			adapt(c)
	if c.train_on and c.army.size() < ARMY_MAX:
		var cap := caps(c)
		var cnt := counts(c)
		var w := weights(c)
		for k in KIND:
			if int(w[k]) > 0 and int(cnt[k]) < int(cap[k]) and c.coins >= float(KIND[k]["cost"]) * 3.0:
				c.train_t[k] = float(c.train_t.get(k, 0.0)) + 0.5 * int(w[k])  # priority 1 = half speed, 3 = 1.5x
				if float(c.train_t[k]) >= float(KIND[k]["train"]):
					c.train_t[k] = 0.0
					c.coins -= float(KIND[k]["cost"])
					c.army.append(_unit(k))
	var foes: Array = []
	for p in c.partners:
		if Diplo.treaty(c, p) == "war":
			foes.append(p)
	var i := 0
	for u in c.army:
		var ok: Array = foes.filter(func(p: City) -> bool: return KIND[u["k"]]["t"] != "ship" or river(c, p))  # ships only where a river joins the towns
		if ok.is_empty():
			u["tgt"] = ""
		elif not ok.any(func(p: City) -> bool: return p.town_name == u["tgt"]):
			u["tgt"] = (ok[i % ok.size()] as City).town_name
			i += 1
		if u["tgt"] == "":
			u.erase("p")  # peace: back home at once (phase 1, docs/WAR_DESIGN.md)


static func _row(k: String) -> PackedFloat32Array:
	if not _vsv.has(k):
		var v: Dictionary = KIND[k]["vs"]
		_vsv[k] = PackedFloat32Array([float(v.get("soft", 0.0)), float(v.get("armor", 0.0)), float(v.get("air", 0.0)), float(v.get("ship", 0.0))])
	return _vsv[k]


static func _of(c: City, foe: String) -> Array:
	var r: Array = []
	for u in c.army:
		if u["tgt"] == foe:
			r.append(u)
	return r


static func register(towns: Array) -> void:
	var same := reg.size() == towns.size()
	for c in towns:
		same = same and reg.get((c as City).gpos) == c
	if same:
		return
	reg.clear()
	for c in towns:
		reg[(c as City).gpos] = c
	_ff.clear()


## A bridge was built or removed (or a world loaded): cached flow fields are out of date.
static func terrain_changed() -> void:
	_ff.clear()


## World-space pixel rect of a town's territory.
static func terr_px(c: City) -> Rect2:
	return Rect2(origin(c) + Vector2(c.terr.position) * TILE, Vector2(c.terr.size) * TILE)


static func _cls(k: String) -> int:
	return int(TCLS[KIND[k]["t"]])


## Can a unit of class `cls` (0/1 ground, 3 ship) stand on this tile of town `c`? Ground: land or a road bridge. Ships: river without a bridge.
static func _tile_ok(c: City, i: int, cls: int) -> bool:
	if cls == 3:
		return c.water[i] == 1 and not c.is_road(c.grid[i])
	return c.water[i] == 0 or c.is_road(c.grid[i])


static func passable(p: Vector2, cls: int) -> bool:
	if cls == 2:
		return true
	var tx := floori(p.x / TILE)
	var ty := floori(p.y / TILE)
	var c: City = reg.get(Vector2i(floori(float(tx) / City.W), floori(float(ty) / City.H)))
	return c != null and _tile_ok(c, posmod(ty, City.H) * City.W + posmod(tx, City.W), cls)


## Nearest standable point to `p`, searching outwards in rings of tiles (for spawning and goals).
static func nearest_ok(p: Vector2, cls: int, max_r := 24) -> Vector2:
	if passable(p, cls):
		return p
	for r in range(1, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := p + Vector2(dx, dy) * TILE
				if passable(q, cls):
					return q
	return Vector2.INF


## Breadth-first distance field (in tiles) from `goal` over everything a class can stand on, across the towns spanned by a and b.
static func _field(a: City, b: City, goal: Vector2, cls: int) -> Dictionary:
	var g0 := Vector2i(mini(a.gpos.x, b.gpos.x), mini(a.gpos.y, b.gpos.y))
	var g1 := Vector2i(maxi(a.gpos.x, b.gpos.x), maxi(a.gpos.y, b.gpos.y))
	var key := "%d,%d,%d,%d,%d,%d,%d" % [g0.x, g0.y, g1.x, g1.y, cls, int(goal.x / TILE), int(goal.y / TILE)]
	var now := _clock
	var now_ms := Time.get_ticks_msec()
	if _ff.has(key) and now - int((_ff[key] as Dictionary)["ts"]) < FIELD_TTL:
		return _ff[key]
	if now_ms - _last_build < (BUILD_GAP_MS if DisplayServer.get_name() != "headless" else 0):
		return {"ok": false}  # not built yet: units slide straight for a moment
	_last_build = now_ms
	var rw := (g1.x - g0.x + 1) * City.W
	var rh := (g1.y - g0.y + 1) * City.H
	var ox := g0.x * City.W
	var oy := g0.y * City.H
	var walk := PackedByteArray()
	walk.resize(rw * rh)
	for gy in range(g0.y, g1.y + 1):
		for gx in range(g0.x, g1.x + 1):
			var c: City = reg.get(Vector2i(gx, gy))
			if c == null:
				continue
			for y in City.H:
				var row := ((gy - g0.y) * City.H + y) * rw + (gx - g0.x) * City.W
				for x in City.W:
					if _tile_ok(c, y * City.W + x, cls):
						walk[row + x] = 1
	var gx0 := clampi(floori(goal.x / TILE) - ox, 0, rw - 1)
	var gy0 := clampi(floori(goal.y / TILE) - oy, 0, rh - 1)
	var dist := PackedInt32Array()
	dist.resize(rw * rh)
	dist.fill(INF_D)
	var res := {"ts": now, "ox": ox, "oy": oy, "rw": rw, "rh": rh, "dist": dist, "walk": walk, "ok": false}
	var gi := gy0 * rw + gx0
	if walk[gi] == 0:  # goal not standable: take the nearest tile that is
		var best := -1
		var bd := 1 << 30
		for i in walk.size():
			if walk[i] == 1:
				var d := (i % rw - gx0) * (i % rw - gx0) + (i / rw - gy0) * (i / rw - gy0)
				if d < bd:
					bd = d
					best = i
		if best < 0:
			_ff[key] = res
			return res
		gi = best
	res["ok"] = true
	res["goal"] = (Vector2(gi % rw + ox, gi / rw + oy) + Vector2(0.5, 0.5)) * TILE
	dist[gi] = 0
	var q := PackedInt32Array([gi])
	var h := 0
	var dxs := [1, -1, 0, 0, 1, 1, -1, -1]
	var dys := [0, 0, 1, -1, 1, -1, 1, -1]
	while h < q.size():
		var i := q[h]
		h += 1
		var x := i % rw
		var y := i / rw
		var d := dist[i] + 1
		for k in 8:
			var nx: int = x + dxs[k]
			var ny: int = y + dys[k]
			if nx < 0 or ny < 0 or nx >= rw or ny >= rh:
				continue
			var ni := ny * rw + nx
			if walk[ni] == 0 or dist[ni] != INF_D:
				continue
			if k >= 4 and (walk[y * rw + nx] == 0 or walk[ny * rw + x] == 0):
				continue  # no cutting corners past water
			dist[ni] = d
			q.append(ni)
	_ff[key] = res
	return res


## Move `spd` pixels downhill along a flow field; `jit` is the unit's sideways wobble so columns do not run on one line.
static func _follow(p: Vector2, ff: Dictionary, spd: float, jit: Vector2) -> Vector2:
	var dist: PackedInt32Array = ff["dist"]
	var rw: int = ff["rw"]
	var rh: int = ff["rh"]
	var ox: int = ff["ox"]
	var oy: int = ff["oy"]
	var rem := spd
	for _k in 3:
		var tx := floori(p.x / TILE) - ox
		var ty := floori(p.y / TILE) - oy
		if tx < 0 or ty < 0 or tx >= rw or ty >= rh:
			return p
		var d := dist[ty * rw + tx]
		if d >= INF_D or d == 0:
			return p
		var bx := tx
		var by := ty
		var bd := d
		var bg := 1e18
		var gp: Vector2 = ff.get("goal", p)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := tx + dx
				var ny := ty + dy
				if (dx == 0 and dy == 0) or nx < 0 or ny < 0 or nx >= rw or ny >= rh:
					continue
				var nd := dist[ny * rw + nx]
				if nd >= d or (dx != 0 and dy != 0 and (dist[ty * rw + nx] >= INF_D or dist[ny * rw + tx] >= INF_D)):
					continue
				var gd := ((Vector2(nx + ox, ny + oy) + Vector2(0.5, 0.5)) * TILE).distance_squared_to(gp)
				if nd < bd or (nd == bd and gd < bg):  # equal steps: take the one that points at the goal
					bd = nd
					bg = gd
					bx = nx
					by = ny
		if bd >= d:
			return p
		var c := (Vector2(bx + ox, by + oy) + Vector2(0.5, 0.5)) * TILE + (jit if bd > 0 else Vector2.ZERO)
		var to := c - p
		var l := to.length()
		if l <= rem:
			p = c
			rem -= l
		else:
			return p + to / l * rem
	return p


## Straight move that slides around water: tries the direct heading, then turns up to 105 degrees either way.
static func _slide(p: Vector2, to: Vector2, spd: float, cls: int) -> Vector2:
	var d := to - p
	if d.length() < 0.5:
		return p
	var dir := d.normalized()
	var step := minf(spd, d.length())
	for a in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
		var q: Vector2 = p + dir.rotated(a) * step
		if passable(q, cls):
			return q
	return p


static func _spawn(c: City, foe: City, u: Dictionary) -> Vector2:
	var l := line(c, foe)
	var dir := (l[1] - l[0]).normalized()
	var p0: Vector2 = l[0] + dir * 90.0 + Vector2(-dir.y, dir.x) * float(u["l"]) * 70.0
	var q := nearest_ok(p0, _cls(u["k"]))
	return q if q.is_finite() else p0


## One second of war between two towns: units spawn on the side facing the enemy, march on the other's territory
## through the terrain, and shoot whatever is in weapon range.
static func fight(a: City, b: City) -> void:
	reg[a.gpos] = a
	reg[b.gpos] = b
	_clock += 1
	var now := Time.get_ticks_msec()
	var all: Array = []
	var side := PackedInt32Array()
	for pair in [[a, b, 0], [b, a, 1]]:
		var c: City = pair[0]
		var fo: City = pair[1]
		for u in _of(c, fo.town_name):
			if not u.has("p"):
				u["p"] = _spawn(c, fo, u)
				u["h"] = (terr_px(fo).get_center() - (u["p"] as Vector2)).angle()
			all.append(u)
			side.append(pair[2])
	var n := all.size()
	var pos := PackedVector2Array()
	var tc := PackedInt32Array()
	var foes := [PackedInt32Array(), PackedInt32Array()]
	var cen := [Vector2.ZERO, Vector2.ZERO]  # centroid of each side's fighters (medics and transports follow it)
	var mc := [0, 0]
	var ships := [0, 0]
	for i in n:
		pos.append(all[i]["p"])
		tc.append(_cls(all[i]["k"]))
		foes[1 - side[i]].append(i)
		var kd: Dictionary = KIND[all[i]["k"]]
		if tc[i] == 3:
			ships[side[i]] += 1
		if not kd.has("heal") and not kd.has("lands"):
			cen[side[i]] += pos[i]
			mc[side[i]] += 1
	for s in 2:
		if mc[s] > 0:
			cen[s] /= float(mc[s])
	var centre := [terr_px(b).get_center(), terr_px(a).get_center()]  # goal of side s: the other town's heart
	var fl := {}  # flow fields this call needs, by side and class (built once, not per unit)
	var hits := PackedFloat32Array()
	hits.resize(n)
	var heals := PackedFloat32Array()
	heals.resize(n)
	for i in n:
		var u: Dictionary = all[i]
		var kd: Dictionary = KIND[u["k"]]
		var p: Vector2 = pos[i]
		var cls := tc[i]
		var spd := float(kd["spd"]) * (1.0 + 0.12 * float(u["l"]))  # jitter so a column does not arrive as one clump
		var jit := Vector2(float(u["l"]), fposmod(float(u["l"]) * 7.3, 1.0) - 0.5) * TILE * 0.4
		var goal: Vector2 = centre[side[i]]
		var q := p
		if kd.has("heal"):
			var cand: Array = []
			for j in n:
				if j != i and side[j] == side[i] and float(all[j]["hp"]) < max_hp(all[j]) and p.distance_to(pos[j]) <= float(kd["rng"]):
					cand.append(j)
			cand.sort_custom(func(m: int, k: int) -> bool: return float(all[m]["hp"]) / max_hp(all[m]) < float(all[k]["hp"]) / max_hp(all[k]))
			for j in cand.slice(0, 3):
				var h := minf(float(kd["heal"]), max_hp(all[j]) - float(all[j]["hp"]))
				heals[j] += h
				_gain(u, h * 0.5)
			if mc[side[i]] > 0 and p.distance_to(cen[side[i]]) > 80.0:
				q = _go(a, b, p, cen[side[i]], spd, cls, jit, false, fl, side[i])
		elif kd.has("lands"):  # transports hold back until the enemy fleet is gone, then run for the shore
			var tg: Vector2 = goal
			if ships[1 - side[i]] > 0 and ships[side[i]] > 1:
				tg = cen[side[i]]
			elif ships[1 - side[i]] > 0:
				tg = p
			q = _go(a, b, p, tg, spd, cls, jit, tg == goal, fl, side[i])
		else:
			var best := -1  # best target in range (damage-weighted, so AA picks planes)
			var bs := 1e9
			var near := -1
			var nd := 1e18
			var row := _row(u["k"])
			var rng_ := float(kd["rng"])
			for j in foes[side[i]]:
				var vs := row[tc[j]]
				if vs <= 0.0:
					continue
				var d2 := p.distance_squared_to(pos[j])
				if d2 < nd:
					nd = d2
					near = j
				if d2 <= rng_ * rng_ and sqrt(d2) / vs < bs:
					bs = sqrt(d2) / vs
					best = j
			if best >= 0:
				var dm := float(kd["dmg"]) * (1.0 + RANK_DMG * rank(u)) * row[tc[best]]
				hits[best] += dm
				_gain(u, dm)
				u["ft"] = now
				u["fp"] = pos[best]
				u["h"] = (pos[best] - p).angle()
				continue
			if near >= 0 and sqrt(nd) <= maxf(AGGRO, rng_ * 1.5):
				var tp: Vector2 = pos[near]
				var stand := maxf(rng_ * 0.8, 10.0)
				q = _slide(p, tp - (tp - p).normalized() * stand, spd, cls) if cls != 2 else p + (tp - p).limit_length(spd)
			else:
				q = _go(a, b, p, goal, spd, cls, jit, true, fl, side[i])
		if q != p:
			u["h"] = (q - p).angle()
		u["p"] = q
	for i in n:
		all[i]["hp"] = minf(float(all[i]["hp"]) - float(hits[i]) + float(heals[i]), max_hp(all[i]))
	for i in n:
		if float(all[i]["hp"]) <= 0.0:
			var owner: City = a if side[i] == 0 else b
			var killer: City = b if side[i] == 0 else a
			owner.army.erase(all[i])
			killer.war_sc[owner.town_name] = int(killer.war_sc.get(owner.town_name, 0)) + 1
			booms.append({"a": a.town_name, "b": b.town_name, "p": all[i]["p"], "t": now})
			owner.sounds.append("alarm")
	booms = booms.filter(func(e: Dictionary) -> bool: return now - int(e["t"]) < 3000)
	blasts = blasts.filter(func(e: Dictionary) -> bool: return now - int(e["ts"]) < 9000)
	a.war_t -= 1.0
	if a.war_t <= 0.0:
		a.war_t = 20.0
		a.war_n[b.town_name] = int(a.war_n.get(b.town_name, 0)) + 1
		b.war_n[a.town_name] = int(b.war_n.get(a.town_name, 0)) + 1
	_occupy(a, b)
	_occupy(b, a)
	_bomb(a, b)
	_bomb(b, a)
	if a.war_n.get(b.town_name, 0) >= 30 and a.army.size() + b.army.size() < 6:
		Diplo.sign_treaty(a, b, "")
		Diplo._say(a, b, "%s and %s, with their armies spent, agree to a ceasefire." % [a.town_name, b.town_name])


## One move of `spd` pixels towards `goal`: air flies straight, ground and ships follow a flow field (or hold at the shore if the goal is cut off).
static func _go(a: City, b: City, p: Vector2, goal: Vector2, spd: float, cls: int, jit: Vector2, use_field: bool, fl: Dictionary, sd: int) -> Vector2:
	if cls == 2:
		return p + (goal - p).limit_length(spd)
	if use_field:
		var fk := sd * 4 + cls
		if not fl.has(fk):
			fl[fk] = _field(a, b, _shore(goal) if cls == 3 else goal, cls)
		var ff: Dictionary = fl[fk]
		if bool(ff["ok"]):
			var q := _follow(p, ff, spd, jit)
			if q != p:
				return q
			var tx := floori(p.x / TILE) - int(ff["ox"])
			var ty := floori(p.y / TILE) - int(ff["oy"])
			var rw: int = ff["rw"]
			if tx >= 0 and ty >= 0 and tx < rw and ty < int(ff["rh"]) and int((ff["dist"] as PackedInt32Array)[ty * rw + tx]) < INF_D:
				return p  # arrived
	return _slide(p, goal, spd, cls)


## Ships head for the river tile nearest `goal`.
static func _shore(goal: Vector2) -> Vector2:
	var c: City = reg.get(Vector2i(floori(goal.x / TILE / City.W), floori(goal.y / TILE / City.H)))
	if c == null:
		return goal
	var best := goal
	var bd := 1e18
	var org := origin(c)
	for i in c.water.size():
		if c.water[i] == 1:
			var w := org + (Vector2(i % City.W, i / City.W) + Vector2(0.5, 0.5)) * TILE
			var d := w.distance_squared_to(goal)
			if d < bd:
				bd = d
				best = w
	return best


## Attackers inside a town's territory with no real opposition raid it and, held long enough, force its surrender.
static func _occupy(att: City, vic: City) -> void:
	var zone := terr_px(vic).grow(100.0)
	var n := 0
	for u in _of(att, vic.town_name):
		if u.has("p") and zone.has_point(u["p"]):
			n += int(KIND[u["k"]].get("lands", 1))
	var def := 0
	for u in _of(vic, att.town_name):
		if u.has("p") and zone.has_point(u["p"]):
			def += 1
	if n >= 2 and n > def:
		vic.occ[att.town_name] = float(vic.occ.get(att.town_name, 0.0)) + 1.0
		att.raid[vic.town_name] = float(att.raid.get(vic.town_name, 0.0)) + n / 18.0
		if float(att.raid[vic.town_name]) >= 1.0:
			att.raid[vic.town_name] = 0.0
			Diplo._raid(att, vic)
			var loot := minf(maxf(vic.coins, 0.0) * 0.03, 30.0)
			vic.coins -= loot
			att.coins += loot
		if float(vic.occ[att.town_name]) >= 40.0:
			Diplo.surrender(att, vic)
	else:
		vic.occ[att.town_name] = maxf(float(vic.occ.get(att.town_name, 0.0)) - 1.0, 0.0)


## Bombers over an enemy town with no fighters, jets or anti-air left to stop them flatten its buildings, one strike per bomber every few seconds.
static func _bomb(att: City, vic: City) -> void:
	var zone := terr_px(vic)
	var nb := 0
	for u in _of(att, vic.town_name):
		if u["k"] == "bomber" and u.has("p") and zone.has_point(u["p"]):
			nb += 1
	if nb == 0:
		return
	for u in _of(vic, att.town_name):
		if u["k"] in ["aa", "fighter", "jet"]:
			return
	att.raid["b" + vic.town_name] = float(att.raid.get("b" + vic.town_name, 0.0)) + 0.15 * nb
	if float(att.raid["b" + vic.town_name]) >= 1.0:
		att.raid["b" + vic.town_name] = 0.0
		vic.strike(1, att)
