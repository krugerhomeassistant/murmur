extends SceneTree
## Army stance: advance marches on the enemy, hold and retreat fall back to the home territory (and retreat does not chase).


func _dist(stance: String) -> float:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in 2:
		var t := City.new(sig)
		t.town_name = "T%d" % k
		t.gpos = Vector2i(k, 0)
		t.human = false
		t.seed_start()
		ts.append(t)
	var a := ts[0]
	var b := ts[1]
	a.partners.append(b)
	b.partners.append(a)
	a.stance = stance
	Diplo.act(a, b, "war")
	for i in 6:
		var u := Military._unit("inf")
		u["tgt"] = b.town_name
		a.army.append(u)
	for s in 40:
		Military.fight(a, b)
	var sum := 0.0
	var mine := Military._of(a, b.town_name)
	for u in mine:
		sum += (u["p"] as Vector2).distance_to(Military.terr_px(b).get_center())
	return sum / maxf(mine.size(), 1.0)


func _cmd_ok() -> bool:
	var t := City.new(Signals.new())
	var ts: Array[City] = [t]
	Cmd.run(ts, t, "stance", ["bogus"])
	var bad := t.stance
	Cmd.run(ts, t, "stance", ["hold"])
	return bad == "advance" and t.stance == "hold"


func _init() -> void:
	var adv := _dist("advance")
	var hold := _dist("hold")
	var ret := _dist("retreat")
	var ok := adv < hold and adv < ret and "hold" in Military.STANCES and _cmd_ok()
	print("STANCE_OK advance=%.0f hold=%.0f retreat=%.0f" % [adv, hold, ret] if ok else "STANCE_FAIL advance=%.0f hold=%.0f retreat=%.0f" % [adv, hold, ret])
	quit(0 if ok else 1)
