extends SceneTree
# Ages: buildings and units are gated by age, knowledge moves a town up, the classic start (Modern) opens everything.
const T = Catalog.Id

func _init() -> void:
	var ok := true
	var sig := Signals.new()
	var c := City.new(sig)
	c.seed_start()
	c.peak = 10000.0  # population never blocks here: only the age does
	if c.age != Ages.LAST:
		ok = false
		print("FAIL default age")
	for id in Catalog.DEFS:
		if not c.unlocked(id):
			ok = false
			print("FAIL modern town cannot build %d" % id)
	Ages.set_age(c, 0)
	if c.unlocked(T.COAL) or c.unlocked(T.UNIVERSITY) or not c.unlocked(T.RES) or not c.unlocked(T.FARM):
		ok = false
		print("FAIL ancient gating")
	if c.lock_text(T.COAL) != "Industrial age" or c.lock_text(T.RES) != "":
		ok = false
		print("FAIL lock_text: %s" % c.lock_text(T.COAL))
	# a town with no people learns nothing; a bigger, schooled one learns faster
	c.pop = 0
	var base := Ages.rate(c)
	c.pop = 200
	var r0 := Ages.rate(c)
	c.cov["edu"] = 1.0
	if not (base == 0.0 and r0 > 0.0 and Ages.rate(c) > r0):
		ok = false
		print("FAIL rate %s %s %s" % [base, r0, Ages.rate(c)])
	# knowledge alone is not enough: the town also needs the people
	c.peak = 5.0
	c.know = float(Ages.KNOW[1]) + 1.0
	if Ages.ready(c) or Ages.second(c) != -1 or c.age != 0:
		ok = false
		print("FAIL advanced without the population")
	c.peak = 100.0
	c.coins = 0.0
	c.mood = 0.8
	if Ages.ready(c):
		ok = false
		print("FAIL advanced without the treasury")
	c.coins = 5000.0
	c.mood = 0.1
	if Ages.ready(c):
		ok = false
		print("FAIL advanced while unhappy")
	c.mood = 0.8
	var up := Ages.second(c)
	if up != 1 or c.age != 1:
		ok = false
		print("FAIL did not advance: %d" % up)
	# units follow the age
	if Ages.unit("inf") != 2 or Ages.unit("jet") != 3 or c.age >= Ages.unit("inf"):
		ok = false
		print("FAIL unit ages")
	# the command and the end of the ladder
	if not Cmd.run([c], c, "set_age", [Ages.LAST]) or c.age != Ages.LAST or Ages.second(c) != -1:
		ok = false
		print("FAIL set_age command")
	if Cmd.run([c], c, "set_age", ["x"]):
		ok = false
		print("FAIL set_age accepted junk")
	# a save from before ages keeps the classic start
	var d := c.to_dict()
	var c2 := City.new(sig)
	d.erase("age")
	c2.from_dict(d)
	if c2.age != Ages.LAST:
		ok = false
		print("FAIL old save age %d" % c2.age)
	print("AGES_OK" if ok else "AGES_FAIL")
	quit(0 if ok else 1)
