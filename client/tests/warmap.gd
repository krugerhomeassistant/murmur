extends SceneTree
# War on the map: ground units never stand in a river, a bridge lets them cross, ships stay on water.
func _towns() -> Array:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in 2:
		var t := City.new(sig)
		t.town_name = "M%d" % k
		t.gpos = Vector2i(k, 0)
		t.human = false
		t.seed_start()
		t.coins = 5000.0
		for o in ts:
			o.partners.append(t)
			t.partners.append(o)
		ts.append(t)
	return ts


func _river(a: City, x0: int) -> void:  # a north-south river, three tiles wide, across the whole of town a
	for y in City.H:
		for x in range(x0, x0 + 3):
			a.water[y * City.W + x] = 1


func _go(ts: Array, secs: int, check: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	for s in secs:
		for t in ts:
			t.tick(0.1)
		Diplo.second(ts, rng)
		check.call()


func _init() -> void:
	var ts := _towns()
	var a: City = ts[0]
	var b: City = ts[1]
	var x0: int = a.terr.end.x + 4  # between a's territory and b
	_river(a, x0)
	var rx0 := float(x0) * Military.TILE
	for i in 4:
		a.army.append(Military._unit("ltank"))
	Diplo.act(a, b, "war")
	var wet := [0]
	_go(ts, 500, func() -> void:
		for u in a.army:
			if u.has("p"):
				var p: Vector2 = u["p"]
				if not Military.passable(p, 0):
					wet[0] += 1
				assert(p.x < rx0 + 1.0 or Military.passable(p, 0), "tank in the river"))
	assert(wet[0] == 0, "ground units stood in the river %d times" % wet[0])
	assert(Diplo.treaty(a, b) == "war", "tanks crossed an unbridged river and won")
	for u in a.army:
		assert((u["p"] as Vector2).x < rx0 + 3.0 * Military.TILE, "tank got across without a bridge")
	# a road bridge across the river opens the way
	for x in range(x0 - 1, x0 + 4):
		var i: int = a.terr.get_center().y * City.W + x
		a.grid[i] = Catalog.Id.ROAD
	Military.terrain_changed()  # what City.place() does for a bridge
	_go(ts, 700, func() -> void: pass)
	assert(Diplo.treaty(a, b) != "war" or a.army.any(func(u: Dictionary) -> bool: return (u["p"] as Vector2).x > rx0 + 3.0 * Military.TILE), "nobody crossed the bridge")
	# ships stay on water
	var ts2 := _towns()
	var c: City = ts2[0]
	var d: City = ts2[1]
	for x in City.W:
		c.water[c.terr.get_center().y * City.W + x] = 1
		d.water[d.terr.get_center().y * City.W + x] = 1
	for i in 3:
		c.army.append(Military._unit("patrol"))
	Diplo.act(c, d, "war")
	var dry := [0]
	_go(ts2, 120, func() -> void:
		for u in c.army:
			if u["k"] == "patrol" and u.has("p") and not Military.passable(u["p"], 3):
				dry[0] += 1)
	assert(dry[0] == 0, "ships left the water %d times" % dry[0])
	print("WARMAP_OK")
	quit()
