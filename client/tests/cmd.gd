extends SceneTree
# Headless: godot --headless --path client -s tests/cmd.gd -> CMD_OK. Valid commands act; malformed or hostile ones are rejected without effect.
func _init() -> void:
	var c := City.new(Signals.new())
	c.seed_start()
	var ts: Array[City] = [c]
	var T = Catalog.Id
	var ctr := c.terr.get_center()
	c.coins = 5000.0
	var spot := Vector2i(-1, -1)
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var p := ctr + Vector2i(dx, dy)
			if spot.x < 0 and c.at(p.x, p.y) == T.EMPTY and c.owns(p.x, p.y):
				spot = p
	var ok := spot.x >= 0
	ok = ok and Cmd.run(ts, c, "place", [spot.x, spot.y, T.ROAD]) == true and c.at(spot.x, spot.y) == T.ROAD
	ok = ok and Cmd.run(ts, c, "place", [spot.x, spot.y, 99999]) == null  # unknown building id
	ok = ok and Cmd.run(ts, c, "place", [1.5, 2, T.ROAD]) == null  # float coordinate
	ok = ok and Cmd.run(ts, c, "place", [-1, 0, T.ROAD]) == null and Cmd.run(ts, c, "place", [100000, 0, T.ROAD]) == null
	ok = ok and Cmd.run(ts, c, "place", ["x", 0, T.ROAD]) == null and Cmd.run(ts, c, "place", []) == null
	ok = ok and Cmd.run(ts, c, "bulldoze", [spot.x, spot.y]) == true and c.at(spot.x, spot.y) == T.EMPTY
	ok = ok and Cmd.run(ts, c, "tax", ["r", 9.0]) == true and is_equal_approx(c.tax_r, 0.5)  # clamped, not trusted
	ok = ok and Cmd.run(ts, c, "tax", ["z", 0.1]) == null and Cmd.run(ts, c, "tax", ["r", "lots"]) == null
	ok = ok and Cmd.run(ts, c, "policy", ["no_such_policy", true]) == null
	ok = ok and Cmd.run(ts, c, "policy", [Catalog.POLICIES.keys()[0], true]) == true
	ok = ok and Cmd.run(ts, c, "loan", [99]) == null and Cmd.run(ts, c, "loan", [-1]) == null
	ok = ok and Cmd.run(ts, c, "train_w", ["inf", 99]) == true and c.train_w["inf"] == 3
	ok = ok and Cmd.run(ts, c, "train_w", ["__proto__", 1]) == null
	ok = ok and Cmd.run(ts, c, "auto_mode", [7]) == null and Cmd.run(ts, c, "auto_mode", [1]) == true and c.auto_mode == 1
	ok = ok and Cmd.run(ts, c, "answer", [5, true]) == null  # no such petition
	ok = ok and Cmd.run(ts, c, "diplo", [0, "gift"]) == null  # cannot target yourself
	ok = ok and Cmd.run(ts, c, "diplo", [9, "gift"]) == null and Cmd.run(ts, c, "diplo", [0, "set_coins"]) == null
	ok = ok and Cmd.run(ts, c, "set", ["coins", 1e9]) == null and Cmd.run(ts, c, "", []) == null  # no generic setter
	print("CMD_OK" if ok else "CMD_FAIL")
	quit(0 if ok else 1)
