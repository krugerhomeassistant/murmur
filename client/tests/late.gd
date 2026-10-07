extends SceneTree
# Late-game profile: keep the treasury topped up so the planner keeps building, then time each _second step.
func _init() -> void:
	var c := City.new(Signals.new())
	c.seed_start()
	c.peak = 3000.0
	var fs := ["_scan", "_crime", "_land", "_tribes", "_traffic", "_grow", "_planner", "_net", "_second"]
	for blk in 12:
		for i in 4000:
			if i % 200 == 0:
				c.coins = maxf(c.coins, 5000.0)
			c.sig.tick(0.25); c.tick(0.25)
		var line := "day=%d pop=%d blds=%d |" % [c.day, c.pop, c.blds]
		for f in fs:
			var t0 := Time.get_ticks_usec()
			for k in 5:
				c.call(f)
			line += " %s=%.0f" % [f, (Time.get_ticks_usec() - t0) / 5.0]
		var t1 := Time.get_ticks_usec()
		for k in 100:
			c._move(0.1)
		print(line, " _move=", (Time.get_ticks_usec() - t1) / 100.0)
	quit()
