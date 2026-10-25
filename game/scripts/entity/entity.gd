class_name Entity
extends Node3D
## "La Visita": the mascot of ¡Hola, Vecinitos!, a children's show that was
## never aired. It is drawn only on visual layer 2, which only a filming
## camcorder renders. Rule: it does not move while someone films it, and it
## comes faster when nobody even looks its way. Its movement runs on the
## authority (the host); presentation (shadow, audio) runs everywhere.

signal caught(player: Player)

const LAYER_MASK := 2  # visual layer 2
enum State { DORMANT, STALKING, FROZEN, FEEDING }

var state := State.DORMANT
var level: Level
var target: Player
## Escalation: tapes the team has taken.
var tapes := 0
var _path: Array[Vector2i] = []
var _repath := 0.0
var _step_acc := 0.0
var _parts: Array[GeometryInstance3D] = []
var _head: Node3D

@onready var music: AudioStreamPlayer3D = $MusicBox
@onready var steps: AudioStreamPlayer3D = $Steps


func _ready() -> void:
	_build_model()
	music.stream = Sfx.get_stream("music_box", true)
	music.play()
	steps.stream = Sfx.get_stream("entity_step")


func wake() -> void:
	if state == State.DORMANT:
		state = State.STALKING


func speed() -> float:
	return Tuning.ENTITY_SPEED + Tuning.ENTITY_SPEED_PER_TAPE * tapes


## Whether `p` is filming it right now: camcorder up, inside the frame,
## within range and not behind a wall (head or chest is enough).
func is_filmed_by(p: Player) -> bool:
	if not p.camcorder.filming:
		return false
	var cam := p.camera
	var space := get_world_3d().direct_space_state
	for h: float in [1.0, 1.95]:
		var point := global_position + Vector3.UP * h
		if not cam.is_position_in_frustum(point):
			continue
		if cam.global_position.distance_to(point) > Tuning.FILM_RANGE:
			continue
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, point, Tuning.LAYER_WORLD)
		if space.intersect_ray(q).is_empty():
			return true
	return false


## The capture: it stands in front of the camera, visible, face to face.
func lunge_at(p: Player) -> void:
	state = State.FEEDING
	var cam := p.camera
	var front := cam.global_position - cam.global_transform.basis.z * 0.85
	global_position = Vector3(front.x, cam.global_position.y - 2.0, front.z)
	_face(cam.global_position)
	_head.rotation.z = 0.25
	music.stop()


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() and target != null and (state == State.STALKING or state == State.FROZEN):
		_think(delta)
	_present()


func _think(delta: float) -> void:
	var filmed := is_filmed_by(target)
	state = State.FROZEN if filmed else State.STALKING
	if filmed:
		# Frozen, but not still: the head keeps tilting while you watch.
		_head.rotation.z = move_toward(_head.rotation.z, 0.5, delta * 0.03)
		return
	var mult := 1.0 if target.camera.is_position_in_frustum(global_position + Vector3.UP) else Tuning.ENTITY_UNSEEN_MULT
	_move(speed() * mult * delta, delta)
	_face(target.global_position)
	if _flat(target.global_position - global_position).length() < Tuning.ENTITY_KILL_RANGE:
		state = State.FEEDING
		caught.emit(target)


func _move(dist: float, delta: float) -> void:
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.25
		var goal := level.nearest_walkable(level.cell_of(target.global_position))
		_path = level.path(level.cell_of(global_position), goal)
	while not _path.is_empty() and _flat(level.center(_path[0]) - global_position).length() < 0.05:
		_path.pop_front()
	var dest := target.global_position if _path.is_empty() else level.center(_path[0])
	var to := _flat(dest - global_position)
	var moved := minf(dist, to.length())
	if moved > 0.0001:
		global_position += to.normalized() * moved
	_step_acc += moved
	if _step_acc > 0.8:
		_step_acc = 0.0
		steps.pitch_scale = randf_range(0.85, 1.05)
		steps.play()


func _face(p: Vector3) -> void:
	var to := _flat(p - global_position)
	if to.length() > 0.05:
		look_at(global_position + to, Vector3.UP)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Local presentation: the song stops while it is filmed, and its shadow
## only exists when the local camcorder sees it.
func _present() -> void:
	music.stream_paused = state == State.FROZEN
	music.volume_db = -16.0 if state == State.DORMANT else -6.0 + tapes
	music.pitch_scale = 1.0 - 0.015 * tapes
	var shown := target != null and (target.camcorder.filming or target.camcorder.reveal)
	var cast := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shown else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _parts[0].cast_shadow != cast:
		for part in _parts:
			part.cast_shadow = cast


# --- model (placeholder built from primitives) ---------------------------

func _build_model() -> void:
	var fur := StandardMaterial3D.new()
	fur.albedo_texture = load("res://assets/textures/mascot_fur.png")
	fur.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	fur.roughness = 1.0
	fur.uv1_triplanar = true
	fur.uv1_scale = Vector3(2, 2, 2)
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color(0.75, 0.72, 0.62)
	glove.roughness = 1.0
	var shoe := StandardMaterial3D.new()
	shoe.albedo_color = Color(0.25, 0.08, 0.06)
	var face := StandardMaterial3D.new()
	face.albedo_texture = load("res://assets/textures/mascot_face.png")
	face.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	face.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	face.alpha_scissor_threshold = 0.5
	face.emission_enabled = true
	face.emission_texture = face.albedo_texture
	face.emission_energy_multiplier = 0.3

	var body := CapsuleMesh.new()
	body.radius = 0.34
	body.height = 1.8
	_part(body, fur, self, Vector3(0, 0.92, 0))
	for side: float in [-1.0, 1.0]:
		var arm := CapsuleMesh.new()
		arm.radius = 0.085
		arm.height = 1.4
		var a := _part(arm, fur, self, Vector3(0.43 * side, 1.12, 0))
		a.rotation.z = 0.07 * side
		var hand := SphereMesh.new()
		hand.radius = 0.11
		hand.height = 0.22
		_part(hand, glove, self, Vector3(0.48 * side, 0.43, 0))
		var foot := BoxMesh.new()
		foot.size = Vector3(0.22, 0.12, 0.36)
		_part(foot, shoe, self, Vector3(0.15 * side, 0.06, -0.06))

	_head = Node3D.new()
	_head.position = Vector3(0, 2.04, 0)
	_head.rotation.x = -0.12
	add_child(_head)
	var skull := SphereMesh.new()
	skull.radius = 0.44
	skull.height = 0.86
	_part(skull, fur, _head, Vector3.ZERO)
	for side: float in [-1.0, 1.0]:
		var ear := SphereMesh.new()
		ear.radius = 0.15
		ear.height = 0.3
		_part(ear, fur, _head, Vector3(0.31 * side, 0.33, 0.05))
	var mask := QuadMesh.new()
	mask.size = Vector2(0.62, 0.62)
	var f := _part(mask, face, _head, Vector3(0, -0.03, -0.45))
	f.rotation.y = PI


func _part(mesh: Mesh, material: Material, parent: Node3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.layers = LAYER_MASK
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_parts.append(mi)
	return mi
