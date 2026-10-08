class_name NetPlay
extends Node
## Multiplayer transport and lobby (docs/MULTIPLAYER.md, phase 0). One code path for a player-hosted game and a dedicated
## server: the host is always peer 1; a dedicated server just isn't in the player table. Created as a child of the root
## named "Net" so RPC paths match on every peer. Game state does not travel yet.

const PORT := 7777
const MAX_PLAYERS := 8
const NAME_MAX := 20

signal roster_changed
signal joined  ## client: accepted by the host
signal failed(reason: String)
signal world(meta: Dictionary)  ## client: the world layout and which town is yours
signal state(idx: int, d: Dictionary)  ## client: a town snapshot arrived
signal chat(who: String, text: String)
signal reply(cmd: String, result: Variant)  ## client: the host's answer to a command

var players := {}  ## peer id -> {"name": String, "ping": int ms}; host-owned, mirrored to clients
var dedicated := false
var active := false
var towns: Array[City] = []  ## host: the simulated towns (set with serve)
var claims := {}  ## host: rejoin token -> the town they last ran, so a rejoin returns to it (the name is not proof of who you are)
var _tok := {}  ## host: peer id -> rejoin token (never sent to other players)
var _seq := 0  ## host: snapshot rounds sent
var _acked := {}  ## host: peer id -> last round the client confirmed
const LAG := 4  ## rounds a client may fall behind before it is skipped
const KICK_LAG := 60  ## rounds behind before it is dropped
var _acc := 0.0
var _bucket := {}  ## host: peer id -> [tokens, last refill time]
const HELLO_WAIT := 5.0  ## a peer that has not said hello by then is dropped, so silent connections cannot fill the slots


## Starts a game server on `port`. dedicated = true: the host process plays no town.
func host(port := PORT, pname := "Host", ded := false) -> bool:
	stop()
	var p := ENetMultiplayerPeer.new()
	if p.create_server(port, MAX_PLAYERS if ded else MAX_PLAYERS - 1) != OK:
		failed.emit("Could not listen on port %d." % port)
		return false
	multiplayer.multiplayer_peer = p
	dedicated = ded
	active = true
	players.clear()
	if not ded:
		players[1] = {"name": _clean(pname), "ping": 0}
	multiplayer.peer_connected.connect(_on_peer, CONNECT_REFERENCE_COUNTED)
	multiplayer.peer_disconnected.connect(_on_gone, CONNECT_REFERENCE_COUNTED)
	roster_changed.emit()
	return true


func join(ip: String, port := PORT, pname := "Player") -> bool:
	stop()
	var p := ENetMultiplayerPeer.new()
	if p.create_client(ip, port) != OK:
		failed.emit("Could not connect to %s:%d." % [ip, port])
		return false
	multiplayer.multiplayer_peer = p
	active = true
	players.clear()
	multiplayer.connected_to_server.connect(func() -> void: _hello.rpc_id(1, _clean(pname), _my_token()), CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(func() -> void: stop(); failed.emit("Connection failed."), CONNECT_ONE_SHOT)
	multiplayer.server_disconnected.connect(func() -> void: stop(); failed.emit("Host closed the game."), CONNECT_ONE_SHOT)
	return true


func stop() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	for s in [multiplayer.peer_connected, multiplayer.peer_disconnected]:
		for c in s.get_connections():
			s.disconnect(c["callable"])
	players.clear()
	active = false
	dedicated = false


func is_host() -> bool:
	return active and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1


## Control characters (newlines, tabs, ANSI escapes) become spaces so one chat line or name cannot fake another or forge a log line.
static func _plain(t: String) -> String:
	var out := ""
	for i in t.length():
		out += " " if t.unicode_at(i) < 32 or t.unicode_at(i) == 127 else t[i]
	return out.strip_edges()


static func _clean(n: String) -> String:
	n = _plain(n)
	if n.to_lower() == "server":
		n = "Player"
	return n.substr(0, NAME_MAX) if n != "" else "Player"


## Host: token bucket per peer so one client cannot pin the host with a command loop (30 per second, bursts of 60).
## This install's secret rejoin token (kept in user://net.cfg); a fresh random one per session if the file cannot be written.
static func _my_token() -> String:
	var cf := ConfigFile.new()
	cf.load("user://net.cfg")
	var t := String(cf.get_value("net", "token", ""))
	if t.length() < 16:
		t = Crypto.new().generate_random_bytes(16).hex_encode()
		cf.set_value("net", "token", t)
		cf.save("user://net.cfg")
	return t


func _allow(id: int, cost := 1.0) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var b: Array = _bucket.get(id, [60.0, now])
	b[0] = minf(float(b[0]) + (now - float(b[1])) * 30.0, 60.0)
	b[1] = now
	_bucket[id] = b
	if float(b[0]) < cost:
		return false
	b[0] = float(b[0]) - cost
	return true


func _on_peer(id: int) -> void:
	# the player joins the table once it sends its name (_hello); silent peers are dropped
	get_tree().create_timer(HELLO_WAIT).timeout.connect(func() -> void:
		if active and multiplayer.is_server() and not players.has(id) and multiplayer.get_peers().has(id):
			multiplayer.multiplayer_peer.disconnect_peer(id))


func _on_gone(id: int) -> void:
	_bucket.erase(id)
	_tok.erase(id)
	_acked.erase(id)
	NetWorld.release(towns, id)
	if players.erase(id):
		_push()


## Chat line to everyone.
func say(text: String) -> void:
	text = _plain(text).substr(0, 140)
	if text == "" or not active:
		return
	if is_host():
		_relay(1, text)
	else:
		_say.rpc_id(1, text)


func _relay(id: int, text: String) -> void:
	var who: String = players[id]["name"] if players.has(id) else "Server"
	chat.emit(who, text)
	_chat.rpc(who, text)


@rpc("any_peer", "reliable")
func _say(text: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and players.has(id) and _allow(id, 20.0):  # a line costs 20 tokens: about 1.5 per second sustained
		_relay(id, _plain(text).substr(0, 140))


@rpc("authority", "reliable")
func _chat(who: String, text: String) -> void:
	chat.emit(who, text)


## Host: the towns clients mirror and command.
var world_info := {}  ## host: {"seed", "rivers"} sent to joiners so they draw the same land between towns


func serve(ts: Array[City], winfo := {}) -> void:
	towns = ts
	world_info = winfo


## Host, about once a second: every town's snapshot to every client.
func broadcast() -> void:
	if not is_host() or players.size() <= (0 if dedicated else 1):
		return
	_seq += 1
	var packs: Array[PackedByteArray] = []
	for t in towns:
		packs.append(NetWorld.pack(t))
	for id in multiplayer.get_peers():
		if not players.has(id):
			continue
		var gap := _seq - int(_acked.get(id, _seq - 1))
		if gap > KICK_LAG:
			multiplayer.multiplayer_peer.disconnect_peer(id)  # stalled for a minute: stop queueing for it
			continue
		if gap > LAG:
			_round.rpc_id(id, _seq)  # a slow client skips snapshots (only this tiny ping queues) and catches up once it answers
			continue
		for i in packs.size():
			_state.rpc_id(id, i, packs[i])
		_round.rpc_id(id, _seq)


## A player action. Clients ask the host; the host runs it for its own town directly.
func command(idx: int, cname: String, args: Array) -> Variant:
	if not active:
		return null
	if is_host():
		return _run(1, idx, cname, args)
	_cmd.rpc_id(1, idx, cname, args)
	return null  # the answer arrives as the `reply` signal


func _run(sender: int, idx: int, cname: String, args: Array) -> Variant:
	if idx < 0 or idx >= towns.size() or towns[idx].owner != sender:
		return null  # not your town
	return Cmd.run(towns, towns[idx], cname, args)


@rpc("any_peer", "reliable")
func _cmd(idx: int, cname: String, args: Array) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not players.has(sender) or not _allow(sender):
		return
	var r: Variant = _run(sender, idx, cname, args)
	_reply.rpc_id(sender, cname, r if (r == null or r is bool or r is String or r is int) else true)


@rpc("authority", "reliable")
func _reply(cname: String, r: Variant) -> void:
	reply.emit(cname, r)


@rpc("authority", "reliable")
func _world(meta: Dictionary) -> void:
	world.emit(meta)


@rpc("authority", "reliable")
func _state(idx: int, b: PackedByteArray) -> void:
	var d := NetWorld.unpack(b)
	if not d.is_empty():
		state.emit(idx, d)


@rpc("authority", "reliable")
func _round(n: int) -> void:
	_ack.rpc_id(1, n)


@rpc("any_peer", "reliable")
func _ack(n: int) -> void:
	if multiplayer.is_server():
		var id := multiplayer.get_remote_sender_id()
		_acked[id] = maxi(int(_acked.get(id, 0)), n)


@rpc("any_peer", "reliable")
func _hello(pname: String, token: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		return
	var tok := token if token.length() >= 16 and token.length() <= 64 else ""
	if tok != "":
		for old in _tok.keys():
			if _tok[old] == tok and old != id:  # same player reconnecting before the old link timed out: take the old seat over
				multiplayer.multiplayer_peer.disconnect_peer(old)
				_on_gone(old)
		_tok[id] = tok
	_acked[id] = _seq
	players[id] = {"name": _unique(_clean(pname)), "ping": 0}
	_push()
	_welcome.rpc_id(id)
	if not towns.is_empty():
		var mine := NetWorld.assign(towns, id, int(claims.get(tok, -1)) if tok != "" else -1)
		if mine >= 0 and tok != "":
			claims[tok] = mine
		_world.rpc_id(id, NetWorld.meta(towns, mine, world_info))


func _unique(n: String) -> String:
	var names := players.values().map(func(p: Dictionary) -> String: return p["name"])
	var out := n
	var k := 2
	while out in names:
		out = "%s %d" % [n, k]
		k += 1
	return out


@rpc("authority", "reliable")
func _welcome() -> void:
	joined.emit()


func _push() -> void:
	roster_changed.emit()
	_roster.rpc(players)


@rpc("authority", "reliable")
func _roster(p: Dictionary) -> void:
	players = p
	roster_changed.emit()


@rpc("any_peer", "unreliable")
func _ping(t: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		_pong.rpc_id(id, t)


@rpc("authority", "unreliable")
func _pong(t: int) -> void:
	var ms := int((Time.get_ticks_usec() - t) / 1000)
	_rtt.rpc_id(1, ms)


@rpc("any_peer", "unreliable")
func _rtt(ms: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id]["ping"] = clampi(ms, 0, 9999)


func _process(delta: float) -> void:
	if not active or multiplayer.multiplayer_peer == null:
		return
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	if multiplayer.is_server():
		if not players.is_empty():
			_roster.rpc(players)  # 1 Hz keeps pings fresh; tiny
	elif multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_ping.rpc_id(1, Time.get_ticks_usec())
