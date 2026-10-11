extends SceneTree
# Victory rules: conquest by land share, last side standing, hegemony with allies, timer reset, sandbox continue, sync sanitising.
func _world(areas: Array) -> Array[City]:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in areas.size():
		var t := City.new(sig)
		t.town_name = "V%d" % k
		t.terr = Rect2i(0, 0, int(areas[k]), 1)
		t.human = false
		t.pop = 10 + k
		ts.append(t)
	return ts


func _run(v: Victory, ts: Array[City], secs: int) -> void:
	for i in secs:
		v.second(ts)
		if v.winner != "":
			return


func _init() -> void:
	var ok := true
	var year := int(Victory.year_secs())
	# conquest: 80% of the land held for 3 years, and not a second earlier
	var ts := _world([80, 10, 10])
	var v := Victory.new()
	_run(v, ts, int(Victory.CONQUEST_YEARS) * year - 5)
	if v.winner != "":
		ok = false
		print("FAIL early win")
	_run(v, ts, 10)
	if v.winner != "V0" or v.route != "conquest" or not v.fresh:
		ok = false
		print("FAIL conquest: %s %s" % [v.winner, v.route])
	var after := v.winner
	ts[1].terr = Rect2i(0, 0, 500, 1)  # sandbox: the standings move on, the winner stays
	_run(v, ts, 50)
	if v.winner != after:
		ok = false
		print("FAIL winner changed")
	# the timer resets when the share drops
	ts = _world([80, 10, 10])
	v = Victory.new()
	_run(v, ts, year)
	ts[1].terr = Rect2i(0, 0, 200, 1)
	_run(v, ts, 5)
	if float(v.con.get("V0", 1.0)) != 0.0:
		ok = false
		print("FAIL timer reset")
	# last side alive
	ts = _world([40, 40, 40])
	v = Victory.new()
	_run(v, ts, 3)
	ts[1].over = "bankrupt"
	ts[2].over = "bankrupt"
	_run(v, ts, 3)
	if v.winner != "V0" or v.route != "last":
		ok = false
		print("FAIL last: %s %s" % [v.winner, v.route])
	# a lone town never wins
	ts = _world([50])
	v = Victory.new()
	_run(v, ts, 100)
	if v.winner != "":
		ok = false
		print("FAIL lone win")
	# hegemony: top score, 50% of the land with an ally, nobody near 70%
	ts = _world([30, 20, 25, 25])
	ts[0].pop = 500
	ts[0].treaty["V1"] = "alliance"
	ts[1].treaty["V0"] = "alliance"
	v = Victory.new()
	_run(v, ts, int(Victory.HEGEMONY_YEARS) * year + 10)
	if v.winner != "V0" or v.route != "hegemony":
		ok = false
		print("FAIL hegemony: %s %s" % [v.winner, v.route])
	# no alliance, no hegemony
	ts[0].treaty.clear()
	v = Victory.new()
	_run(v, ts, int(Victory.HEGEMONY_YEARS) * year + 10)
	if v.winner != "":
		ok = false
		print("FAIL hegemony without allies")
	# snapshot round trip and hostile input
	var w := Victory.new()
	w.apply(v.brief())
	if w.rows.size() != v.rows.size() or absf(w.clock - v.clock) > 0.1:
		ok = false
		print("FAIL roundtrip")
	w.apply({"w": 5, "r": "bogus", "rows": [1, {"land": "x", "name": 3}, {"land": 99.0}], "con": [1], "heg": {"a": "b"}, "clock": -3.0})
	if w.route != "" or w.rows.size() != 2 or float((w.rows[1] as Dictionary)["land"]) != 1.0 or w.clock != 0.0:
		ok = false
		print("FAIL hostile")
	if not Victory.new().describe() == "" or ts[0].town_name != "V0":
		ok = false
	print("VICTORY_OK" if ok else "VICTORY_FAIL")
	quit(0 if ok else 1)
