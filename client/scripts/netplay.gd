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

var players := {}  ## peer id -> {"name": String, "ping": int ms}; host-owned, mirrored to clients
var dedicated := false
var active := false
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
	if players.erase(id):
		_push()


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
