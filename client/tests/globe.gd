extends SceneTree
## Globe markers and the coarse land map: one per town, radius grows with population, overlays stay in 0..1, reading changes nothing, and 200 towns are fast.


func _init() -> void:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in 200:
		var t := City.new(sig)
		t.town_name = "T%d" % k
		t.gpos = Vector2i(k % 20, k / 20)
		t.pop = k * 3
		t.coins = 100.0 + k
		t.age = k % 4
		ts.append(t)
	Diplo.sign_treaty(ts[0], ts[1], "alliance")
	var before := ts[5].coins
	var t0 := Time.get_ticks_usec()
	var all_ok := true
	for o in Globe.OVERLAYS:
		var m := Globe.markers(ts, ts[0], o)
		all_ok = all_ok and m.size() == 200
		for e in m:
			all_ok = all_ok and float(e["v"]) >= 0.0 and float(e["v"]) <= 1.0
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / Globe.OVERLAYS.size()
	var m2 := Globe.markers(ts, ts[0], "side")
	var sides: bool = m2[0]["side"] == "you" and m2[1]["side"] == "alliance" and m2[2]["side"] == "none"
	var grows: bool = Globe.radius(400) > Globe.radius(10) and Globe.radius(100000) == Globe.MAX_R and Globe.radius(0) == Globe.MIN_R
	var pure: bool = ts[5].coins == before
	var w := World.new(777)
	var a := w.coarse(256, -128, 16, 8)
	var det: bool = a == w.coarse(256, -128, 16, 8) and a.size() == 256
	var agree := 0
	var seen := {}
	for j in 16:
		for i in 16:
			seen[a[j * 16 + i]] = true
			var real: int = w.kind(256 + i * 8, -128 + j * 8)
			if (a[j * 16 + i] == World.K.SEA) == (real == World.K.SEA):
				agree += 1
	var coarse_ok: bool = det and agree >= 240 and seen.size() >= 2
	var ok: bool = all_ok and sides and grows and pure and ms < 5.0 and coarse_ok
	print("GLOBE_OK ms=%.2f" % ms if ok else "GLOBE_FAIL coarse=%s agree=%d all=%s sides=%s grows=%s pure=%s ms=%.2f" % [coarse_ok, agree, all_ok, sides, grows, pure, ms])
	quit(0 if ok else 1)
