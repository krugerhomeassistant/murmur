extends SceneTree
## Skill tree: points from knowledge, nodes need a connected node and their age, effects apply through the modifiers, planner towns choose by temper, saves keep the tree.


func _init() -> void:
	var ts: Array[City] = []
	var t := City.new(Signals.new())
	t.seed_start()
	t.human = true
	ts.append(t)
	Ages.set_age(t, 0)
	t.pts = 100000.0
	var locked: bool = Research.block(t, Research.id(0, 1)) != "" and not Research.pick(t, Research.id(0, 1)) and Cmd.run(ts, t, "node", [Research.id(0, 1)]) == null
	var first: bool = Cmd.run(ts, t, "node", [Research.id(2, 0)]) == true
	var twice: bool = not Research.pick(t, Research.id(2, 0))
	var early: bool = not Research.pick(t, Research.id(2, 1)) and Research.block(t, Research.id(2, 1)).begins_with("needs the")
	Ages.set_age(t, 4)
	t.pts = 100000.0
	t.pop = 500
	var base := Ages.rate(t)
	var chain: bool = Research.pick(t, Research.id(2, 1)) and Research.pick(t, Research.id(2, 2))
	var side: bool = Research.pick(t, Research.id(3, 1)) and Research.pick(t, Research.id(1, 1))  # a neighbouring branch opens its next tier too
	var applied: bool = Ages.rate(t) > base * 1.1
	var poor: bool = (func() -> bool:
		t.pts = 10.0
		return not Research.pick(t, Research.id(0, 0)) and Research.block(t, Research.id(0, 0)) == "needs 300 points").call()
	var back := City.new(Signals.new())
	back.from_dict(t.to_dict())
	var saved: bool = back.tree == t.tree and absf(back.pts - t.pts) < 0.01
	var picks := []
	for n in 2:
		var ai := City.new(Signals.new())
		ai.seed_start()
		ai.town_name = "Auria"
		Ages.set_age(ai, Ages.LAST)
		ai.pts = 20000.0
		for k in 12:
			Research.auto(ai)
		picks.append(ai.tree)
	var auto_ok: bool = picks[0].size() >= 6 and picks[0] == picks[1]
	var tv := TreeView.new()
	tv.size = Vector2(1280, 720)
	var seen := {}
	var hit := true
	for i in Research.BRANCHES.size() * Research.TIERS:
		seen[tv.pos(i).round()] = true
		hit = hit and tv._node_at(tv.pos(i)) == i and Rect2(Vector2.ZERO, tv.size).has_point(tv.pos(i))
	var view: bool = hit and seen.size() == Research.BRANCHES.size() * Research.TIERS
	var ok: bool = view and locked and first and twice and early and chain and side and applied and poor and saved and auto_ok
	print("RESEARCH_OK" if ok else "RESEARCH_FAIL view=%s locked=%s first=%s twice=%s early=%s chain=%s side=%s applied=%s poor=%s saved=%s auto=%s" % [view, locked, first, twice, early, chain, side, applied, poor, saved, auto_ok])
	quit(0 if ok else 1)
