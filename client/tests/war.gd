extends SceneTree
# War: a strong army must destroy a weak one, hold its border, and force a surrender (no dice involved).
func _init() -> void:
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
	for i in 14:
		a.army.append(Military._unit("inf"))
	for i in 4:
		a.army.append(Military._unit("tank"))
	for i in 3:
		b.army.append(Military._unit("inf"))
	var b0 := b.army.size()
	Diplo.act(a, b, "war")
	var rng := RandomNumberGenerator.new()
	var secs := 0
	while Diplo.treaty(a, b) == "war" and secs < 1500:
		for t in ts:
			t.tick(0.1)
		Diplo.second(ts, rng)
		secs += 1
	assert(Diplo.treaty(a, b) != "war", "war never ended after %d s" % secs)
	assert(int(a.war_sc.get(b.town_name, 0)) > 0, "no kills recorded")
	assert(a.army.size() > 0, "winner has no army left")
	print("WAR_OK secs=%d a_army=%d b_army=%d (b started %d) kills=%d" % [secs, a.army.size(), b.army.size(), b0, int(a.war_sc.get(b.town_name, 0))])
	quit()
