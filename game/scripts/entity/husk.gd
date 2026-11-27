class_name Husk
extends Entity
## "The Husk" (propuesta, second night): the walking costume of Vecinito,
## left in the wardrobe of Canal 9 when the show was pulled. There is
## nobody inside it. It stands among the other costumes, identical, until
## the first master tape is taken.
##
## Rules (the opposite of the Visita's):
##   * The eye sees it; the camcorder does not. Through the viewfinder there
##     is only its shadow (HuskModel.NAKED_LAYER). The costumes on the rack
##     are on tape; it is not: that is how you tell it apart.
##   * It never moves while somebody alive sees it: in their view, nothing
##     in between, and lit enough to make out (within DARK_SEE in the dark,
##     in a flashlight's beam, under a working lamp, in a flash). Filming
##     is not seeing. Hiding is not seeing.
##   * Unseen, it is fast, faster than walking, and every time you look
##     again it is in another pose.
##   * Nobody can stare forever: after a few seconds of looking at it, you
##     blink (a moment of black). It knows.
##   * It cannot get through a boarded doorway, it does not climb, and it
##     opens doors slowly.
## The host decides everything; on the other machines it holds still while
## their own player sees it, whatever the network says (so it is never seen
## sliding), unless it is far off.

## Metres a second unseen (base), per master tape, alone, all of them taken.
const SPEED := 2.9
const SPEED_PER_TAPE := 0.1
const SOLO_MULT := 0.88
const RAGE_MULT := 1.3
## It takes whoever it reaches, this close (and nothing in between).
const CATCH := 0.95
## You make it out in the dark only this close; in a flashlight's beam (this
## wide, cos) this far; under a lamp that works, within LAMP_REACH of it.
const DARK_SEE := 3.5
const TORCH_REACH := 15.0
const TORCH_CONE := 0.86
const LAMP_REACH := 4.2
const SEE_REACH := 30.0
## The flash lights it up for a moment (it does not mind otherwise).
const FLASH_LIT := 0.5
## Seconds of staring before a blink, and how long the blink lasts.
const BLINK_MIN := 5.5
const BLINK_MAX := 8.5
const BLINK_TIME := 0.24
## How far its own senses go (no cone close by).
const SIGHT := 12.0
const SIGHT_DARK_REACH := 7.0
## A client lets it jump to where the host says, even while seen, past this.
const HOLD_MAX := 2.0
## It says something (the voice box) now and then, when nobody looks.
const VOICE_MIN := 22.0
const VOICE_MAX := 55.0
## Seconds without any idea where anyone is before it is nudged their way.
const NUDGE_AFTER := 35.0

## Replicated: the pose it holds (HuskModel.Pose), where it faces, whether it
## is moving (unseen) and whether the host counts it as seen.
var look := HuskModel.Pose.SLUMP
var yaw := 0.0
var moving := false
var watched := false

var _husk: HuskModel
## Host: per player, seconds of staring and when they blink next; blinking now.
var _stare := {}
var _blink_at := {}
var _blink_left := {}
var _flash_lit := {}
var _voice_in := 30.0
var _goal := Vector3.ZERO
var _has_goal := false
var _watchers: Array[Player] = []
## Clients: shown pose and yaw (held while our player sees it).
var _shown_look := HuskModel.Pose.SLUMP
var _shown_yaw := 0.0
var _was_moving := false
var _step_in := 0.0
var _local_seen := false
## The local player's own blink (black eyelids), seconds left.
var blink := 0.0
signal blinked


func _ready() -> void:
	# (Entity's _ready builds the Visita; none of it here. Replay reads a
	# sprite and a face from it: empty ones.)
	_breath.free()
	_sprite = Sprite3D.new()
	_sprite.visible = false
	add_child(_sprite)
	_face = Sprite3D.new()
	_face.visible = false
	add_child(_face)
	_husk = HuskModel.new()
	_husk.name = "Husk"
	_husk.setup(look, true)
	add_child(_husk)
	_rng.randomize()
	jingle.stream = Sfx.get_stream("husk_rustle", true)
	jingle.volume_db = -60.0
	jingle.play()
	drone.stream = Sfx.get_stream("husk_breath", true)
	drone.unit_size = 0.7
	drone.max_distance = 5.0
	drone.volume_db = -60.0
	drone.play()
	steps.stream = Sfx.get_stream("husk_step")
	steps.unit_size = 2.0
	voice.unit_size = 2.0
	voice.max_distance = 22.0
	for player: AudioStreamPlayer3D in [jingle, drone, voice, steps]:
		player.bus = "Effects"
		player.max_db = MAX_DB
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["net_pos", "state", "tapes", "enraged", "mode", "look", "yaw", "moving", "watched"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	sync.replication_interval = 1.0 / 30.0
	add_child(sync)


## Asleep among the costumes: facing the room, like them.
func place_dormant(at: Vector3) -> void:
	global_position = at
	net_pos = at
	var face := level._toward_middle(level.cell_of(at))
	yaw = atan2(-face.x, -face.z)
	_shown_yaw = yaw
	_facing = face
	rotation.y = 0.0
	_husk.rotation.y = yaw


func wake() -> void:
	if state == State.DORMANT:
		state = State.STALKING
		mode = Mode.WANDER
		_voice_in = _rng.randf_range(VOICE_MIN, VOICE_MAX)
		_wake_fx.rpc(global_position)
	elif enraged:
		_voice_in = 2.0


func cry() -> void:
	cry_pending = false


func speed() -> float:
	var s := SPEED + SPEED_PER_TAPE * tapes
	if Net.is_solo():
		s *= SOLO_MULT
	return s * RAGE_MULT if enraged else s


## The flash: nothing (it is not on the tape), but for a moment its light
## shows it to everyone looking.
func flash_hits(p: Player) -> bool:
	var view := _view_of(p)
	var to := global_position + Vector3.UP * 1.2 - view.origin
	if to.length() < Tuning.FLASH_RANGE and (-view.basis.z).dot(to.normalized()) > 0.6:
		for q in players:
			_flash_lit[q] = FLASH_LIT
	return false


func flashed(_p: Player) -> void:
	pass


func hint(pos: Vector3) -> void:
	_clue_pos = pos
	_clue_age = 0.0
	_clue_player = null
	_clue_precise = false
	_clue_seen = false
	if mode == Mode.WANDER:
		_go(Mode.INVESTIGATE, "una pista")


## The catch: right in front of their eyes, reaching (the one taken sees it
## whatever they hold: Camcorder reveal).
func lunge_at(p: Player) -> void:
	state = State.FEEDING
	look = HuskModel.Pose.LUNGE
	moving = false
	var cam := p.camera
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var front := cam.global_position + fwd * 0.7
	global_position = Vector3(front.x, p.global_position.y, front.z)
	net_pos = global_position
	yaw = atan2(fwd.x, fwd.z)
	_voicebox.rpc(1)


func screamer(seconds: float) -> void:
	_scare = seconds


func resume() -> void:
	state = State.STALKING
	global_position = level.center(level.nearest_walkable(level.cell_of(global_position)))
	_clue_age = INF
	_seen.clear()
	_go(Mode.WANDER, "suelta a su presa")


func debug_info() -> Dictionary:
	return {
		"state": state, "mode": mode, "mode_left": _mode_left, "edge": _last_edge,
		"target": target.display_name if target else "",
		"seen": _seen.map(func(p: Player) -> String: return p.display_name),
		"clue_age": _clue_age, "clue_seen": _clue_seen, "clue_precise": _clue_precise,
		"clue_spot": String(_clue_spot.name) if _clue_spot else "",
		"calm": 0.0, "patience": 0.0, "enraged": enraged, "pose": HuskModel.Pose.keys()[look],
		"watched": _watchers.map(func(p: Player) -> String: return p.display_name),
	}


# --- host -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		# Seen here: it stays exactly where it is (unless the host has it
		# far away: then it was never really here).
		if not (_local_seen and global_position.distance_to(net_pos) < HOLD_MAX):
			global_position = global_position.lerp(net_pos, minf(1.0, delta * 12.0))
		return
	_feeding_for = _feeding_for + delta if state == State.FEEDING else 0.0
	if _feeding_for > 6.0 and not _alive().is_empty():
		resume()
	if state == State.STALKING:
		_clock += delta
		var alive := _alive()
		_update_watchers(alive, delta)
		if watched:
			if moving:
				moving = false
			_still(alive, delta)
		else:
			_hunt(alive, delta)
	net_pos = global_position


## Who sees it right now, and the blinks.
func _update_watchers(alive: Array[Player], delta: float) -> void:
	_watchers.clear()
	for p in alive:
		_flash_lit[p] = maxf(0.0, float(_flash_lit.get(p, 0.0)) - delta)
		var left := float(_blink_left.get(p, 0.0))
		if left > 0.0:
			_blink_left[p] = left - delta
			continue
		if sees_me(p, _view_of(p)):
			_watchers.append(p)
			_stare[p] = float(_stare.get(p, 0.0)) + delta
			if not _blink_at.has(p):
				_blink_at[p] = _rng.randf_range(BLINK_MIN, BLINK_MAX)
			if _stare[p] >= _blink_at[p]:
				_stare[p] = 0.0
				_blink_at[p] = _rng.randf_range(BLINK_MIN, BLINK_MAX)
				_blink_left[p] = BLINK_TIME
				if p.is_local:
					_blink.call()
				elif not p.is_bot:
					_blink.rpc_id(p.peer_id)
		else:
			_stare[p] = maxf(0.0, float(_stare.get(p, 0.0)) - delta * 2.0)
	watched = not _watchers.is_empty()


## Whether `p` (looking from `view`) makes it out right now.
func sees_me(p: Player, view: Transform3D) -> bool:
	if not p.alive or p.is_hidden() or p.camcorder.filming:
		return false
	var space := get_world_3d().direct_space_state
	for h: float in [1.05, 1.6, 0.4]:
		var point := global_position + Vector3.UP * h
		var d := view.origin.distance_to(point)
		if d > SEE_REACH or not _in_frame(p, view, point):
			continue
		if not _lit(p, view, point, d):
			continue
		if _clear(space, view.origin, point):
			return true
	return false


func _lit(p: Player, view: Transform3D, point: Vector3, d: float) -> bool:
	if d < DARK_SEE or float(_flash_lit.get(p, 0.0)) > 0.0:
		return true
	if p.net_light and d < TORCH_REACH:
		var torch := p.flashlight.global_transform if p.is_local else view
		if (-torch.basis.z).dot((point - torch.origin).normalized()) > TORCH_CONE:
			return true
	for lamp in level.lamps:
		if not lamp.dead and lamp.light_energy > 0.15 and lamp.global_position.distance_to(point) < LAMP_REACH:
			return true
	return false


## Seen: still. It only turns its attention (never its head).
func _still(alive: Array[Player], delta: float) -> void:
	_sense_in -= delta
	if _sense_in <= 0.0:
		_sense_in = SENSE_EVERY
		_sense_husk(alive)
	_clue_age += delta


func _hunt(alive: Array[Player], delta: float) -> void:
	if not moving:
		moving = true
		# A new pose every time nobody is looking (it is what you see when
		# you look again).
		var options := [HuskModel.Pose.STAND, HuskModel.Pose.REACH, HuskModel.Pose.TILT, HuskModel.Pose.STRIDE, HuskModel.Pose.CROUCH]
		options.erase(look)
		look = options[_rng.randi() % options.size()]
	_sense_in -= delta
	if _sense_in <= 0.0:
		_sense_in = SENSE_EVERY
		_sense_husk(alive)
	_clue_age += delta
	_decide_husk(alive, delta)
	var before := global_position
	if _has_goal:
		_walk_husk(_goal, speed() * delta, delta)
		_door_guard()
	var flat := _flat(global_position - before)
	if flat.length() > 0.001:
		_facing = flat.normalized()
	# Close to someone: its face to them (and its arms out).
	var near: Player = null
	var best := 6.0
	for p in alive:
		var d := global_position.distance_to(p.global_position)
		if d < best and not p.is_hidden():
			best = d
			near = p
	if near:
		var to := _flat(near.global_position - global_position)
		if to.length() > 0.01:
			_facing = to.normalized()
		if best < 2.2 and look != HuskModel.Pose.CLOSE and look != HuskModel.Pose.REACH:
			look = HuskModel.Pose.CLOSE if _rng.randf() < 0.6 else HuskModel.Pose.REACH
	yaw = atan2(_facing.x, _facing.z) + PI  # (the model faces -Z)
	_voice_in -= delta
	if _voice_in <= 0.0:
		_voice_in = _rng.randf_range(VOICE_MIN, VOICE_MAX) * (0.5 if enraged else 1.0)
		if near or best < 12.0 or enraged:
			_voicebox.rpc(_rng.randi() % 2)
	_try_catch_husk(alive)


func _sense_husk(alive: Array[Player]) -> void:
	_seen.clear()
	_dist = level.layout.distances(level.nearest_walkable(level.cell_of(global_position)), "U")
	var space := get_world_3d().direct_space_state
	for p in alive:
		var m: Array = _motion.get(p, [p.global_position, Vector3.ZERO])
		var vel: Vector3 = (p.global_position - m[0]) / SENSE_EVERY
		_motion[p] = [p.global_position, (m[1] as Vector3).lerp(vel, 0.5)]
		if _sees_player(space, p):
			_seen.append(p)
			_learn(p, true, true)
			continue
		if p.is_hidden() and _clue_player == p and _clue_seen and _clue_age < 1.2:
			_clue_spot = _spot_of(p)
			_clue_pos = p.global_position
		var reach := _noise_of(p)
		if reach > 0.0:
			var n := _steps_to(p.global_position)
			if n <= reach:
				_learn_heard(p, n, reach)
	# All the masters gone: it knows where everyone not hidden is.
	if enraged and _seen.is_empty():
		for p in alive:
			if not p.is_hidden():
				_learn(p, false, false)
				break


func _sees_player(space: PhysicsDirectSpaceState3D, p: Player) -> bool:
	if p.is_hidden():
		return false
	var eye := global_position + Vector3.UP * 1.55
	var chest := p.global_position + Vector3.UP * (0.6 if p.net_crouch else 1.15)
	var to := chest - eye
	var d := to.length()
	var reach := SIGHT if p.net_light else SIGHT_DARK_REACH
	if p.net_crouch:
		reach *= 0.6
	if d > reach:
		return false
	if d > 3.0 and _flat(to).normalized().dot(_facing) < -0.2:
		return false
	return _clear(space, eye, chest)


func _decide_husk(alive: Array[Player], delta: float) -> void:
	_mode_left -= delta
	if not _seen.is_empty():
		target = _seen[0]
		if mode != Mode.CHASE:
			_go(Mode.CHASE, "te ve")
		_goal = target.global_position + _flat(velocity_of(target)) * 0.4
		_has_goal = true
		return
	if _clue_age < 1.5 and _clue_seen and mode == Mode.CHASE:
		_goal = _clue_pos + _clue_vel * minf(_clue_age + 0.5, 1.5)
		_has_goal = true
		return
	if _clue_age < 12.0:
		if mode != Mode.INVESTIGATE or _heard_new or not _has_goal:
			_heard_new = false
			_go(Mode.INVESTIGATE, "oye algo")
			_goal = _clue_pos
			_has_goal = true
		if _flat(global_position - _goal).length() < 0.4:
			_clue_age = INF
			_go(Mode.WANDER, "no hay nadie")
		return
	if _clue_age > NUDGE_AFTER and not alive.is_empty():
		# Long without a trace: the building leads it (a vague nudge).
		var p: Player = alive[_rng.randi() % alive.size()]
		var off := Vector3(_rng.randf_range(-3.0, 3.0), 0.0, _rng.randf_range(-3.0, 3.0))
		hint(level.center(level.nearest_walkable(level.cell_of(p.global_position + off))))
		_goal = _clue_pos
		_has_goal = true
		return
	if mode != Mode.WANDER:
		_go(Mode.WANDER, "ronda")
	if not _has_goal or _flat(global_position - _goal).length() < 0.4 or _mode_left <= 0.0:
		_goal = level.center(_wander_cell())
		_has_goal = true
		_mode_left = 14.0


func _go(m: Mode, why: String) -> void:
	if m != mode:
		_last_edge = [mode, m]
		_note(events, "%s > %s  %s" % [Mode.keys()[mode], Mode.keys()[m], why])
	mode = m
	_path.clear()
	_repath = 0.0
	_has_goal = false


## A cell in a room it has not been to for a while (never past the boards).
func _wander_cell() -> Vector3i:
	var here := level.nearest_walkable(level.cell_of(global_position))
	var dist := _dist if not _dist.is_empty() else level.layout.distances(here, "U")
	var best := here
	var best_score := -INF
	for k in 12:
		var room := _rng.randi() % level.layout.rooms.size()
		var rr: Rect2i = level.layout.rooms[room].rect
		var c := Vector3i(_rng.randi_range(rr.position.x, rr.end.x - 1), 0, _rng.randi_range(rr.position.y, rr.end.y - 1))
		if not dist.has(c):
			continue
		var since := _clock - float(_visited.get(room, -100.0))
		var score := since + _rng.randf() * 10.0 - absf(float(dist[c]) - 14.0) * 0.5
		if score > best_score:
			best_score = score
			best = c
	_visited[level.layout.room_at(best)] = _clock
	return best


func _walk_husk(goal_pos: Vector3, dist: float, delta: float) -> void:
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.3
		var goal := level.nearest_walkable(level.cell_of(goal_pos))
		var here := level.nearest_walkable(level.cell_of(global_position))
		_path = level.path(here, goal, "U")
		if not _path.is_empty():
			var step := Vector3(_path[0] - here)
			var off := _flat(global_position - level.center(here))
			var along := Vector3(step.x, 0.0, step.z).normalized()
			if (off - along * off.dot(along)).length() > 0.08 or level.cell_of(global_position) != here:
				_path.push_front(here)
		elif goal != here:
			_has_goal = false  # (not reachable without the boards)
			return
	while not _path.is_empty() and (level.center(_path[0]) - global_position).length() < 0.06:
		_path.pop_front()
	if not _path.is_empty() and _door_in_way(_path[0]):
		return
	var dest := goal_pos if _path.is_empty() else level.center(_path[0])
	if _path.is_empty():
		var cell := level.cell_of(goal_pos)
		if not level.is_walkable(cell):
			dest = level.center(level.nearest_walkable(cell))
		dest.y = global_position.y
	var to := dest - global_position
	var moved := minf(dist, to.length())
	if moved > 0.0001:
		global_position += to.normalized() * moved


func _try_catch_husk(alive: Array[Player]) -> void:
	var space := get_world_3d().direct_space_state
	for p in alive:
		var d := p.global_position - global_position
		if absf(d.y) > 1.2 or Vector2(d.x, d.z).length() > CATCH:
			continue
		if p.is_hidden():
			# Only where it saw them crawl in.
			if _clue_spot == null or _spot_of(p) != _clue_spot or _clue_age > 4.0:
				continue
		elif not _clear(space, global_position + Vector3.UP * 1.1, p.global_position + Vector3.UP * 1.1):
			continue
		target = p
		caught.emit(p)
		return


@rpc("authority", "call_local", "reliable")
func _wake_fx(at: Vector3) -> void:
	Sfx.play_3d(level, at + Vector3.UP * 1.2, "husk_wake", 2.0)


@rpc("authority", "call_local", "reliable")
func _voicebox(variant: int) -> void:
	voice.stream = Sfx.get_stream("husk_voicebox" if variant == 0 else "husk_voicebox2")
	voice.volume_db = 2.0
	voice.play()
	_note(sounds, "caja de voz %d" % variant)


## This machine's player blinks (the host says when).
@rpc("authority", "call_remote", "reliable")
func _blink() -> void:
	blink = BLINK_TIME
	blinked.emit()


# --- every machine: what you see and hear -----------------------------------------

func _process(delta: float) -> void:
	blink = maxf(0.0, blink - delta)
	_scare = maxf(0.0, _scare - delta)
	var me := viewer
	_local_seen = me != null and state != State.DORMANT and me.is_local and blink <= 0.0 and sees_me(me, me.camera.global_transform)
	# What is shown changes only while it is not seen here.
	if not _local_seen:
		_shown_look = look
		_shown_yaw = yaw
	if state == State.FEEDING:
		_shown_look = look
		_shown_yaw = yaw
	_husk.set_pose(_shown_look)
	_husk.rotation.y = _shown_yaw
	visible = true
	# The fur dragging while it moves (nobody hears it start: only stop).
	var going := moving and state == State.STALKING
	jingle.volume_db = move_toward(jingle.volume_db, (2.0 if going else -60.0), delta * (240.0 if going else 90.0))
	if going:
		_step_in -= delta
		if _step_in <= 0.0:
			_step_in = 0.34 / clampf(speed() / SPEED, 0.8, 1.6)
			steps.pitch_scale = _rng.randf_range(0.9, 1.1)
			steps.play()
	elif _was_moving and state == State.STALKING:
		Sfx.play_3d(level, global_position + Vector3.UP, "husk_settle", -2.0)
	_was_moving = going
	# Breathing inside the head, up close, when it stands still. There is
	# nobody in there.
	var breathe := state == State.STALKING and not going and me != null and me.global_position.distance_to(global_position) < 4.0
	drone.volume_db = move_toward(drone.volume_db, (0.0 if breathe else -60.0), delta * 30.0)
