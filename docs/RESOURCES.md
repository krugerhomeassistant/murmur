# RESOURCES

## Project files
- `GAME_DESIGN.md`: vision, feeds→city mapping, sim rules, roadmap
- `PLAN.md`, `wiki/` (the wiki, see wiki/README.md), `LESSONS_LEARNED.md`, `RESOURCES.md`, `TOOLING_AND_MCP.md`, `ACTIVE_CONTEXT.md`, `ARCHITECTURE.md`
- `server/` (Phase 1+), `client/` (Godot project, Phase 2+)
- User PC: `E:\Projects\Personal\game\murmur\`; tools in `C:\Users\king-\workspace\tools\` (Godot 4.7.2, Blender 5.2.2)

## Feed endpoints (verified 2026-10-07)
- Wikimedia EventStreams: `https://stream.wikimedia.org/v2/stream/recentchange` (SSE). Docs: https://wikitech.wikimedia.org/wiki/Event_Platform/EventStreams
- Coinbase Advanced Trade WS: `wss://advanced-trade-ws.coinbase.com`, channel `market_trades`. Docs: https://docs.cloud.coinbase.com/advanced-trade/docs/ws-channels
- Bluesky Jetstream: `wss://jetstream.us-east.bsky.network/xrpc/network.bsky.jetstream.subscribeEvents` (v2) or `wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post`. Docs: https://bsky.network/docs/jetstream, https://github.com/bluesky-social/jetstream
- GDELT 2.0 (15-min updates): DOC API `https://api.gdeltproject.org/api/v2/doc/doc`. Docs: https://blog.gdeltproject.org/gdelt-doc-2-0-api-debuts/
- GH Archive: `https://data.gharchive.org/YYYY-MM-DD-H.json.gz`. Docs: https://www.gharchive.org/
- GitHub REST rate limits: https://docs.github.com/rest/using-the-rest-api/rate-limits-for-the-rest-api
- USGS: `https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson`
- Open-Meteo: `https://api.open-meteo.com/v1/forecast?latitude=..&longitude=..&current=temperature_2m,weather_code,wind_speed_10m`
- Open-Meteo geocoding (city search): `https://geocoding-api.open-meteo.com/v1/search?name=..&count=5`
- OpenSky: `https://opensky-network.org/api/states/all`. Client/auth: https://github.com/openskynetwork/opensky-api

## Engine / runtime
- Godot `WebSocketPeer`: https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html
- Node release schedule: https://github.com/nodejs/release#release-schedule

## Env / config
None yet. Future: `GITHUB_TOKEN` (optional), `OPENSKY_CLIENT_ID` / `OPENSKY_CLIENT_SECRET` (optional), `PORT`.

## v8 files
- client/scripts/civics.gd: seasons, petitions, milestones, ranks, loans (data)
- client/scripts/world.gd: endless procedural terrain generator (class World)
- client/scripts/sfx.gd: generated audio (AudioStreamGenerator)
- user://murmur_save.bin: autosave (store_var of {towns:[City.to_dict()], cur, sig})
