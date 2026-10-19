extends SceneTree
## Staffed and supplied: a sawmill with no wood in stock runs idle and its workers earn nothing; with wood it works and pays.
const T = Catalog.Id


func _town() -> City:
	var c := City.new(Signals.new())
	c.seed_start()
	c.peak = 100000
	c.age = Ages.LAST
	c.coins = 100000.0
	return c


func _init() -> void:
	var c := _town()
	var spot := Vector2i(-1, -1)
	for y in range(2, c.H - 2):
		for x in range(2, c.W - 3):
			if spot.x < 0 and c.at(x, y) == T.EMPTY and c.water[y * c.W + x] == 0 and c.owns(x, y) and c._road_next_to(y * c.W + x) >= 0:
				spot = Vector2i(x, y)
	c.place(spot.x, spot.y, T.SAWMILL)
	c._scan()
	c.stock["wood"] = 0.0
	c.pop = 100
	c.employed = 100
	c.jobs = 100
	for k in 120:
		c.stock["wood"] = 0.0
		c.sig.mk.price["wood"] = 1.0e6  # nothing affordable on the market either
		c._trade(1.0)
	var idle: float = c.chain_util[T.SAWMILL]
	var said: String = c.work_status(T.SAWMILL)
	for k in 120:
		c.stock["wood"] = 5.0
		c._trade(1.0)
	var busy: float = c.chain_util[T.SAWMILL]
	var worker := City.Citizen.new()
	worker.work = spot.y * c.W + spot.x
	worker.home = worker.work
	worker.wealth = 100.0
	c.citizens = [worker]
	c.chain_util[T.SAWMILL] = 0.0
	c._households()
	var unpaid: float = worker.wealth
	worker.wealth = 100.0
	c.chain_util[T.SAWMILL] = 1.0
	c._households()
	var paid: bool = worker.wealth > unpaid
	var ok: bool = paid and idle < 0.1 and busy > 0.5 and said.begins_with("Idle: no wood") and c.work_status(T.ROAD) == ""
	print("STAFFED_OK idle=%.2f busy=%.2f" % [idle, busy] if ok else "STAFFED_FAIL idle=%.2f busy=%.2f said=%s" % [idle, busy, said])
	quit(0 if ok else 1)
