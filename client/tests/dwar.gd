extends SceneTree
# War drivers (D3): border tension builds between linked towns, an ambitious stronger AI town declares war with a goal,
# and the goal sets the occupation needed and what the winner takes.
func _pair() -> Array[City]:
	var sig := Signals.new()
	var ts: Array[City] = []
	for k in 2:
		var t := City.new(sig)
		t.town_name = "D%d" % k
		t.gpos = Vector2i(k, 0)
		t.pop = 30
		t.human = false
		ts.append(t)
	ts[0].partners.append(ts[1])
	ts[1].partners.append(ts[0])
	ts[0].gate[1] = 1  # a road reaches the shared border on both sides
	ts[1].gate[3] = 1
	return ts


func _init() -> void:
	var ts := _pair()
	var a := ts[0]
	var b := ts[1]
	assert(City.SAVE_KEYS.has("war_goal") and City.SAVE_KEYS.has("tension"), "war state must be saved")
	var amb := Diplo.ambition(a)
	assert(amb >= 0.0 and amb <= 1.0, "ambition out of range")
	# tension grows while linked without a treaty, fades under a pact
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 300:
		Diplo.second(ts, rng)
	var grown := float(a.tension.get(b.town_name, 0.0))
	assert(grown > 0.1, "no tension built: %f" % grown)
	Diplo.sign_treaty(a, b, "pact")
	for i in 300:
		Diplo.second(ts, rng)
	assert(float(a.tension.get(b.town_name, 0.0)) < grown, "a pact should ease tension")
	Diplo.sign_treaty(a, b, "")
	# a stronger AI town at full tension declares war with a goal; the weaker one does not
	for i in 12:
		a.army.append(Military._unit("inf"))
	a.tension[b.town_name] = 1.0
	b.tension[a.town_name] = 1.0
	assert(Diplo.mil(a) > Diplo.mil(b) + 0.2, "test setup: a must out-muscle b")
	for i in 60:
		if Diplo.treaty(a, b) == "war":
			break
		Diplo._event(a, b, rng)
	assert(Diplo.treaty(a, b) == "war", "no war at full tension")
	assert(String(a.war_goal.get(b.town_name, "")) in ["tribute", "land", "total"], "war has no goal")
	assert(String(b.war_goal.get(a.town_name, "")) == String(a.war_goal[b.town_name]), "both sides must know the goal")
	assert(float(a.tension[b.town_name]) == 0.0, "declaring resets tension")
	assert(Diplo.wars(ts).size() == 1 and Diplo.wars(ts)[0]["goal"] == a.war_goal[b.town_name], "war missing from standings")
	# the goal sets the occupation needed and the spoils
	assert(Diplo.OCC_NEED["tribute"] < Diplo.OCC_NEED["land"] and Diplo.OCC_NEED["land"] < Diplo.OCC_NEED["total"], "goal ladder broken")
	a.war_goal[b.town_name] = "tribute"
	assert(int(Diplo.occ_need(a, b)) == 15, "tribute occupation need")
	b.coins = 1000.0
	a.coins = 0.0
	var terr := a.terr
	Diplo.surrender(a, b)
	assert(Diplo.treaty(a, b) == "", "surrender ends the war")
	assert(absf(a.coins - 500.0) < 0.01 and a.terr == terr, "tribute war: half the treasury, no land (coins %f)" % a.coins)
	print("DWAR_OK")
	quit()
