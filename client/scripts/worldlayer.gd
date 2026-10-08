class_name WorldLayer
extends Node2D
## The land between and around the towns: the endless World drawn one texel per tile (scaled to tiles, nearest filter), one
## small texture per world chunk. Chunks near the camera are generated a few milliseconds per frame, so panning never hitches.

const TILE := 32.0
const BUDGET_US := 6000
const KEEP := 700  # chunk textures kept; the farthest are dropped first

var world: World
var season := 0
var _tex := {}  # Vector2i chunk -> ImageTexture
var _cam: Camera2D
var _view := Vector2.ONE * 1280.0


func setup(w: World, cam: Camera2D) -> void:
	world = w
	_cam = cam
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clear()


func clear() -> void:
	_tex.clear()
	queue_redraw()


func set_season(s: int) -> void:
	if s != season:
		season = s
		clear()


func _color(k: int, o: int, grass: Color) -> Color:
	var c := _base(k, grass)
	return c.darkened(0.3) if o > 0 and k >= World.K.PLAIN else c


func _base(k: int, grass: Color) -> Color:
	match k:
		World.K.SEA, World.K.RIVER:
			return Color("3f7fb8")
		World.K.SAND:
			return Color("d8c68c")
		World.K.FOREST:
			return grass.darkened(0.42)
		World.K.HILL:
			return grass.lerp(Color("9a8a5a"), 0.5).darkened(0.1)
		World.K.ROCK:
			return Color("808084")
	return grass.darkened(0.2)


func _bake(cx: int, cy: int) -> ImageTexture:
	var n := world.csize
	var ch := world.chunk(cx, cy)
	var grass: Color = Civics.SEASONS[season]["grass"]
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			img.set_pixel(i, j, _color(ch["k"][j * n + i], ch["o"][j * n + i], grass))
	return ImageTexture.create_from_image(img)


func _process(_d: float) -> void:
	if world == null or _cam == null:
		return
	var span := world.csize * TILE
	var vp := get_viewport_rect().size / _cam.zoom
	var c0 := Vector2i(((_cam.position - vp * 0.5) / span).floor()) - Vector2i.ONE
	var c1 := Vector2i(((_cam.position + vp * 0.5) / span).floor()) + Vector2i.ONE
	if (c1.x - c0.x + 1) * (c1.y - c0.y + 1) > 420:  # zoomed far out: the town thumbnails carry the picture
		return
	var mid := (c0 + c1) / 2
	var want: Array[Vector2i] = []
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			if not _tex.has(Vector2i(x, y)):
				want.append(Vector2i(x, y))
	if want.is_empty():
		return
	want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - mid).length_squared() < (b - mid).length_squared())
	var t0 := Time.get_ticks_usec()
	for cp in want:
		_tex[cp] = _bake(cp.x, cp.y)
		if Time.get_ticks_usec() - t0 > BUDGET_US:
			break
	if _tex.size() > KEEP:
		var keys := _tex.keys()
		keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - mid).length_squared() > (b - mid).length_squared())
		for k in keys.slice(0, _tex.size() - KEEP):
			_tex.erase(k)
	queue_redraw()


func _draw() -> void:
	var span := world.csize * TILE if world != null else 1024.0
	for cp in _tex:
		draw_texture_rect(_tex[cp], Rect2(Vector2(cp) * span, Vector2(span, span)), false)
