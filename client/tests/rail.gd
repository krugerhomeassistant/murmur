extends SceneTree
## Rail yard: when both towns of a trade link have one, freight is cheaper and the link carries more.


func _run(rail: bool) -> float:
	var sg := Signals.new()
	var a := City.new(sg)
	var b := City.new(sg)
	a.town_name = "A"
	b.town_name = "B"
	a.gpos = Vector2i(0, 0)
	b.gpos = Vector2i(1, 0)
	a.partners.append(b)
	b.partners.append(a)
	a.gate[1] = 1
	b.gate[3] = 1
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


func _init() -> void:
	var plain := _run(false)
	var fast := _run(true)
	var ok := plain > 0.0 and fast > plain * 1.5
	print("RAIL_OK plain=%.2f rail=%.2f" % [plain, fast] if ok else "RAIL_FAIL plain=%.2f rail=%.2f" % [plain, fast])
	quit(0 if ok else 1)
