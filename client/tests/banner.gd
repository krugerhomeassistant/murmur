extends SceneTree
## Age banner: the town raises `age_up` for the tick it enters an age and the flag is the only trace.


func _init() -> void:
	var t := City.new(Signals.new())
	t.seed_start()
	t.age = 0
	t.peak = 500
	t.know = 1.0e9
	t.coins = 1.0e6
	t.stock["planks"] = 100.0
	t.mood = 1.0
	var seen := -1
	for i in 5:
		t.mood = 1.0
		t.tick(1.0)
		if t.age_up >= 0:
			seen = t.age_up
			break
	var raised: bool = seen == 1 and t.age == 1
	print("BANNER_OK age=%d" % t.age if raised else "BANNER_FAIL seen=%d age=%d" % [seen, t.age])
	quit(0 if raised else 1)
