extends SceneTree
## War frequency: 8 planner towns on a 4x2 grid, 1800 game seconds (30 minutes). Prints wars started and how each ended.
## Not in CI (slow, non-deterministic): D3 acceptance is at least 2 wars and at least 1 non-stalemate end, measured 3 times.
const SECS := 1800


func _init() -> void:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in 8:
		var t := City.new(sig)
		t.town_name = "R%d" % k
		t.gpos = Vector2i(k % 4, k / 4)
		t.human = false
		t.temper = [0.0, 0.2, -0.25, 0.05][k % 4]
		t.seed_start()
		ts.append(t)
	for t in ts:
		for o in ts:
			if o != t and Diplo.side(t, o) >= 0:
				t.partners.append(o)
	var open := {}
	var started := 0
	for step in SECS * 10:
		sig.tick(0.1)
		if step % 10 == 0:
			Diplo.second(ts, ts[0].rng)
			var now := {}
			for w in Diplo.wars(ts):
				now[w["a"] + ">" + w["b"]] = w["goal"]
			for k in now:
				if not open.has(k):
					started += 1
					print("war %s goal=%s at %d s" % [k, now[k], step / 10])
			for k in open:
				if not now.has(k):
					print("war %s over at %d s" % [k, step / 10])
			open = now
		for t in ts:
			t.tick(0.1)
	for x in ts:
		for y in x.partners:
			print("%s>%s linked=%s tension=%.2f rel=%.2f mil=%.2f/%.2f treaty=%s" % [x.town_name, y.town_name, Diplo.linked(x, y), float(x.tension.get(y.town_name, 0.0)), Diplo.rel(x, y), Diplo.mil(x), Diplo.mil(y), Diplo.treaty(x, y)])
	print("WARRATE started=%d open=%d pops=%s" % [started, open.size(), str(ts.map(func(t: City) -> int: return t.pop))])
	quit()
