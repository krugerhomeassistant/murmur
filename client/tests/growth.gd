extends SceneTree
# Planner towns must keep growing: 4 towns for 4000 sim-s, prints each population and the average (floor asserted).
const FLOOR := 85.0  # baseline before the tax controller was 74; healthy runs land 105 to 220
func _init() -> void:
	var sig := Signals.new()
	var towns: Array[City] = []
	for k in 4:
		var t := City.new(sig)
		t.rng.seed = 20261007 + k
		t._gen_ore()
		t.gpos = Vector2i(k % 2, k / 2)
		t.human = false
		t.seed_start()
		for o in towns:
			o.partners.append(t)
			t.partners.append(o)
		towns.append(t)
	for step in 40000:
		sig.tick(0.1)
		if step % 10 == 0:
			Diplo.second(towns, towns[0].rng)
		for t in towns:
			if t == towns[0]:
				t.tick(0.1)
			else:
				t.pend += 0.1
				if t.pend >= 0.5:
					t.tick(t.pend)
					t.pend = 0.0
	var tot := 0
	for t in towns:
		tot += t.pop
	var avg := tot / float(towns.size())
	print("pops=%s avg=%.0f coins=%s tax=%s" % [str(towns.map(func(c: City) -> int: return c.pop)), avg, str(towns.map(func(c: City) -> int: return int(c.coins))), str(towns.map(func(c: City) -> float: return c.tax_r))])
	assert(avg >= FLOOR, "planner towns stalled")
	print("GROWTH_OK avg=%.0f" % avg)
	quit()
