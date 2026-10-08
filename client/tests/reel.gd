extends Node
## Scripted flyover that records the README GIF frames (see scripts/MEDIA.md). Needs a built showcase town as `m.city`.
## world pull-in -> street level at 8x -> overlays -> border war -> pull back out. `out` gets numbered PNGs.
var m: Node
var out := ""
var fps := 24.0
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
	var far := home + Vector2(300, 100)
	var east: Vector2 = home + Vector2(420, -200)
	var fight := _front()
	if t < 3.0:  # pull in from the world map
		m.speed = 8.0
		_cam(far, home, 0.28, 2.0, t / 3.0)
	elif t < 7.0:  # drift along the main street at 8x
		_cam(home, east, 2.0, 2.0, (t - 3.0) / 4.0)
	elif t < 11.0:  # overlays, a fresh one every 0.7 s
		m.overlay = OVERLAYS[mini(int((t - 7.0) / 0.7), OVERLAYS.size() - 1)]
		_cam(east, home - Vector2(300, 150), 2.0, 1.2, (t - 7.0) / 4.0)
	elif t < 15.0:  # war at the border
		m.overlay = ""
		if t - d < 11.0:
			_war()
		m.speed = 3.0
		_cam(home - Vector2(300, 150), fight, 1.2, 0.8, (t - 11.0) / 1.5)
	elif t < 18.0:  # pull back out to the start frame so the GIF loops
		m.speed = 8.0
		_cam(fight, far, 0.8, 0.28, (t - 15.0) / 3.0)
	else:
		done = true
		return
	acc += d
	if acc >= 1.0 / fps:
		acc = 0.0
		get_viewport().get_texture().get_image().save_png("%s/f%04d.png" % [out, n])
		n += 1


func _front() -> Vector2:
	var l := Military.line(m.city, m.towns[1])
	return (l[0] + l[1]) * 0.5

func _war() -> void:
	var a: City = m.city
	var b: City = m.towns[1]
	for c in [a, b]:
		c.coins = 1.0e7
		for u in ["inf", "inf", "inf", "inf", "inf", "inf", "tank", "tank", "art", "gren", "gren", "inf", "inf", "inf", "tank", "art", "inf", "inf", "inf", "inf"]:
			c.army.append(Military._unit(u))
	Diplo.act(a, b, "war")
