extends SceneTree
# Two-process check of multiplayer phase 3: `godot --headless --path client -s tests/netsync.gd` -> NETSYNC_OK.
# Host simulates 3 planner towns and serves them; a child process joins, mirrors them from snapshots, builds a road on
# its own town through a command, and tries (and must fail) to build on someone else's.
const T = Catalog.Id
const OUT := "user://netsync_client.txt"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var net := NetPlay.new()
	net.name = "Net"
	root.add_child(net)
	await process_frame
	if "--client" in args:
		await _client(net, int(args[args.find("--port") + 1]))
	else:
		await _host(net)


func _host(net: NetPlay) -> void:
	var sig := Signals.new()
	var towns: Array[City] = []
	for k in 3:
		var t := City.new(sig)
		t.rng.seed = 90 + k
		t._gen_ore()
		t.gpos = Vector2i(k, 0)
		t.human = false
		t.seed_start()
		for o in towns:
			o.partners.append(t)
			t.partners.append(o)
		towns.append(t)
	towns[0].owner = 1  # the host plays town 0
	towns[0].human = true
	net.serve(towns)
	var port := 20000 + randi() % 20000
	var heard := []
	net.chat.connect(func(who: String, text: String) -> void: heard.append(who + ": " + text))
	net.host(port, "Boss")
	DirAccess.remove_absolute(OUT)
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "tests/netsync.gd", "--", "--client", "--port", str(port)])
	var done := ""
	for sec in 40:
		for i in 10:
			sig.tick(0.1)
			for t in towns:
				t.tick(0.1)
		net.broadcast()
		await create_timer(0.5).timeout
		if FileAccess.file_exists(OUT):
			done = FileAccess.get_file_as_string(OUT)
			break
	OS.kill(pid)
	var mine := -1
	for i in towns.size():
		if towns[i].owner != 0 and towns[i].owner != 1:
			mine = i
	# the client built a road on its own town; town 0 (the host's) must not have received the client's forbidden command
	var ok := done == "CLIENT_OK" and mine == 1 and "Tester: hello there" in heard
	print("NETSYNC_OK" if ok else "NETSYNC_FAIL client=%s mine=%d" % [done, mine])
	net.stop()
	quit(0 if ok else 1)


func _client(net: NetPlay, port: int) -> void:
	var sig := Signals.new()
	var mirror := []  # lambdas capture by value, so the callbacks mutate this array in place
	var mine := [-1]
	var got := {}
	var replies := []
	net.world.connect(func(m: Dictionary) -> void:
		mirror.assign(NetWorld.mirror(sig, int(m["n"])))
		mine[0] = int(m["mine"]))
	net.state.connect(func(i: int, d: Dictionary) -> void:
		if i < mirror.size():
			mirror[i].from_dict(d)
			got[i] = true)
	net.reply.connect(func(c: String, r: Variant) -> void: replies.append([c, r]))
	net.join("127.0.0.1", port, "Tester")
	for i in 120:
		await create_timer(0.1).timeout
		if mine[0] >= 0 and got.size() == 3:
			break
	if mine[0] < 0 or got.size() < 3:
		_finish("CLIENT_FAIL no world/state mine=%d got=%d" % [mine[0], got.size()])
		return
	var me: City = mirror[mine[0]]
	var other := 0 if mine[0] != 0 else 2
	var ctr := me.terr.get_center()
	var spot := Vector2i(-1, -1)
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var p := ctr + Vector2i(dx, dy)
			if spot.x < 0 and me.at(p.x, p.y) == T.EMPTY and me.owns(p.x, p.y):
				spot = p
	net.say("hello there")
	net.command(mine[0], "place", [spot.x, spot.y, T.ROAD])
	var octr: Vector2i = (mirror[other] as City).terr.get_center()
	net.command(other, "place", [octr.x, octr.y, T.ROAD])  # someone else's town: must be refused
	var built := false
	for i in 80:
		await create_timer(0.1).timeout
		if me.at(spot.x, spot.y) == T.ROAD:
			built = true
			break
	for i in 30:  # both answers: yes for my town, "refused" (null) for the other
		if replies.size() >= 2:
			break
		await create_timer(0.1).timeout
	var leak: bool = replies.size() < 2 or replies[0][1] != true or replies[1][1] != null
	var same: bool = (mirror[0] as City).town_name != "" and (mirror[0] as City).pop >= 0
	_finish("CLIENT_OK" if (built and same and not leak) else "CLIENT_FAIL built=%s same=%s leak=%s replies=%s" % [built, same, leak, str(replies)])


func _finish(s: String) -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(s)
	f.close()
	await create_timer(0.5).timeout
	quit(0)
