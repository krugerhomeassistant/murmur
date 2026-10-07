class_name Guide
extends PanelContainer
## New-player guide: one step at a time at the bottom of the screen. Steps with a check complete themselves; others have a Next button.

const T = Catalog.Id
const STEPS := [
	{"t": "1. Lay a road", "x": "Open the Build menu (left), pick Road and drag a line on the grass. Everything needs a road beside it.", "chk": "roads"},
	{"t": "2. Zone homes", "x": "Pick Residential zone and paint plots touching your road. Zoning is cheap; homes appear on their own.", "chk": "res"},
	{"t": "3. Zone shops and jobs", "x": "Paint Commercial (shops) and Industrial or Farm (jobs) beside the road. People need work and somewhere to spend.", "chk": "jobs"},
	{"t": "4. Power and water", "x": "Build a Wind turbine or Solar plant and a Water tower (Utilities), then connect them to buildings with Power line / Pipe. Power lines and pipes unlock at pop 15. Hover buildings to see what is missing.", "chk": "net"},
	{"t": "5. Grow to 10 people", "x": "Press Space to pause, or use the speed buttons in the top bar. Watch the Pop and Mood numbers; the town grows when homes, jobs and services balance.", "chk": "p10"},
	{"t": "6. Overlays", "x": "Open the Overlays menu to see power, water, fire cover, traffic and more. Q inspects a building, B bulldozes, the wheel zooms, right-drag pans."},
	{"t": "7. You are the mayor", "x": "Windows > Mayor's office: tribes send petitions. Accepting one is a promise with a deadline. Approval must stay above 50% at each election (every 28 days)."},
	{"t": "8. Your neighbours", "x": "Press M for the region map. Each neighbour lies on one side of you, labelled at your border. Build a road all the way to that gold border line to open trade, power, water and commuters. City panel > Region tab: pacts, gifts, embargoes, tribute and war."},
	{"t": "9. Reach 50 people", "x": "Add a school, clinic, fire and police stations, parks as you grow. Services unlock with population. The map is endless: annex land when cramped.", "chk": "p50"},
	{"t": "You've got it", "x": "The game saves every day. Use Windows > Guide in the City menu to bring this back. Have fun!"},
]

var m: Node2D
var i := 0
var title: Label
var body: Label
var nxt: Button
var t_acc := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(460, 0)
	var v := VBoxContainer.new()
	add_child(v)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("e8e2d0"))
	v.add_child(title)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(440, 0)
	v.add_child(body)
	var h := HBoxContainer.new()
	v.add_child(h)
	nxt = Button.new()
	nxt.text = "Next"
	nxt.focus_mode = Control.FOCUS_NONE
	nxt.pressed.connect(_next)
	h.add_child(nxt)
	var sk := Button.new()
	sk.text = "Hide guide"
	sk.focus_mode = Control.FOCUS_NONE
	sk.pressed.connect(func() -> void: visible = false)
	h.add_child(sk)
	_show()


func restart() -> void:
	i = 0
	visible = true
	_show()


func _next() -> void:
	if i >= STEPS.size() - 1:
		visible = false
		return
	i += 1
	_show()


func _show() -> void:
	var s: Dictionary = STEPS[i]
	title.text = s["t"]
	body.text = s["x"]
	nxt.visible = not s.has("chk")
	nxt.text = "Done" if i >= STEPS.size() - 1 else "Next"
	size = Vector2.ZERO


func _count(c: City, id: int) -> int:
	var n := 0
	for k in c.cells:
		if c.grid[k] == id:
			n += 1
	return n


func _ok(k: String) -> bool:
	var c: City = m.city
	match k:
		"roads":
			return c.roads >= 6
		"res":
			return _count(c, T.RES) >= 3
		"jobs":
			return _count(c, T.COM) >= 1 and (_count(c, T.IND) + _count(c, T.FARM)) >= 1
		"net":
			return float(c.net_own.get("power", 0.0)) > 0.0 and float(c.net_own.get("water", 0.0)) > 0.0
		"p10":
			return c.peak >= 10.0
		"p50":
			return c.peak >= 50.0
	return false


func _process(d: float) -> void:
	if not visible:
		return
	var vs := get_viewport_rect().size
	position = Vector2((vs.x - size.x) * 0.5, vs.y - size.y - 48.0)
	t_acc += d
	if t_acc < 0.5:
		return
	t_acc = 0.0
	var s: Dictionary = STEPS[i]
	if s.has("chk") and _ok(s["chk"]):
		_next()
