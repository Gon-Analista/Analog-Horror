class_name PlayerAvatar
extends Node3D
## The body the other players see: a recovery-crew worker in a work jacket
## (tinted per player), jeans and a knit cap, flashlight in the left hand
## and the camcorder in the right. Procedural animation: walk cycle, the
## head follows where they look, the right arm lifts the camcorder to the
## face when they film (its red light blinks), the left arm aims the light.
## Built from primitives with pixel textures; the rig is plain pivots.

## Your own body's layer (left out of your camera).
const SELF_LAYER := 16  # visual layer 5

var tint := Color(0.85, 0.45, 0.15)
## Hidden while someone watches through this player's eyes (spectating).
var hidden_for_view := false
var _hips: Node3D
var _chest: Node3D
var _head: Node3D
var _arm_r: Node3D
var _arm_l: Node3D
var _fore_r: Node3D
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
	var jacket := GearModels.material("jacket", tint)
	var jeans := GearModels.material("jeans")
	var skin := GearModels.material("skin")
	var knit := GearModels.material("knit", tint.darkened(0.45))
	var boots := GearModels.flat(Color(0.12, 0.09, 0.07))
	var gloves := GearModels.flat(Color(0.18, 0.13, 0.1))

	_hips = _pivot(self, Vector3(0, 0.92, 0))
	_leg_l = _pivot(_hips, Vector3(-0.1, 0, 0))
	_leg_r = _pivot(_hips, Vector3(0.1, 0, 0))
	var shins: Array[Node3D] = []
	for leg in [_leg_l, _leg_r]:
		_part(leg, Vector3(0.15, 0.44, 0.16), jeans, Vector3(0, -0.22, 0))
		var shin := _pivot(leg, Vector3(0, -0.42, 0))
		_part(shin, Vector3(0.14, 0.42, 0.15), jeans, Vector3(0, -0.21, 0))
		_part(shin, Vector3(0.15, 0.1, 0.24), boots, Vector3(0, -0.45, -0.04))
		shins.append(shin)
	_shin_l = shins[0]
	_shin_r = shins[1]
	_part(_hips, Vector3(0.34, 0.14, 0.2), jeans, Vector3(0, 0.02, 0))
	_chest = _pivot(_hips, Vector3(0, 0.08, 0))
	_part(_chest, Vector3(0.42, 0.56, 0.24), jacket, Vector3(0, 0.28, 0))
	_part(_chest, Vector3(0.2, 0.08, 0.2), jacket, Vector3(0, 0.6, 0.02))  # collar

	_head = _pivot(_chest, Vector3(0, 0.62, 0))
	_part(_head, Vector3(0.2, 0.24, 0.22), skin, Vector3(0, 0.13, 0))
	_part(_head, Vector3(0.22, 0.1, 0.24), knit, Vector3(0, 0.27, 0.01))
	for x: float in [-0.05, 0.05]:  # eyes, so you can tell where they look
		_part(_head, Vector3(0.03, 0.02, 0.01), GearModels.flat(Color(0.05, 0.04, 0.04)), Vector3(x, 0.15, -0.111))

	_arm_r = _pivot(_chest, Vector3(0.27, 0.5, 0))
	_part(_arm_r, Vector3(0.12, 0.32, 0.12), jacket, Vector3(0, -0.16, 0))
	_fore_r = _pivot(_arm_r, Vector3(0, -0.32, 0))
	_part(_fore_r, Vector3(0.11, 0.28, 0.11), jacket, Vector3(0, -0.14, 0))
	_part(_fore_r, Vector3(0.09, 0.09, 0.1), gloves, Vector3(0, -0.32, 0))
	_cam = GearModels.camcorder()
	_cam.position = Vector3(0, -0.36, -0.06)
	_fore_r.add_child(_cam)
	_tally = _cam.get_node("Tally")

	_arm_l = _pivot(_chest, Vector3(-0.27, 0.5, 0))
	_part(_arm_l, Vector3(0.12, 0.6, 0.12), jacket, Vector3(0, -0.3, 0))
	_part(_arm_l, Vector3(0.09, 0.09, 0.1), gloves, Vector3(0, -0.62, 0))
	_light = GearModels.flashlight()
	_light.position = Vector3(0, -0.64, -0.02)
	_arm_l.add_child(_light)
	# Only the big parts cast shadows: every caster is re-drawn in each
	# shadow pass (flashlights, nearby lamps), small ones are not worth it.
	for m in GearModels.meshes(self):
		var box := (m as MeshInstance3D).mesh as BoxMesh
		if box == null or box.size.length() < 0.3:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func show_body(on: bool) -> void:
	hidden_for_view = not on


## Your own body: not drawn for you (the hands are), and it casts no
## shadow either: two dozen boxes re-drawn in every shadow pass cost more
## than the shadow is worth.
func set_self_view() -> void:
	for m in GearModels.meshes(self):
		m.layers = SELF_LAYER
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## speed: horizontal m/s; pitch: where the head looks (radians, + up);
## raise: camcorder 0 lowered .. 1 at the eye.
## crouch: 0 standing .. 1 crouched (knees bent, hips low, leaning in).
func animate(delta: float, speed: float, pitch: float, raise: float, filming: bool, crouch := 0.0) -> void:
	_t += delta
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
	_arm_r.rotation.x = lerpf(-swing * 0.8, 1.15 + pitch * 0.6, k)
	_arm_r.rotation.z = lerpf(0.05, -0.45, k)
	_fore_r.rotation.x = lerpf(0.15, 1.2, k)
	# Left arm: always aiming the flashlight roughly where they look.
	_arm_l.rotation.x = 1.2 + pitch * 0.8 + swing * 0.15
	_arm_l.rotation.z = 0.15
	# The gear stays level, pointing where the head points.
	_cam.rotation.x = -(_arm_r.rotation.x + _fore_r.rotation.x) + pitch * 0.7 * k
	_light.rotation.x = -_arm_l.rotation.x + pitch
	_tally.visible = filming and fmod(_t, 1.0) < 0.6


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi
