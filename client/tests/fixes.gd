extends SceneTree
# Headless: godot --headless --path client -s tests/fixes.gd -> FIXES_OK. Weather travels in snapshots; recovery "no" is not a survived disaster.
func _init() -> void:
	var s1 := Signals.new()
	var a := City.new(s1)
	s1.set_weather("storm", 50.0)
	var d := a.to_dict()
	var s2 := Signals.new()
	var b := City.new(s2)
	b.from_dict(d)
	var ok := s2.weather() == "storm"
	d["wx"] = ["x", "bad"]
	b.from_dict(d)  # hostile weather value must not crash
	b.petitions = [{"kind": "recover", "cost": 1e9}]
	b.answer(0, false)
	ok = ok and b.disasters_survived == 0
	print("FIXES_OK" if ok else "FIXES_FAIL")
	quit()
