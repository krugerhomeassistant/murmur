class_name BuildInfo
extends RefCounted
## Which build is running: the version from project.godot plus the git commit.
## A clone reads `.git/HEAD`; an exported build carries `res://build_info.json` written by CI (`scripts/stamp_build.py`).


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "dev"))


## Short commit id, or "" when unknown.
static func commit() -> String:
	if FileAccess.file_exists("res://build_info.json"):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://build_info.json"))
		if d is Dictionary:
			return str((d as Dictionary).get("commit", "")).substr(0, 7)
	var git := ProjectSettings.globalize_path("res://").path_join("../.git")
	if not FileAccess.file_exists(git.path_join("HEAD")):
		return ""
	var head := FileAccess.get_file_as_string(git.path_join("HEAD")).strip_edges()
	if not head.begins_with("ref: "):
		return head.substr(0, 7)  # detached HEAD
	var ref := head.substr(5)
	if FileAccess.file_exists(git.path_join(ref)):
		return FileAccess.get_file_as_string(git.path_join(ref)).strip_edges().substr(0, 7)
	for line in FileAccess.get_file_as_string(git.path_join("packed-refs")).split("\n"):
		if line.ends_with(" " + ref):
			return line.substr(0, 7)
	return ""


## For the start menu and window title, for example "v0.2.0 (commit 3a9f2c1)".
static func label() -> String:
	var c := commit()
	return "v%s (commit %s)" % [version(), c] if c != "" else "v%s" % version()
