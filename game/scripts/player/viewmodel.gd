class_name ViewModel
extends Node3D
## First-person hands, holding whatever the inventory puts in them (the
## flashlight in the left and the camcorder in the right at first; either
## can be in either hand, or a hand can be empty). Raising the camcorder
## brings it up to the eye from whichever hand holds it (then the view
## becomes the viewfinder). Bob with the steps, sway with the mouse. Quick
## gestures that never stop you: reaching down for something on the floor,
## pocketing a tape, sliding a battery into the camcorder. Only the local
## player has one; it lives on its own visual layer, lit by a tiny fill
## light that touches nothing else.

const LAYER_MASK := 4  # visual layer 3
const SLEEVE_TINT := Color(0.75, 0.75, 0.72)

## Poses in the RIGHT hand (the left one is the mirror image): position,
## rotation and where the glove grips it. Held low and close to the body,
## out to the sides: they frame the view instead of covering it.
const POSES := {
	"camcorder": [Vector3(0.27, -0.26, -0.24), Vector3(0.18, 0.6, -0.15), Vector3(0.0, -0.08, 0.05)],
	"flashlight": [Vector3(0.26, -0.24, -0.25), Vector3(0.06, 0.14, -0.05), Vector3(0.0, -0.035, 0.12)],
}
const CAM_UP := Vector3(0.03, -0.03, -0.16)
const GRAB_TIME := 0.34
const STOW_TIME := 0.2
const INSERT_TIME := 0.62

var raise := 0.0
var tint := SLEEVE_TINT
## side -> {"node", "arm", "glove", "models": {item: Node3D}, "item", "carry"}
var _hands := {}
var _sway := Vector2.ZERO
var _bob := 0.0
var _t := 0.0
## The current gesture: "" / "grab" / "stow" / "insert", how far, which hand, what.
var _act := ""
var _act_t := 0.0
var _act_side := "right"
var _act_kind := ""


func _ready() -> void:
	for side: String in Inventory.HANDS:
		var node := Node3D.new()
		add_child(node)
		var arm := _arm()
		node.add_child(arm)
		var models := {"camcorder": GearModels.camcorder(), "flashlight": GearModels.flashlight()}
		for item: String in models:
			node.add_child(models[item])
		var carry := Node3D.new()  # what the hand brings up from the floor
		carry.scale = Vector3.ONE * 0.75
		carry.position = Vector3(0.0, -0.03, -0.04)
		node.add_child(carry)
		carry.add_child(GearModels.battery())
		carry.add_child(GearModels.tape())
		_hands[side] = {"node": node, "arm": arm, "models": models, "item": "", "carry": carry}
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
	set_hands("flashlight", "camcorder")


## A gloved hand and a sleeve reaching back towards the shoulder.
func _arm() -> Node3D:
	var arm := Node3D.new()
	var hand := MeshInstance3D.new()
	hand.name = "Glove"
	var hm := BoxMesh.new()
	hm.size = Vector3(0.07, 0.05, 0.09)
	hand.mesh = hm
	hand.material_override = GearModels.flat(Color(0.18, 0.13, 0.1))
	arm.add_child(hand)
	var sleeve := MeshInstance3D.new()
	sleeve.name = "Sleeve"
	var sm := BoxMesh.new()
	sm.size = Vector3(0.09, 0.09, 0.32)
	sleeve.mesh = sm
	sleeve.material_override = GearModels.material("jacket", tint)
	sleeve.rotation.x = 0.25
	arm.add_child(sleeve)
	return arm


## What each hand holds (from the inventory, every frame).
func set_hands(left: String, right: String) -> void:
	for side: String in Inventory.HANDS:
		var item := left if side == "left" else right
		var h: Dictionary = _hands[side]
		if h.item == item:
			continue
		h.item = item
		for key: String in h.models:
			(h.models[key] as Node3D).visible = key == item
		# The glove where it grips this item (an empty hand rests low, open).
		var grip: Vector3 = POSES[item][2] if POSES.has(item) else Vector3(0.0, -0.05, 0.08)
		var arm: Node3D = h.arm
		arm.get_node("Glove").position = grip
		arm.get_node("Sleeve").position = grip + Vector3(0.01, -0.02, 0.2)


## Reaching down for something (Run, when a pickup is ours): "tape",
## "battery", "camcorder"... Quick, and it never stops you moving.
func play_grab(kind: String) -> void:
	_act = "grab"
	_act_t = 0.0
	_act_kind = kind
	_act_side = ""  # chosen on the next frame, with the hands as they are then
	Sfx.play(self, "grab", -8.0, randf_range(0.95, 1.08))


## The hand to grab with: an empty one, else the one without the camcorder.
func _free_side() -> String:
	for side: String in ["right", "left"]:
		if _hands[side].item == "":
			return side
	return "left" if _hands["right"].item == "camcorder" else "right"


## How far the view dips while reaching down (Player adds it to the eye).
func dip() -> float:
	return 0.05 * sin(PI * clampf(_act_t / GRAB_TIME, 0.0, 1.0)) if _act == "grab" else 0.0


func _cam_side() -> String:
	for side: String in Inventory.HANDS:
		if _hands[side].item == "camcorder":
			return side
	return ""


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
	_advance(delta)
	for side: String in Inventory.HANDS:
		var h: Dictionary = _hands[side]
		var node: Node3D = h.node
		var sgn := 1.0 if side == "right" else -1.0
		var item: String = h.item
		var pose: Array = POSES.get(item, [Vector3(0.24, -0.34, -0.22), Vector3(0.1, 0.3, 0.0), Vector3.ZERO])
		var pos: Vector3 = _mirror(pose[0], sgn)
		var rot: Vector3 = _mirror_rot(pose[1], sgn)
		if item == "camcorder":
			pos = pos.lerp(_mirror(CAM_UP, sgn), k)
			rot = rot.lerp(Vector3.ZERO, k)
		else:  # out of the way of the viewfinder
			pos += Vector3(0.05 * sgn, -0.08, 0.05) * k
			rot += Vector3(0.2, -0.15 * sgn, 0.0) * k
		pos += bob * (1.0 if side == "right" else 1.2) + sway
		var gesture := _gesture(side, sgn)
		node.position = pos + gesture[0]
		node.rotation = rot + gesture[1]
		# An empty hand is only seen while it does something.
		node.visible = (item != "" or (_act != "" and side == _act_side)) and not (item == "camcorder" and raise >= 0.93)
		(h.arm as Node3D).visible = node.visible
	for side: String in Inventory.HANDS:
		var tally := (_hands[side].models["camcorder"] as Node3D).get_node("Tally") as Node3D
		tally.visible = filming and fmod(_t, 1.0) < 0.6


func _advance(delta: float) -> void:
	if _act == "":
		return
	if _act_side == "":
		_act_side = _free_side()
		var hand: Node3D = _hands[_act_side].carry
		hand.get_child(0).visible = _act_kind == "battery"
		hand.get_child(1).visible = _act_kind == "tape"
		hand.visible = false
	_act_t += delta
	var carry: Node3D = _hands[_act_side].carry
	match _act:
		"grab":
			# The thing appears in the hand at the bottom of the reach.
			carry.visible = _act_t > GRAB_TIME * 0.45 and _act_kind in ["battery", "tape"]
			if _act_t >= GRAB_TIME:
				_act_t = 0.0
				if _act_kind == "battery" and _cam_side() != "" and raise < 0.1:
					_act = "insert"
					if _act_side == _cam_side():  # the battery goes in with the other hand
						carry.visible = false
						_act_side = "left" if _act_side == "right" else "right"
						var other: Node3D = _hands[_act_side].carry
						other.get_child(0).visible = true
						other.get_child(1).visible = false
					Sfx.play(self, "battery_insert", -6.0)
				elif _act_kind == "tape":
					_act = "stow"
					Sfx.play(self, "tape_pocket", -8.0)
				else:
					if _act_kind == "battery":
						Sfx.play(self, "battery_insert", -6.0)
					_end_act()
		"stow":
			if _act_t >= STOW_TIME:
				_end_act()
		"insert":
			(_hands[_act_side].carry as Node3D).visible = _act_t < INSERT_TIME * 0.45
			if _act_t >= INSERT_TIME or raise > 0.1:
				_end_act()


func _end_act() -> void:
	_act = ""
	_act_t = 0.0
	for side: String in Inventory.HANDS:
		(_hands[side].carry as Node3D).visible = false


## Extra offset (position, rotation) of a hand for the current gesture.
func _gesture(side: String, sgn: float) -> Array:
	var none := [Vector3.ZERO, Vector3.ZERO]
	match _act:
		"grab":
			if side != _act_side:
				return none
			var c := sin(PI * clampf(_act_t / GRAB_TIME, 0.0, 1.0))
			# Forward and towards the middle, the hand turned down to the floor.
			return [Vector3(-0.13 * sgn, -0.07, -0.12) * c, Vector3(-0.9, 0.25 * sgn, 0.0) * c]
		"stow":
			if side != _act_side:
				return none
			var c := clampf(_act_t / STOW_TIME, 0.0, 1.0)
			return [Vector3(0.05 * sgn, -0.25, 0.1) * sin(PI * c), Vector3(0.5, 0.0, 0.0) * sin(PI * c)]
		"insert":
			var c := sin(PI * clampf(_act_t / INSERT_TIME, 0.0, 1.0))
			if side == _cam_side():
				# The camcorder comes to the middle, turned to show its side.
				return [Vector3(-0.17 * sgn, 0.06, -0.04) * c, Vector3(0.1, -0.9 * sgn, 0.25 * sgn) * c]
			if side == _act_side:
				# The battery goes in at its back.
				return [Vector3(-0.15 * sgn, 0.08, -0.02) * c, Vector3(-0.2, 0.4 * sgn, 0.0) * c]
	return none


func _mirror(v: Vector3, sgn: float) -> Vector3:
	return Vector3(v.x * sgn, v.y, v.z)


func _mirror_rot(r: Vector3, sgn: float) -> Vector3:
	return Vector3(r.x, r.y * sgn, r.z * sgn)


## Where the beam starts (the flashlight's lamp), in global space; from the
## middle of the view if no hand holds it.
func light_transform() -> Transform3D:
	for side: String in Inventory.HANDS:
		if _hands[side].item == "flashlight":
			return (_hands[side].node as Node3D).global_transform * Transform3D(Basis(), Vector3(0, 0, -0.12))
	return global_transform * Transform3D(Basis(), Vector3(-0.2, -0.2, -0.3))
