class_name ViewModel
extends Node3D
## First-person hands: the flashlight in the left hand, the camcorder in the
## right. Raising the camcorder brings it up to the eye (then the view
## becomes the viewfinder). Bob with the steps, sway with the mouse. Only
## the local player has one; it lives on its own visual layer, lit by a
## tiny fill light that touches nothing else.

const LAYER_MASK := 4  # visual layer 3
const SLEEVE_TINT := Color(0.75, 0.75, 0.72)

## Camcorder pose lowered (in the right hand) and at the eye.
## Held low and close to the body, out to the sides: they frame the view
## instead of covering it.
const CAM_DOWN := Vector3(0.27, -0.26, -0.24)
const CAM_UP := Vector3(0.03, -0.03, -0.16)
const CAM_DOWN_ROT := Vector3(0.18, 0.6, -0.15)
const LIGHT_POS := Vector3(-0.26, -0.24, -0.25)

var raise := 0.0
var tint := SLEEVE_TINT
var _right: Node3D
var _left: Node3D
var _cam: Node3D
var _tally: MeshInstance3D
var _sway := Vector2.ZERO
var _bob := 0.0
var _t := 0.0


func _ready() -> void:
	_right = Node3D.new()
	add_child(_right)
	_cam = GearModels.camcorder()
	_right.add_child(_cam)
	_tally = _cam.get_node("Tally")
	_right.add_child(_arm(Vector3(0.0, -0.08, 0.05)))
	_left = Node3D.new()
	add_child(_left)
	_left.add_child(GearModels.flashlight())
	_left.add_child(_arm(Vector3(0.0, -0.035, 0.12)))
	for m in GearModels.meshes(self):
		m.layers = LAYER_MASK
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fill := OmniLight3D.new()
	fill.light_cull_mask = LAYER_MASK
	fill.omni_range = 0.9
	fill.light_energy = 0.12
	fill.light_color = Color(0.9, 0.85, 0.8)
	fill.position = Vector3(0, 0.15, -0.1)
	add_child(fill)


## A gloved hand and a sleeve reaching back towards the shoulder.
func _arm(hand_at: Vector3) -> Node3D:
	var arm := Node3D.new()
	var hand := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.07, 0.05, 0.09)
	hand.mesh = hm
	hand.material_override = GearModels.flat(Color(0.18, 0.13, 0.1))
	hand.position = hand_at
	arm.add_child(hand)
	var sleeve := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.09, 0.09, 0.32)
	sleeve.mesh = sm
	sleeve.material_override = GearModels.material("jacket", tint)
	sleeve.position = hand_at + Vector3(0.01, -0.02, 0.2)
	sleeve.rotation.x = 0.25
	arm.add_child(sleeve)
	return arm


## Called by the player every frame.
func animate(delta: float, p_raise: float, speed: float, look_delta: Vector2, filming: bool) -> void:
	_t += delta
	raise = p_raise
	_sway = _sway.lerp(look_delta * 0.6, minf(1.0, delta * 8.0))
	_sway = _sway.limit_length(0.06)
	if speed > 0.3:
		_bob += delta * speed * 2.6
	var bob := Vector3(sin(_bob) * 0.012, -absf(cos(_bob)) * 0.014, 0.0) * (1.0 - raise)
	var sway := Vector3(-_sway.x, _sway.y, 0.0)
	var k := smoothstep(0.0, 1.0, raise)
	_right.position = CAM_DOWN.lerp(CAM_UP, k) + bob + sway
	_right.rotation = CAM_DOWN_ROT.lerp(Vector3.ZERO, k)
	_left.position = LIGHT_POS + bob * 1.2 + sway + Vector3(-0.05, -0.08, 0.05) * k
	_left.rotation = Vector3(0.06, -0.14, 0.05) + Vector3(0.2, 0.15, 0.0) * k
	# Through the viewfinder you no longer see the camera itself.
	_right.visible = raise < 0.93
	_tally.visible = filming and fmod(_t, 1.0) < 0.6


## Where the beam starts (the flashlight's lamp), in global space.
func light_transform() -> Transform3D:
	return _left.global_transform * Transform3D(Basis(), Vector3(0, 0, -0.12))
