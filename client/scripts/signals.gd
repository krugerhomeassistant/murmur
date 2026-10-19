class_name Signals
extends RefCounted
## The seam between the world and the city. The city only ever READS these.
## Sources (simulated events now, live feeds later) only WRITE them.

const BASE := {"market": 0.0, "news": 0.0}

var v := {"market": 0.0, "news": 0.0}  # -1..1, decay back to BASE
var mk := Market.new()  # the goods exchange: a world condition shared by every town
var vic := Victory.new()  # the race to conquest or hegemony
var day_hi := 1  # the oldest town's day: one world calendar, so every town is in the same season
## Weather is regional: fronts drift across the world and a town has the weather of the front over it.
## A front: {t: kind, p: world px centre, r: radius px (-1 covers everything), v: px per second, left: secs, age: secs}.
var fronts: Array = []
const FRONT_R := 2400.0  # about one town plot wide
const KINDS := ["rain", "storm", "heatwave", "snow", "fog", "cold_snap"]
const FADE := 8.0  # seconds a front takes to build up and to die away


func get_f(k: String) -> float:
	return v[k]


## The weather at a world position (pixels): the first front covering it, else "clear".
func weather_at(p: Vector2) -> String:
	for f: Dictionary in fronts:
		if float(f["r"]) < 0.0 or p.distance_to(f["p"]) < float(f["r"]) * strength(f):
			return String(f["t"])
	return "clear"


## 0..1: how fully a front has built up (or is dying away). Its edge shrinks and grows with it.
func strength(f: Dictionary) -> float:
	return clampf(minf(float(f["age"]), float(f["left"])) / FADE, 0.25, 1.0)


func bump(k: String, d: float) -> void:
	v[k] = clampf(v[k] + d, -1.0, 1.0)


## Start weather over a place (an event in a town), or everywhere when no position is given. The same kind already
## nearby is only prolonged; a new front drifts downwind (the wind is a pure function of the place so every peer agrees).
func set_weather(w: String, secs: float, at := Vector2.INF) -> void:
	var glob := at == Vector2.INF
	for f: Dictionary in fronts:
		if f["t"] == w and (glob == (float(f["r"]) < 0.0)) and (glob or at.distance_to(f["p"]) < FRONT_R):
			f["left"] = maxf(float(f["left"]), secs)
			return
	var ang := (fmod(absf(at.x) * 0.0013 + absf(at.y) * 0.0007, 1.0) - 0.5) * 1.2 if not glob else 0.0
	fronts.append({"t": w, "p": Vector2.ZERO if glob else at, "r": -1.0 if glob else FRONT_R, "v": Vector2.ZERO if glob else Vector2.from_angle(ang) * 45.0, "left": secs, "age": 0.0})


func fronts_brief() -> Array:
	var out := []
	for f: Dictionary in fronts:
		out.append([f["t"], f["p"].x, f["p"].y, f["r"], f["v"].x, f["v"].y, f["left"], f["age"]])
	return out


## Replace the fronts from a snapshot or save; anything that is not a well-formed front is dropped.
func apply_fronts(a: Array) -> void:
	fronts = []
	for e in a:
		if e is Array and (e as Array).size() == 8 and e[0] is String and String(e[0]) in KINDS:
			var nums := true
			for i in range(1, 8):
				nums = nums and (e[i] is float or e[i] is int)
			if nums:
				fronts.append({"t": e[0], "p": Vector2(clampf(float(e[1]), -1.0e7, 1.0e7), clampf(float(e[2]), -1.0e7, 1.0e7)), "r": clampf(float(e[3]), -1.0, 1.0e5), "v": Vector2(clampf(float(e[4]), -500.0, 500.0), clampf(float(e[5]), -500.0, 500.0)), "left": clampf(float(e[6]), 0.0, 1000.0), "age": clampf(float(e[7]), 0.0, 1000.0)})


func tick(dt: float) -> void:
	mk.tick(dt, 1.0 + 0.3 * float(v["market"]))
	for k in BASE:
		v[k] = move_toward(v[k], BASE[k], 0.02 * dt)
	var keep: Array = []
	for f: Dictionary in fronts:
		f["left"] = float(f["left"]) - dt
		f["age"] = float(f["age"]) + dt
		f["p"] = f["p"] + f["v"] * dt
		if float(f["left"]) > 0.0:
			keep.append(f)
	fronts = keep
