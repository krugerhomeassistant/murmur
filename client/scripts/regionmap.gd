class_name RegionMap
extends Control
## Overview of the whole region: every town as a thumbnail, placed next to its neighbours, with the border links between them.

var m: Node2D
var tex := {}  # City -> ImageTexture
var t_acc := 99.0
var rects := {}  # City -> Rect2


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var x := Button.new()
	x.text = "Close (M)"
	x.focus_mode = Control.FOCUS_NONE
	x.pressed.connect(func() -> void: visible = false)
	x.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	x.position += Vector2(-110, 50)
	add_child(x)


func _thumb(c: City) -> ImageTexture:
	var img := Image.create(City.W, City.H, false, Image.FORMAT_RGBA8)
	img.fill(Color("2c3a2a"))
	var tr := c.terr
	img.fill_rect(tr, Color("8fae78"))
	for i in c.cells:
		var t: int = c.grid[i]
		if t != Catalog.Id.EMPTY:
			img.set_pixel(i % City.W, i / City.W, Catalog.DEFS[t]["col"])
	return ImageTexture.create_from_image(img)


func _process(d: float) -> void:
	if not visible:
		return
	t_acc += d
	if t_acc > 1.5:
		t_acc = 0.0
		for c in m.towns:
			tex[c] = _thumb(c)
	queue_redraw()


func _col(c: City) -> Color:
	var cur: City = m.city
	if c == cur:
		return Color("f2cf4a")
	var tr := Diplo.treaty(cur, c)
	if tr == "war":
		return Color("d9382a")
	if tr == "alliance":
		return Color("6fd0e8")
	if tr == "pact":
		return Color("9fd3a0")
	if tr == "embargo":
		return Color("e08a3a")
	var r := Diplo.avg(cur, c)
	return Color("9fd3a0") if r > 0.2 else (Color("e07a5f") if r < -0.2 else Color("9aa88f"))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.05, 0.94))
	draw_string(font, Vector2(24, 76), "THE REGION  (click a town to go there; gold = you)", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e8e2d0"))
	if m.towns.is_empty():
		return
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for c in m.towns:
		lo = Vector2i(mini(lo.x, c.gpos.x), mini(lo.y, c.gpos.y))
		hi = Vector2i(maxi(hi.x, c.gpos.x), maxi(hi.y, c.gpos.y))
	var n := hi - lo + Vector2i.ONE
	var area := Rect2(24, 100, size.x - 48, size.y - 180)
	var gap := 34.0
	var cw := minf((area.size.x - gap * (n.x - 1)) / n.x, (area.size.y - gap * (n.y - 1)) / n.y * 1.5)
	cw = clampf(cw, 60.0, 360.0)
	var ch := cw * City.H / City.W + 22.0
	var tot := Vector2(cw * n.x + gap * (n.x - 1), ch * n.y + gap * (n.y - 1))
	var o := area.position + (area.size - tot) * 0.5
	rects.clear()
	for c in m.towns:
		var p := Vector2(c.gpos - lo)
		rects[c] = Rect2(o + Vector2(p.x * (cw + gap), p.y * (ch + gap)), Vector2(cw, ch))
	for c in m.towns:
		var r: Rect2 = rects[c]
		var col := _col(c)
		draw_rect(r.grow(3), col, false, 3.0 if c == m.city else 2.0)
		if tex.has(c):
			draw_texture_rect(tex[c], Rect2(r.position, Vector2(cw, ch - 22.0)), false)
		draw_rect(Rect2(r.position + Vector2(0, ch - 22.0), Vector2(cw, 22.0)), Color(0, 0, 0, 0.55))
		var tr := Diplo.treaty(m.city, c)
		var lab := "%s  pop %d%s" % [c.town_name, c.pop, "" if c == m.city or tr == "" else "  [%s]" % tr.to_upper()]
		draw_string(font, r.position + Vector2(5, ch - 6), lab, HORIZONTAL_ALIGNMENT_LEFT, cw - 8, 13, col)
	for c in m.towns:
		for d in c.partners:
			var k: int = Diplo.side(c, d)
			if k != 1 and k != 2:
				continue  # draw each pair once, from its west/north member
			var a: Rect2 = rects[c]
			var b: Rect2 = rects[d]
			var ok := Diplo.linked(c, d)
			var war := Diplo.treaty(c, d) == "war"
			var lc := Color("d9382a") if war else (Color("9fd3a0") if ok else Color("6a6a60"))
			var p0 := a.get_center() + (Vector2(a.size.x * 0.5, 0) if k == 1 else Vector2(0, a.size.y * 0.5))
			var p1 := b.get_center() - (Vector2(b.size.x * 0.5, 0) if k == 1 else Vector2(0, b.size.y * 0.5))
			draw_line(p0, p1, lc, 4.0 if ok else 2.0)
			var mid := (p0 + p1) * 0.5
			draw_string(font, mid + Vector2(-30, -6), "WAR" if war else ("road" if ok else "no road"), HORIZONTAL_ALIGNMENT_CENTER, 60, 11, lc)
	draw_string(font, Vector2(24, size.y - 24), "Grey line: no road reaches the shared border yet, so no trade or commuters. Green: linked. Build a road to the gold border facing that town.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 13, Color("9aa88f"))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for c in rects:
			if (rects[c] as Rect2).has_point(e.position):
				m.switch_town(m.towns.find(c))
				visible = false
				return
