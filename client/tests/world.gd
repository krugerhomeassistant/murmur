extends SceneTree
# World generator: deterministic from the seed, no seams at chunk borders, sane mix of terrain.
const N := 256

func _grid(w: World) -> PackedByteArray:
	var g := PackedByteArray()
	g.resize(N * N * 2)
	for y in N:
		for x in N:
			g[(y * N + x) * 2] = w.kind(x - 100, y - 100)
			g[(y * N + x) * 2 + 1] = w.ore(x - 100, y - 100)
	return g


func _init() -> void:
	var a := World.new(20261008)
	var ga := _grid(a)
	var gb := _grid(World.new(20261008))
	var gc := _grid(World.new(20261008, 48))  # other chunk size must give the identical land
	var gd := _grid(World.new(77))
	var ok := true
	if ga != gb:
		print("FAIL same seed differs")
		ok = false
	if ga != gc:
		var bad := 0
		for i in ga.size():
			if ga[i] != gc[i]:
				bad += 1
		print("FAIL chunk seam: %d cells differ" % bad)
		ok = false
	if ga == gd:
		print("FAIL seeds equal")
		ok = false
	var cnt := {}  # whole-world mix: sparse samples over a 1400x1400 area for four seeds
	var tot := 0.0
	for sd in [11, 22, 33, 44]:
		var ww := World.new(sd)
		for y in range(-700, 700, 9):
			for x in range(-700, 700, 9):
				var kk := ww.kind(x, y)
				cnt[kk] = int(cnt.get(kk, 0)) + 1
				tot += 1.0
	var water: float = (int(cnt.get(World.K.SEA, 0)) + int(cnt.get(World.K.RIVER, 0))) / tot
	var river: float = int(cnt.get(World.K.RIVER, 0)) / tot
	print("kinds %s water %.2f river %.3f" % [cnt, water, river])
	if water < 0.12 or water > 0.4 or river < 0.01 or river > 0.1:
		print("FAIL water mix")
		ok = false
	for kk in [World.K.PLAIN, World.K.FOREST, World.K.HILL, World.K.ROCK, World.K.SAND]:
		if int(cnt.get(kk, 0)) < tot * 0.01:
			print("FAIL too little of kind %d" % kk)
			ok = false
	var ores := 0
	for i in range(1, ga.size(), 2):
		if ga[i] > 0:
			ores += 1
			if ga[i - 1] < World.K.PLAIN:
				print("FAIL ore under water")
				ok = false
	if ores < 100:
		print("FAIL ore count %d" % ores)
		ok = false
	if "--map" in OS.get_cmdline_user_args():
		for y in range(0, N, 2):
			var s := ""
			for x in range(0, N, 1):
				s += " ~.,\"^#"[ga[(y * N + x) * 2]]
			print(s)
	print("WORLD_OK" if ok else "WORLD_FAIL")
	quit(0 if ok else 1)
