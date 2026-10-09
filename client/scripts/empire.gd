class_name Empire
extends RefCounted
## Running several towns as one: who is on your side, a roll-up of their state, and moving money between them.
## Pure rules (no UI); `Cmd` calls these so the multiplayer host validates them like any other command.

const POOL_FLOOR := 150.0  ## shared treasury: no pooled town is left below this while another has plenty
const BULK := ["auto_mode", "auto_policy", "auto_expand", "train", "tax", "pool"]  # what "apply to all my towns" may change


## Same player: same peer in multiplayer; offline, all human-run towns (or all planner towns when spectating).
static func same_side(a: City, b: City) -> bool:
	return a.owner == b.owner and (a.owner != 0 or a.human == b.human)


static func mine(towns: Array[City], viewer: City) -> Array[City]:
	var r: Array[City] = []
	for t in towns:
		if t.over == "" and same_side(viewer, t):
			r.append(t)
	return r


## One row of the dashboard.
static func row(towns: Array[City], t: City) -> Dictionary:
	var flags: Array[String] = []
	var war := false
	for p in t.partners:
		if Diplo.treaty(t, p) == "war":
			war = true
	if t.over != "":
		flags.append("GAME OVER")
	if war:
		flags.append("AT WAR")
	if t.coins < 50.0 and t.income < 0.0:
		flags.append("broke")
	if t.mood < 0.3:
		flags.append("unrest")
	if t.over == "":
		for n in t.needs().slice(0, 2):
			flags.append(n)
	return {"name": t.town_name, "pop": t.pop, "coins": t.coins, "income": t.income, "mood": t.mood, "flags": flags, "war": war, "idx": towns.find(t)}


static func totals(list: Array[City]) -> Dictionary:
	var pop := 0
	var coins := 0.0
	var inc := 0.0
	for t in list:
		pop += t.pop
		coins += t.coins
		inc += t.income
	return {"towns": list.size(), "pop": pop, "coins": coins, "income": inc}


## Move `amount` coins from one town to another on the same side. Returns what moved (0 if refused).
static func send(from: City, to: City, amount: int) -> int:
	if from == to or not same_side(from, to) or amount <= 0 or from.over != "" or to.over != "":
		return 0
	var a := mini(amount, int(from.coins))
	if a <= 0:
		return 0
	from.coins -= a
	to.coins += a
	return a


## Even out the treasuries of `list`: towns above 3x the floor offer half of what exceeds 2x the floor, towns under the
## floor are topped up toward it in proportion to need. Never creates or destroys money. Returns the amount moved.
static func rebalance(list: Array[City], floor_: float) -> float:
	var offer := {}
	var pool := 0.0
	var short := {}
	var need := 0.0
	for t in list:
		if t.coins > floor_ * 3.0:
			offer[t] = (t.coins - floor_ * 2.0) * 0.5
			pool += offer[t]
		elif t.coins < floor_:
			short[t] = floor_ - t.coins
			need += short[t]
	var moved := minf(pool, need)
	if moved <= 0.0:
		return 0.0
	for t in offer:
		t.coins -= offer[t] * moved / pool
	for t in short:
		t.coins += moved * short[t] / need
	return moved


## Shared treasury: every few seconds the pooled towns of each side even out (see `rebalance`). Planner-run empires rely on it so a rich town feeds a broke one.
static func auto_pool(towns: Array[City]) -> void:
	var seen := {}
	for t in towns:
		if t.pool and t.over == "" and not seen.has(t):
			var list: Array[City] = []
			for o in mine(towns, t):
				seen[o] = true
				if o.pool:
					list.append(o)
			rebalance(list, POOL_FLOOR)
