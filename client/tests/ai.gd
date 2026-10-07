extends SceneTree
# AI armies: planner towns counter what the enemy fields and build military buildings when threatened.
func _init() -> void:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in 2:
		var t := City.new(sig)
		t.town_name = "A%d" % k
		t.gpos = Vector2i(k, 0)
		t.human = false
		t.seed_start()
		t.peak = 400.0  # military buildings unlocked
		t.coins = 3000.0
		for o in ts:
			o.partners.append(t)
			t.partners.append(o)
		ts.append(t)
	var a := ts[0]
	var b := ts[1]
	# counter-training
	for i in 6:
		b.army.append(Military._unit("jet"))
	a.rel[b.town_name] = -0.8
	Military.adapt(a)
	assert(int(a.train_w["aa"]) > int(Military.DEF_W["aa"]) and int(a.train_w["fighter"]) > int(Military.DEF_W["fighter"]), "no anti-air against jets: %s" % str(a.train_w))
	b.army.clear()
	for i in 6:
		b.army.append(Military._unit("tank"))
	Military.adapt(a)
	assert(int(a.train_w["gren"]) > int(Military.DEF_W["gren"]), "no grenadiers against tanks")
	b.army.clear()
	# threat -> military buildings
	assert(a.threat() > 0.3, "no threat felt: %f" % a.threat())
	for step in 25000:
		sig.tick(0.1)
		if step % 10 == 0:
			Diplo.second(ts, ts[0].rng)
			for t in ts:
				t.coins = maxf(t.coins, 2500.0)  # the economy is not what is under test
			for t in ts:
				for o in t.partners:
					t.rel[o.town_name] = minf(Diplo.rel(t, o), -0.6)
		for t in ts:
			t.tick(0.1)
	var mil := 0
	for t in ts:
		mil += (t.bt.get(Catalog.Id.BASE, []) as Array).size() + (t.bt.get(Catalog.Id.BARRACKS, []) as Array).size()
	for t in ts:
		print(t.town_name, " pop ", t.pop, " coins ", int(t.coins), " base ", (t.bt.get(Catalog.Id.BASE, []) as Array).size(), " bk ", (t.bt.get(Catalog.Id.BARRACKS, []) as Array).size(), " ra ", (t.bt.get(Catalog.Id.RADAR, []) as Array).size(), " thr ", t.threat(), " army ", t.army.size(), " income ", t.income)
	assert(mil > 0, "hostile planner towns built no barracks or bases")
	print("AI_OK military_buildings=%d armies=%d/%d" % [mil, a.army.size(), b.army.size()])
	quit()
