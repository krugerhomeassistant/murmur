extends SceneTree
# Planner mining: an unattended town with ore in its land zones mines, then builds a foundry for the ore.
func _init() -> void:
	var sig := Signals.new()
	var c := City.new(sig)
	c.town_name = "Pm"
	c.human = false
	c.seed_start()
	c.peak = 500.0
	for step in 60000:
		sig.tick(0.1)
		c.tick(0.1)
		if step % 200 == 0:
			c.coins = maxf(c.coins, 1500.0)
	var mines := 0
	for i in City.W * City.H:
		if c.grid[i] == Catalog.Id.MINE:
			mines += 1
	var f := (c.bt.get(Catalog.Id.FOUNDRY, []) as Array).size()
	print("pop %d mines %d foundries %d ore %.1f metal %.1f" % [c.pop, mines, f, float(c.stock.get("ore", 0.0)), float(c.stock.get("metal", 0.0))])
	assert(mines > 0, "planner never zoned a mine")
	assert(f > 0, "planner never built a foundry")
	print("PMINE_OK mines=%d foundries=%d" % [mines, f])
	quit()
