extends SceneTree
## All ages, start to finish, at peace (no diplomacy: wars are a separate test): planner towns begin in the Stone age and play
## 4500 sim-seconds (about 4 minutes). They must advance, keep growing (no collapse at an age change or from upkeep), choose
## their research by themselves and never hold a building from a later age.


func _init() -> void:
	var sig := Signals.new()
	var towns: Array[City] = []
	for k in 4:
		var t := City.new(sig)
		t.town_name = "Age%d" % k
		t.gpos = Vector2i(k % 2, k / 2)
		t.seed_start()
		t.human = false
		Ages.set_age(t, 0)
		t.rng.seed = 7000 + k
		for o in towns:
			o.partners.append(t)
			t.partners.append(o)
		towns.append(t)
	var best_age := 0
	var t0 := Time.get_ticks_msec()
	for step in 45000:
		sig.tick(0.1)
		for t in towns:
			t.tick(0.1)
	var ok := true
	var rep := []
	for t in towns:
		best_age = maxi(best_age, t.age)
		var early := 0
		for i in t.cells:
			var g: int = t.grid[i]
			if g != Catalog.Id.EMPTY and Ages.building(g) > t.age:
				early += 1
		var done: bool = Research.pending(t).is_empty()
		rep.append("%s age=%d pop=%d tech=%s early=%d" % [t.town_name, t.age, t.pop, t.tech, early])
		ok = ok and early == 0 and done and t.pop >= 60
	ok = ok and best_age >= 6
	print("AGEPLAY_OK %s (%d s)" % [rep, (Time.get_ticks_msec() - t0) / 1000] if ok else "AGEPLAY_FAIL %s" % [rep])
	quit(0 if ok else 1)
