class_name Powers
extends RefCounted
## God powers (docs/SANDBOX_DESIGN.md, G3): spend belief, which a happy town regenerates, to nudge a town. Each power reuses an
## existing event, so it behaves exactly like the random one. Sandbox games only (`Cmd.sandbox`); never in multiplayer.

const MAX_BELIEF := 100.0
const REGEN := 0.02  # belief per second at mood 0.5; a happier town regenerates more

## id: name, belief cost, cooldown in seconds, event id ("" = special)
const DEFS := {
	"bloom": {"n": "Bloom", "cost": 10.0, "cd": 60.0, "ev": "spring_bloom", "good": true},
	"boom": {"n": "Boom", "cost": 25.0, "cd": 120.0, "ev": "boom", "good": true},
	"cure": {"n": "Cure", "cost": 15.0, "cd": 60.0, "ev": "", "good": true},
	"bless": {"n": "Bless", "cost": 15.0, "cd": 90.0, "ev": "", "good": true},
	"lightning": {"n": "Lightning", "cost": 10.0, "cd": 30.0, "ev": "", "good": false},
	"quake": {"n": "Earthquake", "cost": 30.0, "cd": 120.0, "ev": "earthquake", "good": false},
	"tornado": {"n": "Tornado", "cost": 30.0, "cd": 120.0, "ev": "tornado", "good": false},
	"plague": {"n": "Plague", "cost": 25.0, "cd": 120.0, "ev": "epidemic", "good": false},
	"famine": {"n": "Famine", "cost": 25.0, "cd": 120.0, "ev": "supply_crisis", "good": false},
	"incite": {"n": "Incite", "cost": 20.0, "cd": 120.0, "ev": "", "good": false},
}


## Once per sim second per town: regenerate belief and run cooldowns down.
static func tick(c: City) -> void:
	c.belief = minf(c.belief + REGEN * (0.5 + c.mood), MAX_BELIEF)
	for k in c.power_cd.keys():
		c.power_cd[k] = float(c.power_cd[k]) - 1.0
		if float(c.power_cd[k]) <= 0.0:
			c.power_cd.erase(k)


## Casts a power on the town. Returns false when unknown, too costly, cooling down or without effect.
static func cast(c: City, id: String) -> bool:
	if not DEFS.has(id) or c.power_cd.has(id):
		return false
	var d: Dictionary = DEFS[id]
	if c.belief < float(d["cost"]):
		return false
	var done := false
	match id:
		"cure":
			for z in c.citizens:
				if z.sick > 0.0:
					z.sick = 0.0
					done = true
		"bless":
			done = c.mood < 1.0
			c.mood = minf(c.mood + 0.15, 1.0)
		"incite":  # border tension towards every neighbour rises; a war starts at 1 (Diplo.pick_goal)
			for o in c.partners:
				c.tension[o.town_name] = minf(float(c.tension.get(o.town_name, 0.0)) + 0.3, 1.0)
				done = true
		"lightning":
			done = c.ignite() != ""
		_:
			done = c.trigger(String(d["ev"]))
	if done:
		c.belief -= float(d["cost"])
		c.power_cd[id] = float(d["cd"])
	return done
