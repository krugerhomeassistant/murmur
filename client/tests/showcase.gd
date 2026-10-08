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
	var svc := [T.FIRE, T.POLICE, T.CLINIC, T.SCHOOL, T.PARK, T.PARK, T.PLAZA, T.LIBRARY, T.PLAYGROUND, T.BUS, T.WIND, T.WIND, T.WATER, T.SEWAGE, T.CINEMA, T.PARK, T.WIND, T.WIND, T.WIND, T.WIND, T.WIND, T.WIND, T.WATER, T.WATER, T.WATER, T.SEWAGE, T.SEWAGE, T.SEWAGE, T.HOSPITAL, T.POLICE, T.FIRE, T.SCHOOL, T.PARK, T.PARK, T.WIND, T.WIND, T.WIND, T.WATER, T.WATER, T.SEWAGE]
	var si := 0
	for y in range(r.position.y + 2, r.end.y - 2, 3):
		for x in range(r.position.x + 2, r.end.x - 2, 5):
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
