# Multiplayer design

Decided with the owner, 2026-10-08: **competitive towns** in one shared world (each player runs a town; trade, diplomacy and war between players; unclaimed towns stay on the planner AI), **2-8 players**, **both** LAN/direct-IP and a hosted server.

## Model
- **Host-authoritative.** One process runs the whole sim (all towns, `Diplo`, `Military`) exactly as single-player does today. The sim is not deterministic (global RNG, wall clock), so lockstep is out; clients never simulate.
- **Two ways to host, one code path:** (a) a player hosts (listen server, LAN or direct IP/port forward), (b) a dedicated headless server (`godot --headless --path client -- --server --port 7777`) on any machine/VPS. Transport is Godot `ENetMultiplayerPeer` (UDP, reliable + unreliable channels). Relay/NAT punch-through is out of scope until needed.
- **Ownership.** `City.owner: int` (peer id; 0 = AI). `human` keeps meaning "player-controlled, can be lost/has elections"; planner-only towns have `human=false`. A disconnected player's town is handed to the planner and can be reclaimed on rejoin (same player name/token).

## Layers
1. **Net** (`scripts/net.gd`): peer lifecycle, lobby, player table (peer id -> name, town index, ready), ping, chat.
2. **Commands** (client -> host, reliable RPC): every player-initiated mutation becomes `cmd(town_idx, name, args)`. Host checks `town.owner == sender` and then calls the existing method (`place`, `bulldoze`, `set_water`, `set_policy`, tax rates, annex, loans, build/train priorities, treaty answers, war declarations). Single-player calls the same path locally, so there is one route into the sim.
3. **State** (host -> clients):
   - join: full snapshot (`City.to_dict()` per town, chunked) plus world meta (seed, gpos layout, clock).
   - steady state: 1 Hz compact scalar block per town (coins, pop, mood, stats, army summary, diplomacy), grid diffs from a per-town dirty-cell list (batched, reliable), events/headlines/blasts/tracers as small messages.
   - clients render from a read-only `City` mirror (`remote = true`: `tick` is a no-op, `from_dict`/diffs applied). Citizens/boats/traffic are cosmetic and animated locally from mirrored data.
4. **UI**: lobby/host/join screens (direct IP field, server list later), player list with town colours, chat, "waiting for host" states. Pause is host-only; speed is host-set.

## Phases (each = branch, tests, CHANGELOG, PR)
- [ ] P0 transport: `Net` autoload, `--server` / `--join ip:port`, host + client connect, player table, ping. Headless two-process test.
- [ ] P1 ownership: `City.owner`, per-peer "my town" (main's `city` is the local player's), spectator for extra peers.
- [ ] P2 commands: route all mutators through one command function; host validation; rejection feedback.
- [ ] P3 snapshot join + mirror + 1 Hz sync + grid diffs; a client sees a live world.
- [ ] P4 lobby UI, chat, disconnect/rejoin handling.
- [ ] P5 competitive features: player-vs-player treaties, war and raids use existing `Diplo`/`Military` with real owners.
- [ ] P6 dedicated server polish: CLI flags, config, logging, docs, optional Docker image.
- [ ] P7 hosted options beyond direct IP (relay, server list) only if wanted.

## Risks
- Bandwidth of grid diffs while towns grow fast at 8x: batch per second, compress with `PackedByteArray.compress`, measure.
- Planner towns and 8 players at once: host sim cost is the benchmark scenario; keep the standard benchmark honest and add a multiplayer one.
- Security: validate every RPC argument (bounds, owner, rate); no trust in client state; no player-supplied code or paths.
