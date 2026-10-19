extends SceneTree
# Victory rules (no timers): conquest by land share, last side standing, hegemony with a clear lead and allies, sandbox continue, sync sanitising.
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


func _init() -> void:
	var ok := true
	# culture: schooled and cultured people score more than the same number without
	var ct := _world([10])[0]
	ct.pop = 100
	var plain := Victory.score(ct)
	ct.cov["culture"] = 1.0
	ct.cov["edu"] = 1.0
	var cultured := Victory.score(ct)
	ct.policies["free_school"] = true
	if absf(Victory.culture(ct) - 100.0 * Victory.CULTURE_SCORE * 1.2) > 0.01 or cultured <= plain or Victory.score(ct) <= cultured:
		ok = false
		print("FAIL culture: %s %s %s" % [plain, cultured, Victory.culture(ct)])
	# a huge land share alone never wins: only the last side standing does
	var ts := _world([80, 10, 10])
	var v := Victory.new()
	for i in 50:
		v.second(ts)
	if v.winner != "":
		ok = false
		print("FAIL won on land share: %s %s" % [v.winner, v.route])
	ts[1].over = "bankrupt"
	v.second(ts)
	if v.winner != "":
		ok = false
		print("FAIL won with one rival left")
	# just under the share: no win
	ts = _world([69, 31])
	v = Victory.new()
	v.second(ts)
	if v.winner != "":
		ok = false
		print("FAIL win at 69%")
	# last side alive
	ts = _world([40, 40, 40])
	v = Victory.new()
	v.second(ts)
	ts[1].over = "bankrupt"
	ts[2].over = "bankrupt"
	v.second(ts)
	if v.winner != "V0" or v.route != "last":
		ok = false
		print("FAIL last: %s %s" % [v.winner, v.route])
	# a lone town never wins
	ts = _world([50])
	v = Victory.new()
	for i in 100:
		v.second(ts)
	if v.winner != "":
		ok = false
		print("FAIL lone win")
	# a clear lead with allies is not a win either
	ts = _world([30, 20, 25, 25])
	ts[0].pop = 500
	ts[0].treaty["V1"] = "alliance"
	ts[1].treaty["V0"] = "alliance"
	v = Victory.new()
	v.second(ts)
	if v.winner != "":
		ok = false
		print("FAIL hegemony won: %s %s" % [v.winner, v.route])
	# no alliance, no hegemony
	ts = _world([30, 20, 25, 25])
	ts[0].pop = 500
	v = Victory.new()
	v.second(ts)
	if v.winner != "":
		ok = false
		print("FAIL hegemony without allies")
	# a narrow lead does not win, even with allies
	ts = _world([30, 20, 25, 25])
	ts[0].treaty["V1"] = "alliance"
	ts[1].treaty["V0"] = "alliance"
	v = Victory.new()
	v.second(ts)
	if v.winner != "":
		ok = false
		print("FAIL narrow lead won")
	# snapshot round trip and hostile input
	var w := Victory.new()
	w.apply(v.brief())
	if w.rows.size() != v.rows.size() or absf(w.clock - v.clock) > 0.1:
		ok = false
		print("FAIL roundtrip")
	w.apply({"w": 5, "r": "bogus", "rows": [1, {"land": "x", "name": 3}, {"land": 99.0}], "heg": {"a": "b"}, "clock": -3.0})
	if w.route != "" or w.rows.size() != 2 or float((w.rows[1] as Dictionary)["land"]) != 1.0 or w.clock != 0.0:
		ok = false
		print("FAIL hostile")
	if not Victory.new().describe() == "":
		ok = false
	print("VICTORY_OK" if ok else "VICTORY_FAIL")
	quit(0 if ok else 1)
