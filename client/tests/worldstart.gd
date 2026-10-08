extends SceneTree
# Whole-game start on the endless world: every town on dry ground, same world for all, save/load keeps it.
func _init() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	var ok := true
	for opts in [{"towns": 8, "river": 3}, {"towns": 4, "river": 1}, {"towns": 2, "river": 0}]:
		var t0 := Time.get_ticks_msec()
		m.start_game({"name": "T", "towns": opts["towns"], "river": opts["river"], "mood": 1, "diff": 1, "land": 1, "auto": 2, "policy": true, "expand": true, "guide": false, "spectate": true})
		var ms := Time.get_ticks_msec() - t0
		if m.world == null or m.towns.size() != opts["towns"]:
			ok = false
			print("FAIL no world / wrong town count")
			continue
		var wet := 0
		for t in m.towns:
			for i in City.W * City.H:
				if t.grid[i] != Catalog.Id.EMPTY and t.water[i] == 1:
					ok = false
			wet += t.water.count(1)
			if not t.world_fed:
				ok = false
		if opts["river"] == 1 and wet != 0:
			ok = false
			print("FAIL flat-land option left water")
		print("towns=%d river=%d start %d ms wet=%d seed=%d" % [opts["towns"], opts["river"], ms, wet, m.world.seed])
	m.save_game()
	var sd: int = m.world.seed
	var g0: PackedByteArray = (m.towns[0] as City).ground.duplicate()
	m.world = null
	if not m.load_game() or m.world == null or m.world.seed != sd or (m.towns[0] as City).ground != g0:
		ok = false
		print("FAIL save/load lost the world")
	print("WORLDSTART_OK" if ok else "WORLDSTART_FAIL")
	quit(0 if ok else 1)
