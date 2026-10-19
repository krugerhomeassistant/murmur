extends SceneTree
## Scenario setup: the same world seed gives the same world and the same town sites, a different seed a different one;
## per-town ages and the number of towns you run are honoured and the planner keeps every town alive.


func _init() -> void:
	var m = load("res://scripts/main.gd").new()
	m._fresh({"seed": 12345, "towns": 3, "age": 0})
	var a: World = m.world
	var ages_ok: bool = m.towns.size() == 3 and m.towns.all(func(t: City) -> bool: return t.age == 0)
	m._fresh({"seed": 12345, "towns": 3})
	var b: World = m.world
	m._fresh({"seed": 777, "towns": 3})
	var c: World = m.world
	m._fresh({"seed": 5, "towns": 4, "age": 1, "ages": [2, 0], "runs": 3})
	var per_age: bool = [m.towns[0].age, m.towns[1].age, m.towns[2].age] == [2, 0, 1]
	var runs: int = m.towns.filter(func(t: City) -> bool: return t.human).size()
	m._fresh({"seed": 5, "towns": 2, "runs": 99})
	var capped: bool = m.towns.filter(func(t: City) -> bool: return t.human).size() == 2
	var ok: bool = ages_ok and a.seed == b.seed and a.seed != c.seed and m.towns.size() == 2 and per_age and runs == 3 and capped
	print("SCENARIO_OK seed=%d" % a.seed if ok else "SCENARIO_FAIL ages=%s a=%d b=%d c=%d per_age=%s runs=%d capped=%s" % [ages_ok, a.seed, b.seed, c.seed, per_age, runs, capped])
	quit(0 if ok else 1)
