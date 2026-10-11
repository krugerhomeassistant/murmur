extends SceneTree
# Vassalage (D4): a total-war surrender makes the loser a vassal that keeps its land, pays a share of its income,
# cannot declare war or leave, counts as the overlord's allied land, and is released by any other treaty.
func _init() -> void:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in 2:
		var t := City.new(sig)
		t.town_name = "V%d" % k
		t.gpos = Vector2i(k, 0)
		t.pop = 30
		t.human = false
		t.terr = Rect2i(0, 0, 10, 1)
		ts.append(t)
	ts[0].partners.append(ts[1])
	ts[1].partners.append(ts[0])
	var w := ts[0]
	var l := ts[1]
	assert(City.SAVE_KEYS.has("liege"), "liege must be saved")
	l.coins = 1000.0
	w.war_goal[l.town_name] = "total"
	var land_before := l.terr
	Diplo.sign_treaty(w, l, "war")
	Diplo.surrender(w, l)
	assert(Diplo.treaty(w, l) == "vassal" and l.liege == w.town_name and w.liege == "", "total surrender must make a vassal")
	assert(l.terr == land_before, "a vassal keeps its land")
	assert(Diplo.tmult(w, l) == 0.0, "unlinked towns do not trade (vassal must not crash tmult)")
	l.income = 10.0
	var wc := w.coins
	var rng := RandomNumberGenerator.new()
	Diplo.second(ts, rng)
	assert(absf(w.coins - wc - 10.0 * Diplo.VASSAL_SHARE) < 0.001, "overlord should receive the vassal share (%f)" % (w.coins - wc))
	assert(Diplo.act(l, w, "war") == "A vassal cannot declare war.", "vassal declared war")
	assert(Diplo.act(l, w, "leave").begins_with("You cannot leave"), "vassal left its overlord")
	for i in 200:  # the AI never declares war on or as a vassal
		Diplo._event(w, l, rng)
		Diplo._event(l, w, rng)
	assert(Diplo.treaty(w, l) == "vassal", "treaty changed by events")
	var v := Victory.new()
	var all: Array[City] = [w, l]
	v.second(all)
	var row: Dictionary = v.rows[0]
	for r: Dictionary in v.rows:
		if r["name"] == w.town_name:
			row = r
	assert(float(row["allied"]) > float(row["land"]), "vassal land must count as allied land")
	Diplo.act(w, l, "leave")
	assert(Diplo.treaty(w, l) == "" and l.liege == "", "overlord can release the vassal")
	print("VASSAL_OK")
	quit()
