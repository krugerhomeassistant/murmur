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
var claims := {}  ## host: player name -> the town they last ran, so a rejoin returns to it
var _acc := 0.0


## Starts a game server on `port`. dedicated = true: the host process plays no town.
func host(port := PORT, pname := "Host", ded := false) -> bool:
	stop()
	var p := ENetMultiplayerPeer.new()
	if p.create_server(port, MAX_PLAYERS - 1) != OK:
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
	multiplayer.connected_to_server.connect(func() -> void: _hello.rpc_id(1, _clean(pname)), CONNECT_ONE_SHOT)
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


static func _clean(n: String) -> String:
	n = n.strip_edges().replace("\n", " ")
	return n.substr(0, NAME_MAX) if n != "" else "Player"


func _on_peer(_id: int) -> void:
	pass  # the player joins the table once it sends its name (_hello)


func _on_gone(id: int) -> void:
	NetWorld.release(towns, id)
	if players.erase(id):
		_push()


## Chat line to everyone.
func say(text: String) -> void:
	text = text.strip_edges().substr(0, 140)
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
	if multiplayer.is_server() and players.has(multiplayer.get_remote_sender_id()):
		_relay(multiplayer.get_remote_sender_id(), text.strip_edges().substr(0, 140))


@rpc("authority", "reliable")
func _chat(who: String, text: String) -> void:
	chat.emit(who, text)


## Host: the towns clients mirror and command.
func serve(ts: Array[City]) -> void:
	towns = ts


## Host, about once a second: every town's snapshot to every client.
func broadcast() -> void:
	if not is_host() or players.size() <= (0 if dedicated else 1):
		return
	for i in towns.size():
		_state.rpc(i, NetWorld.pack(towns[i]))


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


@rpc("any_peer", "reliable")
func _hello(pname: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		return
	players[id] = {"name": _unique(_clean(pname)), "ping": 0}
	_push()
	_welcome.rpc_id(id)
	if not towns.is_empty():
		var mine := NetWorld.assign(towns, id, int(claims.get(players[id]["name"], -1)))
		if mine >= 0:
			claims[players[id]["name"]] = mine
		_world.rpc_id(id, NetWorld.meta(towns, mine))


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
	_pong.rpc_id(multiplayer.get_remote_sender_id(), t)


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
