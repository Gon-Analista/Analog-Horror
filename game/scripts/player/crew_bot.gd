class_name CrewBot
extends Node
## A crew member played by the house (the lobby's "BOTS"), to fill a room
## or to have someone to hunt when you are the entity. Lives on the host;
## its body is replicated like anyone's (the host is its authority, it
## drives net_pos / net_yaw like a remote player's), so every machine sees
## it. It goes for the tapes, then for the van; if the entity comes close
## it runs, or hides, or turns and fires its flash; hidden, it waits a
## while and comes out. Not clever: a stand-in, fair to play against.

enum Goal { EXPLORE, TAPE, EXIT, FLEE, HIDE, HIDDEN }

const SEE_RANGE := 7.0      # it notices the entity this close (it hears it, it feels it)
const PANIC_RANGE := 4.0    # ...and this close it does something about it
const FLASH_RANGE := 7.5
const FLASH_COOLDOWN := 9.0
const SPOT_RANGE := 5.0     # it notices a tape this close, in sight

var body: Player
var run: Run
var level: Level
var goal := Goal.EXPLORE
var _path: Array[Vector3i] = []
var _target := ""          # the pickup it is going for, or the hiding place
var _wait := 0.0
var _replan := 0.0
var _flash_cd := 4.0
var _hidden_for := 0.0
var _rng := RandomNumberGenerator.new()
var _known := {}            # tapes it has seen


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if body == null or not body.alive or get_tree().paused or run.phase != Run.Phase.PLAYING:
		return
	_flash_cd -= delta
	_replan -= delta
	var entity := run.entity
	var awake := entity.state != Entity.State.DORMANT
	var d := body.net_pos.distance_to(entity.global_position) if awake else INF
	if goal == Goal.HIDDEN:
		_stay_hidden(delta, d)
		return
	# The entity close: flash it if it can, else run or hide.
	if d < PANIC_RANGE and goal != Goal.FLEE and goal != Goal.HIDE:
		if body.has_camera and _flash_cd <= 0.0 and d < FLASH_RANGE and _sees(entity.global_position + Vector3.UP * 1.4):
			_flash(entity)
		else:
			_escape(entity)
	elif d < SEE_RANGE and entity.mode == Entity.Mode.CHASE and goal != Goal.FLEE and goal != Goal.HIDE:
		_escape(entity)
	if goal == Goal.FLEE and (d > SEE_RANGE * 1.3 or _path.is_empty()):
		goal = Goal.EXPLORE
		_path.clear()
	if goal == Goal.HIDE and _path.is_empty():
		_enter_hiding()
		return
	if goal != Goal.FLEE and goal != Goal.HIDE and (_path.is_empty() or _replan <= 0.0):
		_replan = 1.0
		_plan()
	if _wait > 0.0:
		_wait -= delta
		return
	_walk(delta, Tuning.SPRINT_SPEED if goal == Goal.FLEE or goal == Goal.HIDE else Tuning.WALK_SPEED)
	_arrived()


## What to do now: the van once it has every tape, a tape it knows of, or
## a look round.
func _plan() -> void:
	var here := _cell()
	if run.tapes_got >= run.tapes_needed and run.exit_door:
		goal = Goal.EXIT
		_path = level.path(here, level.nearest_walkable(level.cell_of(run.exit_door.global_position)))
		return
	# Only the tapes it has seen (close, in sight): it has to search the
	# house like anyone.
	var best: Pickup = null
	var best_d := INF
	for n in level.get_children():
		var p := n as Pickup
		if p == null or p.kind != Pickup.Kind.TAPE or p.is_queued_for_deletion():
			continue
		var dd := p.global_position.distance_to(body.net_pos)
		if not _known.has(p.name) and dd < SPOT_RANGE and _sees(p.global_position + Vector3.UP * 0.2):
			_known[p.name] = true
		if _known.has(p.name) and dd < best_d:
			best_d = dd
			best = p
	if best:
		goal = Goal.TAPE
		_target = String(best.name)
		_path = level.path(here, level.nearest_walkable(level.cell_of(best.global_position)))
		return
	goal = Goal.EXPLORE
	if _path.is_empty():
		var dist := level.layout.distances(here)
		var options: Array[Vector3i] = []
		for c: Vector3i in dist.keys():
			if int(dist[c]) >= 5 and int(dist[c]) <= 14:
				options.append(c)
		if not options.is_empty():
			_path = level.path(here, options[_rng.randi() % options.size()])
			_wait = _rng.randf_range(0.0, 1.5)


func _arrived() -> void:
	match goal:
		Goal.TAPE:
			var p := level.get_node_or_null(_target) as Pickup
			if p == null:
				_path.clear()
			elif p.global_position.distance_to(body.net_pos) < 1.0:
				run._pickup_taken.rpc(_target, body.peer_id)
				_path.clear()
				_wait = 0.4
		Goal.EXIT:
			if run.exit_door and run.exit_door.global_position.distance_to(body.net_pos) < 1.4 and run.tapes_got >= run.tapes_needed:
				run._moment("escape", body)
				run._end.rpc(Run.Phase.ESCAPED, run.time, body.peer_id)


## Away from the entity, or into a hiding place close by (a third of the
## time, if there is one).
func _escape(entity: Entity) -> void:
	var here := _cell()
	if _rng.randf() < 0.35:
		for spot in level.hide_spots:
			if level.center(spot.access).distance_to(body.net_pos) < 3.5 \
					and level.center(spot.access).distance_to(entity.global_position) > body.net_pos.distance_to(entity.global_position):
				goal = Goal.HIDE
				_target = String(spot.name)
				_path = level.path(here, spot.access)
				return
	var mine := level.layout.distances(here)
	var its := level.layout.distances(level.nearest_walkable(level.cell_of(entity.global_position)))
	var best := here
	var best_score := -INF
	for c: Vector3i in mine.keys():
		var n := int(mine[c])
		if n < 3 or n > 12:
			continue
		var score := float(its.get(c, 0)) * 1.5 - n * 0.4
		if score > best_score:
			best_score = score
			best = c
	goal = Goal.FLEE
	_path = level.path(here, best)


func _enter_hiding() -> void:
	var spot := level.get_node_or_null(_target) as HideSpot
	if spot == null:
		goal = Goal.EXPLORE
		return
	goal = Goal.HIDDEN
	_hidden_for = _rng.randf_range(7.0, 15.0)
	body.net_hide = String(spot.name)
	body.net_pos = spot.inside
	body.net_yaw = atan2(-spot.facing.x, -spot.facing.z)
	body.net_light = false


func _stay_hidden(delta: float, d: float) -> void:
	_hidden_for -= delta
	var entity := run.entity
	# Its face at the opening: half the time it fires the flash into it.
	if entity.mode == Entity.Mode.PEEK and entity.target == body and body.has_camera and _flash_cd <= 0.0 and _rng.randf() < delta * 1.2:
		_flash(entity)
	if _hidden_for <= 0.0 and d > PANIC_RANGE:
		var spot := level.get_node_or_null(body.net_hide) as HideSpot
		body.net_hide = ""
		if spot:
			body.net_pos = level.center(spot.access)
		body.net_light = true
		goal = Goal.EXPLORE
		_path.clear()


## Turns to it, camcorder up, and fires (the host judges it like anyone's).
func _flash(entity: Entity) -> void:
	var to := entity.global_position + Vector3.UP * 1.4 - (body.net_pos + Vector3.UP * Player.EYE_HEIGHT)
	body.net_yaw = atan2(-to.x, -to.z)
	body.net_pitch = atan2(to.y, Vector2(to.x, to.z).length())
	body.net_raise = 1.0
	body.rotation.y = body.net_yaw
	_flash_cd = FLASH_COOLDOWN + _rng.randf_range(0.0, 3.0)
	run._judge_flash(body.peer_id)
	_wait = 0.3


func _sees(point: Vector3) -> bool:
	var eye := body.net_pos + Vector3.UP * Player.EYE_HEIGHT
	var space := level.get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, point, Tuning.LAYER_WORLD)).is_empty()


func _cell() -> Vector3i:
	return level.nearest_walkable(level.cell_of(body.net_pos))


func _walk(delta: float, speed: float) -> void:
	if _path.is_empty():
		return
	var door := level.door_at(_path[0])
	if door and door.blocks():
		if door.ready_to_move() and not door.is_open:
			door.set_open.rpc(true, false, door.swing_from(body.net_pos))
		return
	var next := level.center(_path[0])
	var to := next - body.net_pos
	var step := speed * delta
	if to.length() <= step:
		body.net_pos = next
		_path.pop_front()
	else:
		body.net_pos += to.normalized() * step
		if Vector2(to.x, to.z).length() > 0.01:
			body.net_yaw = atan2(-to.x, -to.z)
	body.net_raise = move_toward(body.net_raise, 0.0, delta * 3.0)
	body.net_light = true
