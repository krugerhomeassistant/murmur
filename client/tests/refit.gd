extends SceneTree
## Refitting a building to the town's era: costs coins and materials, needs a free crew, the building produces nothing meanwhile,
## then it steps up one era; buildings left behind hold less.


func _init() -> void:
	var c := City.new(Signals.new())
	c.next_fire = 9999.0
	c.ev_t = 9999.0
	c.auto_mode = 0
	c.water.fill(0)
	c.coins = 1.0e5
	Ages.set_age(c, 0)
	c.place(City.OX + 5, City.OY + 6, Catalog.Id.ROAD)
	c.place(City.OX + 5, City.OY + 5, Catalog.Id.RES)
	c.place(City.OX + 7, City.OY + 6, Catalog.Id.ROAD)
	c.place(City.OX + 7, City.OY + 5, Catalog.Id.RES)
	for i in 1200:
		c.tick(0.1)
	var a := (City.OY + 5) * City.W + City.OX + 5
	var b := (City.OY + 5) * City.W + City.OX + 7
	var ok := true
	Ages.set_age(c, 6)
	c._scan()
	var behind := c.housing
	c.stock["planks"] = 0.0
	if c.refit_block(a) == "":
		ok = false
		print("FAIL refit without materials")
	c.stock["planks"] = 100.0
	c.stock["tools"] = 100.0
	c.stock["metal"] = 100.0
	var coins0 := c.coins
	if not c.refit(City.OX + 5, City.OY + 5) or c.coins >= coins0 or c.fit[a] <= 0.0:
		ok = false
		print("FAIL refit start")
	if c.refit_block(b) == "" or c.refit(City.OX + 7, City.OY + 5):
		ok = false
		print("FAIL second refit with one crew")
	c._scan()
	if c.housing >= behind:
		ok = false
		print("FAIL a building under refit still houses: %d vs %d" % [c.housing, behind])
	for i in 2000:
		c.mood = 1.0
		c.tick(0.1)
	if c.fit[a] != 0.0 or c.tier_at(a) != 1:
		ok = false
		print("FAIL refit done: fit %s tier %d" % [c.fit[a], c.tier_at(a)])
	var d := c.to_dict()
	var c2 := City.new(Signals.new())
	c2.from_dict(d)
	if c2.tier_at(a) != 1 or c2.fit_n != 0:
		ok = false
		print("FAIL save")
	print("REFIT_OK" if ok else "REFIT_FAIL")
	quit(0 if ok else 1)
