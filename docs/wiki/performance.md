# Performance notes

Implementation notes for the simulation and renderer. Measured numbers live in the README benchmark table (standard benchmark: 8 towns, 8x, all overlays, windowed).

- Sim: `City._net` caches the flood-fill by `hash([grid,lvl,layer,connected,offline,cells,mods])`; `_net_solve` is the pure solve. Off-screen towns (`lod=3`) tick in 0.5 s batches (`pend`) and run `_crime`/`_land` every 3rd second. `place()` sets `scan_dirty`; `flush()` rescans once per frame. Main caps owed sim time at 20 steps.
- Render: `TileLayer` chunks (16x16 tiles) are children of Main (`show_behind_parent`). `Main._lod()`: 0 (zoom >= 1.2) full art baked to a 2x SubViewport texture, 1 (0.7-1.2) block buildings, 2 (<0.7) flat tiles. Chunks re-record at `chunk_hz` within a `CHUNK_MS` budget; `chunk_kick` forces a refresh on edits/town switch/LOD change. Dynamic things (citizens, cars, boats, fire, lights, overlays, weather, cursor) are still drawn by `Main._draw` every frame.
- Tools: F3 overlay; `godot --headless -s tests/bench.gd | bench2.gd | region.gd | place.gd | netcache.gd`.

See also [Controls](controls.md) for the `--benchmark` flags and [World](world.md) for the world layer's bake budget.
