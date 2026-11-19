class_name PlayerAvatar
extends Node3D
## The body the other players see: one of the four people Canal 9 sent in
## (by player colour): the camera operator (knit cap, stubble), the sound
## technician (ponytail, glasses, headphones round the neck), the reporter
## (side parting, moustache) and the intern (cap on backwards). A crew
## jacket in their colour with a reflective stripe and the CANAL 9 patch, a
## battery pack on the back, jeans, boots; flashlight in the left hand, the
## camcorder in the right. Rounded low-poly parts with pixel textures.
## The face (tools/gen_crew.py) is worried, terrified when the entity is
## near, blinks, and moves its mouth while they talk on the mic.
## Procedural animation: walk cycle, the head follows where they look, the
## right arm lifts the camcorder to the face when they film (its red light
## blinks), the left arm aims the light. The rig is plain pivots.

## Your own body's layer (left out of your camera).
const SELF_LAYER := 16  # visual layer 5
## The local body sits this far behind the eye (metres).
const SELF_BACK := 0.0
## The crew are small, with big heads (Player.EYE_HEIGHT matches).
const SIZE := 0.84

var tint := Color(0.85, 0.45, 0.15)
## Hidden while someone watches through this player's eyes (spectating).
var hidden_for_view := false
## The local player's own body (set_self_view).
var _self := false
## Hidden under a bed or a table: lying face down, the head at the opening.
var lying := false
## ...its feet this far back from the body's position (into the furniture).
var lie_back := 0.7
## Feet to the top of the head, lying (metres).
const LYING_LENGTH := 1.45
## Being taken: the death animation is playing (see play_death).
var dying := false
var _death_t := 0.0
var _death_from := Vector3.ZERO
var _death_to := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _hips: Node3D
var _chest: Node3D
var _head: Node3D
var _face: MeshInstance3D
var _face_mat: StandardMaterial3D
var _arm_r: Node3D
var _arm_l: Node3D
var _fore_r: Node3D
var _fore_l: Node3D
var _leg_r: Node3D
var _leg_l: Node3D
var _shin_r: Node3D
var _shin_l: Node3D
var _tally: MeshInstance3D
var _cam: Node3D
var _light: Node3D
var _phase := 0.0
var _t := 0.0


func _ready() -> void:
	scale = Vector3.ONE * SIZE
	var who := person()
	var jacket := GearModels.material("jacket", tint)
	var jeans := GearModels.material("jeans")
	var skin := GearModels.material("skin")
	var boots := GearModels.flat(Color(0.12, 0.09, 0.07))
	var sole := GearModels.flat(Color(0.05, 0.04, 0.04))
	var gloves := GearModels.flat(Color(0.18, 0.13, 0.1))
	var stripe := GearModels.flat(Color(0.78, 0.8, 0.76), 0.15)
	var gear := GearModels.flat(Color(0.16, 0.16, 0.17))

	_hips = _pivot(self, Vector3(0, 0.92, 0))
	_leg_l = _pivot(_hips, Vector3(-0.1, 0, 0))
	_leg_r = _pivot(_hips, Vector3(0.1, 0, 0))
	var shins: Array[Node3D] = []
	for leg in [_leg_l, _leg_r]:
		_cap(leg, 0.072, 0.48, jeans, Vector3(0, -0.22, 0))
		var shin := _pivot(leg, Vector3(0, -0.42, 0))
		_cap(shin, 0.064, 0.44, jeans, Vector3(0, -0.2, 0))
		_part(shin, Vector3(0.14, 0.1, 0.23), boots, Vector3(0, -0.43, -0.04))
		_part(shin, Vector3(0.15, 0.03, 0.25), sole, Vector3(0, -0.485, -0.04))
		shins.append(shin)
	_shin_l = shins[0]
	_shin_r = shins[1]
	_cap(_hips, 0.13, 0.4, jeans, Vector3(0, 0.03, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.72))
	_chest = _pivot(_hips, Vector3(0, 0.08, 0))
	_cap(_chest, 0.175, 0.6, jacket, Vector3(0, 0.29, 0), Vector3.ZERO, Vector3(1, 1, 0.66))
	for x: float in [-0.17, 0.17]:  # shoulders, so the arms grow out of the body
		_ball(_chest, 0.075, jacket, Vector3(x, 0.5, 0), Vector3(1, 0.9, 1))
	# The reflective stripe round the chest, the collar, the battery pack
	# and the CANAL 9 patch on the back.
	_cyl(_chest, 0.178, 0.035, stripe, Vector3(0, 0.34, 0), Vector3(1, 1, 0.67))
	_cyl(_chest, 0.1, 0.09, GearModels.material("jacket", tint.darkened(0.25)), Vector3(0, 0.6, 0), Vector3(1, 1, 0.9))
	_part(_chest, Vector3(0.2, 0.22, 0.08), gear, Vector3(0, 0.26, 0.15))
	_part(_chest, Vector3(0.06, 0.04, 0.02), GearModels.flat(Color(0.9, 0.6, 0.1), 0.6), Vector3(0.06, 0.33, 0.195))
	var patch := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(0.17, 0.085)
	patch.mesh = pq
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = load("res://assets/textures/crew_patch.png")
	pm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	patch.material_override = pm
	patch.position = Vector3(0, 0.47, 0.132)
	_chest.add_child(patch)
	_cyl(_chest, 0.042, 0.06, skin, Vector3(0, 0.64, 0))  # neck, mostly in the collar

	_head = _pivot(_chest, Vector3(0, 0.64, 0))
	_face = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = HEAD_R
	ball.height = HEAD_R * 2.08
	ball.radial_segments = 16
	ball.rings = 8
	_face.mesh = ball
	_face.position = Vector3(0, HEAD_Y, 0)
	_face_mat = StandardMaterial3D.new()
	_face_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_face_mat.roughness = 0.9
	_face_mat.albedo_texture = _head_texture(who, BLANK)
	_face.material_override = _face_mat
	_head.add_child(_face)
	_build_face(who)
	_headwear(who)

	_arm_r = _pivot(_chest, Vector3(0.21, 0.5, 0))
	_cap(_arm_r, 0.052, 0.34, jacket, Vector3(0, -0.15, 0))
	_fore_r = _pivot(_arm_r, Vector3(0, -0.3, 0))
	_cap(_fore_r, 0.047, 0.3, jacket, Vector3(0, -0.13, 0))
	_ball(_fore_r, 0.048, gloves, Vector3(0, -0.29, 0), Vector3(1, 1.2, 1))
	_cam = GearModels.camcorder()
	_cam.position = Vector3(0, -0.34, -0.06)
	_fore_r.add_child(_cam)
	_tally = _cam.get_node("Tally")

	_arm_l = _pivot(_chest, Vector3(-0.21, 0.5, 0))
	_cap(_arm_l, 0.052, 0.34, jacket, Vector3(0, -0.15, 0))
	_fore_l = _pivot(_arm_l, Vector3(0, -0.3, 0))
	_cap(_fore_l, 0.047, 0.3, jacket, Vector3(0, -0.13, 0))
	_ball(_fore_l, 0.048, gloves, Vector3(0, -0.29, 0), Vector3(1, 1.2, 1))
	_light = GearModels.flashlight()
	_light.position = Vector3(0, -0.32, -0.02)
	_fore_l.add_child(_light)
	# Only the big parts cast shadows: every caster is re-drawn in each
	# shadow pass (flashlights, nearby lamps), small ones are not worth it.
	for m in GearModels.meshes(self):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if m.has_meta("big") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The head's centre above the neck pivot: low, sat on the collar.
const HEAD_Y := 0.16
const HEAD_R := 0.18


## Which of the four this is (by the player's colour).
func person() -> int:
	var best := 0
	var best_d := INF
	for i in Net.COLORS.size():
		var c: Color = Net.COLORS[i]
		var d := Vector3(c.r - tint.r, c.g - tint.g, c.b - tint.b).length()
		if d < best_d:
			best_d = d
			best = i
	return best


## Caps, hair and headphones by person.
func _headwear(who: int) -> void:
	match who:
		0:  # knit cap, rolled up at the edge
			var knit := GearModels.material("knit", tint.darkened(0.45))
			var top := _ball(_head, HEAD_R * 1.05, knit, Vector3(0, HEAD_Y + HEAD_R * 0.4, 0.004), Vector3(1, 0.85, 1))
			(top.mesh as SphereMesh).is_hemisphere = true
			_cyl(_head, HEAD_R * 1.06, 0.05, knit, Vector3(0, HEAD_Y + HEAD_R * 0.44, 0.004))
		1:  # ponytail, headphones round the neck
			var hair := GearModels.flat(Color(0.07, 0.055, 0.05))
			_cap(_head, 0.038, 0.19, hair, Vector3(0, HEAD_Y - 0.03, HEAD_R * 1.02), Vector3(0.5, 0, 0))
			var phones := GearModels.flat(Color(0.1, 0.1, 0.11))
			var band := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.1
			torus.outer_radius = 0.118
			band.mesh = torus
			band.material_override = phones
			band.position = Vector3(0, -0.02, 0.0)
			_head.add_child(band)
			for x: float in [-0.095, 0.095]:
				_cyl(_head, 0.042, 0.032, phones, Vector3(x * 1.05, -0.02, -0.02), Vector3.ONE, Vector3(0, 0, PI / 2))
		2:  # the side parting, a little volume of hair on top
			var hair := GearModels.flat(Color(0.5, 0.34, 0.2))
			var top := _ball(_head, HEAD_R * 1.03, hair, Vector3(0.006, HEAD_Y + HEAD_R * 0.44, 0.008), Vector3(1, 0.62, 1))
			(top.mesh as SphereMesh).is_hemisphere = true
		3:  # a cap on backwards
			var cap := GearModels.flat(tint.darkened(0.15))
			var top := _ball(_head, HEAD_R * 1.05, cap, Vector3(0, HEAD_Y + HEAD_R * 0.4, 0), Vector3(1, 0.78, 1))
			(top.mesh as SphereMesh).is_hemisphere = true
			_part(_head, Vector3(0.18, 0.014, 0.1), cap, Vector3(0, HEAD_Y + HEAD_R * 0.44, HEAD_R * 1.2))


func set_has_light(on: bool) -> void:
	_light.visible = on


func set_has_camera(on: bool) -> void:
	_cam.visible = on


## Where the flashlight points from (for the beam while being taken).
func light_transform() -> Transform3D:
	return _light.global_transform * Transform3D(Basis(), Vector3(0, 0, -0.12))


## Taken by the entity, seen by the others: they are lifted off the floor,
## shaken like a doll by something that (without a camera) is not there,
## then slammed to the floor at its feet. ~2.6 s, then the body is handed
## over to a Corpse lying right there (Run._leave_corpse).
func play_death(toward: Vector3) -> void:
	dying = true
	_death_t = 0.0
	_death_from = global_position
	var to := toward - global_position
	to.y = 0.0
	_death_to = global_position + (to.normalized() if to.length() > 0.1 else -global_transform.basis.z) * 1.4


func _process(delta: float) -> void:
	_update_face(delta)
	if not dying:
		return
	_death_t += delta
	var t := _death_t
	var shake := clampf(t / 0.3, 0.0, 1.0) * (1.0 if t < 1.9 else 0.4)
	# Lifted: up off the floor, the feet dangling.
	var lift := smoothstep(0.0, 1.1, t) * 0.75
	var pos := _death_from + Vector3.UP * lift
	if t > 1.9:  # thrown down at its feet
		var k := smoothstep(1.9, 2.25, t)
		pos = pos.lerp(_death_to + Vector3.UP * 0.1, k)
		rotation.x = lerpf(0.0, -PI / 2, k)
	global_position = pos
	_chest.rotation = Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5)) * shake
	_head.rotation = Vector3(_rng.randf_range(-0.9, 0.5) - 0.6 * shake, _rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.6, 0.6)) * shake
	for arm in [_arm_r, _arm_l]:
		arm.rotation = Vector3(_rng.randf_range(-1.0, 2.6), 0.0, _rng.randf_range(-1.2, 1.2)) * shake
	_fore_l.rotation.x = _rng.randf_range(-0.5, 1.8) * shake
	_fore_r.rotation.x = _rng.randf_range(-0.5, 1.8) * shake
	for leg in [_leg_l, _leg_r]:
		leg.rotation.x = _rng.randf_range(-0.6, 0.9) * shake
	_shin_l.rotation.x = -_rng.randf_range(0.0, 1.4) * shake
	_shin_r.rotation.x = -_rng.randf_range(0.0, 1.4) * shake
	if t > 2.6:
		dying = false
		visible = false


## Limp, for a body on the floor: limbs at odd angles, the head turned.
func pose_dead(rng: RandomNumberGenerator) -> void:
	_fear = 1.0
	_hips.position.y = 0.92
	_chest.rotation = Vector3(rng.randf_range(-0.2, 0.3), 0.0, rng.randf_range(-0.2, 0.2))
	_head.rotation = Vector3(rng.randf_range(-0.6, 0.4), rng.randf_range(-1.1, 1.1), rng.randf_range(-0.5, 0.5))
	_arm_r.rotation = Vector3(rng.randf_range(-0.5, 2.8), 0.0, rng.randf_range(-1.5, 0.3))
	_arm_l.rotation = Vector3(rng.randf_range(-0.5, 2.8), 0.0, rng.randf_range(-0.3, 1.5))
	_fore_r.rotation.x = rng.randf_range(0.0, 1.5)
	_fore_l.rotation.x = rng.randf_range(0.0, 1.5)
	_leg_l.rotation.x = rng.randf_range(-0.3, 0.9)
	_leg_r.rotation.x = rng.randf_range(-0.3, 0.9)
	_shin_l.rotation.x = -rng.randf_range(0.0, 1.2)
	_shin_r.rotation.x = -rng.randf_range(0.0, 1.2)


func show_body(on: bool) -> void:
	hidden_for_view = not on


## Your own body, for you (see inside).
func set_self_view() -> void:
	# Your own body, seen from inside it: the shins and the boots
	# when you look down, and its shadow. Not the head (the eye is in it)
	# nor the arms (the first-person hands are drawn instead): those go on
	# the layer your camera leaves out (the TV's camera still films them).
	# Set back a little, so the chest is in front of the eye, not around it.
	for part: Node3D in [_head, _arm_l, _arm_r]:
		for m in GearModels.meshes(part):
			m.layers = SELF_LAYER
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The chest too (the eye sits right over it: from up here it would only
	# be a big shape in the way of your legs), but its shadow stays.
	for m in GearModels.meshes(_chest):
		if m.layers != SELF_LAYER:
			m.layers = SELF_LAYER
	# And the hips and thighs: from above they were blobs over your feet.
	for node: Node3D in [_hips, _leg_l, _leg_r]:
		for child in node.get_children():
			if child is GeometryInstance3D:
				(child as GeometryInstance3D).layers = SELF_LAYER
	position.z = SELF_BACK
	_self = true


## speed: horizontal m/s; pitch: where the head looks (radians, + up);
## raise: camcorder 0 lowered .. 1 at the eye.
## crouch: 0 standing .. 1 crouched (knees bent, hips low, leaning in).
func animate(delta: float, speed: float, pitch: float, raise: float, filming: bool, crouch := 0.0) -> void:
	_t += delta
	if _self:
		position.z = SELF_BACK  # right under the eye, where it belongs
	elif lying:
		# Flat on the floor, face down, the head towards the opening (the
		# body goes back into the furniture), arms in front.
		rotation.x = -PI / 2
		position = Vector3(0.0, 0.13, lie_back)
		speed = 0.0
		crouch = 0.0
	elif rotation.x != 0.0 and not dying:
		rotation.x = 0.0
		position = Vector3.ZERO
	var walk := clampf(speed / 3.0, 0.0, 1.0)
	_phase += delta * (4.0 + speed * 2.2) * (1.0 if walk > 0.05 else 0.0)
	var swing := sin(_phase) * 0.55 * walk
	var c := smoothstep(0.0, 1.0, crouch)
	_leg_l.rotation.x = swing * (1.0 - c * 0.5) + 1.25 * c
	_leg_r.rotation.x = -swing * (1.0 - c * 0.5) + 1.25 * c
	_shin_l.rotation.x = -1.85 * c - maxf(0.0, -swing) * 0.5
	_shin_r.rotation.x = -1.85 * c - maxf(0.0, swing) * 0.5
	_hips.position.y = lerpf(0.92, 0.48, c) - absf(cos(_phase)) * 0.03 * walk
	_chest.rotation.x = -0.08 * walk - 0.15 * raise - 0.35 * c
	_head.rotation.x = clampf(pitch, -0.9, 0.9) * 0.7
	var k := smoothstep(0.0, 1.0, raise)
	# (A positive X rotation swings an arm forward.)
	# Right arm: swings, or lifts the camcorder up in front of the face.
	_arm_r.rotation.x = lerpf(-swing * 0.8 + 0.1, 1.15 + pitch * 0.6, k)
	_arm_r.rotation.z = lerpf(-0.06, -0.45, k)
	_fore_r.rotation.x = lerpf(0.45, 1.2, k)
	# Left arm: elbow bent, the flashlight held in front, aimed roughly
	# where they look; it sways with the walk.
	_arm_l.rotation.x = 0.35 + pitch * 0.45 + swing * 0.25
	_arm_l.rotation.z = 0.12
	_fore_l.rotation.x = 0.95 + pitch * 0.35
	# The gear stays level, pointing where the head points.
	_cam.rotation.x = -(_arm_r.rotation.x + _fore_r.rotation.x) + pitch * 0.7 * k
	_light.rotation.x = -(_arm_l.rotation.x + _fore_l.rotation.x) + pitch
	_tally.visible = filming and fmod(_t, 1.0) < 0.6
	if lying:
		# The face up to look out, the arms stretched out in front, the
		# chest flat.
		_chest.rotation.x = 0.0
		_head.rotation.x = 1.2 + clampf(pitch, -0.4, 0.4) * 0.5
		for arm: Node3D in [_arm_l, _arm_r]:
			arm.rotation.x = 1.9  # elbows by the head, hands under the chin
		_arm_l.rotation.z = 0.35
		_arm_r.rotation.z = -0.35
		_fore_l.rotation.x = 1.6
		_fore_r.rotation.x = 1.6
		_cam.rotation.x = -(_arm_r.rotation.x + _fore_r.rotation.x) + PI / 2
		_light.rotation.x = -(_arm_l.rotation.x + _fore_l.rotation.x) + PI / 2


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## 0 calm-ish (worried) .. 1 terrified.
func set_fear(f: float) -> void:
	_fear = f


## How loud they are speaking into the mic right now (0..1): the mouth.
func set_voice(level: float) -> void:
	_voice_level = level


# --- the face, in parts --------------------------------------------------------
# Eyes (white, iris, closed lid), brows and mouth are separate little cards
# on the head, so they move: the brows rise and knit with fear, the eyes
# widen and the pupils shrink, they glance about and blink, and the mouth
# opens with how loud they speak into the mic.

const BLANK := 4
## Per person: iris, brow and lip colours (crew_heads.png has the rest).
const LOOKS := [
	[Color(0.27, 0.35, 0.43), Color(0.2, 0.13, 0.09), Color(0.62, 0.42, 0.36)],
	[Color(0.24, 0.16, 0.1), Color(0.08, 0.05, 0.05), Color(0.5, 0.3, 0.24)],
	[Color(0.33, 0.43, 0.27), Color(0.47, 0.31, 0.19), Color(0.66, 0.46, 0.4)],
	[Color(0.19, 0.12, 0.08), Color(0.11, 0.08, 0.06), Color(0.38, 0.22, 0.18)],
]
const SKINS := [Color(0.84, 0.67, 0.55), Color(0.69, 0.49, 0.36), Color(0.89, 0.73, 0.63), Color(0.5, 0.35, 0.25)]

var _fear := 0.0
var _fear_shown := 0.0
var _voice_level := 0.0
var _mouth_open := 0.0
var _blink_in := 3.0
var _blink_left := 0.0
var _look := Vector2.ZERO
var _look_to := Vector2.ZERO
var _look_in := 1.0
var _eyes: Array[MeshInstance3D] = []
var _irises: Array[MeshInstance3D] = []
var _lids: Array[MeshInstance3D] = []
var _brows: Array[MeshInstance3D] = []
var _mouth: MeshInstance3D
var _mouth_line: MeshInstance3D


func _build_face(who: int) -> void:
	var look: Array = LOOKS[who]
	var big := 1.2 if who == 3 else 1.0
	for side: float in [-1.0, 1.0]:
		_eyes.append(_feature(_tex_eye(), 0.27 * big, 0.31 * big))
		_irises.append(_feature(_tex_iris(look[0]), 0.16 * big, 0.16 * big))
		_lids.append(_feature(_tex_lid(SKINS[who]), 0.29 * big, 0.33 * big))
		_brows.append(_feature(_tex_brow(look[1]), 0.3, 0.09 if who != 1 else 0.07))
	_mouth = _feature(_tex_mouth(look[2]), 0.34, 0.24)
	_mouth_line = _feature(_tex_mouth_line(look[2]), 0.32, 0.1)
	if who == 1:  # the sound technician's round glasses, over the eyes
		var glasses := _feature(_tex_glasses(), 0.9, 0.36)
		_place(glasses, 0.0, 0.03, 0.0, 1.035)
	_update_face(0.0)


## A little textured card on the head's surface, facing out.
func _feature(tex: Texture2D, w: float, h: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h) * HEAD_R
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.roughness = 0.9
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(mi)
	return mi


## Put a card at (x, y) on the face (in head radii, from its centre; +x the
## viewer's right), turned `angle` about its own normal, at `lift` radii out.
func _place(mi: MeshInstance3D, x: float, y: float, angle: float, lift := 1.01, scl := Vector2.ONE) -> void:
	var dir := Vector3(-x, y, -sqrt(maxf(0.05, 1.0 - x * x - y * y))).normalized()
	var z := dir
	var xa := Vector3.UP.cross(z).normalized()
	var ya := z.cross(xa)
	var b := Basis(xa, ya, z).rotated(z, angle)
	mi.transform = Transform3D(b.scaled_local(Vector3(scl.x, scl.y, 1.0)), Vector3(0, HEAD_Y, 0) + dir * HEAD_R * lift)


func _update_face(delta: float) -> void:
	if _mouth == null:
		return
	_fear_shown = move_toward(_fear_shown, _fear, delta * 3.0)
	var f := smoothstep(0.0, 1.0, _fear_shown)
	# Glances: now and then the eyes dart somewhere (quicker when afraid).
	_look_in -= delta
	if _look_in <= 0.0:
		_look_in = _rng.randf_range(0.6, 2.5) * (1.0 - 0.6 * f)
		_look_to = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.6, 0.5))
	_look = _look.lerp(_look_to, minf(1.0, delta * 14.0))
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_in = _rng.randf_range(2.0, 5.5)
		_blink_left = 0.12
	_blink_left -= delta
	var closed := _blink_left > 0.0 and f < 0.8
	# The mouth: what they say into the mic opens it; terror leaves it open.
	var want := clampf(_voice_level * 2.2, 0.0, 1.0)
	want = maxf(want, 0.55 * smoothstep(0.6, 1.0, _fear_shown))
	_mouth_open = move_toward(_mouth_open, want, delta * 12.0)
	var wide := 1.0 + 0.25 * f
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ex := side * 0.33
		_place(_eyes[i], ex, 0.04, 0.0, 1.0, Vector2(wide, wide))
		var iris_scale := (1.0 - 0.45 * f)
		_place(_irises[i], ex + _look.x * 0.05, 0.04 + _look.y * 0.04, 0.0, 1.012, Vector2(iris_scale, iris_scale))
		_lids[i].visible = closed
		_eyes[i].visible = not closed
		_irises[i].visible = not closed
		_place(_lids[i], ex, 0.04, 0.0, 1.016, Vector2(wide, wide))
		# Brows: knitted up in the middle (worry), higher with fear.
		var lift := 0.27 + 0.1 * f
		_place(_brows[i], side * 0.32, lift, side * (0.25 + 0.2 * f), 1.02)
	var open := _mouth_open
	_mouth.visible = open > 0.12
	_mouth_line.visible = not _mouth.visible
	_place(_mouth, 0.0, -0.46 - open * 0.05, 0.0, 1.01, Vector2(0.8 + 0.25 * f + 0.15 * open, maxf(0.15, open)))
	_place(_mouth_line, 0.0, -0.45, 0.0, 1.01)


static var _heads := {}
static var _head_sheet: Image
static var _tex := {}


## A person's head without the moving parts (a 128x64 cell of crew_heads.png).
static func _head_texture(who: int, e: int) -> ImageTexture:
	var key := who * 10 + e
	if _heads.has(key):
		return _heads[key]
	if _head_sheet == null:
		_head_sheet = (load("res://assets/textures/crew_heads.png") as Texture2D).get_image()
	var tex := ImageTexture.create_from_image(_head_sheet.get_region(Rect2i(e * 128, who * 64, 128, 64)))
	_heads[key] = tex
	return tex


## Small pixel textures for the face parts, drawn once.
static func _draw_tex(key: String, w: int, h: int, fn: Callable) -> ImageTexture:
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var c: Color = fn.call((x + 0.5) / w * 2.0 - 1.0, (y + 0.5) / h * 2.0 - 1.0)
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


static func _tex_eye() -> ImageTexture:
	return _draw_tex("eye", 12, 14, func(x: float, y: float) -> Color:
		var r := x * x + y * y
		if r > 1.0:
			return Color(0, 0, 0, 0)
		if r > 0.7 or y < -0.75:
			return Color(0.16, 0.1, 0.08)
		return Color(0.95, 0.93, 0.88))


static func _tex_iris(col: Color) -> ImageTexture:
	return _draw_tex("iris%s" % col.to_html(), 8, 8, func(x: float, y: float) -> Color:
		var r := x * x + y * y
		if r > 1.0:
			return Color(0, 0, 0, 0)
		if x > -0.55 and x < -0.1 and y > -0.6 and y < -0.15:
			return Color(1, 1, 1)
		if r < 0.25:
			return Color(0.03, 0.03, 0.03)
		return col if r < 0.75 else col.darkened(0.5))


static func _tex_lid(skin: Color) -> ImageTexture:
	return _draw_tex("lid%s" % skin.to_html(), 12, 14, func(x: float, y: float) -> Color:
		var r := x * x + y * y
		if r > 1.0:
			return Color(0, 0, 0, 0)
		if absf(y - 0.15 - x * x * 0.3) < 0.14:
			return Color(0.16, 0.1, 0.08)  # the closed lashes
		return skin.darkened(0.08))


static func _tex_brow(col: Color) -> ImageTexture:
	return _draw_tex("brow%s" % col.to_html(), 12, 4, func(x: float, y: float) -> Color:
		return col if absf(y) < 0.9 - absf(x) * 0.3 else Color(0, 0, 0, 0))


static func _tex_mouth(lip: Color) -> ImageTexture:
	return _draw_tex("mouth%s" % lip.to_html(), 12, 10, func(x: float, y: float) -> Color:
		var r := x * x + y * y
		if r > 1.0:
			return Color(0, 0, 0, 0)
		if r > 0.72:
			return lip
		if y < -0.45 and absf(x) < 0.6:
			return Color(0.9, 0.87, 0.8)  # upper teeth
		if y > 0.35:
			return Color(0.55, 0.18, 0.2)  # tongue
		return Color(0.16, 0.03, 0.04))


static func _tex_mouth_line(lip: Color) -> ImageTexture:
	return _draw_tex("mline%s" % lip.to_html(), 12, 4, func(x: float, y: float) -> Color:
		# A tight, worried line, the corners down.
		var yy := -0.4 + x * x * 1.3
		return lip.darkened(0.35) if absf(y - yy) < 0.55 else Color(0, 0, 0, 0))


static func _tex_glasses() -> ImageTexture:
	return _draw_tex("glasses", 30, 12, func(x: float, y: float) -> Color:
		var frame := Color(0.12, 0.1, 0.09)
		for cx: float in [-0.5, 0.5]:
			var d := Vector2((x - cx) / 0.42, y / 0.9).length()
			if d > 0.78 and d < 1.0:
				return frame
		if absf(x) < 0.1 and absf(y + 0.1) < 0.12:
			return frame
		return Color(0, 0, 0, 0))


func _cap(parent: Node3D, radius: float, height: float, m: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = maxf(height, radius * 2.0)
	c.radial_segments = 10
	c.rings = 3
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	if radius > 0.06:
		mi.set_meta("big", true)
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, radius: float, height: float, m: Material, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 12
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D, radius: float, m: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := SphereMesh.new()
	b.radius = radius
	b.height = radius * 2.0
	b.radial_segments = 12
	b.rings = 6
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _part(parent: Node3D, size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi
