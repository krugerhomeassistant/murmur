extends SceneTree
## Renders the procedural art of every building to PNG files named the way Sprites expects, as templates for
## replacement art. Needs a renderer: xvfb-run godot --path client -s tools/bake_sprites.gd -- <out dir> [scale]
## Output goes to <out dir>/modern/b<id>_<level>.png (default art/bake, 2x). Copy files you want to use into
## client/art/sprites/<age>/ (a baked file there would replace the live, animated drawing).

const T = Catalog.Id
var out := "art/bake"
var scale := 2
var ids: Array = []
var done := 0


class Cell extends Node2D:
	var id := 0
	var lv := 1

	func _draw() -> void:
		var d: Dictionary = Catalog.DEFS[id]
		var r := Rect2(0, 0, 32, 32)
		if String(d["kind"]) == "zone":
			Art.building(self, r, String(d.get("shape", "")), d["col"], lv, true, false, 3)
		else:
			Art.service(self, r, id, true, false)


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	if a.size() > 1:
		scale = int(a[1])
	DirAccess.make_dir_recursive_absolute(out + "/modern")
	for id in Catalog.DEFS:
		var d: Dictionary = Catalog.DEFS[id]
		if String(d["kind"]) == "zone" and Art.building(Node2D.new(), Rect2(0, 0, 32, 32), String(d.get("shape", "")), d["col"], 1, true, false, 3):
			for lv in 3:
				ids.append([id, lv + 1])
		elif Art._has(id):
			ids.append([id, 1])
	process_frame.connect(_step)


func _step() -> void:
	if ids.is_empty():
		print("BAKE_OK %d sprites in %s" % [done, out])
		quit()
		return
	var it: Array = ids.pop_back()
	var vp := SubViewport.new()
	vp.size = Vector2i(32, 32) * scale
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Cell.new()
	c.id = it[0]
	c.lv = it[1]
	c.scale = Vector2(scale, scale)
	vp.add_child(c)
	root.add_child(vp)
	await process_frame
	await process_frame
	vp.get_texture().get_image().save_png("%s/modern/b%d_%d.png" % [out, it[0], it[1]])
	done += 1
	vp.queue_free()
