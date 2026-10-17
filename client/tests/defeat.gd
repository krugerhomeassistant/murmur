extends SceneTree
# Defeat: a player who loses every town can keep spectating (planner world, Tab/follow) or quit; one live town is no defeat.
func _init() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.bench_seed = 20261017
	m.start_game({"name": "T", "towns": 3, "river": 0, "mood": 1, "diff": 1, "land": 1, "auto": 2, "policy": true, "expand": true, "guide": false, "spectate": false})
	var ok := true
	m.towns[0].human = true
	m.towns[1].human = true
	m.towns[2].human = false
	if m.defeated():
		ok = false
		print("FAIL defeated with live towns")
	m.towns[0].over = "bankrupt"
	if m.defeated():
		ok = false
		print("FAIL defeated with one town left")
	m.towns[1].over = "bankrupt"
	if not m.defeated():
		ok = false
		print("FAIL not defeated after losing every town")
	m.keep_watching()
	if m.defeated() or not m.watching or not m.spectating() or not m.follow:
		ok = false
		print("FAIL keep_watching state")
	if not m.towns.all(func(t: City) -> bool: return not t.human):
		ok = false
		print("FAIL dead towns still human")
	print("DEFEAT_OK" if ok else "DEFEAT_FAIL")
	quit(0 if ok else 1)
