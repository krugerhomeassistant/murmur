extends SceneTree
## The goods exchange: prices follow supply and demand, stay bounded, limit input purchases, survive save/load.
const T = Catalog.Id

func _run(m: Market, secs: int, offer: Dictionary, want: Dictionary, towns := 3) -> void:
	for s in secs:
		for t in towns:
			m.report(offer, want)
		for i in 10:
			m.tick(0.1)

func _init() -> void:
	var errs: Array[String] = []
	# glut: price falls, bounded below
	var m := Market.new()
	_run(m, 120, {"food": 6.0}, {"food": 1.0})
	if m.ratio("food") > 0.6 or m.ratio("food") < Market.LOW - 0.001:
		errs.append("glut should push food well below base but not under the floor: %.2f" % m.ratio("food"))
	# shortage: price rises, bounded above
	var n := Market.new()
	_run(n, 120, {}, {"goods": 5.0})
	if n.ratio("goods") < 1.15 or n.ratio("goods") > Market.HIGH + 0.001:
		errs.append("shortage should push goods price up but not past the ceiling: %.2f" % n.ratio("goods"))
	# balanced: stays near base
	var b := Market.new()
	_run(b, 120, {"ore": 2.0}, {"ore": 2.0})
	if absf(b.ratio("ore") - 1.0) > 0.1:
		errs.append("balanced trade should hold the base price: %.2f" % b.ratio("ore"))
	# unrelated goods do not move
	if absf(m.ratio("metal") - 1.0) > 0.05:
		errs.append("an untraded good should stay at base")
	# market signal scales prices
	var s := Market.new()
	for i in 600:
		s.tick(0.1, 1.3)
	if absf(s.ratio("crops") - 1.3) > 0.05:
		errs.append("the world market multiplier should lift prices")
	# purchases are limited by what is on offer
	var p := Market.new()
	_run(p, 5, {"crops": 1.0}, {}, 1)
	var got := p.take("crops", 50.0)
	if got > 1.0 + Market.WORLD + 0.01 or got <= 0.0:
		errs.append("take must be limited to the pool: %.2f" % got)
	if p.take("crops", 5.0) != 0.0 and p.take("crops", 5.0) > 0.0:
		errs.append("the pool must run dry")
	# save round trip and hostile input
	var r := Market.new()
	r.from_dict(m.to_dict())
	if absf(float(r.price["food"]) - float(m.price["food"])) > 0.001 or (r.hist["food"] as Array).size() != (m.hist["food"] as Array).size():
		errs.append("market save/load round trip")
	r.from_dict({"price": {"food": 1e9, "goods": -5.0}})
	if float(r.price["food"]) > Market.BASE["food"] * Market.HIGH * 1.5 + 0.01 or float(r.price["goods"]) < Market.BASE["goods"] * Market.LOW - 0.01:
		errs.append("hostile prices must be clamped")
	# candles: ten seconds make one, ranges hold, merging and stats agree, the tape names trades and events
	var cm := Market.new()
	_run(cm, 100, {"food": 1.0}, {"food": 6.0}, 3)
	var fc: Array = cm.candles["food"]
	if fc.size() < 8 or fc.size() > 10:
		errs.append("100 s should close about 10 candles, got %d" % fc.size())
	for c: Array in fc:
		if float(c[2]) > float(c[0]) + 0.0001 or float(c[1]) < float(c[3]) - 0.0001 or float(c[2]) > float(c[1]):
			errs.append("candle low/high must bound open and close: %s" % [c])
			break
	var mg: Array = cm.merged("food", 5)
	if mg.size() != fc.size() / 5 or absf(float((mg[0] as Array)[0]) - float((fc[fc.size() % 5] as Array)[0])) > 0.0001 or absf(float((mg[mg.size() - 1] as Array)[3]) - float((fc[fc.size() - 1] as Array)[3])) > 0.0001:
		errs.append("merged candles should span the same range")
	var st := Market.stats(fc)
	if float(st["chg"]) <= 0.0 or float(st["hi"]) < float(st["lo"]) or float(st["units"]) <= 0.0:
		errs.append("a shortage should show a rising price with volume: %s" % [st])
	var sm := Market.sma(fc, 3)
	if sm.size() != fc.size() or absf(sm[sm.size() - 1] - (float((fc[fc.size() - 3] as Array)[3]) + float((fc[fc.size() - 2] as Array)[3]) + float((fc[fc.size() - 1] as Array)[3])) / 3.0) > 0.0001:
		errs.append("sma(3) of the last candles")
	if cm.status("food") != "shortage" or cm.status("ore") != "balanced":
		errs.append("status should read shortage for food and balanced for ore")
	cm.shock_by({"food": 1.3})
	if not String((cm.tape[0] as Dictionary)["s"]).contains("food +30%"):
		errs.append("an event should land on the tape")
	for i in 60:
		cm.note("x%d" % i)
	if cm.tape.size() != Market.TAPE:
		errs.append("the tape is capped")
	var cr := Market.new()
	cr.from_dict(cm.to_dict())
	if (cr.candles["food"] as Array).size() != fc.size():
		errs.append("candles must survive a save round trip")
	cr.from_dict({"cd": {"food": [[1, 2], "junk", [-5.0, 1e30, 0, 1, 2, 3, 4]]}})
	if (cr.candles["food"] as Array).size() != 1 or float(((cr.candles["food"] as Array)[0] as Array)[0]) < 0.0:
		errs.append("hostile candles must be filtered")
	# trade between linked towns: goods flow from cheap to dear, blocked by embargo or a missing road
	var sg := Signals.new()
	var ta := City.new(sg)
	var tb := City.new(sg)
	ta.town_name = "A"
	tb.town_name = "B"
	ta.gpos = Vector2i(0, 0)
	tb.gpos = Vector2i(1, 0)
	ta.partners.append(tb)
	tb.partners.append(ta)
	ta.stock["food"] = 300.0
	ta.need_rate["food"] = 1.0
	ta.price_loc["food"] = 1.2
	tb.stock["food"] = 0.0
	tb.need_rate["food"] = 3.0
	tb.price_loc["food"] = 1.8
	Market.link_trade([ta, tb])
	if float(tb.stock["food"]) > 0.0:
		errs.append("unlinked towns must not trade")
	ta.gate[1] = 1
	tb.gate[3] = 1
	var ca := ta.coins
	var cb := tb.coins
	Market.link_trade([ta, tb])
	var moved := float(tb.stock["food"])
	if moved <= 0.0 or absf(float(ta.stock["food"]) - (300.0 - moved)) > 0.001:
		errs.append("linked towns should move food to the dear side (%.2f)" % moved)
	sg.mk.tick(10.0)
	if sg.mk.tape.is_empty() or not String((sg.mk.tape[0] as Dictionary)["s"]).contains("A to B"):
		errs.append("a link trade should show on the tape")
	if ta.coins <= ca or tb.coins >= cb:
		errs.append("the buyer pays, the seller earns")
	if (tb.coins - cb) + (ta.coins - ca) >= 0.0:
		errs.append("freight must be lost")
	Diplo.sign_treaty(ta, tb, "embargo")
	var before := float(tb.stock["food"])
	Market.link_trade([ta, tb])
	if float(tb.stock["food"]) != before:
		errs.append("an embargo must stop trade")
	# towns: a food-less region pays more for food than the base, and a mill buys crops from a farm town
	var sig := Signals.new()
	var ts: Array[City] = []
	for i in 3:
		var c := City.new(sig)
		c.seed_start()
		c.next_fire = 9999.0
		c.ev_t = 9999.0
		c.coins = 3000.0
		for o in ts:
			o.partners.append(c)
			c.partners.append(o)
		ts.append(c)
	for i in 3000:
		sig.tick(0.1)
		for c in ts:
			c.tick(0.1)
	var inflow := 0.0
	for c in ts:
		inflow += float(c.flow.get("food_need", 0.0))
	if inflow > 0.5 and sig.mk.ratio("food") < 1.0:
		errs.append("towns that cannot feed themselves should lift the food price (%.2f)" % sig.mk.ratio("food"))
	for k in Market.GOODS:
		if is_nan(float(sig.mk.price[k])) or float(sig.mk.price[k]) <= 0.0:
			errs.append("bad price for " + k)
	if errs.is_empty():
		print("MARKET_OK food x%.2f goods x%.2f" % [sig.mk.ratio("food"), sig.mk.ratio("goods")])
	else:
		print("MARKET_FAIL ", errs)
	quit()
