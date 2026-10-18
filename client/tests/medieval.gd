extends SceneTree
## Medieval military: archers and knights are trained from the Medieval age, not before, and rifles still wait for Industrial.


func _init() -> void:
	var ok := true
	var got := {}
	for age in [0, 1]:
		var t := City.new(Signals.new())
		t.seed_start()
		t.age = age
		t.peak = 500
		t.train_on = true
		t.coins = 5000.0
		t.bt[Catalog.Id.BARRACKS] = [Vector2i(0, 0)]
		t.train_w["archer"] = 3
		t.train_w["knight"] = 3
		for s in 60:
			Military.econ(t)
		got[age] = Military.counts(t)
	var gate: bool = Ages.unit("archer") == 1 and Ages.unit("knight") == 1 and got[0]["archer"] == 0 and got[0]["knight"] == 0
	var trains: bool = got[1]["archer"] > 0 and got[1]["knight"] > 0 and got[1]["inf"] == 0
	var rock: bool = Military.KIND["archer"]["rng"] > Military.KIND["spear"]["rng"] and Military.KIND["knight"]["spd"] > Military.KIND["spear"]["spd"]
	ok = gate and trains and rock
	print("MEDIEVAL_OK archers=%d knights=%d" % [got[1]["archer"], got[1]["knight"]] if ok else "MEDIEVAL_FAIL gate=%s trains=%s rock=%s %s" % [gate, trains, rock, got])
	quit(0 if ok else 1)
