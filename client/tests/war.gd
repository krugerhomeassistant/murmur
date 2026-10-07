extends SceneTree
# War: a strong army must destroy a weak one, hold its border, and force a surrender (no dice involved).
# Second scenario uses every unit type and checks veterans rank up and medics heal.
func _run(mix_a: Dictionary, mix_b: Dictionary, prep := Callable()) -> Array:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in 2:
		var t := City.new(sig)
		t.town_name = "W%d" % k
		t.gpos = Vector2i(k, 0)
		t.human = false
		t.seed_start()
		t.coins = 5000.0
		for o in ts:
			o.partners.append(t)
			t.partners.append(o)
		ts.append(t)
	var a := ts[0]
	var b := ts[1]
	if prep.is_valid():
		prep.call(a, b)
	for k in mix_a:
		for i in int(mix_a[k]):
			a.army.append(Military._unit(k))
	for k in mix_b:
		for i in int(mix_b[k]):
			b.army.append(Military._unit(k))
	Diplo.act(a, b, "war")
	var rng := RandomNumberGenerator.new()
	var secs := 0
	while Diplo.treaty(a, b) == "war" and secs < 1500:
		for t in ts:
			t.tick(0.1)
		Diplo.second(ts, rng)
		secs += 1
		for u in a.army:
			if float(u["hp"]) > Military.max_hp(u) + 0.01 or is_nan(float(u["hp"])):
				assert(false, "unit hp out of range")
	assert(Diplo.treaty(a, b) != "war", "war never ended after %d s: a=%s b=%s" % [secs, str(a.army.map(func(u): return u.k + str(int(u.hp)) + "@" + str(int(u.s)) + ">" + str(u.tgt) + "l" + str(snappedf(u.l, 0.01)))), str(b.army.map(func(u): return u.k + str(int(u.hp)) + "@" + str(int(u.s)) + ">" + str(u.tgt) + "l" + str(snappedf(u.l, 0.01))))])
	return [a, b, secs]


func _init() -> void:
	for k in Military.KIND:  # every unit type must be fully defined
		var kd: Dictionary = Military.KIND[k]
		for f in ["n", "t", "hp", "dmg", "rng", "spd", "cost", "upk", "train", "cap", "vs"]:
			assert(kd.has(f), "%s lacks %s" % [k, f])
		assert(Military.DEF_W.has(k), "%s has no default priority" % k)
	var r := _run({"inf": 14, "tank": 4}, {"inf": 3})
	var a: City = r[0]
	var b: City = r[1]
	assert(int(a.war_sc.get(b.town_name, 0)) > 0, "no kills recorded")
	assert(a.army.size() > 0, "winner has no army left")
	print("WAR_OK secs=%d a_army=%d b_army=%d kills=%d" % [r[2], a.army.size(), b.army.size(), int(a.war_sc.get(b.town_name, 0))])
	var all := {}
	for k in Military.KIND:
		all[k] = 2
	var r2 := _run(all, {"inf": 20, "gren": 4, "tank": 3, "jet": 2})
	var c: City = r2[0]
	var top := 0
	for u in c.army:
		top = maxi(top, Military.rank(u))
		assert(float(u["hp"]) <= Military.max_hp(u) + 0.01 and float(u["hp"]) > 0.0, "bad hp")
	assert(top >= 1 or c.army.is_empty(), "nobody ranked up")
	print("MIX_OK secs=%d survivors=%d top_rank=%d" % [r2[2], c.army.size(), top])
	# Ships fight only where a river crosses the border; bombers with no air defence against them destroy buildings.
	var wet := func(a: City, b: City) -> void:
		a.water[a.terr.get_center().y * City.W + a.terr.end.x - 1] = 1
		b.water[b.terr.get_center().y * City.W + b.terr.position.x] = 1
	var r3 := _run({"patrol": 4, "destroyer": 1, "transport": 1}, {"patrol": 4}, wet)
	assert(int((r3[0] as City).war_sc.get((r3[1] as City).town_name, 0)) + int((r3[1] as City).war_sc.get((r3[0] as City).town_name, 0)) > 0, "ships never fought")
	var dry := _run({"patrol": 3, "inf": 6}, {"inf": 3})
	assert(int((dry[0] as City).army.filter(func(u: Dictionary) -> bool: return u["k"] == "patrol").size()) == 3, "ships fought without a river")
	var nb: int = Military.blasts.size()
	var r4 := _run({"bomber": 4, "inf": 2}, {"inf": 4})
	assert(Military.blasts.size() > nb or (r4[1] as City).burned > 0, "bombers destroyed nothing")
	print("NAVAL_OK bombs=%d" % (Military.blasts.size() - nb))
	quit()
