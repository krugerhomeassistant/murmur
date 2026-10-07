class_name Setup
extends Control
## Start menu: continue a saved game or set up a new one. Lives on top of the HUD while visible.

var m: Node2D
var has_save := false
var o_name: LineEdit
var o_towns: OptionButton
var o_mood: OptionButton
var o_diff: OptionButton
var o_land: OptionButton
var o_auto: OptionButton
var o_river: OptionButton
var o_pol: CheckButton
var o_exp: CheckButton
var o_guide: CheckButton
var note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.05, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	var pc := PanelContainer.new()
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size = Vector2(520, 0)
	pc.add_child(v)
	var t := Label.new()
	t.text = "MURMUR"
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", Color("e8e2d0"))
	v.add_child(t)
	var sub := Label.new()
	sub.text = "A cozy, endless city. You are the mayor: keep the voters happy and the town growing."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_color_override("font_color", Color("9aa88f"))
	v.add_child(sub)
	if has_save:
		var cont := Button.new()
		cont.text = "Continue saved game"
		cont.focus_mode = Control.FOCUS_NONE
		cont.pressed.connect(func() -> void: m.continue_game())
		v.add_child(cont)
		var h0 := Label.new()
		h0.text = "or start a new game:"
		h0.add_theme_color_override("font_color", Color("9aa88f"))
		v.add_child(h0)
	o_name = LineEdit.new()
	o_name.text = "Murmur"
	o_name.max_length = 18
	_row(v, "Your town's name", o_name, "What your town is called.")
	o_towns = _opt(v, "Towns at the start", ["1 (just you)", "2 (you + 1 neighbour)", "3 (you + 2 neighbours)", "4 (you + 3 neighbours)", "5", "6", "7", "8 (busy region)"], 1, "Neighbour towns run themselves. You trade, ally, embargo or fight with them. You can found more later from the Towns menu.")
	o_mood = _opt(v, "Neighbours are", ["Friendly", "Mixed (each has its own temper)", "Prickly", "Random"], 1, "How the neighbours feel about you at the start. Friendly towns offer pacts; prickly ones smuggle, raid and demand tribute.")
	o_diff = _opt(v, "Difficulty", ["Relaxed ($600, calmer world)", "Normal ($300)", "Hard ($150, more disasters)"], 1, "Starting money and how often world events strike.")
	o_land = _opt(v, "Starting land", ["Small (40x24)", "Medium (48x32)", "Large (64x40)"], 1, "How much of the map you own at the start. You can annex more at any time.")
	o_river = _opt(v, "Rivers", ["Random river in every town", "None (flat land)", "Custom: I paint it (world editor)"], 0, "A river splits the land. Zones can't go on water; roads over it become bridges (4x cost). Custom starts paused with the paint-water tool so you can draw your own rivers and lakes first.")
	o_auto = _opt(v, "Auto-growth", ["Off - I build everything", "Zones only", "Zones + roads"], 2, "Whether the planner zones plots and lays roads for you when demand rises.")
	o_pol = CheckButton.new()
	o_pol.text = "Auto-policies (the council decides)"
	o_pol.button_pressed = true
	o_pol.focus_mode = Control.FOCUS_NONE
	v.add_child(o_pol)
	o_exp = CheckButton.new()
	o_exp.text = "Auto-annex land when cramped"
	o_exp.button_pressed = true
	o_exp.focus_mode = Control.FOCUS_NONE
	v.add_child(o_exp)
	o_guide = CheckButton.new()
	o_guide.text = "Show the new-player guide"
	o_guide.button_pressed = not has_save
	o_guide.focus_mode = Control.FOCUS_NONE
	v.add_child(o_guide)
	var go := Button.new()
	go.text = "Start new game"
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(_go)
	v.add_child(go)
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("9aa88f"))
	note.add_theme_font_size_override("font_size", 11)
	note.text = "Left click: build / inspect.  Right or middle drag, or WASD: pan.  Wheel: zoom.  Space: pause.  Q inspect, B bulldoze.  The game autosaves every day."
	v.add_child(note)
	var qb := Button.new()
	qb.text = "Quit"
	qb.focus_mode = Control.FOCUS_NONE
	qb.pressed.connect(func() -> void: m.get_tree().quit())
	v.add_child(qb)


func _row(p: Node, label: String, c: Control, tip: String) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(190, 0)
	h.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.tooltip_text = tip
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(c)
	p.add_child(h)


func _opt(p: Node, label: String, items: Array, sel: int, tip: String) -> OptionButton:
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(String(it))
	ob.select(sel)
	_row(p, label, ob, tip)
	return ob


func _go() -> void:
	var nm := o_name.text.strip_edges()
	m.start_game({
		"name": nm if nm != "" else "Murmur",
		"towns": o_towns.selected + 1,
		"mood": o_mood.selected,
		"diff": o_diff.selected,
		"land": o_land.selected,
		"river": o_river.selected,
		"auto": o_auto.selected,
		"policy": o_pol.button_pressed,
		"expand": o_exp.button_pressed,
		"guide": o_guide.button_pressed,
	})
