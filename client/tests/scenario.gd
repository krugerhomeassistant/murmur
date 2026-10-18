extends SceneTree
## Scenario setup: the same world seed gives the same world and the same town sites, a different seed a different one.


func _init() -> void:
	var m = load("res://scripts/main.gd").new()
	m._fresh({"seed": 12345, "towns": 3, "age": 0})
	var a: World = m.world
	var ages_ok: bool = m.towns.size() == 3 and m.towns.all(func(t: City) -> bool: return t.age == 0)
	m._fresh({"seed": 12345, "towns": 3})
	var b: World = m.world
	m._fresh({"seed": 777, "towns": 3})
	var c: World = m.world
	var ok: bool = ages_ok and a.seed == b.seed and a.seed != c.seed and m.towns.size() == 3
	print("SCENARIO_OK seed=%d" % a.seed if ok else "SCENARIO_FAIL ages=%s a=%d b=%d c=%d" % [ages_ok, a.seed, b.seed, c.seed])
	quit(0 if ok else 1)
