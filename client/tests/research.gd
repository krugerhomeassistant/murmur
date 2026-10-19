extends SceneTree
## Research choices: one tech per reached age, applied through the modifiers, picked once, chosen by planner towns on their own.


func _init() -> void:
	var ts: Array[City] = []
	var t := City.new(Signals.new())
	t.seed_start()
	t.human = true
	ts.append(t)
	Ages.set_age(t, 3)
	var pend: bool = Research.pending(t) == [0, 1, 2, 3]
	var future: bool = not Research.pick(t, 4, 0) and Cmd.run(ts, t, "tech", [4, 0]) == null
	t.pop = 500
	var base := Ages.rate(t)
	var cost0 := t.mod("build_cost_mult")
	var picked: bool = Cmd.run(ts, t, "tech", [1, 1]) == true and Research.pick(t, 3, 0)
	var twice: bool = not Research.pick(t, 1, 0)
	var applied: bool = Ages.rate(t) > base * 1.07 and t.mod("build_cost_mult") < cost0 and Research.pending(t) == [0, 2]
	var ai := City.new(Signals.new())
	ai.seed_start()
	ai.town_name = "Auria"
	Ages.set_age(ai, Ages.LAST)
	Research.auto(ai)
	var auto_ok: bool = Research.pending(ai).is_empty() and ai.tech == (func() -> Array:
		var a := City.new(Signals.new())
		a.town_name = "Auria"
		Ages.set_age(a, Ages.LAST)
		Research.auto(a)
		return a.tech).call()
	var ok: bool = pend and future and picked and twice and applied and auto_ok
	print("RESEARCH_OK" if ok else "RESEARCH_FAIL pend=%s future=%s picked=%s twice=%s applied=%s auto=%s" % [pend, future, picked, twice, applied, auto_ok])
	quit(0 if ok else 1)
