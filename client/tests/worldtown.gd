extends SceneTree
const T = Catalog.Id
# Town plots cut from the shared world: offsets line up, neighbours share one coastline, saves keep the ground.
func _init() -> void:
	var w := World.new(20261008)
	var sig := Signals.new()
	var a := City.new(sig)
	var b := City.new(sig)
	a.apply_world(w, City.plot_origin(Vector2i(0, 0)))
	b.apply_world(w, City.plot_origin(Vector2i(1, 0)))
	var ok := true
	for y in City.H:
		for x in [0, City.W - 1]:
			var wa := w.is_water(City.W - 1 + 0 * x, y)
			var wb := w.is_water(City.W, y)
			if (a.water[y * City.W + City.W - 1] == 1) != wa or (b.water[y * City.W] == 1) != wb:
				ok = false
	if not ok:
		print("FAIL plot edges do not match the world")
	var wet := 0
	for i in City.W * City.H:
		if a.water[i] == 1:
			wet += 1
			if a.ore[i] != 0:
				ok = false
				print("FAIL ore on water")
		if (a.ground[i] == World.K.SEA or a.ground[i] == World.K.RIVER) != (a.water[i] == 1):
			ok = false
			print("FAIL water and ground disagree")
	var f := City.new(sig)
	f.apply_world(w, City.plot_origin(Vector2i(2, 1)), false)
	if f.water.count(1) != 0 or f.ground.count(World.K.RIVER) != 0 or f.ground.count(World.K.SEA) != 0:
		ok = false
		print("FAIL flat land option left water")
	var c := City.new(sig)
	c.from_dict(a.to_dict())
	if c.ground != a.ground or c.water != a.water or c.ore != a.ore:
		ok = false
		print("FAIL save round trip")
	var d := City.new(sig)  # a building on a river tile dries it out
	d.seed_start()
	d.apply_world(w, City.plot_origin(Vector2i(0, 0)))
	for i in City.W * City.H:
		if d.grid[i] != T.EMPTY and d.water[i] == 1:
			ok = false
			print("FAIL building stands in water")
	print("plot A wet tiles: %d" % wet)
	print("WORLDTOWN_OK" if ok else "WORLDTOWN_FAIL")
	quit(0 if ok else 1)
