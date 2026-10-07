extends SceneTree
# Headless: 8 towns at main-loop cadence for 3000 sim-s; prints where _second() time goes and the worst single steps.
func _init() -> void:
	var sig := Signals.new()
	var towns: Array[City] = []
	for k in 8:
		var t := City.new(sig)
		t.rng.seed = 20261007 + k
		t._gen_ore()
		t.gpos = Vector2i(k % 3, k / 3)
		t.human = false
		t.seed_start()
		for o in towns:
			o.partners.append(t)
			t.partners.append(o)
		towns.append(t)
	var worst: Array[float] = []
	var tot := 0.0
	for step in 30000:
		var t0 := Time.get_ticks_usec()
		sig.tick(0.1)
		if step % 10 == 0:
			Diplo.second(towns, towns[0].rng)
		var batched := 0
		for t in towns:
			if t == towns[0]:
				t.tick(0.1)
			else:
				t.pend += 0.1
				if t.pend >= 0.5 and batched < 2:
					t.tick(t.pend)
					t.pend = 0.0
					batched += 1
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		tot += ms
		worst.append(ms)
	worst.sort()
	print("steps=%d avg=%.2f p50=%.2f p95=%.2f p99=%.2f max=%.2f ms" % [worst.size(), tot / worst.size(), worst[worst.size() / 2], worst[int(worst.size() * 0.95)], worst[int(worst.size() * 0.99)], worst[-1]])
	var keys := City.prof.keys()
	keys.sort_custom(func(a, b): return City.prof[a] > City.prof[b])
	for k in keys:
		print("  %-12s %8.1f ms total" % [k, City.prof[k] / 1000.0])
	print("pops=%s" % str(towns.map(func(c): return c.pop)))
	quit()
