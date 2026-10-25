class_name Run
extends Node
## One night in the evacuated house, for 1-4 players. The host owns the
## state: it places the tapes from the shared seed, takes the pickups the
## players ask for, advances the TV while someone watches, wakes the entity,
## decides captures and the end. Everyone else asks by RPC and receives the
## events. Solo runs the same code on an offline peer (the player is host).

signal tapes_changed(got: int, needed: int)
signal message(text: String)
signal phase_changed(phase: Phase)
## The local player starts (true) or stops (false) watching the TV up close.
signal read(open: bool)

enum Phase { PLAYING, CAUGHT, ESCAPED }

var phase := Phase.PLAYING
var run_seed := 0
var tapes_got := 0
var tapes_needed := Tuning.TAPES_NEEDED
var time := 0.0
var level: Level
var entity: Entity
var tv: TvBroadcast
var screens: Screens
var exit_door: ExitDoor
## peer id -> Player
var players := {}
var local_player: Player
## Whom a caught local player is watching.
var spectating: Player
var reading := false
var _watchers := {}
## Host: when the alert cut in (-1: not yet). It wakes once nobody is
## reading it any more, or after ALERT_GRACE: time to read the rules first.
var _alert_at := -1.0
var _rng := RandomNumberGenerator.new()


func setup(p_level: Level, p_players: Dictionary, p_local: Player, p_entity: Entity, p_tv: TvBroadcast, p_screens: Screens) -> void:
	level = p_level
	players = p_players
	local_player = p_local
	entity = p_entity
	tv = p_tv
	screens = p_screens


func start(p_seed: int, skip_intro := false) -> void:
	run_seed = p_seed
	_rng.seed = run_seed
	_spawn_players()
	_spawn_entity()
	_spawn_pickups()
	_spawn_exit()
	local_player.interact_requested.connect(_on_interact)
	if multiplayer.is_server():
		entity.caught.connect(_on_caught)
		tv.alert_started.connect(func() -> void: _alert_at = time)
	Net.players_changed.connect(_on_players_changed)
	tapes_changed.emit(tapes_got, tapes_needed)
	if skip_intro:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	local_player.input_enabled = false
	screens.show_intro(players.size())
	await screens.intro_done
	local_player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The player whose eyes this screen shows.
func viewed_player() -> Player:
	if local_player.alive or spectating == null:
		return local_player
	return spectating


func alive_players() -> Array[Player]:
	var out: Array[Player] = []
	for p: Player in players.values():
		if p.alive:
			out.append(p)
	return out


func _process(delta: float) -> void:
	entity.viewer = viewed_player()
	if phase != Phase.PLAYING:
		return
	time += delta
	if multiplayer.is_server():
		_host_tick(delta)
	if reading and local_player.global_position.distance_to(tv.global_position) > Tuning.READ_RANGE:
		_close_reading()
	_disturb()


func _host_tick(delta: float) -> void:
	# The alert cutting into the show is what wakes it; if nobody watches
	# the TV, the alert cuts in anyway after a while.
	if tv.state == TvBroadcast.State.SHOW and time > Tuning.ENTITY_WAKE_TIME:
		tv.interrupt()
	if not _watchers.is_empty():
		tv.watch(delta)
	if _alert_at >= 0.0 and entity.state == Entity.State.DORMANT \
			and (_watchers.is_empty() or time - _alert_at > Tuning.ALERT_GRACE):
		_wake_entity.rpc()


## Lamps and the flashlights fail near the entity (once it is awake).
func _disturb() -> void:
	var awake := entity.state != Entity.State.DORMANT
	var at := entity.global_position
	for lamp in level.lamps:
		lamp.disturbance = clampf(1.0 - lamp.global_position.distance_to(at + Vector3.UP * 2.0) / Tuning.FLICKER_RANGE, 0.0, 1.0) if awake else 0.0
	level.update_shadows(viewed_player().global_position)
	for p: Player in players.values():
		var d := p.global_position.distance_to(at)
		p.disturbance = clampf(1.0 - d / Tuning.FLASHLIGHT_FAIL_RANGE, 0.0, 1.0) if awake else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.PLAYING:
		if not local_player.alive and event is InputEventMouseButton and event.pressed:
			_spectate_next()
		return
	if event.is_action_pressed("restart") and multiplayer.is_server():
		Net.start_game(randi())
	elif event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_M:
		Net.end_session()


# --- spawning ---------------------------------------------------------------

func _spawn_players() -> void:
	var cells := level.spots_of("P")
	var c: Vector2i = cells[0] if not cells.is_empty() else Vector2i(1, 1)
	var ids := players.keys()
	ids.sort()
	for i in ids.size():
		var p: Player = players[ids[i]]
		# Side by side at the front door, facing into the house.
		p.global_position = level.center(c) + Vector3((i - (ids.size() - 1) * 0.5) * 0.8, 0, 0)
		p.set_view(0.0)


func _spawn_entity() -> void:
	var cells := level.spots_of("E")
	var c: Vector2i = cells[0] if not cells.is_empty() else Vector2i(1, 1)
	entity.level = level
	entity.players.assign(players.values())
	entity.viewer = local_player
	entity.global_position = level.center(c)
	entity.net_pos = entity.global_position


## Same seed on every machine: the same pickups in the same places, with
## the same names, so a pickup can be referred to by name. The batteries
## are there from the start; the tapes only appear once the entity wakes.
func _spawn_pickups() -> void:
	var batteries := level.spots_of("B")
	for i in batteries.size():
		_place_pickup(Pickup.Kind.BATTERY, batteries[i], "Battery%d" % i, _rng)


func _spawn_tapes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + 77
	var tape_cells := level.spots_of("T").duplicate()
	for i in range(tape_cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = tape_cells[i]
		tape_cells[i] = tape_cells[j]
		tape_cells[j] = tmp
	for i in mini(Tuning.TAPES_SPAWNED, tape_cells.size()):
		_place_pickup(Pickup.Kind.TAPE, tape_cells[i], "Tape%d" % i, rng)


func _place_pickup(kind: Pickup.Kind, c: Vector2i, pickup_name: String, rng: RandomNumberGenerator) -> void:
	var p := Pickup.create(kind)
	p.name = pickup_name
	level.add_child(p)
	p.global_position = level.center(c) + Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
	p.rotation.y = rng.randf() * TAU


func _spawn_exit() -> void:
	var cells := level.spots_of("X")
	if cells.is_empty():
		push_error("Run: the map has no exit (X)")
		return
	var c: Vector2i = cells[0]
	exit_door = ExitDoor.new()
	exit_door.run = self
	level.add_child(exit_door)
	for d in Level.DIRS:
		if level.is_walkable(c + d):
			exit_door.global_position = level.center(c) + Vector3(d.x, 0, d.y) * Level.CELL * 0.5
			exit_door.look_at(exit_door.global_position + Vector3(d.x, 0, d.y), Vector3.UP)
			break


func _on_players_changed() -> void:
	# Someone left mid-run: their body goes, the hunt goes on.
	for id: int in players.keys():
		if not Net.players.has(id):
			var p: Player = players[id]
			players.erase(id)
			entity.players.erase(p)
			message.emit(tr("%s se ha desconectado") % p.display_name)
			if spectating == p:
				spectating = null
				_spectate_next()
			p.queue_free()
	if multiplayer.is_server():
		_check_all_caught()


# --- local actions -------------------------------------------------------------

func _on_interact(target: Node) -> void:
	if phase != Phase.PLAYING or not local_player.alive:
		return
	if reading:  # E again stops watching, whatever is under the crosshair
		_close_reading()
		return
	if target is Pickup:
		_request_pickup.rpc_id(1, String(target.name))
	elif target is ReadableScreen:
		reading = true
		read.emit(true)
		_set_watching.rpc_id(1, true)
	elif target is ExitDoor and (target as ExitDoor).is_open():
		_request_escape.rpc_id(1)


func _close_reading() -> void:
	reading = false
	read.emit(false)
	_set_watching.rpc_id(1, false)


func _spectate_next() -> void:
	var alive := alive_players()
	if alive.is_empty():
		return
	var i := (alive.find(spectating) + 1) % alive.size()
	_spectate(alive[i])


func _spectate(p: Player) -> void:
	if spectating and is_instance_valid(spectating):
		spectating.avatar.show_body(true)
	spectating = p
	if p:
		p.camera.current = true
		p.avatar.show_body(false)


# --- host: requests --------------------------------------------------------------

func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


@rpc("any_peer", "call_local", "reliable")
func _set_watching(on: bool) -> void:
	if not multiplayer.is_server():
		return
	if on:
		_watchers[_sender()] = true
	else:
		_watchers.erase(_sender())


@rpc("any_peer", "call_local", "reliable")
func _request_pickup(pickup_name: String) -> void:
	if not multiplayer.is_server() or phase != Phase.PLAYING:
		return
	if level.get_node_or_null(pickup_name) is Pickup:
		_pickup_taken.rpc(pickup_name, _sender())


@rpc("any_peer", "call_local", "reliable")
func _request_escape() -> void:
	if multiplayer.is_server() and phase == Phase.PLAYING and tapes_got >= tapes_needed:
		_end.rpc(Phase.ESCAPED, time)


func _on_caught(p: Player) -> void:
	if phase != Phase.PLAYING or not p.alive:
		return
	entity.lunge_at(p)
	_player_caught.rpc(p.peer_id)
	await get_tree().create_timer(2.5).timeout
	if phase == Phase.PLAYING and not _check_all_caught():
		entity.resume()


func _check_all_caught() -> bool:
	if phase == Phase.PLAYING and alive_players().is_empty():
		_end.rpc(Phase.CAUGHT, time)
		return true
	return false


# --- events (everyone) ----------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _wake_entity() -> void:
	if multiplayer.is_server():
		entity.wake()
	Sfx.play(self, "filmed_sting", -4.0)
	# With it, the tapes: you hear them rewinding all over the house.
	_spawn_tapes()
	message.emit(tr("Se oyen cintas rebobinándose por toda la casa"))


@rpc("authority", "call_local", "reliable")
func _pickup_taken(pickup_name: String, by: int) -> void:
	var p := level.get_node_or_null(pickup_name) as Pickup
	if p == null:
		return
	Sfx.play_3d(level, p.global_position, "pickup", -2.0)
	var mine := by == multiplayer.get_unique_id()
	if p.kind == Pickup.Kind.BATTERY:
		if mine:
			local_player.camcorder.add_battery(Tuning.BATTERY_PICKUP)
			message.emit(tr("Batería cargada"))
	else:
		tapes_got += 1
		entity.tapes = tapes_got
		tapes_changed.emit(tapes_got, tapes_needed)
		if tapes_got >= tapes_needed:
			message.emit(tr("Ya están todas: volved a la furgoneta") if players.size() > 1 else tr("Vuelve a la furgoneta"))
		elif not mine:
			message.emit(tr("%s encontró una cinta (%d de %d)") % [Net.name_of(by), tapes_got, tapes_needed])
		else:
			message.emit(tr("Cinta %d de %d") % [tapes_got, tapes_needed])
		if multiplayer.is_server() and tapes_got == Tuning.TV_CORRUPT_AT:
			tv.set_corrupted()
	p.queue_free()


@rpc("authority", "call_local", "reliable")
func _player_caught(id: int) -> void:
	var p: Player = players.get(id)
	if p == null or not p.alive:
		return
	p.alive = false
	_drop_camcorder(p)
	if p == local_player:
		if reading:
			_close_reading()
		p.input_enabled = false
		p.camcorder.reveal = true
		Sfx.play(self, "caught", -2.0)
		await get_tree().create_timer(1.6).timeout
		p.camcorder.reveal = false
		if phase == Phase.PLAYING:
			_spectate_next()
			message.emit(tr("Clic: cambiar de cámara"))
	else:
		message.emit(tr("%s ha desaparecido") % p.display_name)
		if spectating == p:
			_spectate_next()


@rpc("authority", "call_local", "reliable")
func _end(p_phase: Phase, p_time: float) -> void:
	if phase != Phase.PLAYING:
		return
	phase = p_phase
	phase_changed.emit(phase)
	local_player.input_enabled = false
	if reading:
		reading = false
		read.emit(false)
	var survivors := PackedStringArray()
	for pl: Player in players.values():
		if pl.alive:
			survivors.append(pl.display_name)
	if phase == Phase.ESCAPED:
		screens.show_escaped(tapes_got, tapes_needed, p_time, players.size(), survivors, multiplayer.is_server())
	else:
		screens.show_caught(tapes_got, tapes_needed, p_time, multiplayer.is_server())


## Where someone was taken, their camcorder is left on the floor, still
## recording.
func _drop_camcorder(p: Player) -> void:
	var cam := GearModels.camcorder()
	level.add_child(cam)
	cam.global_position = Vector3(p.global_position.x, 0.06, p.global_position.z)
	cam.rotation = Vector3(0.0, _rng.randf() * TAU, PI / 2)
	(cam.get_node("Tally") as Node3D).visible = true
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.1, 0.05)
	glow.light_energy = 0.4
	glow.omni_range = 1.2
	cam.add_child(glow)
