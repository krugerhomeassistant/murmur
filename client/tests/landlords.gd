extends SceneTree
## Rent goes to the best-off quarter of households (conserved); the savings of the well-off are taxed into the treasury.
func _init() -> void:
	var errs: Array[String] = []
	var c := City.new(Signals.new())
	c.seed_start()
	c.next_fire = 9999.0
	c.ev_t = 9999.0
	for i in 600:
		c.tick(0.1)
	if c.citizens.size() < 8:
		errs.append("need residents (%d)" % c.citizens.size())
	else:
		for k in c.citizens.size():
			c.citizens[k].wealth = 400.0 if k % 4 == 0 else 20.0
		c._households()
		var h: Dictionary = c.hh
		if float(h["rent"]) <= 0.0 or absf(float(h["rent"]) - float(h["rent_got"])) > 1e-6:
			errs.append("rent should be collected and fully paid out: %s" % str(h))
		if c.hh_tax <= 0.0:
			errs.append("rich savings should be taxed (%f)" % c.hh_tax)
		var t0 := c.hh_tax
		c.tax_r = 0.0
		for k in c.citizens.size():
			c.citizens[k].wealth = 400.0 if k % 4 == 0 else 20.0
		c._households()
		if c.hh_tax >= t0:
			errs.append("a zero residential rate should collect less savings tax")
	print("LANDLORDS_OK" if errs.is_empty() else "LANDLORDS_FAIL " + str(errs))
	quit()
