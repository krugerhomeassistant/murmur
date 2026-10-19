extends SceneTree
const T := Catalog.Id
## Fuel: a refinery turns ore into fuel, and coal and gas plants run at half output without it.


func _town() -> City:
	var c := City.new(Signals.new())
	c.seed_start()
	for i in 60:
		c.tick(0.5)
	c.coins = 0.0  # too poor to buy fuel from the market
	return c


func _fuel_ok(refinery: bool) -> float:
	var c := _town()
	c.bt[T.COAL] = [0]
	if refinery:
		c.bt[T.REFINERY] = [0]
	c.stock["ore"] = 100.0
	c.stock["fuel"] = 0.0
	c._trade(1.0)
	c._trade(1.0)
	return c.fuel_ok


func _supply(ok: float) -> float:
	var c := _town()
	c.peak = 1.0e5
	c.age = Ages.LAST
	c.coins = 1.0e5
	for y in range(2, c.H - 2):
		for x in range(2, c.W - 3):
			if c.at(x, y) == T.EMPTY and c.at(x + 1, y) == T.EMPTY and c.water[y * c.W + x] == 0 and c.water[y * c.W + x + 1] == 0 and c.owns(x, y) and c.owns(x + 1, y) and c._road_next_to(y * c.W + x) >= 0:
				c.place(x, y, T.COAL)
				c.place(x + 1, y, T.WIRE)
				c.fuel_ok = ok
				c._scan()
				c._net()
				return float(c.net_own["power"])
	return -1.0


func _init() -> void:
	var without := _fuel_ok(false)
	var with := _fuel_ok(true)
	var full := _supply(1.0)
	var half := _supply(0.5)
	var ok := without < 0.6 and with > 0.99 and full > 0.0 and absf(half * 2.0 - full) < 0.5
	print("FUEL_OK without=%.2f with=%.2f power full=%.1f half=%.1f" % [without, with, full, half] if ok else "FUEL_FAIL without=%.2f with=%.2f full=%.1f half=%.1f" % [without, with, full, half])
	quit(0 if ok else 1)
