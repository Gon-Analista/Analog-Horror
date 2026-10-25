extends Node
## The session: who is playing and how they are connected. Solo (offline
## peer), LAN (ENet, for development: two windows on one PC) and online
## (Epic Online Services, through EosNet). The game itself only uses
## Godot's multiplayer API and Net.players, so all three run the same code.

signal players_changed
signal session_failed(reason: String)

enum Mode { SOLO, LAN, ONLINE }

const PORT := 7777
const MAX_PLAYERS := 4
const GAME_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"
## Jacket colours, one per player slot: friends must be told apart in the dark.
const COLORS := [Color(0.92, 0.5, 0.16), Color(0.22, 0.62, 0.64), Color(0.78, 0.22, 0.2), Color(0.82, 0.74, 0.24)]

var mode := Mode.SOLO
## peer id -> {"name": String, "slot": int}
var players := {}
var my_name := "Operador"
## Room code (online) or address (LAN) to show in the lobby.
var code := ""
var run_seed := 0
var in_game := false
## Shown by the menu after a session ends (host left, connection failed...).
var last_message := ""
## Dev: "host" / "client" for the automated two-window test (--net-test).
var test_role := ""


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: _fail(tr("No se pudo conectar con la sala")))
	multiplayer.server_disconnected.connect(func() -> void: end_session(tr("El anfitrión cerró la sala")))
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		multiplayer.multiplayer_peer = null
		EosNet.shutdown_platform()
		get_tree().quit()


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func name_of(id: int) -> String:
	return str(players.get(id, {}).get("name", "?"))


func color_of(id: int) -> Color:
	return COLORS[int(players.get(id, {}).get("slot", 0)) % COLORS.size()]


## Solo is a session of one on an offline peer: same code path as online.
func start_solo(p_seed := -1) -> void:
	_reset(Mode.SOLO)
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {1: {"name": my_name, "slot": 0}}
	start_game(randi() if p_seed < 0 else p_seed)


## Used when the game scene is opened directly (editor F6, dev flags).
func ensure_solo_players() -> void:
	if players.is_empty():
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		players = {1: {"name": my_name, "slot": 0}}


func host_lan() -> bool:
	_reset(Mode.LAN)
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, MAX_PLAYERS - 1) != OK:
		_fail(tr("No se pudo abrir la sala en el puerto %d") % PORT)
		return false
	multiplayer.multiplayer_peer = peer
	code = _local_address()
	players = {1: {"name": my_name, "slot": 0}}
	players_changed.emit()
	return true


func join_lan(address: String) -> bool:
	_reset(Mode.LAN)
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, PORT) != OK:
		_fail(tr("Dirección no válida"))
		return false
	multiplayer.multiplayer_peer = peer
	code = address
	return true


func host_online() -> bool:
	_reset(Mode.ONLINE)
	EosNet.display_name = my_name
	var peer := await EosNet.host_async()
	if peer == null:
		_fail(EosNet.error)
		return false
	multiplayer.multiplayer_peer = peer
	code = EosNet.code
	players = {1: {"name": my_name, "slot": 0}}
	players_changed.emit()
	return true


func join_online(p_code: String) -> bool:
	_reset(Mode.ONLINE)
	EosNet.display_name = my_name
	var peer := await EosNet.join_async(p_code)
	if peer == null:
		_fail(EosNet.error)
		return false
	multiplayer.multiplayer_peer = peer
	code = EosNet.code
	return true


## Host: everyone loads the house with the same seed.
func start_game(p_seed: int) -> void:
	if is_host():
		_start.rpc(p_seed)


func end_session(message := "") -> void:
	last_message = message
	var was_online := mode == Mode.ONLINE
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	in_game = false
	if was_online:
		EosNet.leave_async()
	get_tree().change_scene_to_file(MENU_SCENE)


func _reset(p_mode: Mode) -> void:
	mode = p_mode
	players.clear()
	code = ""
	in_game = false
	last_message = ""


func _fail(reason: String) -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	session_failed.emit(reason)


func _on_connected() -> void:
	_register.rpc_id(1, my_name)


func _on_peer_disconnected(id: int) -> void:
	if is_host() and players.has(id):
		players.erase(id)
		_sync_players.rpc(players)


@rpc("any_peer", "reliable")
func _register(p_name: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_game or players.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var used := []
	for p: Dictionary in players.values():
		used.append(p.slot)
	var slot := 0
	while used.has(slot):
		slot += 1
	players[id] = {"name": p_name.strip_edges().left(16), "slot": slot}
	_sync_players.rpc(players)


@rpc("authority", "call_local", "reliable")
func _sync_players(p: Dictionary) -> void:
	players = p
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _start(p_seed: int) -> void:
	run_seed = p_seed
	in_game = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _local_address() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10."):
			return a
	return "127.0.0.1"
