# TOOLING_AND_MCP

## Active
| Tool | Use | Why |
|---|---|---|
| Godot 4.7.2 (user PC, `C:\Users\king-\workspace\tools\godot`) | the game | 2D, GDScript, free |
| Godot AI plugin + `godot-ai` MCP | create scripts/scenes, run game, read logs, screenshots, simulate input | already installed; user confirmed working |
| Blender 5.2.2 + `blender` MCP | art phase assets | installed, confirmed working |
| Device bridge (`remote-devices`) | move files to/from user PC | linked |
| Linux Godot in sandbox (if downloadable) | headless selfcheck of `city.gd` | fast logic verification without the PC |

## Notes
- The godot-ai session is bound to the project open in the editor. Use `session_manage list` to see which. Murmur needs its own editor window opened via `Open Murmur in Godot.bat`.
- Node 24 LTS + `ws` for the server in Phase 5 only.

## Considered, not used
- X/Twitter API: paid. GitHub REST `/events`: 60 req/h. Colyseus etc.: not needed. Database: not needed yet.

## Custom scripts
None yet. Selfcheck: `City.selfcheck()` run at startup (prints `SELFCHECK_OK`).

## v7 workflow notes
- godot-ai: `filesystem_manage scan` before `project_run`; `game_eval` aborts ~8s -> long runs in a Thread, read back later.
- Soak: new City, loop `c.sig.tick(0.25); c.tick(0.25)`; check `City.selfcheck()` -> SELFCHECK_OK.
- Editor autosave tab-converts city.gd/main.gd; patch scripts must normalise indentation.
- Headless test: `godot --headless -s tests/smoke.gd`.
