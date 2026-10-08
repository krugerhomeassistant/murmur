class_name Lobby
extends Control
## Multiplayer screen: host a game or join one by address (docs/MULTIPLAYER.md). Sits on top of the start menu.

var m: Node2D
var o_name: LineEdit
var o_port: LineEdit
var o_towns: OptionButton
var o_addr: LineEdit
var roster: Label
var note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.05, 0.96)
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
	t.text = "MULTIPLAYER"
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color("e8e2d0"))
	v.add_child(t)
	_dim(v, "One shared world: each player runs a town, neighbours trade, ally or fight. Up to 8 players. The host runs the simulation; to host over the internet, forward UDP port 7777 on the router or run a dedicated server (docs/MULTIPLAYER.md).")
	o_name = LineEdit.new()
	o_name.text = "Player"
	o_name.max_length = NetPlay.NAME_MAX
	_row(v, "Your name", o_name)
	_head(v, "HOST")
	o_port = LineEdit.new()
	o_port.text = str(NetPlay.PORT)
	_row(v, "Port (UDP)", o_port)
	o_towns = OptionButton.new()
	for k in range(2, 9):
		o_towns.add_item("%d towns (free ones run on the planner until someone joins)" % k, k)
	o_towns.select(2)
	_row(v, "Towns in the world", o_towns)
	_btn(v, "Host a game", _host)
	_head(v, "JOIN")
	o_addr = LineEdit.new()
	o_addr.text = "127.0.0.1"
	o_addr.placeholder_text = "host address, e.g. 192.168.1.20 or 192.168.1.20:7777"
	_row(v, "Host address", o_addr)
	_btn(v, "Join", _join)
	roster = Label.new()
	roster.add_theme_color_override("font_color", Color("e8e2d0"))
	v.add_child(roster)
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("e0a458"))
	v.add_child(note)
	_btn(v, "Back", _back)
	m.net.roster_changed.connect(_refresh)
	m.net.failed.connect(func(r: String) -> void: note.text = r)
	m.net.joined.connect(func() -> void: note.text = "Connected. Waiting for the world...")
	_refresh()


func _refresh() -> void:
	var names: Array = m.net.players.values().map(func(p: Dictionary) -> String: return "%s (%d ms)" % [p["name"], p["ping"]])
	roster.text = "Players: " + ", ".join(names) if not names.is_empty() else ""


func _port() -> int:
	var p := int(o_port.text) if o_port.text.is_valid_int() else NetPlay.PORT
	return clampi(p, 1024, 65535)


func _host() -> void:
	m.host_game(_port(), o_towns.get_item_id(o_towns.selected), o_name.text)
	queue_free()


func _join() -> void:
	var hp := o_addr.text.strip_edges().split(":")
	var port := int(hp[1]) if hp.size() > 1 and hp[1].is_valid_int() else NetPlay.PORT
	note.text = "Connecting..."
	m.join_game(hp[0], port, o_name.text)


func _back() -> void:
	m.net.stop()
	queue_free()


func _head(p: Node, s: String) -> void:
	var l := Label.new()
	l.text = s
	l.add_theme_color_override("font_color", Color("9aa88f"))
	p.add_child(l)


func _dim(p: Node, s: String) -> void:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color("9aa88f"))
	l.add_theme_font_size_override("font_size", 11)
	p.add_child(l)


func _row(p: Node, label: String, c: Control) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(190, 0)
	h.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(c)
	p.add_child(h)


func _btn(p: Node, text: String, f: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(f)
	p.add_child(b)
