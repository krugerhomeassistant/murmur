extends SceneTree
## Sandbox commands: refused in a normal game, working (and bounded) when the sandbox is on.


func _init() -> void:
	var t := City.new(Signals.new())
	t.seed_start()
	var ts: Array[City] = [t]
	var c0 := t.coins
	Cmd.sandbox = false
	var off: bool = Cmd.run(ts, t, "grant", [1000]) == null and Cmd.run(ts, t, "spawn", ["spear", 5]) == null and t.coins == c0 and t.army.is_empty()
	Cmd.sandbox = true
	var granted: bool = Cmd.run(ts, t, "grant", [1000]) == true and t.coins == c0 + 1000.0
	var spawned: bool = Cmd.run(ts, t, "spawn", ["spear", 12]) == true and t.army.size() == 12
	var bad: bool = Cmd.run(ts, t, "grant", [-5]) == null and Cmd.run(ts, t, "spawn", ["nope", 3]) == null and Cmd.run(ts, t, "spawn", ["spear", 51]) == null
	var capped: bool = Cmd.run(ts, t, "spawn", ["spear", 50]) == true and Cmd.run(ts, t, "spawn", ["spear", 50]) == true and Cmd.run(ts, t, "spawn", ["spear", 50]) == null
	Cmd.sandbox = false
	var ok := off and granted and spawned and bad and capped
	print("SANDBOX_OK" if ok else "SANDBOX_FAIL off=%s granted=%s spawned=%s bad=%s capped=%s" % [off, granted, spawned, bad, capped])
	quit(0 if ok else 1)
