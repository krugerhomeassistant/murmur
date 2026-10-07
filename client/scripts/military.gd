class_name Military
extends RefCounted
## Real armies. Towns train units from barracks and bases, deploy them to the front when at war, and the units fight
## with hit points, range and damage. A war ends when one side's army is gone and the other holds its border.
## Geometry: the front is the line from town a's edge to town b's edge (see line()); a unit's `s` is how many pixels
## it has marched from its own edge.

const T = Catalog.Id
const TILE := 32.0
const KIND := {
	"inf": {"n": "infantry", "hp": 75.0, "dmg": 2.4, "rng": 110.0, "spd": 9.0, "cost": 25.0, "upk": 0.02, "train": 8.0},
	"tank": {"n": "tanks", "hp": 350.0, "dmg": 6.5, "rng": 240.0, "spd": 14.0, "cost": 140.0, "upk": 0.08, "train": 35.0},
	"jet": {"n": "jets", "hp": 150.0, "dmg": 9.0, "rng": 200.0, "spd": 45.0, "cost": 220.0, "upk": 0.12, "train": 50.0},
}
const VS := {  # damage multiplier, attacker kind -> target kind
	"inf": {"inf": 1.0, "tank": 0.25, "jet": 0.15},
	"tank": {"inf": 1.6, "tank": 1.0, "jet": 0.0},
	"jet": {"inf": 1.2, "tank": 1.5, "jet": 0.8},
}
static var booms: Array = []  # runtime only: explosions for the war visuals


static func origin(c: City) -> Vector2:
	return Vector2(c.gpos) * Vector2(City.W, City.H) * TILE


## World-space ends of the front between two towns: edge to edge for neighbours, centre to centre otherwise.
static func line(a: City, b: City) -> PackedVector2Array:
	var ca := Vector2(a.terr.get_center())
	var cb := Vector2(b.terr.get_center())
	var p0 := origin(a) + ca * TILE
	var p1 := origin(b) + cb * TILE
	match Diplo.side(a, b):
		0:
			p0 = origin(a) + Vector2(ca.x, a.terr.position.y) * TILE
			p1 = origin(b) + Vector2(cb.x, b.terr.end.y) * TILE
		1:
			p0 = origin(a) + Vector2(a.terr.end.x, ca.y) * TILE
			p1 = origin(b) + Vector2(b.terr.position.x, cb.y) * TILE
		2:
			p0 = origin(a) + Vector2(ca.x, a.terr.end.y) * TILE
			p1 = origin(b) + Vector2(cb.x, b.terr.position.y) * TILE
		3:
			p0 = origin(a) + Vector2(a.terr.position.x, ca.y) * TILE
			p1 = origin(b) + Vector2(b.terr.end.x, cb.y) * TILE
	return PackedVector2Array([p0, p1])


static func caps(c: City) -> Dictionary:
	var bk := (c.bt.get(T.BARRACKS, []) as Array).size()
	var ba := (c.bt.get(T.BASE, []) as Array).size()
	var rd := (c.bt.get(T.RADAR, []) as Array).size()
	return {"inf": 6 * bk + 4 * ba, "tank": 3 * ba, "jet": mini(2 * ba, 2 * rd)}


static func counts(c: City) -> Dictionary:
	var n := {"inf": 0, "tank": 0, "jet": 0}
	for u in c.army:
		n[u["k"]] += 1
	return n


## Military strength used by the AI and by tribute demands.
static func power(c: City) -> float:
	var n := counts(c)
	return 0.04 * int(n["inf"]) + 0.15 * int(n["tank"]) + 0.2 * int(n["jet"])


static func summary(c: City) -> String:
	var n := counts(c)
	var k := caps(c)
	return "%d infantry, %d tanks, %d jets (room for %d/%d/%d)" % [n["inf"], n["tank"], n["jet"], k["inf"], k["tank"], k["jet"]]


static func _unit(k: String, hp_scale := 1.0) -> Dictionary:
	return {"k": k, "hp": float(KIND[k]["hp"]) * hp_scale, "tgt": "", "s": 0.0, "l": randf_range(-1.0, 1.0)}


## A declaration of war calls up a militia so even a town with no barracks fields something.
static func conscript(c: City) -> void:
	for i in clampi(c.pop / 15, 3, 12):
		c.army.append(_unit("inf", 0.7))


## Once per sim second per town: pay upkeep, train, send units to the front (or home when peace comes).
static func econ(c: City) -> void:
	var up := 0.0
	for u in c.army:
		up += float(KIND[u["k"]]["upk"])
	c.coins -= up
	if c.coins < -50.0 and not c.army.is_empty():
		c.army.pop_back()  # unpaid troops desert
	if c.train_on:
		var cap := caps(c)
		var cnt := counts(c)
		for k in KIND:
			if int(cnt[k]) < int(cap[k]) and c.coins >= float(KIND[k]["cost"]) * 3.0:
				c.train_t[k] = float(c.train_t.get(k, 0.0)) + 1.0
				if float(c.train_t[k]) >= float(KIND[k]["train"]):
					c.train_t[k] = 0.0
					c.coins -= float(KIND[k]["cost"])
					c.army.append(_unit(k))
	var foes: Array = []
	for p in c.partners:
		if Diplo.treaty(c, p) == "war":
			foes.append(p.town_name)
	var i := 0
	for u in c.army:
		if foes.is_empty():
			u["tgt"] = ""
		elif not foes.has(u["tgt"]):
			u["tgt"] = foes[i % foes.size()]
			i += 1
		if u["tgt"] == "" and float(u["s"]) > 0.0:
			u["s"] = maxf(float(u["s"]) - float(KIND[u["k"]]["spd"]), 0.0)  # march home


static func _of(c: City, foe: String) -> Array:
	var r: Array = []
	for u in c.army:
		if u["tgt"] == foe:
			r.append(u)
	return r


## One second of fighting on the front between two towns at war.
static func fight(a: City, b: City) -> void:
	var l := line(a, b)
	var ln := maxf(l[0].distance_to(l[1]), 600.0)
	var now := Time.get_ticks_msec()
	var all: Array = []
	var side: Array = []
	for u in _of(a, b.town_name):
		u["s"] = minf(float(u["s"]), ln)
		all.append(u)
		side.append(0)
	for u in _of(b, a.town_name):
		u["s"] = minf(float(u["s"]), ln)
		all.append(u)
		side.append(1)
	var gpos: Array = []  # position in a's frame
	for i in all.size():
		gpos.append(float(all[i]["s"]) if side[i] == 0 else ln - float(all[i]["s"]))
	var hits: Array = []
	hits.resize(all.size())
	hits.fill(0.0)
	for i in all.size():
		var u: Dictionary = all[i]
		var kd: Dictionary = KIND[u["k"]]
		var best := -1
		var bd := 1e9
		for j in all.size():
			if side[j] == side[i] or float(VS[u["k"]][all[j]["k"]]) <= 0.0:
				continue
			var d := absf(float(gpos[j]) - float(gpos[i])) + absf(float(all[j]["l"]) - float(u["l"])) * 60.0
			if d < bd:
				bd = d
				best = j
		var own_s := float(u["s"])
		if best >= 0 and bd <= float(kd["rng"]):
			hits[best] += float(kd["dmg"]) * float(VS[u["k"]][all[best]["k"]])
			u["ft"] = now
			u["fg"] = gpos[best]
			u["fl"] = all[best]["l"]
			continue
		var target_s := ln - 20.0
		if best >= 0:
			target_s = float(gpos[best]) if side[i] == 0 else ln - float(gpos[best])
			target_s -= signf(target_s - own_s) * float(kd["rng"]) * 0.8  # stop at firing range
		var spd := float(kd["spd"]) * (1.0 + 0.12 * float(u["l"]))  # lane-based jitter so a column does not arrive as one clump
		u["s"] = clampf(own_s + clampf(target_s - own_s, -spd, spd), 0.0, ln)
		if best >= 0:
			u["l"] = float(u["l"]) + clampf(float(all[best]["l"]) - float(u["l"]), -0.1, 0.1)
	for i in all.size():
		all[i]["hp"] = float(all[i]["hp"]) - float(hits[i])
	for i in all.size():
		if float(all[i]["hp"]) <= 0.0:
			var owner: City = a if side[i] == 0 else b
			var killer: City = b if side[i] == 0 else a
			owner.army.erase(all[i])
			killer.war_sc[owner.town_name] = int(killer.war_sc.get(owner.town_name, 0)) + 1
			booms.append({"a": a.town_name, "b": b.town_name, "g": gpos[i], "l": all[i]["l"], "t": now})
			owner.sounds.append("alarm")
	booms = booms.filter(func(e: Dictionary) -> bool: return now - int(e["t"]) < 3000)
	a.war_t -= 1.0
	if a.war_t <= 0.0:
		a.war_t = 20.0
		a.war_n[b.town_name] = int(a.war_n.get(b.town_name, 0)) + 1
		b.war_n[a.town_name] = int(b.war_n.get(a.town_name, 0)) + 1
	_occupy(a, b, ln)
	_occupy(b, a, ln)
	if a.war_n.get(b.town_name, 0) >= 30 and a.army.size() + b.army.size() < 6:
		Diplo.sign_treaty(a, b, "")
		Diplo._say(a, b, "%s and %s, with their armies spent, agree to a ceasefire." % [a.town_name, b.town_name])


## Attackers standing on a town's edge unopposed raid it and, held long enough, force its surrender.
static func _occupy(att: City, vic: City, ln: float) -> void:
	var n := 0
	for u in _of(att, vic.town_name):
		if float(u["s"]) >= ln - 80.0:
			n += 1
	var def := 0
	for u in _of(vic, att.town_name):
		if float(u["s"]) <= 300.0:
			def += 1
	if n >= 2 and n > def:
		vic.occ[att.town_name] = float(vic.occ.get(att.town_name, 0.0)) + 1.0
		att.raid[vic.town_name] = float(att.raid.get(vic.town_name, 0.0)) + n / 18.0
		if float(att.raid[vic.town_name]) >= 1.0:
			att.raid[vic.town_name] = 0.0
			Diplo._raid(att, vic)
			var loot := minf(maxf(vic.coins, 0.0) * 0.03, 30.0)
			vic.coins -= loot
			att.coins += loot
		if float(vic.occ[att.town_name]) >= 40.0:
			Diplo.surrender(att, vic)
	else:
		vic.occ[att.town_name] = maxf(float(vic.occ.get(att.town_name, 0.0)) - 1.0, 0.0)
