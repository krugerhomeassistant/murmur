# Multiplayer design

Decided with the owner, 2026-10-08: **competitive towns** in one shared world (each player runs a town; trade, diplomacy and war between players; unclaimed towns stay on the planner AI), **2-8 players**, **both** LAN/direct-IP and a hosted server.

## Model
- **Host-authoritative.** One process runs the whole sim (all towns, `Diplo`, `Military`) exactly as single-player does today. The sim is not deterministic (global RNG, wall clock), so lockstep is out; clients never simulate.
- **Two ways to host, one code path:** (a) a player hosts (listen server, LAN or direct IP/port forward), (b) a dedicated headless server (`godot --headless --path client -- --server --port 7777`) on any machine/VPS. Transport is Godot `ENetMultiplayerPeer` (UDP, reliable + unreliable channels). Relay/NAT punch-through is out of scope until needed.
- **Ownership.** `City.owner: int` (peer id; 0 = AI). `human` keeps meaning "player-controlled, can be lost/has elections"; planner-only towns have `human=false`. A disconnected player's town is handed to the planner and can be reclaimed on rejoin (same player name/token).

## Layers
1. **Net** (`scripts/netplay.gd`): peer lifecycle, lobby, player table (peer id -> name, town index, ready), ping, chat.
2. **Commands** (client -> host, reliable RPC): every player-initiated mutation becomes `cmd(town_idx, name, args)`. Host checks `town.owner == sender` and then calls the existing method (`place`, `bulldoze`, `set_water`, `set_policy`, tax rates, annex, loans, build/train priorities, treaty answers, war declarations). Single-player calls the same path locally, so there is one route into the sim.
3. **State** (host -> clients):
   - join: full snapshot (`City.to_dict()` per town, chunked) plus world meta (seed, gpos layout, clock).
   - steady state: 1 Hz compact scalar block per town (coins, pop, mood, stats, army summary, diplomacy), grid diffs from a per-town dirty-cell list (batched, reliable), events/headlines/blasts/tracers as small messages.
   - clients render from a read-only `City` mirror (`remote = true`: `tick` is a no-op, `from_dict`/diffs applied). Citizens/boats/traffic are cosmetic and animated locally from mirrored data.
4. **UI**: lobby/host/join screens (direct IP field, server list later), player list with town colours, chat, "waiting for host" states. Pause is host-only; speed is host-set.

## Phases (each = branch, tests, CHANGELOG, PR)
- [x] P0 transport: `NetPlay` (scripts/netplay.gd), `--server` / `--join host[:port]`, roster + ping, two-process test `tests/net.gd` (NET_OK).
- [x] P1 ownership (core): `City.owner` (saved), `NetWorld.assign/release`; the Main/HUD side (per-peer "my town", spectators) lands with P3b. [ ] original scope: `City.owner`, per-peer "my town" (main's `city` is the local player's), spectator for extra peers.
- [x] P2 commands: `Cmd.run` (scripts/cmd.gd) is the single validated route for place, bulldoze, water, tax, policy, loan, expand, auto toggles, training, petitions, rally and diplomacy; HUD and input call `Main.cmd`. `tests/cmd.gd` (CMD_OK) covers hostile arguments. Sandbox event triggers stay local-only.
- [x] P3a snapshots: host sends each town's `to_dict` gzip-compressed once a second (about 5 KB per town measured at pop 70, so no diffing yet); `NetWorld` (scripts/networld.gd) packs/unpacks, `NetPlay.broadcast/command`; client mirrors via `from_dict`; commands carry the town index and the host rejects non-owners. `tests/netsync.gd` (NETSYNC_OK) covers join, mirror, command, refusal.
- [x] P3b game integration: `Main.host_game` (lobby "Host": a normal world, you own town 1, friends take the free towns), `Main.join_game` (client runs a no-sim mirror, `remote = true`, viewed town = yours, snapshots via `from_dict`), `Main.cmd` routes every action through the host, a networked world never touches the single-player save; lobby screen (scripts/lobby.gd) from the start menu; `--server [--port N] [--towns N]` dedicated mode. `tests/mp.gd` (MP_OK) runs a real server process and a real client process.
- [x] P4 chat and reconnects: Enter opens chat (140 chars, `NetPlay.say`, relayed by the host, `ChatBox`), a player who leaves hands the town back to the planner and gets the same town when they rejoin under the same name (`claims`), a lost host connection returns the client to the start menu, leaving a networked game stops the network.
- [x] P5 player-vs-player diplomacy: when the other town belongs to another player (`b.owner != 0`), pacts, alliances, ceasefires and tribute demands become proposals in that player's petitions (`Diplo._ask`), the proposer's price is held and refunded on refusal or expiry; war, embargo, gifts and cancelling stay unilateral. Planner towns answer instantly as before. `tests/pvp.gd` (PVP_OK).
- [x] P6 dedicated server polish: `--server --port --towns --speed`, join/leave/chat logging, run instructions below. Not done: world persistence, password, Docker image.
- [ ] P7 hosted options beyond direct IP (relay, server list) only if wanted.

## Risks
- Bandwidth of grid diffs while towns grow fast at 8x: batch per second, compress with `PackedByteArray.compress`, measure.
- Planner towns and 8 players at once: host sim cost is the benchmark scenario; keep the standard benchmark honest and add a multiplayer one.
- Security: validate every RPC argument (bounds, owner, rate); no trust in client state; no player-supplied code or paths.

## Measurements
- Town snapshot at pop 70 (day ~400): 5.3 KB gzip, pack 1.1 ms on the host, apply 1.3 ms on a client (headless, one town). 8 towns once a second is about 40 KB/s per client. Re-measure with large towns (500+ pop) before release; if it grows, add diffs or send non-viewed towns less often.

## Running a server
- **From the game:** start menu > Multiplayer > Host. Friends on the same network join with your LAN address; over the internet forward UDP 7777 on your router (or use a VPN/overlay network such as Tailscale or ZeroTier, no port forwarding needed).
- **Dedicated (headless):** `godot --headless --path client -- --server [--port 7777] [--towns 6] [--speed 1]`. It prints joins, leaves and chat. Players take free towns; empty towns run on the planner. The server world is not saved yet (a restart makes a new world).
- Open the port in the server's firewall (UDP). There is no password yet: anyone who can reach the port can join, up to 8 players.
