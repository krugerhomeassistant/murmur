extends SceneTree
# Windows can pop out into their own OS window and dock back; the layout is remembered.
func _init() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.start_game({"name": "T", "towns": 3, "river": 0, "mood": 1, "diff": 1, "land": 1, "auto": 2, "policy": true, "expand": true, "guide": false, "spectate": true})
	var h = m.hud
	var ok := true
	for i in 20:
		await process_frame
	var p: PanelContainer = h.wins["empire"]
	h._popout("empire")
	await process_frame
	if not (p.get_parent() is Window) or not h.pop_wins.has("empire") or (h.win_bar["empire"] as Control).visible:
		ok = false
		print("FAIL pop out")
	for i in 20:
		await process_frame  # the dashboard keeps refreshing inside the other window
	if h.emp_cells.size() != 3 or p.size.x < 100.0:
		ok = false
		print("FAIL popped window content: rows %d size %s" % [h.emp_cells.size(), str(p.size)])
	var cf := ConfigFile.new()
	cf.load(h.UI_FILE)
	if not bool(cf.get_value("empire", "popped", false)):
		ok = false
		print("FAIL layout not saved")
	h._set_open("empire", false)
	if (h.pop_wins["empire"] as Window).visible:
		ok = false
		print("FAIL close did not hide the popped window")
	h._set_open("empire", true)
	h._dock("empire")
	await process_frame
	if p.get_parent() != h or h.pop_wins.has("empire") or not (h.win_bar["empire"] as Control).visible:
		ok = false
		print("FAIL dock")
	cf = ConfigFile.new()
	cf.load(h.UI_FILE)
	if bool(cf.get_value("empire", "popped", true)):
		ok = false
		print("FAIL dock not saved")
	cf.set_value("army", "popped", true)  # a saved layout with a popped window is restored on load
	cf.set_value("army", "pos", Vector2(220, 80))
	cf.set_value("army", "open", true)
	cf.save(h.UI_FILE)
	h._load_ui()
	for i in 5:
		await process_frame
	if not h.pop_wins.has("army"):
		ok = false
		print("FAIL restore popped window")
	h._reset_wins()  # reset docks everything
	await process_frame
	if not h.pop_wins.is_empty():
		ok = false
		print("FAIL reset did not dock")
	print("POPOUT_OK" if ok else "POPOUT_FAIL")
	quit(0 if ok else 1)
