extends SceneTree
# Spectator: 3 towns, all human=false, run 3000 sim-seconds; none may end, all must grow.
func _init() -> void:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in 3:
		var t := City.new(sig)
		t.town_name = "T%d" % k
		t.gpos = Vector2i(k, 0)
		t.human = false
		t.seed_start()
		for o in ts:
			o.partners.append(t)
			t.partners.append(o)
		ts.append(t)
	for step in 30000:
		sig.tick(0.1)
		if step % 10 == 0:
			Diplo.second(ts, ts[0].rng)
		for t in ts:
			t.tick(0.1)
	for t in ts:
		assert(t.over == "", "%s ended: %s" % [t.town_name, t.over])
		assert(t.pop > 20, "%s did not grow (pop %d)" % [t.town_name, t.pop])
	print("SPECTATE_OK pops=%s" % str(ts.map(func(t: City) -> int: return t.pop)))
	quit()
