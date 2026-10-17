extends SceneTree
## Sprite lookup: file names, age fallback, level fallback, cache, missing files.


func _init() -> void:
	var ok := true
	var dir := "user://sprites_test"
	var id: int = Catalog.Id.RES
	Sprites.roots = [dir]
	DirAccess.make_dir_recursive_absolute(dir + "/ancient")
	DirAccess.make_dir_recursive_absolute(dir + "/modern")
	DirAccess.make_dir_recursive_absolute(dir + "/all")
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	img.save_png("%s/ancient/b%d_1.png" % [dir, id])
	img.save_png("%s/modern/b%d.png" % [dir, id])
	img.save_png("%s/all/b%d_3.png" % [dir, id])
	Sprites.clear()
	var n := Sprites.names(id, 2, 1)
	if n[0] != "medieval/b%d_2.png" % id or n[-1] != "all/b%d.png" % id or n.size() != 2 * 3:
		ok = false
		print("FAIL names %s" % [n])
	if Sprites.tex(id, 1, 0) == null:
		ok = false
		print("FAIL ancient sprite not found")
	if Sprites.tex(id, 1, 3) == null:
		ok = false
		print("FAIL modern sprite not found")
	if Sprites.tex(id, 1, 1) == null:
		ok = false
		print("FAIL a medieval town should fall back to the ancient sprite")
	if Sprites.tex(id, 2, 0) != null:
		ok = false
		print("FAIL no level 2 sprite exists in the ancient age")
	if Sprites.tex(id, 3, 0) == null:
		ok = false
		print("FAIL the 'all' folder should serve any age")
	if Sprites.tex(id + 99, 1, 3) != null:
		ok = false
		print("FAIL a building without a sprite must return null")
	var first := Sprites.tex(id, 1, 0)
	if first != Sprites.tex(id, 1, 0):
		ok = false
		print("FAIL not cached")
	Sprites.roots = Sprites.ROOTS.duplicate()
	Sprites.clear()
	print("SPRITES_OK" if ok else "SPRITES_FAIL")
	quit()
