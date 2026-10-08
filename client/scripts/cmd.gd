class_name Cmd
extends RefCounted
## The one route from player input into the simulation (docs/MULTIPLAYER.md, phase 2). Single-player calls `run` directly;
## in multiplayer the host calls it for a client's command after checking the sender owns the town. Every argument is
## validated here because over the network it is untrusted. Returns what the underlying City/Diplo method returns.

const TAX := ["r", "c", "i"]
const DIPLO := ["gift", "pact", "alliance", "embargo", "lift", "peace", "tribute", "war", "leave"]  # the Diplo.act verbs


static func run(towns: Array[City], t: City, name: String, a: Array) -> Variant:
	for v in a:  # NaN or INF in a number would slip through clampf and poison the town's money
		if v is float and not is_finite(v):
			return null
	match name:
		"place":
			if _ints(a, 3) and t.inside(a[0], a[1]) and Catalog.DEFS.has(a[2]):
				return t.place(a[0], a[1], a[2])
		"bulldoze":
			if _ints(a, 2) and t.inside(a[0], a[1]):
				return t.bulldoze(a[0], a[1])
		"water":
			if _ints(a, 3) and t.inside(a[0], a[1]) and t.owns(a[0], a[1]) and (a[2] == 0 or a[2] == 1):
				return t.set_water(a[0], a[1], a[2])
		"tax":
			if a.size() == 2 and a[0] is String and a[0] in TAX and (a[1] is float or a[1] is int):
				t.set("tax_" + a[0], clampf(float(a[1]), 0.0, 0.5))
				return true
		"policy":
			if a.size() == 2 and a[0] is String and Catalog.POLICIES.has(a[0]) and a[1] is bool:
				t.set_policy(a[0], a[1])
				return true
		"loan":
			if _ints(a, 1) and a[0] >= 0 and a[0] < Civics.LOANS.size():
				return t.take_loan(a[0])
		"expand":
			if _ints(a, 1) and a[0] >= 0 and a[0] < 4:
				return t.expand(a[0])
		"auto_expand":
			if a.size() == 1 and a[0] is bool:
				t.auto_expand = a[0]
				return true
		"auto_policy":
			if a.size() == 1 and a[0] is bool:
				t.auto_policy = a[0]
				return true
		"auto_mode":
			if _ints(a, 1) and a[0] >= 0 and a[0] <= 2:
				t.auto_mode = a[0]
				return true
		"train":
			if a.size() == 1 and a[0] is bool:
				t.train_on = a[0]
				return true
		"train_w":
			if a.size() == 2 and a[0] is String and Military.KIND.has(a[0]) and a[1] is int:
				t.train_w[a[0]] = clampi(a[1], 0, 3)
				return true
		"answer":
			if a.size() == 2 and a[0] is int and a[1] is bool and a[0] >= 0 and a[0] < t.petitions.size():
				t.answer(a[0], a[1])
				return true
		"rally":
			return t.rally()
		"diplo":
			if a.size() == 2 and a[0] is int and a[1] is String and a[1] in DIPLO and a[0] >= 0 and a[0] < towns.size() and towns[a[0]] != t:
				return Diplo.act(t, towns[a[0]], a[1])
	return null  # unknown command or rejected arguments


static func _ints(a: Array, n: int) -> bool:
	if a.size() != n:
		return false
	for v in a:
		if not v is int:
			return false
	return true
