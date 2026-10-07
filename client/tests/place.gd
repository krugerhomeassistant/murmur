extends SceneTree
# Cost of place(): painting roads/zones should stay cheap.
func _init() -> void:
	var c := City.new(Signals.new())
	c.seed_start()
	c.coins = 1e6
	c.peak = 5000.0
	var t := c.terr
	var n := 0
	var t0 := Time.get_ticks_usec()
	for x in range(t.position.x, t.end.x):
		for y in range(t.position.y, mini(t.end.y, t.position.y + 6)):
			c.place(x, y, Catalog.Id.ROAD if (x + y) % 3 == 0 else Catalog.Id.RES)
			n += 1
	print("place avg %.0fus over %d" % [(Time.get_ticks_usec() - t0) / float(n), n])
	quit()
