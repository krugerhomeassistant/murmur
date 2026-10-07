extends SceneTree
# Farm variants: fish farms need water, greenhouses grow in winter, the planner picks variants.
func _init() -> void:
	var c := City.new(Signals.new())
	c.seed_start()
	c.peak = 500.0
	c.coins = 5000.0
	var cells: Array[int] = []  # empty, dry tiles beside a road
	for i in City.W * City.H:
		if c.owns(i % City.W, i / City.W) and c.grid[i] == 0 and c.water[i] == 0 and c._road_next_to(i) >= 0:
			cells.append(i)
	var dry := -1
	for i in cells:
		if not c.wet_next(i % City.W, i / City.W):
			dry = i
			break
	assert(dry >= 0, "no dry roadside tile")
	assert(not c.place(dry % City.W, dry / City.W, Catalog.Id.FISHFARM), "fish farm placed away from water")
	var wet := -1
	for i in cells:  # make water next to a roadside tile, keeping the tile itself dry
		var x := i % City.W
		var y := i / City.W
		if i != dry and c.grid[i] == 0:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if c.inside(x + d.x, y + d.y) and c.grid[(y + d.y) * City.W + x + d.x] == 0 and c.set_water(x + d.x, y + d.y, 1):
					wet = i
					break
		if wet >= 0:
			break
	assert(wet >= 0, "could not make a waterside tile")
	assert(c.place(wet % City.W, wet / City.W, Catalog.Id.FISHFARM), "fish farm refused beside water")
	var gh := -1
	for i in cells:
		if c.grid[i] == 0 and i != wet and c.water[i] == 0:
			assert(c.place(i % City.W, i / City.W, Catalog.Id.GREENHOUSE), "greenhouse refused")
			gh = i
			break
	c.lvl[wet] = 1  # built
	c.lvl[gh] = 1
	c.flush()
	assert(c.green_jobs > 0 and c.fish_jobs > 0, "variant jobs not counted")
	var winter := 0
	for k in Civics.SEASONS.size():
		if float(Civics.SEASONS[k]["harvest"]) < float(Civics.SEASONS[winter]["harvest"]):
			winter = k
	c.season = winter
	c.employed = c.jobs
	c._trade(0.0)
	assert(float(c.flow["crops"]) > 0.0, "greenhouse grew nothing in winter")
	assert(float(c.flow["food"]) > 0.0, "fish farm made no food")
	var seen := {}
	for i in 300:
		seen[c._farm_variant()] = true
	assert(seen.has(Catalog.Id.FARM) and seen.has(Catalog.Id.ORCHARD) and seen.has(Catalog.Id.GREENHOUSE), "planner variants: %s" % str(seen.keys()))
	print("FARMS_OK variants=%d" % seen.size())
	quit()
