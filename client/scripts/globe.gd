class_name Globe
extends RefCounted
## Data for the world (globe) view, docs/SANDBOX_DESIGN.md G4a: one marker per town and one overlay value per marker.
## Pure: reads towns, changes nothing, so it is safe to call every frame and easy to test.

const OVERLAYS := ["side", "age", "population", "wealth", "military"]
const MIN_R := 6.0  # marker radius in world tiles at 0 population
const MAX_R := 40.0


## Radius of a town's disc: grows with the square root of the population (area follows people), clamped.
static func radius(pop: int) -> float:
	return clampf(MIN_R + 1.6 * sqrt(float(maxi(pop, 0))), MIN_R, MAX_R)


## How `t` relates to `me`: "you", "ally", "war", "vassal", "pact", "embargo" or "none".
static func side(me: City, t: City) -> String:
	if t == me:
		return "you"
	var tr := Diplo.treaty(me, t)
	return "none" if tr == "" else tr


## 0..1 value of an overlay for a town (the marker ring colour index). `ref` normalises the open scale (largest value in view).
static func value(t: City, overlay: String, ref: float) -> float:
	var v := 0.0
	match overlay:
		"age":
			return float(t.age) / float(Ages.LAST)
		"population":
			v = float(t.pop)
		"wealth":
			v = t.coins / maxf(float(t.pop), 1.0)
		"military":
			v = Military.power(t)
		_:
			return 0.0
	return clampf(v / maxf(ref, 0.0001), 0.0, 1.0)


## One dictionary per town: {t, name, pos (world tiles, centre of the town), r, side, v}.
static func markers(towns: Array, me: City, overlay: String) -> Array:
	var ref := 0.0
	for t in towns:
		match overlay:
			"population":
				ref = maxf(ref, float(t.pop))
			"wealth":
				ref = maxf(ref, t.coins / maxf(float(t.pop), 1.0))
			"military":
				ref = maxf(ref, Military.power(t))
	var out := []
	for t in towns:
		var c: City = t
		out.append({"t": c, "name": c.town_name, "pos": (Vector2(c.gpos) + Vector2(0.5, 0.5)) * Vector2(City.W, City.H), "r": radius(c.pop), "side": side(me, c), "v": value(c, overlay, ref)})
	return out
