extends SceneTree
# The Market window (chart, stats, towns, tape) fills in for every good and timeframe without errors.
func _init() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.start_game({"name": "T", "towns": 3, "river": 0, "mood": 1, "diff": 1, "land": 1, "auto": 2, "policy": true, "expand": true, "guide": false, "spectate": true})
	var h = m.hud
	for i in 10:
		await process_frame
	for i in 1500:
		m.sig.tick(0.1)
		for c in m.towns:
			c.tick(0.1)
	m.sig.mk.shock_by({"food": 1.3})
	h.win_open["market"] = true
	var errs: Array[String] = []
	for k in Market.GOODS:
		for tf in Hud.MK_TF.size():
			h.mk_sel = k
			h.mk_tf = tf
			h._market_refresh(m.city)
			await process_frame
			if h.mk_stats.get_parsed_text().find("$") < 0 or h.mk_tape.text == "":
				errs.append("window empty for %s/%d" % [k, tf])
	if (m.sig.mk.candles["food"] as Array).size() < 5:
		errs.append("no candles after 150 s")
	print("MARKETWIN_OK" if errs.is_empty() else "MARKETWIN_FAIL %s" % [errs])
	quit()
