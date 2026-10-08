extends SceneTree
## Dumps the static game data tables as JSON for scripts/gen_wiki.py (the generated wiki pages).
## Usage: godot --headless --path client -s tools/dump_wiki.gd -- <out.json>

func _conv(v):
	match typeof(v):
		TYPE_COLOR:
			return "#" + (v as Color).to_html(false)
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[_key(k)] = _conv(v[k])
			return d
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var a := []
			for x in v:
				a.append(_conv(x))
			return a
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [v.x, v.y]
	return v


func _key(k) -> String:
	# Catalog.Id values are plain ints; name them where the key is a building id.
	return str(k)


func _init() -> void:
	var ids := {}
	for n in Catalog.Id:
		ids[str(int(Catalog.Id[n]))] = n
	var out := {
		"ids": ids,
		"cats": Catalog.CATS,
		"defs": Catalog.DEFS,
		"metrics": Catalog.METRICS,
		"policies": Catalog.POLICIES,
		"tribes": Catalog.TRIBES,
		"events": WorldEvents.EVENTS,
		"event_cats": WorldEvents.CATS,
		"kinds": Military.KIND,
		"def_w": Military.DEF_W,
		"ranks": Military.RANKS,
		"rank_xp": Military.RANK_XP,
		"seasons": Civics.SEASONS,
		"petitions": Civics.PETITIONS,
		"milestones": Civics.MILESTONES,
		"city_ranks": Civics.RANKS,
		"loans": Civics.LOANS,
		"guide": Guide.STEPS,
		"diplo_costs": Diplo.COSTS,
		"consts": {
			"year_days": Civics.YEAR_DAYS, "rally_cost": Civics.RALLY_COST,
			"day_secs": City.DAY_SECS, "rate": City.RATE, "debt_limit": City.DEBT_LIMIT,
			"build_secs": City.BUILD_SECS, "grow_cost": City.GROW_COST, "bridge_x": City.BRIDGE_X,
			"walk": City.WALK, "plot_w": City.W, "plot_h": City.H, "start_w": City.START_W,
			"start_h": City.START_H, "expand": City.EXPAND, "army_max": Military.ARMY_MAX,
			"rank_dmg": Military.RANK_DMG, "rank_hp": Military.RANK_HP, "aggro": Military.AGGRO,
			"found_cost": 300.0, "found_step": 120.0, "explore": 10, "port": NetPlay.PORT,
			"max_players": NetPlay.MAX_PLAYERS, "market_low": Market.LOW, "market_high": Market.HIGH,
			"market_world": Market.WORLD, "market_sens": Market.SENS, "market_follow": Market.FOLLOW, "market_base": Market.BASE, "weather_penalty": City.WEATHER_PENALTY,
		},
	}
	var args := OS.get_cmdline_user_args()
	var f := FileAccess.open(args[0] if args.size() > 0 else "wiki_data.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_conv(out), "  ", false))
	f.close()
	print("WIKIDUMP_OK")
	quit()
