extends Node
## Epic Online Services: a device login (no Epic account needed), a lobby
## of up to 4 found by a short code and the P2P peer the game plays
## through. The only script that names the EOS SDK; the rest of the game
## gets a MultiplayerPeer from here.

const SOCKET := "analog"
const BUCKET := "analog:coop"
const MAX_PLAYERS := 4
const CODE_LEN := 5
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var logged_in := false
var _platform_ok := false
var _busy := false
var _leaving := false
var lobby
var code := ""
## Name shown to the other players (set before setup_async).
var display_name := "Operador"
## What went wrong last (shown in the lobby UI).
var error := ""


## The platform and the login, once per session.
func setup_async() -> bool:
	if logged_in:
		return true
	var cfg := ConfigFile.new()
	if cfg.load("res://eos/credentials.cfg") != OK:
		error = tr("Faltan las credenciales de Epic en esta versión")
		return false
	var creds := HCredentials.new()
	for k in ["product_name", "product_id", "sandbox_id", "deployment_id", "client_id", "client_secret"]:
		creds.set(k, str(cfg.get_value("eos", k, "")))
	# EOS rejects an empty version (InvalidParameters on initialize).
	var version := str(ProjectSettings.get_setting("application/config/version"))
	creds.product_version = version if version != "" else "0.0.0"
	HPlatform.flags = EOS.Platform.PlatformFlags.DisableOverlay
	# The platform only once (a failed login retries on the same one).
	if not _platform_ok:
		if not await HPlatform.setup_eos_async(creds):
			error = tr("No se pudo iniciar Epic Online Services")
			return false
		_platform_ok = true
	if not await _login_async():
		error = tr("No se pudo entrar a Epic Online Services")
		return false
	logged_in = true
	return true


## Device ID login: this computer is the account (a new one is made the
## first time).
func _login_async() -> bool:
	var dev := EOS.Connect.CreateDeviceIdOptions.new()
	dev.device_model = "%s %s" % [OS.get_name(), OS.get_model_name()]
	EOS.Connect.ConnectInterface.create_device_id(dev)
	var made: Dictionary = await IEOS.connect_interface_create_device_id_callback
	if not EOS.is_success(made) and int(made.get("result_code", -1)) != EOS.Result.DuplicateNotAllowed:
		return false
	var opts := EOS.Connect.LoginOptions.new()
	opts.credentials = EOS.Connect.Credentials.new()
	opts.credentials.type = EOS.ExternalCredentialType.DeviceidAccessToken
	opts.credentials.token = null
	opts.user_login_info = EOS.Connect.UserLoginInfo.new()
	var shown := display_name.strip_edges().left(32)
	opts.user_login_info.display_name = shown if shown != "" else "Operador"
	if not await HAuth.login_game_services_async(opts):
		return false
	# EOSG 2.3.1 only tells the P2P peer who we are on a plain login (not
	# right after the account is created): once more.
	await HAuth.login_game_services_async(opts)
	EOSGRuntime.local_product_user_id = HAuth.product_user_id
	return HAuth.product_user_id != ""


## Host: a lobby with a fresh code; the P2P peer to host with (null: failed).
func host_async() -> MultiplayerPeer:
	if _busy:
		error = tr("Espera, la sala anterior aún se está cerrando…")
		return null
	_busy = true
	await _wait_leaving()
	var peer := await _host_async()
	_busy = false
	return peer


## Until a room being left / destroyed is gone (EOS: one at a time).
func _wait_leaving() -> void:
	for i in 40:
		if not _leaving:
			return
		await get_tree().create_timer(0.25, true, false, true).timeout


func _host_async() -> MultiplayerPeer:
	if not await setup_async():
		return null
	# The last room must be gone before a new one (EOS: one at a time).
	if lobby != null:
		await leave_async()
	var o := EOS.Lobby.CreateLobbyOptions.new()
	o.bucket_id = BUCKET
	o.max_lobby_members = MAX_PLAYERS
	o.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	o.local_user_id = HAuth.product_user_id
	o.presence_enabled = false
	# The room is the host's: if the host leaves, the match ends.
	o.disable_host_migration = true
	# A busy service sometimes says no: a couple more tries.
	for i in 3:
		lobby = await HLobbies.create_lobby_async(o)
		if lobby != null:
			break
		await get_tree().create_timer(1.0, true, false, true).timeout
	if lobby == null:
		error = tr("No se pudo crear la sala (Epic no respondió). Prueba de nuevo.")
		return null
	code = ""
	for i in CODE_LEN:
		code += CODE_CHARS[randi() % CODE_CHARS.length()]
	lobby.add_attribute("CODE", code)
	# The code must be in the lobby for the friends' search to find it.
	var published := false
	for i in 3:
		if await lobby.update_async():
			published = true
			break
		await get_tree().create_timer(0.8, true, false, true).timeout
	if not published:
		await leave_async()
		error = tr("No se pudo publicar la sala (Epic no respondió). Prueba de nuevo.")
		return null
	var peer := EOSGMultiplayerPeer.new()
	if peer.create_server(SOCKET) != OK:
		error = tr("No se pudo abrir la conexión")
		return null
	peer.set_auto_accept_connection_requests(true)
	return peer


## Client: the lobby with that code; the P2P peer to its host (null: none).
func join_async(p_code: String) -> MultiplayerPeer:
	if _busy:
		error = tr("Espera, ya estoy buscando la sala…")
		return null
	_busy = true
	await _wait_leaving()
	var peer := await _join_async(p_code)
	_busy = false
	return peer


func _join_async(p_code: String) -> MultiplayerPeer:
	if not await setup_async():
		return null
	if lobby != null:
		await leave_async()
	# A new room takes a moment to show up in the search: a few tries.
	var found = null
	for i in 4:
		found = await HLobbies.search_by_attribute_async({"key": "CODE", "value": p_code.strip_edges().to_upper()})
		if found != null and not (found as Array).is_empty():
			break
		await get_tree().create_timer(1.5, true, false, true).timeout
	if found == null or (found as Array).is_empty():
		error = tr("No hay ninguna sala con ese código")
		return null
	lobby = await HLobbies.join_async(found[0])
	if lobby == null:
		error = tr("No se pudo entrar a la sala (¿está llena?)")
		return null
	code = p_code.to_upper()
	var peer := EOSGMultiplayerPeer.new()
	if peer.create_client(SOCKET, lobby.owner_product_user_id) != OK:
		error = tr("No se pudo conectar con el anfitrión")
		return null
	return peer


func leave_async() -> void:
	if lobby == null:
		return
	# The room is forgotten at once (a new one may start meanwhile).
	var old = lobby
	lobby = null
	code = ""
	_leaving = true
	if old.is_owner():
		await old.destroy_async()
	else:
		await old.leave_async()
	_leaving = false


## The game is closing: the platform is released and the SDK shut down
## (left running, its threads keep the process alive after the window
## closes). Never call it straight from an EOS callback (or right after
## awaiting one): it would release the platform in the middle of its tick.
func shutdown_platform() -> void:
	if not _platform_ok:
		return
	_platform_ok = false
	logged_in = false
	# EOSGRuntime ticks the platform every frame: ticking a released one
	# crashes (signal 11).
	EOSGRuntime.set_process(false)
	EOS.Platform.PlatformInterface.release()
	EOS.Platform.PlatformInterface.shutdown()
