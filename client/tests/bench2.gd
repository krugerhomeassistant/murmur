extends SceneTree
# Per-function cost on a grown town.
func _init() -> void:
	var c := City.new(Signals.new())
	c.seed_start()
	for i in 5000:
		c.sig.tick(0.25); c.tick(0.25)
	print("pop=%d day=%d" % [c.pop, c.day])
	for f in ["_scan","_crime","_land","_tribes","_collect_mods","_sickness","_traffic","_grow","_planner","_net","_sync_buses","_civics","_milestones","_unlocks","_second"]:
		var t0 := Time.get_ticks_usec()
		for i in 20:
			c.call(f)
		print("%s %.0fus" % [f, (Time.get_ticks_usec() - t0) / 20.0])
	var t1 := Time.get_ticks_usec()
	for i in 200:
		c._move(0.25)
	print("_move %.0fus" % [(Time.get_ticks_usec() - t1) / 200.0])
	quit()
