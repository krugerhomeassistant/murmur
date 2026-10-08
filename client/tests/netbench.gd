extends SceneTree
# Headless: cost of the growth-only net re-solve (keep path) on a grown town. Prints us per call.
func _init() -> void:
	var sig := Signals.new()
	var c := City.new(sig)
	c.rng.seed = 20261007
	c._gen_ore()
	c.human = false
	c.seed_start()
	for i in 20000:
		sig.tick(0.1)
		c.tick(0.1)
	c._scan()
	var n := 3000
	var wide: bool = c._net_solve.get_argument_count() > 5
	var t0 := Time.get_ticks_usec()
	for k in n:
		for m in City.NETS:
			var nc: Dictionary = c.net_cache[m]
			var a: Array = [m, c._nl(m), c.net_reach[m], true, float(nc["sup"])]
			if wide:
				a.append(nc)
			c.callv("_net_solve", a)
	print("pop=%d  %.1f us per growth re-solve (3 nets)" % [c.pop, (Time.get_ticks_usec() - t0) / float(n)])
	quit()
