extends SceneTree
## Buildings keep the era they were built in: a new age does not repaint old buildings; the era is saved.


func _init() -> void:
	var c := City.new(Signals.new())
	c.next_fire = 9999.0
	c.ev_t = 9999.0
	c.auto_mode = 0
	c.water.fill(0)
	c.coins = 1.0e5
	Ages.set_age(c, 0)
	var ok := true
	c.place(City.OX + 5, City.OY + 6, Catalog.Id.ROAD)
	c.place(City.OX + 5, City.OY + 5, Catalog.Id.RES)
	for i in 900:
		c.tick(0.1)
	var old_i := (City.OY + 5) * City.W + City.OX + 5
	if c.lvl[old_i] == 0 or c.tier_at(old_i) != 0:
		ok = false
		print("FAIL old building: lvl %d tier %d" % [c.lvl[old_i], c.tier_at(old_i)])
	Ages.set_age(c, 6)  # the Industrial age
	c.place(City.OX + 6, City.OY + 6, Catalog.Id.ROAD)
	c.place(City.OX + 6, City.OY + 5, Catalog.Id.RES)
	for i in 900:
		c.tick(0.1)
	var new_i := (City.OY + 5) * City.W + City.OX + 6
	if c.lvl[new_i] == 0 or c.tier_at(new_i) != 2 or c.tier_at(old_i) != 0:
		ok = false
		print("FAIL new building: lvl %d tiers new %d old %d" % [c.lvl[new_i], c.tier_at(new_i), c.tier_at(old_i)])
	var d := c.to_dict()
	var c2 := City.new(Signals.new())
	c2.from_dict(d)
	if c2.tier_at(old_i) != 0 or c2.tier_at(new_i) != 2:
		ok = false
		print("FAIL save: %d %d" % [c2.tier_at(old_i), c2.tier_at(new_i)])
	print("ERA_OK" if ok else "ERA_FAIL")
	quit(0 if ok else 1)
