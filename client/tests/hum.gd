extends SceneTree
# Debug: a human-run town (no player input) among planner towns; reports when/why it ends.
func _init() -> void:
	var sig := Signals.new()
	var towns: Array[City] = []
	for k in 8:
		var t := City.new(sig)
		t.rng.seed = 20261007 + k
		t._gen_ore()
		t.gpos = Vector2i(k % 3, k / 3)
		t.human = k == 0
		t.seed_start()
		for o in towns:
			o.partners.append(t)
			t.partners.append(o)
		towns.append(t)
	for step in 30000:
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
		if towns[0].over != "":
			print("OVER at step %d day %d: %s coins=%.0f pop=%d" % [step, towns[0].day, towns[0].over, towns[0].coins, towns[0].pop])
			break
	print("END day=%d pop=%d coins=%.0f over='%s'" % [towns[0].day, towns[0].pop, towns[0].coins, towns[0].over])
	quit()
