extends SceneTree
# Whole-game multiplayer check: a dedicated server process and a client process, both running the real Main scene.
#   godot --headless --path client -s tests/mp.gd  -> MP_OK
func _init() -> void:
	var port := 20000 + randi() % 20000
	var proj := ProjectSettings.globalize_path("res://")
	var exe := OS.get_executable_path()
	var srv := OS.create_process(exe, ["--headless", "--path", proj, "--", "--server", "--port", str(port), "--towns", "3"])
	await create_timer(4.0).timeout
	var out := []
	OS.execute(exe, ["--headless", "--path", proj, "--", "--join", "127.0.0.1:%d" % port, "--mp-test"], out, true)
	OS.kill(srv)
	var text := "\n".join(out)
	var ok := text.contains("MP_CLIENT world=3 mine=") and text.contains("MP_CLIENT_OK")
	print("MP_OK" if ok else "MP_FAIL\n" + text.substr(maxi(text.length() - 800, 0)))
	quit(0 if ok else 1)
