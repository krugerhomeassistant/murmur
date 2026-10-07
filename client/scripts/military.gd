class_name Military
extends RefCounted
## Real armies. Towns train units from barracks and bases, deploy them to the front when at war, and the units fight
## with hit points, range and damage. A war ends when one side's army is gone and the other holds its border.
## Geometry: the front is the line from town a's edge to town b's edge (see line()); a unit's `s` is how many pixels
## it has marched from its own edge.
## Every unit type lives in KIND: `t` is what it counts as when shot at (soft/armor/air), `vs` its damage multiplier
## against each of those, `cap` how many each building houses, `radar` that air capacity is also limited by radar posts.

const T = Catalog.Id
const TILE := 32.0
const KIND := {
	"inf": {"n": "Rifleman", "t": "soft", "hp": 75.0, "dmg": 2.4, "rng": 110.0, "spd": 9.0, "cost": 25.0, "upk": 0.02, "train": 8.0, "cap": {T.BARRACKS: 6, T.BASE: 4}, "vs": {"soft": 1.0, "armor": 0.25, "air": 0.15, "ship": 0.1}},
	"gren": {"n": "Grenadier", "t": "soft", "hp": 80.0, "dmg": 3.2, "rng": 90.0, "spd": 8.0, "cost": 40.0, "upk": 0.03, "train": 12.0, "cap": {T.BARRACKS: 2, T.BASE: 2}, "vs": {"soft": 0.8, "armor": 1.8, "air": 0.0, "ship": 0.3}},
	"snip": {"n": "Sniper", "t": "soft", "hp": 45.0, "dmg": 5.5, "rng": 330.0, "spd": 8.0, "cost": 50.0, "upk": 0.03, "train": 16.0, "cap": {T.BARRACKS: 2}, "vs": {"soft": 1.6, "armor": 0.1, "air": 0.2, "ship": 0.1}},
	"medic": {"n": "Medic", "t": "soft", "hp": 60.0, "dmg": 0.0, "rng": 110.0, "spd": 9.0, "cost": 40.0, "upk": 0.03, "train": 14.0, "cap": {T.BARRACKS: 1, T.BASE: 1}, "vs": {}, "heal": 2.5},
	"ltank": {"n": "Light tank", "t": "armor", "hp": 220.0, "dmg": 4.5, "rng": 220.0, "spd": 22.0, "cost": 100.0, "upk": 0.05, "train": 22.0, "cap": {T.BASE: 3}, "vs": {"soft": 1.4, "armor": 0.8, "air": 0.0, "ship": 0.3}},
	"tank": {"n": "Battle tank", "t": "armor", "hp": 350.0, "dmg": 6.5, "rng": 240.0, "spd": 14.0, "cost": 140.0, "upk": 0.08, "train": 35.0, "cap": {T.BASE: 3}, "vs": {"soft": 1.6, "armor": 1.0, "air": 0.0, "ship": 0.5}},
	"htank": {"n": "Heavy tank", "t": "armor", "hp": 650.0, "dmg": 8.5, "rng": 250.0, "spd": 9.0, "cost": 260.0, "upk": 0.14, "train": 60.0, "cap": {T.BASE: 1}, "vs": {"soft": 1.5, "armor": 1.3, "air": 0.0, "ship": 0.6}},
	"art": {"n": "Artillery", "t": "armor", "hp": 120.0, "dmg": 12.0, "rng": 600.0, "spd": 8.0, "cost": 200.0, "upk": 0.09, "train": 40.0, "cap": {T.BASE: 2}, "vs": {"soft": 1.5, "armor": 0.9, "air": 0.0, "ship": 1.0}},
	"aa": {"n": "Anti-air", "t": "armor", "hp": 140.0, "dmg": 5.0, "rng": 380.0, "spd": 10.0, "cost": 150.0, "upk": 0.07, "train": 28.0, "cap": {T.BASE: 1}, "vs": {"soft": 0.3, "armor": 0.2, "air": 3.0, "ship": 0.0}},
	"jet": {"n": "Strike jet", "t": "air", "hp": 150.0, "dmg": 9.0, "rng": 200.0, "spd": 45.0, "cost": 220.0, "upk": 0.12, "train": 50.0, "cap": {T.BASE: 2}, "radar": true, "vs": {"soft": 1.2, "armor": 1.5, "air": 0.8, "ship": 1.2}},
	"fighter": {"n": "Fighter", "t": "air", "hp": 120.0, "dmg": 6.0, "rng": 220.0, "spd": 55.0, "cost": 200.0, "upk": 0.1, "train": 45.0, "cap": {T.BASE: 2}, "radar": true, "vs": {"soft": 0.5, "armor": 0.4, "air": 2.2, "ship": 0.5}},
	"bomber": {"n": "Bomber", "t": "air", "hp": 220.0, "dmg": 10.0, "rng": 140.0, "spd": 38.0, "cost": 300.0, "upk": 0.16, "train": 65.0, "cap": {T.BASE: 1}, "radar": true, "vs": {"soft": 1.3, "armor": 1.8, "air": 0.0, "ship": 2.0}},
	"heli": {"n": "Helicopter", "t": "air", "hp": 160.0, "dmg": 7.0, "rng": 190.0, "spd": 30.0, "cost": 240.0, "upk": 0.13, "train": 50.0, "cap": {T.BASE: 1}, "vs": {"soft": 1.4, "armor": 1.6, "air": 0.3, "ship": 1.0}},
	"patrol": {"n": "Patrol boat", "t": "ship", "hp": 160.0, "dmg": 4.0, "rng": 200.0, "spd": 28.0, "cost": 120.0, "upk": 0.06, "train": 25.0, "cap": {T.NAVYARD: 3}, "vs": {"soft": 1.0, "armor": 0.5, "air": 0.3, "ship": 1.0}},
	"destroyer": {"n": "Destroyer", "t": "ship", "hp": 520.0, "dmg": 8.0, "rng": 320.0, "spd": 16.0, "cost": 320.0, "upk": 0.15, "train": 60.0, "cap": {T.NAVYARD: 2}, "vs": {"soft": 1.3, "armor": 1.0, "air": 1.0, "ship": 1.4}},
	"transport": {"n": "Transport", "t": "ship", "hp": 400.0, "dmg": 0.0, "rng": 100.0, "spd": 12.0, "cost": 200.0, "upk": 0.08, "train": 40.0, "cap": {T.NAVYARD: 1}, "vs": {}, "lands": 6},
}
const DEF_W := {"inf": 2, "gren": 1, "snip": 1, "medic": 1, "ltank": 1, "tank": 2, "htank": 1, "art": 1, "aa": 1, "jet": 1, "fighter": 1, "bomber": 1, "heli": 1, "patrol": 1, "destroyer": 1, "transport": 1}
const RANKS := ["Recruit", "Veteran", "Elite", "Legend"]
const RANK_XP := [250.0, 800.0, 2000.0]  # damage dealt (or healed) to reach rank 1, 2, 3
const RANK_DMG := 0.15  # per rank
const RANK_HP := 0.10
const ARMY_MAX := 150  # per town: training stops here (upkeep, and fights cost O(n^2))
const LANE := 35.0  # px of sideways offset per unit of lane, counted in range checks (must stay below the shortest weapon range / 2)
const TCLS := {"soft": 0, "armor": 1, "air": 2, "ship": 3}
static var _vsv := {}  # kind -> damage multipliers as a flat array indexed by target class, for the fight inner loop
static var booms: Array = []  # runtime only: explosions for the war visuals
static var blasts: Array = []  # runtime only: buildings hit by raids and bombers {t: town, p: town-space pixel, ts: ms}


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


## Ships can only fight where a river runs across the border between two neighbours (water on both edges).
static func river(a: City, b: City) -> bool:
	var d := Diplo.side(a, b)
	return d >= 0 and _wet_edge(a, d) and _wet_edge(b, (d + 2) % 4)


static func _wet_edge(c: City, d: int) -> bool:
	var r := c.terr
	var xs := range(r.position.x, r.end.x) if d % 2 == 0 else [r.end.x - 1 if d == 1 else r.position.x]
	var ys := range(r.position.y, r.end.y) if d % 2 == 1 else [r.position.y if d == 0 else r.end.y - 1]
	for y in ys:
		for x in xs:
			if c.water[y * City.W + x] == 1:
				return true
	return false


static func caps(c: City) -> Dictionary:
	var rd := (c.bt.get(T.RADAR, []) as Array).size()
	var r := {}
	for k in KIND:
		var n := 0
		for id in KIND[k]["cap"]:
			n += int(KIND[k]["cap"][id]) * (c.bt.get(id, []) as Array).size()
		r[k] = mini(n, 2 * rd) if KIND[k].get("radar", false) else n
	return r


static func counts(c: City) -> Dictionary:
	var n := {}
	for k in KIND:
		n[k] = 0
	for u in c.army:
		n[u["k"]] += 1
	return n


static func weights(c: City) -> Dictionary:
	var w := DEF_W.duplicate()
	for k in c.train_w:
		if w.has(k):
			w[k] = int(c.train_w[k])
	return w


## Military strength used by the AI and by tribute demands.
static func power(c: City) -> float:
	var p := 0.0
	for u in c.army:
		p += float(KIND[u["k"]]["cost"]) * 0.0012 * (1.0 + 0.1 * int(u.get("rk", 0)))
	return p


static func summary(c: City) -> String:
	var n := counts(c)
	var k := caps(c)
	var parts: PackedStringArray = []
	var room := 0
	for id in KIND:
		room += int(k[id])
		if int(n[id]) > 0:
			parts.append("%d %s" % [n[id], String(KIND[id]["n"]).to_lower()])
	return "%d units%s (room for %d)" % [c.army.size(), (": " + ", ".join(parts)) if not parts.is_empty() else "", room]


## Planner towns train what counters the enemy: sums the target classes of every unit a hostile neighbour has and bumps the weights of types that beat the big ones.
static func adapt(c: City) -> void:
	var tot := {"soft": 0, "armor": 0, "air": 0, "ship": 0}
	var n := 0
	for p in c.partners:
		if Diplo.treaty(c, p) == "war" or (Diplo.treaty(c, p) == "" and Diplo.rel(c, p) < -0.2):
			for u in p.army:
				tot[KIND[u["k"]]["t"]] += 1
				n += 1
	var w := DEF_W.duplicate()
	if n >= 3:
		var up := {"air": ["aa", "fighter"], "armor": ["gren", "art", "heli", "bomber", "htank"], "soft": ["tank", "snip", "art", "ltank", "bomber"], "ship": ["destroyer", "patrol", "bomber", "art"]}
		for cl in up:
			if float(tot[cl]) / n >= 0.25:
				for k in up[cl]:
					w[k] = mini(int(w[k]) + (2 if float(tot[cl]) / n >= 0.5 else 1), 3)
	c.train_w = w


static func rank(u: Dictionary) -> int:
	return int(u.get("rk", 0))


static func max_hp(u: Dictionary) -> float:
	return float(u.get("mx", KIND[u["k"]]["hp"]))


static func _unit(k: String, hp_scale := 1.0) -> Dictionary:
	var h := float(KIND[k]["hp"]) * hp_scale
	return {"k": k, "hp": h, "mx": h, "xp": 0.0, "rk": 0, "tgt": "", "s": 0.0, "l": randf_range(-1.0, 1.0)}


static func _gain(u: Dictionary, xp: float) -> void:
	u["xp"] = float(u.get("xp", 0.0)) + xp
	while rank(u) < 3 and float(u["xp"]) >= float(RANK_XP[rank(u)]):
		var m0 := max_hp(u)
		u["rk"] = rank(u) + 1
		u["mx"] = m0 * (1.0 + RANK_HP * 1.0 / (1.0 + RANK_HP * (rank(u) - 1)))
		u["hp"] = float(u["hp"]) + float(u["mx"]) - m0


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
	if not c.human:
		c.train_t["_a"] = float(c.train_t.get("_a", 0.0)) + 1.0
		if float(c.train_t["_a"]) >= 10.0:
			c.train_t["_a"] = 0.0
			adapt(c)
	if c.train_on and c.army.size() < ARMY_MAX:
		var cap := caps(c)
		var cnt := counts(c)
		var w := weights(c)
		for k in KIND:
			if int(w[k]) > 0 and int(cnt[k]) < int(cap[k]) and c.coins >= float(KIND[k]["cost"]) * 3.0:
				c.train_t[k] = float(c.train_t.get(k, 0.0)) + 0.5 * int(w[k])  # priority 1 = half speed, 3 = 1.5x
				if float(c.train_t[k]) >= float(KIND[k]["train"]):
					c.train_t[k] = 0.0
					c.coins -= float(KIND[k]["cost"])
					c.army.append(_unit(k))
	var foes: Array = []
	for p in c.partners:
		if Diplo.treaty(c, p) == "war":
			foes.append(p)
	var i := 0
	for u in c.army:
		var ok: Array = foes.filter(func(p: City) -> bool: return KIND[u["k"]]["t"] != "ship" or river(c, p))  # ships only where a river joins the towns
		if ok.is_empty():
			u["tgt"] = ""
		elif not ok.any(func(p: City) -> bool: return p.town_name == u["tgt"]):
			u["tgt"] = (ok[i % ok.size()] as City).town_name
			i += 1
		if u["tgt"] == "" and float(u["s"]) > 0.0:
			u["s"] = maxf(float(u["s"]) - float(KIND[u["k"]]["spd"]), 0.0)  # march home


static func _row(k: String) -> PackedFloat32Array:
	if not _vsv.has(k):
		var v: Dictionary = KIND[k]["vs"]
		_vsv[k] = PackedFloat32Array([float(v.get("soft", 0.0)), float(v.get("armor", 0.0)), float(v.get("air", 0.0)), float(v.get("ship", 0.0))])
	return _vsv[k]


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
	var n := all.size()
	var gpos := PackedFloat32Array()  # position in a's frame
	var lane := PackedFloat32Array()
	var tc := PackedInt32Array()  # target class of each unit
	var foes := [PackedInt32Array(), PackedInt32Array()]  # foes[s]: indices of the units opposing side s
	var ms := [0.0, 0.0]  # mean march distance of each side's fighters, where medics stay behind
	var mc := [0, 0]
	for i in n:
		gpos.append(float(all[i]["s"]) if side[i] == 0 else ln - float(all[i]["s"]))
		lane.append(float(all[i]["l"]))
		tc.append(int(TCLS[KIND[all[i]["k"]]["t"]]))
		foes[1 - side[i]].append(i)
		if not KIND[all[i]["k"]].has("heal") and not KIND[all[i]["k"]].has("lands"):
			ms[side[i]] += float(all[i]["s"])
			mc[side[i]] += 1
	var hits: Array = []
	hits.resize(n)
	hits.fill(0.0)
	var heals := hits.duplicate()
	for i in n:
		var u: Dictionary = all[i]
		var kd: Dictionary = KIND[u["k"]]
		var own_s := float(u["s"])
		var spd := float(kd["spd"]) * (1.0 + 0.12 * float(u["l"]))  # lane-based jitter so a column does not arrive as one clump
		if kd.has("lands"):  # transports hold back until the enemy fleet is gone, then run for the shore
			var ships := false
			for j in foes[side[i]]:
				if tc[j] == 3:
					ships = true
			var tg: float = (ms[side[i]] / maxf(mc[side[i]], 1) - 70.0) if ships else ln - 20.0
			u["s"] = clampf(own_s + clampf(tg - own_s, -spd, spd), 0.0, ln)
			continue
		if kd.has("heal"):
			var cand: Array = []
			for j in n:
				if j != i and side[j] == side[i] and float(all[j]["hp"]) < max_hp(all[j]) and absf(float(gpos[j]) - float(gpos[i])) <= float(kd["rng"]):
					cand.append(j)
			cand.sort_custom(func(p: int, q: int) -> bool: return float(all[p]["hp"]) / max_hp(all[p]) < float(all[q]["hp"]) / max_hp(all[q]))
			for j in cand.slice(0, 3):
				var h := minf(float(kd["heal"]), max_hp(all[j]) - float(all[j]["hp"]))
				heals[j] += h
				_gain(u, h * 0.5)
			var home: float = (float(ms[side[i]]) / float(mc[side[i]]) - 70.0) if mc[side[i]] > 0 else 0.0
			u["s"] = clampf(own_s + clampf(home - own_s, -spd, spd), 0.0, ln)
			continue
		var best := -1  # best target in range (damage-weighted, so AA picks planes), and the nearest one otherwise
		var bs := 1e9
		var near := -1
		var nd := 1e9
		var row := _row(u["k"])
		var rng_ := float(kd["rng"])
		var gi := gpos[i]
		var li := lane[i]
		for j in foes[side[i]]:
			var vs := row[tc[j]]
			if vs <= 0.0:
				continue
			var d := absf(gpos[j] - gi) + absf(lane[j] - li) * LANE
			if d < nd:
				nd = d
				near = j
			if d <= rng_ and d / vs < bs:
				bs = d / vs
				best = j
		if best >= 0:
			var dm := float(kd["dmg"]) * (1.0 + RANK_DMG * rank(u)) * row[tc[best]]
			hits[best] += dm
			_gain(u, dm)
			u["ft"] = now
			u["fg"] = gpos[best]
			u["fl"] = all[best]["l"]
			continue
		var target_s := ln - 20.0
		if near >= 0:
			target_s = float(gpos[near]) if side[i] == 0 else ln - float(gpos[near])
			target_s -= signf(target_s - own_s) * maxf(float(kd["rng"]) * 0.8 - absf(float(all[near]["l"]) - float(u["l"])) * LANE, 10.0)  # stop at firing range, allowing for the sideways gap
		u["s"] = clampf(own_s + clampf(target_s - own_s, -spd, spd), 0.0, ln)
	for i in n:
		all[i]["hp"] = minf(float(all[i]["hp"]) - float(hits[i]) + float(heals[i]), max_hp(all[i]))
	for i in n:
		if float(all[i]["hp"]) <= 0.0:
			var owner: City = a if side[i] == 0 else b
			var killer: City = b if side[i] == 0 else a
			owner.army.erase(all[i])
			killer.war_sc[owner.town_name] = int(killer.war_sc.get(owner.town_name, 0)) + 1
			booms.append({"a": a.town_name, "b": b.town_name, "g": gpos[i], "l": all[i]["l"], "t": now})
			owner.sounds.append("alarm")
	booms = booms.filter(func(e: Dictionary) -> bool: return now - int(e["t"]) < 3000)
	blasts = blasts.filter(func(e: Dictionary) -> bool: return now - int(e["ts"]) < 9000)
	a.war_t -= 1.0
	if a.war_t <= 0.0:
		a.war_t = 20.0
		a.war_n[b.town_name] = int(a.war_n.get(b.town_name, 0)) + 1
		b.war_n[a.town_name] = int(b.war_n.get(a.town_name, 0)) + 1
	_occupy(a, b, ln)
	_occupy(b, a, ln)
	_bomb(a, b, ln)
	_bomb(b, a, ln)
	if a.war_n.get(b.town_name, 0) >= 30 and a.army.size() + b.army.size() < 6:
		Diplo.sign_treaty(a, b, "")
		Diplo._say(a, b, "%s and %s, with their armies spent, agree to a ceasefire." % [a.town_name, b.town_name])


## Attackers standing on a town's edge unopposed raid it and, held long enough, force its surrender.
static func _occupy(att: City, vic: City, ln: float) -> void:
	var n := 0
	for u in _of(att, vic.town_name):
		if float(u["s"]) >= ln - 80.0:
			n += int(KIND[u["k"]].get("lands", 1))
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


## Bombers over an enemy town with no fighters, jets or anti-air left to stop them flatten its buildings, one strike per bomber every few seconds.
static func _bomb(att: City, vic: City, ln: float) -> void:
	var nb := 0
	for u in _of(att, vic.town_name):
		if u["k"] == "bomber" and float(u["s"]) >= ln - 150.0:
			nb += 1
	if nb == 0:
		return
	for u in _of(vic, att.town_name):
		if u["k"] in ["aa", "fighter", "jet"]:
			return
	att.raid["b" + vic.town_name] = float(att.raid.get("b" + vic.town_name, 0.0)) + 0.15 * nb
	if float(att.raid["b" + vic.town_name]) >= 1.0:
		att.raid["b" + vic.town_name] = 0.0
		vic.strike(1, att)
