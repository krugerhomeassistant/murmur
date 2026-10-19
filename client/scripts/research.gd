class_name Research
extends RefCounted
## Research choices (ages finish line AF6): entering an age lets the town pick one of two techs for it.
## A tech is a bundle of the same modifiers policies and events use, so it costs nothing in the hot paths.

const TECHS := [
	[{"n": "Fire", "d": "mood +0.02", "mods": {"mood": 0.02}}, {"n": "Flint tools", "d": "goods +3%", "mods": {"goods_mult": 1.03}}],
	[{"n": "Bronze tools", "d": "production +3%", "mods": {"prod_mult": 1.03}}, {"n": "Writing", "d": "knowledge +8%", "mods": {"know_mult": 1.08}}],
	[{"n": "Coinage", "d": "taxes +3%", "mods": {"tax_mult": 1.03}}, {"n": "Aqueducts", "d": "mood +0.02", "mods": {"mood": 0.02}}],
	[{"n": "Masonry", "d": "buildings cost 5% less", "mods": {"build_cost_mult": 0.95}}, {"n": "Monasteries", "d": "knowledge +8%", "mods": {"know_mult": 1.08}}],
	[{"n": "Guilds", "d": "taxes +3%", "mods": {"tax_mult": 1.03}}, {"n": "Heavy plough", "d": "goods +4%", "mods": {"goods_mult": 1.04}}],
	[{"n": "Printing press", "d": "knowledge +10%", "mods": {"know_mult": 1.1}}, {"n": "Banking", "d": "sales +4%", "mods": {"sales_mult": 1.04}}],
	[{"n": "Steam power", "d": "production +4%", "mods": {"prod_mult": 1.04}}, {"n": "Public health", "d": "mood +0.02", "mods": {"mood": 0.02}}],
	[{"n": "Electric grid", "d": "upkeep 4% less", "mods": {"upkeep_mult": 0.96}}, {"n": "Assembly lines", "d": "production +4%", "mods": {"prod_mult": 1.04}}],
	[{"n": "Nuclear science", "d": "knowledge +8%", "mods": {"know_mult": 1.08}}, {"n": "Mass media", "d": "sales +4%", "mods": {"sales_mult": 1.04}}],
	[{"n": "Computing", "d": "sales +5%", "mods": {"sales_mult": 1.05}}, {"n": "Efficiency", "d": "upkeep 4% less", "mods": {"upkeep_mult": 0.96}}],
	[{"n": "Networks", "d": "knowledge +8%", "mods": {"know_mult": 1.08}}, {"n": "Automation", "d": "production +4%", "mods": {"prod_mult": 1.04}}],
	[{"n": "Fusion", "d": "goods +5%", "mods": {"goods_mult": 1.05}}, {"n": "Abundance", "d": "mood +0.03", "mods": {"mood": 0.03}}],
]


## Ages a town has reached but not yet chosen a tech for.
static func pending(c: City) -> Array[int]:
	var out: Array[int] = []
	for a in mini(c.age, TECHS.size() - 1) + 1:
		if int(c.tech[a]) < 0:
			out.append(a)
	return out


## Choose option `opt` (0 or 1) for `age`: only for an age already reached and not yet decided.
static func pick(c: City, age: int, opt: int) -> bool:
	if age < 0 or age >= TECHS.size() or age > c.age or opt < 0 or opt > 1 or int(c.tech[age]) >= 0:
		return false
	c.tech[age] = opt
	c._log("Research: %s." % TECHS[age][opt]["n"])
	c._collect_mods()
	return true


## The modifiers of every chosen tech, merged the way City._add_mods merges them.
static func mods(c: City) -> Dictionary:
	var out := {}
	for a in TECHS.size():
		if int(c.tech[a]) >= 0:
			for k in TECHS[a][int(c.tech[a])]["mods"]:
				var v: float = float(TECHS[a][int(c.tech[a])]["mods"][k])
				out[k] = float(out.get(k, 1.0)) * v if String(k).ends_with("_mult") else float(out.get(k, 0.0)) + v
	return out


## Planner towns choose by themselves: the same town always makes the same choice.
static func auto(c: City) -> void:
	for a in pending(c):
		pick(c, a, hash([c.town_name, a]) & 1)
