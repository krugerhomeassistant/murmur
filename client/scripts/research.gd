class_name Research
extends RefCounted
## The town skill tree: six branches of six nodes. A node is taken with knowledge points (earned with knowledge), needs the previous node of its branch
## or a neighbouring branch's node of the same tier, and its tier opens with the age (tier * 2). A node is a bundle of the same modifiers policies and
## events use, so it costs nothing in the hot paths. A town cannot take everything: the points run out long before the tree does.

const TIERS := 6
const POINTS_PER_KNOW := 0.6
const BRANCHES := [
	{"n": "Economy", "nodes": [
		{"n": "Barter", "d": "taxes +2%", "mods": {"tax_mult": 1.02}},
		{"n": "Coinage", "d": "sales +3%", "mods": {"sales_mult": 1.03}},
		{"n": "Guilds", "d": "taxes +3%", "mods": {"tax_mult": 1.03}},
		{"n": "Banking", "d": "sales +4%", "mods": {"sales_mult": 1.04}},
		{"n": "Stock exchange", "d": "taxes +4%", "mods": {"tax_mult": 1.04}},
		{"n": "Global trade", "d": "sales +5%", "mods": {"sales_mult": 1.05}},
	]},
	{"n": "Industry", "nodes": [
		{"n": "Flint tools", "d": "goods +3%", "mods": {"goods_mult": 1.03}},
		{"n": "Bronze tools", "d": "production +3%", "mods": {"prod_mult": 1.03}},
		{"n": "Masonry", "d": "buildings cost 5% less", "mods": {"build_cost_mult": 0.95}},
		{"n": "Steam power", "d": "production +4%", "mods": {"prod_mult": 1.04}},
		{"n": "Assembly lines", "d": "goods +4%", "mods": {"goods_mult": 1.04}},
		{"n": "Automation", "d": "buildings cost 6% less", "mods": {"build_cost_mult": 0.94}},
	]},
	{"n": "Knowledge", "nodes": [
		{"n": "Oral tradition", "d": "knowledge +5%", "mods": {"know_mult": 1.05}},
		{"n": "Writing", "d": "knowledge +6%", "mods": {"know_mult": 1.06}},
		{"n": "Monasteries", "d": "knowledge +7%", "mods": {"know_mult": 1.07}},
		{"n": "Printing press", "d": "knowledge +8%", "mods": {"know_mult": 1.08}},
		{"n": "Computing", "d": "knowledge +8%", "mods": {"know_mult": 1.08}},
		{"n": "Networks", "d": "knowledge +10%", "mods": {"know_mult": 1.1}},
	]},
	{"n": "Society", "nodes": [
		{"n": "Fire", "d": "mood +0.02", "mods": {"mood": 0.02}},
		{"n": "Aqueducts", "d": "mood +0.02", "mods": {"mood": 0.02}},
		{"n": "Public works", "d": "upkeep 3% less", "mods": {"upkeep_mult": 0.97}},
		{"n": "Public health", "d": "mood +0.02", "mods": {"mood": 0.02}},
		{"n": "Mass media", "d": "mood +0.02 and immigration +5%", "mods": {"mood": 0.02, "immig_mult": 1.05}},
		{"n": "Abundance", "d": "mood +0.03", "mods": {"mood": 0.03}},
	]},
	{"n": "Military", "nodes": [
		{"n": "Stockade", "d": "crime -5%", "mods": {"crime_mult": 0.95}},
		{"n": "Bronze arms", "d": "soldiers +5% health", "mods": {"army_mult": 1.05}},
		{"n": "Drill", "d": "soldiers +5% health", "mods": {"army_mult": 1.05}},
		{"n": "Standing army", "d": "crime -8%", "mods": {"crime_mult": 0.92}},
		{"n": "Combined arms", "d": "soldiers +8% health", "mods": {"army_mult": 1.08}},
		{"n": "Total war", "d": "soldiers +10% health", "mods": {"army_mult": 1.1}},
	]},
	{"n": "Infrastructure", "nodes": [
		{"n": "Roads", "d": "upkeep 2% less", "mods": {"upkeep_mult": 0.98}},
		{"n": "Bridges", "d": "goods +2%", "mods": {"goods_mult": 1.02}},
		{"n": "Canals", "d": "upkeep 3% less", "mods": {"upkeep_mult": 0.97}},
		{"n": "Railways", "d": "production +3%", "mods": {"prod_mult": 1.03}},
		{"n": "Electric grid", "d": "upkeep 4% less", "mods": {"upkeep_mult": 0.96}},
		{"n": "Efficiency", "d": "upkeep 4% less", "mods": {"upkeep_mult": 0.96}},
	]},
]

static func id(branch: int, tier: int) -> int:
	return branch * TIERS + tier


static func node(i: int) -> Dictionary:
	return BRANCHES[i / TIERS]["nodes"][i % TIERS]


static func cost(i: int) -> float:
	var t := i % TIERS + 1
	return 300.0 * t * t


static func has(c: City, i: int) -> bool:
	return c.tree.has(i)


## Why a node cannot be taken now ("" when it can).
static func block(c: City, i: int) -> String:
	if i < 0 or i >= BRANCHES.size() * TIERS:
		return "no such node"
	if has(c, i):
		return "taken"
	var t := i % TIERS
	if c.age < t * 2:
		return "needs the %s age" % Ages.name_of(t * 2)
	var b := i / TIERS
	var linked := t == 0 or has(c, i - 1) or has(c, id((b + 1) % BRANCHES.size(), t - 1)) or has(c, id((b + BRANCHES.size() - 1) % BRANCHES.size(), t - 1))
	if not linked:
		return "needs a connected node first"
	if c.pts < cost(i):
		return "needs %d points" % ceili(cost(i))
	return ""


static func pick(c: City, i: int) -> bool:
	if block(c, i) != "":
		return false
	c.pts -= cost(i)
	c.tree.append(i)
	c._log("Research: %s." % node(i)["n"])
	c._collect_mods()
	return true


## The modifiers of every node taken, merged the way City._add_mods merges them.
static func mods(c: City) -> Dictionary:
	var out := {}
	for i in c.tree:
		var m: Dictionary = node(i)["mods"]
		for k in m:
			var v: float = float(m[k])
			out[k] = float(out.get(k, 1.0)) * v if String(k).ends_with("_mult") else float(out.get(k, 0.0)) + v
	return out


## Planner towns take the affordable node of their favourite branch first; the same town always has the same temper.
static func auto(c: City) -> void:
	var best := -1
	var bw := -1.0
	for i in BRANCHES.size() * TIERS:
		if block(c, i) != "":
			continue
		var w := 1.0 + float(hash([c.town_name, i / TIERS]) % 100) / 25.0 - float(i % TIERS) * 0.3
		if w > bw:
			bw = w
			best = i
	if best >= 0:
		pick(c, best)
