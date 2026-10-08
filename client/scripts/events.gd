class_name WorldEvents
extends RefCounted
## Event catalog. Random events and the player's sandbox menu share it.
## Live feeds (Phase 3) write into Signals directly and bypass this.
##
## mods: while active. keys ending _mult multiply, everything else adds.
##   mood, income_add, cov_<metric>, dem_res/dem_com/dem_ind/dem_off, speed_mult, upkeep_mult,
##   sales_mult, goods_mult, office_mult, prod_mult, tour_mult, crime_mult, poll_mult,
##   immig_mult, fire_mult, build_mult, tax_mult
## inst: one-off. coins, coins_pop (per citizen), ignite n, damage (fraction of buildings lose a level),
##   destroy n buildings, citizens +/-n, news, market
## scale: a city stat whose coverage softens the event (effect * (1 - 0.7 * coverage)).

const CATS := ["Weather", "Economy", "Social", "Disaster", "Civic"]

const EVENTS := {
    # ---- weather ----
    "rain": {"n": "Rain", "cat": "Weather", "w": 10, "minpop": 0, "dur": 40.0, "weather": "rain",
        "mods": {"speed_mult": 0.9}, "msg": "Rain rolls in.", "say": "Typical. It's raining again.",
        "desc": "Steady rain for 40 seconds. Mood -5%. Fires burn out after 9 seconds instead of 14. Citizens walk 10% slower."},
    "heatwave": {"n": "Heatwave", "cat": "Weather", "w": 5, "minpop": 10, "dur": 45.0, "weather": "heatwave", "scale": "health",
        "mods": {"fire_mult": 2.5, "cov_water": -0.15}, "msg": "A heatwave settles over the city.", "say": "It's far too hot to think.",
        "desc": "Mood -10%, fires start 2.5 times as often and water coverage drops 15%. Healthcare softens the damage."},
    "storm": {"n": "Storm", "cat": "Weather", "w": 4, "minpop": 10, "dur": 30.0, "weather": "storm",
        "mods": {"speed_mult": 0.75, "cov_power": -0.2}, "inst": {"damage": 0.02}, "msg": "A storm is battering the city.",
        "say": "Hold on to your hat!",
        "desc": "Mood -20%, citizens walk 25% slower, power coverage drops 20% and about 2% of buildings lose a level to the winds."},
    "snow": {"n": "Snowfall", "cat": "Weather", "w": 4, "minpop": 10, "dur": 50.0, "weather": "snow",
        "mods": {"speed_mult": 0.7, "upkeep_mult": 1.08}, "msg": "Snow blankets the streets.", "say": "Snow day!",
        "desc": "Everyone walks 30% slower and heating raises upkeep 8% while it lasts."},
    "fog": {"n": "Dense fog", "cat": "Weather", "w": 3, "minpop": 10, "dur": 40.0, "weather": "fog",
        "mods": {"speed_mult": 0.85, "crime_mult": 1.4}, "msg": "Thick fog rolls in.", "say": "I can't see my own feet.",
        "desc": "Walking 15% slower and theft up 40%. Police coverage softens nothing here, but patrols help."},
    "cold_snap": {"n": "Cold snap", "cat": "Weather", "w": 3, "minpop": 40, "dur": 60.0, "weather": "snow",
        "mods": {"cov_power": -0.25, "mood": -0.04}, "msg": "A bitter cold snap grips the city.", "say": "The heating can't keep up.",
        "desc": "Power coverage -25% and mood -4% for a minute. Cities with spare power barely notice."},
    "drought": {"n": "Drought", "cat": "Weather", "w": 2, "minpop": 25, "dur": 90.0, "weather": "heatwave",
        "mods": {"cov_water": -0.3, "goods_mult": 0.9}, "msg": "A drought is parching the land.", "say": "The taps are running dry.",
        "desc": "Water coverage -30% and goods income -10% for 90 seconds. Overlapping water towers cushion it."},
    "flood": {"n": "Flood", "cat": "Weather", "w": 1.5, "minpop": 30, "dur": 40.0, "weather": "rain",
        "mods": {"speed_mult": 0.7}, "inst": {"damage": 0.04, "coins_pop": -1.0}, "msg": "Flash floods swamp the low streets.",
        "say": "The water's up to my knees!",
        "desc": "About 4% of buildings lose a level and repairs cost 1 coin per citizen. Everyone walks 30% slower while it drains."},
    "tornado": {"n": "Tornado", "cat": "Weather", "w": 1, "minpop": 60, "dur": 0.0,
        "inst": {"tornado": 1}, "msg": "A tornado tears through the city!", "say": "Take cover!",
        "desc": "A twister crosses the map, flattening most buildings in its path and tearing down power lines. Insurance pays out per building; afterwards you choose whether to fund a fast rebuild."},
    "blizzard": {"n": "Blizzard", "cat": "Weather", "w": 1, "minpop": 30, "dur": 50.0, "weather": "snow",
        "mods": {"speed_mult": 0.6, "cov_transit": -0.4, "upkeep_mult": 1.1}, "inst": {"damage": 0.01}, "msg": "A blizzard buries the streets.",
        "say": "I can't even open my front door.",
        "desc": "Walking 40% slower, transit -40%, upkeep +10% and a few buildings damaged. Mostly a winter event."},
    "spring_bloom": {"n": "Spring bloom", "cat": "Weather", "w": 1, "minpop": 10, "dur": 60.0,
        "mods": {"mood": 0.04, "tour_mult": 1.2}, "msg": "The city is in full bloom.", "say": "Smell those blossoms!",
        "desc": "Mood +4% and tourism +20% for a minute. Spring only."},
    "harvest_fair": {"n": "Harvest fair", "cat": "Civic", "w": 1, "minpop": 20, "dur": 50.0,
        "mods": {"mood": 0.05, "sales_mult": 1.1}, "msg": "The harvest fair opens in the square.", "say": "Best pumpkins I've ever seen.",
        "desc": "Mood +5% and shop sales +10% for 50 seconds. Autumn only."},
    # ---- economy ----
    "boom": {"n": "Market boom", "cat": "Economy", "w": 5, "minpop": 0, "dur": 0.0,
        "inst": {"market": 0.7}, "msg": "Markets surge. Shops report record sales.", "say": "Business is booming!",
        "desc": "The market signal jumps +0.7 and decays slowly. All incomes get +35% at the peak."},
    "supply_crisis": {"n": "Supply crisis", "cat": "Economy", "w": 2, "minpop": 40, "dur": 0.0,
        "inst": {"shock": {"food": 1.7, "goods": 1.5, "crops": 1.4}}, "msg": "Supply lines break down. Prices are climbing.", "say": "Everything costs more every week.",
        "desc": "Food, goods and crop prices jump (x1.7, x1.5, x1.4) and ease back over a few minutes. Wages lag behind, so poor households run out of savings; a long squeeze means unrest. Cost-of-living payments help."},
    "price_slump": {"n": "Price slump", "cat": "Economy", "w": 2, "minpop": 40, "dur": 0.0,
        "inst": {"shock": {"food": 0.7, "goods": 0.75, "ore": 0.7, "metal": 0.75}}, "msg": "A glut pushes prices down.", "say": "Cheap bread, finally.",
        "desc": "Food, goods, ore and metal prices fall about 25-30% and recover over a few minutes. Households save more; producers earn less."},
    "crash": {"n": "Market crash", "cat": "Economy", "w": 4, "minpop": 0, "dur": 0.0,
        "inst": {"market": -0.7}, "msg": "Markets tumble. Shoppers hold on to their coins.", "say": "My savings are gone.",
        "desc": "The market signal drops -0.7 and recovers slowly. All incomes fall 35% at the trough."},
    "inflation": {"n": "Inflation", "cat": "Economy", "w": 3, "minpop": 50, "dur": 90.0,
        "mods": {"upkeep_mult": 1.25}, "msg": "Prices are climbing. Everything costs more.", "say": "A loaf of bread costs how much?!",
        "desc": "Upkeep +25% for 90 seconds."},
    "tech_boom": {"n": "Tech boom", "cat": "Economy", "w": 2, "minpop": 80, "dur": 80.0,
        "mods": {"office_mult": 1.5, "immig_mult": 1.5, "dem_off": 0.4}, "msg": "Tech firms are moving in.", "say": "Everyone's talking about start-ups.",
        "desc": "Office income +50%, newcomers arrive 50% faster and office demand jumps for 80 seconds."},
    "strike": {"n": "Factory strike", "cat": "Economy", "w": 3, "minpop": 40, "dur": 60.0,
        "mods": {"goods_mult": 0.5, "mood": -0.02}, "msg": "Factory workers walked out.", "say": "We're on strike!",
        "desc": "Goods income halves for a minute."},
    "tourist_season": {"n": "Tourist season", "cat": "Economy", "w": 3, "minpop": 60, "dur": 90.0,
        "mods": {"tour_mult": 2.0, "sales_mult": 1.15}, "msg": "Tourists flood in.", "say": "So many visitors this year!",
        "desc": "Tourism income doubles and shop sales rise 15% for 90 seconds. Stadiums, museums and hotels shine."},
    "trade_deal": {"n": "Trade deal", "cat": "Economy", "w": 2, "minpop": 50, "dur": 90.0,
        "mods": {"goods_mult": 1.4, "dem_ind": 0.3}, "msg": "A trade deal opens new markets.", "say": "Orders are pouring in.",
        "desc": "Goods income +40% and industrial demand +30% for 90 seconds."},
    "oil_shock": {"n": "Oil shock", "cat": "Economy", "w": 2, "minpop": 60, "dur": 80.0,
        "mods": {"upkeep_mult": 1.15, "goods_mult": 0.85}, "msg": "Fuel prices spike.", "say": "Filling up costs a fortune.",
        "desc": "Upkeep +15% and goods income -15% for 80 seconds."},
    "investor": {"n": "Foreign investor", "cat": "Economy", "w": 2, "minpop": 30, "dur": 0.0,
        "inst": {"coins_pop": 4.0}, "msg": "A foreign investor funds your city.", "say": "New money, new jobs.",
        "desc": "Instant windfall of 4 coins per citizen."},
    "audit": {"n": "Tax audit", "cat": "Economy", "w": 2, "minpop": 60, "dur": 0.0, "scale": "gov",
        "inst": {"coins_pop": -3.0}, "msg": "Auditors found irregularities in the books.", "say": "The auditors are in town.",
        "desc": "Costs up to 3 coins per citizen. A town hall within reach softens it."},
    "startups": {"n": "Start-up wave", "cat": "Economy", "w": 3, "minpop": 40, "dur": 90.0,
        "mods": {"dem_com": 0.35, "sales_mult": 1.1}, "msg": "A wave of start-ups opens for business.", "say": "Another new cafe on my street!",
        "desc": "Commercial demand +35% and sales +10% for 90 seconds."},
    "factory_offer": {"n": "Factory relocation", "cat": "Economy", "w": 3, "minpop": 30, "dur": 90.0,
        "mods": {"dem_ind": 0.4}, "msg": "A manufacturer wants to relocate here.", "say": "Is that factory really coming?",
        "desc": "Industrial demand +40% for 90 seconds. Zone Industrial away from homes."},
    # ---- social ----
    "good_news": {"n": "Good news", "cat": "Social", "w": 5, "minpop": 0, "dur": 0.0,
        "inst": {"news": 0.7}, "msg": "Good news from abroad lifts spirits.", "say": "Did you hear? Wonderful news!",
        "desc": "The news signal jumps +0.7 and fades. Mood +21% at the peak."},
    "scandal": {"n": "Scandal", "cat": "Social", "w": 4, "minpop": 0, "dur": 0.0,
        "inst": {"news": -0.8}, "msg": "A scandal rocks the council. Anger in the streets.", "say": "Disgraceful!",
        "desc": "The news signal drops -0.8 and fades. Mood -24% at the trough."},
    "celebrity": {"n": "Celebrity visit", "cat": "Social", "w": 2, "minpop": 70, "dur": 60.0,
        "mods": {"tour_mult": 1.5, "mood": 0.05}, "msg": "A celebrity is in town.", "say": "I saw them in the street!",
        "desc": "Tourism income +50% and mood +5% for a minute."},
    "sports_win": {"n": "Home team wins", "cat": "Social", "w": 3, "minpop": 60, "dur": 60.0,
        "mods": {"mood": 0.06, "sales_mult": 1.1}, "msg": "The home team won the cup!", "say": "We won! We actually won!",
        "desc": "Mood +6% and shop sales +10% for a minute."},
    "marathon": {"n": "City marathon", "cat": "Social", "w": 2, "minpop": 50, "dur": 40.0,
        "mods": {"mood": 0.03, "speed_mult": 0.9, "tour_mult": 1.3}, "msg": "Runners fill the streets.", "say": "Go on, you can do it!",
        "desc": "Mood +3%, tourism +30%, but road closures slow walkers 10%."},
    "protest_march": {"n": "Protest march", "cat": "Social", "w": 3, "minpop": 40, "dur": 50.0,
        "mods": {"mood": -0.05, "sales_mult": 0.9}, "msg": "Crowds march on the town square.", "say": "What do we want? Change!",
        "desc": "Mood -5% and sales -10% for 50 seconds."},
    "riot": {"n": "Riot", "cat": "Social", "w": 1.5, "minpop": 80, "dur": 40.0, "scale": "police",
        "mods": {"mood": -0.08}, "inst": {"ignite": 2, "coins_pop": -1.5}, "msg": "Rioters set fires in the streets!", "say": "Burn it down!",
        "desc": "Two fires break out, repairs cost 1.5 coins per citizen and mood -8%. Police coverage cuts all of it by up to 70%."},
    "crime_wave": {"n": "Crime wave", "cat": "Social", "w": 2, "minpop": 50, "dur": 60.0, "scale": "police",
        "mods": {"crime_mult": 2.5, "mood": -0.03}, "msg": "Theft is surging.", "say": "My shop was robbed again.",
        "desc": "Theft losses 2.5 times higher and mood -3% for a minute. Police coverage softens it."},
    "mafia_rises": {"n": "Mafia takes hold", "cat": "Social", "w": 1.5, "minpop": 70, "dur": 120.0, "scale": "justice",
        "mods": {"crime_add": 0.2, "sales_mult": 0.9, "mood": -0.02}, "msg": "A crime family is muscling in on the city.", "say": "You pay them, or you close.",
        "desc": "Crime +20% and shop income -10% for two minutes. Courts and prisons cut it by up to 70%."},
    "protection_racket": {"n": "Protection racket", "cat": "Social", "w": 2, "minpop": 60, "dur": 0.0, "scale": "police",
        "inst": {"coins_pop": -1.2, "news": -0.2}, "msg": "Shopkeepers are paying for protection.", "say": "Pay up, or the window breaks.",
        "desc": "Costs 1.2 coins per citizen and sours the news. Police coverage softens it."},
    "gang_war": {"n": "Gang war", "cat": "Social", "w": 1, "minpop": 90, "dur": 45.0, "scale": "police",
        "mods": {"crime_add": 0.25, "mood": -0.05}, "inst": {"ignite": 1}, "msg": "Gangs are fighting in the streets.", "say": "Stay inside. They're shooting again.",
        "desc": "Crime +25%, mood -5% and one building catches fire. Police coverage softens it."},
    "bank_heist": {"n": "Bank heist", "cat": "Social", "w": 1, "minpop": 70, "dur": 0.0, "scale": "police",
        "inst": {"coins": -80, "news": -0.3}, "msg": "Robbers hit the bank.", "say": "Did you see the getaway car?",
        "desc": "Costs about 80 coins and bad headlines. Police coverage cuts the loss."},
    "police_raid": {"n": "Big police raid", "cat": "Civic", "w": 1.5, "minpop": 60, "dur": 40.0, "scale": "justice",
        "mods": {"crime_add": -0.2, "mood": 0.02}, "inst": {"news": 0.3}, "msg": "A major raid cleans up the docks.", "say": "About time somebody did something.",
        "desc": "Crime -20%, mood +2% and good headlines for 40 seconds."},
    "prison_break": {"n": "Prison break", "cat": "Disaster", "w": 0.8, "minpop": 100, "dur": 50.0,
        "mods": {"crime_add": 0.3, "mood": -0.04}, "msg": "Convicts have escaped!", "say": "They're on the loose.",
        "desc": "Crime +30% and mood -4% until they are recaptured. Only happens once you have a prison."},
    "air_show": {"n": "Air show", "cat": "Civic", "w": 2, "minpop": 100, "dur": 40.0, "needs": Catalog.Id.BASE,
        "mods": {"mood": 0.03, "tour_mult": 1.5}, "inst": {"coins_pop": 1.0, "news": 0.2}, "msg": "Jets roar over an air show.", "say": "Did you see those jets?",
        "desc": "Needs a military base. Mood +3%, tourism x1.5 and 1 coin per citizen."},
    "conscription": {"n": "Conscription call", "cat": "Social", "w": 1, "minpop": 120, "dur": 60.0, "needs": Catalog.Id.BASE,
        "mods": {"mood": -0.04, "immig_mult": 0.7}, "msg": "Young people are called up for service.", "say": "My son got his papers today.",
        "desc": "Needs a military base. Mood -4% and immigration -30% for a minute."},
    "deployment": {"n": "Troops deployed", "cat": "Civic", "w": 1.5, "minpop": 120, "dur": 90.0, "needs": Catalog.Id.BASE,
        "mods": {"mood": -0.03, "income_add": 10.0}, "inst": {"news": -0.2}, "msg": "The garrison ships out on deployment.", "say": "The barracks are so quiet now.",
        "desc": "Needs a military base. Extra funding (+0.8 coins/s) but mood -3% and grim headlines."},
    "base_closure": {"n": "Base review", "cat": "Civic", "w": 1, "minpop": 120, "dur": 90.0, "needs": Catalog.Id.BASE,
        "mods": {"income_add": -10.0, "mood": -0.02}, "msg": "The ministry reviews the base budget.", "say": "They might close the base.",
        "desc": "Needs a military base. Funding falls 0.8 coins/s and mood -2% for 90 seconds."},
    "border_incident": {"n": "Border incident", "cat": "Disaster", "w": 1, "minpop": 100, "dur": 40.0, "scale": "defence",
        "mods": {"mood": -0.06, "sales_mult": 0.9}, "inst": {"news": -0.4}, "msg": "Tensions flare at the border.", "say": "Are we going to be attacked?",
        "desc": "Mood -6%, shop income -10% and bad news. Defence coverage cuts it by up to 70%."},
    "baby_boom": {"n": "Baby boom", "cat": "Social", "w": 2, "minpop": 50, "dur": 100.0,
        "mods": {"immig_mult": 1.6, "dem_res": 0.3}, "msg": "The maternity ward is full.", "say": "Another one on the way!",
        "desc": "Population grows 60% faster and housing demand rises for 100 seconds."},
    "immigrants": {"n": "Immigrant wave", "cat": "Social", "w": 3, "minpop": 20, "dur": 0.0,
        "inst": {"citizens": 8}, "msg": "A wave of newcomers arrives.", "say": "New neighbours at last.",
        "desc": "Up to 8 new citizens arrive immediately, if there are homes for them."},
    "exodus": {"n": "Exodus", "cat": "Social", "w": 2, "minpop": 30, "dur": 0.0,
        "inst": {"citizens": -6}, "msg": "Families leave for greener pastures.", "say": "We're moving away.",
        "desc": "Six citizens leave immediately."},
    "brain_drain": {"n": "Brain drain", "cat": "Social", "w": 1.5, "minpop": 100, "dur": 90.0,
        "mods": {"office_mult": 0.8, "cov_edu": -0.2}, "msg": "Graduates are leaving for bigger cities.", "say": "There's nothing for graduates here.",
        "desc": "Office income -20% and education coverage -20% for 90 seconds."},
    "election_win": {"n": "Mayor re-elected", "cat": "Social", "w": 2, "minpop": 60, "dur": 80.0,
        "mods": {"mood": 0.05, "tax_mult": 1.05}, "msg": "Voters re-elect the mayor.", "say": "Four more years!",
        "desc": "Mood +5% and tax income +5% for 80 seconds."},
    "recall": {"n": "Recall vote", "cat": "Social", "w": 1.5, "minpop": 80, "dur": 60.0, "scale": "gov",
        "mods": {"mood": -0.06}, "msg": "A recall vote shakes the council.", "say": "Time for a new mayor.",
        "desc": "Mood -6% for a minute. A town hall within reach softens it."},
    # ---- disaster ----
    "fire": {"n": "Fire", "cat": "Disaster", "w": 0, "minpop": 0, "dur": 0.0,
        "inst": {"ignite": 1}, "msg": "Fire! A building is ablaze. Build a fire station, or bulldoze a firebreak.", "say": "Fire!",
        "desc": "Sets one random building alight. Fires burn 14 seconds and spread unless a fire station is within 7 tiles."},
    "wildfire": {"n": "Wildfire", "cat": "Disaster", "w": 1.2, "minpop": 40, "dur": 0.0,
        "inst": {"ignite": 3}, "msg": "A wildfire sweeps in from the hills!", "say": "The whole hillside is burning!",
        "desc": "Sets three random buildings alight at once."},
    "earthquake": {"n": "Earthquake", "cat": "Disaster", "w": 0.8, "minpop": 50, "dur": 0.0,
        "inst": {"damage": 0.1, "ignite": 1, "coins_pop": -2.0}, "msg": "The ground shakes. Buildings crack and a fire starts.", "say": "Everything's shaking!",
        "desc": "About 10% of buildings lose a level, one fire starts and repairs cost 2 coins per citizen."},
    "power_outage": {"n": "Power outage", "cat": "Disaster", "w": 2.5, "minpop": 40, "dur": 30.0,
        "inst": {"blackout": 1}, "msg": "Blackout! A power plant has tripped.", "say": "Blackout!",
        "desc": "One power plant goes offline for 40 seconds. Spare plants on the same lines, or imports from neighbours, keep the lights on."},
    "water_main": {"n": "Burst water main", "cat": "Disaster", "w": 2, "minpop": 30, "dur": 40.0,
        "mods": {"cov_water": -0.6}, "msg": "A water main has burst.", "say": "There's a river in the road!",
        "desc": "Water coverage -60% for 40 seconds."},
    "gas_leak": {"n": "Gas explosion", "cat": "Disaster", "w": 1.5, "minpop": 30, "dur": 0.0,
        "inst": {"ignite": 1}, "msg": "A gas leak explodes!", "say": "Did you hear that bang?",
        "desc": "One building catches fire."},
    "collapse": {"n": "Building collapse", "cat": "Disaster", "w": 1, "minpop": 60, "dur": 0.0,
        "inst": {"destroy": 1}, "msg": "An old building collapsed.", "say": "That building just fell down!",
        "desc": "One random building is destroyed."},
    "epidemic": {"n": "Epidemic", "cat": "Disaster", "w": 1.5, "minpop": 60, "dur": 90.0, "scale": "health",
        "mods": {"mood": -0.03}, "inst": {"infect": 6}, "msg": "A nasty flu is spreading through the city.", "say": "Half the office is off sick.",
        "desc": "Six citizens fall ill. The sick stay home, spread it to housemates and co-workers, and some do not recover. Clinics and hospitals cure them faster and slow the spread."},
    "rats": {"n": "Rat infestation", "cat": "Disaster", "w": 1.5, "minpop": 40, "dur": 70.0,
        "mods": {"cov_waste": -0.3, "mood": -0.03}, "msg": "Rats have taken over the alleyways.", "say": "I saw a rat the size of a cat.",
        "desc": "Waste coverage -30% and mood -3% for 70 seconds."},
    # ---- civic ----
    "grant": {"n": "State grant", "cat": "Civic", "w": 3, "minpop": 20, "dur": 0.0,
        "inst": {"coins_pop": 3.0}, "msg": "The state sends a development grant.", "say": "Free money from the government!",
        "desc": "Instant 3 coins per citizen."},
    "fine": {"n": "Regulator fine", "cat": "Civic", "w": 1.5, "minpop": 50, "dur": 0.0, "scale": "gov",
        "inst": {"coins_pop": -2.0}, "msg": "The regulator fines the city.", "say": "Another fine for the council.",
        "desc": "Costs up to 2 coins per citizen. A town hall within reach softens it."},
    "garbage_strike": {"n": "Garbage strike", "cat": "Civic", "w": 2, "minpop": 40, "dur": 60.0,
        "mods": {"cov_waste": -0.7, "mood": -0.03}, "msg": "Refuse collectors are on strike.", "say": "The bins haven't been emptied in weeks.",
        "desc": "Waste coverage -70% and mood -3% for a minute."},
    "transit_strike": {"n": "Transit strike", "cat": "Civic", "w": 2, "minpop": 60, "dur": 50.0,
        "mods": {"cov_transit": -0.8}, "msg": "Bus and rail workers walked out.", "say": "No buses again!",
        "desc": "Transit coverage -80% for 50 seconds."},
    "teacher_strike": {"n": "Teachers' strike", "cat": "Civic", "w": 2, "minpop": 80, "dur": 50.0,
        "mods": {"cov_edu": -0.6}, "msg": "Teachers are on strike.", "say": "School's closed. Again.",
        "desc": "Education coverage -60% for 50 seconds."},
    "road_works": {"n": "Road works", "cat": "Civic", "w": 3, "minpop": 30, "dur": 60.0,
        "mods": {"speed_mult": 0.8, "upkeep_mult": 1.05}, "msg": "Road works are clogging the streets.", "say": "Detour after detour.",
        "desc": "Walking 20% slower and upkeep +5% for a minute."},
    "parade": {"n": "Street parade", "cat": "Civic", "w": 3, "minpop": 40, "dur": 30.0,
        "mods": {"mood": 0.06, "tour_mult": 1.3}, "msg": "A parade marches down the main street.", "say": "Look at the floats!",
        "desc": "Mood +6% and tourism +30% for 30 seconds."},
    "festival": {"n": "Hold a festival ($40)", "cat": "Civic", "w": 0, "minpop": 0, "dur": 30.0, "cost": 40.0, "player": true,
        "mods": {"mood": 0.2, "sales_mult": 1.15}, "msg": "Festival! Spirits rise.", "say": "Best festival ever!",
        "desc": "Costs 40 coins. Mood +20% and sales +15% for 30 seconds. Only you can call it."},
}


static func pick(rng: RandomNumberGenerator, pop: int, active: Array[String], recent: Dictionary, day: int, has: Dictionary = {}, sw: Dictionary = {}) -> String:
    var total := 0.0
    var opts: Array[String] = []
    var ws: Array[float] = []
    for id in EVENTS:
        var e: Dictionary = EVENTS[id]
        var w := float(e["w"]) * float(sw.get(id, 1.0))
        if e.has("needs") and not has.has(int(e["needs"])):
            continue
        if w <= 0.0 or pop < int(e["minpop"]) or active.has(id) or day - int(recent.get(id, -99)) < 2:
            continue
        opts.append(id)
        ws.append(w)
        total += w
    if opts.is_empty():
        return ""
    var r := rng.randf() * total
    for i in opts.size():
        r -= ws[i]
        if r <= 0.0:
            return opts[i]
    return opts[opts.size() - 1]


static func describe(id: String) -> String:
    var e: Dictionary = EVENTS[id]
    var s := "[b]%s[/b]   [color=#9aa88f]%s event[/color]\n" % [e["n"], e["cat"]]
    s += "Appears from pop %d   Duration %s\n\n" % [e["minpop"], ("%d s" % int(e["dur"])) if float(e["dur"]) > 0.0 else "instant"]
    s += String(e["desc"])
    if e.has("scale"):
        s += "\n\n[color=#9fd3a0]Softened by %s coverage.[/color]" % String(Catalog.METRICS[e["scale"]]["n"]).to_lower()
    return s
