extends SceneTree
## Groups: towns in one group are allied and cannot declare war or embargo on each other.


func _init() -> void:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in 3:
		var t := City.new(sig)
		t.town_name = "G%d" % k
		t.gpos = Vector2i(k, 0)
		t.human = k < 2
		t.seed_start()
		ts.append(t)
	for a in ts:
		for b in ts:
			if a != b:
				a.partners.append(b)
	Cmd.run(ts, ts[0], "group", [-1])
	Cmd.run(ts, ts[0], "group", [100])
	Cmd.run(ts, ts[0], "group", ["1"])
	var bad := ts[0].group
	Cmd.run(ts, ts[0], "group", [1])
	Cmd.run(ts, ts[1], "group", [1])
	var allied := Diplo.treaty(ts[0], ts[1]) == "alliance" and Diplo.treaty(ts[1], ts[0]) == "alliance"
	var outside := Diplo.treaty(ts[0], ts[2]) != "alliance"
	var war := Diplo.act(ts[0], ts[1], "war")
	var held := Diplo.treaty(ts[0], ts[1]) != "war" and war.find("group") >= 0
	var ok := bad == 0 and allied and outside and held
	print("GROUP_OK allied=%s war_msg=%s" % [allied, war] if ok else "GROUP_FAIL bad=%d allied=%s outside=%s held=%s" % [bad, allied, outside, held])
	quit(0 if ok else 1)
