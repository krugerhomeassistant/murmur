class_name TreeView
extends Control
## Full-screen skill tree (key K): six arms from a hub, six nodes along each. Taken nodes are lit, nodes that can be taken are outlined,
## the rest are dim; hover shows what a node does and what it needs, click takes it.

const R0 := 64.0  # hub radius
const STEP := 50.0  # distance between tiers
const NODE := 20.0
const COLS := [Color("e0b84a"), Color("e08a3a"), Color("5a9be0"), Color("6cc070"), Color("d9564a"), Color("9aa3a8")]
var m: Node2D
var hover := -1


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func pos(i: int) -> Vector2:
	var b := i / Research.TIERS
	var a := -PI / 2.0 + TAU * b / float(Research.BRANCHES.size())
	return size * 0.5 + Vector2.from_angle(a) * (R0 + STEP * (i % Research.TIERS))


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _node_at(p: Vector2) -> int:
	for i in Research.BRANCHES.size() * Research.TIERS:
		if pos(i).distance_to(p) <= NODE + 4.0:
			return i
	return -1


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		hover = _node_at(e.position)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var i := _node_at(e.position)
		if i >= 0:
			m.cmd("node", [i])


func _draw() -> void:
	var c: City = m.city
	var nb := Research.BRANCHES.size()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.06, 0.94))
	var ctr := size * 0.5
	draw_circle(ctr, R0 - 18.0, Color(0.12, 0.15, 0.12))
	draw_string(ThemeDB.fallback_font, ctr + Vector2(-60, 4), "%s age" % Ages.name_of(c.age), HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color("f3e7cf"))
	draw_string(ThemeDB.fallback_font, Vector2(24, 32), "SKILL TREE   points %d   (K or Esc closes)" % int(c.pts), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f3e7cf"))
	for b in nb:
		draw_line(ctr, pos(Research.id(b, 0)), Color(COLS[b], 0.5), 3.0)
		for t in Research.TIERS:
			var i := Research.id(b, t)
			if t > 0:
				draw_line(pos(i - 1), pos(i), Color(COLS[b], 0.7 if Research.has(c, i - 1) and Research.has(c, i) else 0.25), 3.0)
			var nxt := Research.id((b + 1) % nb, t)  # the neighbouring arm's same tier is connected too
			if t > 0:
				draw_line(pos(i), pos(nxt), Color(0.5, 0.55, 0.5, 0.18), 1.5)
	for i in nb * Research.TIERS:
		var p := pos(i)
		var col: Color = COLS[i / Research.TIERS]
		var why := Research.block(c, i)
		if why == "taken":
			draw_circle(p, NODE, col)
		elif why == "":
			draw_circle(p, NODE, Color(col, 0.18))
			draw_arc(p, NODE, 0.0, TAU, 28, col, 3.0)
		else:
			draw_circle(p, NODE, Color(0.12, 0.14, 0.12))
			draw_arc(p, NODE, 0.0, TAU, 28, Color(col, 0.3), 1.5)
		draw_string(ThemeDB.fallback_font, p + Vector2(-44, NODE + 14), String(Research.node(i)["n"]), HORIZONTAL_ALIGNMENT_CENTER, 88, 11, Color("f3e7cf") if why == "taken" or why == "" else Color("8a948a"))
	for b in nb:
		draw_string(ThemeDB.fallback_font, pos(Research.id(b, Research.TIERS - 1)) + (pos(Research.id(b, Research.TIERS - 1)) - ctr).normalized() * 52.0 - Vector2(50, 0), String(Research.BRANCHES[b]["n"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 100, 14, COLS[b])
	if hover >= 0:
		var why := Research.block(c, hover)
		var txt := "%s: %s (%d points)%s" % [Research.node(hover)["n"], Research.node(hover)["d"], int(Research.cost(hover)), "" if why == "" else "  -  " + why]
		var mp := get_local_mouse_position() + Vector2(16, 16)
		var ts := ThemeDB.fallback_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_rect(Rect2(mp - Vector2(6, 16), ts + Vector2(12, 10)), Color(0, 0, 0, 0.85))
		draw_string(ThemeDB.fallback_font, mp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
