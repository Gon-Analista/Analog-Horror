class_name Run
extends Node
## One night in the evacuated house, for 1-4 players. The host owns the
## state: it places the tapes from the shared seed, takes the pickups the
## players ask for, advances the TV while someone watches, wakes the entity,
## decides captures and the end. Everyone else asks by RPC and receives the
## events. Solo runs the same code on an offline peer (the player is host).

signal tapes_changed(got: int, needed: int)
signal message(text: String)
## The goal changes (all the tapes: out by the front door): a title, what
## to do, and the line that stays on screen until it is done.
signal objective(title: String, line: String, reminder: String)
signal phase_changed(phase: Phase)
## The local player starts (true) or stops (false) watching the TV up close.
signal read(open: bool)

enum Phase { PLAYING, CAUGHT, ESCAPED }

var phase := Phase.PLAYING
var run_seed := 0
var tapes_got := 0
var tapes_needed := Tuning.TAPES_DEFAULT
var time := 0.0
var level: Level
var entity: Entity
var tv: TvBroadcast
var screens: Screens
var exit_door: ExitDoor
## peer id -> Player
var players := {}
var local_player: Player
const RELOAD_LOCK_MS := 900  # (the hands are busy putting it in)
var _reloaded_at := -RELOAD_LOCK_MS
var _hinting := false
## Whom a caught local player is watching.
var spectating: Player
var reading := false
var _watchers := {}
## Host: when the alert cut in (-1: not yet). It wakes once nobody is
## reading it any more, or after ALERT_GRACE: time to read the rules first.
var _alert_at := -1.0
## Host: how long the woken entity has waited for its cry, and how long
## nobody has been at the TV (it cries a moment after the last one leaves).
var _cry_total := 0.0
var _cry_clear := 0.0
var _rng := RandomNumberGenerator.new()
## 1 when it screams (all tapes taken), fading: a burst of interference.
var rage_flash := 0.0
## 1 when a friend's flash went off in our eyes, fading (the HUD whites out).
var dazzle := 0.0
var _ended_at := 0
var _cam_seq := 0
## Bodies of the taken (the entity plays with them).
var corpses: Array[Corpse] = []
signal paused_changed(on: bool)
## The local player's flash went off (the viewfinder whites out).
signal flash
## The local player has just been taken: the screamer (viewfinder cuts).
signal scared
## The night's best moments, played back at the end (see Replay).
var replay: Replay
var _moment_seq := 0
## Host: close calls being watched (peer id -> seconds left to survive), and
## when each player last had one.
var _close := {}
var _close_last := {}
## "La Visita es un jugador": who plays it (0: the house does), the same on
## every machine; and on that player's machine, the controls.
var entity_peer := 0
var pilot: EntityPilot
var _pilot_scream_at := -99.0
var _pilot_attack_at := -99.0
var _pilot_voice_in := 6.0
var _pilot_last_mode := -1


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
	_pick_entity_player()
	_assign_cameras()
	_spawn_entity()
	_spawn_pickups()
	_spawn_exit()
	local_player.interact_requested.connect(_on_interact)
	local_player.drop_camera_requested.connect(_on_drop_camera)
	local_player.reload_requested.connect(_on_reload)
	local_player.camcorder.flash_fired.connect(_on_flash)
	replay = Replay.new()
	replay.name = "Replay"
	add_child(replay)
	replay.setup(self)
	if multiplayer.is_server():
		entity.caught.connect(_on_caught)
		entity.moment.connect(_moment)
		tv.alert_started.connect(func() -> void: _alert_at = time)
	Net.players_changed.connect(_on_players_changed)
	tapes_changed.emit(tapes_got, tapes_needed)
	if entity_peer == local_player.peer_id:
		become_pilot()
	if skip_intro:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	local_player.input_enabled = false
	if pilot:
		screens.show_pilot_intro(players.size() - 1, tapes_needed)
	else:
		screens.show_intro(players.size() - (1 if entity_peer else 0), tapes_needed, Net.name_of(entity_peer) if entity_peer else "")
	await screens.intro_done
	local_player.input_enabled = pilot == null
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
	rage_flash = maxf(0.0, rage_flash - delta * 0.8)
	dazzle = maxf(0.0, dazzle - delta / Tuning.FLASH_BLIND_TIME)
	if phase != Phase.PLAYING:
		return
	if not local_player.input_enabled and Net.is_solo() and pilot == null:
		return  # (alone, reading the intro: the night waits)
	time += delta
	if multiplayer.is_server():
		_host_tick(delta)
	if reading and not local_player.seated and local_player.global_position.distance_to(tv.global_position) > Tuning.READ_RANGE:
		_close_reading()
	_disturb()


func _host_tick(delta: float) -> void:
	# The alert cutting into the show is what wakes it; if nobody watches
	# the TV, the alert cuts in anyway after a while.
	if tv.state == TvBroadcast.State.SHOW and time > Tuning.ENTITY_WAKE_TIME * (0.5 if entity_peer else 1.0):
		tv.interrupt()
	if not _watchers.is_empty():
		tv.watch(delta)
	if _alert_at >= 0.0 and entity.state == Entity.State.DORMANT \
			and (_watchers.is_empty() or time - _alert_at > Tuning.ALERT_GRACE):
		_wake_entity.rpc()
	if entity.cry_pending:
		_cry_total += delta
		_cry_clear = _cry_clear + delta if _watchers.is_empty() else 0.0
		if _cry_clear > 1.5 or _cry_total > 40.0:
			entity.cry()
	_watch_close_calls(delta)
	if entity.is_piloted():
		_pilot_voice(delta)


## Host: it got within a hand of someone in a chase and they lived: a clip.
func _watch_close_calls(delta: float) -> void:
	for id: int in _close.keys():
		var p: Player = players.get(id)
		if p == null or not p.alive:
			_close.erase(id)
			continue
		_close[id] -= delta
		if _close[id] <= 0.0:
			_close.erase(id)
			_moment("close", p)
	if entity.state != Entity.State.STALKING or entity.mode != Entity.Mode.CHASE:
		return
	for p in alive_players():
		if _close.has(p.peer_id) or time - float(_close_last.get(p.peer_id, -99.0)) < 20.0:
			continue
		var d := p.global_position - entity.global_position
		if absf(d.y) < 1.2 and Vector2(d.x, d.z).length() < 1.4:
			_close[p.peer_id] = 4.0
			_close_last[p.peer_id] = time


## Host: something worth seeing again; every machine keeps its seconds.
func _moment(kind: String, who: Player) -> void:
	if who == null or phase != Phase.PLAYING:
		return
	_moment_seq += 1
	_mark_moment.rpc(_moment_seq, kind, who.peer_id)


@rpc("authority", "call_local", "reliable")
func _mark_moment(id: int, kind: String, focus: int) -> void:
	replay.mark(id, kind, focus)


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
		if pilot == null and not local_player.alive and event is InputEventMouseButton and event.pressed:
			_spectate_next()
		return
	if Time.get_ticks_msec() - _ended_at < 1500:
		return  # (a key still held when the night ended does nothing)
	if event is InputEventKey and event.pressed and not event.echo and multiplayer.is_server() and not replay.clips.is_empty():
		# The best moments' TV: the arrows go through the clips, SPACE plays
		# them all in a row.
		var key := (event as InputEventKey).physical_keycode
		var n := replay.clips.size()
		var at := maxi(0, replay.current())
		if key == KEY_LEFT or key == KEY_A:
			_play_replay.rpc((at - 1 + n) % n)
			return
		if key == KEY_RIGHT or key == KEY_D:
			_play_replay.rpc((at + 1) % n)
			return
		if key == KEY_SPACE:
			_play_replay.rpc(-1)
			return
	if event.is_action_pressed("restart") and not event.is_echo() and multiplayer.is_server():
		Net.start_game(randi())
	elif event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_M:
		Net.end_session()


# --- spawning ---------------------------------------------------------------

func _spawn_players() -> void:
	var c: Vector3i = level.spots_of("P")[0]
	# Side by side just inside the front door, facing into the house.
	var cells: Array[Vector3i] = []
	for off: Vector3i in [Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(2, 0, 0), Vector3i(-2, 0, 0)]:
		if level.is_walkable(c + off):
			cells.append(c + off)
	var ids := players.keys()
	ids.sort()
	for i in ids.size():
		var p: Player = players[ids[i]]
		p.global_position = level.center(cells[i % cells.size()])
		p.set_view(0.0)
		if p.is_bot:
			p.net_pos = p.global_position


## One camcorder for every two players (1 for 1-2, 2 for 3-4), handed to
## every other player in join order. Same result on every machine.
func _assign_cameras() -> void:
	var ids := players.keys()
	ids.sort()
	ids.erase(entity_peer)
	var cameras := ids.size() if not Tuning.SCARCE_CAMERAS else maxi(1, ceili(ids.size() / 2.0))
	for i in ids.size():
		var p: Player = players[ids[i]]
		p.has_camera = i < cameras if not Tuning.SCARCE_CAMERAS else (i % 2 == 0 and i / 2 < cameras)
	if entity_peer and players.has(entity_peer):
		players[entity_peer].has_camera = false
	if not local_player.has_camera and local_player.peer_id != entity_peer:
		message.emit(tr("No llevas cámara: quédate cerca de quien la lleva"))


func _spawn_entity() -> void:
	var c: Vector3i = level.spots_of("E")[0]
	entity.level = level
	entity.corpses = corpses
	entity.players.assign(players.values().filter(func(p: Player) -> bool: return p.peer_id != entity_peer))
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
		var tmp: Vector3i = tape_cells[i]
		tape_cells[i] = tape_cells[j]
		tape_cells[j] = tmp
	for i in mini(tapes_needed + 1, tape_cells.size()):
		_place_pickup(Pickup.Kind.TAPE, tape_cells[i], "Tape%d" % i, rng)


func _place_pickup(kind: Pickup.Kind, c: Vector3i, pickup_name: String, rng: RandomNumberGenerator) -> void:
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
	var c: Vector3i = cells[0]
	exit_door = ExitDoor.new()
	exit_door.run = self
	level.add_child(exit_door)
	for d in Level.DIRS:
		if level.is_walkable(c + Vector3i(d.x, 0, d.y)):
			exit_door.global_position = level.center(c) + Vector3(d.x, 0, d.y) * Level.CELL * 0.5
			exit_door.look_at(exit_door.global_position + Vector3(d.x, 0, d.y), Vector3.UP)
			break


func _on_players_changed() -> void:
	# Someone left mid-run: their body goes, the hunt goes on.
	for id: int in players.keys():
		if not Net.players.has(id) and not players[id].is_bot:
			var p: Player = players[id]
			players.erase(id)
			if id == entity_peer:
				_pilot_gone()
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
	if reading:  # E again gets up, but only once the alert is on the screen
		if tv.is_showing_text():
			_close_reading()
		return
	if local_player.hiding:
		local_player.leave_hide()
		return
	if target is HideSpot:
		local_player.hide_in(target)
	elif target is Pickup:
		if (target as Pickup).kind == Pickup.Kind.BATTERY and not local_player.inventory.bag.has(""):
			message.emit(tr("No te caben más baterías"))
			return
		_request_pickup.rpc_id(1, String(target.name))
	elif target is ReadableScreen:
		# Sat in front of it: you watch it from there to the end (the
		# programme, what it shows of the room, the alert).
		var seat := tv.seat_for(_seat_index())
		local_player.sit(seat[0], seat[1], seat[2], seat[3])
		reading = true
		read.emit(true)
		_set_watching.rpc_id(1, true)
	elif target is ExitDoor and (target as ExitDoor).is_open():
		_request_escape.rpc_id(1)
	elif target is Door:
		_request_door.rpc_id(1, String(target.name))
	elif target is HouseWindow:
		_request_window.rpc_id(1, String(target.name))


## Host: open or close a window (not while it slides or right after). It
## scrapes: the entity hears it.
@rpc("any_peer", "call_local", "reliable")
func _request_window(window_name: String) -> void:
	if not multiplayer.is_server() or phase != Phase.PLAYING:
		return
	var w := level.get_node_or_null(window_name) as HouseWindow
	var who: Player = players.get(_sender())
	if w == null or who == null or not who.alive or not w.ready_to_move():
		return
	if who.global_position.distance_to(w.global_position) > Tuning.INTERACT_RANGE + 1.2:
		return
	w.set_open.rpc(not w.is_open)
	entity.hear(w.global_position + Vector3.UP * 1.3, Tuning.NOISE_PICKUP)


## Host: open or close a door, unless it is swinging or was just used, or
## (closing) someone stands in it or the entity is close: it holds it.
@rpc("any_peer", "call_local", "reliable")
func _request_door(door_name: String) -> void:
	if not multiplayer.is_server() or phase != Phase.PLAYING:
		return
	var door := level.get_node_or_null(door_name) as Door
	var who: Player = players.get(_sender())
	if door == null or who == null or not who.alive or not door.ready_to_move():
		return
	if who.global_position.distance_to(door.global_position) > Tuning.INTERACT_RANGE + 1.2:
		return
	if door.is_open:
		for p: Player in players.values():
			if p.alive and level.cell_of(p.global_position) == door.cell:
				return  # someone is in the doorway
		# It can be shut in its face (it opens it again, or goes over
		# it); only with it in the doorway itself does it hold it.
		if entity.state != Entity.State.DORMANT and level.cell_of(entity.global_position) == door.cell:
			_tell.rpc_id(who.peer_id, tr("Algo la sujeta desde el otro lado"))
			return
	if door.is_open and entity.state == Entity.State.STALKING and entity.global_position.distance_to(door.global_position) < 3.0:
		_moment("door", who)  # shut in its face
	door.set_open.rpc(not door.is_open, false, door.swing_from(who.global_position))
	entity.hear(door.global_position, Tuning.NOISE_PICKUP)


func _on_drop_camera() -> void:
	if phase == Phase.PLAYING and local_player.alive and local_player.has_camera and not Net.is_solo():
		_request_drop.rpc_id(1, local_player.camcorder.battery)


## The power goes when half the tapes are found (at least one).
func blackout_at() -> int:
	return maxi(1, ceili(tapes_needed / 2.0))


## Which seat is ours: the order of the players (the same on every machine).
func _seat_index() -> int:
	var ids := players.keys()
	ids.sort()
	return ids.find(local_player.peer_id)


func _close_reading() -> void:
	local_player.stand_up()
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
	var p := level.get_node_or_null(pickup_name) as Pickup
	var who: Player = players.get(_sender())
	if p == null or who == null or not who.alive:
		return
	# One camcorder each.
	if p.kind == Pickup.Kind.CAMERA and who.has_camera:
		_tell.rpc_id(who.peer_id, tr("Ya llevas una cámara"))
		return
	_pickup_taken.rpc(pickup_name, who.peer_id)


## R: a spare battery from the bag into the camcorder.
func _on_reload() -> void:
	if phase != Phase.PLAYING or Time.get_ticks_msec() - _reloaded_at < RELOAD_LOCK_MS:
		return
	var me := local_player
	if not me.inventory.has("battery"):
		message.emit(tr("No llevas baterías"))
	elif not me.has_camera:
		message.emit(tr("No llevas cámara"))
	elif me.camcorder.battery >= 100.0:
		message.emit(tr("La cámara ya está cargada"))
	else:
		_reloaded_at = Time.get_ticks_msec()
		me.inventory.remove("battery")
		me.camcorder.add_battery(Tuning.BATTERY_PICKUP)
		if me.viewmodel:
			me.viewmodel.play_grab("battery")
		message.emit(tr("Batería cargada"))
		_battery_changed.rpc()


## Someone changed a battery: it can be heard, also by the Visita.
@rpc("any_peer", "call_local", "reliable")
func _battery_changed() -> void:
	var who: Player = players.get(_sender())
	if who == null:
		return
	if who != local_player:
		Sfx.play_3d(level, who.global_position, "battery_insert", -6.0)
	if multiplayer.is_server():
		entity.hear(who.global_position, Tuning.NOISE_PICKUP)


## The first camcorder ever to run out with a spare in the bag: the hint
## stays until the battery is in (or there is none), and never comes back.
func reload_hint() -> bool:
	var me := local_player
	if me == null or not me.alive or not me.has_camera or me.camcorder.battery > 0.0 or not me.inventory.has("battery"):
		_hinting = false
	elif not _hinting and not Settings.reload_hint_seen:
		_hinting = true
		Settings.reload_hint_seen = true
		Settings.save()
	return _hinting


## Host: a player lets go of their camcorder (to pass it on), in front of them.
@rpc("any_peer", "call_local", "reliable")
func _request_drop(battery: float) -> void:
	if not multiplayer.is_server() or phase != Phase.PLAYING:
		return
	var who: Player = players.get(_sender())
	if who == null or not who.alive or not who.has_camera:
		return
	var at := _floor_spot(who.global_position - who.global_transform.basis.z * 0.6, who.global_position)
	_cam_seq += 1
	_camera_dropped.rpc(who.peer_id, "Camcorder%d" % _cam_seq, at, battery, false)


## On the floor at `at`, or at `fallback` if that is a wall, furniture or
## the stairwell: nothing dropped ends up inside the house's geometry.
func _floor_spot(at: Vector3, fallback: Vector3) -> Vector3:
	var c := level.cell_of(at)
	if level.is_walkable(c):
		return Vector3(at.x, level.center(c).y, at.z)
	return level.center(level.nearest_walkable(level.cell_of(fallback)))


@rpc("authority", "call_local", "reliable")
func _camera_dropped(id: int, cam_name: String, at: Vector3, battery: float, recording: bool) -> void:
	var p: Player = players.get(id)
	if p:
		p.has_camera = false
	var cam := Pickup.create(Pickup.Kind.CAMERA)
	cam.name = cam_name
	cam.battery = battery
	cam.recording = recording
	level.add_child(cam)
	cam.global_position = at
	if multiplayer.is_server() and not recording:
		entity.hear(at, Tuning.NOISE_CAMERA)
	if not recording:
		Sfx.play_3d(level, at, "click", -4.0)
		message.emit(tr("Has soltado la cámara") if p == local_player else tr("%s ha soltado la cámara") % Net.name_of(id))


@rpc("authority", "call_local", "reliable")
func _tell(text: String) -> void:
	message.emit(text)


@rpc("any_peer", "call_local", "reliable")
func _request_escape() -> void:
	if multiplayer.is_server() and phase == Phase.PLAYING and tapes_got >= tapes_needed:
		_moment("escape", players.get(_sender()))
		_end.rpc(Phase.ESCAPED, time, _sender())  # one out is enough


func _on_caught(p: Player) -> void:
	if p.net_god and phase == Phase.PLAYING:
		entity.resume()  # immortal (Alt+F1): it lets go
		return
	if phase != Phase.PLAYING or not p.alive:
		if phase == Phase.PLAYING and entity.state == Entity.State.FEEDING:
			entity.resume()  # (already taken: nothing to hold)
		return
	entity.lunge_at(p)
	_moment("caught", p)
	_player_caught.rpc(p.peer_id)
	# The last one: straight from its face to "no signal" (no glimpse of
	# the house in between).
	await get_tree().create_timer(1.6 if alive_players().is_empty() else 2.5).timeout
	if phase == Phase.PLAYING and not _check_all_caught():
		entity.resume()


func _check_all_caught() -> bool:
	if phase == Phase.PLAYING and alive_players().is_empty():
		_end.rpc(Phase.CAUGHT, time, 0)
		return true
	return false


# --- events (everyone) ----------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _wake_entity() -> void:
	if multiplayer.is_server():
		entity.wake()
		if entity.is_piloted():
			_pilot_place.rpc_id(entity_peer, entity.global_position)  # where it comes in
	# (No sting: the only sound is its cry, far away; Entity._wake_cry.)
	# With it, the tapes: you hear them rewinding all over the house.
	_spawn_tapes()
	message.emit(tr("Se oyen cintas rebobinándose por toda la casa"))


@rpc("authority", "call_local", "reliable")
func _pickup_taken(pickup_name: String, by: int) -> void:
	var p := level.get_node_or_null(pickup_name) as Pickup
	if p == null:
		return
	Sfx.play_3d(level, p.global_position, "pickup", -2.0)
	if multiplayer.is_server():
		entity.hear(p.global_position, Tuning.NOISE_CAMERA if p.kind == Pickup.Kind.CAMERA else Tuning.NOISE_PICKUP)
	var mine := by == multiplayer.get_unique_id()
	if mine and local_player.viewmodel:  # the hand goes down for it (never stops you)
		local_player.viewmodel.play_grab(["tape", "battery", "camcorder"][p.kind])
	if p.kind == Pickup.Kind.CAMERA:
		var who: Player = players.get(by)
		if who:
			who.has_camera = true
		if mine:
			local_player.camcorder.battery = p.battery
			message.emit(tr("Llevas la cámara (%d%%)") % int(p.battery))
		else:
			message.emit(tr("%s lleva la cámara") % Net.name_of(by))
	elif p.kind == Pickup.Kind.BATTERY:
		if mine:
			local_player.inventory.add_to_bag("battery")
			message.emit(tr("Batería guardada"))
	else:
		tapes_got += 1
		entity.tapes = tapes_got
		tapes_changed.emit(tapes_got, tapes_needed)
		if tapes_got == tapes_needed:
			_enrage()
			if multiplayer.is_server():
				_moment("rage", players.get(by))
		if tapes_got == tapes_needed and pilot != null:
			message.emit(tr("¡Tienen todas las cintas! Van a la puerta de entrada"))
		elif tapes_got == tapes_needed:
			var many := players.size() > 1
			objective.emit(tr("¡TENÉIS TODAS LAS CINTAS!") if many else tr("¡TIENES TODAS LAS CINTAS!"),
					tr("Salid por la puerta por la que entrasteis") if many else tr("Sal por la puerta por la que entraste"),
					tr("▶ Volved a la puerta de entrada") if many else tr("▶ Vuelve a la puerta de entrada"))
		elif tapes_got > tapes_needed:
			message.emit(tr("¡Corred a la furgoneta!") if players.size() > 1 else tr("¡Corre a la furgoneta!"))
		elif not mine:
			message.emit(tr("%s encontró una cinta (%d de %d)") % [Net.name_of(by), tapes_got, tapes_needed])
		else:
			message.emit(tr("Cinta %d de %d") % [tapes_got, tapes_needed])
		if multiplayer.is_server() and tapes_got == Tuning.TV_CORRUPT_AT:
			tv.set_corrupted()
		if tapes_got == blackout_at():
			_blackout()
	p.queue_free()


## The last tape: it screams through the whole house and changes. From
## now on the camera only holds it for a moment, and it is faster.
func _enrage() -> void:
	if multiplayer.is_server():
		entity.enraged = true
		entity.wake()
	Sfx.play(self, "rage", -10.0)
	rage_flash = 1.0


## The power goes: every lamp and the TV die. Only the lamp over the front
## door stays on (another circuit). From here you see with your flashlight,
## your camcorder and your friends' lights.
func _blackout() -> void:
	for lamp in level.lamps:
		lamp.dead = true
		lamp.shadow_enabled = false
	tv.power_off()
	if reading:
		_close_reading()
	Sfx.play(self, "power_down", -2.0)
	message.emit(tr("Se ha ido la luz"))


@rpc("authority", "call_local", "reliable")
func _player_caught(id: int) -> void:
	var p: Player = players.get(id)
	if p == null or not p.alive:
		return
	p.alive = false
	replay.note_death(id, entity.global_position)
	# Found in a hiding place: the others see the body dragged out of it.
	var spot := level.get_node_or_null(p.net_hide) as HideSpot if p.net_hide != "" else null
	if spot and p != local_player:
		p.global_position = level.center(spot.access)
		p.net_pos = p.global_position
	if p.has_camera:
		_camera_dropped(id, "Fallen%d" % id, _floor_spot(p.global_position, p.global_position), p.net_battery, true)
	Sfx.play_3d(level, p.global_position + Vector3.UP * 1.5, "death_scream", -3.0)
	Sfx.play_3d(level, p.global_position + Vector3.UP, "death_gore", -3.0)
	_leave_corpse(p)
	if p == local_player:
		if reading:
			_close_reading()
		p.input_enabled = false
		p.camcorder.reveal = true
		Sfx.play(self, "caught", -6.0)
		_screamer(p)
		await get_tree().create_timer(1.6).timeout
		if alive_players().is_empty():
			return  # the end screen comes now; its face stays until then
		p.camcorder.reveal = false
		if phase == Phase.PLAYING:
			_spectate_next()
			message.emit(tr("Clic: cambiar de cámara"))
	else:
		p.avatar.play_death(entity.global_position)
		message.emit(tr("%s ha desaparecido") % p.display_name)
		if spectating == p:
			_spectate_next()


## Dev (Alt+F1): a bot teammate next to you. Host only; it lives on this
## machine alone (no replication), which is enough to test the entity.
func spawn_bot() -> String:
	if not multiplayer.is_server():
		return tr("Solo el anfitrión puede crear bots")
	var id := 900
	while players.has(id):
		id += 1
	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	p.setup(id, tr("Bot %d") % (id - 899), Net.COLORS[(id - 899 + players.size()) % Net.COLORS.size()], false)
	p.is_bot = true
	level.get_parent().add_child(p)
	p.set_multiplayer_authority(multiplayer.get_unique_id())
	var sync := p.get_node_or_null("Sync")
	if sync:
		sync.queue_free()
	var at := level.center(level.nearest_walkable(level.cell_of(local_player.global_position)))
	p.global_position = at
	p.net_pos = at
	p.has_camera = false
	players[id] = p
	entity.players.append(p)
	var bot := Bot.new()
	bot.name = "Bot"
	bot.body = p
	bot.level = level
	bot.leader = local_player
	p.add_child(bot)
	return tr("%s se une a la noche") % p.display_name


## The flash: seen at once here, judged by the host (who uses the view we
## last sent), seen by everyone.
func _on_flash() -> void:
	_flash_fx(local_player.peer_id)
	if multiplayer.is_server():
		_judge_flash(local_player.peer_id)
	else:
		_request_flash.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_flash() -> void:
	if multiplayer.is_server():
		_judge_flash(_sender())


func _judge_flash(id: int) -> void:
	var p: Player = players.get(id)
	if p == null or not p.alive:
		return
	# Everyone else sees it go off (the one who fired it already did).
	if id != multiplayer.get_unique_id():
		_flash_fx(id)
	for peer in multiplayer.get_peers():
		if peer != id:
			_flash_fx.rpc_id(peer, id)
	if entity.flash_hits(p):
		if entity.is_piloted():
			_pilot_burned(p)
		else:
			entity.flashed(p)
		_moment("flash", p)
	# Friends looking into it: dazzled for a moment (it is funny).
	var dazzled := false
	for q: Player in players.values():
		var power := _dazzle(p, q)
		if power > 0.0:
			if not dazzled:
				dazzled = true
				_moment("dazzle", p)
			if q.peer_id == multiplayer.get_unique_id():
				_dazzled(power)
			elif not q.is_bot:
				_dazzled.rpc_id(q.peer_id, power)


## How hard `p`'s flash hits `q` in the eyes (0: not at all): q in p's
## frame, close, nothing in between, and q looking back at it.
func _dazzle(p: Player, q: Player) -> float:
	if q == p or not q.alive or q.is_hidden():
		return 0.0
	var from := entity._view_of(p)
	var eye := q.camera.global_position
	var d := from.origin.distance_to(eye)
	if d > Tuning.FLASH_RANGE or not entity._in_flash(p, from, eye):
		return 0.0
	var q_view := entity._view_of(q)
	var facing := (-q_view.basis.z).dot((from.origin - eye).normalized())
	if facing < 0.2:
		return 0.0
	var space := level.get_world_3d().direct_space_state
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from.origin, eye, Tuning.LAYER_WORLD)).is_empty():
		return 0.0
	return clampf((1.0 - d / Tuning.FLASH_RANGE) * 1.4, 0.3, 1.0) * clampf(facing * 1.4, 0.0, 1.0)


## This machine's player got a friend's flash in the eyes.
@rpc("authority", "call_remote", "reliable")
func _dazzled(power: float) -> void:
	dazzle = maxf(dazzle, power)
	Sfx.play(self, "flash_fire", -2.0)
	Sfx.play(self, "tinnitus", -10.0 + power * 4.0)


## Everyone: a white burst of light from that player's camcorder.
@rpc("authority", "call_remote", "reliable")
func _flash_fx(id: int) -> void:
	var p: Player = players.get(id)
	if p == null:
		return
	replay.note_flash(id)
	var light := OmniLight3D.new()
	light.light_color = Color(0.92, 0.96, 1.0)
	light.light_energy = 9.0
	light.omni_range = 10.0
	light.shadow_enabled = true
	light.light_volumetric_fog_energy = 3.0
	level.add_child(light)
	light.global_position = p.camera.global_position - p.camera.global_transform.basis.z * 0.3
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(light.queue_free)
	if p != local_player:
		# The glare of the bulb itself, seen from outside.
		var glare := Sprite3D.new()
		glare.texture = _glare_texture()
		glare.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glare.shaded = false
		glare.no_depth_test = false
		glare.pixel_size = 0.006
		glare.modulate = Color(1.0, 1.0, 1.0, 1.0)
		level.add_child(glare)
		glare.global_position = light.global_position
		var gt := create_tween()
		gt.tween_property(glare, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		gt.tween_callback(glare.queue_free)
	Sfx.play_3d(level, light.global_position, "flash_fire", 0.0)
	if p == local_player:
		flash.emit()


static var _glare: Texture2D


## A soft round flare (made once).
static func _glare_texture() -> Texture2D:
	if _glare == null:
		var grad := GradientTexture2D.new()
		grad.fill = GradientTexture2D.FILL_RADIAL
		grad.fill_from = Vector2(0.5, 0.5)
		grad.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.25, Color(0.9, 0.95, 1.0, 0.7))
		g.set_color(g.get_point_count() - 1, Color(0.8, 0.9, 1.0, 0.0))
		grad.gradient = g
		grad.width = 64
		grad.height = 64
		_glare = grad
	return _glare


## Host (alone, or the one hosting): pause the night for everyone.
func request_pause(on: bool) -> void:
	if multiplayer.is_server():
		_set_paused.rpc(on)


@rpc("authority", "call_local", "reliable")
func _set_paused(on: bool) -> void:
	get_tree().paused = on
	paused_changed.emit(on)


## Taken: its face slams into the lens, the picture shakes and punches in,
## the frames cut between its face and its face closer, red and black,
## the tape tearing; then the signal dies.
func _screamer(p: Player) -> void:
	scared.emit()
	entity.screamer(1.5)
	p.camcorder.fov_kick = 22.0
	var t := 0.0
	while t < 1.5 and is_instance_valid(p):
		var k := 1.0 - t / 1.5
		p.camera.h_offset = randf_range(-1.0, 1.0) * 0.07 * k
		p.camera.v_offset = randf_range(-1.0, 1.0) * 0.05 * k
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(p):
		p.camera.h_offset = 0.0
		p.camera.v_offset = 0.0


## Where they fall, after the entity is done with them, the body stays.
## (Where the death animation slams it: at the entity's feet.)
func _leave_corpse(p: Player) -> void:
	var to := entity.global_position - p.global_position
	to.y = 0.0
	var at := _floor_spot(p.global_position + (to.normalized() * 1.4 if to.length() > 0.1 else Vector3.ZERO), p.global_position)
	var tint := p.tint
	var id := p.peer_id
	await get_tree().create_timer(2.2).timeout
	Sfx.play_3d(level, at, "body_thud", -2.0)
	await get_tree().create_timer(0.4).timeout
	var body := Corpse.new()
	body.setup(id, tint)
	level.add_child(body)
	body.global_position = at + Vector3(0, 0.14, 0)
	corpses.append(body)


@rpc("authority", "call_local", "reliable")
func _end(p_phase: Phase, p_time: float, by: int) -> void:
	if phase != Phase.PLAYING:
		return
	phase = p_phase
	_ended_at = Time.get_ticks_msec()
	phase_changed.emit(phase)
	local_player.input_enabled = false
	if reading:
		reading = false
		read.emit(false)
	var survivors := PackedStringArray()
	for pl: Player in players.values():
		if pl.alive:
			survivors.append(pl.display_name)
	if multiplayer.is_server():
		_send_clips()
	if pilot:
		screens.show_entity_end(phase == Phase.CAUGHT, tapes_got, tapes_needed, p_time, multiplayer.is_server())
		return
	if entity_peer:
		screens.note(tr("La Visita era %s") % Net.name_of(entity_peer))
	if phase == Phase.ESCAPED:
		screens.show_escaped(tapes_got, tapes_needed, p_time, players.size(), Net.name_of(by), survivors, multiplayer.is_server())
	else:
		screens.show_caught(tapes_got, tapes_needed, p_time, multiplayer.is_server())


# --- the best moments (Replay) -------------------------------------------------------

## Host: once the last moment's seconds are on tape, the pick goes to everyone.
func _send_clips() -> void:
	await get_tree().create_timer(4.0).timeout
	if not is_inside_tree():
		return
	var list := replay.pick()
	if not list.is_empty():
		_set_clips.rpc(list)
		_play_replay.rpc(0)  # the first one starts on its own


@rpc("authority", "call_local", "reliable")
func _set_clips(list: Array) -> void:
	replay.set_clips(list)


## Host -> everyone, at once: play clip `i` (or every clip: -1).
@rpc("authority", "call_local", "reliable")
func _play_replay(i: int) -> void:
	replay.play(i)


@rpc("authority", "call_local", "reliable")
func _stop_replay() -> void:
	replay.stop()


# --- "La Visita es un jugador" ------------------------------------------------------

## Everyone, at the start: the entity's player is out of the house (no
## body, no camera, not counted among the living); the AI stays asleep.
func _pick_entity_player() -> void:
	entity_peer = 0
	if Net.game_mode == Net.GameMode.VERSUS and players.size() >= 2 and players.has(Net.entity_peer):
		entity_peer = Net.entity_peer
	entity.pilot_id = entity_peer
	if entity_peer == 0:
		return
	var p: Player = players[entity_peer]
	p.alive = false
	p.visible = false
	p.get_node("Collision").set_deferred("disabled", true)


## This machine plays the entity: its controls, its eyes, its screen.
func become_pilot() -> void:
	var ui := screens.get_parent()
	for c in ui.get_children():
		if c.name == "Hud" or c.name == "Viewfinder" or c is InventoryUI:
			c.visible = false
			c.process_mode = Node.PROCESS_MODE_DISABLED
	local_player.input_enabled = false
	local_player.visible = false
	local_player.process_mode = Node.PROCESS_MODE_DISABLED
	pilot = EntityPilot.new()
	pilot.name = "Pilot"
	add_child(pilot)
	pilot.setup(self, ui)


## Its player left: the house takes it over again.
func _pilot_gone() -> void:
	message.emit(tr("La Visita se ha desconectado: ahora la controla la casa"))
	entity_peer = 0
	entity.pilot_id = 0
	entity.piloted_here = false
	if multiplayer.is_server() and entity.state != Entity.State.DORMANT:
		entity.resume()


## Host -> the entity's player: what happened to it.
@rpc("authority", "call_local", "reliable")
func _pilot_event(kind: String, value: float) -> void:
	if pilot == null:
		return
	match kind:
		"missed":
			pilot.missed()
		"stun":
			pilot.stunned(value)
		"found":
			pilot.searched(true)
		"empty":
			pilot.searched(false)
		"hid":
			pilot.hid()


func _tell_pilot(kind: String, value := 0.0) -> void:
	if entity_peer:
		_pilot_event.rpc_id(entity_peer, kind, value)


@rpc("authority", "call_local", "reliable")
func _pilot_place(pos: Vector3) -> void:
	if pilot:
		pilot.place(pos)


func _from_pilot() -> bool:
	return multiplayer.is_server() and entity_peer != 0 and _sender() == entity_peer


## Its player -> host, 30 times a second: where it is and how it moves.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _pilot_state(pos: Vector3, yaw: float, ceiling: bool, m: int) -> void:
	if _from_pilot():
		pilot_moved(pos, yaw, ceiling, m)


## Host: the entity is where its player says (not while it holds someone
## or looks into a hiding place: then it is where the host put it).
func pilot_moved(pos: Vector3, yaw: float, ceiling: bool, m: int) -> void:
	if entity.state == Entity.State.FEEDING or entity.state == Entity.State.DORMANT or entity.mode == Entity.Mode.PEEK:
		return
	entity.global_position = pos
	entity.net_pos = pos
	entity.on_ceiling = ceiling
	entity._facing = Basis(Vector3.UP, yaw) * Vector3.FORWARD
	_pilot_last_mode = m
	entity.mode = m as Entity.Mode
	entity.pose = Entity.Pose.CROUCH if m == Entity.Mode.STALK else Entity.Pose.STAND


@rpc("any_peer", "call_remote", "reliable")
func _pilot_attack(from_ceiling: bool) -> void:
	if _from_pilot():
		pilot_attack(from_ceiling)


## Host: its grab (or its drop from the ceiling) takes whoever is right
## there in front of it (below it), in reach and in sight.
func pilot_attack(from_ceiling: bool) -> void:
	if phase != Phase.PLAYING or entity.state != Entity.State.STALKING or time - _pilot_attack_at < 0.5:
		return
	_pilot_attack_at = time
	if from_ceiling:
		entity._drop_fx.rpc()
	var target := _pilot_target(from_ceiling)
	if target == null:
		_tell_pilot("missed")
		return
	if from_ceiling:
		_moment("drop", target)
	entity.caught.emit(target)


func _pilot_target(from_ceiling: bool) -> Player:
	var best: Player = null
	var best_d := INF
	var reach := Tuning.PILOT_DROP_RANGE if from_ceiling else Tuning.PILOT_GRAB_RANGE
	var space := level.get_world_3d().direct_space_state
	for p in alive_players():
		if p.is_hidden():
			continue
		var d := p.global_position - entity.global_position
		var flat := Vector2(d.x, d.z)
		if absf(d.y) > 1.3 or flat.length() > reach or flat.length() >= best_d:
			continue
		if not from_ceiling and flat.length() > 0.5 and Vector2(entity._facing.x, entity._facing.z).normalized().dot(flat.normalized()) < 0.35:
			continue
		var q := PhysicsRayQueryParameters3D.create(entity.global_position + Vector3.UP * 1.2, p.global_position + Vector3.UP * 0.9, Tuning.LAYER_WORLD)
		if not space.intersect_ray(q).is_empty():
			continue
		best = p
		best_d = flat.length()
	return best


## Host: a flash in its player's face: blinded, crawling, then shrugs the
## next ones off for a while.
func _pilot_burned(p: Player) -> void:
	entity._flash_immune = Tuning.PILOT_FLASH_IMMUNE
	entity._say("voice_agony")
	entity._burn_fx.rpc()
	entity._note(entity.events, "el flash de %s la ciega (jugador)" % p.display_name)
	if entity.mode == Entity.Mode.PEEK:
		entity._set_mode(Entity.Mode.WANDER, 0.0, "flasheada asomándose")
	_tell_pilot("stun", Tuning.PILOT_STUN_ENRAGED if entity.enraged else Tuning.PILOT_STUN)


## Its player looks into a hiding place: whoever is in there sees its face
## for a moment (a flash saves them), then it takes them.
@rpc("any_peer", "call_local", "reliable")
func _pilot_search(spot_name: String) -> void:
	if not _from_pilot() or phase != Phase.PLAYING or entity.state != Entity.State.STALKING:
		return
	var spot := level.get_node_or_null(spot_name) as HideSpot
	var who: Player = null
	if spot and level.center(spot.access).distance_to(entity.global_position) <= Tuning.PILOT_SEARCH_RANGE + 0.5:
		for p in alive_players():
			if p.net_hide == spot_name:
				who = p
	if who == null:
		# Nobody in there: it gets in itself, and waits (unseen, silent).
		if spot and level.center(spot.access).distance_to(entity.global_position) <= Tuning.PILOT_SEARCH_RANGE + 0.5:
			entity.gone = true
			_tell_pilot("hid")
		else:
			_tell_pilot("empty")
		return
	_tell_pilot("found")
	entity._peek_into(spot, who)
	await get_tree().create_timer(Tuning.PEEK_TIME).timeout
	if phase == Phase.PLAYING and entity.mode == Entity.Mode.PEEK and entity.target == who and who.alive and who.net_hide == spot_name:
		entity.caught.emit(who)
	elif entity.mode == Entity.Mode.PEEK:
		entity._set_mode(Entity.Mode.WANDER, 0.0, "se aparta del escondite")


@rpc("any_peer", "call_local", "reliable")
func _pilot_door(door_name: String) -> void:
	if not _from_pilot() or phase != Phase.PLAYING:
		return
	var door := level.get_node_or_null(door_name) as Door
	if door == null or not door.ready_to_move() or door.global_position.distance_to(entity.global_position) > 2.0:
		return
	if door.is_open:
		for p in alive_players():
			if level.cell_of(p.global_position) == door.cell:
				return
	door.set_open.rpc(not door.is_open, true, door.swing_from(entity.global_position))


## Host: played by someone, it still makes its own sounds, by itself, as
## it always does (its player does not choose them): screams while it
## hunts, "¿dónde estás?", humming, crying, moaning while it walks about;
## nothing while it creeps, waits on the ceiling or hides.
func _pilot_voice(delta: float) -> void:
	if entity.state != Entity.State.STALKING or entity.gone or entity.quiet or entity.vanishing:
		return
	_pilot_voice_in -= delta
	if _pilot_voice_in > 0.0:
		return
	match entity.mode:
		Entity.Mode.WANDER:
			_pilot_voice_in = _rng.randf_range(7.0, 14.0)
			var lines := [entity._where_line(), "voice_hum", "voice_cry", "voice_moan", "voice_giggle"]
			entity._say(lines[_rng.randi() % lines.size()])
		_:
			_pilot_voice_in = _rng.randf_range(2.0, 4.0)


## Its player charges (the attack): it shrieks as it comes.
@rpc("any_peer", "call_local", "reliable")
func _pilot_charge() -> void:
	if _from_pilot() and entity.state == Entity.State.STALKING and time - _pilot_scream_at > 1.0:
		_pilot_scream_at = time
		entity._scream()


## Its player gets out of where it hid.
@rpc("any_peer", "call_local", "reliable")
func _pilot_unhide() -> void:
	if _from_pilot() and entity.gone:
		entity.gone = false


## Everyone: it feels for them (Q). The living hear it whisper (the cue to
## hide and keep quiet).
@rpc("any_peer", "call_local", "reliable")
func _pilot_sense() -> void:
	if _sender() != entity_peer or local_player.peer_id == entity_peer:
		return
	if local_player.alive:
		Sfx.play(self, "voice_whisper", -12.0)
