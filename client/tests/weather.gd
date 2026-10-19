extends SceneTree
## Weather is regional and drifts; every town shares one season calendar; snapshots carry the fronts and reject junk.


func _init() -> void:
	var sig := Signals.new()
	var a := City.new(sig)
	var b := City.new(sig)
	a.gpos = Vector2i(0, 0)
	b.gpos = Vector2i(5, 0)
	var ok := true
	sig.set_weather("rain", 60.0, a.world_pos())
	for i in 100:  # build up (the edge starts small)
		sig.tick(0.1)
	if sig.weather_at(a.world_pos()) != "rain" or sig.weather_at(b.world_pos()) != "clear":
		ok = false
		print("FAIL regional: %s %s" % [sig.weather_at(a.world_pos()), sig.weather_at(b.world_pos())])
	var p0: Vector2 = sig.fronts[0]["p"]
	for i in 100:
		sig.tick(0.1)
	if sig.fronts.size() != 1 or (sig.fronts[0]["p"] as Vector2).distance_to(p0) < 100.0:
		ok = false
		print("FAIL drift")
	sig.set_weather("rain", 90.0, a.world_pos() + Vector2(300, 0))  # same weather nearby is prolonged, not doubled
	if sig.fronts.size() != 1:
		ok = false
		print("FAIL doubled")
	var d := a.to_dict()
	var s2 := Signals.new()
	var c := City.new(s2)
	c.from_dict(d)
	if s2.fronts.size() != 1 or s2.weather_at(sig.fronts[0]["p"]) != "rain":
		ok = false
		print("FAIL snapshot")
	d["wx"] = [["rain", "x", 0, 1, 0, 0, 5, 0], ["bogus", 0, 0, 1, 0, 0, 5, 0], 7]
	c.from_dict(d)
	if s2.fronts.size() != 0:
		ok = false
		print("FAIL hostile fronts")
	# one calendar: a town founded later is in the same season as the old one
	var s3 := Signals.new()
	var old := City.new(s3)
	var young := City.new(s3)
	old.day = 20
	young.day = 1
	old._second()
	young._second()
	if old.season != young.season or old.season != 2:
		ok = false
		print("FAIL season %d %d" % [old.season, young.season])
	print("WEATHER_OK" if ok else "WEATHER_FAIL")
	quit(0 if ok else 1)
