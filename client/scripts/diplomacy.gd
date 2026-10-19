class_name Diplo
extends RefCounted
## Relations between towns of the region. Each City keeps its own opinion in `rel[town_name]` (-1..1),
## a `temper` (baseline attitude) and shared `treaty[town_name]` ("", "pact", "alliance", "embargo").
## Static helpers only; main.gd calls second() once per sim second.

const T = Catalog.Id
const MIN_ARMY := 3  # trained units a computer-run town needs before it starts a war
const DIRN := ["north", "east", "south", "west"]
const COSTS := {"gift": 100.0, "pact": 200.0, "alliance": 400.0, "peace": 150.0}
const TENSION_RATE := 0.003  # per second between linked towns without a treaty, scaled by ambition
const VASSAL_SHARE := 0.1  # share of a vassal's positive income paid to its overlord each second
const OCC_NEED := {"tribute": 15.0, "land": 40.0, "total": 60.0}  # occupation points that force a surrender, by war goal


static func rel(a: City, b: City) -> float:
	return float(a.rel.get(b.town_name, a.temper * 0.5))


static func avg(a: City, b: City) -> float:
	return (rel(a, b) + rel(b, a)) * 0.5


static func treaty(a: City, b: City) -> String:
	return String(a.treaty.get(b.town_name, ""))


static func stance(r: float) -> String:
	if r < -0.6:
		return "Hostile"
	if r < -0.2:
		return "Tense"
	if r < 0.2:
		return "Neutral"
	if r < 0.6:
		return "Friendly"
	return "Warm"


static func mil(c: City) -> float:
	return Military.power(c) + float(c.cov.get("defence", 0.0)) + 0.4 * (c.bt.get(T.BASE, []) as Array).size() + 0.15 * (c.bt.get(T.BARRACKS, []) as Array).size() + 0.1 * (c.bt.get(T.RADAR, []) as Array).size() + 0.35 * (c.bt.get(T.NAVYARD, []) as Array).size()


## Fighting weight for deciding who may start a war: arms plus a militia share of the population, so small towns without barracks can still be bullies.
static func strength(c: City) -> float:
	return mil(c) + c.pop / 300.0


## 0..1 appetite for conquest: strong military and a hostile temper raise it.
static func ambition(c: City) -> float:
	var m := mil(c)
	return clampf(0.35 + 0.4 * m / (m + 3.0) - 0.4 * c.temper, 0.0, 1.0)


static func occ_need(w: City, l: City) -> float:
	return OCC_NEED.get(String(w.war_goal.get(l.town_name, "land")), 40.0)


## What `x` wants from `y`: a decisive lead takes everything, a town with room to grow takes land, otherwise tribute.
static func pick_goal(x: City, y: City) -> String:
	if strength(x) > strength(y) + 1.5:
		return "total"
	var k := side(x, y)
	return "land" if k >= 0 and x.can_expand(k) else "tribute"


## Which side of `a` town `b` lies on (0 N, 1 E, 2 S, 3 W), or -1 if not next to it.
static func side(a: City, b: City) -> int:
	var dl := b.gpos - a.gpos
	if dl == Vector2i(0, -1):
		return 0
	if dl == Vector2i(1, 0):
		return 1
	if dl == Vector2i(0, 1):
		return 2
	if dl == Vector2i(-1, 0):
		return 3
	return -1


static func _open(c: City, d: int) -> bool:
	return int(c.gate[d]) > 0


## Trade flows only between adjacent towns that both have a road reaching their shared border (planner towns lay that road themselves).
static func linked(a: City, b: City) -> bool:
	var d := side(a, b)
	return d >= 0 and _open(a, d) and _open(b, (d + 2) % 4)


## Multiplier on power/water imports and commuters between two towns.
static func tmult(a: City, b: City) -> float:
	var t := treaty(a, b)
	if t == "embargo" or t == "war" or not linked(a, b):
		return 0.0
	var m := clampf(0.6 + 0.5 * avg(a, b), 0.2, 1.3)
	if t == "pact":
		m *= 1.25
	elif t == "alliance" or t == "vassal":
		m *= 1.4
	return m


static func _shift(a: City, b: City, r_a: float, r_b: float) -> void:
	a.rel[b.town_name] = clampf(rel(a, b) + r_a, -1.0, 1.0)
	b.rel[a.town_name] = clampf(rel(b, a) + r_b, -1.0, 1.0)


static func sign_treaty(a: City, b: City, t: String) -> void:
	if t != "vassal" and treaty(a, b) == "vassal":
		a.liege = ""  # any other treaty ends vassalage
		b.liege = ""
	a.treaty[b.town_name] = t
	b.treaty[a.town_name] = t
	a.pet_ver += 1
	b.pet_ver += 1


static func _say(a: City, b: City, text: String) -> void:
	for c in [a, b]:
		c.msg = text
		c._log(text)


## Player actions. Returns a headline.
## Puts a town in a group (0 leaves it). Every other town of the same group becomes an ally.
static func set_group(c: City, g: int, towns: Array) -> void:
	c.group = g
	if g <= 0:
		return
	for o in towns:
		if o != c and (o as City).group == g:
			sign_treaty(c, o, "alliance")


static func act(a: City, b: City, what: String) -> String:
	var t := treaty(a, b)
	if a.group > 0 and a.group == b.group and (what == "war" or what == "embargo" or what == "cancel"):
		return "%s is in your group." % b.town_name
	var cost: float = COSTS.get(what, 0.0)
	if a.coins < cost:
		return "That needs $%d." % int(cost)
	if _player(a, b) and (what == "pact" or what == "alliance" or (what == "peace" and t == "war") or (what == "tribute" and mil(a) >= mil(b) + 0.3)):
		return _ask(a, b, what, cost, t)
	match what:
		"gift":
			a.coins -= cost
			_shift(a, b, 0.03, 0.16)
			b.coins += cost * 0.5
			return "%s gratefully accepts your gift." % b.town_name
		"pact":
			if t != "" and t != "embargo":
				return "You already have a treaty with %s." % b.town_name
			if avg(a, b) < 0.15:
				return "%s does not trust you enough for a trade pact (relation %d%%)." % [b.town_name, int(avg(a, b) * 100.0)]
			a.coins -= cost
			sign_treaty(a, b, "pact")
			_shift(a, b, 0.05, 0.1)
			return "Trade pact signed with %s: imports and commuters flow 25%% better." % b.town_name
		"alliance":
			if t != "pact":
				return "An alliance needs a trade pact first."
			if avg(a, b) < 0.55:
				return "%s is not close enough to ally (relation %d%%, needs 55%%)." % [b.town_name, int(avg(a, b) * 100.0)]
			a.coins -= cost
			sign_treaty(a, b, "alliance")
			_shift(a, b, 0.1, 0.1)
			return "Alliance with %s! Shared defence and 40%% better trade." % b.town_name
		"embargo":
			sign_treaty(a, b, "embargo")
			_shift(a, b, -0.05, -0.3)
			return "Embargo on %s. All trade and commuting stops." % b.town_name
		"lift":
			if t != "embargo":
				return "There is no embargo."
			sign_treaty(a, b, "")
			_shift(a, b, 0.0, 0.08)
			return "Embargo lifted."
		"peace":
			if t == "war":
				if int(a.war_n.get(b.town_name, 0)) < 3:
					return "%s refuses to talk yet. The war has barely begun." % b.town_name
				a.coins -= cost
				sign_treaty(a, b, "")
				_shift(a, b, 0.1, 0.3)
				_say(a, b, "Ceasefire between %s and %s." % [a.town_name, b.town_name])
				return "Ceasefire signed with %s." % b.town_name
			a.coins -= cost
			_shift(a, b, 0.05, 0.25)
			if t == "embargo":
				sign_treaty(a, b, "")
			return "Your envoys visit %s with gifts and apologies." % b.town_name
		"tribute":
			if mil(a) < mil(b) + 0.3:
				_shift(a, b, -0.05, -0.15)
				return "%s laughs off your demand. You are not strong enough." % b.town_name
			var pay := minf(maxf(b.coins * 0.3, 0.0), 150.0)
			b.coins -= pay
			a.coins += pay
			_shift(a, b, 0.0, -0.4)
			return "%s pays $%d tribute and resents it." % [b.town_name, int(pay)]
		"war":
			if t == "war":
				return "You are already at war."
			if a.liege != "":
				return "A vassal cannot declare war."
			declare(a, b, "land", "")
			return "War declared on %s. Militia muster; barracks and bases train real units that march to the front and fight." % b.town_name
		"leave":
			if t == "":
				return "No treaty to cancel."
			if t == "vassal" and a.liege != "":
				return "You cannot leave your overlord; only %s can release you." % b.town_name
			if t == "war":
				return "A war is ended with a peace treaty, not cancelled."
			sign_treaty(a, b, "")
			_shift(a, b, -0.05, -0.15)
			return "Treaty with %s cancelled." % b.town_name
	return ""


## `a` declares war on `b` with a stated goal; `why` names the trigger in the headline.
## A computer-run town goes to war only with a trained army (units come from barracks and bases, never from nothing).
static func ready(c: City) -> bool:
	return c.army.size() >= MIN_ARMY


static func declare(a: City, b: City, goal: String, why: String) -> void:
	sign_treaty(a, b, "war")
	for p in [[a, b], [b, a]]:
		var x: City = p[0]
		var y: City = p[1]
		x.war_n[y.town_name] = 0
		x.war_sc[y.town_name] = 0
		x.war_goal[y.town_name] = goal
		x.tension[y.town_name] = 0.0
	_shift(a, b, -0.3, -0.6)
	_say(a, b, "%s declares war on %s%s! Goal: %s." % [a.town_name, b.town_name, (" (" + why + ")") if why != "" else "", goal])
	a.sounds.append("alarm")
	b.sounds.append("alarm")


## When `b` is attacked, every other member of its group declares war on `a` too (never on a groupmate of `a`).
static func defend(a: City, b: City, towns: Array) -> void:
	if b.group <= 0 or b.group == a.group:
		return
	for o in towns:
		var d: City = o
		if d != a and d != b and d.group == b.group and d.over == "" and d.liege == "" and treaty(d, a) != "war":
			declare(d, a, "land", "defending " + b.town_name)


## Wars in progress, one row per war from the declaring side: {a, b, goal, occ, need, secs}.
static func wars(towns: Array) -> Array:
	var out := []
	for i in towns.size():
		for j in range(i + 1, towns.size()):
			var x: City = towns[i]
			var y: City = towns[j]
			if treaty(x, y) == "war":
				out.append({"a": x.town_name, "b": y.town_name, "goal": String(x.war_goal.get(y.town_name, "land")), "occ": maxi(int(y.occ.get(x.town_name, 0.0)), int(x.occ.get(y.town_name, 0.0))), "need": int(occ_need(x, y)), "secs": int(x.war_n.get(y.town_name, 0)) * 20})
	return out


## True when `b` is run by a different player (multiplayer): treaties and tribute then need that player's answer instead of an AI's.
static func _player(a: City, b: City) -> bool:
	return b.owner != 0 and b.owner != a.owner


## A proposal to another player: it lands in their petitions (answered like any offer); the price is held until they decide.
static func _ask(a: City, b: City, what: String, cost: float, t: String) -> String:
	if what == "pact" and t != "" and t != "embargo":
		return "You already have a treaty with %s." % b.town_name
	if what == "alliance" and t != "pact":
		return "An alliance needs a trade pact first."
	if what == "peace" and int(a.war_n.get(b.town_name, 0)) < 3:
		return "%s will not talk yet. The war has barely begun." % b.town_name
	var ok := false
	if what == "tribute":
		var amt := clampf(b.coins * 0.3, 40.0, 150.0)
		ok = _offer(b, a, "demand", {"t": "%s demands tribute" % a.town_name, "txt": "%s wants $%d to keep the peace. Refuse and its raiders will hit your border." % [a.town_name, int(amt)], "amount": amt, "days": 0})
	else:
		var tr: String = "" if what == "peace" else what
		var label := "a ceasefire" if what == "peace" else "a %s" % what
		ok = _offer(b, a, "offer", {"t": "%s proposes %s" % [a.town_name, label], "txt": "%s offers %s. Accept and it takes effect now; refuse and %s gets its money back." % [a.town_name, label, a.town_name], "treaty": tr, "days": 0, "pay": cost})
	if not ok:
		return "%s already has a proposal from you waiting." % b.town_name
	a.coins -= cost
	return "Proposal sent to %s." % b.town_name


## Answer to an offer/demand decision made by `a` (the human town).
static func resolve(a: City, p: Dictionary, yes: bool) -> void:
	var b := a.partner(String(p["with"]))
	if b == null:
		return
	if p["kind"] == "offer":
		if yes:
			sign_treaty(a, b, String(p["treaty"]))
			_shift(a, b, 0.08, 0.1)
			a._log("You signed a %s with %s." % [String(p["treaty"]) if p["treaty"] != "" else "ceasefire", b.town_name])
		else:
			b.coins += float(p.get("pay", 0.0))  # a proposing player's deposit comes back
			_shift(a, b, 0.0, -0.04)
	else:  # demand
		var pay: float = float(p["amount"])
		if yes and a.coins >= pay:
			a.coins -= pay
			b.coins += pay
			_shift(a, b, -0.02, 0.15)
			a._log("You paid %s $%d to keep the peace." % [b.town_name, int(pay)])
		else:
			_shift(a, b, -0.1, -0.02)
			_raid(b, a)


static func _raid(from: City, to: City) -> void:
	var sev := 1.0 - 0.7 * clampf(float(to.cov.get("defence", 0.0)), 0.0, 1.0)
	var n := int(round(3.0 * sev))
	if n > 0 and to.pop > 15:
		to.strike(n, from)
		to._offer_recovery("raid by %s" % from.town_name)
	to.sounds.append("alarm")
	_say(from, to, "%s raids %s's border%s." % [from.town_name, to.town_name, (": %d buildings lost" % n) if n > 0 else ", but the defences hold"])


static func _offer(a: City, b: City, kind: String, extra: Dictionary) -> bool:
	for p in a.petitions:
		if p.get("with", "") == b.town_name and p["kind"] != "recover":
			return false
	var p := {"kind": kind, "id": kind + b.town_name, "tribe": "", "with": b.town_name, "expires": a.day + 2}
	p.merge(extra)
	a.petitions.append(p)
	a.pet_ver += 1
	a.msg = String(p["t"])
	a._log(a.msg)
	a.sounds.append("petition")
	return true


## Called every sim second with all towns.
static func second(towns: Array, rng: RandomNumberGenerator) -> void:
	Military.register(towns)
	for c in towns:
		Military.econ(c)
	for i in towns.size():
		for j in range(i + 1, towns.size()):
			var a: City = towns[i]
			var b: City = towns[j]
			if a.derelict or b.derelict:
				continue  # an empty town has no diplomacy
			for pair in [[a, b], [b, a]]:
				var x: City = pair[0]
				var y: City = pair[1]
				var t := treaty(x, y)
				var target := x.temper
				target += {"": 0.0, "pact": 0.4, "alliance": 0.7, "vassal": 0.3, "embargo": -0.8, "war": -0.9}[t]
				var flow: float = float(x.imports["power"]) + float(x.imports["water"]) + float(y.imports["power"]) + float(y.imports["water"])
				target += minf(0.3, flow * 0.02)
				if mil(y) > mil(x) + 0.5:
					target -= 0.2  # fear
				if y.pop > x.pop * 2 and x.pop > 0:
					target -= 0.1  # envy
				target -= 0.3 * minf(_tension(x, y, t), 1.0)
				x.rel[y.town_name] = move_toward(rel(x, y), clampf(target, -1.0, 1.0), 0.003)
			if treaty(a, b) == "war":
				Military.fight(a, b)
			_tribute(a, b)
			_tribute(b, a)
			a.dipl_t -= 1.0
			if a.dipl_t > 0.0:
				continue
			a.dipl_t = rng.randf_range(45.0, 90.0)
			_event(a, b, rng)


## Border tension of `x` towards `y`, updated one second: grows between linked towns without a treaty (faster for ambitious, stronger towns), fades otherwise.
static func _tension(x: City, y: City, t: String) -> float:
	var v := float(x.tension.get(y.town_name, 0.0))
	if t == "" and linked(x, y):
		v += TENSION_RATE * (0.5 + ambition(x)) * (1.5 if strength(x) > strength(y) + 0.2 else 0.6)
	else:
		v = maxf(v - 0.002, 0.0)
	x.tension[y.town_name] = v
	return v


## The winner takes tribute and may annex a strip of the loser's land; the war ends.
static func surrender(w: City, l: City) -> void:
	var goal := String(w.war_goal.get(l.town_name, "land"))
	var pay := minf(l.coins * (0.3 if goal == "land" else 0.5), 300.0 if goal == "land" else 600.0) if l.coins > 0.0 else 0.0
	l.coins -= pay
	w.coins += pay
	if goal == "total":
		vassalize(w, l)
	else:
		sign_treaty(w, l, "")
	l.occ[w.town_name] = 0.0
	var k := side(w, l)
	var took := ""
	if goal == "land" and k >= 0 and w.can_expand(k) and l.cede((k + 2) % 4):
		w.expand(k, true)
		took = " %s annexes a strip of its land." % w.town_name
	w.rep = clampf(w.rep + 0.1, -0.3, 0.3)  # victory rallies voters
	l.rep = clampf(l.rep - 0.1, -0.3, 0.3)
	_say(w, l, "%s surrenders to %s and pays $%d.%s %s" % [l.town_name, w.town_name, int(pay), took, ("It is now a vassal." if goal == "total" else "The war is over.")])


## A vassal pays its overlord a fixed share of its positive income every second.
static func _tribute(v: City, o: City) -> void:
	if v.liege != o.town_name or treaty(v, o) != "vassal":
		return
	var pay := maxf(v.income, 0.0) * VASSAL_SHARE
	v.coins -= pay
	o.coins += pay


## `w` takes `l` as a vassal: it keeps its land, coins and buildings, pays a share of its income and cannot declare war.
static func vassalize(w: City, l: City) -> void:
	sign_treaty(w, l, "vassal")
	l.liege = w.town_name


static func _event(a: City, b: City, rng: RandomNumberGenerator) -> void:
	var r := avg(a, b)
	var t := treaty(a, b)
	if t == "war":
		return
	if a.pop < 12 or b.pop < 12:
		return
	for pair in [[a, b], [b, a]]:
		var x: City = pair[0]
		var y: City = pair[1]
		if not x.human and x.liege == "" and t != "pact" and t != "alliance" and t != "vassal" and float(x.tension.get(y.town_name, 0.0)) >= 1.0 and ready(x) and strength(x) > strength(y) and rng.randf() < 0.12 * ambition(x):
			declare(x, y, pick_goal(x, y), "border tension")
			return
	var human: City = a if a.human else (b if b.human else null)
	var other: City = b if human == a else a
	if r > 0.1 and rng.randf() < 0.7:
		match rng.randi() % 3:
			0:
				a.coins += 40.0
				b.coins += 40.0
				_shift(a, b, 0.06, 0.06)
				_say(a, b, "%s and %s hold a joint festival: +$40 each." % [a.town_name, b.town_name])
			1:
				a.trigger("parade")
				b.trigger("parade")
				_shift(a, b, 0.05, 0.05)
				_say(a, b, "A cultural exchange between %s and %s draws crowds." % [a.town_name, b.town_name])
			2:
				var rich: City = a if a.coins > b.coins else b
				var poor: City = b if rich == a else a
				if rich.coins > 200.0 and poor.coins < rich.coins * 0.6:
					rich.coins -= 60.0
					poor.coins += 60.0
					_shift(a, b, 0.05, 0.05)
					_say(a, b, "%s sends $60 of aid to %s." % [rich.town_name, poor.town_name])
		if human != null and t == "" and r > 0.35 and rng.randf() < 0.6:
			_offer(human, other, "offer", {"t": "%s proposes a trade pact" % other.town_name, "txt": "%s likes what it sees. A trade pact boosts power and water imports and commuting by 25%%. No cost to you." % other.town_name, "treaty": "pact", "days": 0})
		return
	if r >= -0.15 and r <= 0.1 and rng.randf() < 0.5:
		a.coins += 20.0
		b.coins += 20.0
		_shift(a, b, 0.04, 0.04)
		_say(a, b, "A trade fair brings merchants from %s and %s together: +$20 each." % [a.town_name, b.town_name])
		return
	if r < -0.15 and t != "embargo":
		var aggressor: City = a if rel(a, b) < rel(b, a) else b
		var victim: City = b if aggressor == a else a
		if r < -0.7 and not aggressor.human and ready(aggressor) and mil(aggressor) > mil(victim) + 0.4 and rng.randf() < 0.4:
			declare(aggressor, victim, pick_goal(aggressor, victim), "relations collapsed")
			return
		match rng.randi() % 4:
			0:
				_shift(a, b, -0.06, -0.06)
				_say(a, b, "A diplomatic spat between %s and %s." % [a.town_name, b.town_name])
			1:
				victim.trigger("crime_wave")
				_shift(a, b, -0.04, -0.04)
				_say(a, b, "Smugglers from %s flood %s with contraband." % [aggressor.town_name, victim.town_name])
			2:
				victim.trigger("border_incident")
				_shift(a, b, -0.05, -0.05)
			3:
				if r < -0.55 and mil(aggressor) >= mil(victim) - 0.3:
					if victim.human and rng.randf() < 0.6:
						var amt := minf(150.0, maxf(victim.coins * 0.3, 40.0))
						_offer(victim, aggressor, "demand", {"t": "%s demands tribute" % aggressor.town_name, "txt": "%s wants $%d to keep the peace. Refuse and its raiders will hit your border (strong defence softens that)." % [aggressor.town_name, int(amt)], "amount": amt, "days": 0})
					else:
						_raid(aggressor, victim)
						_shift(a, b, -0.08, -0.08)
				else:
					victim.trigger("water_main")
					_say(a, b, "%s diverts the river. %s's water supply suffers." % [aggressor.town_name, victim.town_name])
