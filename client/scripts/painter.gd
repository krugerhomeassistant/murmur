class_name Painter
extends RefCounted
## Soft painted sprites for moving things, baked once into small textures (3x supersampled, linear filtered).
## One textured draw replaces several rectangles per car or person, so the look gets richer without extra draw calls.

const SS := 3.0  # texture pixels per world pixel
static var cache := {}


## Cars face +x; centred on the origin, 12 x 7 world pixels.
static func car(col: Color) -> ImageTexture:
	var key := "car" + col.to_html()
	if cache.has(key):
		return cache[key]
	var im := _blank(12, 7)
	_ell(im, 18, 20, 17, 7, Color(0, 0, 0, 0.22))  # soft shadow
	for y in [2.5, 15.0]:  # wheels peek out under the body
		_rr(im, 5, y, 12, y + 4, 1.5, Color("2a2a2e"), Color("2a2a2e"))
		_rr(im, 24, y, 31, y + 4, 1.5, Color("2a2a2e"), Color("2a2a2e"))
	_rr(im, 1.5, 3.5, 34.5, 17.5, 5.0, col.lightened(0.25), col.darkened(0.2))  # body
	_rr(im, 3, 4.5, 33, 8.0, 3.0, Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0))  # sheen
	_rr(im, 11, 6.5, 26, 14.5, 3.0, col.darkened(0.12), col.darkened(0.3))  # roof
	_rr(im, 22.5, 7, 27.5, 14, 2.0, Color("a9cfe0"), Color("7fa9c0"))  # windscreen
	_rr(im, 8.5, 7.5, 11.5, 13.5, 1.0, Color("86aec4"), Color("6b92aa"))  # rear glass
	_ell(im, 34, 6.5, 1.6, 1.4, Color("fff3c4"))  # headlights
	_ell(im, 34, 14.5, 1.6, 1.4, Color("fff3c4"))
	_ell(im, 2.5, 6.5, 1.2, 1.2, Color("b83a3a"))  # tail lights
	_ell(im, 2.5, 14.5, 1.2, 1.2, Color("b83a3a"))
	return _bake(key, im)


## A wooden cart facing +x, 10 x 6 world pixels, with spoked wheels and a straw load.
static func cart() -> ImageTexture:
	if cache.has("cart"):
		return cache["cart"]
	var im := _blank(10, 6)
	_ell(im, 15, 16, 14, 6, Color(0, 0, 0, 0.2))
	for y in [0.5, 13.5]:
		_rr(im, 5, y, 13, y + 4, 2.0, Color("3a2a1a"), Color("5a432a"))
		_rr(im, 18, y, 26, y + 4, 2.0, Color("3a2a1a"), Color("5a432a"))
	_rr(im, 2, 3, 28, 15, 2.0, Color("a07a48"), Color("6e5230"))  # bed
	_rr(im, 4, 5, 22, 13, 3.0, Color("d8b861"), Color("b8963f"))  # straw load
	_rr(im, 27, 7, 30, 11, 1.5, Color("5a432a"), Color("5a432a"))  # shaft
	return _bake("cart", im)


## A person seen from above, 6 x 8 world pixels, in greys so it can be tinted with the mood colour.
static func person() -> ImageTexture:
	if cache.has("person"):
		return cache["person"]
	var im := _blank(6, 8)
	_ell(im, 9, 18.5, 6.5, 3.5, Color(0, 0, 0, 0.3))
	_rr(im, 3.5, 9, 14.5, 20, 4.5, Color(0.72, 0.72, 0.72), Color(0.5, 0.5, 0.5))  # shoulders and body
	_ell(im, 9, 7.5, 5.2, 5.2, Color(1, 1, 1))  # head
	return _bake("person", im)


static func _blank(w: float, h: float) -> Image:
	return Image.create_empty(int(w * SS), int(h * SS), false, Image.FORMAT_RGBA8)


static func _bake(key: String, im: Image) -> ImageTexture:
	var t := ImageTexture.create_from_image(im)
	cache[key] = t
	return t


static func _over(im: Image, x: int, y: int, c: Color, cover: float) -> void:
	var a := c.a * clampf(cover, 0.0, 1.0)
	if a <= 0.0:
		return
	var d := im.get_pixel(x, y)
	var oa := a + d.a * (1.0 - a)
	var rgb := (Vector3(c.r, c.g, c.b) * a + Vector3(d.r, d.g, d.b) * d.a * (1.0 - a)) / oa
	im.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, oa))


## Filled ellipse with a one-pixel soft edge.
static func _ell(im: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(maxi(0, int(cy - ry) - 1), mini(im.get_height(), int(cy + ry) + 2)):
		for x in range(maxi(0, int(cx - rx) - 1), mini(im.get_width(), int(cx + rx) + 2)):
			var d := Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry).length()
			_over(im, x, y, c, (1.0 - d) * minf(rx, ry) + 0.5)


## Rounded rectangle with a top-to-bottom colour gradient and a one-pixel soft edge.
static func _rr(im: Image, x0: float, y0: float, x1: float, y1: float, r: float, top: Color, bot: Color) -> void:
	var half := Vector2(x1 - x0, y1 - y0) * 0.5
	var mid := Vector2(x0, y0) + half
	for y in range(maxi(0, int(y0) - 1), mini(im.get_height(), int(y1) + 2)):
		for x in range(maxi(0, int(x0) - 1), mini(im.get_width(), int(x1) + 2)):
			var q := (Vector2(x + 0.5, y + 0.5) - mid).abs() - half + Vector2(r, r)
			var dist := q.maxf(0.0).length() + minf(maxf(q.x, q.y), 0.0) - r
			_over(im, x, y, top.lerp(bot, clampf((y + 0.5 - y0) / (y1 - y0), 0.0, 1.0)), 0.5 - dist)
