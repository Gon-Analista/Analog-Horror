extends Node
## The session: who is playing and how they are connected. Solo (offline
## peer), LAN (ENet, for development: two windows on one PC) and online
## (Epic Online Services, through EosNet). The game itself only uses
## Godot's multiplayer API and Net.players, so all three run the same code.

signal players_changed
signal session_failed(reason: String)

enum Mode { SOLO, LAN, ONLINE }
## The night: everyone against the house, or one of you is the entity.
enum GameMode { NORMAL, VERSUS }

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
## Tapes to recover (the host picks it; the house grows with it).
var tape_count := 5
## The host picks it in the lobby (VERSUS needs two players or more).
var game_mode := GameMode.NORMAL
## VERSUS: who the host wants as the entity (0: someone at random, never
## the same twice running if it can be helped).
var entity_choice := 0
## VERSUS: who plays it this night (sent with the start).
var entity_peer := 0
var _last_entity := 0
## Crew members played by the house (CrewBot), added in the lobby: the room
## fills up to 4 with them. Sent with the start.
var bot_count := 0
var in_game := false
## Shown by the menu after a session ends (host left, connection failed...).
var last_message := ""
## Dev: "host" / "client" for the automated two-window test (--net-test).
var test_role := ""
## Proximity voice: VoiceChat.Mode (0 open mic with voice detection,
## 1 push-to-talk with V, 2 off).
var voice_mode := 0
## How the entity is drawn: 0 the new drawing, 1 the classic ink one
## (Entity.SHEETS), 2 the 3D one (Entity.STYLE_3D). The game ships with the
## 3D one and no choice (decision of the user, 2026-10-29); the drawings stay
## for the TV and the end screens, and for --entity-style in development.
var entity_style := 2
## Host: clients that have confirmed they are in the roster (before a start).
var _acked := {}
## Client: the start came before our own place in the roster.
var _start_pending := false
var _starting := false
const LOG := "user://net_log.txt"


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void: log_line("peer_connected %d (me %d)" % [id, multiplayer.get_unique_id()]))
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: _fail(tr("No se pudo conectar con la sala")))
	multiplayer.server_disconnected.connect(func() -> void: end_session(tr("El anfitrión cerró la sala")))
	get_tree().auto_accept_quit = false


func _process(_delta: float) -> void:
	# The connection is gone (the other side crashed or quit, Epic dropped
	# it): back to the menu, not a game running on with nobody to talk to.
	if in_game and mode != Mode.SOLO and (multiplayer.multiplayer_peer == null
			or multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED):
		log_line("connection lost")
		end_session(tr("Se perdió la conexión con la sala"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		multiplayer.multiplayer_peer = null
		EosNet.shutdown_platform()
		get_tree().quit()


func is_host() -> bool:
	return multiplayer.is_server()


## Alone in the house (solo, or a room nobody joined): the game helps a bit.
func is_solo() -> bool:
	return players.size() <= 1


func my_id() -> int:
	return multiplayer.get_unique_id()


func name_of(id: int) -> String:
	return str(players.get(id, {}).get("name", "?"))


func color_of(id: int) -> Color:
	return COLORS[int(players.get(id, {}).get("slot", 0)) % COLORS.size()]


## Solo is a session of one on an offline peer: same code path as online.
func start_solo(p_seed := -1) -> void:
	_reset(Mode.SOLO)
	bot_count = 0
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


## Host: everyone loads the same house (seed and tape count), once every
## guest has confirmed it knows its own place in the roster (or 4 s).
func start_game(p_seed: int) -> void:
	if not is_host() or _starting:
		return
	_starting = true
	for i in 40:
		var missing := false
		for id: int in players:
			if id != 1 and not _acked.has(id):
				missing = true
		if not missing:
			break
		if i % 10 == 0:
			_sync_players.rpc(players)
		await get_tree().create_timer(0.1).timeout
	log_line("start seed=%d players=%s acked=%s" % [p_seed, players.keys(), _acked.keys()])
	_starting = false
	var who := 0
	bot_count = clampi(bot_count, 0, MAX_PLAYERS - players.size())
	if game_mode == GameMode.VERSUS and players.size() + bot_count >= 2:
		if players.has(entity_choice):
			who = entity_choice
		else:
			var ids := players.keys()
			if ids.size() > 1:
				ids.erase(_last_entity)
			who = ids[randi() % ids.size()]
		_last_entity = who
	_start.rpc(p_seed, tape_count, game_mode, who, bot_count)


## A line in user://net_log.txt (what each machine saw of the session).
func log_line(text: String) -> void:
	var f := FileAccess.open(LOG, FileAccess.READ_WRITE if FileAccess.file_exists(LOG) else FileAccess.WRITE)
	if f == null:
		return
	if f.get_length() > 200000:
		f.close()
		f = FileAccess.open(LOG, FileAccess.WRITE)
	f.seek_end()
	f.store_line("%s [%s] %s" % [Time.get_datetime_string_from_system(), "host" if is_host() else "guest", text])
	print("NET ", text)


func _enter_tree() -> void:
	# The session (and Epic's ticking) must go on while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in get_tree().root.get_children():
		if n.name.begins_with("EOS") or n.name.begins_with("H"):
			n.process_mode = Node.PROCESS_MODE_ALWAYS


func end_session(message := "") -> void:
	get_tree().paused = false
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
	_acked.clear()
	_start_pending = false
	code = ""
	in_game = false
	last_message = ""


func _fail(reason: String) -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	session_failed.emit(reason)


func _on_connected() -> void:
	log_line("connected, my id %d" % multiplayer.get_unique_id())
	_register.rpc_id(1, my_name, multiplayer.get_unique_id())


func _on_peer_disconnected(id: int) -> void:
	log_line("peer_disconnected %d" % id)
	_acked.erase(id)
	if is_host() and players.has(id):
		players.erase(id)
		_sync_players.rpc(players)


@rpc("any_peer", "reliable")
func _register(p_name: String, says_id := 0) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	log_line("register %s sender=%d says=%d" % [p_name, id, says_id])
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
	if not is_host() and players.has(my_id()):
		_ack.rpc_id(1)
		if _start_pending:
			_start_pending = false
			_enter_game()


## Guest -> host: "I am in the roster you sent" (see start_game).
@rpc("any_peer", "reliable")
func _ack() -> void:
	if is_host():
		_acked[multiplayer.get_remote_sender_id()] = true


## Guest -> host: send the roster again (ours did not have us in it).
@rpc("any_peer", "reliable")
func _resync() -> void:
	if is_host():
		_sync_players.rpc_id(multiplayer.get_remote_sender_id(), players)


@rpc("authority", "call_local", "reliable")
func _start(p_seed: int, tapes: int, p_mode := 0, p_entity := 0, p_bots := 0) -> void:
	bot_count = p_bots
	run_seed = p_seed
	tape_count = tapes
	game_mode = p_mode as GameMode
	entity_peer = p_entity
	in_game = true
	if not players.has(my_id()):
		# Without our own body we would look through the host's eyes,
		# unable to move: ask for the roster again and wait for it.
		log_line("start without me (id %d, roster %s): asking again" % [my_id(), players.keys()])
		_start_pending = true
		_resync.rpc_id(1)
		get_tree().create_timer(5.0).timeout.connect(func() -> void:
			if _start_pending:
				end_session(tr("No se pudo entrar en la partida (id %d)") % my_id()))
		return
	_enter_game()


func _enter_game() -> void:
	log_line("enter game, my id %d, roster %s" % [my_id(), players.keys()])
	get_tree().change_scene_to_file(GAME_SCENE)


func _local_address() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10."):
			return a
	return "127.0.0.1"
