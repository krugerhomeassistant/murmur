extends SceneTree
## Arms: units cost arms, made by armouries from metal or bought abroad; the planner builds armouries where there are troops.
const T = Catalog.Id

func _init() -> void:
	var errs: Array[String] = []
	var sig := Signals.new()
	var c := City.new(sig)
	c.seed_start()
	c.next_fire = 9999.0
	c.ev_t = 9999.0
	c.army.clear()
	# buying abroad: coins pay for labour plus imported arms
	c.coins = 3000.0
	c.stock["arms"] = 0.0
	var ok := Military._pay(c, "tank")
	var arms_cost: float = Military.arms_need("tank") * float(sig.mk.price["arms"]) * Market.IMPORT
	if not ok or absf((3000.0 - c.coins) - (float(Military.KIND["tank"]["cost"]) * Military.LABOUR + arms_cost)) > 0.01:
		errs.append("a tank bought abroad should cost labour plus imported arms (paid %.1f)" % (3000.0 - c.coins))
	# own stock is used first
	c.coins = 3000.0
	c.stock["arms"] = 20.0
	Military._pay(c, "tank")
	if absf(float(c.stock["arms"]) - (20.0 - Military.arms_need("tank"))) > 0.001 or absf(3000.0 - c.coins - float(Military.KIND["tank"]["cost"]) * Military.LABOUR) > 0.01:
		errs.append("stocked arms should be spent before buying abroad")
	# too poor: refused, nothing taken
	c.coins = 10.0
	c.stock["arms"] = 0.0
	if Military._pay(c, "tank") or c.coins != 10.0:
		errs.append("an unaffordable unit must not be paid for")
	# armoury turns metal into arms
	var a := City.new(Signals.new())
	a.seed_start()
	a.next_fire = 9999.0
	a.ev_t = 9999.0
	a.coins = 3000.0
	a.stock["metal"] = 50.0
	var cell := -1
	for i in a.cells:
		if a.grid[i] == T.EMPTY and a._road_next_to(i) >= 0 and a.water[i] == 0:
			cell = i
			break
	if cell >= 0:
		a.grid[cell] = T.ARMOURY
		a.connected[cell] = 1
		a._rebuild_cells()
		a._scan()
	var arms0 := float(a.stock["arms"])
	for i in 300:
		a.tick(0.1)
	if cell >= 0 and float(a.stock["arms"]) <= arms0 and a.pop > 0:
		errs.append("an armoury should turn metal into arms (stock %.2f, metal %.2f)" % [float(a.stock["arms"]), float(a.stock["metal"])])
	if errs.is_empty():
		print("ARMS_OK arms=%.1f" % float(a.stock["arms"]))
	else:
		print("ARMS_FAIL ", errs)
	quit()
