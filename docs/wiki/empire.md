# Empire mode and pop-out windows

Murmur lets one player run several towns at once. The **Empire window** is a dashboard of every town with alerts, one-click settings for all of your towns, and money transfers between them. **Spectator mode** is the same dashboard with every town run by the planner. The **pop-out** feature lets any HUD window, including this one, move into its own operating-system window, for example on a second monitor.

Related pages: [world](world.md) (founding towns), [multiplayer](multiplayer.md) (the command route and ownership), [controls](controls.md), [policies](policies.md), [constants](constants.md).

## Summary

- The rules are in `Empire` (`client/scripts/empire.gd`): who is on your side, a dashboard row per town, totals, `send` and `rebalance`.
- The window is built by `Hud._empire` and refreshed by `Hud._empire_refresh` about ten times a second while it is open.
- All changes go through `Cmd.run` (`send`, `balance`, `apply_all`), so the multiplayer host validates them exactly like single-player input.
- "Your towns" means towns on the same side as the **viewed** town (`Empire.same_side`).
- Spectator mode (a start-menu checkbox) makes every town planner-run and opens the Empire window automatically.
- Every window except the hover card has an "Out" button; the layout is stored in `user://ui.cfg`.

## Opening the window

| How | Notes |
|---|---|
| Windows menu > "Empire (all towns)" | Check item; closed by default. |
| Automatically | `Hud.reset` opens it at the start of a spectator game (`Main.spectating()`). |
| Windows menu > "Reset window layout" | Docks everything and closes the Army and Empire windows again. |

The window title is "Empire (all your towns)", the default position is (160, 70) and the body minimum is 600 by 400. The window refreshes only while it is open (`win_open["empire"]`).

## What the window shows

### Totals line

`Empire.totals(Empire.mine(towns, viewed))` is rendered as `N of your towns   pop P   treasury $C   net +X/s`. It sums population, coins and income over the towns on your side that are not game over (`Empire.mine` skips towns with `over != ""`).

### The town grid

The grid has 8 columns, one row per **town in the game** (not only yours; other sides are listed too, so you can see the neighbours):

| Column | Content | Source |
|---|---|---|
| Town | Name, prefixed with `> ` for the viewed town | `Empire.row` `name` |
| Pop | Population | `City.pop` |
| Coins | `$` and whole coins | `City.coins` |
| Net/s | Income per second with one decimal and sign | `City.income` |
| Mood | Whole percent | `City.mood` |
| Alerts | Flags joined with `; `, or `ok` | `Empire.row` `flags` |
| Go | Button: glides the camera to that town | `Main.switch_town` |
| +$100 | Button: send $100 from the viewed town to this one | `Cmd` `send` |

The Town, Pop, Coins, Net/s and Mood headers are flat buttons that sort the rows (see Open questions for what each actually sorts by). The +$100 button is disabled for the viewed town itself and for any town that is not on your side.

### Alerts

`Empire.row` builds the flags in this order:

1. `GAME OVER` if the town has ended.
2. `AT WAR` if the town has a war treaty with any partner.
3. `broke` if coins are below 50 and income is negative.
4. `unrest` if mood is below 30 percent.
5. Unless the game is over, the first two entries of `City.needs()` (`city.gd`). In the order the function checks them: buildings on fire, tornado, power plants offline, sick citizens, decisions waiting in the Mayor's office, an election within 5 days, traffic jams, mostly imported food, protest, unemployed citizens, each need stat whose uncovered share is high enough (`City._need` above 0.3), long commutes, far shops, high crime, pollution, high demand for homes, shops or jobs, plots waiting for funds, buildings without road access, low funds (under $40), and finally "All quiet. Plan the next district." when nothing else applies. Only the first two that apply are shown, so a town with many problems shows the ones checked earlier.

## Sides: whose towns are "yours"

`Empire.same_side(a, b)` is `a.owner == b.owner and (a.owner != 0 or a.human == b.human)`.

| Situation | Who is on one side |
|---|---|
| Multiplayer | Towns with the same `owner` (peer id). Planner towns have owner 0. |
| Single player | Towns with the same `human` flag. Your own town and any town you founded have `human = true`; the neighbours made at game start have `human = false`. |
| Spectator | Every town has `human = false`, so all towns are one side. |

The check is made against the **viewed** town (`Main.city`, the town under the camera). If you move the camera over a planner-run neighbour in a single-player game, "your towns" in the window becomes the set of planner towns, and the bulk controls below act on them. See Open questions.

## Bulk settings ("ALL MY TOWNS")

The lower half of the window changes one setting on every town of your side at once through the command `apply_all` (`Cmd.run`). The widgets display the **viewed** town's current values, refreshed every few frames.

| Control | Command | Allowed values |
|---|---|---|
| Auto-growth drop-down: Off, Zones only, Zones + roads | `apply_all ["auto_mode", i]` | integer 0 to 2 |
| Check "Auto-policies" | `apply_all ["auto_policy", bool]` | boolean |
| Check "Auto-annex" | `apply_all ["auto_expand", bool]` | boolean |
| Check "Auto-train troops" | `apply_all ["train", bool]` | boolean |
| Tax rows Res / Com / Ind with `-` and `+` | `apply_all ["tax", "r"/"c"/"i", rate]` | rate clamped to 0 to 0.5 |

Rules, from `Cmd.run`:

- The key must be in `Empire.BULK` = `auto_mode, auto_policy, auto_expand, train, tax`. Any other key returns null and does nothing.
- `tax` needs exactly two further arguments; every other key needs exactly one. A wrong argument count returns null.
- The command is then run for each town returned by `Empire.mine(towns, sender_town)`, using the same single-town validation as the normal command (for example `auto_mode` must be an integer from 0 to 2, `tax` must be a number for `r`, `c` or `i`). The return value is the number of towns that accepted it.
- The tax buttons compute the new rate from the **viewed** town (`Hud._tax_all`: current rate plus or minus 0.01, snapped to 0.01, clamped to 0 to 0.5) and then set that same rate on every town of your side. The Budget tab sliders (one town) stop at 30 percent; the bulk buttons can reach 50 percent, which is the limit `Cmd` enforces.
- Other settings (policies one by one, training priorities, loans, land) have no bulk form.

## Sending money

Button "+$100" runs `send [index, 100]` for the viewed town (the sender). In `Cmd.run`:

- both arguments must be integers, the index must be a valid town other than the sender, and the amount must be above 0 and at most 1,000,000;
- `Empire.send(from, to, amount)` then refuses (returns 0) if the towns are the same, are not on the same side, the amount is not positive, or either town is game over;
- otherwise it moves `min(amount, int(from.coins))` coins, and refuses if that is 0. It never makes a treasury negative.

The window only ever sends 100; the command itself accepts any amount in range.

## Balancing treasuries

Button "Balance treasuries (floor $200)" runs `balance [200]`. `Cmd.run` accepts an integer floor from 0 to 5000 and calls `Empire.rebalance(Empire.mine(towns, sender_town), floor)`:

1. A town with more than 3 x floor coins becomes a donor and offers half of what it holds above 2 x floor: `(coins - 2 * floor) / 2`.
2. A town with less than the floor is short by `floor - coins`.
3. The amount moved is `min(total offered, total shortage)`; if that is not positive nothing happens and 0 is returned.
4. Each donor gives its share of the offered pool in proportion to its offer, and each short town receives in proportion to its shortage.

Money is conserved. With the button's floor of 200, towns above $600 give half of what they hold above $400, and towns under $200 are topped up toward $200. Example: A holds $1,000 (offers 300) and B holds $50 (short 150): 150 moves, A ends with $850 and B with $200. Towns between the floor and 3 x floor are untouched. The window headline reads "Moved $N between your towns."; in multiplayer see Open questions.

## Spectator mode

Start menu checkbox "Spectator: no mayor, watch towns run themselves" (`Setup.o_spec`, passed as `spectate`). In `Main._fresh`:

- every town gets `human = false`, 400 coins, `auto_mode` 2 (zones and roads), `auto_policy` and `auto_expand` on;
- the new-player guide is not started (`Setup._go` clears it);
- the headline says "Spectating: no mayor. Tab or the Towns menu switches town, F toggles auto-follow, 8x speeds it up."

While `Main.spectating()` is true (no town is human):

- Tab switches to the next town (`Main._unhandled_input`; in other games Tab does nothing).
- With auto-follow on (key F toggles it; default on), the camera moves to the next town every 30 seconds, but only when there is more than one town and the zoom is closer than level 3 (see the level-of-detail table on [world](world.md#level-of-detail-and-drawing-layers)).
- The Empire window opens by itself (`Hud.reset`).

The commands you issue still go through `Cmd.run` for the viewed town; there is no check offline that the viewed town is yours, so you can build in a planner town while spectating. The benchmark and the dedicated server also start in spectator mode (`Benchmark._ready`, `Main._net_args`); see [multiplayer](multiplayer.md) and [controls](controls.md#command-line-flags).

## Empire play in multiplayer

`Main.cmd` sends each command to the host with the viewed town's index; the host (`NetPlay._run`) refuses it unless that town's `owner` is the sender. `Empire.same_side` then compares peer ids. `NetWorld.assign` gives each connecting peer one town and founding is disabled in multiplayer, so in the current code a player's side is a single town and `send` and `balance` have nothing to act on. The empire commands are validated for the day a player can own several towns; see [multiplayer](multiplayer.md).

## Pop-out windows

Every HUD window has the same title bar (`Hud._win`): the title, an **Out** button, a **-** button (minimize or restore the body) and an **x** button (close; reopen from the Windows menu). Dragging the title bar with the left mouse button moves the window inside the main window and brings it to the front.

The windows are:

| Key | Title | Default position | Notes |
|---|---|---|---|
| `build` | Build | (8, 44) | Tool buttons. |
| `info` | City panel | right edge, y 44 | The tabbed panel. |
| `detail` | Details (hover a building) | (200, y) | No Out button; shows and hides itself, so it always stays in the main window. |
| `mayor` | Mayor's office | (200, 44) | |
| `army` | Army | (220, 80) | Closed by default. |
| `empire` | Empire (all your towns) | (160, 70) | Closed by default. |

### Out (`Hud._popout`)

1. A new `Window` is created hidden, with `force_native = true` (so it is a real OS window, which can be dragged to another screen), the HUD theme, the title `Murmur: <window title>`, and `wrap_controls = true` so it is never smaller than the panel needs.
2. Its size is the saved size or the panel's current size (at least 320 by 200). Its position is the saved position or the main window position plus the panel position plus (40, 40).
3. The panel is moved from the HUD into the window, filled to the window, and the in-panel title bar (with the Out, - and x buttons) is hidden because the OS title bar replaces it.
4. The window is shown if the window is open.

Closing the OS window (`close_requested`) calls `Hud._dock`, which moves the panel back to the HUD at its previous position, shows the title bar again and frees the OS window. The x button of a docked window and the Windows menu check items hide or show a popped window too (`Hud._set_open`).

### Keyboard in a popped window

Key presses in a popped window are forwarded to `Main._unhandled_input` (`window_input` in `_popout`), so Space, Tab, M, B and the number keys keep working, unless a `LineEdit` has focus. Mouse input is not forwarded. WASD and arrow panning read the keyboard state directly in `Main._process`.

### Remembered layout (`user://ui.cfg`)

`Hud._save_ui` writes a Godot `ConfigFile`, one section per window key, with:

| Key | Type | Meaning |
|---|---|---|
| `pos` | Vector2 | Position in the main window. |
| `open` | bool | Window shown. |
| `min` | bool | Minimized. |
| `popped` | bool | In its own OS window. |
| `wpos`, `wsize` | Vector2i | OS window position and size (only for popped windows). |

It is written after a title-bar drag ends, on minimize, on open and close, after pop-out and dock, when a popped window loses focus, on a close request of the main window while any window is popped, and by Reset. `Hud._load_ui` runs at startup: it restores `pos`, `open` and `min` (open defaults to true except for `army`), and re-opens popped windows with `_popout`. Windows are clamped into the visible area whenever the main window is resized (`_clamp_all`).

Windows menu > "Reset window layout" (`Hud._reset_wins`) docks every popped window, shows all windows except Details, Army and Empire, and puts every panel back at its default position.

Headless runs (and platforms without sub-window support) fall back to embedded Godot windows, as noted in `Hud._popout`.

## Where in the code

| Topic | File and function |
|---|---|
| Rules | `client/scripts/empire.gd`: `same_side`, `mine`, `row`, `totals`, `send`, `rebalance`, `BULK` |
| Commands | `client/scripts/cmd.gd`: `send`, `balance`, `apply_all` branches of `Cmd.run` |
| Window | `client/scripts/hud.gd`: `_empire`, `_chk`, `_tax_all`, `_empire_sort`, `_empire_refresh` |
| Spectate | `client/scripts/main.gd`: `_fresh`, `spectating`, `_process` (auto-follow), `_unhandled_input` (Tab, F); `hud.gd`: `reset`; `setup.gd`: `o_spec` |
| Pop-out | `client/scripts/hud.gd`: `_win`, `_popout`, `_dock`, `_set_open`, `_reset_wins`, `_save_ui`, `_load_ui` |
| Tests | `client/tests/empire.gd` (EMPIRE_OK), `popout.gd` (POPOUT_OK), `spectate.gd` (SPECTATE_OK) |

## Open questions

- **Sides depend on the viewed town.** Offline, `Main.cmd` does not check that the viewed town is yours, and `Empire.same_side` compares `human` flags. Viewing a neighbour (`human = false`) makes the planner towns "your towns" for totals, bulk changes and sending.
- **Founding while spectating.** A founded town is created with `human = true` (`Main.found_town_at`), so after founding one `Main.spectating()` is false: Tab and auto-follow stop and the sides split. This follows from the code; I did not run it.
- **Multiplayer feedback.** On a client `Main.cmd` returns null, so the Balance button always shows "Nothing to balance." even when the host moved money; on the host or offline a no-op shows "Moved $0 between your towns.".
- **Simulation level of detail.** Reduced-rate simulation for many towns (E2) is not done. Towns share only by trade (goods, power, water, services), never by automatic money transfers: a shared-treasury auto top-up was built and removed on purpose. Manual Send and Balance remain.
- **Refresh rate.** The window refreshes every sixth frame (`tick_n % 6` in `Hud._process`), which is about ten times a second at 60 frames per second and slower on a slow machine.
