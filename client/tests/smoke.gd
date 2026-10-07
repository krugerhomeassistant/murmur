extends SceneTree
# Headless: godot --headless -s tests/smoke.gd  -> SMOKE_OK. Selfcheck + 3 sim-minutes soak.
func _init() -> void:
	var r: String = City.selfcheck()
	assert(r == "SELFCHECK_OK", r)
	var c := City.new(Signals.new())
	c.seed_start()
	for i in 720:
		c.sig.tick(0.25); c.tick(0.25)
	assert(c.citizens.size() >= 0)
	print("SMOKE_OK day=", c.day, " pop=", c.citizens.size())
	quit()
