class_name Victory
extends RefCounted
## The end goal (docs/DOMINATION_DESIGN.md, docs/wiki/victory.md). Towns belong to a *side* (all towns of one human or
## multiplayer owner, or a single planner town). A side wins the moment the map is in its state (no timers):
##   conquest   : it holds CONQUEST_SHARE of all claimed land, or is the only side left,
##   hegemony   : its score is at least LEAD_RATIO times the next side's while its land plus its allies' land is at least ALLY_SHARE.
## The check runs once per sim second on the host (`second`), the result rides in every snapshot (`brief`).
## A win does not stop the game (sandbox): the standings keep updating.
## Pure rules, no scene: tests use it directly. Vassals count as allied land; culture joins the score.

const CONQUEST_SHARE := 0.7
const ALLY_SHARE := 0.4
const LEAD_RATIO := 1.5  # hegemony needs a clear lead, so a fresh alliance cannot win on the first second
const LAND_SCORE := 100.0  # claimed tiles per score point
const TRADE_SCORE := 50.0  # units exported per score point
const CULTURE_SCORE := 0.4  # score per citizen at full culture and education coverage: the peaceful route

var winner := ""  # side key, "" while undecided
var winner_name := ""
var route := ""  # "conquest", "last" or "hegemony"
var clock := 0.0  # sim seconds
var seen := 1  # most sides alive at once; no win is possible before there are two
var rows: Array = []  # standings, best score first: {side, name, towns, land, allied, score, con, heg}
var fresh := false  # set when a win has just been decided; the game reads and clears it


## The side a town plays for: a multiplayer owner, "human" for offline player towns, otherwise the town on its own.
static func side(t: City) -> String:
	if t.owner != 0:
		return "o%d" % t.owner
	return "human" if t.human else t.town_name


static func land(t: City) -> int:
	return t.terr.get_area()


## Culture points: people who are cultured and schooled. Free schooling (policy) counts 20% more.
static func culture(t: City) -> float:
	var c := float(t.pop) * (0.6 * float(t.cov.get("culture", 0.0)) + 0.4 * float(t.cov.get("edu", 0.0))) * CULTURE_SCORE
	return c * (1.2 if t.policies.get("free_school", false) else 1.0)


static func score(t: City) -> float:
	return float(t.pop) + float(land(t)) / LAND_SCORE + t.exported / TRADE_SCORE + culture(t)


## One second of the race. `towns` is everyone in the world.
func second(towns: Array[City]) -> void:
	clock += 1.0
	var sides := {}
	var total := 0.0
	for t in towns:
		if t.over != "":
			continue
		var k := side(t)
		if not sides.has(k):
			sides[k] = {"side": k, "name": t.town_name, "towns": 0, "land": 0.0, "allied": 0.0, "score": 0.0, "cul": 0.0, "list": []}
		var s: Dictionary = sides[k]
		s["towns"] = int(s["towns"]) + 1
		s["land"] = float(s["land"]) + land(t)
		s["score"] = float(s["score"]) + score(t)
		s["cul"] = float(s["cul"]) + culture(t)
		(s["list"] as Array).append(t)
		total += land(t)
	seen = maxi(seen, sides.size())
	for k in sides:
		var s: Dictionary = sides[k]
		var allied: float = s["land"]
		for t in towns:
			if t.over == "" and side(t) != k:
				for mine: City in s["list"]:
					if Diplo.treaty(mine, t) in ["alliance", "vassal"]:
						allied += land(t)
						break
		s["allied"] = allied / maxf(total, 1.0)
		s["land"] = float(s["land"]) / maxf(total, 1.0)
	var list: Array = sides.values()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	rows = []
	for i in list.size():
		var s: Dictionary = list[i]
		var k: String = s["side"]
		var next := float((list[i + 1] as Dictionary)["score"]) if i + 1 < list.size() else 0.0
		var lead: bool = i == 0 and float(s["score"]) >= LEAD_RATIO * next
		var con := minf(float(s["land"]) / CONQUEST_SHARE, 1.0)  # progress bars only: the rule itself is a state
		var heg := minf(float(s["allied"]) / ALLY_SHARE, 1.0) if lead else 0.0
		rows.append({"side": k, "name": s["name"], "towns": s["towns"], "land": s["land"], "allied": s["allied"], "score": s["score"], "cul": s["cul"], "con": con, "heg": heg})
		if winner != "" or seen < 2:
			continue
		if list.size() == 1:
			_win(k, s["name"], "last")
		elif float(s["land"]) >= CONQUEST_SHARE:
			_win(k, s["name"], "conquest")
		elif heg >= 1.0:
			_win(k, s["name"], "hegemony")


func _win(k: String, nm: String, how: String) -> void:
	winner = k
	winner_name = nm
	route = how
	fresh = true


## One line for the headline and the game-over panel.
func describe() -> String:
	match route:
		"conquest":
			return "%s wins by conquest: %d%% of the land is theirs." % [winner_name, int(CONQUEST_SHARE * 100.0)]
		"hegemony":
			return "%s wins by hegemony: the clear top score with %d%% of the land allied." % [winner_name, int(ALLY_SHARE * 100.0)]
		"last":
			return "%s wins: no other side is left." % winner_name
	return ""


## Snapshot and save state (the same dictionary; `apply` sanitises it because snapshots come from a possibly hostile host).
func brief() -> Dictionary:
	return {"w": winner, "wn": winner_name, "r": route, "clock": clock, "seen": seen, "rows": rows.duplicate(true)}


func apply(d: Dictionary) -> void:
	winner = str(d.get("w", "")).left(40)
	winner_name = str(d.get("wn", "")).left(40)
	route = str(d.get("r", "")) if str(d.get("r", "")) in ["conquest", "hegemony", "last"] else ""
	clock = clampf(float(d.get("clock", 0.0)), 0.0, 1.0e9)
	seen = clampi(int(d.get("seen", 1)), 1, 1000)
	rows = []
	var rs: Variant = d.get("rows", [])
	if rs is Array:
		for r: Variant in (rs as Array).slice(0, 64):
			if r is Dictionary:
				var rd := r as Dictionary
				rows.append({"side": str(rd.get("side", "")).left(40), "name": str(rd.get("name", "")).left(40), "towns": clampi(int(rd.get("towns", 0)), 0, 1000),
					"land": clampf(float(rd.get("land", 0.0)), 0.0, 1.0), "allied": clampf(float(rd.get("allied", 0.0)), 0.0, 1.0), "score": clampf(float(rd.get("score", 0.0)), 0.0, 1.0e9), "cul": clampf(float(rd.get("cul", 0.0)), 0.0, 1.0e9),
					"con": clampf(float(rd.get("con", 0.0)), 0.0, 1.0), "heg": clampf(float(rd.get("heg", 0.0)), 0.0, 1.0)})


