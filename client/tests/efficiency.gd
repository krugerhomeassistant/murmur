extends SceneTree
# Efficiency: mood scales construction speed instead of switching it off; only mood 0 stops it.
func _progress(mood: float) -> float:
	var sig := Signals.new()
	var c := City.new(sig)
	c.seed_start()
	c.next_fire = 9999.0
	c.coins = 100000.0
	var cell := -1
	for i in c.cells:
		if c.grid[i] == City.T.EMPTY and c.water[i] == 0 and c._road_next_to(i) >= 0:
			cell = i
			break
	if cell < 0:
		return -1.0
	c.grid[cell] = City.T.RES
	c._scan()
	if c.connected[cell] == 0:
		return -1.0
	c.build[cell] = 0.01
	c.mood = mood
	c._grow()
	return c.build[cell] - 0.01


func _init() -> void:
	var ok := true
	var sig := Signals.new()
	var c := City.new(sig)
	for m in [0.0, 0.1, 0.25, 0.5, 0.9]:
		c.mood = m
		print("mood %.2f -> efficiency %.2f" % [m, c.efficiency()])
	c.mood = 0.0
	if c.efficiency() != 0.0:
		ok = false
		print("FAIL efficiency at mood 0")
	c.mood = 0.05
	if c.efficiency() <= 0.0:
		ok = false
		print("FAIL efficiency 0 above mood 0")
	c.mood = 0.5
	if c.efficiency() != 1.0:
		ok = false
		print("FAIL full efficiency at 0.5")
	var lo := _progress(0.15)
	var hi := _progress(0.6)
	var zero := _progress(0.0)
	if lo < 0.0 or hi < 0.0:
		print("note: no connected zone in the seed town, construction check skipped")
	else:
		if not (lo > 0.0 and lo < hi):
			ok = false
			print("FAIL construction at low mood: %.4f vs %.4f" % [lo, hi])
		if absf(zero) > 0.000001:
			ok = false
			print("FAIL construction at mood 0: %.4f" % zero)
	print("EFFICIENCY_OK" if ok else "EFFICIENCY_FAIL")
	quit(0 if ok else 1)
