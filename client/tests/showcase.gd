extends RefCounted
## Lays out a dense, serviced downtown on `c` for README media (see scripts/MEDIA.md). Planner towns stall near 100 pop, so this is hand-built.
static func build(c: City) -> int:
	var T = Catalog.Id
	c.peak = 1.0e9
	c.coins = 1.0e7
	c.human = true
	var r := c.terr
	var n := 0
	for y in range(r.position.y + 1, r.end.y - 1):
		for x in range(r.position.x + 1, r.end.x - 1):
			if c.at(x, y) != T.EMPTY or c.water[y * City.W + x] == 1:
				continue
			var main := (y - r.position.y) % 8 == 2 or (x - r.position.x) % 9 == 4
			if main:
				n += int(c.place(x, y, T.AVENUE if (y - r.position.y) % 8 == 2 and x % 2 == 0 else T.ROAD))
			elif (y - r.position.y) % 4 == 0 and (x - r.position.x) % 3 != 1:
				n += int(c.place(x, y, T.ROAD))
	for y in range(r.position.y + 1, r.end.y - 1):
		for x in range(r.position.x + 1, r.end.x - 1):
			if c.at(x, y) == T.EMPTY and c.water[y * City.W + x] == 0 and c._road_next_to(y * City.W + x) >= 0:
				var h := (x * 7 + y * 13 + x * y) % 20
				var k: int = [T.RES, T.RES, T.COTTAGE, T.TOWNHOUSE, T.APT, T.COM, T.COM, T.COM, T.OFFICE, T.CONDO, T.RES, T.TENEMENT, T.COM, T.APT, T.RES, T.TOWNHOUSE, T.COM, T.OFFICE, T.RES, T.CONDO][h]
				if x > r.end.x - 7:
					k = T.IND
				n += int(c.place(x, y, k))
	var svc := [T.FIRE, T.POLICE, T.CLINIC, T.SCHOOL, T.PARK, T.PLAZA, T.LIBRARY, T.PLAYGROUND, T.BUS, T.CINEMA, T.HOSPITAL, T.POLICE, T.FIRE, T.SCHOOL, T.PARK, T.PARK, T.PARK]
	for k in 10:
		svc.append(T.COAL)
	for k in 28:
		svc.append(T.WATER)
		svc.append(T.SEWAGE)
		svc.append(T.PARK if k % 3 == 0 else T.PLAYGROUND)
	var si := 0
	for y in range(r.position.y + 2, r.end.y - 2, 2):
		for x in range(r.position.x + 2, r.end.x - 2, 4):
			if si >= svc.size():
				break
			var i := y * City.W + x
			if c.is_road(c.grid[i]):
				continue
			c.grid[i] = T.EMPTY
			c.lvl[i] = 0
			if c.place(x, y, svc[si]):
				si += 1
	for i in c.cells:
		if c.is_road(c.grid[i]):
			c.wire[i] = 1
			c.pipe[i] = 1
			c.sewer[i] = 1
	c.scan_dirty = true
	c.flush()
	return n


## Whole recipe: new 4-town spectator world, hand-built downtown, extra utilities, ~650 residents, locked mood and summer.
static func stage(m: Node) -> void:
	var T = Catalog.Id
	m.bench_seed = 20261011
	m.open_setup()
	m.start_game({"name": "Murmur", "towns": 4, "mood": 1, "diff": 1, "land": 1, "river": 3, "auto": 2, "policy": true, "expand": true, "guide": false, "spectate": true})
	for ch in m.hud.get_children():
		if ch.get_script() != null and str(ch.get_script().resource_path).ends_with("setup.gd"):
			ch.queue_free()
	var c: City = m.city
	build(c)
	for i in c.cells:
		if c.is_zone(c.grid[i]) and c.lvl[i] == 0:
			c.lvl[i] = 1 + (i * 7) % 2
	var want := {T.COAL: 8, T.WATER: 36, T.SEWAGE: 32, T.WIND: 6}
	var idx := []
	for i in c.cells:
		if c.is_zone(c.grid[i]) and c._road_next_to(i) >= 0 and i % 5 < 2:
			idx.append(i)
	idx.shuffle()
	var p := 0
	for t in want:
		var k := 0
		while k < want[t] and p < idx.size():
			var i: int = idx[p]
			p += 1
			c.grid[i] = T.EMPTY
			c.lvl[i] = 0
			if c.place(i % City.W, i / City.W, t):
				k += 1
	c.scan_dirty = true
	c.flush()
	var n := 0
	while n < 650 and c._spawn():
		n += 1
	var lock := Timer.new()
	lock.wait_time = 0.1
	lock.timeout.connect(func() -> void:
		c.mood = 0.85
		c.protest = false
		c.coins = 1.0e7
		c.day = 10 + c.day % 2)  # stay in summer
	m.add_child(lock)
	lock.start()
	c.clock = 10.0
	m.follow = false
	m.speed = 1.0
	m.chunk_kick = true
