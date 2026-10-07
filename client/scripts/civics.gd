class_name Civics
extends RefCounted
## Static data for the mayor's side of the game: seasons, petitions, milestones, ranks, loans.
## Rules live in city.gd.

const T = Catalog.Id
const YEAR_DAYS := 28  # 4 seasons x 7 days; elections at the end of every year

## mods merge like policy mods. ev: random-event weight multipliers. harvest: farm output multiplier.
const SEASONS := [
    {"n": "Spring", "grass": Color("8fb877"), "harvest": 0.6,
        "mods": {"immig_mult": 1.15, "mood": 0.02},
        "ev": {"rain": 2.0, "flood": 2.0, "spring_bloom": 3.0, "snow": 0.0, "cold_snap": 0.0, "blizzard": 0.0, "harvest_fair": 0.0, "heatwave": 0.3},
        "txt": "New families arrive (+15% immigration), mood +2%. Rain and floods are common."},
    {"n": "Summer", "grass": Color("a3b46a"), "harvest": 1.0,
        "mods": {"tour_mult": 1.3, "fire_mult": 1.3},
        "ev": {"heatwave": 3.0, "drought": 3.0, "storm": 1.5, "wildfire": 2.0, "snow": 0.0, "cold_snap": 0.0, "blizzard": 0.0, "spring_bloom": 0.0, "harvest_fair": 0.0},
        "txt": "Tourism +30%, but fires start 30% more often. Heatwaves and droughts."},
    {"n": "Autumn", "grass": Color("b5a062"), "harvest": 1.8,
        "mods": {"mood": 0.0},
        "ev": {"storm": 2.0, "fog": 2.5, "harvest_fair": 3.0, "snow": 0.3, "blizzard": 0.0, "spring_bloom": 0.0, "heatwave": 0.2},
        "txt": "Harvest: farms produce 80% more crops. Storms and fog roll in."},
    {"n": "Winter", "grass": Color("d9dfe2"), "harvest": 0.2,
        "mods": {"upkeep_mult": 1.1, "power_dem": 0.25, "speed_mult": 0.9, "mood": -0.02},
        "ev": {"snow": 4.0, "cold_snap": 3.0, "blizzard": 3.0, "heatwave": 0.0, "drought": 0.0, "spring_bloom": 0.0, "harvest_fair": 0.0, "wildfire": 0.2},
        "txt": "Heating: upkeep +10% and power demand +25%. Farms barely produce, people walk slower, mood -2%."},
]

## Petitions. need: build <id> | cov [metric, min] | tax [r/c/i, max] | policy <key> | policy_off <key> | unemp <max> | event <id>.
## A petition is never raised while its need is already met. days: deadline after you accept.
const PETITIONS := [
    {"id": "park", "tribe": "club", "t": "More green space", "txt": "The Social club wants another park. Our kids play in the street.", "need": {"build": T.PARK}, "days": 3},
    {"id": "bar", "tribe": "club", "t": "Somewhere to unwind", "txt": "The Social club asks for a bar, or anywhere to meet after work.", "need": {"build": T.BAR}, "days": 4},
    {"id": "leisure", "tribe": "club", "t": "Leisure for all", "txt": "Parks, cinemas, stadiums: we want 70% of homes near leisure.", "need": {"cov": ["leisure", 0.7]}, "days": 5, "minpop": 60},
    {"id": "festival", "tribe": "club", "t": "Throw a festival", "txt": "Spirits are low. The Social club asks you to hold a festival.", "need": {"event": "festival"}, "days": 2},
    {"id": "church", "tribe": "church", "t": "A place of worship", "txt": "The Congregation has nowhere to meet on Sundays.", "need": {"build": T.CHURCH}, "days": 4},
    {"id": "lamps", "tribe": "church", "t": "Light our streets", "txt": "Muggings after dark. The Congregation wants street lamps.", "need": {"build": T.LIGHT}, "days": 3, "crime": 0.2},
    {"id": "health", "tribe": "church", "t": "Care for the sick", "txt": "We want 70% of homes within reach of a clinic or hospital.", "need": {"cov": ["health", 0.7]}, "days": 5},
    {"id": "tax_i", "tribe": "union", "t": "Cut industrial tax", "txt": "Factories are cutting shifts. The union wants industrial tax at 8% or less.", "need": {"tax": ["i", 0.08]}, "days": 2},
    {"id": "jobs", "tribe": "union", "t": "Jobs, jobs, jobs", "txt": "Too many of us are out of work. Get unemployment under 8%.", "need": {"unemp": 0.08}, "days": 5},
    {"id": "school", "tribe": "union", "t": "Schools for our kids", "txt": "The union wants 60% of homes near a school.", "need": {"cov": ["edu", 0.6]}, "days": 5},
    {"id": "transit", "tribe": "union", "t": "Buses to work", "txt": "Commutes are killing us. Half the homes should be near transit.", "need": {"cov": ["transit", 0.5]}, "days": 5, "minpop": 60},
    {"id": "union_hall", "tribe": "union", "t": "A union hall", "txt": "The union needs a hall to meet in.", "need": {"build": T.UNION_HALL}, "days": 4},
    {"id": "tax_c", "tribe": "business", "t": "Cut commercial tax", "txt": "Shopkeepers want commercial tax at 8% or less.", "need": {"tax": ["c", 0.08]}, "days": 2},
    {"id": "police", "tribe": "business", "t": "Protect our shops", "txt": "Break-ins every week. We want 60% police coverage.", "need": {"cov": ["police", 0.6]}, "days": 5},
    {"id": "chamber", "tribe": "business", "t": "A chamber of commerce", "txt": "Business owners want a chamber to lobby from.", "need": {"build": T.CHAMBER}, "days": 4},
    {"id": "depot", "tribe": "business", "t": "Open up trade", "txt": "Build a trade depot so our goods sell abroad.", "need": {"build": T.DEPOT}, "days": 5},
    {"id": "museum", "tribe": "artists", "t": "A museum", "txt": "The Arts collective wants a museum. Culture is not optional.", "need": {"build": T.MUSEUM}, "days": 5},
    {"id": "library", "tribe": "artists", "t": "A public library", "txt": "Books for everyone, say the artists.", "need": {"build": T.LIBRARY}, "days": 4},
    {"id": "clean_air", "tribe": "artists", "t": "Clean the air", "txt": "The smog ruins our paintings. Pass the clean air rules.", "need": {"policy": "clean_air"}, "days": 2, "poll": 0.15},
    {"id": "no_curfew", "tribe": "rebels", "t": "End the curfew", "txt": "The Reform movement demands you lift the night curfew.", "need": {"policy_off": "curfew"}, "days": 1},
    {"id": "no_search", "tribe": "rebels", "t": "Stop stop-and-search", "txt": "Stop harassing people on the street.", "need": {"policy_off": "stop_search"}, "days": 1},
    {"id": "tax_r", "tribe": "rebels", "t": "Cut household tax", "txt": "Families are struggling. Cut residential tax to 8% or less.", "need": {"tax": ["r", 0.08]}, "days": 2},
    {"id": "transit_free", "tribe": "rebels", "t": "Free buses", "txt": "Public transport should be free for all.", "need": {"policy": "transit_free"}, "days": 2, "minpop": 60},
]

## Milestones: stat must reach value (City property). reward in coins.
const MILESTONES := [
    {"id": "p10", "n": "First families", "stat": "peak", "v": 10, "reward": 100},
    {"id": "p50", "n": "A real village", "stat": "peak", "v": 50, "reward": 200},
    {"id": "p100", "n": "Town status", "stat": "peak", "v": 100, "reward": 300},
    {"id": "p200", "n": "Growing city", "stat": "peak", "v": 200, "reward": 500},
    {"id": "p400", "n": "Big city", "stat": "peak", "v": 400, "reward": 800},
    {"id": "p800", "n": "Metropolis", "stat": "peak", "v": 800, "reward": 1500},
    {"id": "mood70", "n": "Happy town (mood 70%)", "stat": "mood", "v": 0.7, "reward": 150},
    {"id": "appr75", "n": "Beloved mayor (approval 75%)", "stat": "approval", "v": 0.75, "reward": 200},
    {"id": "kept1", "n": "A promise kept", "stat": "kept", "v": 1, "reward": 100},
    {"id": "kept5", "n": "Man of the people (5 promises kept)", "stat": "kept", "v": 5, "reward": 300},
    {"id": "elect1", "n": "Re-elected", "stat": "elections_won", "v": 1, "reward": 400},
    {"id": "elect3", "n": "Third term", "stat": "elections_won", "v": 3, "reward": 1000},
    {"id": "exp50", "n": "First exports (50 units)", "stat": "exported", "v": 50, "reward": 150},
    {"id": "exp500", "n": "Trading hub (500 units)", "stat": "exported", "v": 500, "reward": 500},
    {"id": "ave5", "n": "Boulevards (5 avenue tiles)", "stat": "avenues", "v": 5, "reward": 100},
    {"id": "land60", "n": "Desirable address (land value 60)", "stat": "land_avg", "v": 0.6, "reward": 200},
    {"id": "survive", "n": "Survivor (rebuild after a disaster)", "stat": "disasters_survived", "v": 1, "reward": 150},
    {"id": "rich", "n": "Fat treasury ($3000)", "stat": "coins", "v": 3000, "reward": 0},
]

const RANKS := [[0, "Hamlet"], [30, "Village"], [80, "Town"], [200, "City"], [500, "Metropolis"]]

const LOANS := [
    {"n": "Small loan", "amt": 500, "days": 8, "rate": 0.10, "minpop": 0},
    {"n": "Bank loan", "amt": 1500, "days": 16, "rate": 0.18, "minpop": 60},
    {"n": "City bond", "amt": 4000, "days": 40, "rate": 0.25, "minpop": 150},
]

const RALLY_COST := 150.0


static func rank(peak: float) -> String:
    var r := "Hamlet"
    for k in RANKS:
        if peak >= float(k[0]):
            r = k[1]
    return r


static func need_text(n: Dictionary) -> String:
    if n.has("build"):
        return "Build a %s" % String(Catalog.DEFS[n["build"]]["n"]).to_lower()
    if n.has("cov"):
        return "%s coverage %d%%+" % [Catalog.METRICS[n["cov"][0]]["n"], int(float(n["cov"][1]) * 100.0)]
    if n.has("tax"):
        return "%s tax at %d%% or less" % [{"r": "Residential", "c": "Commercial", "i": "Industrial"}[n["tax"][0]], int(float(n["tax"][1]) * 100.0)]
    if n.has("policy"):
        return "Enable %s" % Catalog.POLICIES[n["policy"]]["n"]
    if n.has("policy_off"):
        return "Turn off %s" % Catalog.POLICIES[n["policy_off"]]["n"]
    if n.has("unemp"):
        return "Unemployment under %d%%" % int(float(n["unemp"]) * 100.0)
    if n.has("event"):
        return "Hold a festival"
    return "?"
