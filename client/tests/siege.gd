extends SceneTree
## Sieges: siege guns inside an undefended enemy town flatten its buildings; a defender in the town stops it.


func _town(k: int, sig: Signals) -> City:
	var t := City.new(sig)
	t.town_name = "S%d" % k
	t.gpos = Vector2i(k, 0)
	t.human = false
	t.seed_start()
	return t


func _ruined(guns: String, defender: bool) -> int:
	var sig := Signals.new()
	var a := _town(0, sig)
	var b := _town(1, sig)
	a.partners.append(b)
	b.partners.append(a)
	Diplo.act(a, b, "war")
	var zone := Military.terr_px(b)
	for i in 4:
		var u := Military._unit(guns)
		u["tgt"] = b.town_name
		u["p"] = zone.get_center()
		a.army.append(u)
	if defender:
		var d := Military._unit("inf")
		d["tgt"] = a.town_name
		d["p"] = zone.get_center()
		b.army.append(d)
	Military.blasts.clear()
	for s in 40:
		Military._shell(a, b)
	return Military.blasts.filter(func(e: Dictionary) -> bool: return e["t"] == b.town_name).size()


func _init() -> void:
	var open := _ruined("art", false)
	var held := _ruined("art", true)
	var inf := _ruined("inf", false)
	var ok := open >= 3 and held == 0 and inf == 0
	print("SIEGE_OK open=%d held=%d inf=%d" % [open, held, inf] if ok else "SIEGE_FAIL open=%d held=%d inf=%d" % [open, held, inf])
	quit(0 if ok else 1)
