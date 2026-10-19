class_name Capture
extends RefCounted
## Dead towns are up for grabs (owner, 2026-10-19). A town whose people have all left is derelict: nobody owns it. Any side can send
## troops: they tear down its town hall, then stay while a new town hall is built (`CLAIM_SECS`). While they build, another side can
## arrive; two sides on the same ground fight and the loser's alliances with the winner break, so a claim is never safe until it is done.
## Troops are real units taken from the sender's army and returned to the new town's garrison. Pure rules on City state, run on the host once a second.

const RAZE_NEED := 30.0  # unit-seconds of tearing down the town hall
const CLAIM_SECS := 120.0  # a new town hall takes this long to build with the troops holding the ground
const TRAVEL := 30.0  # seconds to cross to a neighbouring plot, plus this much per extra plot
const SETTLERS := 6  # people the claimant moves in
const SEND_COOLDOWN := 40.0


static func _power(units: Array) -> float:
	var p := 0.0
	for u in units:
		p += float(Military.KIND[u["k"]]["cost"]) * 0.0012 * (1.0 + 0.1 * int(u.get("rk", 0)))
	return p


static func _lead(towns: Array, side: String) -> City:
	for t: City in towns:
		if t.over == "" and Victory.side(t) == side:
			return t
	return null


static func _dist(a: City, b: City) -> int:
	return absi(a.gpos.x - b.gpos.x) + absi(a.gpos.y - b.gpos.y)


## Send `n` units of `from`'s army to the derelict town `d`. False when it is not allowed.
static func send(from: City, d: City, n: int) -> bool:
	if not d.derelict or from.over != "" or from == d or n < 1 or from.army.size() <= n or from.cap_cd > 0.0:
		return false
	var units: Array = []
	for _i in n:
		var u: Dictionary = from.army.pop_back()
		for k in ["ft", "fg", "fl", "p"]:  # runtime battle keys do not travel
			u.erase(k)
		units.append(u)
	d.inbound.append({"side": Victory.side(from), "from": from.town_name, "eta": TRAVEL * float(_dist(from, d)), "u": units})
	from.cap_cd = SEND_COOLDOWN
	from.msg = "%d troops march on the empty town of %s." % [n, d.town_name]
	from._log(from.msg)
	return true


static func second(towns: Array) -> void:
	for d: City in towns:
		if d.derelict:
			_arrive(d)
			var present: Array = []
			for s in d.garrison:
				if (d.garrison[s] as Array).size() > 0:
					present.append(s)
			if present.size() >= 2:
				_clash(d, present, towns)
			elif present.size() == 1:
				_progress(d, present[0], towns)
		elif d.cap_cd > 0.0:
			d.cap_cd -= 1.0


static func _arrive(d: City) -> void:
	var keep: Array = []
	for g: Dictionary in d.inbound:
		g["eta"] = float(g["eta"]) - 1.0
		if float(g["eta"]) > 0.0:
			keep.append(g)
			continue
		var s: String = g["side"]
		if not d.garrison.has(s):
			d.garrison[s] = []
		(d.garrison[s] as Array).append_array(g["u"])
	d.inbound = keep


## Two or more sides on the same ground: each unit may fall in proportion to the strength facing it. Rivals break treaties and go to war.
static func _clash(d: City, present: Array, towns: Array) -> void:
	var power := {}
	var total := 0.0
	for s in present:
		power[s] = _power(d.garrison[s])
		total += float(power[s])
	for s in present:
		var foe := total - float(power[s])
		var chance := clampf(0.06 * foe / maxf(float(power[s]), 0.01), 0.0, 0.5)
		var alive: Array = []
		for u in d.garrison[s]:
			if d.rng.randf() >= chance:
				alive.append(u)
		d.garrison[s] = alive
	for i in present.size():
		for j in range(i + 1, present.size()):
			var a := _lead(towns, present[i])
			var b := _lead(towns, present[j])
			if a != null and b != null and Diplo.treaty(a, b) != "war":
				if Diplo.treaty(a, b) in ["alliance", "pact", "vassal"]:
					a._log("Our alliance with %s broke over %s." % [b.town_name, d.town_name])
				Diplo.declare(a, b, "land", "claim on " + d.town_name)
	if d.claim_by != "" and (d.garrison.get(d.claim_by, []) as Array).is_empty():
		d.claim_by = ""
		d.claim_t = 0.0


static func _progress(d: City, s: String, towns: Array) -> void:
	var lead := _lead(towns, s)
	if lead == null:
		return
	var n := float((d.garrison[s] as Array).size())
	if d.raze_left > 0.0:
		d.raze_left -= n * 0.5
		if d.raze_left <= 0.0:
			d.raze_left = 0.0
			for i in d.cells:
				if d.grid[i] == Catalog.Id.TOWNHALL:
					d.grid[i] = Catalog.Id.EMPTY
			lead.msg = "The town hall of %s is down. Hold it while our own is built." % d.town_name
			lead._log(lead.msg)
		return
	if d.claim_by != s:  # a different side took over the ground: the build starts again
		d.claim_by = s
		d.claim_t = 0.0
	d.claim_t += 1.0
	if d.claim_t >= CLAIM_SECS:
		_resettle(d, s, lead, towns)


static func _resettle(d: City, s: String, lead: City, towns: Array) -> void:
	d.derelict = false
	d.over = ""
	d.owner = lead.owner
	d.human = lead.human
	d.group = lead.group
	d.liege = ""
	d.side_key = s
	d.army = d.garrison[s]
	d.garrison.clear()
	for g: Dictionary in d.inbound:  # troops still on the road turn back
		for t: City in towns:
			if t.town_name == String(g["from"]):
				t.army.append_array(g["u"])
	d.inbound.clear()
	var dole := minf(lead.coins * 0.5, 200.0)
	lead.coins -= dole
	d.coins = dole
	d.mood = 0.6
	d.empty_t = 0
	d.claim_by = ""
	d.claim_t = 0.0
	d._scan()
	for _i in SETTLERS:
		d._spawn()
	d.pop = d.citizens.size()
	lead.msg = "%s is ours: a new town hall stands there." % d.town_name
	lead._log(lead.msg)


## Planner towns with spare troops send them to empty towns nearby.
static func ai(towns: Array) -> void:
	for a: City in towns:
		if a.human or a.over != "" or a.army.size() < 12 or a.cap_cd > 0.0 or Diplo.ambition(a) < 0.3:
			continue
		var best: City = null
		for d: City in towns:
			if d.derelict and _dist(a, d) <= 4 and (best == null or _dist(a, d) < _dist(a, best)):
				best = d
		if best != null:
			send(a, best, mini(a.army.size() / 2, 30))
