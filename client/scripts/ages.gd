class_name Ages
extends RefCounted
## Ages: what a town may build and train depends on its age as well as its population (docs/AGES_DESIGN.md).
## A town moves up by itself when it has enough knowledge and enough people; the start age is chosen in the setup screen.
## Pure data and rules, no scene: tests use it directly.

const T = Catalog.Id

## Twelve ages in four eras of three. The era (`tier`) decides how the town looks (roads, houses, vehicles, clothes); the age decides what
## it may build and train, which research it has picked, and how much it knows.
const NAMES := ["Stone", "Bronze", "Classical", "Dark", "Medieval", "Renaissance", "Industrial", "Electric", "Atomic", "Information", "Digital", "Future"]
const ERA := ["Ancient", "Medieval", "Industrial", "Modern"]
const PER_ERA := 3
const LAST := 11
const KNOW := [0.0, 150.0, 350.0, 600.0, 1000.0, 1600.0, 2400.0, 3500.0, 5000.0, 7000.0, 9500.0, 13000.0]  # knowledge needed to enter each age
const PEAK := [0, 10, 22, 40, 65, 90, 120, 160, 200, 250, 300, 360]  # peak population needed to enter each age
const GRACE_STEP := 400.0  # seconds per step of the grace period after entering an age: a newly expected service is missed 25% more every step
const COINS := [0.0, 100.0, 220.0, 400.0, 650.0, 900.0, 1200.0, 1600.0, 2000.0, 2500.0, 3500.0, 5000.0]  # treasury needed to enter each age: the new age expects services that cost money
const HOLD_MOOD := 0.35
const BASE_RATE := 0.5  # knowledge per second per 50 people before education and culture

## Era (0 Ancient, 1 Medieval, 2 Industrial, 3 Modern) in which a building becomes available; anything not listed is Ancient.
const BUILDING := {
	T.AVENUE: 1, T.TOWNHOUSE: 1, T.TENEMENT: 1, T.FIRE: 1, T.POLICE: 1, T.SCHOOL: 1, T.LIBRARY: 1, T.TOWNHALL: 1, T.COURT: 1, T.PRISON: 1,
	T.PORT: 1, T.DEPOT: 1, T.CHAMBER: 1, T.HOTEL: 1, T.FOUNDRY: 1, T.TOOLWORKS: 1, T.RAILYARD: 2, T.HYDRO: 2, T.REFINERY: 2, T.RESERVOIR: 2, T.DESAL: 3, T.GAS: 3, T.NUCLEAR: 3, T.LIGHT: 1,
	T.APT: 2, T.OFFICE: 2, T.COAL: 2, T.WIRE: 2, T.PIPE: 2, T.SEWER: 2, T.SEWAGE: 2, T.CLINIC: 2, T.HOSPITAL: 2, T.BUS: 2, T.TRAIN: 2, T.BANK: 2,
	T.UNION_HALL: 2, T.LANDFILL: 2, T.CINEMA: 2, T.STADIUM: 2, T.MUSEUM: 2, T.NAVYARD: 2, T.ARMOURY: 2, T.GREENHOUSE: 2, T.WATER: 2,
	T.CONDO: 3, T.UNIVERSITY: 3, T.SOLAR: 3, T.WIND: 3, T.MALL: 3, T.THEME: 3, T.RECYCLE: 3, T.RADAR: 3, T.BASE: 3,
}
## Later ages inside the era (0 to 2). Everything a service need depends on (fire, police, schools, power, water, sewage, waste, transit, health)
## opens with its era, so an age that starts to expect it can always build it.
const SPREAD := {
	T.WAREHOUSE: 1, T.MILL: 1, T.BAR: 1, T.MINE: 1, T.CHURCH: 2, T.SAWMILL: 2,
	T.TOWNHOUSE: 1, T.LIBRARY: 1, T.TOWNHALL: 1, T.DEPOT: 1, T.FOUNDRY: 1, T.LIGHT: 1, T.COURT: 2, T.PRISON: 2, T.CHAMBER: 2, T.HOTEL: 2, T.TOOLWORKS: 2, T.TENEMENT: 2,
	T.HYDRO: 1, T.RESERVOIR: 1, T.REFINERY: 2, T.OFFICE: 1, T.HOSPITAL: 1, T.BANK: 1, T.UNION_HALL: 1, T.MUSEUM: 1, T.NAVYARD: 1, T.CINEMA: 2, T.STADIUM: 2, T.GREENHOUSE: 2,
	T.UNIVERSITY: 1, T.SOLAR: 1, T.WIND: 1, T.MALL: 1, T.RECYCLE: 1, T.THEME: 2, T.RADAR: 2, T.BASE: 2, T.DESAL: 2, T.NUCLEAR: 2,
}

## Era in which a unit type can be trained, and its later age inside the era.
const UNIT := {
	"archer": 1, "knight": 1, "galley": 1,
	"inf": 2, "gren": 2, "art": 2, "patrol": 2, "destroyer": 2, "transport": 2,
	"snip": 3, "medic": 3, "ltank": 3, "tank": 3, "htank": 3, "aa": 3, "jet": 3, "fighter": 3, "bomber": 3, "heli": 3,
}
const UNIT_SPREAD := {"galley": 1, "knight": 2, "gren": 1, "art": 1, "transport": 1, "destroyer": 2, "snip": 1, "tank": 1, "aa": 1, "jet": 1, "fighter": 1, "htank": 2, "bomber": 2, "heli": 2}


## Eras (0 to 3) and the first age of each; `tier(age)` is the era an age belongs to.
static func tier(age: int) -> int:
	return clampi(age / PER_ERA, 0, ERA.size() - 1)


## Age from which people expect a service (coverage metric). Before it nobody misses it: coverage counts as full, so an Ancient town
## is not punished for lacking power, sewers or clinics it cannot build. Metrics not listed are expected from the start.
const EXPECTS := {"fire": 3, "police": 3, "edu": 3, "power": 6, "water": 6, "sewage": 6, "waste": 6, "transit": 6, "health": 6}


static func expects(metric: String) -> int:
	return int(EXPECTS.get(metric, 0))


## 0 to 4: how far into the grace period the town is. At stage 0 a service the new age expects still counts as fully covered; at stage 4 it is missed in full.
static func stage(age_t: float) -> int:
	return mini(4, int(age_t / GRACE_STEP))


static func name_of(age: int) -> String:
	return NAMES[clampi(age, 0, LAST)]


static func building(id: int) -> int:
	return int(BUILDING.get(id, 0)) * PER_ERA + int(SPREAD.get(id, 0))


static func unit(kind: String) -> int:
	return int(UNIT.get(kind, 0)) * PER_ERA + int(UNIT_SPREAD.get(kind, 0))


## Knowledge gained per second: grows with the population and with how well it is schooled and cultured.
static func rate(c: City) -> float:
	return float(c.pop) / 50.0 * BASE_RATE * (1.0 + float(c.cov.get("edu", 0.0)) + 0.6 * float(c.cov.get("culture", 0.0))) * c.mod("know_mult")


## True when the town may enter the next age now.
static func ready(c: City) -> bool:
	return c.age < LAST and c.know >= float(KNOW[c.age + 1]) and c.peak >= float(PEAK[c.age + 1]) and c.coins >= float(COINS[c.age + 1]) and c.mood >= HOLD_MOOD


## One second of research. Returns the new age when the town advanced, else -1.
static func second(c: City) -> int:
	if c.mood >= HOLD_MOOD:  # an unhappy town is given time: new expectations do not stack on one already struggling
		c.age_t += 1.0
	if c.age >= LAST:
		return -1
	c.know += rate(c)
	if ready(c):
		c.age += 1
		if EXPECTS.values().has(c.age):  # only an age that opens a need starts a new grace period
			c.age_t = 0.0
		return c.age
	return -1


## Puts a town in an age (setup, sandbox commands): its knowledge starts at that age's threshold.
static func set_age(c: City, age: int) -> void:
	c.age = clampi(age, 0, LAST)
	c.know = float(KNOW[c.age])
	c.age_t = 1.0e9  # no grace period for the age a town starts in
