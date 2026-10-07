class_name Signals
extends RefCounted
## The seam between the world and the city. The city only ever READS these.
## Sources (simulated events now, live feeds later) only WRITE them.

const BASE := {"market": 0.0, "news": 0.0}

var v := {"market": 0.0, "news": 0.0}  # -1..1, decay back to BASE
var _weather := "clear"
var _weather_left := 0.0


func get_f(k: String) -> float:
	return v[k]


func weather() -> String:
	return _weather


func bump(k: String, d: float) -> void:
	v[k] = clampf(v[k] + d, -1.0, 1.0)


func set_weather(w: String, secs: float) -> void:
	_weather = w
	_weather_left = secs


func tick(dt: float) -> void:
	for k in BASE:
		v[k] = move_toward(v[k], BASE[k], 0.02 * dt)
	if _weather_left > 0.0:
		_weather_left -= dt
		if _weather_left <= 0.0:
			_weather = "clear"
