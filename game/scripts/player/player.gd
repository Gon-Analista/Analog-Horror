class_name Player
extends CharacterBody3D
## One member of the crew. The local one walks, looks, carries the
## flashlight and camcorder (first-person hands) and points at things; the
## others are bodies (PlayerAvatar) driven by what their owners replicate.
## The owner is the authority of its own movement and camcorder; what an
## interaction causes is decided by Run on the host.

signal interact_requested(target: Node)  # target may be null

const EYE_HEIGHT := 1.62
const NAMEPLATE_RANGE := 7.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Flashlight
@onready var camcorder: Camcorder = $Camcorder

var peer_id := 1
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

var crouching := false
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
	camera.current = is_local
	camera.fov = Tuning.FOV
	avatar = PlayerAvatar.new()
	avatar.tint = tint
	add_child(avatar)
	_light_energy = flashlight.light_energy
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
		add_child(_steps3d)
	_add_sync()
	_snap_flashlight()


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
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if not input_enabled or not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m: Vector2 = (event as InputEventMouseMotion).screen_relative * Tuning.MOUSE_SENS
		rotate_y(-m.x)
		_pitch = clampf(_pitch - m.y, -1.4, 1.4)
		head.rotation.x = _pitch
		_look_delta += m
	elif event.is_action_pressed("crouch"):
		if not crouching:
			_set_crouch(true)
		elif _can_stand():
			_set_crouch(false)
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		Sfx.play(self, "click", -6.0)
	elif event.is_action_pressed("interact"):
		interact_requested.emit(focus)


func _physics_process(delta: float) -> void:
	if is_local:
		_move_local(delta)
	else:
		_follow_remote(delta)


func _move_local(delta: float) -> void:
	var wish := Vector3.ZERO
	if input_enabled and alive:
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


## Other players: glide towards what their owner replicated.
func _follow_remote(delta: float) -> void:
	var w := minf(1.0, delta * 12.0)
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
	avatar.visible = alive and not avatar.hidden_for_view
	avatar.animate(delta, speed, _pitch, camcorder.raise, camcorder.filming, crouch_amount)
	if viewmodel:
		viewmodel.visible = alive
		viewmodel.animate(delta, camcorder.raise, speed, _look_delta, camcorder.filming)
		_look_delta = Vector2.ZERO
	# The beam: from the hand in the first-person view, from the head
	# (where the avatar aims it) for the others.
	var target := viewmodel.light_transform() if viewmodel else camera.global_transform * Transform3D(Basis(), Vector3(-0.22, -0.2, -0.2))
	flashlight.global_transform = flashlight.global_transform.interpolate_with(target, minf(1.0, delta * 14.0))
	if not is_local:
		flashlight.visible = net_light and alive
	elif not alive:
		flashlight.visible = false
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
	var eye := lerpf(EYE_HEIGHT, Tuning.CROUCH_EYE, smoothstep(0.0, 1.0, crouch_amount))
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
	q.collision_mask = Tuning.LAYER_WORLD
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _update_focus() -> void:
	focus = null
	if not input_enabled or not alive:
		return
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * Tuning.INTERACT_RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, Tuning.LAYER_WORLD | Tuning.LAYER_INTERACT, [get_rid()])
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider.has_method("prompt"):
		focus = hit.collider


func _add_sync() -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["net_pos", "net_yaw", "net_pitch", "net_raise"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for prop in ["net_light", "net_filming", "net_crouch"]:
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
	_nameplate.visible = alive and d < NAMEPLATE_RANGE
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
