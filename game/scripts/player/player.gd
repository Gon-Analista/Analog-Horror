class_name Player
extends CharacterBody3D
## One member of the crew. The local one walks, looks, carries the
## flashlight and camcorder (first-person hands) and points at things; the
## others are bodies (PlayerAvatar) driven by what their owners replicate.
## The owner is the authority of its own movement and camcorder; what an
## interaction causes is decided by Run on the host.

signal interact_requested(target: Node)  # target may be null
signal drop_camera_requested
signal reload_requested
## Local: something in the hands was used (the toolbar shows itself).
signal used

const EYE_HEIGHT := 1.45  # matches the avatar (PlayerAvatar.SIZE)
const NAMEPLATE_RANGE := 7.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Flashlight
@onready var camcorder: Camcorder = $Camcorder

var peer_id := 1
## Played by the house (CrewBot, or the dev bot): no machine of its own.
var is_bot := false
## This machine plays the entity (EntityPilot): the hidden are not seen
## (under a table only from close by), as for the entity itself.
static var entity_view := false
## ...and it is feeling for them (Q): the hidden who talk are seen too.
static var entity_xray := false
var display_name := ""
var tint := Color(0.92, 0.5, 0.16)
var is_local := true
var alive := true
var input_enabled := true
## Interactable under the crosshair (has prompt(), on the interact layer).
var focus: Node = null
## 0..1: the flashlight fails near the entity (set by Run).
var disturbance := 0.0
var avatar: PlayerAvatar
var viewmodel: ViewModel

# Replicated: the owner writes them, everyone else follows them.
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_pitch := 0.0
var net_raise := 0.0
var net_light := true
var net_filming := false
var net_crouch := false
var net_battery := 100.0
## Name of the HideSpot this body is in ("" = not hiding). Replicated: the
## host's entity needs it, and the others stop drawing the body.
var net_hide := ""
## Dev (Alt+F1 monitor open): the entity cannot take this body.
var net_god := false
## How loud they speak into the mic (0..1, VoiceChat sets it, it decays):
## the avatar's mouth follows it.
var voice_level := 0.0
## Whether this player owns a camcorder (in a hand or in the bag). Set by
## Run on every machine (events), not replicated by the synchronizer.
var has_camera := true:
	set(v):
		has_camera = v
		if is_local and inventory:
			if v and not inventory.has("camcorder"):
				inventory.add("camcorder")
			elif not v:
				inventory.remove("camcorder")
## Local: what this player carries (hands and bag).
var inventory := Inventory.new()
## Local: the flashlight switched on (it only lights from a hand). F.
var light_on := true
## Local: the inventory is open: no looking around, no using things.
var ui_open := false
## Local: sat in front of the TV: no walking, only a little looking about.
var seated := false
var _seat_yaw := 0.0
var seat_fov := 30.0
var _stand_at := Vector3.ZERO
## Replicated: what is in each hand (the others draw it).
var net_left := "flashlight"
var net_right := "camcorder"

var crouching := false
## Local: the hiding place we are in (under a bed, a table, in a wardrobe).
var hiding: HideSpot = null
var _hide_from := Vector3.ZERO
var _light_before_hiding := true
## Local, in a wardrobe: its inside and doors, as you see them.
var _closet: Node3D
## 0 standing .. 1 crouched (smoothed, for the eye and the body).
var crouch_amount := 0.0

var _pitch := 0.0
var _bob := 0.0
var _look_delta := Vector2.ZERO
var _light_energy := 0.0
var _remote_speed := 0.0
var _last_pos := Vector3.ZERO
var _step_phase := 0.0
var _rng := RandomNumberGenerator.new()
var _nameplate: Label3D
var _steps3d: AudioStreamPlayer3D


## Before adding it to the tree.
func setup(id: int, p_name: String, p_tint: Color, local: bool) -> void:
	peer_id = id
	name = "P%d" % id
	display_name = p_name
	tint = p_tint
	is_local = local


func _ready() -> void:
	add_to_group("players")
	collision_mask = Tuning.LAYER_WORLD | Tuning.LAYER_BOARDS
	camera.current = is_local
	camera.cull_mask &= ~TvBroadcast.FEED_LAYER  # only the TV's camera sees that
	camera.fov = Tuning.FOV
	avatar = PlayerAvatar.new()
	avatar.tint = tint
	add_child(avatar)
	_light_energy = flashlight.light_energy
	# Round the hot centre of the beam, a wide soft spill (no shadow).
	var spill := SpotLight3D.new()
	spill.light_color = flashlight.light_color
	spill.light_energy = 0.55
	spill.spot_range = 11.0
	spill.spot_angle = 42.0
	spill.spot_angle_attenuation = 2.2
	spill.spot_attenuation = 1.4
	spill.light_volumetric_fog_energy = 0.25
	spill.shadow_enabled = false
	flashlight.add_child(spill)
	# Each body changes its own capsule height when crouching.
	$Collision.shape = ($Collision.shape as CapsuleShape3D).duplicate()
	flashlight.top_level = true
	if is_local:
		avatar.set_self_view()
		camera.cull_mask &= ~(Entity.LAYER_MASK | PlayerAvatar.SELF_LAYER)
		viewmodel = ViewModel.new()
		viewmodel.tint = tint
		camera.add_child(viewmodel)
		_add_dust()
	else:
		camera.cull_mask &= ~Entity.LAYER_MASK
		_add_nameplate()
		_steps3d = AudioStreamPlayer3D.new()
		_steps3d.stream = Sfx.get_stream("step")
		_steps3d.unit_size = 3.0
		_steps3d.volume_db = -10.0
		_steps3d.bus = "Effects"
		add_child(_steps3d)
	_add_sync()
	_snap_flashlight()
	if is_local:
		inventory.left = "flashlight"
		inventory.right = "camcorder" if has_camera else ""
		inventory.changed.connect(func() -> void: used.emit())


## Whether `item` is in one of the hands (the local inventory, or what the
## owner replicated).
func holds(item: String) -> bool:
	if is_local:
		return inventory.in_hand(item)
	return net_left == item or net_right == item


## Spawns and dev tours.
func set_view(yaw: float, pitch := 0.0) -> void:
	rotation.y = yaw
	_pitch = pitch
	head.rotation.x = pitch
	velocity = Vector3.ZERO
	net_pos = global_position
	net_yaw = yaw
	net_pitch = pitch
	_snap_flashlight()


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if false and event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if not input_enabled or not alive or ui_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m: Vector2 = (event as InputEventMouseMotion).screen_relative * Tuning.MOUSE_SENS
		if seated:
			rotation.y = clampf(wrapf(rotation.y - m.x - _seat_yaw, -PI, PI), -0.5, 0.5) + _seat_yaw
		else:
			rotate_y(-m.x)
		_pitch = clampf(_pitch - m.y, -1.4, 1.4) if hiding == null and not seated else clampf(_pitch - m.y, -0.35, 0.3)
		head.rotation.x = _pitch
		_look_delta += m
	elif event.is_action_pressed("crouch"):
		if hiding:
			pass
		elif not crouching:
			_set_crouch(true)
		elif _can_stand():
			_set_crouch(false)
	elif event.is_action_pressed("flashlight"):
		light_on = not light_on
		Sfx.play(self, "click", -6.0)
		used.emit()
	elif event.is_action_pressed("interact"):
		interact_requested.emit(focus)
	elif event.is_action_pressed("drop_camera"):
		drop_camera_requested.emit()
	elif event.is_action_pressed("reload"):
		reload_requested.emit()


func _physics_process(delta: float) -> void:
	if is_local:
		_move_local(delta)
	else:
		_follow_remote(delta)


func _move_local(delta: float) -> void:
	if hiding:
		_stay_hidden(delta)
		return
	if seated:
		velocity = Vector3.ZERO
		head.position.y = move_toward(head.position.y, Tuning.SEAT_EYE, delta * 2.0)
		_update_focus()
		net_pos = global_position
		net_yaw = rotation.y
		net_pitch = _pitch
		net_crouch = true
		return
	var wish := Vector3.ZERO
	if input_enabled and alive:  # (walking still works with the inventory open)
		var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		wish = transform.basis * Vector3(v.x, 0.0, v.y)
	var speed := Tuning.WALK_SPEED
	if crouching:
		speed = Tuning.CROUCH_SPEED
	elif camcorder.raise > 0.5:
		speed = Tuning.FILM_SPEED
	elif Input.is_action_pressed("sprint"):
		speed = Tuning.SPRINT_SPEED
	var target := wish.limit_length(1.0) * speed
	var accel := Tuning.ACCEL if wish != Vector3.ZERO else Tuning.DECEL
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	elif input_enabled and alive and not crouching and Input.is_action_just_pressed("jump"):
		velocity.y = Tuning.JUMP_VELOCITY
	move_and_slide()
	_head_bob(delta)
	_update_focus()
	net_pos = global_position
	net_yaw = rotation.y
	net_pitch = _pitch
	net_raise = camcorder.raise
	net_light = flashlight.visible
	net_filming = camcorder.filming
	net_crouch = crouching
	net_battery = camcorder.battery
	net_left = inventory.left
	net_right = inventory.right


## Other players: glide towards what their owner replicated.
func _follow_remote(delta: float) -> void:
	var w := minf(1.0, delta * 12.0)
	var spot := _hidden_spot()
	head.position.y = lerpf(head.position.y, spot.eye() if spot else (Tuning.CROUCH_EYE if net_crouch else EYE_HEIGHT), w)
	global_position = global_position.lerp(net_pos, w)
	rotation.y = lerp_angle(rotation.y, net_yaw, w)
	_pitch = lerpf(_pitch, net_pitch, w)
	head.rotation.x = _pitch
	var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
	_last_pos = global_position
	_remote_speed = lerpf(_remote_speed, moved / maxf(delta, 0.001), minf(1.0, delta * 8.0))
	if _remote_speed > 0.4 and alive:
		var phase := int(_step_phase / PI)
		_step_phase += delta * _remote_speed * 2.6
		if int(_step_phase / PI) != phase:
			_steps3d.pitch_scale = _rng.randf_range(0.9, 1.1)
			_steps3d.play()


func _process(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length() if is_local else _remote_speed
	var crouched := crouching if is_local else net_crouch
	crouch_amount = move_toward(crouch_amount, 1.0 if crouched else 0.0, delta * 5.0)
	# Hidden, the others still see you in there (lying under the bed or the
	# table; in a wardrobe the doors hide you). Only you do not draw yourself.
	avatar.visible = (alive or avatar.dying) and not avatar.hidden_for_view and (net_hide == "" or avatar.dying or not is_local)
	var spot := _hidden_spot()
	if entity_view and spot and not avatar.dying:
		var cam := get_viewport().get_camera_3d()
		var near := cam != null and cam.global_position.distance_to(global_position) < Tuning.TABLE_SIGHT
		avatar.visible = avatar.visible and ((spot.kind == HideSpot.Kind.TABLE and near) or (entity_xray and voice_level > 0.15))
	avatar.lying = spot != null and spot.kind != HideSpot.Kind.WARDROBE and not avatar.dying
	if avatar.lying:
		# The head just at the edge of the furniture, looking out.
		avatar.lie_back = PlayerAvatar.LYING_LENGTH - (spot.depth * 0.5 + 0.12)
	if avatar.lying:
		crouch_amount = 0.0
	avatar.set_has_camera(holds("camcorder"))
	avatar.set_has_light(holds("flashlight"))
	voice_level = maxf(0.0, voice_level - delta * 4.0)
	avatar.set_voice(voice_level)
	avatar.set_fear(1.0 if avatar.dying or not alive else clampf(disturbance * 2.0, 0.0, 1.0))
	if not avatar.dying:
		avatar.animate(delta, speed, _pitch, camcorder.raise, camcorder.filming, crouch_amount)
	if viewmodel:
		viewmodel.visible = alive
		viewmodel.set_hands(inventory.left, inventory.right)
		viewmodel.animate(delta, camcorder.raise, speed, _look_delta, camcorder.filming)
		_look_delta = Vector2.ZERO
	# The beam: from the hand in the first-person view, from the head
	# (where the avatar aims it) for the others.
	var target := viewmodel.light_transform() if viewmodel else camera.global_transform * Transform3D(Basis(), Vector3(-0.22, -0.2, -0.2))
	# Filming, the light shines from the camcorder itself, straight down
	# the middle of the picture (the hand holding it moves out of the way).
	if camcorder.raise > 0.5:
		target = target.interpolate_with(camera.global_transform * Transform3D(Basis(), Vector3(0.06, -0.05, -0.15)), smoothstep(0.5, 1.0, camcorder.raise))
	if avatar.dying:
		target = avatar.light_transform()  # the beam thrashes with the body
	flashlight.global_transform = flashlight.global_transform.interpolate_with(target, minf(1.0, delta * 14.0))
	if not is_local:
		flashlight.visible = net_light and (alive or avatar.dying)
	else:
		flashlight.visible = light_on and holds("flashlight") and alive
	var e := _light_energy
	if disturbance > 0.0 and _rng.randf() < disturbance * 0.35:
		e *= _rng.randf_range(0.0, 0.5)
	flashlight.light_energy = e
	if _nameplate:
		_update_nameplate()


func _snap_flashlight() -> void:
	if is_inside_tree():
		flashlight.global_transform = camera.global_transform * Transform3D(Basis(), Vector3(-0.2, -0.2, -0.3))


func _head_bob(delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z).length()
	var eye := lerpf(EYE_HEIGHT, Tuning.CROUCH_EYE, smoothstep(0.0, 1.0, crouch_amount)) - (viewmodel.dip() if viewmodel else 0.0)
	if horizontal > 0.3 and is_on_floor():
		var phase := int(_bob / PI)
		_bob += delta * horizontal * 2.6
		if int(_bob / PI) != phase:
			Sfx.play(self, "step", -16.0 + horizontal - (6.0 if crouching else 0.0), _rng.randf_range(0.9, 1.1))
		head.position.y = eye - absf(sin(_bob)) * 0.035
		head.position.x = sin(_bob) * 0.012
	else:
		head.position.y = move_toward(head.position.y, eye, delta * 2.5)
		head.position.x = move_toward(head.position.x, 0.0, delta * 0.1)


## Crawls into a hiding place: the body lies inside the furniture (no
## collision), the view at its height, looking out of its opening.
func hide_in(spot: HideSpot) -> void:
	if hiding or not alive:
		return
	_hide_from = global_position
	hiding = spot
	net_hide = String(spot.name)
	_light_before_hiding = light_on
	light_on = false  # a light in a hiding place gives you away
	if is_local and spot.kind == HideSpot.Kind.WARDROBE:
		var level := get_tree().current_scene.get_node("Run").level as Level
		_closet = spot.make_inside(level)
		spot.add_child(_closet)
	$Collision.disabled = true
	velocity = Vector3.ZERO
	global_position = spot.inside
	rotation.y = atan2(-spot.facing.x, -spot.facing.z)
	_pitch = 0.0
	head.rotation.x = 0.0
	head.position = Vector3(0.0, spot.eye(), 0.0)
	Sfx.play(self, "step", -8.0, 0.7)


## Sits down at `at` facing `yaw` (the TV): stays until stand_up().
func sit(at: Vector3, yaw: float, fov := Tuning.SEAT_FOV, pitch := -0.05) -> void:
	if seated or hiding:
		return
	seated = true
	_stand_at = global_position
	$Collision.disabled = true
	global_position = at
	_seat_yaw = yaw
	seat_fov = fov
	set_view(yaw, pitch)
	used.emit()


func stand_up() -> void:
	if not seated:
		return
	seated = false
	global_position = _stand_at
	$Collision.disabled = false
	head.position.y = EYE_HEIGHT


## Back out where we came in.
func leave_hide() -> void:
	if hiding == null:
		return
	hiding = null
	net_hide = ""
	light_on = _light_before_hiding
	if _closet:
		_closet.queue_free()
		_closet = null
	global_position = _hide_from
	$Collision.disabled = false
	if not _can_stand():
		_set_crouch(true)
	Sfx.play(self, "step", -8.0, 0.7)


func is_hidden() -> bool:
	return net_hide != ""


## The hiding place this body is in (from the replicated name), or null.
func _hidden_spot() -> HideSpot:
	if net_hide == "":
		return null
	if hiding:
		return hiding
	var level := get_tree().get_first_node_in_group("level") as Level
	if level == null:
		var run := get_tree().current_scene.get_node_or_null("Run") as Run
		level = run.level if run else null
	return level.get_node_or_null(net_hide) as HideSpot if level else null


func _stay_hidden(delta: float) -> void:
	velocity = Vector3.ZERO
	if _closet:
		# The entity pulls the doors open when it leans in.
		var open := 1.4 if camcorder.peeked else 0.5  # (a crack you can see the room through)
		for k in [["DoorL", 1.0], ["DoorR", -1.0]]:
			var door := _closet.get_node(String(k[0])) as Node3D
			door.rotation.y = lerpf(door.rotation.y, open * float(k[1]), minf(1.0, delta * 9.0))
	head.position = head.position.move_toward(Vector3(0.0, hiding.eye(), 0.0), delta * 2.0)
	_update_focus()
	net_pos = global_position
	net_yaw = rotation.y
	net_pitch = _pitch
	net_raise = camcorder.raise
	net_light = flashlight.visible
	net_filming = camcorder.filming
	net_crouch = true
	net_battery = camcorder.battery


func _set_crouch(on: bool) -> void:
	crouching = on
	var shape := $Collision.shape as CapsuleShape3D
	shape.height = Tuning.CROUCH_HEIGHT if on else Tuning.STAND_HEIGHT
	$Collision.position.y = shape.height * 0.5


## Room above to stand up (not under the boards or a table).
func _can_stand() -> bool:
	var probe := CapsuleShape3D.new()
	probe.radius = 0.26
	probe.height = Tuning.STAND_HEIGHT - 0.05
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.transform = Transform3D(Basis(), global_position + Vector3.UP * (Tuning.STAND_HEIGHT * 0.5 + 0.03))
	q.collision_mask = Tuning.LAYER_WORLD | Tuning.LAYER_BOARDS
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _update_focus() -> void:
	focus = null
	if not input_enabled or not alive:
		return
	if hiding:
		focus = hiding  # E comes out
		return
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * Tuning.INTERACT_RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, Tuning.LAYER_WORLD | Tuning.LAYER_INTERACT, [get_rid()])
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider.has_method("prompt"):
		focus = hit.collider
	elif Net.is_solo():
		focus = _nearest_pickup()


## Solo: the closest tape or battery you are standing next to, aimed at or
## not (searching alone in the dark is hard enough).
func _nearest_pickup() -> Pickup:
	var best: Pickup = null
	var best_d := Tuning.SOLO_PICKUP_RADIUS
	for node in get_tree().get_nodes_in_group("pickups"):
		var p := node as Pickup
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = p
	return best


func _add_sync() -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["net_pos", "net_yaw", "net_pitch", "net_raise", "net_battery"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for prop in ["net_light", "net_filming", "net_crouch", "net_hide", "net_god", "net_left", "net_right"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = cfg
	sync.replication_interval = 1.0 / 30.0
	add_child(sync)


## The other players' names, faint, only up close (like a name tag on a
## jacket you can read in the light).
func _add_nameplate() -> void:
	_nameplate = Label3D.new()
	_nameplate.text = display_name
	_nameplate.font_size = 28
	_nameplate.pixel_size = 0.004
	_nameplate.outline_size = 6
	_nameplate.modulate = tint.lightened(0.35)
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.position.y = 2.05
	add_child(_nameplate)


func _update_nameplate() -> void:
	var cam := get_viewport().get_camera_3d()
	var d := cam.global_position.distance_to(global_position) if cam else 99.0
	_nameplate.visible = alive and d < NAMEPLATE_RANGE and not entity_view  # (the entity does not read names)
	_nameplate.position.y = 0.55 if is_hidden() else 2.05  # over where they lie
	_nameplate.modulate.a = clampf((NAMEPLATE_RANGE - d) / 3.0, 0.0, 0.8)


## Dust hanging in the air around the player. The motes are lit like
## everything else, so they only show inside the flashlight beam.
func _add_dust() -> void:
	var dust := GPUParticles3D.new()
	dust.amount = 350
	dust.lifetime = 10.0
	dust.preprocess = 10.0
	dust.local_coords = false
	dust.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 6, 12))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(4.0, 1.3, 4.0)
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 0.005
	process.initial_velocity_max = 0.03
	process.gravity = Vector3(0, -0.004, 0)
	dust.process_material = process
	var mote := QuadMesh.new()
	mote.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.85, 0.82, 0.74)
	m.roughness = 1.0
	mote.material = m
	dust.draw_pass_1 = mote
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.position.y = 1.3
	add_child(dust)
