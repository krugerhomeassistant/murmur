extends SceneTree
## Traffic module: a jam widens the busiest road to an avenue, congestion decays, one bus per stop.


func _init() -> void:
	var ok := true
	var c := City.new(Signals.new())
	c.seed_start()
	c.coins = 1000.0
	var road := -1
	for i in c.cells:
		if c.grid[i] == Catalog.Id.ROAD:
			road = i
			break
	if road < 0:
		print("FAIL no road in the start town")
		print("TRAFFIC_FAIL")
		quit()
		return
	c.traffic[road] = 20.0
	var coins := c.coins
	if not Traffic.widen(c) or c.grid[road] != Catalog.Id.AVENUE or c.coins >= coins:
		ok = false
		print("FAIL widen: %s coins %s" % [c.grid[road], c.coins])
	c.traffic.fill(0.0)
	if Traffic.widen(c):
		ok = false
		print("FAIL widen with no traffic")
	c.traffic[road] = 10.0
	Traffic.tick(c)
	if absf(c.traffic[road] - 7.0) > 0.01:
		ok = false
		print("FAIL decay: %s" % c.traffic[road])
	c.bt[Catalog.Id.BUS] = []
	c.buses = [{"stop": 5}]
	Traffic.sync_buses(c)
	if not c.buses.is_empty():
		ok = false
		print("FAIL bus without a stop kept")
	print("TRAFFIC_OK" if ok else "TRAFFIC_FAIL")
	quit()
