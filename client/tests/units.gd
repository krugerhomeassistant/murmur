extends SceneTree
## Every unit on the map is one of the town's people: a bus needs eight people to run it, so a town of four has none.


func _init() -> void:
	var c := City.new(Signals.new())
	c.seed_start()
	var stop := -1
	for i in c.cells:
		if c.grid[i] == Catalog.Id.EMPTY and c._road_next_to(i) >= 0:
			stop = i
			break
	c.bt[Catalog.Id.BUS] = [stop]
	c.pop = 4
	Traffic.sync_buses(c)
	var none: bool = c.buses.is_empty()
	c.pop = 40
	Traffic.sync_buses(c)
	var one: bool = c.buses.size() == 1
	c.pop = 4
	Traffic.sync_buses(c)
	var gone: bool = c.buses.is_empty()
	var small := City.new(Signals.new())
	small.seed_start()
	small.pop = 4
	var foe := City.new(Signals.new())
	foe.seed_start()
	Diplo.declare(small, foe, "land", "")
	var levy: bool = small.army.is_empty() and foe.army.is_empty() and not Diplo.ready(small)  # war raises no free troops
	small.army.append(Military._unit("spear"))
	small.army.append(Military._unit("spear"))
	small.army.append(Military._unit("spear"))
	levy = levy and Diplo.ready(small)
	var hs: bool = c._haulers([[1, 20.0]], []) == 0 and c._haulers([[1, 20.0]], [5]) == 3 and c._haulers([[1, 8.0]], [5]) == 1
	var ok: bool = stop >= 0 and none and one and gone and levy and hs
	print("UNITS_OK" if ok else "UNITS_FAIL stop=%d none=%s one=%s gone=%s levy=%s haulers=%s" % [stop, none, one, gone, levy, hs])
	quit(0 if ok else 1)
