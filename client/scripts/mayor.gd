class_name Mayor
extends RefCounted
## The mayor's side of a town: petitions, promises, approval, elections, loans and advisors.
## Pure rules over a City (split out of city.gd); City keeps `answer`, `rally`, `take_loan` and `advisors` as its public API.

const T = Catalog.Id


static func met(c: City, n: Dictionary, have := 0) -> bool:
	if n.has("build"):
		return (c.bt.get(int(n["build"]), []) as Array).size() > have
	if n.has("cov"):
		return float(c.cov.get(n["cov"][0], 0.0)) >= float(n["cov"][1])
	if n.has("tax"):
		return float(c.get("tax_" + String(n["tax"][0]))) <= float(n["tax"][1]) + 0.001
	if n.has("policy"):
		return c.is_policy(n["policy"])
	if n.has("policy_off"):
		return not c.is_policy(n["policy_off"])
	if n.has("unemp"):
		return c.unemp <= float(n["unemp"])
	if n.has("event"):
		return c.is_active(n["event"])
	return false


static func open_ids(c: City) -> Dictionary:
	var o := {}
	for p in c.petitions + c.promises:
		o[String(p.get("id", ""))] = true
	return o


static func raise_petition(c: City) -> void:
	if not c.human or c.pop < 12 or c.petitions.size() >= 3:
		return
	var open := Mayor.open_ids(c)
	var opts: Array = []
	for p in Civics.PETITIONS:
		var id: String = p["id"]
		var n: Dictionary = p["need"]
		if open.has(id) or c.day - int(c.pet_recent.get(id, -99)) < 6 or c.pop < int(p.get("minpop", 15)):
			continue
		if float(c.tribe_share.get(p["tribe"], 0.0)) < 0.05 or c.crime < float(p.get("crime", 0.0)) or c.pollution < float(p.get("poll", 0.0)):
			continue
		if n.has("build"):
			if not c.unlocked(int(n["build"])) or (c.bt.get(int(n["build"]), []) as Array).size() >= 1 + c.pop / 100:
				continue
		elif Mayor.met(c, n):
			continue
		if n.has("event") and c.mood > 0.55:
			continue
		opts.append(p)
	if opts.is_empty():
		return
	var p: Dictionary = opts[c.rng.randi() % opts.size()].duplicate(true)
	p["kind"] = "petition"
	p["expires"] = c.day + 2
	c.pet_recent[p["id"]] = c.day
	c.petitions.append(p)
	c.pet_ver += 1
	c.msg = "Petition from the %s: %s" % [Catalog.TRIBES[p["tribe"]]["n"], p["t"]]
	c._log(c.msg)
	c.sounds.append("petition")


## Answers decision idx. yes = accept the petition / fund the rebuild.
static func answer(c: City, idx: int, yes: bool) -> void:
	if idx < 0 or idx >= c.petitions.size():
		return
	var p: Dictionary = c.petitions[idx]
	c.petitions.remove_at(idx)
	c.pet_ver += 1
	if p["kind"] == "offer" or p["kind"] == "demand":
		Diplo.resolve(c, p, yes)
		return
	if p["kind"] == "build":
		var id := int(p["bid"])
		var at := int(p["cell"])
		var d: Dictionary = Catalog.DEFS.get(id, {})
		var free: bool = at >= 0 and at < c.grid.size() and (c.lamp[at] == 0 and c.is_road(c.grid[at]) if id == T.LIGHT else c.grid[at] == T.EMPTY)
		if not yes or d.is_empty() or not free or c.coins < float(p["cost"]):
			c.vetoed[str(id)] = c.day + 10
			return
		if id == T.LIGHT:
			c.lamp[at] = 1
		else:
			c.grid[at] = id
		c.coins -= float(p["cost"])
		c.msg = "Planners built a %s." % String(d["n"]).to_lower()
		c._scan()
		return
	if p["kind"] == "recover":
		if yes and c.coins >= float(p["cost"]):
			c.disasters_survived += 1
			c.coins -= float(p["cost"])
			c._rebuild()
			c.rep += 0.04
			c._log("You funded the rebuild ($%d)." % int(p["cost"]))
			c.msg = "Crews rebuild the damaged blocks overnight."
		else:
			c.ruins.clear()
			c._log("The city will recover on its own.")
		return
	var tb: String = p["tribe"]
	if yes:
		p["deadline"] = c.day + int(p["days"])
		var n: Dictionary = p["need"]
		p["have"] = (c.bt.get(int(n["build"]), []) as Array).size() if n.has("build") else 0
		c.promises.append(p)
		c.favor[tb] = float(c.favor.get(tb, 0.0)) + 0.05
		c._log("You promised the %s: %s (by day %d)." % [Catalog.TRIBES[tb]["n"], Civics.need_text(n), p["deadline"]])
	else:
		c.favor[tb] = float(c.favor.get(tb, 0.0)) - 0.12
		c.rep -= 0.02
		c._log("You turned down the %s." % Catalog.TRIBES[tb]["n"])


static func civics(c: City) -> void:
	for p in c.promises.duplicate():
		var tb: String = p["tribe"]
		if Mayor.met(c, p["need"], int(p.get("have", 0))):
			c.promises.erase(p)
			c.kept += 1
			c.favor[tb] = float(c.favor.get(tb, 0.0)) + 0.2
			c.rep += 0.06
			c.msg = "Promise kept: %s. The %s cheer." % [p["t"], Catalog.TRIBES[tb]["n"]]
			c._log(c.msg)
			c.sounds.append("good")
			c.pet_ver += 1
		elif c.day > int(p["deadline"]):
			c.promises.erase(p)
			c.broken += 1
			c.favor[tb] = float(c.favor.get(tb, 0.0)) - 0.3
			c.rep -= 0.1
			c.msg = "Promise broken: %s. The %s are furious." % [p["t"], Catalog.TRIBES[tb]["n"]]
			c._log(c.msg)
			c.sounds.append("bad")
			c.pet_ver += 1
	for p in c.petitions.duplicate():
		if c.day > int(p["expires"]):
			Mayor.answer(c, c.petitions.find(p), false)
	c.pet_t -= 1.0
	if c.pet_t <= 0.0:
		c.pet_t = c.rng.randf_range(70.0, 130.0)
		Mayor.raise_petition(c)
	for k in c.favor:
		c.favor[k] = clampf(move_toward(float(c.favor[k]), 0.0, 0.0008), -0.4, 0.4)
	c.rep = clampf(move_toward(c.rep, 0.0, 0.0004), -0.3, 0.3)
	var op := 0.0
	for k in c.tribe_mood:
		op += float(c.tribe_share.get(k, 0.0)) * (float(c.tribe_mood[k]) - 0.5)
	var target := 0.35 + 0.5 * c.mood + 0.08 * clampf(c.income / 2.0, -1.0, 1.0) - (0.1 if c.coins < 0.0 else 0.0) - 0.1 * c.crime + 0.3 * op + c.rep
	if c.tax_r > 0.12:
		target -= (c.tax_r - 0.12) * 1.5
	target -= 0.04 * c.wars() + 0.012 * minf(c.war_battles(), 12.0)  # war weariness
	c.approval = clampf(move_toward(c.approval, target, 0.004), 0.0, 1.0)


static func rally(c: City) -> bool:
	if c.rally_used or c.coins < Civics.RALLY_COST or c.next_election - c.day > 7:
		return false
	c.coins -= Civics.RALLY_COST
	c.rally_used = true
	c.rep += 0.07
	c._log("Campaign rally in the square.")
	c.msg = "Your rally fills the square. Approval rises."
	return true


static func new_day(c: City) -> void:
	if c.next_election - c.day == 3:
		c.msg = "Election in 3 days. Polls put you at %d%%." % int(c.approval * 100.0)
		c._log(c.msg)
	if c.day < c.next_election or not c.human:
		return
	var vote := clampf(c.approval + c.rng.randf_range(-0.04, 0.04), 0.0, 1.0)
	c.last_vote = vote
	c.next_election += Civics.YEAR_DAYS
	c.rally_used = false
	if vote >= 0.5:
		c.elections_won += 1
		c.msg = "Re-elected with %d%% of the vote!" % int(vote * 100.0)
		c._log(c.msg)
		c.sounds.append("chime")
	else:
		c._log("Lost the election with %d%%." % int(vote * 100.0))
		c.over = "Voted out. You won only %d%% of the vote on day %d." % [int(vote * 100.0), c.day]


static func milestones(c: City) -> void:
	for ms in Civics.MILESTONES:
		if not c.done_ms.has(ms["id"]) and float(c.get(ms["stat"])) >= float(ms["v"]):
			c.done_ms[ms["id"]] = c.day
			c.coins += float(ms["reward"])
			c.msg = "Milestone: %s%s" % [ms["n"], ("  (+$%d)" % ms["reward"]) if int(ms["reward"]) > 0 else ""]
			c._log(c.msg)
			c.sounds.append("chime")


static func take_loan(c: City, k: int) -> bool:
	var L: Dictionary = Civics.LOANS[k]
	if c.loans.size() >= 3 or c.peak < float(L["minpop"]):
		return false
	var total := float(L["amt"]) * (1.0 + float(L["rate"]))
	c.loans.append({"n": L["n"], "left": total, "pay": total / (float(L["days"]) * City.DAY_SECS)})
	c.coins += float(L["amt"])
	c._log("Took a %s: $%d, repay $%d over %d days." % [String(L["n"]).to_lower(), L["amt"], int(total), L["days"]])
	return true


## Advisors: [name, advice, happy]
static func advisors(c: City) -> Array:
	var a: Array = []
	var t := "Income is %+.2f a second. Keep taxes near 10%% unless we need the money." % c.income
	if c.income < -0.2:
		t = "We're losing $%.2f a second. Raise taxes, end a policy or take a loan." % -c.income
	elif c.coins > 1500.0:
		t = "We're sitting on $%d. Spend it on services, or cut taxes to win votes." % int(c.coins)
	elif not c.loans.is_empty():
		var pay := 0.0
		for l in c.loans:
			pay += float(l["pay"])
		t = "We're repaying %d loan(s) at $%.2f a second. No new borrowing, please." % [c.loans.size(), pay]
	a.append(["Treasurer", t, c.income >= 0.0])
	t = "The streets are calm and the fire crews are bored."
	if c.burning > 0:
		t = "%d building(s) on fire! Fire stations within 7 tiles put fires out in seconds." % c.burning
	elif c.crime > 0.3:
		t = "Crime is at %d%%. Street lamps, police stations and courts in the red blocks (Crime overlay)." % int(c.crime * 100.0)
	elif float(c.cov["fire"]) < 0.6 and c.pop > 30:
		t = "Only %d%% of homes have fire cover. One spark and we lose a street." % int(float(c.cov["fire"]) * 100.0)
	a.append(["Police & fire chief", t, c.burning == 0 and c.crime <= 0.3])
	t = "Growth is steady. Demand: homes %+d, shops %+d, industry %+d." % [int(c.res_dem * 10), int(c.com_dem * 10), int(c.ind_dem * 10)]
	if c.congestion > 0.3:
		t = "Traffic is jammed (%d%%). Upgrade busy roads to avenues and add bus stops." % int(c.congestion * 100.0)
	elif c.avg_commute > 18.0:
		t = "Commutes average %d tiles. Zone jobs nearer homes, or add avenues." % int(c.avg_commute)
	elif c.pop - c.employed > 4:
		t = "%d people can't find work. Zone industry or offices." % (c.pop - c.employed)
	a.append(["City planner", t, c.congestion <= 0.3 and c.avg_commute <= 18.0])
	t = "People are healthy and fed."
	if c.sick_n > 0:
		t = "%d citizens are sick. Clinics and hospitals cure them faster and slow the spread." % c.sick_n
	elif c.pop >= 30 and float(c.flow.get("food_local", 1.0)) < 0.4:
		t = "We import most of our food. Farms plus a food mill would save money."
	else:
		for m in Catalog.METRICS:
			if c._need(m) > 0.3:
				t = "%s reaches only %d%% of homes. That is hurting mood." % [Catalog.METRICS[m]["n"], int(float(c.cov[m]) * 100.0)]
				break
	a.append(["Health & welfare", t, c.sick_n == 0])
	var dl := c.next_election - c.day
	t = "Election in %d days. We poll at %d%%." % [dl, int(c.approval * 100.0)]
	if c.approval < 0.5:
		t += " We'd lose today! Keep promises, lift mood%s." % (", hold a rally" if dl <= 7 and not c.rally_used else "")
	elif c.tax_r > 0.12:
		t += " Voters hate the household tax. Cut it."
	if not c.petitions.is_empty():
		t += " %d petition(s) await your answer." % c.petitions.size()
	a.append(["Campaign manager", t, c.approval >= 0.5])
	if c.wars() > 0:
		a.append(["General", "We are at war (%d x 20 s so far). Voters are tiring: mood and approval fall the longer it lasts. Barracks and bases train the infantry, tanks and jets that fight; radar posts allow jets. Keep the front or lose the border. Sue for peace after a minute." % int(c.war_battles()), false])
	return a
