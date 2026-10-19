extends SceneTree
## Galleys: a Medieval warship housed at the port, not available in the Ancient age.


func _init() -> void:
	var got := {}
	for age in [0, 4]:
		var t := City.new(Signals.new())
		t.seed_start()
		t.age = age
		t.peak = 500
		t.train_on = true
		t.coins = 5000.0
		t.bt[Catalog.Id.PORT] = [Vector2i(0, 0)]
		t.train_w["galley"] = 3
		for s in 60:
			Military.econ(t)
		got[age] = Military.counts(t)["galley"]
	var ok: bool = Ages.unit("galley") == 4 and Military.KIND["galley"]["t"] == "ship" and got[0] == 0 and got[4] > 0
	print("GALLEY_OK galleys=%d" % got[4] if ok else "GALLEY_FAIL %s" % got)
	quit(0 if ok else 1)
