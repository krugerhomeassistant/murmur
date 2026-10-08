extends SceneTree
# Headless: godot --headless --path client -s tests/focus.gd -> FOCUS_OK. Mayor's focus commands validate; hostile values are neutral; council focus follows prices and threat.
func _init() -> void:
	var c := City.new(Signals.new())
	var ts: Array[City] = [c]
	var ok := c.foc("mining") == 1.0
	c.focus["mining"] = "x"
	ok = ok and c.foc("mining") == 1.0
	c.focus["mining"] = 99
	ok = ok and c.foc("mining") == 2.0
	ok = ok and Cmd.run(ts, c, "focus", ["military", 30]) == true and absf(c.foc("military") - 0.3) < 0.001 and not c.auto_focus
	ok = ok and Cmd.run(ts, c, "focus", ["bogus", 30]) == null and Cmd.run(ts, c, "focus", ["military", 1.5]) == null
	ok = ok and Cmd.run(ts, c, "focus", ["military", 9999]) == true and c.foc("military") == 2.0
	ok = ok and Cmd.run(ts, c, "auto_focus", [true]) == true and c.auto_focus
	c.price_loc["ore"] = 1.6
	c._auto_focus()
	ok = ok and absf(c.foc("mining") - 2.0) < 0.001
	var d := c.to_dict()
	var c2 := City.new(Signals.new())
	c2.from_dict(d)
	ok = ok and c2.foc("mining") == 2.0
	print("FOCUS_OK" if ok else "FOCUS_FAIL")
	quit()
