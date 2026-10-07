# WIKI: Murmur

## Purpose
A cozy city-builder you steer while the world around it changes. Base game is offline and simulated; an optional Live Data layer makes the world real. Full design: `GAME_DESIGN.md`.

## Glossary
- **Signal**: a world condition the city reacts to (`market`, `news`, `weather`, later `quake`, `buzz`).
- **Source**: whatever writes a signal: simulated events, or a live feed.
- **Seam**: the `Signals` object. City reads it; sources write it.
- **Connected**: a building with a road on a 4-neighbour tile. Only connected buildings work.
- **Mood**: 0..1 city happiness. Drives growth and protests.
- **Protest**: mood below 0.2. Citizens gather mid-map, income -30%.
- **Festival**: player action, costs coins, lifts mood for 30 s.
- **Live city / Paused city**: (later) keeps simulating on a server while closed / freezes on close.
- **Ring**: (later) data radius: local, country, world, used when local data is thin.

## Business rules
- City reads only Signals, never feeds.
- With Live on, the HUD shows a LIVE badge on real signals. Nothing simulated is labelled real.
- Privacy: no usernames, handles or faces from any feed. Public headlines allowed.
- Location (later): player-picked, coarse (~25 km), filter-only, never displayed or kept past the session.

## Controls (prototype)
Left click / drag: place. Keys 1-6: Road, House, Shop, Workshop, Park, Bulldoze. Space: pause. Buttons: tax, world events, festival, speed.

## Economy numbers
See GAME_DESIGN.md section 4. Tuned after playtest; final values recorded here.

## Feed rates
Measured in Phase 5. Empty until then.

## v5 gameplay
36 buildings in 10 categories (build menu accordion), 13 city stats (Stats tab, Overlays menu), 10 policies, ~46 events (World events menu by category; also random). City auto-grows: planner zones plots by demand and extends roads (City menu / Policy tab: auto-growth off/zones/zones+roads). Every building/stat/policy/event has a description: hover in build menu, Codex tab, tooltips.

## v8: Mayor, seasons, streets, disasters, economy (2026-10-07)
### Mayor's office (window)
- **Approval** 0..1: target = 0.35 + 0.5·mood + 0.08·clamp(income/2) − 0.1·crime + 0.3·Σ(tribe share·(opinion−0.5)) + rep − debt/tax penalties; moves 0.004/s.
- **Petitions**: a tribe asks every 70-130 s (max 3 open, answer within 2 days). Accept = promise with deadline; delivered → kept (+0.06 rep, +0.2 tribe favour); missed → broken (−0.1 rep, −0.3 favour). Decline/ignore → −0.12 favour, −0.02 rep. Favour adds to tribe satisfaction.
- **Elections** every 28 days (end of winter, day 29, 57...). Vote = approval ± 4%. Under 50% = game over ("Voted out"). Rally ($150, last 7 days, once) = +0.07 rep.
- **Advisors**: Treasurer, Police & fire chief, City planner, Health & welfare, Campaign manager (they can disagree).
- **Goals**: 18 milestones with coin rewards; rank Hamlet→Village→Town→City→Metropolis by peak pop.
### Seasons (7 days each, year = 28 days)
Spring immigration +15%; Summer tourism +30%, fires +30%; Autumn harvest ×1.8; Winter upkeep +10%, power demand +25%, harvest ×0.2. Each season reweights weather events (Civics.SEASONS.ev). Ground colour follows season.
### Living streets
Citizens with commute >9 tiles and no transit drive cars (2.2× speed). Traffic = EMA of cars per road cell; jams above 3 (road) / 8 (avenue) slow cars and add congestion (mood −0.08·congestion). Planner widens jammed roads into avenues. Each bus stop runs a visible bus. Night: car/bus headlights, lamp glow. Overlay: Traffic.
### Disasters
Tornado: twister crosses the map (3 cells/s), destroys buildings, cuts lines. Epidemic: citizens fall sick, stay home, spread to housemates/co-workers, may die; health coverage cures faster. Blackout: one power plant offline 40 s. Damage/destroy events + tornado create a **recovery decision**: pay $20/building to restore instantly, or let it recover. Disaster insurance policy pays $30 per destroyed building.
### Economy
Farms → crops (×season harvest) → Food mill (3/s) → food. Industry → goods. Needs: food 0.05/citizen/s, goods 0.03/citizen + 0.02/shop job. Shortfall imported (food 1.5, goods 2.0 × RATE × market price). Storage cap 60 + 250/warehouse; stock above 80% (20% with a depot) exported; trade depots +25% export price. Loans: small $500/8d/10%, bank $1500/16d/18% (pop 60), bond $4000/40d/25% (pop 150); max 3.
### Save / sound
Autosave every new day + on window close to user://murmur_save.bin; City menu: Save now, New city. Generated sound: traffic hum, rain, birds, crickets, cues for build/petition/milestone/disaster; mute and volume in City menu.

## v9: growable map + neighbour + diplomacy (2026-10-07)
- **Map** is 96x64; you own a rectangle (`terr`, starts 48x32 in the middle). Region tab > Your land: buy an 8-cell strip N/E/S/W. Cost $120 x (1 + 0.5 x purchases made). Auto-annex (default on): the planner buys the most built-up side when it has no room left beside roads and holds 1.5x the price. Unowned land is dimmed; building there is refused. No upper limit except the map edge, so the game is endless.
- **Neighbour**: every new game starts with Brookfield (friendly, temper +0.2), run entirely by the planner and kept alive by the state (`human=false`, cannot be lost). Switch via Towns menu. Founded towns: Ashby (temper -0.25, prickly), Northgate (0.05).
- **Relations**: each town has an opinion of the other (-1..1) drifting toward its temper + treaty (pact +0.4, alliance +0.7, embargo -0.8) + trade flow, minus fear (their military 0.5+ above yours) and envy (they are 2x your size). Stance: Hostile < -60%, Tense < -20%, Neutral < 20%, Friendly < 60%, Warm.
- **Trade multiplier** (power/water imports, commuters) = clamp(0.6 + 0.5 x avg relation, 0.2, 1.3), x1.25 pact, x1.4 alliance, 0 embargo.
- **Your actions** (Region tab): Gift $100, Trade pact $200 (relation >= 15%), Alliance $400 (pact + relation >= 55%; +25% defence coverage), Embargo/Lift, Demand tribute (needs clearly stronger military), Peace $150, Cancel treaty.
- **Events** every 45-90 s per pair: friendly (festival, cultural exchange, aid, they offer a pact), neutral (trade fair), hostile (spat, smuggling crime wave, border incident, river diversion, tribute demand, raids). Raids destroy up to 3 buildings (defence coverage cuts it) and offer a rebuild decision. Offers and demands appear in the Mayor's office > Decisions.
- **Street lamps** sit on road tiles; planner keeps them 3 tiles apart, you 2.
- Saves from before this version are ignored (map size changed).

## Start menu
Shown at launch. Options: town name, starting towns (1-4), neighbour mood, difficulty (Relaxed $600 / Normal $300 / Hard $150, event frequency x1.5/1/0.7 inverse), starting land (40x24/48x32/64x40), auto-growth, auto-policy, auto-annex. "Continue saved game" appears when a save exists. Up to 6 towns total via Towns menu.

## Guide
guide.gd: 10-step new-player guide (bottom centre). Start menu checkbox, City menu > Show the guide. Steps with chk auto-complete.

## Region, borders, war
Towns sit on a region grid (square spiral from your town; gpos). A town's 4 sides face N/E/S/W neighbours. Trade (power/water imports, commuters) flows only between ORTHOGONALLY adjacent towns where BOTH towns have a road within 3 tiles of the shared border that belongs to the town's biggest connected road network (City._road_net -> gate[]); planner towns lay that road themselves (City._plan_gate). The region is one continuous world: every town is drawn at its grid offset (Main.origin), the viewed town (city) is the one under the camera centre, clicking another town glides the camera there, key M (or Towns menu) toggles fit-the-whole-world. Below zoom 0.25 each town shows a live thumbnail and its name (TownLayer, LOD 3). No town cap. War: Diplo.act(..,"war") calls up a militia; real units (Military.KIND, 13 types): infantry (rifleman, grenadier, sniper, medic), armour (light/battle/heavy tank, artillery, anti-air), air (strike jet, fighter, bomber, helicopter). Each has hp, range, damage, cost, upkeep, a target class (soft/armor/air) and damage multipliers against each class, and per-building capacity (`cap`; air types besides the helicopter also need 2 slots per radar post). Auto-trained when coins allow (City.train_on, per-kind priority City.train_w 0-3, edited in the Army window), deployed to the front between the towns (Military.line) and fought once per sim second (Military.fight): units pick the target that maximises damage/distance (so AA hits planes), medics heal 3 wounded allies in range and stay behind the line, and damage dealt or healed earns rank (Veteran 250, Elite 800, Legend 2000: +15% damage and +10% hp per rank). Attackers standing unopposed on the border raid it (buildings lost, loot) and raise City.occ; 40 s of occupation = surrender + reparations/annex (Diplo.surrender). Armies spent after 10 minutes = ceasefire. Peace needs >=60 s of war. AI declares war at rel < -0.7 with military edge.

War spoils: winning (3 battles ahead) makes the loser cede an 8-tile strip (City.cede) that the winner annexes free; soldiers pace the front line while at war.

War weariness: each war -3% mood, -0.4% per battle; approval target -4%/war, -1.2%/battle (cap 12). Victory +10% rep, defeat -10%. Garrison policy: +30% defence cover. General advisor appears at war.

## Art
art.gd (class Art): hand-drawn 32x32 sprites from primitives for all 39 service buildings (animated: turbine, ferris wheel, bus, train, smoke, radar, mill, flags, police lights) plus empty-zone lot sketches. Called from main._service/_zone. Add a building: add id to Art._has and a match arm in Art._draw.

## Art pass 2
- Art.building (zone sprites by shape/level), Art.icon + Art.IconView (Build menu icons via SubViewport UPDATE_ONCE), Art.ground (tufts/flowers/trees, river band outside owned land at y=3).
- Wired: main._building, main draw loop (EMPTY cells), hud._tool_btn.

## Rivers (v1)
- `City.water` (1 = river, saved). `gen_river(seed, mode)` makes a meandering river beside the start plan; none in old saves. Setup option "Rivers".
- Zones/services cannot be built on water (place() and planner skip it). Roads over water = bridges, cost x`BRIDGE_X` (4). Wires/pipes may cross.
- Art.water (ripples, banks, swimming and jumping fish), Art.bridge (deck+rails).

## Sewage
- Third utility network (City.NETS = power, water, sewage). `City.sewer` layer, Sewage plant (Id.SEWAGE, out sewage 16, unlock 40) and Sewer pipe (Id.SEWER). Same rules as water: plant must touch a connected sewer, buildings touching a live line are served, over-demand lowers satisfaction. Need metric "sewage" (mood -10% uncovered). Planner lays sewers and builds plants.
## HUD
- Top-right strip under the menu bar: R/C/I/O demand bars and P/W/S supply/demand (red = shortage). Hovering a map cell shows a floating card (Hud._maptip_text): building, level, residents/workers, road access, power/water/sewer, land value.

## World editor, ports, navy
- Setup "Rivers: Custom" starts paused with the Paint water tool (Build menu: Paint water / Remove water, free, empty ground only; `City.set_water`). Tools WATER_ADD=96, WATER_DEL=97 in main.gd.
- Port (trade, counts as 2 depots for export prices, 10 jobs) and Naval yard (mil, +0.35 war strength, 20 jobs, grant) must touch water (`Catalog "water": true`, `City.wet_next`), need road access, are never built by the planner. Cargo ships/warships sail the river beside them (`main._boats`, `Art.boat`).

## Fishing and river health
- Fishing dock (water-adjacent, 6 jobs): ~0.15 food/worker/s into stock, scaled by `City.river_health`. River health falls toward (sewage treated / produced) once pop > 20; polluted water turns green and fish vanish. Hover a river tile to see health.

## Performance
- Sim: `City._net` caches the flood-fill by `hash([grid,lvl,layer,connected,offline,cells,mods])`; `_net_solve` is the pure solve. Off-screen towns (`lod=3`) tick in 0.5 s batches (`pend`) and run `_crime`/`_land` every 3rd second. `place()` sets `scan_dirty`; `flush()` rescans once per frame. Main caps owed sim time at 20 steps.
- Render: `TileLayer` chunks (16x16 tiles) are children of Main (`show_behind_parent`). `Main._lod()`: 0 (zoom >= 1.2) full art baked to a 2x SubViewport texture, 1 (0.7-1.2) block buildings, 2 (<0.7) flat tiles. Chunks re-record at `chunk_hz` within a `CHUNK_MS` budget; `chunk_kick` forces a refresh on edits/town switch/LOD change. Dynamic things (citizens, cars, boats, fire, lights, overlays, weather, cursor) are still drawn by `Main._draw` every frame.
- Tools: F3 overlay; `godot --headless -s tests/bench.gd | bench2.gd | region.gd | place.gd | netcache.gd`.

## Shared rivers
Setup Rivers = 'One river through neighbouring towns' (default). Main._fresh picks horizontal/vertical, takes the row/column of the player's town, and gives each town `river_plan {horiz,a,b}` (cross-span fractions at its entry/exit borders from `_edge_frac(seed, k)`); `City._gen_shared_river` draws it with wobble/width tapering to fixed values at the territory edges so neighbours match. Towns founded later still get their own random river.
