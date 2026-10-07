extends SceneTree
# Cached _net must equal a from-scratch solve after the layout changes.
func _init() -> void:
	var c := City.new(Signals.new())
	c.seed_start()
	for i in 4000:
		c.sig.tick(0.25); c.tick(0.25)
	for m in City.NETS:
		var v1: PackedFloat32Array = c.net_val[m].duplicate()
		var s1: float = c.net_sup[m]
		c.net_cache.clear()
		c._net()
		assert(c.net_val[m] == v1 and is_equal_approx(s1, float(c.net_sup[m])), "net cache drift " + m)
	print("NETCACHE_OK pop=", c.pop)
	quit()
