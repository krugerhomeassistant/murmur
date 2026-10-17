extends SceneTree
## Wood and tools chain: lumber camps need forest, toolworks turn wood and metal into tools, stocked tools lift production.


func _town() -> City:
	var c := City.new(Signals.new())
	c.seed_start()
	c.ground.resize(City.W * City.H)
	c.ground.fill(World.K.PLAIN)
	c.coins = 5000.0
	c.pop = 60
	return c


func _place(c: City, id: int) -> int:
	for i in c.cells:
		if c.grid[i] == Catalog.Id.EMPTY and c.water[i] == 0 and c._road_next_to(i) >= 0:
			c.grid[i] = id
			c._scan()
			return i
	return -1


func _init() -> void:
	var ok := true
	var c := _town()
	for k in ["wood", "tools"]:
		if not c.stock.has(k) or not Market.GOODS.has(k):
			ok = false
			print("FAIL %s missing from stock or market" % k)
	if c._lumber_site():  # the planner must not pick a camp it cannot place (it stalled every other service)
		ok = false
		print("FAIL lumber site without forest")
	# a lumber camp in a forest cuts wood, one on bare land does not
	var camp := _place(c, Catalog.Id.LUMBER)
	for y in range(maxi(camp / City.W - 5, 0), mini(camp / City.W + 6, City.H)):
		for x in range(maxi(camp % City.W - 5, 0), mini(camp % City.W + 6, City.W)):
			c.ground[y * City.W + x] = World.K.PLAIN
	c.wood_sig = -1
	if c._wood_rate(1.0) != 0.0:
		ok = false
		print("FAIL wood without forest")
	for i in 6:
		c.ground[camp + i + 1] = World.K.FOREST
		c.grid[camp + i + 1] = Catalog.Id.EMPTY
	c.wood_sig = -1
	var trees := c._forest_near(camp)
	if trees < 4 or absf(c._wood_rate(1.0) - trees * 0.02) > 0.001:
		ok = false
		print("FAIL wood rate %s" % c._wood_rate(1.0))
	# toolworks: wood and metal become tools
	_place(c, Catalog.Id.TOOLWORKS)
	c.jobs = 100
	c.employed = 100
	c.stock["wood"] = 50.0
	c.stock["metal"] = 50.0
	c.stock["tools"] = 0.0
	c._trade(1.0)
	if float(c.stock["tools"]) <= 0.0 or float(c.stock["metal"]) >= 50.0:
		ok = false
		print("FAIL toolworks: tools %s metal %s" % [c.stock["tools"], c.stock["metal"]])
	# stocked tools raise output, no tools leave it at baseline
	var base := _town()
	base.jobs = 100
	base.employed = 100
	base.farm_jobs = 40
	base.stock["tools"] = 0.0
	base.coins = 0.0  # cannot buy any
	base._trade(1.0)
	var plain: float = base.prod_rate["crops"]
	var with := _town()
	with.jobs = 100
	with.employed = 100
	with.farm_jobs = 40
	with.stock["tools"] = 100.0
	with._trade(1.0)
	if float(with.prod_rate["crops"]) <= plain * 1.1:
		ok = false
		print("FAIL tools bonus: %s vs %s" % [with.prod_rate["crops"], plain])
	# sawmill: wood becomes planks, planks speed up building sites, no planks leaves the speed alone
	var sm := _town()
	sm.ground.fill(World.K.PLAIN)
	_place(sm, Catalog.Id.SAWMILL)
	sm.jobs = 100
	sm.employed = 100
	sm.coins = 0.0
	sm.stock["wood"] = 50.0
	sm.stock["planks"] = 0.0
	sm._trade(1.0)
	if float(sm.stock["planks"]) <= 0.0 or float(sm.stock["wood"]) >= 50.0:
		ok = false
		print("FAIL sawmill: planks %s wood %s" % [sm.stock["planks"], sm.stock["wood"]])
	var site := -1
	for i in sm.zones:
		site = i
		break
	if site >= 0:
		sm.lvl[site] = 0
		sm.build[site] = 0.1
		sm.stock["planks"] = 50.0
		sm._trade(1.0)
		if sm.plank_mult <= 1.0:
			ok = false
			print("FAIL planks should speed up a building site: %s" % sm.plank_mult)
		sm.stock["planks"] = 0.0
		sm.stock["wood"] = 0.0
		sm._trade(1.0)
		if sm.plank_mult != 1.0:
			ok = false
			print("FAIL no planks, no bonus: %s" % sm.plank_mult)
	else:
		print("NOTE no zone in the start town: site check skipped")
	print("TOOLS_OK" if ok else "TOOLS_FAIL")
	quit()
