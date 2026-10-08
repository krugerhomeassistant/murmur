extends SceneTree
## Planner proposals: with ask_build a planner service becomes a decision; yes builds it, no vetoes it for 10 days.
func _init() -> void:
	var errs: Array[String] = []
	var c := City.new(Signals.new())
	c.seed_start()
	c.next_fire = 9999.0
	c.ev_t = 9999.0
	c.human = true
	c.ask_build = true
	c.pop = 200
	var built0 := 0
	for i in c.cells:
		built0 += 1 if c.grid[i] != Catalog.Id.EMPTY else 0
	for k in 40:
		c.coins = 5000.0
		c._plan_service(true)
		if not c.petitions.is_empty() and c.petitions[0]["kind"] == "build":
			break
	if c.petitions.is_empty() or c.petitions[0]["kind"] != "build":
		errs.append("no proposal appeared")
	else:
		var p: Dictionary = c.petitions[0]
		var id := int(p["bid"])
		var at := int(p["cell"])
		if c.coins != 5000.0:
			errs.append("proposing must not spend")
		var before := c.coins
		c.answer(0, true)
		if (c.grid[at] != id and not (id == Catalog.Id.LIGHT and c.lamp[at] == 1)) or c.coins != before - float(p["cost"]):
			errs.append("yes should build and charge")
		c.petitions.append(p.duplicate())
		c.answer(0, false)
		if int(c.vetoed.get(str(id), 0)) <= c.day:
			errs.append("no should veto")
	c.petitions.append({"kind": "build", "bid": 99999, "cell": 5, "tribe": "", "cost": 1.0, "id": "x", "t": "", "txt": "", "expires": 9})
	c.answer(c.petitions.size() - 1, true)  # hostile building id must not crash
	print("PROPOSE_OK" if errs.is_empty() else "PROPOSE_FAIL " + str(errs))
	quit()
