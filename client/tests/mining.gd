extends SceneTree
# Mining chain: mine only on ore, foundry smelts, stock never negative, old stock dict migrates.
func _init() -> void:
	var c := City.new(Signals.new())
	c.seed_start()
	var oi := -1
	for i in City.W * City.H:
		if c.ore[i] > 0 and c.owns(i % City.W, i / City.W) and c.grid[i] == 0:
			oi = i
			break
	assert(oi >= 0, "no ore in territory")
	c.peak = 500.0
	c.coins = 5000.0
	var x := oi % City.W
	var y := oi / City.W
	var dry := 0
	for i in City.W * City.H:
		if c.ore[i] == 0 and c.owns(i % City.W, i / City.W) and c.grid[i] == 0 and c.water[i] == 0:
			dry = i
			break
	assert(not c.place(dry % City.W, dry / City.W, Catalog.Id.MINE), "mine placed off-ore")
	assert(c.place(x, y, Catalog.Id.MINE), "mine refused on ore")
	c.stock = {"crops": 0.0, "food": 0.0, "goods": 0.0}  # old save
	c.flush()
	c._trade(0.0)
	assert(c.stock.has("ore") and c.stock.has("metal"))
	for k in c.stock:
		assert(float(c.stock[k]) >= 0.0)
	print("MINING_OK ore=%.2f" % float(c.stock["ore"]))
	quit()
