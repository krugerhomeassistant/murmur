extends SceneTree
# Headless two-process check: this process hosts, a child process joins; run `godot --headless --path client -s tests/net.gd`.
# Prints NET_OK once the roster shows the joined client with a measured ping, then a clean leave empties it.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var net := NetPlay.new()
	net.name = "Net"
	root.add_child(net)
	await process_frame
	if "--client" in args:
		var port := int(args[args.find("--port") + 1])
		net.joined.connect(func() -> void: print("CLIENT_JOINED"))
		net.failed.connect(func(r: String) -> void: print("CLIENT_FAIL ", r); quit(1))
		net.join("127.0.0.1", port, "Tester")
		await create_timer(6.0).timeout
		net.stop()
		quit(0)
		return
	var port := 20000 + randi() % 20000
	if not net.host(port, "Boss"):
		print("NET_FAIL host")
		quit(1)
		return
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "tests/net.gd", "--", "--client", "--port", str(port)])
	var seen := false
	for i in 200:
		await create_timer(0.1).timeout
		if net.players.size() == 2:
			var other: Dictionary = net.players.values().filter(func(p: Dictionary) -> bool: return p["name"] == "Tester")[0] if net.players.values().any(func(p: Dictionary) -> bool: return p["name"] == "Tester") else {}
			if not other.is_empty() and net.players.keys().has(1) and net.players[1]["name"] == "Boss":
				seen = true
				break
	var ok := seen
	if ok:  # wait for a ping measurement; loopback may legitimately read 0 ms, so only require the table stays consistent
		await create_timer(2.5).timeout
		ok = net.players.size() == 2
	for i in 100:  # the client leaves cleanly after 6 s; the roster must drop it
		if net.players.size() == 1:
			break
		await create_timer(0.1).timeout
	OS.kill(pid)
	ok = ok and net.players.size() == 1
	var np := NetPlay.new()  # sanitising and the rate limit are pure host-side helpers
	ok = ok and NetPlay._plain("a\nb\tc\u001b[31m") == "a b c [31m" and NetPlay._clean("server") == "Player" and NetPlay._clean("  \n ") == "Player"
	var granted := 0
	for k in 200:
		granted += int(np._allow(7))
	ok = ok and granted >= 60 and granted < 100  # burst of 60 plus a trickle, then refused
	ok = ok and NetWorld.unpack(var_to_bytes({"a": PackedByteArray([1, 2, 3])}).compress(FileAccess.COMPRESSION_GZIP)).has("a")
	var big := PackedByteArray()
	big.resize(5 << 20)  # over the 4 MB decompression cap
	ok = ok and NetWorld.unpack(var_to_bytes(big).compress(FileAccess.COMPRESSION_GZIP)).is_empty()
	var t := City.new(Signals.new())
	t.from_dict({"coins": 5.0, "not_a_save_key": 1, "multiplayer": 3})  # unknown keys are ignored
	ok = ok and t.coins == 5.0 and not ("not_a_save_key" in t)
	np.free()
	print("NET_OK" if ok else "NET_FAIL players=%s" % str(net.players))
	net.stop()
	quit(0 if ok else 1)
