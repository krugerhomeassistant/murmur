# Murmur: Game Design Document

Working title. A cozy city-builder you steer, in a world that keeps changing. The base game is fully playable offline on simulated world events. An optional **Live Data** layer swaps those events for real ones (weather, news, markets, quakes, ...). A separate **Earth view** mode (much later) shows the real planet.

## 1. Pillars
1. **Fun first, playable early.** Every phase ends with something you can play. No data plumbing before there is a game.
2. **One engine, two worlds.** The city only reads **signals** (market, news mood, weather, ...). Simulated or live, it cannot tell the difference. Live data is a toggle per signal, never a rewrite.
3. **You steer, the world pushes.** You decide (build, tax, policy, respond). The world changes the conditions. Neither side runs the game alone.
4. **Honest data.** With Live on, signals come from real feeds and the HUD says so. With it off, nothing pretends to be real.
5. **Readable and natural.** Muted, normal city palette (no neon). The mood of the city should be visible at a glance.
6. **Private by design.** Citizens represent events, never real people. No usernames, handles or faces from any feed.

## 2. Core loop
Observe the city -> a world event hits (rain, market crash, scandal) -> decide how to respond (spend, change tax, build, hold a festival) -> see the city react -> grow.

**Player verbs**
- Build: road, house, shop, workshop, park; bulldoze. Buildings only work when adjacent to a road.
- Policy: tax rate (more income vs lower mood).
- Respond: festival (costs coins, lifts mood), later: police, subsidies, curfew.
- Sandbox: fire world events yourself (crash, scandal, storm...) and watch the city cope. Same code path as random and, later, live events.

## 3. Signals: the seam
| Signal | Range | Simulated source (base game) | Live source (optional, later) |
|---|---|---|---|
| `weather` | clear / rain / heatwave / storm | random weather spells | Open-Meteo `current` |
| `market` | -1..1 | boom / crash events, decays to 0 | Coinbase trades trend |
| `news` | -1..1 | good news / scandal events, decays to 0 | GDELT tone |
| `quake` (later) | 0..1 | random tremors | USGS |
| `buzz` (later) | 0..1 | random | Bluesky / Wikipedia / GitHub activity |

Rule: only `Signals` is read by the city. Sources only write into it.

## 4. Simulation rules (prototype, to be tuned by playtest)
- **Grid:** 40 x 18 tiles. Tile types: empty, road, house, shop, workshop, park.
- **Connected** = a 4-neighbour is a road (parks exempt). Unconnected buildings are dimmed and do nothing.
- **Housing** 4 per connected house. **Jobs:** 3 per shop, 5 per workshop.
- **Population** grows toward housing while mood > 0.4, shrinks when mood < 0.2 or over housing.
- **Income** = (employed x tax x 12 + sales x 0.8 + goods x 1.2) x (1 + 0.5 x market), minus upkeep, x a global rate constant.
- **Mood** moves toward a target: 0.55 + park bonus - tax penalty + news x 0.3 - weather penalty - unemployment x 0.3 + festival bonus.
- **Protest** when mood < 0.2: citizens gather in the middle, income -30%.
- **Citizens:** dots that walk between home, work and parks. Visual only, one dot per person up to a cap.

## 5. Live Data layer (optional, built after the game is fun)
- **Per-signal toggle** in a settings screen. HUD shows a LIVE badge on any signal that is real.
- **Client-direct first:** weather, quakes and news tone are plain HTTP polls, so Godot can fetch them with no server.
- **Server later:** firehose feeds (Bluesky, Wikipedia, Coinbase, GitHub archive) are aggregated by a small Node server into the same signals. The server also enables **Live cities** that keep running while the game is closed.
- **Location:** player picks any place (Open-Meteo geocoding). Coarse (~25 km) location filters feeds. Thin local data falls back outward: local -> country -> world. The city map stays procedural and never resembles the real place.
- **Live or Paused city** (per city): Live keeps ticking on the server while closed; Paused freezes on close. Missed real events are not replayed.
- **Privacy:** location is a filter only; never shown, never kept past the session, only rounded coordinates leave the machine.

| Feed | Source (verified 2026-10-07) | Localizes by |
|---|---|---|
| Weather | Open-Meteo, no key, non-commercial | lat/lon |
| Quakes | USGS `all_hour.geojson` | distance |
| News tone | GDELT 2.0 (15 min) | event location / country |
| Markets | Coinbase `market_trades` WS (no auth, beta) | local currency pair if listed |
| Wikipedia | Wikimedia EventStreams SSE | local-language wiki |
| Social | Bluesky Jetstream | language / place names |
| Code | GH Archive hourly dumps (keyless) | global only |
| Flights (later) | OpenSky (anon 400 credits/day) | bounding box |

X/Twitter skipped: paid API.

## 6. Earth view (separate mode, much later)
A look-only picture of the real planet right now, built on the same data server. Treated as its own mode so it does not dilute the game.

## 7. Art direction
Muted natural palette, readable at a glance. Prototype is flat 2D top-down in Godot. 3D vs 2.5D is decided after playtesting the prototype; Blender via MCP for assets in the art phase.

## 8. Roadmap
See PLAN.md. In order: playable offline prototype -> depth and feel -> Live Data v1 (client-direct) -> location picker -> firehose server -> art pass -> always-on Live cities -> Earth view.

## 9. Open questions
- Keep 2D top-down, or go isometric / 3D? (after prototype playtest)
- Hosting provider and budget (only when Live cities are built; user creates the account).
- Publish publicly or personal only? Affects non-commercial feed terms (Open-Meteo, GDELT).
