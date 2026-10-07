extends SceneTree
# Shared river: the water row at the east border of town A matches town B's at its west border.
func _init() -> void:
	var a := City.new(Signals.new())
	var b := City.new(Signals.new())
	var edge := 0.5
	a.river_plan = {"horiz": true, "a": 0.4, "b": edge}
	b.river_plan = {"horiz": true, "a": edge, "b": 0.6}
	a.set_start(48, 32)
	b.set_start(48, 32)
	var ya := -1
	var yb := -1
	for y in City.H:
		if a.water[y * City.W + a.terr.end.x - 1] == 1 and ya < 0:
			ya = y
		if b.water[y * City.W + b.terr.position.x] == 1 and yb < 0:
			yb = y
	assert(ya >= 0 and yb >= 0 and absi(ya - yb) <= 1, "river misaligned %d vs %d" % [ya, yb])
	var wet := 0
	for i in City.W * City.H:
		wet += a.water[i]
	assert(wet > 100)
	print("RIVERS_OK ya=%d yb=%d wet=%d" % [ya, yb, wet])
	quit()
