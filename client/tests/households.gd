extends SceneTree
## Household finances: savings accrue, upgrades need savings, price surges squeeze households until wages catch up, payments help.
const T = Catalog.Id

func _town(sig: Signals) -> City:
	var c := City.new(sig)
	c.seed_start()
	c.next_fire = 9999.0
	c.ev_t = 9999.0
	c.auto_mode = 2
	c.coins = 3000.0
	return c

func _run(sig: Signals, c: City, secs: int) -> void:
	for i in secs * 10:
		sig.tick(0.1)
		c.tick(0.1)

func _init() -> void:
	var errs: Array[String] = []
	var sig := Signals.new()
	var c := _town(sig)
	_run(sig, c, 600)
	if c.pop < 20:
		errs.append("town did not grow (pop %d)" % c.pop)
	var employed_w := 0.0
	var n := 0
	for ct in c.citizens:
		if ct.work >= 0:
			employed_w += ct.wealth
			n += 1
	if n > 0 and employed_w / n < 20.0:
		errs.append("employed households should hold savings (avg %.1f)" % (employed_w / n))
	# upgrades need savings
	var poor := _town(Signals.new())
	_run(poor.sig, poor, 120)
	for ct in poor.citizens:
		ct.wealth = 0.0
	poor.hh["avg"] = 0.0
	poor._households()
	var before := {}
	for i in poor.zones:
		before[i] = poor.lvl[i]
	for k in 200:
		for ct in poor.citizens:
			ct.wealth = 0.0
		poor._grow()
	var homes_up := 0
	for i in poor.zones:
		if int(Catalog.DEFS[poor.grid[i]].get("home", 0)) > 0 and poor.lvl[i] > int(before.get(i, 9)) and poor.home_w.has(i):
			homes_up += 1
	if homes_up > 0:
		errs.append("penniless residents must not upgrade their homes (%d did)" % homes_up)
	# price surge: households squeezed, wages catch up later
	var sig2 := Signals.new()
	var t2 := _town(sig2)
	_run(sig2, t2, 400)
	var broke0 := t2.hardship
	sig2.mk.shock_by({"food": 2.5, "goods": 2.5})
	_run(sig2, t2, 120)
	var squeezed := float(t2.hh["real"])
	if t2.cpi < 1.2:
		errs.append("a price shock should lift the cost-of-living index (%.2f)" % t2.cpi)
	if squeezed > 0.95:
		errs.append("real wages should fall during a surge (%.2f)" % squeezed)
	_run(sig2, t2, 1200)
	if t2.wage_ix <= 1.0 and t2.cpi > 1.1:
		errs.append("wages should follow prices up")
	# payments keep broke households afloat: same town twice, only the policy differs
	var base := _town(Signals.new())
	_run(base.sig, base, 120)
	for ct in base.citizens:
		ct.wealth = 0.0
		ct.work = -1  # nobody earns: only the payments can help
	var snap := base.to_dict()
	var plain := _town(Signals.new())
	plain.from_dict(snap)
	var paid := _town(Signals.new())
	paid.from_dict(snap)
	paid.set_policy("cost_support", true)
	for i in 20:
		plain._households()
		paid._households()
	var w_plain := 0.0
	var w_paid := 0.0
	for ct in plain.citizens:
		w_plain += ct.wealth
	for ct in paid.citizens:
		w_paid += ct.wealth
	if plain.citizens.size() > 3 and w_paid <= w_plain:
		errs.append("cost-of-living payments should leave households with more savings (%.1f vs %.1f)" % [w_paid, w_plain])
	# save round trip
	var d := t2.to_dict()
	var r := _town(Signals.new())
	r.from_dict(d)
	if r.citizens.size() != t2.citizens.size() or absf(r.citizens[0].wealth - t2.citizens[0].wealth) > 0.2 or absf(r.wage_ix - t2.wage_ix) > 0.001:
		errs.append("household save/load round trip")
	if errs.is_empty():
		print("HOUSEHOLDS_OK pop=%d avg=$%d broke=%d%% cpi=%.2f wage=%.2f" % [t2.pop, int(t2.hh["avg"]), int(t2.hardship * 100.0), t2.cpi, t2.wage_ix])
	else:
		print("HOUSEHOLDS_FAIL ", errs)
	quit()
