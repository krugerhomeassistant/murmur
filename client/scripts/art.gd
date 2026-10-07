class_name Art
extends RefCounted
## Hand-drawn building art from primitives. Everything is drawn in a 32x32 local space (call with the tile's top-left).
## No image files: shapes only, so it ships inside the scripts.

const T = Catalog.Id
const PAVE := Color("b9b6a6")
const GLASS := Color("9cc4dc")
const LIT := Color("ffd98a")


static func _r(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, h), c)


static func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), col)


static func _win(ci: CanvasItem, x: float, y: float, w: float, h: float, night: bool) -> void:
	_r(ci, x, y, w, h, LIT if night else GLASS)
	_r(ci, x, y, w, 1, Color(1, 1, 1, 0.35))


static func _cols(ci: CanvasItem, x: float, y: float, w: float, h: float, n: int, c: Color) -> void:
	for k in n:
		_r(ci, x + k * (w - 2.0) / maxf(n - 1, 1), y, 2, h, c)


static func _smoke(ci: CanvasItem, x: float, y: float, seed_: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for k in 3:
		var f := fmod(t * 0.7 + seed_ + k * 0.33, 1.0)
		ci.draw_circle(Vector2(x + f * 5.0, y - f * 12.0), 1.5 + f * 2.5, Color(0.8, 0.8, 0.8, 0.55 * (1.0 - f)))


static func _flag(ci: CanvasItem, x: float, y: float, c: Color) -> void:
	_r(ci, x, y, 1, 9, Color("4a4a4a"))
	var w := sin(Time.get_ticks_msec() * 0.006) * 1.0
	_tri(ci, Vector2(x + 1, y), Vector2(x + 7, y + 2 + w), Vector2(x + 1, y + 4), c)


## Draw one service building. Returns true if there is bespoke art for it.
static func service(ci: CanvasItem, r: Rect2, id: int, ok: bool, night: bool) -> bool:
	if not _has(id):
		return false
	ci.draw_set_transform(r.position)
	var dim := Color.WHITE if ok else Color(0.62, 0.62, 0.62)
	ci.draw_rect(Rect2(1, 1, 30, 30), Color("a9b59a") * dim)
	_draw(ci, id, night, dim)
	ci.draw_set_transform(Vector2.ZERO)
	return true


static func _has(id: int) -> bool:
	return id in [T.FIRE, T.POLICE, T.CLINIC, T.HOSPITAL, T.SCHOOL, T.LIBRARY, T.UNIVERSITY, T.PARK, T.PLAYGROUND, T.PLAZA, T.CINEMA, T.MUSEUM, T.STADIUM, T.THEME, T.CHURCH, T.BAR, T.BUS, T.TRAIN, T.WIND, T.SOLAR, T.COAL, T.WATER, T.LANDFILL, T.RECYCLE, T.MARKET, T.BANK, T.MALL, T.HOTEL, T.UNION_HALL, T.CHAMBER, T.COURT, T.PRISON, T.BASE, T.BARRACKS, T.RADAR, T.MILL, T.WAREHOUSE, T.DEPOT, T.TOWNHALL, T.SEWAGE, T.PORT, T.NAVYARD, T.FISHDOCK, T.FOUNDRY]


static func _draw(ci: CanvasItem, id: int, night: bool, k: Color) -> void:
	var t := Time.get_ticks_msec() * 0.001
	match id:
		T.FIRE:
			_r(ci, 3, 11, 20, 17, Color("c0392b") * k)
			_r(ci, 3, 9, 20, 3, Color("7b241c") * k)
			for g in 2:
				_r(ci, 5 + g * 9, 16, 7, 12, Color("d5d8dc") * k)
				for s in 4:
					_r(ci, 5 + g * 9, 18 + s * 2.5, 7, 1, Color("909497") * k)
			_r(ci, 24, 5, 6, 23, Color("a93226") * k)
			_r(ci, 24, 3, 6, 3, Color("7b241c") * k)
			ci.draw_circle(Vector2(27, 9), 1.8, Color("f4d03f") * k)
			_r(ci, 8, 12, 12, 2, Color.WHITE * k)
		T.POLICE:
			_r(ci, 3, 10, 26, 18, Color("34495e") * k)
			_r(ci, 3, 8, 26, 3, Color("1b2631") * k)
			_r(ci, 13, 14, 6, 14, Color("2c3e50") * k)
			ci.draw_circle(Vector2(16, 19), 0.1, Color.WHITE)
			var star := PackedVector2Array()
			for s in 10:
				var a := -PI / 2 + s * PI / 5
				star.append(Vector2(16, 14) + Vector2.from_angle(a) * (4.0 if s % 2 == 0 else 1.8))
			ci.draw_colored_polygon(star, Color("f1c40f") * k)
			var fl := int(t * 4.0) % 2 == 0
			ci.draw_circle(Vector2(8, 7), 2.0, (Color("e74c3c") if fl else Color("2e86c1")) * k)
			ci.draw_circle(Vector2(24, 7), 2.0, (Color("2e86c1") if fl else Color("e74c3c")) * k)
			_win(ci, 5, 16, 6, 5, night)
			_win(ci, 21, 16, 6, 5, night)
		T.CLINIC:
			_r(ci, 4, 10, 24, 18, Color("ecf0f1") * k)
			_tri(ci, Vector2(3, 10), Vector2(29, 10), Vector2(16, 3), Color("c0392b") * k)
			_r(ci, 14, 20, 5, 8, Color("5d6d7e") * k)
			_r(ci, 14, 12, 4, 1, Color.WHITE)
			_r(ci, 15, 11, 2, 5, Color("e74c3c") * k)
			_r(ci, 13.5, 12.5, 5, 2, Color("e74c3c") * k)
			_win(ci, 6, 14, 5, 5, night)
			_win(ci, 22, 14, 5, 5, night)
		T.HOSPITAL:
			_r(ci, 3, 9, 26, 20, Color("ecf0f1") * k)
			_r(ci, 11, 3, 10, 26, Color("d6dbdf") * k)
			_r(ci, 15, 5, 2, 8, Color("e74c3c") * k)
			_r(ci, 12, 8, 8, 2, Color("e74c3c") * k)
			for row in 3:
				_win(ci, 5, 12 + row * 5, 4, 3, night)
				_win(ci, 23, 12 + row * 5, 4, 3, night)
				_win(ci, 13, 14 + row * 4.5, 6, 2, night)
			_r(ci, 14, 24, 4, 5, Color("5d6d7e") * k)
		T.SCHOOL:
			_r(ci, 3, 13, 26, 15, Color("b5651d") * k)
			_r(ci, 3, 11, 26, 3, Color("7e4a1e") * k)
			_r(ci, 12, 5, 8, 9, Color("a0561a") * k)
			_tri(ci, Vector2(11, 5), Vector2(21, 5), Vector2(16, 0), Color("5b3a1a") * k)
			ci.draw_circle(Vector2(16, 9), 1.6, Color("f4d03f") * k)
			for g in 4:
				_win(ci, 5 + g * 6, 17, 4, 4, night)
			_r(ci, 14, 22, 4, 6, Color("4a2e12") * k)
			_flag(ci, 4, 3, Color("e74c3c") * k)
		T.LIBRARY:
			_r(ci, 4, 14, 24, 14, Color("e5d9b6") * k)
			_tri(ci, Vector2(3, 14), Vector2(29, 14), Vector2(16, 6), Color("c9b98a") * k)
			_cols(ci, 7, 15, 18, 11, 4, Color("f7f1dc") * k)
			_r(ci, 3, 27, 26, 2, Color("b8ad8a") * k)
			_r(ci, 14, 9, 4, 3, Color("7d6b3d") * k)
		T.UNIVERSITY:
			_r(ci, 2, 15, 28, 13, Color("a9a07e") * k)
			_r(ci, 11, 8, 10, 20, Color("c7bd98") * k)
			ci.draw_circle(Vector2(16, 8), 5.0, Color("5d8aa8") * k)
			_r(ci, 15.5, 1, 1, 4, Color("4a4a4a"))
			_win(ci, 4, 18, 4, 5, night)
			_win(ci, 24, 18, 4, 5, night)
			_cols(ci, 12, 17, 8, 10, 3, Color("f1ecd7") * k)
			ci.draw_circle(Vector2(16, 12), 1.5, Color.WHITE)
		T.PARK:
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("6fae5a") * k)
			ci.draw_line(Vector2(2, 22), Vector2(30, 12), Color("d9cfa8") * k, 3.0)
			for p in [Vector2(8, 9), Vector2(23, 22), Vector2(10, 25), Vector2(25, 6)]:
				_r(ci, p.x - 1, p.y, 2, 6, Color("6b4a2a"))
				ci.draw_circle(p + Vector2(0, -1), 5.0, Color("3f7a3a") * k)
				ci.draw_circle(p + Vector2(-1.5, -2.5), 2.5, Color("5a9a4a") * k)
			_r(ci, 15, 16, 6, 2, Color("8a5a2a"))
		T.PLAYGROUND:
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("e3cf94") * k)
			_r(ci, 4, 7, 2, 12, Color("c0392b"))
			_r(ci, 14, 7, 2, 12, Color("c0392b"))
			_r(ci, 4, 7, 12, 2, Color("c0392b"))
			var sw := sin(t * 2.5) * 3.0
			ci.draw_line(Vector2(8, 9), Vector2(8 + sw, 17), Color.WHITE, 1.0)
			ci.draw_line(Vector2(12, 9), Vector2(12 + sw, 17), Color.WHITE, 1.0)
			_r(ci, 7 + sw, 17, 6, 2, Color("2e86c1"))
			_tri(ci, Vector2(22, 8), Vector2(22, 24), Vector2(29, 24), Color("f39c12") * k)
			_r(ci, 20, 6, 4, 3, Color("27ae60"))
		T.PLAZA:
			for gx in 6:
				for gy in 6:
					_r(ci, 1 + gx * 5, 1 + gy * 5, 4.5, 4.5, (Color("cfc8b4") if (gx + gy) % 2 == 0 else Color("bdb6a0")) * k)
			ci.draw_circle(Vector2(16, 16), 9.0, Color("8d8671") * k)
			ci.draw_circle(Vector2(16, 16), 7.5, Color("4f9fd6") * k)
			var rp := fmod(t * 0.8, 1.0)
			ci.draw_arc(Vector2(16, 16), 2.0 + rp * 5.0, 0, TAU, 16, Color(1, 1, 1, 1.0 - rp), 1.0)
			ci.draw_circle(Vector2(16, 16), 2.0, Color("8d8671") * k)
		T.CINEMA:
			_r(ci, 3, 10, 26, 18, Color("4a2c5a") * k)
			_r(ci, 3, 8, 26, 5, Color("2e1a3a") * k)
			for b in 8:
				ci.draw_circle(Vector2(5.5 + b * 3.0, 10.5), 1.0, LIT if (int(t * 3.0) + b) % 2 == 0 else Color("7a6a3a"))
			_r(ci, 6, 15, 7, 9, Color("e8d9a8") * k)
			_r(ci, 19, 15, 7, 9, Color("e8d9a8") * k)
			_r(ci, 14, 22, 4, 6, Color("1a1020"))
			ci.draw_circle(Vector2(9.5, 19), 1.8, Color("c0392b") * k)
		T.MUSEUM:
			_r(ci, 3, 25, 26, 4, Color("b8b4a4") * k)
			_r(ci, 4, 12, 24, 13, Color("ded7c0") * k)
			_tri(ci, Vector2(2, 12), Vector2(30, 12), Vector2(16, 4), Color("c9c1a6") * k)
			_cols(ci, 6, 13, 20, 12, 5, Color("f6f1e0") * k)
			ci.draw_circle(Vector2(16, 9), 1.6, Color("8a7a4a") * k)
		T.STADIUM:
			ci.draw_rect(Rect2(1, 4, 30, 24), Color("9a9a96") * k)
			ci.draw_rect(Rect2(3, 6, 26, 20), Color("c9835a") * k)
			ci.draw_rect(Rect2(6, 9, 20, 14), Color("4f9a45") * k)
			ci.draw_rect(Rect2(6, 9, 20, 14), Color.WHITE, false, 1.0)
			ci.draw_line(Vector2(16, 9), Vector2(16, 23), Color.WHITE, 1.0)
			ci.draw_circle(Vector2(16, 16), 3.0, Color(1, 1, 1, 0))
			ci.draw_arc(Vector2(16, 16), 3.0, 0, TAU, 12, Color.WHITE, 1.0)
			for l in 4:
				_r(ci, 2 + (l % 2) * 27, 2 + (l / 2) * 25, 2, 4, Color("555555"))
		T.THEME:
			var cx := Vector2(16, 14)
			ci.draw_circle(cx, 11.0, Color(0, 0, 0, 0))
			ci.draw_arc(cx, 10.0, 0, TAU, 24, Color("e8e2d0") * k, 1.5)
			for s in 6:
				var a := t * 0.6 + s * TAU / 6.0
				ci.draw_line(cx, cx + Vector2.from_angle(a) * 10.0, Color("c8c2b0") * k, 1.0)
				ci.draw_circle(cx + Vector2.from_angle(a) * 10.0, 2.0, [Color("e74c3c"), Color("f1c40f"), Color("3498db")][s % 3] * k)
			_tri(ci, Vector2(10, 29), Vector2(16, 14), Vector2(22, 29), Color("7a5a3a") * k)
			_r(ci, 3, 24, 8, 5, Color("e74c3c") * k)
			_tri(ci, Vector2(2, 24), Vector2(12, 24), Vector2(7, 19), Color("f1c40f") * k)
		T.CHURCH:
			_r(ci, 4, 14, 16, 14, Color("e8e0cc") * k)
			_tri(ci, Vector2(3, 14), Vector2(21, 14), Vector2(12, 8), Color("8a5a3a") * k)
			_r(ci, 20, 7, 8, 21, Color("ddd5be") * k)
			_tri(ci, Vector2(19, 7), Vector2(29, 7), Vector2(24, -1), Color("6a4a30") * k)
			_r(ci, 23.5, -2, 1, 5, Color("f4d03f"))
			_r(ci, 22.5, -0.5, 3, 1, Color("f4d03f"))
			_r(ci, 10, 21, 4, 7, Color("5a3a22") * k)
			ci.draw_circle(Vector2(12, 17), 2.0, Color("e74c3c") if not night else LIT)
			_win(ci, 22.5, 11, 3, 5, night)
		T.BAR:
			_r(ci, 4, 11, 24, 17, Color("7a4a2a") * k)
			for s in 6:
				_r(ci, 4 + s * 4, 11, 4, 5, (Color("c0392b") if s % 2 == 0 else Color("f0e6d0")) * k)
			_win(ci, 6, 19, 6, 5, night)
			_r(ci, 14, 19, 4, 9, Color("3a2412"))
			_r(ci, 21, 18, 6, 6, Color("f1c40f") * k)
			_r(ci, 22, 19, 3, 4, Color("f9e79f") * k)
			for b in 6:
				ci.draw_circle(Vector2(5.0 + b * 4.4, 9), 1.0, LIT if night else Color("c8b878"))
		T.BUS:
			_r(ci, 3, 18, 12, 2, Color("555555"))
			_r(ci, 3, 8, 12, 2, Color("2e86c1") * k)
			_r(ci, 3, 8, 1, 12, Color("2e86c1") * k)
			_r(ci, 14, 8, 1, 12, Color("2e86c1") * k)
			_r(ci, 5, 12, 8, 3, Color("d6eaf8") * k)
			var bx := 7.0 + fmod(t * 5.0, 12.0)
			_r(ci, bx - 6, 21, 18, 8, Color("f1c40f") * k)
			_win(ci, bx - 4, 22, 4, 3, night)
			_win(ci, bx + 2, 22, 4, 3, night)
			ci.draw_circle(Vector2(bx - 1, 29), 2.0, Color("222222"))
			ci.draw_circle(Vector2(bx + 8, 29), 2.0, Color("222222"))
		T.TRAIN:
			_r(ci, 4, 6, 24, 12, Color("8e6e53") * k)
			_tri(ci, Vector2(3, 6), Vector2(29, 6), Vector2(16, 0), Color("5d4636") * k)
			ci.draw_circle(Vector2(16, 10), 3.0, Color("f7f1dc") * k)
			ci.draw_line(Vector2(16, 10), Vector2(16, 8), Color("222222"), 1.0)
			ci.draw_line(Vector2(16, 10), Vector2(17.5, 10), Color("222222"), 1.0)
			_r(ci, 1, 22, 30, 1.5, Color("555555"))
			_r(ci, 1, 27, 30, 1.5, Color("555555"))
			for s in 8:
				_r(ci, 2 + s * 4, 21, 1.5, 8, Color("6b4a2a"))
			var tx := fmod(t * 4.0, 10.0)
			_r(ci, 3 + tx, 22.5, 14, 4.5, Color("c0392b") * k)
			_win(ci, 5 + tx, 23, 3, 2, night)
			_win(ci, 10 + tx, 23, 3, 2, night)
		T.WIND:
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("93b383") * k)
			_tri(ci, Vector2(14, 29), Vector2(18, 29), Vector2(16, 11), Color("ecf0f1") * k)
			var a := t * 1.8
			for s in 3:
				ci.draw_line(Vector2(16, 11), Vector2(16, 11) + Vector2.from_angle(a + s * TAU / 3.0) * 12.0, Color.WHITE * k, 2.0)
			ci.draw_circle(Vector2(16, 11), 2.0, Color("bdc3c7") * k)
		T.SOLAR:
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("9aa88a") * k)
			for gx in 2:
				for gy in 3:
					var px := 3.0 + gx * 14.0
					var py := 3.0 + gy * 9.0
					ci.draw_colored_polygon(PackedVector2Array([Vector2(px, py + 6), Vector2(px + 2, py), Vector2(px + 12, py), Vector2(px + 10, py + 6)]), Color("1f3a68") * k)
					ci.draw_line(Vector2(px + 6, py), Vector2(px + 5, py + 6), Color("5a7ab8"), 1.0)
					ci.draw_line(Vector2(px + 1, py + 3), Vector2(px + 11, py + 3), Color("5a7ab8"), 1.0)
			ci.draw_circle(Vector2(26, 6), 1.5, Color("ffe08a"))
		T.COAL:
			_r(ci, 3, 16, 26, 12, Color("5d6d7e") * k)
			_r(ci, 3, 14, 26, 3, Color("34495e") * k)
			_r(ci, 6, 3, 5, 15, Color("7b7d7d") * k)
			_r(ci, 15, 6, 5, 12, Color("7b7d7d") * k)
			_r(ci, 6, 3, 5, 2, Color("c0392b") * k)
			_r(ci, 15, 6, 5, 2, Color("c0392b") * k)
			_smoke(ci, 8.5, 3, 0.0)
			_smoke(ci, 17.5, 6, 0.5)
			_r(ci, 22, 19, 5, 9, Color("2c3e50") * k)
			_win(ci, 6, 21, 4, 3, night)
		T.FISHDOCK:
			_r(ci, 2, 24, 28, 5, Color("8a6a4a") * k)
			for s in 5:
				_r(ci, 3 + s * 6, 24, 2, 7, Color("5a4228") * k)
			_r(ci, 6, 12, 12, 12, Color("c9b38a") * k)
			_tri(ci, Vector2(4, 12), Vector2(20, 12), Vector2(12, 5), Color("6a7a8a") * k)
			_win(ci, 9, 16, 5, 4, night)
			for s in 3:
				ci.draw_line(Vector2(22, 14 + s * 3), Vector2(28, 14 + s * 3), Color("d8d0b0"), 1.0)
			ci.draw_line(Vector2(22, 12), Vector2(22, 24), Color("5a4228"), 1.0)
			ci.draw_line(Vector2(28, 12), Vector2(28, 24), Color("5a4228"), 1.0)
		T.PORT, T.NAVYARD:
			var navy := id == T.NAVYARD
			_r(ci, 2, 22, 28, 7, Color("7a7a72") * k)
			_r(ci, 2, 26, 28, 3, Color("5a5a54") * k)
			if navy:
				_r(ci, 5, 12, 14, 10, Color("6a7a8a") * k)
				_r(ci, 7, 9, 10, 3, Color("8a9aaa") * k)
				ci.draw_line(Vector2(12, 9), Vector2(12, 3), Color("2a2a2a"), 1.0)
				_flag(ci, 12, 3, Color("2e86c1") * k)
				_r(ci, 22, 18, 6, 4, Color("4a5a3a") * k)
			else:
				for s in 3:
					_r(ci, 3 + s * 6, 17, 5, 5, [Color("c0392b"), Color("2e86c1"), Color("d68910")][s] * k)
				ci.draw_line(Vector2(24, 22), Vector2(24, 6), Color("e0a030"), 2.0)
				ci.draw_line(Vector2(24, 6), Vector2(12, 6), Color("e0a030"), 2.0)
				ci.draw_line(Vector2(14, 6), Vector2(14, 12 + 3.0 * sin(t)), Color("2a2a2a"), 1.0)
		T.SEWAGE:
			_r(ci, 3, 20, 26, 9, Color("8a8576") * k)
			for s in 2:
				var cx := 9.0 + s * 14.0
				ci.draw_circle(Vector2(cx, 13), 7.0, Color("9a7a4a") * k)
				ci.draw_circle(Vector2(cx, 13), 5.0, Color("6b5a34") * k)
				ci.draw_circle(Vector2(cx + 1.5 * sin(t * 1.5 + s), 13 + 1.5 * cos(t * 1.5 + s)), 1.5, Color("b8a070") * k)
			_r(ci, 12, 22, 8, 7, Color("5a4a2a") * k)
			_smoke(ci, 26, 20, 0.3)
		T.WATER:
			for l in 2:
				_r(ci, 10 + l * 10, 17, 2, 12, Color("5d6d7e") * k)
			ci.draw_line(Vector2(11, 18), Vector2(21, 28), Color("7f8c8d"), 1.0)
			ci.draw_line(Vector2(21, 18), Vector2(11, 28), Color("7f8c8d"), 1.0)
			_r(ci, 6, 6, 20, 11, Color("3a86c8") * k)
			_tri(ci, Vector2(5, 6), Vector2(27, 6), Vector2(16, 0), Color("2b5f8f") * k)
			_r(ci, 6, 10, 20, 1, Color(1, 1, 1, 0.3))
			_r(ci, 6, 13, 20, 1, Color(0, 0, 0, 0.18))
		T.LANDFILL:
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("8a7a58") * k)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(2, 28), Vector2(8, 14), Vector2(16, 9), Vector2(25, 15), Vector2(30, 28)]), Color("6b5a3e") * k)
			for s in 9:
				var q := Vector2(6 + (s * 7) % 22, 16 + (s * 5) % 11)
				ci.draw_rect(Rect2(q.x, q.y, 2, 2), [Color("c0392b"), Color("2e86c1"), Color("ecf0f1")][s % 3])
			var bd := Vector2(16 + sin(t * 1.2) * 8.0, 6 + cos(t * 1.7) * 2.0)
			ci.draw_line(bd, bd + Vector2(2, -1), Color.WHITE, 1.0)
			ci.draw_line(bd, bd + Vector2(-2, -1), Color.WHITE, 1.0)
		T.RECYCLE:
			_r(ci, 3, 10, 26, 18, Color("3f7a4a") * k)
			_r(ci, 3, 8, 26, 3, Color("2a5a34") * k)
			for s in 3:
				var a2 := -PI / 2 + s * TAU / 3.0
				var p0 := Vector2(16, 19) + Vector2.from_angle(a2) * 5.0
				var p1 := Vector2(16, 19) + Vector2.from_angle(a2 + 2.0) * 5.0
				ci.draw_line(p0, p1, Color.WHITE, 1.5)
				_tri(ci, p1, p1 + Vector2.from_angle(a2 + 2.0 + 1.0) * 3.0, p1 + Vector2.from_angle(a2 + 2.0 - 1.4) * 3.0, Color.WHITE)
			for b in 3:
				_r(ci, 5 + b * 4, 24, 3, 4, [Color("2e86c1"), Color("f1c40f"), Color("7f8c8d")][b])
		T.MARKET:
			for s in 3:
				var x0 := 3.0 + s * 9.0
				_r(ci, x0, 12, 8, 3, (Color("e74c3c") if s % 2 == 0 else Color("f0e6d0")) * k)
				_r(ci, x0, 15, 8, 8, Color("8a5a2a") * k)
				ci.draw_circle(Vector2(x0 + 2.5, 22), 1.6, [Color("e74c3c"), Color("f1c40f"), Color("27ae60")][s])
				ci.draw_circle(Vector2(x0 + 5.5, 22), 1.6, [Color("f39c12"), Color("e74c3c"), Color("f1c40f")][s])
				_r(ci, x0, 12, 1, 12, Color("6b4a2a"))
			_r(ci, 2, 25, 28, 3, Color("a08a66") * k)
		T.BANK:
			_r(ci, 3, 25, 26, 4, Color("9aa0a6") * k)
			_r(ci, 4, 12, 24, 13, Color("d8dcdf") * k)
			_tri(ci, Vector2(2, 12), Vector2(30, 12), Vector2(16, 5), Color("b2b8bd") * k)
			_cols(ci, 6, 13, 20, 12, 5, Color("f4f6f7") * k)
			ci.draw_circle(Vector2(16, 9), 2.6, Color("f1c40f") * k)
			_r(ci, 15.5, 7.5, 1, 3, Color("9a7d0a"))
		T.MALL:
			_r(ci, 2, 9, 28, 19, Color("8e7cc3") * k)
			_r(ci, 2, 7, 28, 3, Color("5b4a8a") * k)
			_r(ci, 5, 14, 22, 8, GLASS * k)
			for s in 4:
				_r(ci, 8 + s * 5, 14, 1, 8, Color(1, 1, 1, 0.5))
			_r(ci, 13, 22, 6, 6, Color("2c2a3a"))
			_r(ci, 5, 10, 22, 3, LIT if night else Color("f3e7cf"))
			_r(ci, 3, 29, 5, 2, Color("e74c3c"))
			_r(ci, 12, 29, 5, 2, Color("2e86c1"))
		T.HOTEL:
			_r(ci, 6, 5, 20, 23, Color("c9a27a") * k)
			_r(ci, 6, 3, 20, 3, Color("8a6a4a") * k)
			for row in 4:
				for col in 3:
					_win(ci, 8 + col * 6, 8 + row * 4.5, 4, 3, night and (row + col) % 2 == 0)
			_r(ci, 13, 24, 6, 4, Color("3a2a1a"))
			_r(ci, 9, 22, 14, 2, Color("c0392b") * k)
			ci.draw_circle(Vector2(16, 4), 1.4, Color("f1c40f"))
		T.UNION_HALL:
			_r(ci, 4, 12, 24, 16, Color("a0522d") * k)
			_r(ci, 3, 10, 26, 3, Color("6e3a1c") * k)
			_r(ci, 11, 2, 10, 9, Color("c0392b") * k)
			ci.draw_arc(Vector2(16, 6.5), 2.6, 0, TAU, 10, Color.WHITE, 1.2)
			for s in 6:
				var a3 := s * TAU / 6.0
				ci.draw_line(Vector2(16, 6.5) + Vector2.from_angle(a3) * 2.4, Vector2(16, 6.5) + Vector2.from_angle(a3) * 3.6, Color.WHITE, 1.0)
			_win(ci, 6, 16, 5, 5, night)
			_win(ci, 21, 16, 5, 5, night)
			_r(ci, 14, 20, 4, 8, Color("3a1f0e"))
		T.CHAMBER:
			_r(ci, 4, 11, 24, 17, Color("5d7a99") * k)
			_r(ci, 3, 9, 26, 3, Color("3a5470") * k)
			_cols(ci, 6, 12, 20, 14, 4, Color("e8edf2") * k)
			ci.draw_circle(Vector2(16, 6), 3.0, Color("f1c40f") * k)
			ci.draw_arc(Vector2(16, 6), 3.0, 0, TAU, 10, Color("9a7d0a"), 1.0)
			_flag(ci, 5, 1, Color("2e86c1") * k)
		T.COURT:
			_r(ci, 3, 25, 26, 4, Color("9d9a90") * k)
			_r(ci, 4, 12, 24, 13, Color("cfcbbd") * k)
			_tri(ci, Vector2(2, 12), Vector2(30, 12), Vector2(16, 5), Color("a8a496") * k)
			_cols(ci, 6, 13, 20, 12, 4, Color("f1eee2") * k)
			ci.draw_line(Vector2(16, 7), Vector2(16, 11), Color("4a4a4a"), 1.0)
			ci.draw_line(Vector2(12, 8), Vector2(20, 8), Color("4a4a4a"), 1.0)
			ci.draw_arc(Vector2(12, 9.5), 1.5, 0, PI, 6, Color("4a4a4a"), 1.0)
			ci.draw_arc(Vector2(20, 9.5), 1.5, 0, PI, 6, Color("4a4a4a"), 1.0)
		T.PRISON:
			_r(ci, 2, 12, 28, 17, Color("7f8c8d") * k)
			_r(ci, 2, 10, 28, 3, Color("566573") * k)
			for s in 4:
				_r(ci, 5 + s * 6, 16, 4, 5, Color("2c3e50"))
				for b in 3:
					_r(ci, 5.8 + s * 6 + b * 1.2, 16, 0.6, 5, Color("aab7b8"))
			_r(ci, 13, 23, 6, 6, Color("2c3e50"))
			_r(ci, 1, 4, 5, 9, Color("566573") * k)
			_r(ci, 26, 4, 5, 9, Color("566573") * k)
			_r(ci, 0, 3, 7, 2, Color("34495e"))
			_r(ci, 25, 3, 7, 2, Color("34495e"))
			if night:
				ci.draw_circle(Vector2(3.5, 6), 1.2, LIT)
		T.BASE:
			_r(ci, 2, 12, 28, 16, Color("6b7a4a") * k)
			for s in 5:
				_r(ci, 2 + s * 6, 9, 4, 4, Color("55633a") * k)
			_r(ci, 12, 18, 8, 10, Color("3a4326"))
			_r(ci, 4, 15, 6, 4, Color("8a9a66") * k)
			ci.draw_rect(Rect2(21, 20, 7, 4), Color("4a5436") * k)
			_r(ci, 24, 18, 5, 1.5, Color("4a5436"))
			_flag(ci, 15, 0, Color("c0392b") * k)
		T.BARRACKS:
			_r(ci, 2, 12, 28, 16, Color("84795a") * k)
			_tri(ci, Vector2(1, 12), Vector2(31, 12), Vector2(16, 6), Color("5d5640") * k)
			for s in 5:
				_win(ci, 4 + s * 5.2, 17, 3, 4, night)
			_r(ci, 13, 22, 6, 6, Color("3a3426"))
			_flag(ci, 26, 2, Color("e74c3c") * k)
		T.RADAR:
			_r(ci, 12, 14, 8, 14, Color("7f8c8d") * k)
			_r(ci, 8, 26, 16, 3, Color("566573") * k)
			var ra := t * 1.6
			ci.draw_arc(Vector2(16, 12), 10.0, ra, ra + 2.4, 12, Color("ecf0f1") * k, 3.0)
			ci.draw_line(Vector2(16, 12), Vector2(16, 14), Color("7f8c8d"), 2.0)
			ci.draw_arc(Vector2(16, 12), 13.0, ra - 0.2, ra + 0.8, 8, Color(0.5, 1.0, 0.6, 0.5), 1.0)
		T.FOUNDRY:
			_r(ci, 6, 14, 20, 14, Color("8a5a4a") * k)
			_r(ci, 20, 4, 4, 11, Color("5a4a44") * k)
			ci.draw_circle(Vector2(22, 4), 2.0, Color("ff9a3c") if int(t * 2.0) % 2 == 0 else Color("a8501c"))
			_r(ci, 10, 20, 8, 8, Color("ff9a3c") * k)
		T.FOUNDRY:
			_r(ci, 6, 14, 20, 15, Color("7a6a62") * k)
			_r(ci, 20, 4, 5, 12, Color("5a4a44") * k)
			ci.draw_circle(Vector2(22, 4 + 2.0 * sin(t * 2.0)), 3.0, Color(1.0, 0.55, 0.2, 0.7))
			_r(ci, 10, 20, 8, 9, Color("e67e22") * k)
		T.MILL:
			_r(ci, 9, 12, 14, 17, Color("c9b98a") * k)
			_tri(ci, Vector2(8, 12), Vector2(24, 12), Vector2(16, 5), Color("8a5a3a") * k)
			var ma := t * 1.2
			for s in 4:
				var d := Vector2.from_angle(ma + s * PI / 2.0)
				ci.draw_line(Vector2(16, 12), Vector2(16, 12) + d * 11.0, Color("f0e6d0") * k, 2.0)
				ci.draw_line(Vector2(16, 12) + d * 5.0, Vector2(16, 12) + d * 11.0 + Vector2(-d.y, d.x) * 2.5, Color("d8cba8"), 1.0)
			ci.draw_circle(Vector2(16, 12), 1.8, Color("5a3a22"))
			_r(ci, 14, 22, 4, 7, Color("5a3a22"))
		T.WAREHOUSE:
			_r(ci, 2, 11, 28, 17, Color("8d9aa5") * k)
			_tri(ci, Vector2(1, 11), Vector2(31, 11), Vector2(16, 6), Color("5d6d7e") * k)
			for s in 3:
				_r(ci, 4 + s * 9, 16, 8, 12, Color("b8c2cc") * k)
				for l in 5:
					_r(ci, 4 + s * 9, 17 + l * 2.4, 8, 0.8, Color("8a949c"))
			_r(ci, 24, 4, 3, 4, Color("a0522d"))
		T.DEPOT:
			_r(ci, 2, 10, 17, 18, Color("7a8a9a") * k)
			_tri(ci, Vector2(1, 10), Vector2(20, 10), Vector2(10, 5), Color("566573") * k)
			_r(ci, 5, 16, 11, 12, Color("c0c8d0") * k)
			for s in 3:
				_r(ci, 21, 8 + s * 7, 9, 6, [Color("e74c3c"), Color("2e86c1"), Color("f1c40f")][s] * k)
				_r(ci, 21, 8 + s * 7, 9, 1, Color(1, 1, 1, 0.3))
			var tx := 2.0 + fmod(t * 4.0, 14.0)
			_r(ci, tx, 29.5, 8, 2, Color("27ae60") * k)
		T.TOWNHALL:
			_r(ci, 3, 14, 26, 14, Color("d9cfb4") * k)
			_r(ci, 11, 6, 10, 22, Color("cfc4a6") * k)
			_tri(ci, Vector2(10, 6), Vector2(22, 6), Vector2(16, 0), Color("6a8aa8") * k)
			ci.draw_circle(Vector2(16, 10), 3.0, Color.WHITE * k)
			ci.draw_line(Vector2(16, 10), Vector2(16, 8), Color("222222"), 1.0)
			ci.draw_line(Vector2(16, 10), Vector2(17.5, 11), Color("222222"), 1.0)
			_cols(ci, 5, 16, 22, 11, 4, Color("f3edda") * k)
			_flag(ci, 22, -1, Color("2e86c1") * k)
			_r(ci, 14, 22, 4, 6, Color("5a4a2a"))


## Grown zone buildings (houses, shops, factories...). `h` varies colours per plot, `lv` is the level 1-3.
static func building(ci: CanvasItem, r: Rect2, shape: String, body: Color, lv: int, ok: bool, night: bool, h: int) -> bool:
	if not shape in ["house", "terrace", "tower", "condo", "shop", "factory", "office", "farm", "orchard", "ranch", "green", "fishfarm"]:
		return false
	ci.draw_set_transform(r.position)
	var k := Color.WHITE if ok else Color(0.6, 0.6, 0.6)
	var t := Time.get_ticks_msec() * 0.001
	var roofs := [Color("a5483a"), Color("6a7a8a"), Color("7a5a3a"), Color("8a3a3a"), Color("4a6a5a")]
	var walls := [Color("e8d9b8"), Color("d9c7a0"), Color("c9d3b8"), Color("e3c8b0"), Color("d8d8cc")]
	var roof: Color = roofs[h % roofs.size()] * k
	var wall: Color = walls[(h / 5) % walls.size()] * k
	match shape:
		"house":
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("86ab6c") * k)
			_r(ci, 2, 27, 28, 2, Color("c9bfa0") * k)
			var top := 10.0 - 4.0 * (lv - 1)
			_r(ci, 6, top + 6, 20, 21 - top - 6 + 6, wall)
			_tri(ci, Vector2(4, top + 6), Vector2(28, top + 6), Vector2(16, top - 3), roof)
			_r(ci, 14, 20, 5, 8, Color("5a3a22") * k)
			_win(ci, 8, top + 9, 4, 4, night)
			_win(ci, 21, top + 9, 4, 4, night)
			if lv >= 2:
				_win(ci, 14.5, top + 9, 4, 4, night)
			if lv >= 3:
				_r(ci, 22, 18, 7, 10, Color("9a9a90") * k)
			_r(ci, 22, top - 2, 3, 5, Color("7a4a3a") * k)
			if night and lv >= 2:
				_smoke(ci, 23.5, top - 2, (h % 7) * 0.13)
			_r(ci, 2, 26, 3, 3, Color("d85a8a") * k)
			ci.draw_circle(Vector2(28, 27), 2.0, Color("4a8a3a") * k)
		"terrace":
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("86ab6c") * k)
			for s in 3:
				var fx := 3.0 + s * 9.0
				var cc: Color = [Color("e0b8a0"), Color("c8d8b0"), Color("b8c8e0")][(s + h) % 3] * k
				_r(ci, fx, 12, 9, 16, cc)
				_tri(ci, Vector2(fx - 0.5, 12), Vector2(fx + 9.5, 12), Vector2(fx + 4.5, 5), roof)
				_win(ci, fx + 2, 15, 4.5, 4, night)
				_r(ci, fx + 3, 22, 3, 6, Color("5a3a22") * k)
				if lv >= 2:
					_win(ci, fx + 2, 8.5, 4.5, 2.5, night)
		"tower":
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("9aa08a") * k)
			var fl := 3 + lv * 2
			var ht := 6.0 + fl * 2.6
			var by := 29.0 - ht
			_r(ci, 6, by, 20, ht, body * k)
			_r(ci, 6, by, 20, 2, body.lightened(0.3) * k)
			for row in fl:
				for col in 3:
					_win(ci, 8 + col * 6, by + 3 + row * 2.6, 3.5, 1.8, night and (row * 3 + col + h) % 3 != 0)
			_r(ci, 14, 25, 4, 4, Color("3a2a1a") * k)
			_r(ci, 8, by - 2, 4, 2, Color("7f8c8d"))
		"condo":
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("9ab0a0") * k)
			var fl2 := 4 + lv * 2
			var ht2 := 8.0 + fl2 * 2.4
			var by2 := 29.0 - ht2
			_r(ci, 7, by2, 18, ht2, Color("7fb2d4") * k)
			_r(ci, 7, by2, 4, ht2, Color("5a8aaa") * k)
			for row in fl2:
				_r(ci, 7, by2 + 3 + row * 2.4, 18, 0.8, Color(1, 1, 1, 0.35))
				if night and (row + h) % 2 == 0:
					_r(ci, 12, by2 + 3.5 + row * 2.4, 11, 1.2, LIT)
			_r(ci, 6, by2 - 1, 20, 2, Color("e8edf2") * k)
			_r(ci, 14, 25, 5, 4, Color("2c3e50") * k)
			ci.draw_line(Vector2(9, by2 + 2), Vector2(12, by2 + ht2 - 3), Color(1, 1, 1, 0.4), 1.0)
		"shop":
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("a9ac9c") * k)
			var sc: Color = [Color("c0392b"), Color("2e86c1"), Color("27ae60"), Color("d68910")][h % 4] * k
			var ph := 14.0 + 3.0 * lv
			_r(ci, 3, 28 - ph, 26, ph, wall)
			_r(ci, 3, 28 - ph, 26, 3, sc.darkened(0.3))
			for s in 8:
				_r(ci, 3 + s * 3.25, 28 - ph + 3, 3.25, 4, sc if s % 2 == 0 else Color("f4efe0") * k)
			_win(ci, 5, 28 - ph + 9, 10, ph - 11, night)
			_r(ci, 18, 28 - ph + 9, 5, ph - 9, Color("4a3422") * k)
			_r(ci, 25, 28 - ph + 9, 3, 4, sc)
			if lv >= 2:
				_r(ci, 8, 28 - ph - 3, 16, 4, sc.darkened(0.2))
				_r(ci, 9, 28 - ph - 2, 14, 1, Color(1, 1, 1, 0.5))
		"factory":
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("9a9684") * k)
			var fh := 12.0 + 2.0 * lv
			_r(ci, 3, 29 - fh, 26, fh, Color("8a8576") * k)
			for s in 3:
				_tri(ci, Vector2(3 + s * 8.7, 29 - fh), Vector2(11.7 + s * 8.7, 29 - fh), Vector2(11.7 + s * 8.7, 29 - fh - 5), Color("6a665a") * k)
			_r(ci, 21, 29 - fh - 9, 4, 11, Color("6a4a3a") * k)
			_r(ci, 21, 29 - fh - 9, 4, 2, Color("c0392b") * k)
			_smoke(ci, 23, 29 - fh - 9, (h % 5) * 0.2)
			_r(ci, 5, 22, 8, 7, Color("4a463e") * k)
			_win(ci, 15, 22, 4, 3, night)
			if lv >= 2:
				_r(ci, 26, 15, 4, 13, Color("a0a8ac") * k)
			if lv >= 3:
				_r(ci, 26, 12, 4, 3, Color("8a9094") * k)
		"office":
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("a0a8b0") * k)
			var oh := 10.0 + 5.0 * lv
			var oy := 29.0 - oh
			_r(ci, 7, oy, 18, oh, Color("5d7a99") * k)
			_r(ci, 7, oy, 18, 2, Color("8aa8c8") * k)
			for row in int(oh / 3.0) - 1:
				for col in 4:
					_win(ci, 8.5 + col * 4.2, oy + 3 + row * 3.0, 2.6, 1.6, night and (row + col + h) % 2 == 0)
			_r(ci, 15.5, oy - 4, 1, 4, Color("7f8c8d"))
			ci.draw_circle(Vector2(16, oy - 4), 1.0, Color("e74c3c") if int(t * 1.5) % 2 == 0 else Color("7a2a20"))
			_r(ci, 14, 26, 4, 3, Color("2c3e50") * k)
		"orchard":
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("a8c070") * k)
			for row in 3:
				for col in 3:
					var cx := 6.0 + col * 10.0
					var cy := 7.0 + row * 9.0
					_r(ci, cx - 0.7, cy + 1, 1.4, 3.5, Color("6a4a2a") * k)
					ci.draw_circle(Vector2(cx, cy), 3.6, Color("4f9a3a") * k)
					ci.draw_circle(Vector2(cx - 1.2, cy - 0.6), 0.7, Color("d94a3a"))
					ci.draw_circle(Vector2(cx + 1.2, cy + 0.8), 0.7, Color("d94a3a"))
		"ranch":
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("9cc46a") * k)
			for s in 9:
				_r(ci, 2 + s * 3.2, 4, 0.8, 5, Color("7a5a3a") * k)  # fence
			_r(ci, 2, 5, 28, 0.8, Color("7a5a3a") * k)
			_r(ci, 17, 16, 12, 11, Color("8a3a2a") * k)
			_tri(ci, Vector2(16, 16), Vector2(30, 16), Vector2(23, 10), Color("5a2a20") * k)
			for c in 3:
				_r(ci, 3 + c * 5, 18 + (c % 2) * 5, 4, 2.4, Color("f4efe0") * k)
				_r(ci, 4 + c * 5, 18.4 + (c % 2) * 5, 1.4, 1.2, Color("2a2a2a") * k)
		"green":
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("9fbf8a") * k)
			_r(ci, 3, 6, 26, 20, Color(0.75, 0.92, 0.95, 0.85) * k)
			for col in 6:
				_r(ci, 3 + col * 5.0, 6, 0.8, 20, Color("e8f4f4") * k)
			for col in 5:
				ci.draw_circle(Vector2(5.5 + col * 5.0, 21), 1.6, Color("4f9a3a") * k)
			_tri(ci, Vector2(2, 6), Vector2(30, 6), Vector2(16, 2), Color("d8eef0") * k)
		"fishfarm":
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("c4b48a") * k)
			_r(ci, 3, 4, 12, 9, Color("4a8fb8") * k)
			_r(ci, 17, 4, 12, 9, Color("3f82ab") * k)
			_r(ci, 3, 16, 12, 9, Color("3f82ab") * k)
			_r(ci, 17, 16, 12, 9, Color("4a8fb8") * k)
			for p in 4:
				ci.draw_circle(Vector2(9 + (p % 2) * 14.0, 8.5 + (p / 2) * 12.0), 0.9, Color(1, 1, 1, 0.8))
		"farm":
			ci.draw_rect(Rect2(1, 1, 30, 30), Color("c4b46a") * k)
			for s in 5:
				_r(ci, 2, 3 + s * 3.2, 28, 1.6, [Color("7aa84a"), Color("b8a840"), Color("8ab050")][(s + h) % 3] * k)
			_r(ci, 17, 15, 12, 12, Color("a93226") * k)
			_tri(ci, Vector2(16, 15), Vector2(30, 15), Vector2(23, 8), Color("6a2a20") * k)
			_r(ci, 21, 20, 4, 7, Color("f4efe0") * k)
			_r(ci, 4, 14, 6, 13, Color("c8ccd0") * k)
			ci.draw_circle(Vector2(7, 14), 3.0, Color("a8acb0") * k)
	ci.draw_set_transform(Vector2.ZERO)
	return true


## Small version of any buildable, used by the build menu buttons.
static func icon(ci: CanvasItem, id: int) -> void:
	var d: Dictionary = Catalog.DEFS[id]
	var kind := String(d["kind"])
	var col: Color = d["col"]
	if kind == "road":
		ci.draw_rect(Rect2(0, 0, 32, 32), Color("8aa070"))
		ci.draw_rect(Rect2(0, 9, 32, 14), col)
		for s in 4:
			ci.draw_rect(Rect2(2 + s * 8, 15, 4, 2), Color("e8d890"))
		if id == T.AVENUE:
			ci.draw_rect(Rect2(0, 15, 32, 2), Color("e8d890"))
	elif kind == "zone":
		var sh := String(d.get("shape", ""))
		if not building(ci, Rect2(0, 0, 32, 32), sh, col, 2, true, false, 3):
			zone(ci, Rect2(0, 0, 32, 32), sh, col, true)
	elif kind == "net":
		ci.draw_rect(Rect2(0, 0, 32, 32), Color("8aa070"))
		var nc := Color("f2cf4a") if id == T.WIRE else (Color("a07a4a") if id == T.SEWER else Color("4fa3e0"))
		ci.draw_line(Vector2(2, 24), Vector2(30, 8), nc, 3.0)
		ci.draw_circle(Vector2(6, 22), 3.0, nc)
		ci.draw_circle(Vector2(26, 10), 3.0, nc)
	elif id == T.LIGHT:
		ci.draw_rect(Rect2(0, 0, 32, 32), Color("5a5a56"))
		ci.draw_line(Vector2(16, 28), Vector2(16, 8), Color("2a2a2a"), 2.0)
		ci.draw_circle(Vector2(16, 7), 5.0, Color("ffe9a0"))
	elif not service(ci, Rect2(0, 0, 32, 32), id, true, false):
		ci.draw_rect(Rect2(2, 2, 28, 28), col)


## A 32x32 control that draws one building icon.
class IconView extends Control:
	var id := 0

	func _init(i: int = 0) -> void:
		id = i
		custom_minimum_size = Vector2(32, 32)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Art.icon(self, id)


## Painted ground: grass tufts, flowers, bushes and trees (denser, with a river, outside your land).
static func ground(ci: CanvasItem, x: int, y: int, owned: bool, season: int) -> void:
	var h := (x * 73856093 ^ y * 19349663) & 255
	var p := Vector2(x, y) * 32.0
	if not owned:
		if h < 70:
			_tree(ci, p + Vector2(8 + (h % 16), 12 + ((h / 4) % 14)), h, season)
		return
	if h < 10:
		for s in 3:
			var q := p + Vector2(6 + s * 8 + (h % 5), 22 - s * 3)
			ci.draw_line(q, q + Vector2(-1.5, -4), Color("6f9a58"), 1.0)
			ci.draw_line(q, q + Vector2(1.5, -4), Color("6f9a58"), 1.0)
	elif h < 15:
		ci.draw_circle(p + Vector2(8 + (h * 3) % 18, 8 + (h * 5) % 18), 1.4, [Color("f4efe0"), Color("f1c40f"), Color("e07aa0")][h % 3])
	elif h < 18 and season != 3:
		ci.draw_circle(p + Vector2(10 + h % 12, 14 + h % 9), 4.0, Color("5a8a48"))
		ci.draw_circle(p + Vector2(8 + h % 12, 12 + h % 9), 2.0, Color("78a860"))
	elif h == 18:
		_tree(ci, p + Vector2(16, 22), h, season)


## Ore deposit: dark rock flecks (richness 1-3 = more flecks); one rect when zoomed out.
static func ore(ci: CanvasItem, x: int, y: int, rich: int, far: bool) -> void:
	var p := Vector2(x, y) * 32.0
	if far:
		ci.draw_rect(Rect2(p + Vector2(8, 8), Vector2(16, 16)), Color("5a5a66"))
		return
	var h := (x * 73856093 ^ y * 19349663) & 255
	for s in 2 + rich:
		var q := p + Vector2(5 + ((h >> s) * 7 + s * 11) % 22, 5 + ((h >> s) * 5 + s * 13) % 22)
		ci.draw_rect(Rect2(q, Vector2(5, 4)), Color("4a4a56"))
		ci.draw_rect(Rect2(q + Vector2(1, 0), Vector2(3, 1)), Color("8a8a9a"))


## River cell: shaded water, moving ripples, muddy banks, and a few fish (swimming, sometimes jumping).
## `n` = bitmask of dry neighbours: 1 north, 2 east, 4 south, 8 west.
static func water(ci: CanvasItem, x: int, y: int, n: int, night: bool, health := 1.0) -> void:
	var p := Vector2(x, y) * 32.0
	var t := Time.get_ticks_msec() * 0.001
	var h := (x * 73856093 ^ y * 19349663) & 255
	var deep := (Color("2f6f9c") if not night else Color("1c3a58")).lerp(Color("6a7a3a"), (1.0 - health) * 0.6)
	ci.draw_rect(Rect2(p, Vector2(32, 32)), deep)
	ci.draw_rect(Rect2(p + Vector2(0, 8 + 3.0 * sin(t * 0.8 + x)), Vector2(32, 6)), Color(1, 1, 1, 0.06))
	var bank := Color("a8946a")
	if n & 1:
		ci.draw_rect(Rect2(p, Vector2(32, 4)), bank)
	if n & 4:
		ci.draw_rect(Rect2(p + Vector2(0, 28), Vector2(32, 4)), bank)
	if n & 8:
		ci.draw_rect(Rect2(p, Vector2(4, 32)), bank)
	if n & 2:
		ci.draw_rect(Rect2(p + Vector2(28, 0), Vector2(4, 32)), bank)
	for s in 2:
		var ph := t * 0.9 + h * 0.37 + s * 2.1
		var rx := fposmod(ph * 9.0 + s * 14.0, 32.0)
		ci.draw_line(p + Vector2(rx, 8 + s * 14), p + Vector2(rx + 7, 8 + s * 14), Color(1, 1, 1, 0.3), 1.0)
	if h % 5 == 0 and (h % 17) / 17.0 < health:
		var f := fposmod(t * 0.12 + h * 0.013, 1.0)
		var fp := p + Vector2(4 + f * 24.0, 12 + (h % 9) + 2.0 * sin(t * 2.0 + h))
		var fc := Color("e8913a") if h % 2 == 0 else Color("c9d4dc")
		ci.draw_circle(fp, 2.0, fc)
		ci.draw_colored_polygon(PackedVector2Array([fp + Vector2(-1.5, 0), fp + Vector2(-5, -2), fp + Vector2(-5, 2)]), fc)
	if h % 11 == 0:
		var j := fposmod(t * 0.25 + h * 0.07, 1.0)
		if j < 0.16:
			var u := j / 0.16
			var jp := p + Vector2(10 + (h % 12), 24 - 14.0 * sin(u * PI))
			ci.draw_circle(jp, 2.0, Color("e8913a"))
			ci.draw_colored_polygon(PackedVector2Array([jp + Vector2(-1.5, 0), jp + Vector2(-5, -2.5), jp + Vector2(-5, 2.5)]), Color("e8913a"))
			if u > 0.85:
				ci.draw_arc(p + Vector2(10 + (h % 12), 24), 2.0 + (u - 0.85) * 40.0, 0, TAU, 12, Color(1, 1, 1, 0.5), 1.0)


## A ship on the river at pixel `p`. vert = sailing north/south; dir = +1 / -1 along the axis.
static func boat(ci: CanvasItem, p: Vector2, vert: bool, dir: float, navy: bool) -> void:
	var ang := (PI / 2.0 if vert else 0.0) + (0.0 if dir > 0.0 else PI)
	ci.draw_set_transform(p, ang)
	ci.draw_line(Vector2(-14, 0), Vector2(-24, 0), Color(1, 1, 1, 0.45), 2.0)
	var hull := Color("5a6470") if navy else Color("8a3a2a")
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-12, -5), Vector2(9, -5), Vector2(15, 0), Vector2(9, 5), Vector2(-12, 5)]), hull)
	if navy:
		ci.draw_rect(Rect2(-4, -3, 9, 6), Color("8a9aaa"))
		ci.draw_rect(Rect2(8, -1, 7, 2), Color("2a2a2a"))
		ci.draw_circle(Vector2(1, 0), 2.0, Color("4a5a6a"))
	else:
		for s in 3:
			ci.draw_rect(Rect2(-10 + s * 5, -3, 4, 6), [Color("c0392b"), Color("2e86c1"), Color("d68910")][s])
		ci.draw_rect(Rect2(6, -3, 4, 6), Color("e8e2d0"))
	ci.draw_set_transform(Vector2.ZERO)


## Deck + rails over a water road tile. `horiz` = the road runs east-west.
static func bridge(ci: CanvasItem, r: Rect2, horiz: bool) -> void:
	var p := r.position
	var rail := Color("5a4a3a")
	if horiz:
		ci.draw_rect(Rect2(p + Vector2(0, 2), Vector2(32, 3)), rail)
		ci.draw_rect(Rect2(p + Vector2(0, 27), Vector2(32, 3)), rail)
		for s in 4:
			ci.draw_rect(Rect2(p + Vector2(3 + s * 8, 1), Vector2(2, 30)), Color(0, 0, 0, 0.18))
	else:
		ci.draw_rect(Rect2(p + Vector2(2, 0), Vector2(3, 32)), rail)
		ci.draw_rect(Rect2(p + Vector2(27, 0), Vector2(3, 32)), rail)
		for s in 4:
			ci.draw_rect(Rect2(p + Vector2(1, 3 + s * 8), Vector2(30, 2)), Color(0, 0, 0, 0.18))


static func _tree(ci: CanvasItem, q: Vector2, h: int, season: int) -> void:
	var canopy: Color = [Color("5a9a48"), Color("5a9a48"), Color("c8903a"), Color("dfe8ea")][season]
	var canopy2: Color = [Color("e8a8c0"), Color("78b860"), Color("e0b060"), Color("f4f8fa")][season]
	ci.draw_rect(Rect2(q.x - 1, q.y, 2, 6), Color("6b4a2a"))
	ci.draw_circle(q + Vector2(0, -2), 6.0 + (h % 3), canopy)
	ci.draw_circle(q + Vector2(-2, -4), 3.0, canopy2)


## Empty zone plot: tinted lot with a small sketch of what is coming.
static func zone(ci: CanvasItem, r: Rect2, shape: String, zc: Color, ok: bool) -> void:
	ci.draw_set_transform(r.position)
	var k := Color.WHITE if ok else Color(0.65, 0.65, 0.65)
	ci.draw_rect(Rect2(1, 1, 30, 30), Color(zc, 0.55) * k)
	ci.draw_rect(Rect2(2, 2, 28, 28), zc.darkened(0.25) * k, false, 1.0)
	var line := zc.darkened(0.5)
	match shape:
		"shop":
			_r(ci, 7, 14, 18, 11, Color(1, 1, 1, 0.45))
			for s in 6:
				_r(ci, 7 + s * 3, 12, 3, 4, line if s % 2 == 0 else Color("f0e6d0"))
			_r(ci, 14, 19, 4, 6, line)
		"factory":
			_r(ci, 6, 15, 20, 10, Color(1, 1, 1, 0.4))
			_r(ci, 20, 7, 4, 9, line)
			_tri(ci, Vector2(6, 15), Vector2(13, 15), Vector2(6, 10), line)
			_tri(ci, Vector2(13, 15), Vector2(20, 15), Vector2(13, 10), line)
		"office":
			_r(ci, 10, 6, 12, 19, Color(1, 1, 1, 0.45))
			for row in 4:
				_r(ci, 12, 9 + row * 4, 3, 2, line)
				_r(ci, 17, 9 + row * 4, 3, 2, line)
		"farm", "orchard", "ranch", "green", "fishfarm":
			for s in 5:
				_r(ci, 4, 6 + s * 5, 24, 2, line)
		"condo":
			_r(ci, 9, 7, 14, 18, Color(1, 1, 1, 0.45))
			for row in 4:
				_r(ci, 11, 10 + row * 4, 10, 1, line)
		_:
			_r(ci, 8, 15, 16, 10, Color(1, 1, 1, 0.45))
			_tri(ci, Vector2(7, 15), Vector2(25, 15), Vector2(16, 8), line)
			_r(ci, 14, 19, 4, 6, line)
	ci.draw_set_transform(Vector2.ZERO)
