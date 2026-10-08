# Multiplayer

Murmur has an experimental multiplayer mode in which each player runs one town in a shared world. One process, the **host**, runs the whole simulation. Everyone else is a **client** that draws a mirror of the host's towns and sends commands. Towns nobody has taken keep running on the planner. This page covers hosting and joining, the lobby, ports, player limits, how towns are claimed, the host-authoritative model, the full list of commands and their validation, snapshots, chat, player-versus-player diplomacy and the current limitations.

Related pages: [empire](empire.md) (the empire commands), [world](world.md), [controls](controls.md#command-line-flags) (command-line flags), [war](war.md), [constants](constants.md) (`port`, `max_players`).

## Summary

- Transport is Godot's ENet over **UDP**, default port **7777** (`NetPlay.PORT`).
- Maximum **8 players**: `NetPlay.MAX_PLAYERS`. The server is created with `MAX_PLAYERS - 1` = 7 client slots, so a player-hosted game is the host plus 7 clients (see Open questions for the dedicated server).
- Two ways to host, one code path: Start menu > Multiplayer > Host (the host also plays and owns the first town), or a headless dedicated server started with `--server`.
- Every action a player takes is a command that the host validates (`Cmd.run`) and that only works on a town the sender owns.
- The host sends every town's full state, gzip-compressed, once per simulated second. Clients never simulate.
- A player who leaves hands the town back to the planner; rejoining under the same name returns it.
- There is no password, encryption, relay, world persistence or founding of towns in multiplayer yet.

## Hosting and joining

### From the game

Start menu > "Multiplayer (host or join)" opens the lobby (`Lobby`, `client/scripts/lobby.gd`).

| Field | Default | Rule |
|---|---|---|
| Your name | `Player` | Up to 20 characters (`NetPlay.NAME_MAX`). |
| Port (UDP) | 7777 | Parsed as an integer, a non-number falls back to 7777, then clamped to 1024 to 65535 (`Lobby._port`). |
| Towns in the world | 4 | A drop-down from 2 to 8 ("N towns (free ones run on the planner until someone joins)"). |
| Host address | `127.0.0.1` | `host` or `host:port`; the port defaults to 7777 (`Lobby._join`). |

Buttons: **Host a game** (`Main.host_game`), **Join** (`Main.join_game`), **Back** (stops the network). Below the buttons the lobby shows the roster as `name (ping ms)` and a status line with messages such as "Connecting...", "Connected. Waiting for the world...", "Could not connect to H:P.", "Connection failed." or "Could not listen on port N.".

`Main.host_game(port, towns, name)` starts an ordinary world through `start_game` with: the town count clamped to 2 to 8, natural rivers, "Mixed" neighbour temper, normal difficulty, medium start land, auto-growth zones and roads, auto-policies and auto-annex on, no guide, no spectator mode. The save file is not touched (`mp` is true). The host's town gets `owner = 1` (the host's peer id); every other town is planner-run (`human = false`, `owner = 0`). The host then calls `NetPlay.serve(towns)` and `NetPlay.host(port, name)`, creates the chat box and sets the headline "Hosting on UDP N. Friends join with your address; each takes a free town."

`Main.join_game` calls `NetPlay.join(ip, port, name)`. When the connection is up the client sends its name, the host answers, and the client starts a mirror game (see below).

### Dedicated server

```
godot --headless --path client -- --server [--port 7777] [--towns 6] [--speed 1]
```

(`Main._net_args`). The arguments after `--` are read from `OS.get_cmdline_user_args()`.

| Flag | Default | Rule |
|---|---|---|
| `--server` | off | Starts the game with a fresh world and listens. |
| `--port N` | 7777 | No range check. |
| `--towns N` | 6 | Clamped to 2 to 8. |
| `--speed X` | 1.0 | Clamped to 0.5 to 8.0. |

The server world is built with `start_game` as a **spectator** game (all towns planner-run, name "Server", natural rivers, no guide), so every town is free for players. The process plays no town and is not in the player table. It prints `Murmur server: listening on UDP N with T towns at X.Xx`, a line for every join and leave with the player count, and `[chat] name: text` for chat. A restart makes a new world.

`--join host[:port]` (with optional `--mp-test`) joins from the command line under the name "Player"; it is what the multiplayer test uses.

### Network requirements

- Players on the same network join with the host's LAN address.
- Over the internet the host must forward **UDP** 7777 (or the chosen port) on the router and allow it in the firewall, or use a VPN or overlay network such as Tailscale or ZeroTier (advice from `docs/MULTIPLAYER.md`).
- There is no relay or NAT punch-through (`docs/MULTIPLAYER.md`: out of scope until needed).

## Players, names and towns

### Joining sequence (`NetPlay`)

1. The client connects; on `connected_to_server` it sends `_hello(name)`.
2. The host starts a 5 second timer for every new peer (`HELLO_WAIT`). A peer that has not said hello by then is disconnected, so silent connections cannot fill the slots.
3. On hello the host cleans the name, makes it unique, adds the player to `players` (`{"name", "ping"}`), pushes the roster to everyone, and sends `_welcome` to the new client.
4. If the host has towns (`serve` was called), `NetWorld.assign` gives the player a town and the host sends the world meta `{"n": town count, "mine": index}`.
5. The client builds a mirror (`Main._net_world`): `remote = true`, `NetWorld.mirror` makes `n` empty towns wired as neighbours of each other, the viewed town is yours, and the game starts. Real contents arrive with the first snapshots.

If every town is already taken, `mine` is -1 and the client joins as a **spectator**: the headline reads "Joined as a spectator: every town is taken." and `Main.cmd` refuses all its commands.

### Names

`NetPlay._clean`: control characters (newlines, tabs, escapes) become spaces and the name is trimmed; the name "server" in any case becomes "Player"; an empty name becomes "Player"; the name is cut to 20 characters. `NetPlay._unique` appends " 2", " 3" and so on while the name is already used by a connected player.

### Claims

`NetPlay.claims` maps a player **name** to the town index they last ran. On hello, `NetWorld.assign(towns, peer, claims[name])`:

- if the remembered town is still free (`owner == 0`) the player gets it back;
- otherwise the player gets the first free town (lowest index) and the claim is updated.

The town gets `owner = peer` and `human = true`. Each peer gets exactly one town. When a peer disconnects, `NetWorld.release` sets `owner = 0` and `human = false` on its towns, handing them to the planner; the claim stays in the table. The table lives only in the host's memory.

### Ping and roster

Every second the host sends the roster to all peers. Each client pings the host once a second; the measured round trip is reported back and stored in `players[id]["ping"]` (0 to 9999 ms). The roster is shown in the lobby.

## The host-authoritative model

- The host process runs the entire simulation, the same loop as single player (`Main._process`): all towns, `Diplo`, `Military`. A client never runs it: `Main.remote` is true and the sim loop is skipped.
- The simulation is not deterministic (global random numbers, wall-clock time), so lockstep play is not possible (`docs/MULTIPLAYER.md`); that is why clients mirror state instead of re-simulating.
- Every player action goes through `Main.cmd`. In a network game it first checks that the viewed town's `owner` equals your peer id (`NetPlay.my_id`), otherwise the headline reads "That town is not yours." Then `NetPlay.command(index, name, args)` runs it: the host runs it directly, a client sends it to the host.
- On the host, `NetPlay._run(sender, index, name, args)` rejects an out-of-range town index or a town whose `owner` is not the sender, then calls `Cmd.run`.
- **Speed and pause** are the host's `Main.speed`. The top-bar speed buttons and Space on a client change only the client's local variable, which nothing reads while `remote` is true.
- Sandbox event triggers from the World events menu are not commands; they act on the local town object directly (`Hud._on_event_menu`).

## Commands (`Cmd.run`)

`Cmd.run(towns, town, name, args)` is the only route into the simulation (`client/scripts/cmd.gd`). Single player calls it locally; in multiplayer the host calls it after checking ownership. It returns what the underlying method returns, or null for an unknown name or rejected arguments.

**Global check.** Before anything else, any argument that is a float and not finite (NaN or infinity) rejects the whole command, because such a value would slip through `clampf` and corrupt the town's money.

**Argument helper.** `_ints(args, n)` requires exactly `n` arguments, all integers.

| Command | Arguments | Validation | Effect |
|---|---|---|---|
| `place` | x, y, building id (3 ints) | Cell inside the plot, id exists in `Catalog.DEFS` | `City.place` (which further checks ownership of the cell, coins, unlock, water and so on) |
| `bulldoze` | x, y (2 ints) | Cell inside the plot | `City.bulldoze` |
| `water` | x, y, v (3 ints) | Inside, owned by the town, v is 0 or 1 | `City.set_water` (world editor) |
| `tax` | "r", "c" or "i", rate | 2 arguments, first a String in `Cmd.TAX`, second an int or float | Sets that tax, clamped to 0 to 0.5 |
| `policy` | policy key, on/off | Key in `Catalog.POLICIES`, second a bool | `City.set_policy` |
| `loan` | index (1 int) | 0 up to the number of `Civics.LOANS` minus 1 | `City.take_loan` |
| `expand` | side (1 int) | 0 to 3 (north, east, south, west) | `City.expand` (buy a land strip) |
| `auto_expand` | bool | exactly one bool | Sets auto-annex |
| `auto_policy` | bool | exactly one bool | Sets auto-policies |
| `auto_mode` | 0 to 2 (1 int) | Integer 0 to 2 | Sets auto-growth |
| `train` | bool | exactly one bool | Sets auto-train |
| `train_w` | unit kind, weight | Kind in `Military.KIND`, weight an int | Weight clamped to 0 to 3 |
| `answer` | petition index, yes/no | Index int, answer bool, index within the petition list | `City.answer` (petitions, offers, demands, recovery) |
| `rally` | none | None | `City.rally` |
| `send` | town index, amount | 2 ints, index valid and not the sender, amount 1 to 1,000,000 | `Empire.send` (same side only) |
| `balance` | floor (1 int) | 0 to 5000 | `Empire.rebalance` over your towns |
| `apply_all` | key plus value(s) | Key in `Empire.BULK`; `tax` takes 2 values, others 1 | The single-town command on each of your towns; returns the count |
| `diplo` | town index, verb | Index int, valid and not the sender; verb in `Cmd.DIPLO` | `Diplo.act`, returns the headline text |

`Cmd.DIPLO` is `gift, pact, alliance, embargo, lift, peace, tribute, war, leave`.

The empire commands are described in detail on [empire](empire.md).

### Rate limit and reply

- A client command must come from a peer in the player table and pass a **token bucket** per peer (`NetPlay._allow`): 30 tokens per second refill, a burst of 60, each command costs 1. A command out of tokens is dropped silently.
- The host answers with `_reply(name, result)`. The result is passed on if it is null, a bool, a String or an int; any other type (a float, for example from `balance`) becomes true. A client shows a String result (such as "Proposal sent to Ashby.") as the headline.
- The host's own commands (`NetPlay.command` on the host) are not rate limited.
- Over the wire a client command is a reliable RPC `_cmd(index, name, args)`.

## Snapshots

- `NetPlay.broadcast()` is called by `Main._process` once for every **simulated** second (when its `dacc` counter passes 1.0). It sends one reliable RPC `_state(index, bytes)` per town to every peer. Nothing is sent when there are no clients.
- Because it is tied to simulated seconds, the rate follows the game speed: about once per real second at 1x, faster at 3x and 8x, and not at all while the host is paused.
- `NetWorld.pack(town)` is `var_to_bytes(town.to_dict())` compressed with gzip. `City.to_dict` writes the keys of `City.SAVE_KEYS` plus the citizen list and army, which is also exactly what a save contains for a town. Every town is sent in full each time; there are no diffs.
- `NetWorld.unpack` decompresses with a hard cap of 4 MiB (`decompress_dynamic(4 << 20, ...)`) because the sender is untrusted, and accepts only a Dictionary. `City.from_dict` accepts only `SAVE_KEYS`, `cit`, `v` and `army`.
- Measured by the developers (`docs/MULTIPLAYER.md`): 5.3 KB gzip per town at population 70, pack 1.1 ms on the host and apply 1.3 ms on a client, about 40 KB/s per client for 8 towns. They note that large towns have not been re-measured.
- The first snapshot of your own town centres the camera (`Main._net_state`).
- Save games: `Main.save_game` does nothing while a network is active, so a networked world never overwrites your single-player save.

## Chat

- Enter opens the chat input (`Main._unhandled_input`; the box exists only in a network game: created for the host in `host_game` and for a client when the world arrives). Enter sends, Esc cancels. The input is limited to 140 characters.
- `NetPlay.say` replaces control characters with spaces and cuts to 140 characters. A client sends a reliable `_say` to the host; the host relays it to everyone as `_chat(who, text)` with the sender's player name. The host's own lines go out under the host's player name; on a dedicated server a line from no player is shown as "Server".
- On the host, each chat line costs 20 tokens from the sender's bucket (about 1.5 lines per second sustained, a burst of three).
- The box shows the last 6 lines at the bottom left; a line fades after 14 seconds (`ChatBox.SHOW_MS`) unless the input is open.
- The dedicated server prints chat to its log as `[chat] name: text`.

## Player-versus-player diplomacy

When the other town belongs to a different player (`Diplo._player`: `b.owner != 0 and b.owner != a.owner`), these actions become **proposals** instead of taking effect at once (`Diplo.act` -> `Diplo._ask`):

| Verb | Becomes a proposal when |
|---|---|
| `pact`, `alliance` | Always |
| `peace` | You are at war |
| `tribute` | Your military is at least 0.3 stronger than theirs (otherwise it fails as against the planner) |

The proposal lands in the other player's petitions as an offer ("Sign it", "Decline") or demand ("Pay $N", "Refuse"), valid until the end of day + 2. The proposer's price is taken at once and is returned if the proposal is declined or expires (`Diplo.resolve`). Pre-checks still apply (for example an alliance needs a trade pact first, peace needs at least 3 war rounds). A second proposal to the same town while one waits is refused. A refused tribute demand is a raid on the payer. **War, embargo, lifting an embargo, gifts and cancelling a treaty are one-sided** and take effect immediately. Planner towns (owner 0) answer instantly, as in single player. Costs and effects of each verb are on the Region tab tooltips; war itself is on [war](war.md).

## Limitations

From the code and `docs/MULTIPLAYER.md`:

- One town per player; founding towns is disabled in multiplayer (`Main.found_town`), and so are empire-wide commands in practice.
- No password, no authentication, no encryption; a name is the only identity (see Claims). Anyone who can reach the port can join, up to the player limit.
- No relay, server list or NAT punch-through; the host must be reachable (port forwarding or a VPN).
- The dedicated server's world is not saved. A player-hosted game never writes the single-player save.
- Full snapshots for every town once per simulated second, with no diffs; large towns and many players are untested.
- Clients do not simulate, so any cosmetic that is computed locally (citizens walking, cars, boats) is animated from mirrored data and can differ between screens.
- The World events menu acts on the local town object, so on the host it changes the real simulation of the viewed town, whoever owns it.

## Where in the code

| Topic | File and function |
|---|---|
| Transport, roster, names, rate limit, chat, RPCs | `client/scripts/netplay.gd`: `host`, `join`, `_hello`, `_allow`, `_run`, `_cmd`, `broadcast`, `say` |
| Ownership, snapshots, mirror | `client/scripts/networld.gd`: `assign`, `release`, `pack`, `unpack`, `mirror`, `meta` |
| Validated commands | `client/scripts/cmd.gd`: `Cmd.run` |
| Lobby | `client/scripts/lobby.gd` |
| Game integration | `client/scripts/main.gd`: `_net_args`, `host_game`, `join_game`, `_net_world`, `_net_state`, `_net_failed`, `cmd`, `save_game` |
| Chat box | `client/scripts/chatbox.gd` |
| Player diplomacy | `client/scripts/diplomacy.gd`: `act`, `_player`, `_ask`, `resolve`, `_offer` |
| Tests (CI `netplay` job) | `client/tests/net.gd` (NET_OK), `cmd.gd` (CMD_OK), `netsync.gd` (NETSYNC_OK), `mp.gd` (MP_OK, a real server and a real client process), `pvp.gd` (PVP_OK) |

## Open questions

- **Dedicated server size.** `NetPlay.host` calls `create_server(port, MAX_PLAYERS - 1)` whether or not the process is dedicated. The README and `docs/MULTIPLAYER.md` say up to 8 players, but a dedicated server (which is not itself a player) seems to accept 7 clients.
- **World seed on clients.** `NetWorld.meta` carries only `n` and `mine`, and `Main._net_world` does not set `Main.world`. I did not find where a client would learn the host's seed, so the land drawn between towns by `WorldLayer` on a client may not match the host's world, while each town's own water, ore and ground do arrive in the snapshot.
- **Weather and other `Signals`.** The `Signals` object is ticked inside the simulation loop and is not in `City.to_dict`, so a client's weather overlay and ambient sound presumably do not follow the host's. I did not test it.
- **Claim identity.** Claims are keyed by display name only. A different person who joins under a name after its owner left receives that town; the design note in `docs/MULTIPLAYER.md` mentions a "name/token", but there is no token in the code.
- **IPv6 and host names.** `Lobby._join` splits the address on `:`, so an IPv6 literal cannot be entered; whether host names resolve was not checked.
- **Failed listen.** `Main.host_game` ignores the return value of `NetPlay.host`; on failure the "Could not listen" text goes to the headline while the already-started world stays on screen with the host as owner.
- **Name length.** `_unique` can append a number after the 20 character cut, so a name can be up to a few characters longer than `NAME_MAX`.
