class_name Run
extends Node
## One night in the evacuated house: places tapes and batteries from the
## seed, counts what is recovered, escalates the entity and ends in escape
## or capture. This is authority state: in co-op the host owns it and its
## events (pickup, wake, corruption, end) go out by RPC.

signal tapes_changed(got: int, needed: int)
signal message(text: String)
signal phase_changed(phase: Phase)

enum Phase { INTRO, PLAYING, CAUGHT, ESCAPED }

var phase := Phase.INTRO
var run_seed := 0
var tapes_got := 0
var tapes_needed := Tuning.TAPES_NEEDED
var time := 0.0
var level: Level
var player: Player
var entity: Entity
var tv: TvBroadcast
var screens: Screens
var exit_door: ExitDoor
var _rng := RandomNumberGenerator.new()


func setup(p_level: Level, p_player: Player, p_entity: Entity, p_tv: TvBroadcast, p_screens: Screens) -> void:
	level = p_level
	player = p_player
	entity = p_entity
	tv = p_tv
	screens = p_screens


func start(p_seed: int, skip_intro := false) -> void:
	run_seed = p_seed
	_rng.seed = run_seed
	_spawn_player()
	_spawn_entity()
	_spawn_pickups()
	_spawn_exit()
	player.interact_requested.connect(_on_interact)
	entity.caught.connect(_on_caught)
	tapes_changed.emit(tapes_got, tapes_needed)
	if skip_intro:
		_begin()
		return
	player.input_enabled = false
	screens.show_intro()
	await screens.intro_done
	_begin()


func _begin() -> void:
	_set_phase(Phase.PLAYING)
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_phase(p: Phase) -> void:
	phase = p
	phase_changed.emit(p)


func _process(delta: float) -> void:
	if phase != Phase.PLAYING:
		return
	time += delta
	if entity.state == Entity.State.DORMANT and time > Tuning.ENTITY_WAKE_TIME:
		entity.wake()
	_disturb()


## Lamps and the flashlight fail near the entity (once it is awake).
func _disturb() -> void:
	var awake := entity.state != Entity.State.DORMANT
	var at := entity.global_position
	for lamp in level.lamps:
		lamp.disturbance = clampf(1.0 - lamp.global_position.distance_to(at + Vector3.UP * 2.0) / Tuning.FLICKER_RANGE, 0.0, 1.0) if awake else 0.0
	var d := player.global_position.distance_to(at)
	player.disturbance = clampf(1.0 - d / Tuning.FLASHLIGHT_FAIL_RANGE, 0.0, 1.0) if awake else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if (phase == Phase.CAUGHT or phase == Phase.ESCAPED) and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


# --- spawning ---------------------------------------------------------------

func _spawn_player() -> void:
	var cells := level.spots_of("P")
	var c: Vector2i = cells[0] if not cells.is_empty() else Vector2i(1, 1)
	player.global_position = level.center(c)
	player.set_view(0.0)  # facing north, into the house


func _spawn_entity() -> void:
	var cells := level.spots_of("E")
	var c: Vector2i = cells[0] if not cells.is_empty() else Vector2i(1, 1)
	entity.level = level
	entity.target = player
	entity.global_position = level.center(c)


func _spawn_pickups() -> void:
	var tape_cells := level.spots_of("T").duplicate()
	# Seeded Fisher-Yates: every player of the run gets the same house.
	for i in range(tape_cells.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Vector2i = tape_cells[i]
		tape_cells[i] = tape_cells[j]
		tape_cells[j] = tmp
	for i in mini(Tuning.TAPES_SPAWNED, tape_cells.size()):
		_place_pickup(Pickup.Kind.TAPE, tape_cells[i])
	for c: Vector2i in level.spots_of("B"):
		_place_pickup(Pickup.Kind.BATTERY, c)


func _place_pickup(kind: Pickup.Kind, c: Vector2i) -> void:
	var p := Pickup.create(kind)
	level.add_child(p)
	p.global_position = level.center(c) + Vector3(_rng.randf_range(-0.25, 0.25), 0.0, _rng.randf_range(-0.25, 0.25))
	p.rotation.y = _rng.randf() * TAU


func _spawn_exit() -> void:
	var cells := level.spots_of("X")
	if cells.is_empty():
		push_error("Run: the map has no exit (X)")
		return
	var c: Vector2i = cells[0]
	exit_door = ExitDoor.new()
	exit_door.run = self
	level.add_child(exit_door)
	# On the face of the X cell that looks into the house.
	for d in Level.DIRS:
		if level.is_walkable(c + d):
			exit_door.global_position = level.center(c) + Vector3(d.x, 0, d.y) * Level.CELL * 0.5
			exit_door.look_at(exit_door.global_position + Vector3(d.x, 0, d.y), Vector3.UP)
			break


# --- events -------------------------------------------------------------------

func _on_interact(target: Node) -> void:
	if phase != Phase.PLAYING:
		return
	if target is Pickup:
		_collect(target)
	elif target is ExitDoor and (target as ExitDoor).is_open():
		_escape()


func _collect(p: Pickup) -> void:
	Sfx.play(self, "pickup", -4.0)
	if p.kind == Pickup.Kind.BATTERY:
		player.camcorder.add_battery(Tuning.BATTERY_PICKUP)
		message.emit(tr("Batería cargada"))
	else:
		tapes_got += 1
		entity.tapes = tapes_got
		entity.wake()
		tapes_changed.emit(tapes_got, tapes_needed)
		if tapes_got >= tapes_needed:
			message.emit(tr("Vuelve a la furgoneta"))
		else:
			message.emit(tr("Cinta %d de %d") % [tapes_got, tapes_needed])
		if tapes_got == Tuning.TV_CORRUPT_AT:
			tv.show_rules(true)
	p.queue_free()


func _escape() -> void:
	_set_phase(Phase.ESCAPED)
	player.input_enabled = false
	screens.show_escaped(tapes_got, tapes_needed, time)


func _on_caught(p: Player) -> void:
	if phase != Phase.PLAYING:
		return
	_set_phase(Phase.CAUGHT)
	p.input_enabled = false
	p.camcorder.reveal = true
	entity.lunge_at(p)
	Sfx.play(self, "caught", -2.0)
	await get_tree().create_timer(0.9).timeout
	screens.show_caught(tapes_got, tapes_needed, time)
