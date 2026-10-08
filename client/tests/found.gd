extends SceneTree
# Founding on the map: any free plot, price grows with distance, blocked and unaffordable sites are refused.
func _init() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.bench_seed = 20261007
	m.start_game({"name": "T", "towns": 2, "river": 0, "mood": 1, "diff": 1, "land": 1, "auto": 2, "policy": true, "expand": true, "guide": false, "spectate": true})
	var ok := true
	var c0: float = m.found_cost(Vector2i(1, 1))
	var c1: float = m.found_cost(Vector2i(5, 0))
	if c0 != m.FOUND_COST or c1 <= c0:
		ok = false
		print("FAIL cost does not grow with distance: %s %s" % [c0, c1])
	m.city.coins = 100000.0
	if m.found_town_at(m.towns[0].gpos):
		ok = false
		print("FAIL founded on an occupied plot")
	var n: int = m.towns.size()
	var site := Vector2i.ZERO
	for x in range(3, 30):
		if m.found_block(Vector2i(x, 2)) == "":
			site = Vector2i(x, 2)
			break
	var before: float = m.city.coins
	var price: float = m.found_cost(site)
	if site == Vector2i.ZERO or not m.found_town_at(site) or m.towns.size() != n + 1 or m.towns[n].gpos != site:
		ok = false
		print("FAIL did not found at %s" % str(site))
	elif absf(before - m.city.coins - price) > 0.01:
		ok = false
		print("FAIL charged %s, price %s" % [before - m.city.coins, price])
	else:
		var t: City = m.towns[n]
		if not t.world_fed or t.ground.count(World.K.PLAIN) == City.W * City.H and t.water.count(1) == 0 and t.ore.count(0) == City.W * City.H:
			print("note: new plot looks featureless")
	m.city.coins = 10.0
	if m.found_town_at(Vector2i(0, 9)) or m.towns.size() != n + 1:
		ok = false
		print("FAIL founded without the money")
	var wet := Vector2i.ZERO
	for y in range(-20, 20):
		for x in range(-20, 20):
			if m.found_block(Vector2i(x, y)) == "Too much water there.":
				wet = Vector2i(x, y)
	if wet == Vector2i.ZERO:
		ok = false
		print("FAIL no watery plot found to test the refusal")
	print("FOUND_OK" if ok else "FOUND_FAIL")
	quit(0 if ok else 1)
