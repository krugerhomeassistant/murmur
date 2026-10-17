class_name Sprites
extends RefCounted
## Sprite lookup: a PNG on disk replaces the procedural drawing of a building, otherwise `Art` draws it.
## Files: <root>/<age>/b<id>_<level>.png, then b<id>.png, then the same names in each older age, then in "all".
## <age> is one of ancient, medieval, industrial, modern. Roots: user://sprites (mods, tests) before res://art/sprites.
## The PNG fills one tile; any square size works (64 or 128 px for sharper art).

const ROOTS: Array[String] = ["user://sprites", "res://art/sprites"]
const AGES: Array[String] = ["ancient", "medieval", "industrial", "modern"]

static var _cache: Dictionary = {}
static var roots: Array[String] = ROOTS.duplicate()


static func clear() -> void:
	_cache.clear()


## Candidate file names for a building, most specific first (age from the town's age down to ancient, then "all").
static func names(id: int, lv: int, age: int) -> Array[String]:
	var out: Array[String] = []
	var dirs: Array[String] = []
	for a in range(clampi(age, 0, AGES.size() - 1), -1, -1):
		dirs.append(AGES[a])
	dirs.append("all")
	for d in dirs:
		out.append("%s/b%d_%d.png" % [d, id, lv])
		out.append("%s/b%d.png" % [d, id])
	return out


static func tex(id: int, lv: int, age: int) -> Texture2D:
	var key := id * 1000 + lv * 10 + clampi(age, 0, AGES.size() - 1)
	if _cache.has(key):
		return _cache[key]
	var found: Texture2D = null
	for n in names(id, lv, age):
		for root in roots:
			var p := "%s/%s" % [root, n]
			if root.begins_with("res://"):
				if ResourceLoader.exists(p):
					found = load(p) as Texture2D
			elif FileAccess.file_exists(p):
				var img := Image.load_from_file(p)
				if img != null and not img.is_empty():
					found = ImageTexture.create_from_image(img)
			if found != null:
				break
		if found != null:
			break
	_cache[key] = found
	return found


## Draws the sprite over tile rectangle r. Returns false when there is none (the caller draws procedurally).
static func draw(ci: CanvasItem, r: Rect2, id: int, lv: int, age: int, ok: bool) -> bool:
	var t := tex(id, lv, age)
	if t == null:
		return false
	ci.draw_texture_rect(t, r, false, Color.WHITE if ok else Color(0.6, 0.6, 0.6))
	return true
