extends SceneTree
## Ancient military: barracks and spearmen exist from the first age; rifles wait for the Industrial age.


func _init() -> void:
	var t := City.new(Signals.new())
	t.seed_start()
	t.age = 0
	t.peak = 500
	t.train_on = true
	t.coins = 5000.0
	t.bt[Catalog.Id.BARRACKS] = [Vector2i(0, 0)]  # a barracks standing, whatever the map
	t.train_w["spear"] = 3
	for s in 40:
		Military.econ(t)
	var spears := Military.counts(t)["spear"] as int
	var rifles := Military.counts(t)["inf"] as int
	var ok := t.unlocked(Catalog.Id.BARRACKS) and Ages.unit("spear") == 0 and Ages.unit("inf") == 6 and spears > 0 and rifles == 0
	print("SPEAR_OK spears=%d" % spears if ok else "SPEAR_FAIL spears=%d rifles=%d unlocked=%s" % [spears, rifles, t.unlocked(Catalog.Id.BARRACKS)])
	quit(0 if ok else 1)
