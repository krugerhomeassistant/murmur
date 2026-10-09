extends SceneTree
## Build stamp: version comes from project.godot; from a clone the commit is a short hex id.
func _init() -> void:
	var v := BuildInfo.version()
	var c := BuildInfo.commit()
	var ok := v != "" and v != "dev" and (c == "" or (c.length() == 7 and c.is_valid_hex_number()))
	print("BUILDINFO_OK %s" % BuildInfo.label() if ok else "BUILDINFO_FAIL %s" % BuildInfo.label())
	quit()
