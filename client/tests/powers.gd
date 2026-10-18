extends SceneTree
## God powers: belief is spent, cooldowns hold, refusals outside the sandbox, belief regenerates with mood.


func _init() -> void:
	var t := City.new(Signals.new())
	t.seed_start()
	var ts: Array[City] = [t]
	t.belief = 20.0
	Cmd.sandbox = false
	var off: bool = Cmd.run(ts, t, "power", ["bloom"]) == null and t.belief == 20.0
	Cmd.sandbox = true
	var cast: bool = Cmd.run(ts, t, "power", ["bloom"]) == true and is_equal_approx(t.belief, 10.0)
	var cooling: bool = Cmd.run(ts, t, "power", ["bloom"]) == false and is_equal_approx(t.belief, 10.0)
	var broke: bool = Cmd.run(ts, t, "power", ["quake"]) == false and is_equal_approx(t.belief, 10.0)
	var unknown: bool = Cmd.run(ts, t, "power", ["nope"]) == null
	t.belief = 50.0
	var z := City.Citizen.new()
	z.sick = 50.0
	t.citizens.append(z)
	var cured: bool = Cmd.run(ts, t, "power", ["cure"]) == true and z.sick == 0.0 and Cmd.run(ts, t, "power", ["cure"]) == false
	for i in 61:
		Powers.tick(t)
	var cd_ends: bool = not t.power_cd.has("bloom")
	var b0 := t.belief
	t.mood = 0.9
	Powers.tick(t)
	var gain_hi := t.belief - b0
	t.mood = 0.1
	var b1 := t.belief
	Powers.tick(t)
	var regen: bool = gain_hi > t.belief - b1 and t.belief > b1
	t.belief = 100.0
	var quake: bool = Cmd.run(ts, t, "power", ["quake"]) == true and t.belief < 100.0
	t.belief = 100.0
	t.mood = 0.5
	var bless: bool = Cmd.run(ts, t, "power", ["bless"]) == true and is_equal_approx(t.mood, 0.65)
	var other := City.new(Signals.new())
	t.partners.append(other)
	var incite: bool = Cmd.run(ts, t, "power", ["incite"]) == true and is_equal_approx(float(t.tension.get(other.town_name, 0.0)), 0.3)
	Cmd.sandbox = false
	var ok := off and cast and cooling and broke and unknown and cured and cd_ends and regen and quake and bless and incite
	print("POWERS_OK" if ok else "POWERS_FAIL off=%s cast=%s cooling=%s broke=%s unknown=%s cured=%s cd_ends=%s regen=%s quake=%s bless=%s incite=%s" % [off, cast, cooling, broke, unknown, cured, cd_ends, regen, quake, bless, incite])
	quit(0 if ok else 1)
