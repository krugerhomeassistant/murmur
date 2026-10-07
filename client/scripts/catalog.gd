class_name Catalog
extends RefCounted
## Static game data: buildings, city stats (coverage metrics) and policies.
## Pure data plus text generators. All rules live in city.gd.

enum Id {
    EMPTY, ROAD, AVENUE, RES, APT, COM, IND, OFFICE, FARM,
    FIRE, POLICE, CLINIC, HOSPITAL, SCHOOL, LIBRARY, UNIVERSITY,
    PARK, PLAYGROUND, PLAZA, CINEMA, MUSEUM, STADIUM, THEME,
    BUS, TRAIN, WIND, SOLAR, COAL, WATER, LANDFILL, RECYCLE,
    MARKET, BANK, MALL, HOTEL, TOWNHALL, WIRE, PIPE, LIGHT, COURT, PRISON, COTTAGE, TOWNHOUSE, TENEMENT, CONDO, CHURCH, BAR, UNION_HALL, CHAMBER, BASE, BARRACKS, RADAR, MILL, WAREHOUSE, DEPOT, SEWAGE, SEWER, PORT, NAVYARD, FISHDOCK,
    ORCHARD, RANCH, MINE, FOUNDRY,
}

const CATS := [
    ["infra", "Infrastructure"], ["zone", "Zones"], ["safety", "Safety"], ["health", "Health"],
    ["edu", "Education"], ["leisure", "Leisure & culture"], ["transit", "Transport"],
    ["util", "Utilities"], ["biz", "Commerce"], ["gov", "Government"], ["mil", "Military"], ["trade", "Industry & trade"],
]

## kind: need = uncovered homes lower mood (once the city is big enough to care);
## bonus = covered homes raise mood / income; safety = no direct mood effect.
const METRICS := {
    "fire": {"n": "Fire safety", "kind": "safety", "w": 0.0,
        "say": "One spark and this whole street goes up.",
        "txt": "Share of homes within reach of a fire station. A fire inside a covered area is put out after 3 seconds; elsewhere it burns 14 seconds, destroys the building and spreads to neighbours."},
    "police": {"n": "Policing", "kind": "need", "w": 0.06,
        "say": "I don't feel safe here. Where are the police?",
        "txt": "Uncovered homes lower mood (up to -12%) and let crime drain your treasury (theft costs roughly 0.12 coin per citizen per second before scaling). Riots and crime waves hit uncovered cities much harder."},
    "health": {"n": "Healthcare", "kind": "need", "w": 0.10,
        "say": "The nearest clinic is miles away.",
        "txt": "Uncovered homes lower mood (up to -10%) and cut productivity by up to 20%, which shrinks every tax line. Epidemics and heat waves are far worse without it."},
    "edu": {"n": "Education", "kind": "need", "w": 0.08,
        "say": "The kids need a school.",
        "txt": "Uncovered homes lower mood (up to -8%). Educated cities earn up to 30% more residential and industrial tax, and office buildings need it to run at full productivity."},
    "leisure": {"n": "Leisure", "kind": "need", "w": 0.12,
        "say": "This city needs a park.",
        "txt": "Parks, plazas, cinemas and stadiums. Uncovered homes lower mood (up to -12%). Citizens also spend their evenings and weekends in leisure buildings."},
    "culture": {"n": "Culture", "kind": "bonus", "w": 0.05,
        "say": "There's more to life than work. Thank goodness for the museum.",
        "txt": "Libraries, museums and plazas. Covered homes gain up to +5% mood. Culture also draws visitors who spend money."},
    "transit": {"n": "Public transport", "kind": "need", "w": 0.06,
        "say": "Getting around this city is a nightmare.",
        "txt": "Uncovered homes lower mood (up to -6%). Citizens in covered homes walk 30% faster to work and leisure."},
    "power": {"n": "Electricity", "kind": "need", "w": 0.15,
        "say": "The lights keep going out.",
        "txt": "Uncovered homes lower mood (up to -15%) and reduce productivity by up to 25%. Power plants have a radius, so spread them and combine sources."},
    "water": {"n": "Water", "kind": "need", "w": 0.15,
        "say": "We've got no running water!",
        "txt": "Uncovered homes lower mood (up to -15%) and productivity by up to 15%. Droughts and burst mains cut coverage."},
    "sewage": {"n": "Sewage", "kind": "need", "w": 0.1,
        "say": "The drains are backing up and the smell is awful.",
        "txt": "Uncovered homes lower mood (up to -10%) and make people sick more often. Sewers must reach a treatment plant; demand above plant capacity overloads the whole network."},
    "waste": {"n": "Waste disposal", "kind": "need", "w": 0.08,
        "say": "Rubbish is piling up in the streets.",
        "txt": "Uncovered homes lower mood (up to -8%). Landfills handle waste cheaply but smell; recycling centres do it cleanly."},
    "commerce": {"n": "Retail strength", "kind": "bonus", "w": 0.0,
        "say": "Shopping has never been this easy.",
        "txt": "Markets and malls. Covered homes boost shop sales by up to 25%."},
    "finance": {"n": "Banking", "kind": "bonus", "w": 0.0,
        "say": "My savings are finally earning something.",
        "txt": "Banks. Covered homes raise all tax income by up to 12%."},
    "light": {"n": "Street lighting", "kind": "safety", "w": 0.0,
        "say": "These streets are far too dark after sunset.",
        "txt": "Lit blocks have less crime (up to -25% of the crime score). Lamps reach only a few tiles, so place them where crime is highest."},
    "justice": {"n": "Justice", "kind": "safety", "w": 0.0,
        "say": "Nobody ever gets prosecuted around here.",
        "txt": "Courts and prisons. Covered blocks have up to 35% less crime, and mafia events fade sooner. Criminals who are caught stay off the streets."},
    "defence": {"n": "Defence", "kind": "bonus", "w": 0.02,
        "say": "At least we're protected out here.",
        "txt": "Bases and radar posts. Covered homes gain up to +2% mood, and border incidents hit covered towns far less."},
    "gov": {"n": "Civic administration", "kind": "bonus", "w": 0.04,
        "say": "At least the council answers my letters.",
        "txt": "Town hall reach. Covered homes gain up to +4% mood, and the city loses less to fines and audits."},
}

const POLICIES := {
    "transit_free": {"n": "Free public transport", "up": 2.0, "mods": {"cov_transit": 0.3, "mood": 0.02},
        "desc": "Fares are scrapped. Adds +30% transit coverage everywhere and +2% mood, but the operators must still be paid."},
    "recycling": {"n": "Recycling programme", "up": 1.0, "mods": {"cov_waste": 0.35, "mood": 0.01},
        "desc": "Kerbside recycling. Adds +35% waste coverage everywhere and +1% mood."},
    "watch": {"n": "Neighbourhood watch", "up": 0.8, "mods": {"crime_mult": 0.6},
        "desc": "Volunteers patrol the streets. Theft losses fall by 40%. Cheap, but no substitute for police."},
    "biz_subsidy": {"n": "Business subsidies", "up": 1.5, "mods": {"sales_mult": 1.12, "goods_mult": 1.12},
        "desc": "Tax breaks for shops and factories. +12% commercial and industrial income."},
    "tourism": {"n": "Tourism campaign", "up": 1.5, "mods": {"tour_mult": 2.0},
        "desc": "Posters in every airport. Doubles tourism income from stadiums, museums, hotels and theme parks."},
    "free_school": {"n": "Free schooling", "up": 1.5, "mods": {"cov_edu": 0.2, "mood": 0.01},
        "desc": "Books and meals for every child. Adds +20% education coverage and +1% mood."},
    "clean_air": {"n": "Clean air rules", "up": 0.5, "mods": {"poll_mult": 0.5, "goods_mult": 0.9},
        "desc": "Filters on every chimney. Halves pollution but factories earn 10% less."},
    "austerity": {"n": "Austerity budget", "up": -1.0, "mods": {"upkeep_mult": 0.85, "mood": -0.05},
        "desc": "Everything gets trimmed. Upkeep falls 15% and you save coins every second, but mood drops 5%."},
    "curfew": {"n": "Night curfew", "up": 0.5, "mods": {"crime_mult": 0.5, "mood": -0.04},
        "desc": "Streets empty after dark. Theft losses halve, but mood drops 4%."},
    "stop_search": {"n": "Stop and search", "up": 0.4, "mods": {"crime_mult": 0.7, "mood": -0.03},
        "desc": "Officers may search anyone. Crime falls 30% but mood drops 3%. Cheap, divisive."},
    "community_police": {"n": "Community policing", "up": 1.2, "mods": {"cov_police": 0.15, "mood": 0.01, "crime_mult": 0.9},
        "desc": "Officers walk the beat and know the locals. +15% police coverage, crime -10%, mood +1%."},
    "garrison": {"n": "Garrison", "up": 1.5, "mods": {"cov_defence": 0.3, "mood": -0.01},
        "desc": "Soldiers man the borders. +30% defence coverage: raids do less damage and your side wins more battles. Costs upkeep, mood -1%."},
    "insurance": {"n": "Disaster insurance", "up": 1.0, "mods": {"insured": 1.0},
        "desc": "Premiums every second. When fire, storms, quakes or tornadoes destroy a building, the insurer pays the city $30 for it."},
    "fast_track": {"n": "Fast-track permits", "up": 1.0, "mods": {"build_mult": 1.6},
        "desc": "Planning approvals in days. New buildings finish 60% faster."},
}

## Building definitions. kind: road | zone | svc.
## zone: home/jobs per level, max level. svc: r radius, prov {metric: strength}, jobs (staff),
## poll [radius, strength], tour (visitor income strength), spot (citizens visit it).
const DEFS := {
    Id.ROAD: {"n": "Road", "cat": "infra", "kind": "road", "cost": 5, "up": 0.08, "unlock": 0, "col": Color("4d4d4a"), "g": "",
        "desc": "The backbone of your city. Every building needs a road on one of its four sides, or it sits idle with a red mark. Citizens walk only along roads, so your layout decides how long commutes are.",
        "tip": "Build loops and grids. Dead ends mean long walks and grumpy residents."},
    Id.AVENUE: {"n": "Avenue", "cat": "infra", "kind": "road", "cost": 12, "up": 0.2, "unlock": 25, "col": Color("5c5c5a"), "g": "",
        "desc": "A wide, fast road. Works like a normal road for connecting buildings, but citizens walk 50% faster along it and path-finding prefers it.",
        "tip": "Run an avenue through the middle of long commutes, then fill the sides with zones."},
    Id.RES: {"n": "Residential zone", "cat": "zone", "kind": "zone", "cost": 10, "up": 0.3, "unlock": 0, "col": Color("c9a27a"), "g": "R",
        "sector": "res", "home": 4, "jobs": 0, "max": 3, "shape": "house",
        "desc": "Paint it beside a road and the city builds houses on it for you, paying the construction cost. Each house level holds 4 residents. Residents pay income tax while employed and walk to jobs, shops and parks.",
        "tip": "Keep homes away from factories and coal plants. Pollution lowers mood."},
    Id.APT: {"n": "Apartment zone", "cat": "zone", "kind": "zone", "cost": 15, "up": 0.5, "unlock": 80, "col": Color("b58a6e"), "g": "A",
        "sector": "res", "home": 10, "jobs": 0, "max": 3, "shape": "tower",
        "desc": "High-density housing: 10 residents per level, up to 30 per plot. Crowded blocks need strong services: power, water, transit and police all matter more because so many people depend on one plot.",
        "tip": "Place apartments near bus stops and train stations."},
    Id.COTTAGE: {"n": "Cottage zone", "cat": "zone", "kind": "zone", "cost": 12, "up": 0.3, "unlock": 30, "col": Color("d6b88a"), "g": "Co",
        "sector": "res", "home": 2, "jobs": 0, "max": 3, "shape": "house", "tier": 1.35,
        "desc": "Detached cottages with gardens: only 2 residents per level, but they pay 35% more tax. The planner places them on quiet, high land-value blocks.",
        "tip": "Great beside parks and schools, hopeless next to a factory."},
    Id.TOWNHOUSE: {"n": "Townhouse zone", "cat": "zone", "kind": "zone", "cost": 18, "up": 0.4, "unlock": 70, "col": Color("c49a7c"), "g": "Th",
        "sector": "res", "home": 6, "jobs": 0, "max": 3, "shape": "terrace", "tier": 1.1,
        "desc": "Terraced rows: 6 residents per level at 10% above average tax. A middle path between cottages and apartment blocks.",
        "tip": "Good on transit lines at the edge of the centre."},
    Id.TENEMENT: {"n": "Tenement zone", "cat": "zone", "kind": "zone", "cost": 10, "up": 0.5, "unlock": 60, "col": Color("8f7a6a"), "g": "Tn",
        "sector": "res", "home": 14, "jobs": 0, "max": 3, "shape": "tower", "tier": 0.6, "crime": 0.18,
        "desc": "Cramped cheap blocks: 14 residents per level, but they pay only 60% tax and raise local crime. A quick fix for housing shortages that you may regret.",
        "tip": "Add street lamps and police nearby, and avoid placing them in rich blocks."},
    Id.CONDO: {"n": "Luxury condo zone", "cat": "zone", "kind": "zone", "cost": 40, "up": 0.8, "unlock": 200, "col": Color("a9c4d8"), "g": "Lx",
        "sector": "res", "home": 8, "jobs": 0, "max": 3, "shape": "condo", "tier": 2.0,
        "desc": "Glass towers for the wealthy: 8 residents per level paying double tax. Only the planner builds them, and only on blocks with high land value.",
        "tip": "Parks, culture, clean air and low crime raise land value."},
    Id.COM: {"n": "Commercial zone", "cat": "zone", "kind": "zone", "cost": 15, "up": 0.3, "unlock": 0, "col": Color("6f8fae"), "g": "C",
        "sector": "com", "home": 0, "jobs": 3, "max": 3, "shape": "shop",
        "desc": "Shops and small businesses: 3 jobs per level. Citizens shop here in the evening and on weekends, which drives sales income. Demand rises with population.",
        "tip": "Too high a commercial tax scares shops away. Watch the C demand bar."},
    Id.IND: {"n": "Industrial zone", "cat": "zone", "kind": "zone", "cost": 20, "up": 0.3, "unlock": 0, "col": Color("8a7560"), "g": "I",
        "sector": "ind", "home": 0, "jobs": 5, "max": 3, "shape": "factory", "poll": [4, 0.35],
        "desc": "Workshops and factories: 5 jobs per level and steady goods income. They pollute nearby homes, so site them at the edge of town, a few blocks from housing.",
        "tip": "Clean air rules halve pollution at a cost to income."},
    Id.OFFICE: {"n": "Office zone", "cat": "zone", "kind": "zone", "cost": 25, "up": 0.4, "unlock": 60, "col": Color("7d98b8"), "g": "O",
        "sector": "office", "home": 0, "jobs": 4, "max": 3, "shape": "office",
        "desc": "Clean white-collar jobs, 4 per level, paying the best taxes. Productivity depends on education coverage: with no schools offices run at half speed.",
        "tip": "Pair offices with schools, libraries and a university."},
    Id.FARM: {"n": "Farm zone", "cat": "zone", "kind": "zone", "cost": 8, "up": 0.1, "unlock": 0, "col": Color("b8a65a"), "g": "F",
        "sector": "farm", "home": 0, "jobs": 2, "max": 2, "shape": "farm",
        "desc": "Cheap fields and barns: 2 jobs per level, tiny upkeep, a trickle of goods income and no pollution. A cheap way to give early residents work.",
        "tip": "Farms are a good buffer between homes and industry."},
    Id.ORCHARD: {"n": "Orchard zone", "cat": "zone", "kind": "zone", "cost": 12, "up": 0.15, "unlock": 40, "col": Color("8fb85a"), "g": "Or",
        "sector": "orchard", "home": 0, "jobs": 2, "max": 2, "shape": "farm",
        "desc": "Fruit and nut groves: 2 jobs per level and 50% more crops than a field, with no pollution. Crops still need a food mill.",
        "tip": "Autumn harvests are biggest; pair orchards with a mill and a warehouse."},
    Id.RANCH: {"n": "Ranch zone", "cat": "zone", "kind": "zone", "cost": 14, "up": 0.2, "unlock": 60, "col": Color("a8885a"), "g": "Ra",
        "sector": "ranch", "home": 0, "jobs": 3, "max": 2, "shape": "farm", "poll": [2, 0.1],
        "desc": "Pasture and dairy: 3 jobs per level and food made on the spot, no mill needed. A little smell reaches nearby homes.",
        "tip": "A ranch feeds a growing town without the mill chain, but keep it a couple of blocks from housing."},
    Id.MINE: {"n": "Mine", "cat": "zone", "kind": "zone", "cost": 30, "up": 0.5, "unlock": 100, "col": Color("6a6a72"), "g": "Mn",
        "sector": "mine", "home": 0, "jobs": 4, "max": 3, "shape": "factory", "poll": [4, 0.4],
        "desc": "Digs ore, 4 jobs per level. Can only be placed on ore deposits (dark flecks on the map); richer deposits yield more. Ore sells raw, or feeds a foundry.",
        "tip": "Find the dark flecks, put a road beside them, then a foundry nearby."},
    Id.FIRE: {"n": "Fire station", "cat": "safety", "kind": "svc", "cost": 80, "up": 0.6, "unlock": 0, "col": Color("b5533c"), "g": "F",
        "r": 7, "prov": {"fire": 1.0}, "jobs": 4, "shape": "cross",
        "desc": "Fire crews. Fires within 7 tiles are put out after 3 seconds instead of burning 14 and destroying the building. Fires spread to neighbouring buildings, so early response saves districts.",
        "tip": "Cover your densest blocks first. Parks and roads also act as firebreaks."},
    Id.POLICE: {"n": "Police station", "cat": "safety", "kind": "svc", "cost": 120, "up": 1.0, "unlock": 30, "col": Color("4a6fa5"), "g": "P",
        "r": 9, "prov": {"police": 1.0}, "jobs": 6,
        "desc": "Keeps order within 9 tiles. Raises mood in covered homes and stops theft draining your treasury. It also softens riots and crime waves.",
        "tip": "Unlocks at 30 residents. Cover most homes before your city passes 60."},
    Id.CLINIC: {"n": "Clinic", "cat": "health", "kind": "svc", "cost": 150, "up": 1.2, "unlock": 50, "col": Color("e8e2d0"), "g": "+",
        "r": 9, "prov": {"health": 0.6}, "jobs": 5, "shape": "cross",
        "desc": "A small clinic covering 9 tiles at 60% strength. Healthier citizens are happier and more productive, which shrinks every tax line less. Two overlapping clinics give full coverage.",
        "tip": "Hospitals cover far more but cost far more."},
    Id.HOSPITAL: {"n": "Hospital", "cat": "health", "kind": "svc", "cost": 450, "up": 3.0, "unlock": 120, "col": Color("f0f0f0"), "g": "H",
        "r": 16, "prov": {"health": 1.0}, "jobs": 20, "shape": "cross",
        "desc": "A full hospital: 16 tiles of full healthcare coverage and 20 jobs. The best defence against epidemics.",
        "tip": "One hospital in the centre covers most of a mid-size city."},
    Id.SCHOOL: {"n": "School", "cat": "edu", "kind": "svc", "cost": 180, "up": 1.2, "unlock": 70, "col": Color("d99a4e"), "g": "S",
        "r": 10, "prov": {"edu": 0.6}, "jobs": 8,
        "desc": "Primary and secondary education within 10 tiles at 60% strength. Raises mood, tax income (up to +30% with full coverage) and office productivity.",
        "tip": "Teacher strikes cut education coverage. Keep a spare school."},
    Id.LIBRARY: {"n": "Library", "cat": "edu", "kind": "svc", "cost": 200, "up": 1.0, "unlock": 90, "col": Color("a8795a"), "g": "L",
        "r": 10, "prov": {"edu": 0.3, "culture": 0.4}, "jobs": 4,
        "desc": "Quiet books and free internet. Adds modest education and culture coverage within 10 tiles.",
        "tip": "Cheap way to nudge education and culture past the threshold."},
    Id.UNIVERSITY: {"n": "University", "cat": "edu", "kind": "svc", "cost": 700, "up": 4.0, "unlock": 200, "col": Color("8f6a4a"), "g": "U",
        "r": 22, "prov": {"edu": 1.0, "culture": 0.2}, "jobs": 25, "tour": 0.5,
        "desc": "Top-tier education across 22 tiles, plus 25 jobs and a trickle of visitors. Makes offices run at full productivity.",
        "tip": "Brain drain events hurt cities without a university."},
    Id.PARK: {"n": "Park", "cat": "leisure", "kind": "svc", "cost": 30, "up": 0.2, "unlock": 8, "col": Color("5f8a4f"), "g": "",
        "r": 5, "prov": {"leisure": 0.35}, "jobs": 0, "spot": true, "shape": "park",
        "desc": "Green space. Adds 35% leisure coverage within 5 tiles. Citizens stroll here in the evening and fires cannot spread across it.",
        "tip": "Scatter small parks rather than building one big one."},
    Id.PLAYGROUND: {"n": "Playground", "cat": "leisure", "kind": "svc", "cost": 50, "up": 0.3, "unlock": 20, "col": Color("7fb069"), "g": "p",
        "r": 5, "prov": {"leisure": 0.3}, "jobs": 0, "spot": true,
        "desc": "Swings and slides for the kids. 30% leisure coverage within 5 tiles.",
        "tip": "Good filler beside apartment blocks."},
    Id.PLAZA: {"n": "Plaza", "cat": "leisure", "kind": "svc", "cost": 80, "up": 0.3, "unlock": 40, "col": Color("c8b88a"), "g": "o",
        "r": 6, "prov": {"leisure": 0.3, "culture": 0.2}, "jobs": 0, "spot": true, "tour": 0.2,
        "desc": "A paved square with a fountain. Adds leisure and culture coverage within 6 tiles and a little tourism. Protesters gather in the nearest road square, so plazas keep crowds away from homes.",
        "tip": "Put plazas where several roads meet."},
    Id.CINEMA: {"n": "Cinema", "cat": "leisure", "kind": "svc", "cost": 250, "up": 1.5, "unlock": 70, "col": Color("9a4a6a"), "g": "Ci",
        "r": 12, "prov": {"leisure": 0.5, "culture": 0.2}, "jobs": 6, "spot": true, "tour": 0.3,
        "desc": "Evening entertainment within 12 tiles. 50% leisure coverage, a little culture, 6 jobs and some visitor income.",
        "tip": "Citizens love an evening out. Great mood return per coin."},
    Id.MUSEUM: {"n": "Museum", "cat": "leisure", "kind": "svc", "cost": 400, "up": 2.0, "unlock": 130, "col": Color("b09a7a"), "g": "Mu",
        "r": 14, "prov": {"culture": 1.0}, "jobs": 8, "spot": true, "tour": 1.0,
        "desc": "Full culture coverage across 14 tiles, 8 jobs and good visitor income that scales with the tourism campaign.",
        "tip": "Culture raises mood and pays for itself with tourists."},
    Id.CHURCH: {"n": "Church", "cat": "leisure", "kind": "svc", "cost": 120, "up": 0.5, "unlock": 35, "col": Color("d8d0c0"), "g": "+",
        "r": 8, "prov": {"culture": 0.3, "leisure": 0.1}, "jobs": 3, "spot": true, "faction": "church",
        "desc": "A place of worship and community. Gives the Congregation a home (+2% city mood when they are content), a little culture, and a Sunday crowd.",
        "tip": "One per district is plenty."},
    Id.BAR: {"n": "Bar", "cat": "leisure", "kind": "svc", "cost": 90, "up": 0.5, "unlock": 45, "col": Color("8a5a3a"), "g": "B",
        "r": 6, "prov": {"leisure": 0.4}, "jobs": 3, "spot": true, "tour": 0.1, "crime": 0.08, "faction": "club",
        "desc": "Evening drinks within 6 tiles: 40% leisure coverage and a few jobs. Pleases the Social club, but late nights add a little local crime.",
        "tip": "Keep a police station or street lamps nearby."},
    Id.STADIUM: {"n": "Stadium", "cat": "leisure", "kind": "svc", "cost": 500, "up": 3.0, "unlock": 100, "col": Color("8a6fa8"), "g": "St",
        "r": 12, "prov": {"leisure": 0.6, "culture": 0.2}, "jobs": 15, "spot": true, "tour": 2.0, "shape": "dome",
        "desc": "A big stadium: 60% leisure coverage, 15 jobs and strong visitor income. Home-team wins lift the whole city's mood.",
        "tip": "Expensive upkeep, but tourists cover it in a busy city."},
    Id.THEME: {"n": "Theme park", "cat": "leisure", "kind": "svc", "cost": 600, "up": 4.0, "unlock": 180, "col": Color("d4567a"), "g": "Th",
        "r": 14, "prov": {"leisure": 0.8}, "jobs": 25, "spot": true, "tour": 3.5, "shape": "dome",
        "desc": "Roller coasters. 80% leisure coverage across 14 tiles, 25 jobs and the strongest tourism income in the game.",
        "tip": "Run a tourism campaign alongside it."},
    Id.BUS: {"n": "Bus stop", "cat": "transit", "kind": "svc", "cost": 40, "up": 0.3, "unlock": 40, "col": Color("4a8a8a"), "g": "B",
        "r": 6, "prov": {"transit": 0.6}, "jobs": 1,
        "desc": "Local buses. 60% transit coverage within 6 tiles: residents there walk to work 30% faster and are happier.",
        "tip": "Cheap and effective. Cluster stops along avenues."},
    Id.TRAIN: {"n": "Train station", "cat": "transit", "kind": "svc", "cost": 350, "up": 2.5, "unlock": 120, "col": Color("5a6a7a"), "g": "T",
        "r": 14, "prov": {"transit": 1.0, "commerce": 0.2}, "jobs": 8, "tour": 0.5,
        "desc": "Rail across 14 tiles. Full transit coverage, a boost to nearby shops, 8 jobs and some visitors.",
        "tip": "Strikes can shut it down. Back it up with buses."},
    Id.WIND: {"n": "Wind turbine", "cat": "util", "kind": "svc", "cost": 150, "up": 0.5, "unlock": 40, "col": Color("cfe3e8"), "g": "W",
        "r": 0, "prov": {}, "out": {"power": 8}, "jobs": 1, "shape": "turbine",
        "desc": "Clean but weak: generates 8 units of power into the grid. Storms and cold snaps reduce it, so pair with another source.",
        "tip": "Cheap way to bridge the gap until you afford solar or coal."},
    Id.SOLAR: {"n": "Solar farm", "cat": "util", "kind": "svc", "cost": 300, "up": 0.6, "unlock": 60, "col": Color("3a5a8a"), "g": "So",
        "r": 0, "prov": {}, "out": {"power": 14}, "jobs": 2, "shape": "panels",
        "desc": "Silent clean power: 14 units into the grid with almost no upkeep.",
        "tip": "Needs open land. Combine with wind for full coverage."},
    Id.COAL: {"n": "Coal power plant", "cat": "util", "kind": "svc", "cost": 400, "up": 3.0, "unlock": 40, "col": Color("4a4a4a"), "g": "Co",
        "r": 0, "prov": {}, "out": {"power": 40}, "jobs": 12, "poll": [10, 1.0], "shape": "chimney",
        "desc": "Generates 40 units of power and 12 jobs, but it pollutes homes within 10 tiles. Cheap to build, dirty to live next to.",
        "tip": "Site it far from housing, near the map edge."},
    Id.WATER: {"n": "Water tower", "cat": "util", "kind": "svc", "cost": 120, "up": 0.8, "unlock": 25, "col": Color("6aa8c8"), "g": "Wa",
        "r": 0, "prov": {}, "out": {"water": 14}, "jobs": 2, "shape": "tower",
        "desc": "Pumps 14 units of water into the pipe network. Droughts and burst mains cut coverage, so overlap two towers in big districts.",
        "tip": "Needed from about 25 residents."},
    Id.WIRE: {"n": "Power line", "cat": "util", "kind": "net", "layer": "wire", "cost": 2, "up": 0.03, "unlock": 15, "col": Color("e0c050"), "g": "",
        "desc": "Carries electricity. Power plants feed any connected line; a building is powered when a live line touches one of its four sides or its own tile. Lines can run under roads and buildings. Each unit of demand beyond plant output causes brownouts for everyone on the grid.",
        "tip": "Run lines along roads. Auto-growth lays them for you, but you can draw your own and bulldoze twice to cut one."},
    Id.PIPE: {"n": "Water pipe", "cat": "util", "kind": "net", "layer": "pipe", "cost": 2, "up": 0.03, "unlock": 15, "col": Color("5aa0d0"), "g": "",
        "desc": "Carries water from towers to buildings, same rules as power lines. Total demand above the pumps' output lowers water pressure for the whole network. Burst mains and droughts hit it hard.",
        "tip": "Water towers must touch a connected pipe to pump anything."},
    Id.PORT: {"n": "Port", "cat": "trade", "kind": "svc", "cost": 450, "up": 1.5, "unlock": 60, "col": Color("5a7a9a"), "g": "Po",
        "r": 0, "prov": {}, "jobs": 10, "water": true, "chain": "trade", "shape": "port",
        "desc": "A harbour with cranes and cargo ships. Must touch the river. Counts as two trade depots for export prices, and gives 10 jobs.",
        "tip": "Build it on the bank. Watch the cargo ships sail up and down the river."},
    Id.FISHDOCK: {"n": "Fishing dock", "cat": "trade", "kind": "svc", "cost": 200, "up": 0.6, "unlock": 40, "col": Color("6a9aaa"), "g": "Fi",
        "r": 0, "prov": {}, "jobs": 6, "water": true, "shape": "dock",
        "desc": "Boats bring in fish: about 0.15 food per worker per second, straight into your food stock. Must touch the river. A polluted river (untreated sewage) means fewer fish.",
        "tip": "Treat your sewage or the catch dries up."},
    Id.NAVYARD: {"n": "Naval yard", "cat": "mil", "kind": "svc", "cost": 900, "up": 3.0, "unlock": 150, "col": Color("6a7a8a"), "g": "Nv",
        "r": 0, "prov": {}, "jobs": 20, "water": true, "grant": 5.0, "shape": "port",
        "desc": "Warships on the river. Must touch the water. Adds military strength in wars (counts more than a barracks), 20 jobs and a government grant.",
        "tip": "Needs a river. Pairs with a base for full defence."},
    Id.SEWAGE: {"n": "Sewage plant", "cat": "util", "kind": "svc", "cost": 160, "up": 1.0, "unlock": 40, "col": Color("8a7a52"), "g": "Sw",
        "r": 0, "prov": {}, "out": {"sewage": 16}, "jobs": 3, "poll": [3, 0.3], "shape": "treatment",
        "desc": "Treats 16 units of sewage from the sewer network. It smells, so keep it a few tiles from homes. Untreated demand overloads every connected building.",
        "tip": "Needed from about 40 residents. Connect it with sewer pipes."},
    Id.SEWER: {"n": "Sewer pipe", "cat": "util", "kind": "net", "layer": "sewer", "cost": 2, "up": 0.03, "unlock": 30, "col": Color("9a7a4a"), "g": "",
        "desc": "Carries sewage from buildings to a treatment plant, same rules as water pipes. Can run under roads and buildings.",
        "tip": "Auto-growth lays sewers once a plant exists."},
    Id.LIGHT: {"n": "Street lamp", "cat": "safety", "kind": "svc", "cost": 25, "up": 0.1, "unlock": 30, "col": Color("f0d890"), "g": "L",
        "r": 4, "prov": {"light": 0.7}, "jobs": 0, "shape": "lamp",
        "desc": "A lamp post placed ON a road tile (no building plot needed). Lights the street within 4 tiles; lit blocks have noticeably less crime, mostly at night. Bulldoze the tile to remove just the lamp.",
        "tip": "Cheap. Click road tiles in the blocks with the redder crime overlay."},
    Id.COURT: {"n": "Courthouse", "cat": "gov", "kind": "svc", "cost": 300, "up": 1.5, "unlock": 80, "col": Color("c8b090"), "g": "Ct",
        "r": 14, "prov": {"justice": 0.6}, "jobs": 8,
        "desc": "Prosecutes offenders within 14 tiles. Crime falls up to 21% in covered blocks and mafia events fade sooner.",
        "tip": "Pair with a prison for full justice coverage."},
    Id.PRISON: {"n": "Prison", "cat": "gov", "kind": "svc", "cost": 500, "up": 3.0, "unlock": 100, "col": Color("6a6a70"), "g": "Pr",
        "r": 20, "prov": {"justice": 0.6}, "jobs": 15, "poll": [3, 0.15],
        "desc": "Locks up convicts: 20 tiles of justice coverage and 15 jobs, but nobody likes living next door.",
        "tip": "Site it at the edge of town."},
    Id.LANDFILL: {"n": "Landfill", "cat": "util", "kind": "svc", "cost": 100, "up": 0.6, "unlock": 35, "col": Color("7a6a4a"), "g": "La",
        "r": 12, "prov": {"waste": 0.6}, "jobs": 3, "poll": [7, 0.6],
        "desc": "Cheap waste disposal: 60% coverage within 12 tiles, but it smells out homes within 7 tiles.",
        "tip": "Place it away from housing. Recycling centres replace it later."},
    Id.RECYCLE: {"n": "Recycling centre", "cat": "util", "kind": "svc", "cost": 220, "up": 1.5, "unlock": 80, "col": Color("5a9a6a"), "g": "Rc",
        "r": 14, "prov": {"waste": 1.0}, "jobs": 8,
        "desc": "Clean full waste coverage across 14 tiles with no smell, plus 8 jobs.",
        "tip": "Strikes and rats events hurt waste coverage. Have a backup."},
    Id.MARKET: {"n": "Market", "cat": "biz", "kind": "svc", "cost": 120, "up": 0.6, "unlock": 20, "col": Color("d9a24e"), "g": "Mk",
        "r": 8, "prov": {"commerce": 0.5}, "jobs": 4, "spot": true,
        "desc": "Stalls and street food. 50% retail strength within 8 tiles, which lifts shop sales. Citizens drop in during the evening.",
        "tip": "Sales boost applies to total sales, so build once shops are busy."},
    Id.BANK: {"n": "Bank", "cat": "biz", "kind": "svc", "cost": 300, "up": 1.5, "unlock": 90, "col": Color("9a8a3a"), "g": "$",
        "r": 14, "prov": {"finance": 1.0}, "jobs": 6,
        "desc": "Credit for businesses. Homes within 14 tiles raise all tax income by up to 12%.",
        "tip": "Bank runs and audits are milder with a town hall."},
    Id.MALL: {"n": "Shopping mall", "cat": "biz", "kind": "svc", "cost": 500, "up": 3.0, "unlock": 150, "col": Color("8a7ab8"), "g": "Ml",
        "r": 12, "prov": {"commerce": 1.0, "leisure": 0.3}, "jobs": 15, "spot": true, "tour": 0.5,
        "desc": "A one-stop retail centre. Full retail strength across 12 tiles, some leisure, 15 jobs and visitors.",
        "tip": "Busy malls need transit nearby."},
    Id.HOTEL: {"n": "Hotel", "cat": "biz", "kind": "svc", "cost": 260, "up": 1.2, "unlock": 100, "col": Color("a85a5a"), "g": "Ho",
        "r": 4, "prov": {}, "jobs": 6, "tour": 1.5,
        "desc": "Beds for visitors: 6 jobs and 1.5 units of tourism income. Earns more with stadiums, museums and a tourism campaign.",
        "tip": "Sits well beside attractions."},
    Id.UNION_HALL: {"n": "Union hall", "cat": "gov", "kind": "svc", "cost": 150, "up": 0.6, "unlock": 70, "col": Color("a85a4a"), "g": "U",
        "r": 10, "prov": {"gov": 0.2}, "jobs": 3, "spot": true, "faction": "union",
        "desc": "Headquarters for the Workers' union. A content union gives +5% productivity; an angry one works to rule (-10%).",
        "tip": "Keep industrial taxes low and jobs plentiful to keep them happy."},
    Id.CHAMBER: {"n": "Chamber of commerce", "cat": "biz", "kind": "svc", "cost": 200, "up": 0.8, "unlock": 90, "col": Color("5a7a9a"), "g": "Cc",
        "r": 10, "prov": {"finance": 0.15}, "jobs": 4, "spot": true, "faction": "business",
        "desc": "Where shopkeepers and factory owners lobby. Content business owners add +8% shop income; unhappy ones cut shop and factory income 10%.",
        "tip": "Low commercial tax and a busy market keep them smiling."},
    Id.BASE: {"n": "Military base", "cat": "mil", "kind": "svc", "cost": 800, "up": 4.0, "unlock": 150, "col": Color("5a6a4a"), "g": "Ba",
        "r": 25, "prov": {"defence": 1.0}, "jobs": 25, "poll": [4, 0.2], "grant": 8.0, "shape": "fort",
        "desc": "A garrison with 25 jobs and a steady government grant. Noisy and a little polluting for neighbours within 4 tiles. Defence coverage across 25 tiles shields you from border incidents, and it unlocks air shows, deployments and conscription events.",
        "tip": "Site it at the edge of town. The grant roughly covers its own upkeep."},
    Id.BARRACKS: {"n": "Barracks", "cat": "mil", "kind": "svc", "cost": 350, "up": 1.5, "unlock": 150, "col": Color("6a7a5a"), "g": "Bk",
        "r": 8, "prov": {"police": 0.3}, "jobs": 12, "grant": 3.0, "shape": "fort",
        "desc": "Housing for soldiers: 12 jobs, a small grant and 30% police coverage within 8 tiles as patrols walk the streets.",
        "tip": "Needs a base nearby to feel useful."},
    Id.RADAR: {"n": "Radar post", "cat": "mil", "kind": "svc", "cost": 250, "up": 1.0, "unlock": 160, "col": Color("7a8a9a"), "g": "Ra",
        "r": 20, "prov": {"defence": 0.6}, "jobs": 4, "grant": 1.5, "shape": "radar",
        "desc": "Watches the skies: 60% defence coverage within 20 tiles, 4 jobs and a small grant.",
        "tip": "Two radars plus a base give full defence."},
    Id.MILL: {"n": "Food mill", "cat": "trade", "kind": "svc", "cost": 160, "up": 0.6, "unlock": 20, "col": Color("b89a5a"), "g": "Mi",
        "r": 0, "prov": {}, "jobs": 6, "poll": [2, 0.1], "chain": "mill", "shape": "chimney",
        "desc": "Turns crops from your farms into food: up to 3 units a second. Food made at home is free; anything the shops cannot get locally is imported at market price.",
        "tip": "One mill per 4-5 farm plots. Autumn harvests are huge, so a warehouse stops the surplus spoiling."},
    Id.FOUNDRY: {"n": "Foundry", "cat": "trade", "kind": "svc", "cost": 220, "up": 1.0, "unlock": 120, "col": Color("8a5a4a"), "g": "Fo",
        "r": 0, "prov": {}, "jobs": 8, "poll": [3, 0.3], "chain": "foundry", "shape": "chimney",
        "desc": "Smelts ore into metal, up to 2 ore a second. Metal sells for far more than ore, and factories turn it into extra goods.",
        "tip": "Needs a mine. One foundry per 3-4 mine plots."},
    Id.WAREHOUSE: {"n": "Warehouse", "cat": "trade", "kind": "svc", "cost": 120, "up": 0.4, "unlock": 30, "col": Color("8a7a6a"), "g": "Wh",
        "r": 0, "prov": {}, "jobs": 3, "chain": "store",
        "desc": "Adds 250 units of storage for crops, food and goods. Stock above 80% of capacity is sold off cheaply as exports; without space, harvests and factory output are wasted.",
        "tip": "Store the autumn harvest to feed the city through winter."},
    Id.DEPOT: {"n": "Trade depot", "cat": "trade", "kind": "svc", "cost": 300, "up": 1.0, "unlock": 60, "col": Color("6a8a9a"), "g": "TD",
        "r": 0, "prov": {}, "jobs": 8, "chain": "trade",
        "desc": "A freight yard on the regional line. Each depot raises export prices by 25% and lets the city export continuously instead of only when storage overflows.",
        "tip": "Pair with plenty of industry. Booming markets make exports pay even more."},
    Id.TOWNHALL: {"n": "Town hall", "cat": "gov", "kind": "svc", "cost": 300, "up": 1.5, "unlock": 50, "col": Color("c9b87a"), "g": "TH",
        "r": 20, "prov": {"gov": 1.0}, "jobs": 10, "spot": true,
        "desc": "The seat of government. Covered homes gain +4% mood and the city loses less when audited or fined.",
        "tip": "A single central town hall covers most towns."},
}


static func need_pop(metric: String) -> int:
    var best := 1 << 30
    for id in DEFS:
        var d: Dictionary = DEFS[id]
        if d.get("prov", {}).has(metric) or d.get("out", {}).has(metric):
            best = mini(best, int(d["unlock"]))
    return best


static func cat_name(cat: String) -> String:
    for c in CATS:
        if c[0] == cat:
            return c[1]
    return cat


static func describe_building(id: int, peak: float) -> String:
    var d: Dictionary = DEFS[id]
    var s := "[b]%s[/b]   [color=#9aa88f]%s[/color]\n" % [d["n"], cat_name(d["cat"])]
    var locked: bool = peak < int(d["unlock"])
    s += "Cost $%d   Upkeep %.1f/s   %s\n" % [d["cost"], d["up"], ("[color=#e07a5f]Unlocks at pop %d (best %d)[/color]" % [d["unlock"], int(peak)]) if locked else "Unlocked"]
    s += "\n" + String(d["desc"]) + "\n\n[b]Effects[/b]\n"
    var kind: String = d["kind"]
    if kind == "net":
        s += "- Connect plants to buildings; bulldoze a built-over tile twice to cut the line.\n"
    elif kind == "road":
        s += "- Connects buildings (a road on any of their four sides).\n"
        if id == Id.AVENUE:
            s += "- Citizens walk 50% faster along avenues.\n"
    elif kind == "zone":
        s += "- Built automatically while connected to a road; the city pays the cost.\n"
        s += "- Up to level %d (taller buildings need positive demand and a happy city).\n" % d["max"]
        if int(d["home"]) > 0:
            s += "- Holds %d residents per level.\n" % d["home"]
        if int(d["jobs"]) > 0:
            s += "- Offers %d jobs per level.\n" % d["jobs"]
    else:
        if int(d.get("jobs", 0)) > 0:
            s += "- Employs %d citizens (public jobs).\n" % d["jobs"]
        for m in d.get("prov", {}):
            s += "- Provides %d%% %s to homes within %d tiles.\n" % [int(float(d["prov"][m]) * 100.0), String(METRICS[m]["n"]).to_lower(), d["r"]]
        for m in d.get("out", {}):
            s += "- Generates %d units of %s for connected lines.\n" % [d["out"][m], String(METRICS[m]["n"]).to_lower()]
        if d.get("spot", false):
            s += "- Citizens visit it in their free time.\n"
        if d.has("tour"):
            s += "- Brings visitor income (strength %.1f).\n" % d["tour"]
    if d.has("poll"):
        s += "- Pollutes homes within %d tiles (strength %.2f).\n" % [d["poll"][0], d["poll"][1]]
    s += "\n[b]Tip[/b]  " + String(d["tip"])
    return s


static func describe_metric(m: String) -> String:
    var M: Dictionary = METRICS[m]
    var np := need_pop(m)
    var s := "[b]%s[/b]   [color=#9aa88f]city stat[/color]\n\n%s\n\n" % [M["n"], M["txt"]]
    if String(M["kind"]) == "need":
        s += "Starts to matter at about pop %d.\n" % np
    var prov: Array[String] = []
    for id in DEFS:
        if DEFS[id].get("prov", {}).has(m) or DEFS[id].get("out", {}).has(m):
            prov.append(String(DEFS[id]["n"]))
    if not prov.is_empty():
        s += "Provided by: " + ", ".join(prov)
    return s


static func describe_policy(k: String) -> String:
    var p: Dictionary = POLICIES[k]
    return "[b]%s[/b]   [color=#9aa88f]policy[/color]\n%s per second\n\n%s" % [p["n"], ("Costs %.1f" % p["up"]) if float(p["up"]) >= 0.0 else ("Saves %.1f" % -float(p["up"])), p["desc"]]


## Citizen tribes (factions). Every citizen belongs to one; each tribe has a mood and demands.
const TRIBES := {
    "church": {"n": "Congregation", "w": 14, "wants": "A church within reach and low crime.", "up": "Content: city mood +2%.", "down": "Unhappy: city mood -2%."},
    "union": {"n": "Workers' union", "w": 30, "wants": "Full employment and low industrial tax. A union hall helps.", "up": "Content: productivity +5%.", "down": "Unhappy: productivity -10% (work to rule)."},
    "business": {"n": "Chamber of commerce", "w": 12, "wants": "Low commercial and industrial taxes and a busy market. A chamber helps.", "up": "Content: shop income +8%.", "down": "Unhappy: shop and factory income -10%."},
    "artists": {"n": "Arts collective", "w": 8, "wants": "Museums, libraries and plazas (culture coverage).", "up": "Content: tourism x1.2.", "down": "Unhappy: tourism x0.8."},
    "rebels": {"n": "Reform movement", "w": 10, "wants": "No curfew or stop-and-search, honest news and no protests.", "up": "Content: nothing happens, which is the point.", "down": "Unhappy: crime +10%."},
    "club": {"n": "Social club", "w": 26, "wants": "Parks, bars, cinemas and stadiums (leisure coverage).", "up": "Content: city mood +2%.", "down": "Unhappy: city mood -2%."},
}
const FIRST_NAMES := ["Ada", "Ben", "Cleo", "Dev", "Elif", "Finn", "Gus", "Hana", "Ivo", "June", "Kofi", "Lena", "Milo", "Nadia", "Omar", "Pia", "Quin", "Rosa", "Sam", "Tara", "Uma", "Vic", "Wren", "Yara", "Zed"]
const TRIBE_LINES := {
    "church": ["We could do with a church round here.", "Sunday service was lovely.", "Crime on our street is a worry."],
    "union": ["The union stands with the workers.", "Fair pay for fair work.", "Another shift, another day."],
    "business": ["Taxes are choking small business.", "Customers are scarce this week.", "Opening a second shop soon."],
    "artists": ["A city without a gallery is a graveyard.", "Painting the market square tonight.", "The museum inspires me."],
    "rebels": ["Don't trust the council.", "We need real change.", "Curfews are for cowards."],
    "club": ["Anyone up for a drink?", "Let's meet at the park.", "The nightlife could be better."],
}
