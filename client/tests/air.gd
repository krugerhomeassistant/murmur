extends SceneTree
## Air defence: bombers flatten an undefended town fast; anti-air guns and fighters slow them but do not stop them outright.


func _ruined(guards: int, secs: int) -> int:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in 2:
		var t := City.new(sig)
		t.town_name = "A%d" % k
		t.gpos = Vector2i(k, 0)
		t.human = false
		t.seed_start()
		ts.append(t)
	var a := ts[0]
	var b := ts[1]
	a.partners.append(b)
	b.partners.append(a)
	var c := Military.terr_px(b).get_center()
	for i in 4:
		var u := Military._unit("bomber")
		u["tgt"] = b.town_name
		u["p"] = c
		a.army.append(u)
	for i in guards:
		var g := Military._unit("aa")
		g["tgt"] = a.town_name
		b.army.append(g)
	Military.blasts.clear()
	for s in secs:
		Military._bomb(a, b)
	return Military.blasts.filter(func(e: Dictionary) -> bool: return e["t"] == b.town_name).size()


func _init() -> void:
	var open := _ruined(0, 10)
	var guarded := _ruined(3, 10)
	var long_run := _ruined(3, 200)
	var ok := open >= 3 and guarded < open and long_run >= 1
	print("AIR_OK open=%d guarded=%d long=%d" % [open, guarded, long_run] if ok else "AIR_FAIL open=%d guarded=%d long=%d" % [open, guarded, long_run])
	quit(0 if ok else 1)
