extends SceneTree
# Empire rules: sides, sends, balancing (no money created), bulk settings through Cmd, dashboard window runs.
func _towns(n: int, human: bool) -> Array[City]:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in n:
		var t := City.new(sig)
		t.town_name = "E%d" % k
		t.gpos = Vector2i(k, 0)
		t.human = human
		ts.append(t)
	for t in ts:
		for o in ts:
			if o != t:
				t.partners.append(o)
	return ts


func _sum(ts: Array[City]) -> float:
	var s := 0.0
	for t in ts:
		s += t.coins
	return s


func _init() -> void:
	var ok := true
	var ts := _towns(4, false)
	ts[3].human = true  # a rival the player does not run
	var mine := Empire.mine(ts, ts[0])
	if mine.size() != 3 or ts[3] in mine:
		ok = false
		print("FAIL sides: %d" % mine.size())
	ts[0].coins = 3000.0
	ts[1].coins = 20.0
	ts[2].coins = 100.0
	ts[3].coins = 50.0
	var before := _sum(ts)
	var moved := Empire.rebalance(mine, 200.0)
	if absf(_sum(ts) - before) > 0.001 or moved <= 0.0 or ts[3].coins != 50.0 or ts[0].coins >= 3000.0 or ts[1].coins <= 20.0:
		ok = false
		print("FAIL rebalance moved %s sum %s vs %s" % [moved, _sum(ts), before])
	if Empire.rebalance(mine, 200.0) > 0.0 and ts[0].coins < 600.0:
		ok = false
		print("FAIL rebalance drained a poor donor")
	var c := ts[0].coins
	if Cmd.run(ts, ts[0], "send", [1, 100]) != 100 or ts[0].coins != c - 100.0:
		ok = false
		print("FAIL send")
	if Cmd.run(ts, ts[0], "send", [3, 100]) != null and Cmd.run(ts, ts[0], "send", [3, 100]) != 0:
		ok = false
		print("FAIL send to another side")
	if Cmd.run(ts, ts[0], "send", [0, 100]) != null or Cmd.run(ts, ts[0], "send", [1, -5]) != null:
		ok = false
		print("FAIL send validation")
	if Cmd.run(ts, ts[0], "apply_all", ["auto_mode", 0]) != 3 or ts[1].auto_mode != 0 or ts[2].auto_mode != 0 or ts[3].auto_mode == 0:
		ok = false
		print("FAIL apply_all auto_mode")
	if Cmd.run(ts, ts[0], "apply_all", ["tax", "c", 0.11]) != 3 or absf(ts[2].tax_c - 0.11) > 0.0001 or absf(ts[3].tax_c - 0.11) < 0.0001 and ts[3].tax_c == 0.11:
		ok = false
		print("FAIL apply_all tax")
	if Cmd.run(ts, ts[0], "apply_all", ["coins", 5]) != null or Cmd.run(ts, ts[0], "apply_all", ["tax", "c"]) != null:
		ok = false
		print("FAIL apply_all validation")
	var row := Empire.row(ts, ts[0])
	if row["name"] != "E0" or not row.has("flags"):
		ok = false
		print("FAIL row")
	# dashboard window inside the real game (spectate = empire mode)
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.start_game({"name": "T", "towns": 3, "river": 0, "mood": 1, "diff": 1, "land": 1, "auto": 2, "policy": true, "expand": true, "guide": false, "spectate": true})
	for i in 40:
		await process_frame
	var w: PanelContainer = m.hud.wins["empire"]
	if not w.visible or m.hud.emp_cells.size() != 3:
		ok = false
		print("FAIL empire window: visible %s rows %d" % [w.visible, m.hud.emp_cells.size()])
	m.hud._empire_sort(2)
	for i in 20:
		await process_frame
	if m.hud.emp_cells.size() != 3:
		ok = false
		print("FAIL empire sort rebuild")
	print("EMPIRE_OK" if ok else "EMPIRE_FAIL")
	quit(0 if ok else 1)
