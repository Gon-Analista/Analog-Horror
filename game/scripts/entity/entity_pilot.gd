class_name EntityPilot
extends Node
## "La Visita es un jugador": this machine is the entity. Only on the
## machine of the one who plays it (Run.become_pilot).
##
## You see through its eyes: a red sight that sees in the dark but fades
## past ~10 m, and it hears through walls (a red ring where someone runs,
## talks, takes a tape, opens a door, fires a flash). WASD walks (silent
## enough), C creeps (no steps at all), SHIFT hunts (fast, loud, it
## shrieks, for a few seconds), SPACE climbs to the ceiling (slow, over the
## furniture and through the broken windows over the doors; nobody hears
## it) and drops back; LEFT CLICK lunges and grabs (from the ceiling: drops
## on whoever is below), RIGHT CLICK says something to them, Q feels where
## everyone is for a moment (they hear it whisper), E opens a door or looks
## into a hiding place (whoever is in there sees its face: a flash then
## saves them).
## It moves here, without waiting for the network, and tells the host 30
## times a second; the host passes it on and decides every catch.

enum Move { WALK, SNEAK, SPRINT }

var run: Run
var entity: Entity
var level: Level
var body: CharacterBody3D
var camera: Camera3D
var hud: Control
var yaw := 0.0
var pitch := 0.0
var move := Move.WALK
var ceiling := false
var stamina := Tuning.PILOT_STAMINA
var exhausted := false
## The door or hiding place in front (E).
var focus: Node = null
## Heard through the walls: [position, age, kind] (kind: "run", "voice", "sound").
var pings: Array = []
## Q: seconds left of feeling where everyone is.
var sense_left := 0.0
var sense_cd := 0.0
var attack_cd := 0.0
var stun := 0.0
var miss := 0.0
var lunge := 0.0
var climb := 0.0
var _climb_up := false
var _ceiling_cd := 0.0
var _search_cd := 0.0
var _lock := 0.0
## Hidden in a wardrobe or under a bed, like the crew (E): unseen, waiting.
var hidden: HideSpot = null
var _asked_spot: HideSpot = null
var _hide_yaw := 0.0
var _closet: Node3D = null
var _slow := 0.0
var _send_in := 0.0
var _heard_at := {}  # what made a ring -> when (not every frame)
var _was_feeding := false
var _eye := Tuning.PILOT_EYE
var _shape: CollisionShape3D
var _clock := 0.0
# Its sight: the shader over the picture (instead of the crew's), the heat
# of the living laid over their bodies (through the walls while it feels).
var _sight: ColorRect
var _sight_mat: ShaderMaterial
var _post_fx: CanvasItem
var _heat: ShaderMaterial
var _xray: ShaderMaterial
var _heated := {}  # Player -> [GeometryInstance3D]
# Its body: the heart (faster as it hunts and when they are near), its
# breath, the sway of its walk, the jolt of a landing.
var _beat_in := 0.0
var _pulse := 0.0
var _heart: AudioStreamPlayer
var _breath: AudioStreamPlayer
var _bob := 0.0
var _land_kick := 0.0
var _sense_fx := 0.0
var _hunt := 0.0


func setup(p_run: Run, ui: Node) -> void:
	run = p_run
	entity = run.entity
	level = run.level
	process_priority = -10  # before the entity draws itself
	process_physics_priority = -10
	entity.piloted_here = true
	body = CharacterBody3D.new()
	body.name = "PilotBody"
	body.collision_layer = 0
	body.collision_mask = Tuning.LAYER_WORLD | Tuning.LAYER_BOARDS
	body.floor_snap_length = 0.45
	body.floor_max_angle = deg_to_rad(50.0)
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	_shape.shape = cap
	_shape.position.y = 0.85
	body.add_child(_shape)
	level.add_child(body)
	body.global_position = entity.global_position
	camera = Camera3D.new()
	camera.fov = Tuning.PILOT_FOV
	camera.near = 0.05
	camera.cull_mask = run.local_player.camera.cull_mask & ~(Entity.LAYER_MASK | ViewModel.LAYER_MASK)
	camera.environment = _vision()
	level.add_child(camera)
	camera.current = true
	var hud_node := PilotHud.new()
	ui.add_child(hud_node)
	hud_node.setup(self)
	hud = hud_node
	Sfx.listeners.append(_heard)
	Player.entity_view = true
	# Its own sounds are right in its ears: far quieter here (and never
	# louder than this, however close).
	entity.drone.volume_db -= 22.0
	for a: AudioStreamPlayer3D in [entity.voice, entity.steps, entity.drone, entity.jingle]:
		a.max_db = -8.0
	_build_sight()
	_heart = AudioStreamPlayer.new()
	_heart.stream = Sfx.get_stream("pilot_heart")
	_heart.bus = "Effects"
	add_child(_heart)
	_breath = AudioStreamPlayer.new()
	_breath.stream = Sfx.get_stream("neck_breath", true)
	_breath.bus = "Effects"
	_breath.volume_db = -40.0
	add_child(_breath)
	_breath.play()


## Its eye over the picture (the crew's tape look goes), and the heat.
func _build_sight() -> void:
	var post := level.get_parent().get_node_or_null("PostLayer")
	if post:
		_post_fx = post.get_node_or_null("PostFX") as CanvasItem
		_sight = ColorRect.new()
		_sight.name = "EntitySight"
		_sight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sight_mat = ShaderMaterial.new()
		_sight_mat.shader = load("res://shaders/entity_sight.gdshader")
		_sight.material = _sight_mat
		post.add_child(_sight)
	_heat = ShaderMaterial.new()
	_heat.shader = load("res://shaders/entity_heat.gdshader")
	_xray = ShaderMaterial.new()
	_xray.shader = load("res://shaders/entity_heat_xray.gdshader")


## Back in the window (after Alt+Tab): the mouse is the view's again.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and run and run.phase == Run.Phase.PLAYING 			and not get_tree().paused and not run.screens.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	Sfx.listeners.erase(_heard)
	Player.entity_view = false
	Player.entity_xray = false


## Its sight in the light of the house: it sees in the dark (a faint even
## light everywhere), and past ~10 m everything sinks into black (the
## shader turns it red).
func _vision() -> Environment:
	var world_env := level.get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	var env: Environment = world_env.environment.duplicate() if world_env else Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.8, 0.78)
	env.ambient_light_energy = 0.3
	env.volumetric_fog_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.0, 0.0, 0.0)
	env.fog_light_energy = 0.0
	env.fog_density = Tuning.PILOT_FOG
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.15
	return env


func max_stamina() -> float:
	return Tuning.PILOT_STAMINA * (1.5 if entity.enraged else 1.0)


func asleep() -> bool:
	return entity.state == Entity.State.DORMANT


func feeding() -> bool:
	return entity.state == Entity.State.FEEDING


func _unhandled_input(event: InputEvent) -> void:
	if run.phase != Run.Phase.PLAYING or get_tree().paused:
		return
	# The mouse let go (Alt+Tab, another window): a click takes it back
	# (that click does nothing else).
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not run.screens.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m: Vector2 = (event as InputEventMouseMotion).screen_relative * Tuning.MOUSE_SENS
		yaw = wrapf(yaw - m.x, -PI, PI)
		pitch = clampf(pitch - m.y, -1.45, 1.3)
		return
	if asleep() or feeding():
		return
	if event.is_action_pressed("flash"):
		_attack()
	elif event.is_action_pressed("jump"):
		_toggle_ceiling()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_Q:
		_sense()


func _physics_process(delta: float) -> void:
	_clock += delta
	for k in ["sense_cd", "attack_cd", "stun", "miss", "_ceiling_cd", "_search_cd", "_lock", "_slow", "sense_left"]:
		set(k, maxf(0.0, float(get(k)) - delta))
	var me := run.local_player
	_update_senses(delta)
	if asleep():
		# Waiting to wake: wherever the host has it.
		entity.global_position = entity.net_pos
		body.global_position = entity.net_pos
		_place_view(delta)
		me.global_position = body.global_position
		return
	if feeding():
		_was_feeding = true
		_place_view(delta)
		return
	if _was_feeding:
		_was_feeding = false
		_slow = Tuning.PILOT_AFTER_MEAL
	# Climbing up or down: still for a moment.
	if climb > 0.0:
		climb = maxf(0.0, climb - delta)
		if climb <= 0.0:
			_finish_climb()
			_land_kick = 1.0 if not ceiling else 0.5
			Sfx.play(self, "pilot_land", -20.0 if ceiling else -16.0)
	var can_move := run.phase == Run.Phase.PLAYING and _lock <= 0.0 and climb <= 0.0 and hidden == null
	var wish := Vector3.ZERO
	if can_move:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		wish = Basis(Vector3.UP, yaw) * Vector3(iv.x, 0.0, iv.y)
	var sprinting := wish != Vector3.ZERO and Input.is_action_pressed("sprint") and not exhausted and not ceiling and stun <= 0.0
	# C: crouched (low, slow, silent; under the boards across a doorway).
	var sneaking := not sprinting and not ceiling and (Input.is_action_pressed("crouch") or not _room_to_stand())
	_set_low(sneaking)
	move = Move.SPRINT if sprinting else (Move.SNEAK if sneaking else Move.WALK)
	if sprinting:
		stamina -= delta
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
	else:
		stamina = minf(max_stamina(), stamina + Tuning.PILOT_STAMINA_REGEN * delta)
		if exhausted and stamina >= max_stamina() * 0.4:
			exhausted = false
	var speed := Tuning.PILOT_SPRINT if sprinting else (Tuning.PILOT_SNEAK if sneaking else Tuning.PILOT_WALK)
	if ceiling:
		speed = Tuning.PILOT_CEILING_SPEED
	speed *= 1.0 + Tuning.PILOT_SPEED_PER_TAPE * entity.tapes
	if stun > 0.0:
		speed *= Tuning.PILOT_STUN_SLOW
	if miss > 0.0:
		speed *= Tuning.PILOT_MISS_SLOW
	if _slow > 0.0:
		speed *= 0.5
	if lunge > 0.0:
		# The charge: screaming, straight at them (it steers with the view);
		# whoever it reaches on the way, it takes.
		lunge = maxf(0.0, lunge - delta)
		wish = Basis(Vector3.UP, yaw) * Vector3.FORWARD
		speed = Tuning.PILOT_CHARGE_SPEED
		if _someone_in_reach():
			lunge = 0.0  # (it grabs them, it does not run on past)
		if lunge <= 0.0:
			_send_state()
			_send_attack(false)
	if ceiling or climb > 0.0:
		# (Up there, or on the way up or down: never the body's physics: with
		# its shape off it fell through the floor while climbing.)
		_move_ceiling(wish.limit_length(1.0) * speed if ceiling else Vector3.ZERO, delta)
	else:
		var target := wish.limit_length(1.0) * speed
		body.velocity.x = move_toward(body.velocity.x, target.x, 24.0 * delta)
		body.velocity.z = move_toward(body.velocity.z, target.z, 24.0 * delta)
		body.velocity.y = -0.5 if body.is_on_floor() else body.velocity.y - 9.8 * delta
		body.move_and_slide()
	if entity.mode != Entity.Mode.PEEK:
		entity.global_position = body.global_position
	me.global_position = body.global_position
	_place_view(delta)
	_update_entity()
	_update_focus()
	_listen(delta)
	_send_in -= delta
	if _send_in <= 0.0:
		_send_in = 1.0 / 30.0
		_send_state()


func _place_view(delta: float) -> void:
	var want := Tuning.PILOT_EYE
	if ceiling or (climb > 0.0 and _climb_up):
		want = Level.HEIGHT - 0.3
	elif move == Move.SNEAK:
		want = Tuning.PILOT_SNEAK_EYE
	if climb > 0.0:
		var k := 1.0 - climb / Tuning.PILOT_CLIMB_TIME
		var a := Tuning.PILOT_EYE if _climb_up else Level.HEIGHT - 0.3
		var b := Level.HEIGHT - 0.3 if _climb_up else Tuning.PILOT_EYE
		_eye = lerpf(a, b, smoothstep(0.0, 1.0, k))
	else:
		_eye = move_toward(_eye, want, delta * 3.0)
	var shake := Vector3.ZERO
	if stun > 0.0:
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * 0.03 * minf(1.0, stun)
	# The sway of its walk: slow and deep creeping, a hard jolt running;
	# on the ceiling, a slow crawl.
	var flat := Vector2(body.velocity.x, body.velocity.z).length() if not ceiling else (Tuning.PILOT_CEILING_SPEED if Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO else 0.0)
	_bob += delta * flat * (2.6 if move == Move.SPRINT else 1.9)
	var sway := clampf(flat / Tuning.PILOT_SPRINT, 0.0, 1.0)
	var bob := Vector3(cos(_bob) * 0.035, -absf(sin(_bob)) * 0.06, 0.0) * sway * (1.6 if move == Move.SPRINT else 1.0)
	var roll := sin(_bob) * 0.025 * sway + (sin(_clock * 1.3) * 0.01 if move == Move.SNEAK else 0.0)
	_land_kick = move_toward(_land_kick, 0.0, delta * 4.0)
	bob.y -= _land_kick * _land_kick * 0.18
	var basis := Basis.from_euler(Vector3(pitch - _land_kick * 0.08, yaw, roll))
	camera.global_transform = Transform3D(basis, body.global_position + Vector3.UP * _eye + basis * bob + shake)
	if hidden:
		# From inside where it hides, looking out of the opening (the
		# wardrobe's doors either side of the crack, as for the crew).
		var b := Basis.from_euler(Vector3(clampf(pitch, -0.3, 0.3), clampf(wrapf(yaw - _hide_yaw, -PI, PI), -0.55, 0.55) + _hide_yaw, 0.0))
		camera.global_transform = Transform3D(b, hidden.inside + Vector3.UP * hidden.eye())
		camera.fov = lerpf(camera.fov, 62.0, minf(1.0, delta * 6.0))
	var lunge_fov := 14.0 if lunge > 0.0 else 0.0
	camera.fov = lerpf(camera.fov, Tuning.PILOT_FOV + (8.0 if move == Move.SPRINT else 0.0) + lunge_fov - (6.0 if move == Move.SNEAK else 0.0), minf(1.0, delta * 6.0))


## What the others see of it (this machine draws nothing, but the host
## and the recording read these).
func _update_entity() -> void:
	entity.on_ceiling = ceiling or (climb > 0.0 and _climb_up)
	entity._facing = Basis(Vector3.UP, yaw) * Vector3.FORWARD
	if entity.mode == Entity.Mode.PEEK and _lock > 0.0:
		return
	entity.pose = Entity.Pose.LUNGE if lunge > 0.0 else (Entity.Pose.CROUCH if move == Move.SNEAK else Entity.Pose.STAND)
	entity.mode = _mode()


func _mode() -> Entity.Mode:
	if ceiling or climb > 0.0:
		return Entity.Mode.AMBUSH
	if lunge > 0.0 or move == Move.SPRINT:
		return Entity.Mode.CHASE
	if stun > 0.0:
		return Entity.Mode.FLEE
	return Entity.Mode.STALK if move == Move.SNEAK else Entity.Mode.WANDER


func _send_state() -> void:
	var pos := body.global_position
	if multiplayer.is_server():
		run.pilot_moved(pos, yaw, entity.on_ceiling, int(_mode()))
	else:
		run._pilot_state.rpc_id(1, pos, yaw, entity.on_ceiling, int(_mode()))


# --- the ceiling -----------------------------------------------------------------

func _toggle_ceiling() -> void:
	if climb > 0.0 or _ceiling_cd > 0.0 or stun > 0.0 or lunge > 0.0 or _lock > 0.0:
		return
	if hidden:
		return
	if not ceiling and level.stair_end_near(body.global_position).x >= 0:
		return  # (not on a flight of stairs)
	_climb_up = not ceiling
	climb = Tuning.PILOT_CLIMB_TIME
	if _climb_up:
		_shape.disabled = true
		body.velocity = Vector3.ZERO


func _finish_climb() -> void:
	ceiling = _climb_up
	_ceiling_cd = Tuning.PILOT_CEILING_COOLDOWN
	if not ceiling:
		_land()


## Back on the floor: never inside furniture or a wall.
func _land() -> void:
	ceiling = false
	_shape.disabled = false
	var c := level.cell_of(body.global_position)
	if not level.is_walkable(c):
		var to := level.center(level.nearest_walkable(c))
		body.global_position = Vector3(to.x, to.y, to.z)
	else:
		body.global_position.y = level.center(c).y
	body.velocity = Vector3.ZERO


## Along the ceiling: over the furniture, not through walls, and past a
## closed door only through the broken window over it.
func _ceiling_ok(c: Vector3i) -> bool:
	var ch := level.char_at(c)
	if HouseLayout.is_solid_char(ch) or ch == "S":
		return false
	var door := level.door_at(c)
	return door == null or not door.blocks() or door.transom


func _move_ceiling(vel: Vector3, delta: float) -> void:
	var pos := body.global_position
	for axis: Vector3 in [Vector3(vel.x, 0.0, 0.0), Vector3(0.0, 0.0, vel.z)]:
		var step := axis * delta
		if step.length() < 0.00001:
			continue
		var probe := pos + step + step.normalized() * 0.22
		if _ceiling_ok(level.cell_of(probe)):
			pos += step
	body.global_position = pos


# --- actions -----------------------------------------------------------------------

func _attack() -> void:
	if hidden:
		_leave_hiding()  # out of it, straight at them
		attack_cd = 0.0
	if attack_cd > 0.0 or lunge > 0.0 or stun > 0.0 or _lock > 0.0 or climb > 0.0:
		return
	if ceiling:
		# It lets go and falls on whoever is under it.
		_land()
		_ceiling_cd = Tuning.PILOT_CEILING_COOLDOWN
		attack_cd = 1.0
		_send_state()
		_send_attack(true)
		return
	lunge = Tuning.PILOT_CHARGE_TIME
	attack_cd = Tuning.PILOT_CHARGE_TIME + Tuning.PILOT_ATTACK_COOLDOWN
	run._pilot_charge.rpc_id(1)  # (the host makes it shriek)


## Someone right in front, close enough to grab (what the host will check).
func _someone_in_reach() -> bool:
	var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	for q: Player in run.players.values():
		if not q.alive or q.peer_id == entity.pilot_id or q.is_hidden():
			continue
		var d := q.global_position - body.global_position
		var flat := Vector2(d.x, d.z)
		if absf(d.y) < 1.3 and flat.length() < Tuning.PILOT_GRAB_RANGE * 0.75 and (flat.length() < 0.4 or Vector2(fwd.x, fwd.z).dot(flat.normalized()) > 0.5):
			return true
	return false


func _send_attack(from_ceiling: bool) -> void:
	if multiplayer.is_server():
		run.pilot_attack(from_ceiling)
	else:
		run._pilot_attack.rpc_id(1, from_ceiling)


## The host: nobody there.
func missed() -> void:
	miss = Tuning.PILOT_MISS_TIME


## The host: a flash in its face.
func stunned(seconds: float) -> void:
	stun = seconds
	lunge = 0.0
	_lock = 0.0
	if ceiling or climb > 0.0:
		climb = 0.0
		_land()


func _sense() -> void:
	if sense_cd > 0.0:
		return
	Sfx.play(self, "pilot_sense", -16.0)
	sense_cd = Tuning.PILOT_SENSE_COOLDOWN * (0.5 if entity.enraged else 1.0)
	sense_left = Tuning.PILOT_SENSE_TIME
	run._pilot_sense.rpc()


## E: a door; a hiding place: if someone is in there it looks in at them
## (and takes them), if not it gets in itself and waits; hidden, E gets out.
func _interact() -> void:
	if hidden:
		_leave_hiding()
	elif focus is Door:
		run._pilot_door.rpc_id(1, String(focus.name))
	elif focus is HideSpot and _search_cd <= 0.0 and not ceiling:
		_search_cd = Tuning.PILOT_SEARCH_COOLDOWN
		_lock = Tuning.PEEK_TIME + 0.3  # (shorter if there is nobody in there)
		_asked_spot = focus
		_send_state()
		run._pilot_search.rpc_id(1, String(focus.name))


## The host: what it found in there (nobody: it got in itself).
func searched(found: bool) -> void:
	if not found:
		_lock = minf(_lock, 0.6)


func hid() -> void:
	hidden = _asked_spot
	_lock = 0.0
	if hidden:
		yaw = atan2(-hidden.facing.x, -hidden.facing.z)
		_hide_yaw = yaw
		pitch = 0.0
		if hidden.kind == HideSpot.Kind.WARDROBE:
			_closet = hidden.make_inside(level)
			hidden.add_child(_closet)


func _leave_hiding() -> void:
	hidden = null
	if _closet:
		_closet.queue_free()
		_closet = null
	_search_cd = 1.0
	run._pilot_unhide.rpc_id(1)


## Low (crouched): the body fits under the boards.
func _set_low(low: bool) -> void:
	var cap := _shape.shape as CapsuleShape3D
	var h := 0.9 if low else 1.7
	if absf(cap.height - h) > 0.01:
		cap.height = h
		_shape.position.y = h * 0.5


## Room above to stand up (not under the boards).
func _room_to_stand() -> bool:
	var space := body.get_world_3d().direct_space_state
	var from := body.global_position + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 1.3, Tuning.LAYER_WORLD | Tuning.LAYER_BOARDS)
	q.exclude = [body.get_rid()]
	return space.intersect_ray(q).is_empty()


func _update_focus() -> void:
	focus = null
	if ceiling or climb > 0.0:
		return
	var at := body.global_position
	var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var best := INF
	for d in level.doors:
		var to := d.global_position - at
		to.y = 0.0
		if to.length() < 1.5 and to.length() < best and (to.length() < 0.4 or fwd.dot(to.normalized()) > 0.3):
			best = to.length()
			focus = d
	for s in level.hide_spots:
		var to := level.center(s.access) - at
		to.y = 0.0
		if absf(level.center(s.access).y - at.y) < 1.0 and to.length() < Tuning.PILOT_SEARCH_RANGE - 0.6 and to.length() < best \
				and (s.inside - at).normalized().dot(fwd) > 0.2:
			best = to.length()
			focus = s


func prompt() -> String:
	if focus is Door:
		return tr("[E] Cerrar la puerta") if (focus as Door).is_open else tr("[E] Abrir la puerta")
	if hidden:
		return tr("[E] Salir · CLIC IZQ: saltar sobre ellos")
	if focus is HideSpot:
		return tr("[E] Esconderte o mirar dentro") if _search_cd <= 0.0 else ""
	return ""


# --- what it hears -----------------------------------------------------------------

func _listen(delta: float) -> void:
	for p in pings:
		p[1] += delta
	pings = pings.filter(func(p: Array) -> bool: return p[1] < 1.6)
	var at := body.global_position
	for q: Player in run.players.values():
		if not q.alive or q.peer_id == entity.pilot_id:
			continue
		var d := q.global_position.distance_to(at)
		var speed := q._remote_speed if not q.is_local else Vector2(q.velocity.x, q.velocity.z).length()
		if speed > 3.2 and d < Tuning.PILOT_HEAR_RUN:
			_ping("run%d" % q.peer_id, q.global_position + Vector3.UP * 0.2, "run", 0.45)
		if q.voice_level > 0.15 and d < Tuning.PILOT_HEAR_VOICE:
			_ping("voice%d" % q.peer_id, q.head.global_position, "voice", 0.35)


func _heard(id: String, pos: Vector3, _volume_db: float, _max_db: float) -> void:
	if body == null:
		return
	var d := pos.distance_to(body.global_position)
	if d > 2.5 and d < Tuning.PILOT_HEAR_SOUND and not id.begins_with("voice_") and not id.begins_with("chase_scream"):
		_ping("sound:" + id, pos, "sound", 0.3)


func _ping(key: String, pos: Vector3, kind: String, every: float) -> void:
	if _clock - float(_heard_at.get(key, -99.0)) < every:
		return
	_heard_at[key] = _clock
	pings.append([pos, 0.0, kind])


## Q: where everyone is (the hidden only if they are talking).
func sensed() -> Array[Player]:
	var out: Array[Player] = []
	if sense_left <= 0.0:
		return out
	for q: Player in run.players.values():
		if q.alive and q.peer_id != entity.pilot_id and q.global_position.distance_to(body.global_position) < Tuning.PILOT_SENSE_RANGE \
				and (not q.is_hidden() or q.voice_level > 0.15):
			out.append(q)
	return out


## The host put it somewhere (where it wakes).
func place(pos: Vector3) -> void:
	body.global_position = pos
	body.velocity = Vector3.ZERO
	entity.global_position = pos


## Its heart, its breath, the heat of the living and its eye's shader.
func _update_senses(delta: float) -> void:
	var near := INF
	for q: Player in run.players.values():
		if q.alive and q.peer_id != entity.pilot_id:
			near = minf(near, q.global_position.distance_to(body.global_position))
	# The heart: ~60 a minute at rest, up to ~140 hunting or with them close.
	var excite := clampf((1.0 - near / 10.0), 0.0, 1.0) * 0.6 + (0.6 if move == Move.SPRINT or lunge > 0.0 else 0.0) + (0.3 if stun > 0.0 else 0.0)
	var rate := lerpf(1.0, 2.3, clampf(excite, 0.0, 1.0))
	_beat_in -= delta
	if _beat_in <= 0.0 and not asleep():
		_beat_in = 1.0 / rate
		_pulse = 1.0
		_heart.volume_db = lerpf(-30.0, -18.0, clampf(excite, 0.0, 1.0))
		_heart.play()
	_pulse = maxf(0.0, _pulse - delta * 3.5)
	var panting := move == Move.SPRINT or exhausted
	_breath.volume_db = lerpf(_breath.volume_db, -22.0 if panting else (-32.0 if move != Move.SNEAK else -38.0), minf(1.0, delta * 3.0))
	_sense_fx = move_toward(_sense_fx, 1.0 if sense_left > 0.0 else 0.0, delta * 3.0)
	var replaying := run.replay != null and run.replay.playing
	if _sight:
		_sight.visible = not replaying and run.phase == Run.Phase.PLAYING
		if _post_fx:
			_post_fx.visible = not _sight.visible
		_sight_mat.set_shader_parameter("pulse", _pulse * _pulse)
		_hunt = lerpf(_hunt, 1.0 if move == Move.SPRINT or lunge > 0.0 else 0.0, minf(1.0, delta * 4.0))
		_sight_mat.set_shader_parameter("hunt", _hunt)
		_sight_mat.set_shader_parameter("hurt", clampf(stun / Tuning.PILOT_STUN, 0.0, 1.0))
		_sight_mat.set_shader_parameter("sense", _sense_fx)
		_sight_mat.set_shader_parameter("sleep", 1.0 if asleep() else 0.0)
	# The heat of the living: on their bodies, through the walls while it
	# feels for them; the taken are cold.
	Player.entity_xray = sense_left > 0.0
	for q: Player in run.players.values():
		if q.peer_id == entity.pilot_id:
			continue
		if not _heated.has(q):
			_heated[q] = GearModels.meshes(q.avatar)
		var mat: Material = null
		if q.alive and not replaying:
			mat = _xray if sense_left > 0.0 else _heat
		for m: GeometryInstance3D in _heated[q]:
			if is_instance_valid(m) and m.material_overlay != mat:
				m.material_overlay = mat
