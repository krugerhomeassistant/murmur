extends SceneTree
# Headless: 8 towns, main-loop cadence (0.1s steps, off-screen towns in 0.5s batches). Prints per-day cost; hangs show up as a timeout.
func _init() -> void:
	var sig := Signals.new()
	var towns: Array[City] = []
	for k in 8:
		var t := City.new(sig)
		t.town_name = "T%d" % k
		t.gpos = Vector2i(k % 3, k / 3)
		t.human = k == 0
		t.seed_start()
		for o in towns:
			o.partners.append(t)
			t.partners.append(o)
		towns.append(t)
	var dacc := 0.0
	var t0 := Time.get_ticks_usec()
	var last := 0
	for step in 12000:
		sig.tick(0.1)
		dacc += 0.1
		if dacc >= 1.0:
			dacc -= 1.0
			Diplo.second(towns, towns[0].rng)
		for t in towns:
			if t == towns[0]:
				t.tick(0.1)
			else:
				t.pend += 0.1
				if t.pend >= 0.5:
					t.tick(t.pend)
					t.pend = 0.0
		if towns[0].day != last:
			last = towns[0].day
			print("day %d pop0=%d ms/step=%.2f" % [last, towns[0].pop, (Time.get_ticks_usec() - t0) / 1000.0 / (step + 1)])
	print("REGION_OK")
	quit()
