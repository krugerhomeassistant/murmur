class_name ChatBox
extends VBoxContainer
## Multiplayer chat: recent lines bottom-left, Enter opens the input. Lines fade after a while.

var m: Node2D
var lines := []  # [text, born_msec]
var log_l: Label
var edit: LineEdit
const SHOW_MS := 14000


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 12.0
	offset_bottom = -44.0
	offset_top = -200.0
	custom_minimum_size = Vector2(380, 0)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	log_l = Label.new()
	log_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	log_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_l.add_theme_color_override("font_color", Color("e8e2d0"))
	log_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	log_l.add_theme_constant_override("outline_size", 4)
	add_child(log_l)
	edit = LineEdit.new()
	edit.visible = false
	edit.max_length = 140
	edit.placeholder_text = "Say something (Enter to send, Esc to cancel)"
	edit.text_submitted.connect(func(t: String) -> void:
		m.net.say(t)
		close())
	add_child(edit)
	m.net.chat.connect(func(who: String, text: String) -> void:
		lines.append(["%s: %s" % [who, text], Time.get_ticks_msec()])
		lines = lines.slice(-6)
		_show())


func open() -> void:
	edit.visible = true
	edit.grab_focus()


func close() -> void:
	edit.text = ""
	edit.visible = false
	edit.release_focus()


func _show() -> void:
	var now := Time.get_ticks_msec()
	log_l.text = "\n".join(lines.filter(func(l: Array) -> bool: return now - int(l[1]) < SHOW_MS or edit.visible).map(func(l: Array) -> String: return l[0]))


func _process(_d: float) -> void:
	if log_l.text != "" or not lines.is_empty():
		_show()


func _input(e: InputEvent) -> void:
	if edit.visible and e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
