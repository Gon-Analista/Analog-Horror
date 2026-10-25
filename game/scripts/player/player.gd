class_name Player
extends CharacterBody3D
## First-person operator: walks, looks, carries the flashlight and the
## camcorder and points at things. Only local input and presentation live
## here; what an interaction causes is decided by Run (later: by the host).

signal interact_requested(target: Node)

const EYE_HEIGHT := 1.62
## Flashlight held low and to the right: shadows read better than from the eye.
const FLASHLIGHT_OFFSET := Vector3(0.18, -0.16, 0.0)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Flashlight
@onready var camcorder: Camcorder = $Camcorder

var input_enabled := true
## Interactable under the crosshair (has prompt(), on the interact layer).
var focus: Node = null
## 0..1: the flashlight fails near the entity (set by Run).
var disturbance := 0.0
var _pitch := 0.0
var _bob := 0.0
var _light_energy := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	camera.fov = Tuning.FOV
	camera.cull_mask &= ~Entity.LAYER_MASK
	_light_energy = flashlight.light_energy
	flashlight.top_level = true
	_snap_flashlight()


## Spawns and dev tours.
func set_view(yaw: float, pitch := 0.0) -> void:
	rotation.y = yaw
	_pitch = pitch
	head.rotation.x = pitch
	velocity = Vector3.ZERO
	_snap_flashlight()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m: Vector2 = (event as InputEventMouseMotion).screen_relative * Tuning.MOUSE_SENS
		rotate_y(-m.x)
		_pitch = clampf(_pitch - m.y, -1.4, 1.4)
		head.rotation.x = _pitch
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		Sfx.play(self, "click", -6.0)
	elif event.is_action_pressed("interact") and focus != null:
		interact_requested.emit(focus)


func _physics_process(delta: float) -> void:
	var wish := Vector3.ZERO
	if input_enabled:
		var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		wish = transform.basis * Vector3(v.x, 0.0, v.y)
	var speed := Tuning.WALK_SPEED
	if camcorder.raise > 0.5:
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


func _process(delta: float) -> void:
	var target := camera.global_transform * Transform3D(Basis(), FLASHLIGHT_OFFSET)
	flashlight.global_transform = flashlight.global_transform.interpolate_with(target, minf(1.0, delta * 12.0))
	var e := _light_energy
	if disturbance > 0.0 and _rng.randf() < disturbance * 0.35:
		e *= _rng.randf_range(0.0, 0.5)
	flashlight.light_energy = e


func _snap_flashlight() -> void:
	if is_inside_tree():
		flashlight.global_transform = camera.global_transform * Transform3D(Basis(), FLASHLIGHT_OFFSET)


func _head_bob(delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal > 0.3 and is_on_floor():
		var phase := int(_bob / PI)
		_bob += delta * horizontal * 2.6
		if int(_bob / PI) != phase:
			Sfx.play(self, "step", -16.0 + horizontal, _rng.randf_range(0.9, 1.1))
		head.position.y = EYE_HEIGHT - absf(sin(_bob)) * 0.035
		head.position.x = sin(_bob) * 0.012
	else:
		head.position.y = move_toward(head.position.y, EYE_HEIGHT, delta * 0.2)
		head.position.x = move_toward(head.position.x, 0.0, delta * 0.1)


func _update_focus() -> void:
	focus = null
	if not input_enabled:
		return
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * Tuning.INTERACT_RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, Tuning.LAYER_WORLD | Tuning.LAYER_INTERACT, [get_rid()])
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider.has_method("prompt"):
		focus = hit.collider
