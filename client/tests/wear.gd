extends SceneTree
## Maintenance: unpaid crews let wear build, which lowers production and mood; paid crews restore it.


func _init() -> void:
	var ok := true
	var c := City.new(Signals.new())
	c.seed_start()
	c.pop = 40
	c.coins = 5000.0
	for i in 300:
		c.tick(0.5)
	if c.wear > 0.01:
		ok = false
		print("FAIL funded town wears: %.2f" % c.wear)
	var lines := ""
	for l in c.budget_lines:
		lines += String(l[0])
	if lines.find("Maintenance") < 0:
		ok = false
		print("FAIL no Maintenance budget line")
	c.coins = -100.0
	c.income = -5.0
	for i in 200:
		c.coins = -100.0
		c.tick(0.5)
	var worn := c.wear
	if worn < 0.1:
		ok = false
		print("FAIL unpaid town did not wear: %.2f" % worn)
	c.coins = 5000.0
	for i in 200:
		c.tick(0.5)
	if c.wear >= worn:
		ok = false
		print("FAIL wear did not recover: %.2f -> %.2f" % [worn, c.wear])
	print("WEAR_OK wear=%.2f" % worn if ok else "WEAR_FAIL")
	quit(0 if ok else 1)
