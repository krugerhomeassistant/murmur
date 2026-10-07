# Changelog

All notable changes to Murmur are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Performance: utility-network solve is cached by layout signature (sim tick about 2x cheaper); off-screen towns tick in 0.5 s batches and refresh crime/land value every 3rd second; `place()`/`bulldoze()` defer the rescan to once per frame (2.8 ms to 2 us per tile); land-value pass hoists modifier lookups; sim catch-up per frame is capped.
- Rendering: the map is split into 16x16-tile chunks. Zoomed in they are baked to textures, mid zoom draws simple blocks, far zoom draws flat tiles (dense 96x64 test town: 7 fps to 300+ fps zoomed out, 26 to 66 fps at zoom 1.25).
- HUD updates skip no-op theme overrides and throttle the Build menu button refresh.

### Added
- Click a tile with the Inspect tool to pin its info card (live updating, click again to close).
- F3 overlay: fps, sim ms, draw ms, towns. `tests/bench*.gd`, `tests/region.gd` (8 towns), `tests/netcache.gd`, `tests/place.gd` for headless profiling.

### Fixed
- Top bar clock clipped ("Day 33 04:21 S") and the RCIO/utility strip overlapping the menu row.

## [0.1.0] - 2026-10-07

### Added
- Start menu with game setup (towns, neighbour temper, difficulty, land, auto-growth, rivers) and a new-player guide.
- Region of neighbouring towns on a grid with a region map; trade, commuters and utilities flow through border roads.
- Diplomacy and war: pacts, alliances, embargoes, battles with land capture, garrison and war weariness.
- Art pass: service buildings, grown zone buildings, Build menu icons, ground detail.
- Rivers (random or painted in the world editor), bridges, animated water with fish, ports, naval yards and ships, fishing docks, river health.
- Sewage network (plant and sewer pipes), always-visible demand and utility strip, map hover card.
