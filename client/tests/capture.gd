extends SceneTree
## Dead towns are up for grabs: a town with nobody left becomes derelict, troops tear down its town hall and hold it while a new one
## is built, a rival arriving in that window contests it (and breaks alliances), and the winner gets the town.


func _town(sig: Signals, nm: String, gx: int) -> City:
	var t := City.new(sig)
	t.town_name = nm
	t.gpos = Vector2i(gx, 0)
	t.seed_start()
	t.human = false
	t.next_fire = 9999.0
	t.ev_t = 9999.0
	return t


func _troops(t: City, n: int) -> void:
	t.army.clear()
	for i in n:
		t.army.append(Military._unit("spear"))


func _init() -> void:
	var sig := Signals.new()
	var a := _town(sig, "A", 0)
	var b := _town(sig, "B", 1)
	var c := _town(sig, "C", 2)
	var towns: Array[City] = [a, b, c]
	for x in towns:
		for y in towns:
			if x != y:
				x.partners.append(y)
	var ok := true
	# a town that loses everyone is abandoned
	b.peak = 30.0
	for i in 20:
		b.citizens.clear()
		b.pop = 0
		b.mood = 0.1
		b.tick(1.0)
	if not b.derelict or b.over == "":
		ok = false
		print("FAIL not abandoned")
	# troops march, tear down the hall, hold the ground while a new one is built
	_troops(a, 20)
	if not Capture.send(a, b, 10) or a.army.size() != 10 or Capture.send(a, b, 5):
		ok = false
		print("FAIL send / cooldown")
	for i in 400:
		Capture.second(towns)
	if b.derelict or b.over != "" or b.pop < 1 or Victory.side(b) != Victory.side(a) or b.army.size() < 5:
		ok = false
		print("FAIL capture: derelict %s over '%s' pop %d side %s army %d" % [b.derelict, b.over, b.pop, Victory.side(b), b.army.size()])
	# a rival in the building window contests it: war, and no claim for either until one side is left
	var d := _town(sig, "D", 1)
	d.derelict = true
	d.over = "empty"
	d.gpos = Vector2i(1, 1)
	towns.append(d)
	_troops(a, 30)
	a.cap_cd = 0.0
	_troops(c, 30)
	Diplo.sign_treaty(a, c, "alliance")
	Capture.send(a, d, 15)
	for i in 100:
		Capture.second(towns)
	var mid := d.claim_t
	Capture.send(c, d, 15)
	for i in 80:
		Capture.second(towns)
	if Diplo.treaty(a, c) != "war":
		ok = false
		print("FAIL no war between the claimants: %s" % Diplo.treaty(a, c))
	if not d.derelict or d.claim_t > mid + 75.0:  # the build paused while both sides stood there
		ok = false
		print("FAIL claim went on while contested: %s %s" % [d.claim_t, mid])
	# save round trip keeps the claim state
	var d2 := City.new(Signals.new())
	d2.from_dict(d.to_dict())
	if d2.derelict != d.derelict or d2.garrison.size() != d.garrison.size():
		ok = false
		print("FAIL save")
	print("CAPTURE_OK" if ok else "CAPTURE_FAIL")
	quit(0 if ok else 1)
