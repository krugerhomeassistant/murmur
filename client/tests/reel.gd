extends Node
## Scripted flyover that records the README GIF frames (see scripts/MEDIA.md). Needs a built showcase town as `m.city`.
## world pull-in -> street level at 8x -> overlays -> border war -> pull back out. `out` gets numbered PNGs.
var m: Node
var out := ""
var fps := 12.0
var t := 0.0
var acc := 0.0
var n := 0
var home := Vector2.ZERO
var done := false
const OVERLAYS := ["land", "crime", "traffic", "pollution", "all", ""]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	home = m.origin(m.city) + Vector2(m.city.terr.get_center()) * m.TILE

func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

func _cam(from_p: Vector2, to_p: Vector2, from_z: float, to_z: float, k: float) -> void:
	var e := _ease(clampf(k, 0.0, 1.0))
	m.cam.position = from_p.lerp(to_p, e)
	m.cam.zoom = Vector2.ONE * exp(lerpf(log(from_z), log(to_z), e))

func _process(d: float) -> void:
	if done:
		return
	t += d
	var east: Vector2 = home + Vector2(420, -200)
	var border: Vector2 = Vector2(m.city.W * m.TILE, m.city.H * m.TILE * 0.5)
	if t < 4.0:  # pull in from the world map
		m.speed = 8.0
		_cam(home + Vector2(300, 100), home, 0.28, 2.0, t / 4.0)
	elif t < 9.0:  # drift along the main street at 8x
		_cam(home, east, 2.0, 2.0, (t - 4.0) / 5.0)
	elif t < 14.0:  # overlays, one per second
		m.overlay = OVERLAYS[mini(int(t - 9.0), OVERLAYS.size() - 1)]
		_cam(east, home - Vector2(300, 150), 2.0, 1.2, (t - 9.0) / 5.0)
	elif t < 15.0:
		m.overlay = ""
	elif t < 22.0:  # war at the border
		if t - d < 15.0:
			_war()
		m.speed = 3.0
		_cam(home - Vector2(300, 150), border, 1.2, 1.0, (t - 15.0) / 3.0)
	elif t < 26.0:  # pull back out to the whole region
		_cam(border, border, 1.0, 0.18, (t - 22.0) / 4.0)
	else:
		done = true
		return
	acc += d
	if acc >= 1.0 / fps:
		acc = 0.0
		get_viewport().get_texture().get_image().save_png("%s/f%04d.png" % [out, n])
		n += 1

func _war() -> void:
	var a: City = m.city
	var b: City = m.towns[1]
	for c in [a, b]:
		c.coins = 1.0e7
		for u in ["inf", "inf", "inf", "tank", "tank", "art", "gren", "inf", "tank", "art", "inf", "inf"]:
			c.army.append(Military._unit(u))
	Diplo.act(a, b, "war")
