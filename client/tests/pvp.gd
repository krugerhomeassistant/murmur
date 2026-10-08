extends SceneTree
# Headless: godot --headless --path client -s tests/pvp.gd -> PVP_OK. Treaties between two player-run towns need the other
# player's answer; refusals refund; a planner town (owner 0) still answers instantly as before.
func _init() -> void:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in 3:
		var t := City.new(sig)
		t.rng.seed = 7 + k
		t._gen_ore()
		t.gpos = Vector2i(k, 0)
		t.seed_start()
		t.coins = 2000.0
		for o in ts:
			o.partners.append(t)
			t.partners.append(o)
		ts.append(t)
	var a := ts[0]
	var b := ts[1]
	var c := ts[2]
	a.owner = 11
	b.owner = 12
	var ok := true
	var before := a.coins
	var msg := Diplo.act(a, b, "pact")
	ok = ok and msg.begins_with("Proposal sent") and Diplo.treaty(a, b) == "" and b.petitions.size() == 1 and is_equal_approx(a.coins, before - 200.0)
	ok = ok and Diplo.act(a, b, "pact").contains("already has a proposal")  # no double proposal, no double charge
	ok = ok and is_equal_approx(a.coins, before - 200.0)
	b.answer(0, false)  # refused: deposit back, still no treaty
	ok = ok and Diplo.treaty(a, b) == "" and is_equal_approx(a.coins, before)
	Diplo.act(a, b, "pact")
	b.answer(0, true)
	ok = ok and Diplo.treaty(a, b) == "pact" and Diplo.treaty(b, a) == "pact"
	ok = ok and Diplo.act(a, b, "alliance").begins_with("Proposal sent")
	b.answer(0, true)
	ok = ok and Diplo.treaty(a, b) == "alliance"
	Diplo.act(a, b, "leave")  # unilateral by design
	ok = ok and Diplo.treaty(a, b) == ""
	Diplo.act(a, b, "war")  # declaring war needs no consent
	ok = ok and Diplo.treaty(a, b) == "war"
	ok = ok and Diplo.act(a, b, "peace").contains("will not talk")
	a.war_n[b.town_name] = 5
	ok = ok and Diplo.act(a, b, "peace").begins_with("Proposal sent")
	b.answer(0, true)
	ok = ok and Diplo.treaty(a, b) == ""
	# a planner town (no owner) keeps the old instant behaviour
	a.rel[c.town_name] = 0.9
	c.rel[a.town_name] = 0.9
	ok = ok and Diplo.act(a, c, "pact").begins_with("Trade pact signed") and Diplo.treaty(a, c) == "pact"
	print("PVP_OK" if ok else "PVP_FAIL")
	quit(0 if ok else 1)
