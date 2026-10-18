extends SceneTree
## Rail yard: when both towns of a trade link have one, freight is cheaper and the link carries more.


func _run(rail: bool, port := false, road := true) -> float:
	var sg := Signals.new()
	var a := City.new(sg)
	var b := City.new(sg)
	a.town_name = "A"
	b.town_name = "B"
	a.gpos = Vector2i(0, 0)
	b.gpos = Vector2i(1, 0)
	a.partners.append(b)
	b.partners.append(a)
	if road:
		a.gate[1] = 1
		b.gate[3] = 1
	if port:
		for c in [a, b]:
			c.bt[Catalog.Id.PORT] = [0]
	if rail:
		for c in [a, b]:
			c.bt[Catalog.Id.RAILYARD] = [0]
	a.stock["food"] = 300.0
	a.need_rate["food"] = 1.0
	a.price_loc["food"] = 1.2
	b.stock["food"] = 0.0
	b.need_rate["food"] = 3.0
	b.price_loc["food"] = 1.8
	Market.link_trade([a, b])
	return float(b.stock["food"])


func _reach(at: Vector2i) -> float:
	var c := City.new(Signals.new())
	c.grid[5 * c.W + 5] = Catalog.Id.FARM
	c.works = [5 * c.W + 5]
	c.bt[Catalog.Id.RAILYARD] = [at.y * c.W + at.x]
	return c._rail_share()


func _init() -> void:
	var plain := _run(false)
	var fast := _run(true)
	var noroad := _run(false, false, false)
	var sea := _run(false, true, false)
	var close := _reach(Vector2i(8, 8))
	var far := _reach(Vector2i(40, 40))
	var ok := close > far and far >= 0.4 and close <= 1.0 and plain > 0.0 and fast > plain * 1.5 and noroad == 0.0 and sea > 0.0
	print("RAIL_OK plain=%.2f rail=%.2f sea=%.2f (no road: %.2f) reach near=%.2f far=%.2f" % [plain, fast, sea, noroad, close, far] if ok else "RAIL_FAIL plain=%.2f rail=%.2f sea=%.2f noroad=%.2f near=%.2f far=%.2f" % [plain, fast, sea, noroad, close, far])
	quit(0 if ok else 1)
