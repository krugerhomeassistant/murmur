class_name Traffic
extends RefCounted
## Road traffic and buses of one town: pure rules over a City, split out of city.gd.

const T = Catalog.Id


## Cars leave a trail on each road cell they cross; jams form where it piles up.
static func tick(c: City) -> void:
	c.drivers = 0
	for i in c.cells:
		c.traffic[i] *= 0.7
	for z in c.citizens:
		if z.car and z.path.size() > 0:
			var q := Vector2i(z.pos.floor())
			if c.inside(q.x, q.y):
				c.traffic[q.y * City.W + q.x] += 1.0
				c.drivers += 1
	var cs := 0.0
	var n := 0
	for i in c.cells:
		if c.traffic[i] > 0.3:
			n += 1
			cs += clampf((c.traffic[i] - (8.0 if c.grid[i] == T.AVENUE else 3.0)) / 4.0, 0.0, 1.0)
	c.congestion = cs / maxf(n, 1)


## Upgrades the busiest plain road (and up to 3 neighbours in line) to an avenue.
static func widen(c: City) -> bool:
	var best := -1
	var bv := 3.0
	for i in c.cells:
		if c.grid[i] == T.ROAD and c.traffic[i] > bv:
			bv = c.traffic[i]
			best = i
	if best < 0:
		return false
	var p := c.cell(best)
	var axis := Vector2i(1, 0) if c.is_road(c.at(p.x + 1, p.y)) or c.is_road(c.at(p.x - 1, p.y)) else Vector2i(0, 1)
	var n := 0
	for k in range(-2, 3):
		var q := p + axis * k
		if c.inside(q.x, q.y) and c.grid[q.y * City.W + q.x] == T.ROAD and c.coins >= 7.0:
			c.grid[q.y * City.W + q.x] = T.AVENUE
			c.coins -= 7.0
			n += 1
	c.roads_dirty = true
	c.msg = "Planners widened a jammed street into an avenue."
	c._scan()
	return n > 0


## People per bus: a bus needs a driver and passengers from the town's own people, so a tiny town has none (every unit on the map is one of its people).
const PEOPLE_PER_BUS := 8


## One bus per bus stop, standing at the road next to it, as many as the town's people can run.
static func sync_buses(c: City) -> void:
	var stops: Array = c.bt.get(T.BUS, [])
	var keep: Array = []
	for b in c.buses:
		if stops.has(b["stop"]) and keep.size() < c.pop / PEOPLE_PER_BUS:
			keep.append(b)
	c.buses = keep
	for s in stops:
		var has := false
		if c.buses.size() >= c.pop / PEOPLE_PER_BUS:
			break
		for b in c.buses:
			if b["stop"] == s:
				has = true
		var r := c._road_next_to(s)
		if not has and r >= 0:
			c.buses.append({"stop": s, "pos": c.center(r), "path": PackedVector2Array(), "pi": 0, "wait": 1.0, "out": false, "dir": Vector2.RIGHT})


## Sends a bus out to a plaza or leisure spot and back to its stop.
static func bus_route(c: City, b: Dictionary) -> void:
	var goal: int = b["stop"]
	if not b["out"]:
		var opts: Array = c.spots.duplicate()
		if c.plaza >= 0:
			opts.append(c.plaza)
		if opts.is_empty():
			b["wait"] = 5.0
			return
		goal = opts[c.rng.randi() % opts.size()]
	var gr := c._road_next_to(goal)
	var p: Vector2 = b["pos"]
	var fr := Vector2i(p.floor())
	if gr < 0 or not c.inside(fr.x, fr.y) or not c.is_road(c.grid[fr.y * City.W + fr.x]):
		var r := c._road_next_to(b["stop"])
		if r >= 0:
			b["pos"] = c.center(r)
		b["wait"] = 3.0
		return
	var ids := c.astar.get_id_path(fr, c.cell(gr))
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
