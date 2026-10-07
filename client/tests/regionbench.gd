extends SceneTree
# 8 towns, main-loop cadence. Env MODE=old ticks every town every 0.1s step; MODE=new batches off-screen towns (0.5s).
func _init() -> void:
	var batch := OS.get_environment("MODE") == "new"
	var sig := Signals.new()
	var towns: Array[City] = []
	for k in 8:
		var t := City.new(sig)
		t.town_name = "T%d" % k
		t.gpos = Vector2i(k % 3, k / 3)
		t.human = k == 0
		t.seed_start()
		t.acc = 0.3 * k
		t.rng.seed = 1000 + k
		for o in towns:
			o.partners.append(t)
			t.partners.append(o)
		towns.append(t)
	var dacc := 0.0
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	var steps := 9000
	for step in steps:
		var a := Time.get_ticks_usec()
		sig.tick(0.1)
		dacc += 0.1
		if dacc >= 1.0:
			dacc -= 1.0
			Diplo.second(towns, towns[0].rng)
		for t in towns:
			if t == towns[0] or not batch:
				t.tick(0.1)
			else:
				t.pend += 0.1
				if t.pend >= 0.5:
					t.tick(t.pend)
					t.pend = 0.0
		worst = maxf(worst, Time.get_ticks_usec() - a)
	var tot := (Time.get_ticks_usec() - t0) / 1000.0
	print("REGION mode=%s steps=%d total=%.0fms per_step=%.2fms per_sim_second=%.1fms worst_step=%.1fms pop0=%d day=%d" % ["new" if batch else "old", steps, tot, tot / steps, tot / steps * 10.0, worst / 1000.0, towns[0].pop, towns[0].day])
	quit()
