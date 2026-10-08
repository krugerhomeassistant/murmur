# Controls, interface and files

Everything the player can press, click or choose, plus where the game keeps its files and how it is started and tested. Hotkeys are raw key codes handled in code: `project.godot` defines no input map.

Related pages: [world](world.md) (camera limits and zoom levels), [empire](empire.md) (Empire window and pop-out windows), [multiplayer](multiplayer.md) (chat and network flags), [buildings](buildings.md), [stats](stats.md), [policies](policies.md), [events](events.md), [constants](constants.md).

## Summary

- Left click builds or inspects, right or middle drag pans, the wheel zooms, Space pauses, M shows the whole region.
- The HUD has a top bar (speed buttons, status labels, five menus), six floating windows (Build, City panel, Hover details, Mayor's office, Army, Empire) and a message line at the bottom.
- The City panel has eight tabs: Info, Budget, Stats, People, Region, Policy, Events, Codex.
- A new game is configured on the start menu (eleven options plus a Multiplayer button).
- The game autosaves to `user://murmur_save.bin` at the start of every day and on closing the window.
- Command-line flags after `--`: `--benchmark` (`--war`, `--watch`), `--selfcheck`, `--server` (`--port`, `--towns`, `--speed`), `--join` (`--mp-test`), `--capture` (`--every`).

## Keyboard

All handled in `Main._unhandled_input` and `Main._process` (`client/scripts/main.gd`). Keys are ignored while a text field has focus (the pan keys are too). Nothing except F9 does anything before a game has started.

| Key | Action | Notes |
|---|---|---|
| W A S D, arrow keys | Pan the camera | Polled each frame with `Input.is_key_pressed`: 700 / zoom world pixels per second. Cancels a camera glide. This polling is not skipped while a text field has focus (see Open questions). |
| Space | Pause or resume | Toggles `speed` between 0 and 1 (it goes to 1x even if you were at 3x or 8x). |
| Q or Esc | Select the Inspect tool | Esc also cancels town-founding mode ("Founding cancelled."). While the chat input is open, Esc closes it first (`ChatBox._input`). |
| B | Select the Bulldoze tool | |
| 1 | Road tool | Top-row digits only. |
| 2 | Residential zone tool | |
| 3 | Commercial zone tool | |
| 4 | Industrial zone tool | |
| 5 | Park tool | |
| 6 | Fire station tool | |
| M | Zoom out to the whole region, press again to come back | `Main.toggle_map`; see [world](world.md#the-region-map-m). |
| Tab | Switch to the next town | Only in spectator mode (`Main.spectating()`); otherwise nothing. |
| F | Toggle auto-follow | Headline "Auto-follow on/off." The camera only moves by itself when spectating. |
| T | Toggle auto-training of troops | `Cmd` `train`, headline "Auto-train troops on/off." |
| R | Restart after game over | Only when the viewed town's `over` is set (`Main.new_game`). |
| Enter, keypad Enter | Open the chat input | Only in a network game (`ChatBox` exists). Enter sends, Esc cancels. |
| F3 | Performance overlay | A label at the top left: `N fps   sim X ms   draw Y ms   towns N`. |
| F9 | Run the standard benchmark | Works even on the start menu. See Benchmark below, including the save-file warning. |

Hotkeys also work from a popped-out window (see [empire](empire.md#pop-out-windows)) unless a text field there has focus.

## Mouse

| Action | Effect |
|---|---|
| Left click | With a building, zone, road or water tool: place on the cell under the cursor. With Bulldoze: remove. With Inspect: select a citizen or pin a tile card. In founding mode: found a town on the plot under the cursor. Clicking on another town's plot with any tool glides the camera there instead. |
| Left drag | Repeats the tool for each mouse-motion event while the button is held (road, zone, bulldoze, water paint). Inspect does nothing on drag. The code acts on the cell under the cursor at each event and does not fill in cells between two events, so a fast drag can leave gaps. |
| Right or middle drag | Pan: `camera -= motion / zoom`. Cancels a glide. |
| Wheel up / down | Zoom in / out by a factor of 1.1 per notch, clamped to 0.03 to 2.5. Zooms about the screen centre (the camera position does not move). Clears the remembered "fit" zoom of M. |
| Hover over the map | Shows the floating tile card (see Information cards) when the cursor is not over a window. |
| Title bar of a window | Drag to move; **Out**, **-** and **x** buttons (see Windows). |

Feedback in the message line when a placement fails: "X unlocks at population N." (locked building), "That land isn't yours yet. Annex it from the Region tab." (outside your territory), "Street lamps go on a road tile, at least 2 tiles from another lamp.", "Not enough coins." (empty cell, cannot pay). Successful placement and bulldoze play short sounds.

## Tools

Tool ids are in `main.gd`: `WATER_ADD` = 96, `WATER_DEL` = 97, `INSPECT` = 98, `BULLDOZE` = 99; any other value is a building id from `Catalog.Id`. The tool is reset to Inspect whenever a game starts (`Main._begin`). All tools act on the **viewed** town.

| Tool | How to select | What it does |
|---|---|---|
| Inspect | Q, Esc, or the button | Click a citizen who is walking (the nearest within 0.7 tiles) to see their home, work, commute, activity and thought in the Info tab, or click a tile to pin its info card; click the same tile again, or click a citizen, to close it. Clicks outside the viewed town's plot never reach the tool (they glide to another town instead). |
| Bulldoze | B or the button | Removes the street lamp on the cell first; on empty ground removes wire, pipe and sewer lines; otherwise removes the building or road (`City.bulldoze`). No refund. Only inside your territory. |
| Paint water / Remove water (editor) | Buttons | Free. Paints or erases river on empty ground, inside your territory (`Cmd` `water`). Start menu "Custom: I paint it" selects Paint water and pauses the game. |
| Roads, zones, services, utilities | Build menu, keys 1 to 6 | One building per click or drag event. Zones are painted cell by cell: a zone starts as an empty plot and a building appears on its own once demand and utilities allow. Roads laid over water become bridges at 4 times the price. |

A tool for a service building draws a faint circle of 0.9 times its radius around the cursor. The Details window shows the selected building's description. Everything that costs money checks your coins and the unlock level (`City.place`).

## The screen

### Top bar (`Hud._top`)

Left to right:

| Item | Content |
|---|---|
| Pause, 1x, 3x, 8x | Set the simulation speed to 0, 1, 3 or 8. The game runs slower than asked if it cannot keep up: at most 6 ms of simulation work per frame (`SIM_BUDGET_MS`) and never more than 20 steps owed (`Main._process`). |
| Clock | Town name, clock and season. A day is 60 simulation seconds. |
| Coins | `$` and treasury with net income per second; red when negative. Below -150 the town goes bankrupt. |
| Pop | Population / housing. |
| Jobs | Employed / total jobs. |
| Mood | Percent and a bar. |
| Approval | Percent; red under 50. Elections are every 28 days. |
| World events | Menu of events by category (see below). |
| Windows | Menu of windows. |
| Towns | Menu of towns. |
| Overlays | Menu of map overlays. |
| City | Menu for auto-growth, saving, guide, sound. |

Top right (under the bar): four small bars R, C, I, O for the demand for new residential, commercial, industrial and office zones (up means people want more) and a utilities label `P s/d  W s/d  S s/d` for power, water and sewage supply / demand, with `!` and red text on a shortage.

Bottom: the message line (`Main.headline`). In multiplayer the chat lines sit above it at the left.

### Menus

**World events** (`Hud._top`): submenus Weather, Economy, Social, Disaster and Civic list every world event; entries that cost or require an action by you are marked "(you)", and hovering shows the description. Choosing one calls `City.trigger` on the viewed town (Fire calls `City.ignite`); a failure shows "Could not trigger X (not enough coins?)." These are sandbox triggers, not commands. All events are on [events](events.md).

**Windows**: check items Build menu, City panel, Hover details, Mayor's office, Army, Empire (all towns), Market; "Reset window layout".

**Towns**: one entry per town as `> Name  (pop N)` with `>` on the viewed town (click to glide there); "Whole world (M)"; "Found a new town (from $300)" (see [world](world.md#founding-a-town)).

**Overlays** (`Main._overlay`, drawn on every town in view except at the whole-world zoom level 3):

| Entry | Drawing |
|---|---|
| None | Off. |
| ALL (everything at once) | Brown tint for pollution, red tint for crime, six dots on every non-road building (power, water, fire, police, health, leisure) green when coverage is above 0.3 and red otherwise, and the word FIRE on burning buildings. |
| Crime | Red, stronger with more crime. |
| Land value | Colour from red (low) to green (high). |
| Traffic | Road tiles from green to red; roads jam above 3 and avenues above 8. |
| Pollution | Brown. |
| Coverage: (one for each of the 17 stats) | Green where the stat reaches the cell, faint red where it does not. The stats are listed on [stats](stats.md). |

**City**: Auto-growth off / zones only / zones + roads; "Save now (autosaves every day)"; "Show the guide"; "New city (opens the start menu)"; "Sound on / off"; "Volume up" and "Volume down" in steps of 10 percent (default 30 percent; not saved).

### Windows

Each window has a title bar with **Out** (open as an OS window, not on Details), **-** (minimize) and **x** (close). Drag by the title. Positions, open state and pop-out state are saved in `user://ui.cfg` (details on [empire](empire.md#pop-out-windows)).

| Window | Default | Content |
|---|---|---|
| **Build** | open, left | Four tool buttons (Inspect (Q), Bulldoze (B), Paint water, Remove water), then 12 category headers that fold open with a click: Infrastructure and Zones start open, then Safety, Health, Education, Leisure & culture, Transport, Utilities, Commerce, Government, Military, Industry & trade. Each building is a button `Name  $cost` with an icon; locked buildings are greyed with `(pop N)` (unlock by peak population). At the bottom, the R/C/I/O demand gauge. Hover a button for its description in the Details window. |
| **City panel** | open, right | Eight tabs, below. |
| **Hover details** | open, but shown only with something to show | Description of the hovered button, or of the building tool you hold. |
| **Mayor's office** | open | Approval bar, Rally button ($150; enabled in the last 7 days before an election, once per campaign), election line, tabs Decisions (petitions, offers, demands and recovery choices with Accept / Decline style buttons, and your promises), Advisors, Goals (rank and milestones). |
| **Army** | closed | Auto-train check, army summary and ranks, and one row per unit kind with `count / capacity` and `-` / `+` buttons for training priority (0 off, 1 slow, 2 normal, 3 fast). |
| **Empire** | closed (open in spectator games) | The dashboard on [empire](empire.md). |

**City panel tabs** (`Hud._right`):

| Tab | Content |
|---|---|
| Info | Inspector (selected citizen or tile), "What the city needs" (first 7 notices), Goal (rank and next unlock), Murmurs (citizen remarks). |
| Budget | Tax sliders for residential, commercial and industrial (0 to 30 percent in 1 percent steps), income and expenses list with a graph (coins and population history), the farms-mill-goods economy summary, and the three loan buttons (max 3 loans at a time). |
| Stats | Coverage bars for every stat (hover for details), crime bar, average commute and shop distance, land value. |
| People | The tribes: share of town, opinion, what they want. |
| Region | Every town with imports, commuters and trade; your land (territory size, four annex buttons North / East / South / West, auto-annex check); and a card for each neighbour with Gift $100, Trade pact $200, Alliance $400, Embargo / Lift embargo, Demand tribute, Peace $150, Declare WAR and Cancel treaty buttons. |
| Policy | Auto-growth selector, auto-policies check, and a switch for each policy ([policies](policies.md)). |
| Events | Active events with time left, and the log. |
| Codex | A list of every building, stat, policy and event (`Building: …`, `Stat: …`, `Policy: …`, `Event: …`); select one to read it. |

### Information cards

- **Hover card** (`Hud._maptip_text`): follows the cursor over a cell of the viewed town when no window is under it. Shows the building name (with "(bridge)" on water), level or "(empty plot)", road access, residents and workers, "ON FIRE", power / water / sewer status, and land value. An empty water cell shows "River" with its health.
- **Pinned card**: clicking a tile with Inspect pins the same card beside it with "click again to close"; it updates live. The tile under it no longer shows the hover card.
- **Guide** (`Guide`): ten steps at the bottom centre (lay a road, zone homes, zone shops and jobs, power and water, grow to 10, overlays, the mayor, neighbours, reach 50, done). Steps with a check complete themselves; others have Next; "Hide guide" closes it; City > "Show the guide" restarts it.
- **Game over panel**: "GAME OVER", the reason, peak population and "Press R to restart."

## New game setup screen

`Setup` (`client/scripts/setup.gd`) is shown at launch and by City > "New city". `Main.start_game` receives the values below.

| Option | Choices (default in bold) | Effect |
|---|---|---|
| Continue saved game | Button, only if a save exists | Loads `user://murmur_save.bin` (`Main.continue_game`). |
| Your town's name | Text, "Murmur", 18 characters at most | Empty becomes "Murmur". |
| Towns at the start | **2 (you + 1 neighbour)**; 1 (just you), 3, 4, 5, 6, 7, 8 | Number of towns, passed as the selection plus one. Neighbours run on the planner with 400 coins. More can be founded later. |
| Neighbours are | **Mixed (each has its own temper)**; Friendly; Prickly; Random | Neighbour temper: Friendly 0.2 for all; Mixed from `TEMPERS` [0, 0.2, -0.25, 0.05] by town number; Prickly -0.25; Random between -0.3 and 0.3. Your own town's temper is 0. |
| Difficulty | **Normal ($300)**; Relaxed ($600, calmer world); Hard ($150, more disasters) | Starting coins of your town 300 / 600 / 150, and the delay between random world events is multiplied by 1.0 / 1.5 / 0.7 on every town (`ev_scale`). |
| Starting land | **Medium (48x32)**; Small (40x24); Large (64x40) | Territory of every town at the start, centred in its plot. |
| Rivers | **Natural (rivers, lakes, coast)**; None (flat land); Custom: I paint it (world editor) | Natural uses the world's water. None and Custom turn water into plain land; Custom also selects Paint water and starts paused. |
| Auto-growth | **Zones + roads**; Off - I build everything; Zones only | Your town's planner mode. Neighbours always use zones + roads. |
| Auto-policies | On | The council switches policies by itself (your town). |
| Auto-annex land when cramped | On | The planner buys land when cramped and rich enough (your town). |
| Spectator | Off | No mayor: every town on the planner (see [empire](empire.md#spectator-mode)). |
| Show the new-player guide | On if there is no save, off if there is one; ignored in spectator mode | Starts the guide. |
| Start new game | Button | Starts the game and **deletes the existing save file** (`Main.start_game`). |
| Multiplayer (host or join) | Button | Opens the lobby ([multiplayer](multiplayer.md)). |
| Quit | Button | Exits. |

A line at the bottom of the menu summarises the basic controls.

How the world is chosen for these options (dry start sites, at least 30 water tiles for your town when rivers are natural) is on [world](world.md#choosing-the-start-sites).

## Saving and loading

| Item | Rule (`Main`) |
|---|---|
| Save file | `user://murmur_save.bin`, a Godot variant dictionary: version 2, the index of the viewed town, every town's `to_dict`, the `Signals` values and the world `{seed, rivers}`. |
| Autosave | When the viewed town's day changes (also once right after a game starts) and the game is not over (`Main._process`); on closing the window while a game is running and not over (`NOTIFICATION_WM_CLOSE_REQUEST`); City > "Save now". |
| Not saved | A network game (host or client) never writes the save. A finished game is not saved. |
| Load | At launch the save is read (`Main._ready` -> `load_game`); the start menu offers "Continue saved game". A save whose version is not 2 or that holds no towns is ignored. |
| New city | City > "New city" saves the running game first (unless it is over, in which case the save is deleted) and opens the start menu. Starting a new game from there deletes the save. |
| Volume, mute, camera, overlay, tool | Not saved. |

## Files in `user://`

Godot's per-user data folder for the project name "Murmur" (the project sets no custom folder): on Windows `%APPDATA%\Godot\app_userdata\Murmur`, on Linux `~/.local/share/godot/app_userdata/Murmur`, on macOS `~/Library/Application Support/Godot/app_userdata/Murmur`.

| File | Written by | Content |
|---|---|---|
| `murmur_save.bin` | `Main.save_game` | The save above. |
| `ui.cfg` | `Hud._save_ui` | Window layout (`ConfigFile`; see [empire](empire.md#pop-out-windows)). |
| `benchmark.json` | `Benchmark._report` | Last benchmark result. From the editor the result is also written to `res://benchmark_result.json`. |
| `netsync_client.txt` | `tests/netsync.gd` | Test output only. |

## Benchmark (F9 or `--benchmark`)

`Benchmark` (`client/scripts/benchmark.gd`) is the standard measurement quoted in the README: seed 20261007, 8 towns, spectator, Normal difficulty and Medium land. It first simulates 30,000 steps of 0.1 s (3,000 simulation seconds, about 50 minutes) without drawing, then runs at 8x with the ALL overlay at zoom 1.0 and vsync off, warms up for 15 s and samples for 30 s. It prints `BENCHMARK_JSON {...}` and writes `user://benchmark.json` with fps, frame-time percentiles, CPU and GPU render time, draw calls, simulation and draw cost, memory, slow-frame breakdown, effective speed and population. With `--benchmark` the game quits afterwards; with F9 it stays running. `--war` declares four wars (towns 0v1, 2v3, 4v5, 6v7, each with a mixed army and $5,000) before sampling. `--watch` makes the camera follow the busiest town; the results are tagged as not standard.

The benchmark starts a temporary world (`temp` option of `Main.start_game`): it never deletes or overwrites `user://murmur_save.bin` (`Main.ephemeral` blocks `save_game`), so F9 is safe in a game you want to keep.

## Command-line flags

Game flags are read with `OS.get_cmdline_user_args()`, so they must come after a lone `--`, for example `godot --path client -- --benchmark`. Godot's own flags (`--headless`, `--path`, `-s`) come before it.

| Flag | Where | Effect |
|---|---|---|
| `--benchmark` | `Main._ready` | Run the standard benchmark and quit. |
| `--war` | `Benchmark` | With `--benchmark`: four wars during the sample. |
| `--watch` | `Benchmark` | With `--benchmark`: the camera follows the busiest town. |
| `--selfcheck` | `Main._ready` | Print the result of `City.selfcheck()` (slow; `SELFCHECK_OK`). |
| `--server` | `Main._net_args` | Start a dedicated multiplayer server ([multiplayer](multiplayer.md#dedicated-server)). |
| `--port N` | `Main._net_args` | Port of `--server` (default 7777). |
| `--towns N` | `Main._net_args` | Towns of `--server` (default 6, 2 to 8). |
| `--speed X` | `Main._net_args` | Speed of `--server` (0.5 to 8). |
| `--join host[:port]` | `Main._net_args` | Join a server as "Player". |
| `--mp-test` | `Main` | Used by `tests/mp.gd`: retry the connection, change a tax rate through the host, print `MP_CLIENT_OK`, quit; gives up after 40 s. |
| `--capture DIR` | `Main._capture_args` | Save the window as `fNNNN.png` into `DIR` every `--every` seconds while a game is running (README media; `scripts/MEDIA.md`). |
| `--every S` | `Main._capture_args` | Interval for `--capture`, default 0.25, minimum 0.05. |

The window is 1280 by 720 with canvas-item stretch and expanding aspect, on the GL Compatibility renderer (`project.godot`).

## Development: tests and CI in ten lines

1. Tests are headless scripts: `godot --headless --path client -s tests/<name>.gd`; each prints a marker such as `WORLD_OK` and exits non-zero on failure.
2. CI (`.github/workflows/ci.yml`, Godot 4.7.2) has three jobs: `hygiene`, `smoke` and `netplay`.
3. `hygiene` runs `python3 scripts/check_repo.py` (markdown links and backticked paths exist, `VERSION` matches the changelog, docs index, README claims) and `gdlint scripts tests` (gdtoolkit 4.5.0, rules in `client/gdlintrc`).
4. `smoke` runs `smoke.gd` (SMOKE_OK: self-check plus a 3 minute soak) and then netcache, rivers, spectate, mining, war (also MIX_OK and NAVAL_OK), world, worldtown, worldstart, found, empire, popout, warmap, ai, farms, pmine and growth.
5. `netplay` runs net, cmd, netsync, mp (a real server and a real client process) and pvp.
6. Profilers that CI does not run: `bench.gd`, `bench2.gd`, `regionbench.gd`, `stageprof.gd`, `netbench.gd`, `place.gd`, `region.gd`, `late.gd`; debug tool `hum.gd`; media tools `showcase.gd` and `reel.gd`.
7. The generated reference pages come from `python3 scripts/gen_wiki.py` (it runs `client/tools/dump_wiki.gd`); `--check` fails if they differ. This check is not in `ci.yml`.
8. Workflow: feature branch, a `CHANGELOG.md` entry under Unreleased, `check_repo.py` clean, CI green, squash merge (`CLAUDE.md`, `CONTRIBUTING.md`).
9. A release runs the performance pass last, then every test, `scripts/bump.py` and a tag (`docs/RELEASING.md`).
10. The standard benchmark numbers in the README must be measured, not estimated.

## Where in the code

| Topic | File and function |
|---|---|
| Keys, mouse, camera, tools | `client/scripts/main.gd`: `_unhandled_input`, `_process`, `_paint`, `_select`, `cmd` |
| HUD, menus, windows, tabs | `client/scripts/hud.gd`: `_top`, `_left`, `_right`, `_army`, `_empire`, `_mayor`, `_win` |
| Info cards | `hud.gd`: `_maptip_text`, `_update_pin`, `_insp_text`; `guide.gd` |
| Overlays | `main.gd`: `_overlay`, `draw_overlay` |
| Setup screen | `client/scripts/setup.gd`; `main.gd`: `start_game`, `_fresh` |
| Save and load | `main.gd`: `save_game`, `load_game`, `new_game` |
| Benchmark and flags | `client/scripts/benchmark.gd`; `main.gd`: `_ready`, `_net_args`, `_capture_args` |
| Tests and CI | `client/tests/`, `.github/workflows/ci.yml`, `scripts/check_repo.py` |

## Open questions

- **Controls other than the viewed town.** Offline, `Main.cmd` does not check that the viewed town is one you run, so tools work in a planner-run neighbour as well. Whether that is intended is not stated.
- **Guide wording.** The guide says "drag a line on the grass" for roads; the code places one tile per mouse-motion event with no interpolation (`Main._paint`).
- **Guide menu path.** The last guide step says "Windows > Guide in the City menu"; the item is City > "Show the guide".
