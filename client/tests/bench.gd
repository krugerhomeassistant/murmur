extends SceneTree
# Headless: godot --headless --path client -s tests/bench.gd  -> per-tick cost as the town grows.
func _init() -> void:
	var c := City.new(Signals.new())
	c.seed_start()
	for blk in 6:
		var t0 := Time.get_ticks_usec()
		var mx := 0.0
		for i in 1200:
			var a := Time.get_ticks_usec()
			c.sig.tick(0.25); c.tick(0.25)
			mx = maxf(mx, Time.get_ticks_usec() - a)
		print("day=%d pop=%d cit=%d avg=%.0fus max=%.0fus" % [c.day, c.pop, c.citizens.size(), (Time.get_ticks_usec() - t0) / 1200.0, mx])
	quit()
