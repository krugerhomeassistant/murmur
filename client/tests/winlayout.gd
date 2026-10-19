extends SceneTree
## Floating windows never overlap: stacked panels are moved apart and edges snap while dragging.


func _init() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.start_game({"name": "T", "towns": 2, "river": 0, "mood": 1, "diff": 1, "land": 1, "auto": 2, "policy": false, "expand": false, "guide": false, "spectate": true})
	var h = m.hud
	for i in 20:
		await process_frame
	var keys := ["build", "info", "mayor", "market", "empire"]
	for k in keys:
		h._set_open(k, true)
		(h.wins[k] as PanelContainer).position = Vector2(300, 200)  # every window dropped on the same spot
	for i in 5:
		await process_frame
	h._clamp_all()
	var ok := true
	for a in keys:
		for b in keys:
			if a < b and h._rect(h.wins[a]).intersects(h._rect(h.wins[b])):
				ok = false
				print("FAIL overlap %s %s" % [a, b])
	var p: PanelContainer = h.wins["build"]
	var q: Rect2 = h._rect(h.wins["info"])
	p.position = Vector2(q.end.x + 6.0, q.position.y + 3.0)  # near the right edge of another window
	h._snap(p)
	if absf(p.position.x - q.end.x) > 0.5:
		ok = false
		print("FAIL snap x %s vs %s" % [p.position.x, q.end.x])
	print("WINLAYOUT_OK" if ok else "WINLAYOUT_FAIL")
	quit(0 if ok else 1)
