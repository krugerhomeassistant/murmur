extends SceneTree
const T := Catalog.Id
## Utility tiers: each plant adds its rated output to a connected grid (power) or pipe network (water), and output rises by tier.


func _free(c: City, wet: bool) -> Vector2i:
	for y in range(2, c.H - 2):
		for x in range(2, c.W - 3):
			if c.at(x, y) == T.EMPTY and c.at(x + 1, y) == T.EMPTY and c.water[y * c.W + x] == 0 and c.water[y * c.W + x + 1] == 0 and c.wet_next(x, y) == wet and c.owns(x, y) and c.owns(x + 1, y) and (c._road_next_to(y * c.W + x) >= 0 or (wet and c.at(x, y + 1) == T.EMPTY and c.water[(y + 1) * c.W + x] == 0 and c.owns(x, y + 1))):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _init() -> void:
	var ok := true
	var tiers := [T.WIND, T.SOLAR, T.COAL, T.HYDRO, T.GAS, T.NUCLEAR, T.WELL, T.WATER, T.RESERVOIR, T.DESAL]
	var prev := 0.0
	for t in [T.COAL, T.HYDRO, T.GAS, T.NUCLEAR]:
		var o := float(Catalog.DEFS[t]["out"]["power"])
		if o <= prev:
			ok = false
			print("FAIL output not rising at %s" % Catalog.DEFS[t]["n"])
		prev = o
	if float(Catalog.DEFS[T.WELL]["out"]["water"]) >= float(Catalog.DEFS[T.WATER]["out"]["water"]) or Ages.building(T.WELL) != 0 or float(Catalog.DEFS[T.WATER]["out"]["water"]) >= float(Catalog.DEFS[T.RESERVOIR]["out"]["water"]) or float(Catalog.DEFS[T.RESERVOIR]["out"]["water"]) >= float(Catalog.DEFS[T.DESAL]["out"]["water"]):
		ok = false
		print("FAIL water output not rising")
	if Ages.building(T.NUCLEAR) < Ages.building(T.COAL) or Ages.building(T.HYDRO) < 1:
		ok = false
		print("FAIL age gating")
	for t in tiers:
		var c := City.new(Signals.new())
		c.seed_start()
		c.peak = 100000
		c.age = Ages.LAST
		c.coins = 100000.0
		var m: String = Catalog.DEFS[t]["out"].keys()[0]
		var p := _free(c, bool(Catalog.DEFS[t].get("water", false)))
		if p.x < 0:
			print("SKIP no site for %s" % Catalog.DEFS[t]["n"])
			continue
		var rp := p.y * c.W + p.x
		if c._road_next_to(rp) < 0:
			c.place(p.x, p.y + 1, T.ROAD)  # a river site far from any road
		c._scan()
		c._net()
		var before: float = c.net_own[m]
		if not c.place(p.x, p.y, t) or not c.place(p.x + 1, p.y, T.WIRE if m == "power" else T.PIPE):
			ok = false
			print("FAIL could not place %s" % Catalog.DEFS[t]["n"])
			continue
		c._scan()
		c._net()
		var got: float = float(c.net_own[m]) - before
		var want := float(Catalog.DEFS[t]["out"][m])
		if got < want * 0.5:
			ok = false
			print("FAIL %s supplies %.1f, expected about %.1f" % [Catalog.DEFS[t]["n"], got, want])
	print("POWER_OK" if ok else "POWER_FAIL")
	quit(0 if ok else 1)
