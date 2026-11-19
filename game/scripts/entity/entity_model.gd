class_name EntityModel
extends Node3D
## La Visita in 3D (the game's; the drawings stay for the TV and the end): the
## same creature as the "nueva" drawing, as a stop-motion puppet. A plaster
## mask (the drawing's own, tools/gen_entity_3d.py) on a black, too long,
## too thin body; long hair in black strings; black filaments bristling off
## the body and limbs; arms far too long, hands bigger than its head, long
## fingers. Plain pivots and simple shapes with flat textures (like the
## crew), animated by poses (one per Entity.Pose) that it moves between
## in jerks, a few times a second, never quite still (it "boils" like the
## drawing). The head always turns to whoever looks at it.
## Entity drives it (Entity._present_model); Replay drives a copy.

const FACES := ["smile", "happy", "grin", "beam", "sad", "scream", "open"]
const FACE_SHEET := "res://assets/textures/entity3d_faces.png"
const FACE_NORMAL := "res://assets/textures/entity3d_faces_normal.png"
## The mask's layout (tools/gen_entity_mask.py), in units of its half
## width: the cell spans x -1.15..1.15, y -1.5..2.2 (down); the eyes.
const MASK_HALF := 0.1565
const MASK_X := Vector2(-1.15, 1.15)
const MASK_Y := Vector2(-1.5, 2.2)
const MASK_EYE := Vector2(0.4, -0.3)
## Where the mask sits on the head, and how far its middle stands out.
const MASK_AT := Vector3(0, 0.07, -0.075)
const MASK_BULGE := 0.065
const HAIR := "res://assets/textures/entity3d_hair.png"
const SKIN := "res://assets/textures/entity3d_skin.png"
## The expression of each pose (as in the drawing).
const POSE_FACE := ["smile", "happy", "grin", "beam", "sad", "open", "grin", "smile", "grin", "beam", "scream"]
## How often it moves to its next held pose (stop-motion), and how much it
## shakes between them.
const STEP_FPS := 10.0
const BOIL := 0.06
## Its proportions: hips this high; a long body, a long neck jutting
## forward like a vulture's (not an ostrich on stilts).
const HIPS := 0.94
const TORSO := 0.72
const NECK := 0.5
## Unlisted in a pose: the neck juts forward.
const REST := {"neck": Vector3(-0.45, 0, 0)}

var _rng := RandomNumberGenerator.new()
var _root: Node3D     # the whole body (hips height, lean)
var _spine: Node3D
var _neck: Node3D
var _neck_mesh: MeshInstance3D
var _head: Node3D
var _face_mat: StandardMaterial3D
var _arm: Array[Node3D] = []    # [left, right] shoulders
var _fore: Array[Node3D] = []
var _hand: Array[Node3D] = []
var _fingers: Array = []        # per hand: [finger pivots]
var _leg: Array[Node3D] = []
## A second, thinner pair of arms, lower down the body (it should not have them).
var _arm2: Array[Node3D] = []
var _fore2: Array[Node3D] = []
var _shin: Array[Node3D] = []
var _skin_mat: StandardMaterial3D
var _hair_mat: StandardMaterial3D
var _meshes: Array[GeometryInstance3D] = []
var _hair_cards: Array[Node3D] = []
var _coat: Array[Node3D] = []
var _finger_joints: Array[Node3D] = []
var _head_yaw := 0.0
var _pricks: Array[MeshInstance3D] = []
var _ribs: MeshInstance3D
# What makes it wrong to watch: the head snapping to an angle and holding
# it, the body lurching, a joint bending the wrong way for a frame, the
# fingers twitching one by one, its face changing when it should not.
var _snap := Vector3.ZERO
var _snap_left := 0.0
var _snap_in := 2.0
var _lurch := 0.0
var _wrong := ""
var _finger_twitch := {}
var _mood := ""
var _mood_left := 0.0
var _mood_in := 3.0
var _glance := 0.0
var _head_rot := Vector3.ZERO
var _glance_in := 2.0
var _held := {}       # joint -> rotation being shown (stepped)
var _step_in := 0.0
var _face := -1
var _face_frame := 0
var _t := 0.0
## What it showed last (Replay records it).
var shown_yaw := 0.0


func _ready() -> void:
	_rng.seed = 4242
	# Its black: matte, like soot and tar, no sheen to catch a light.
	_skin_mat = StandardMaterial3D.new()
	_skin_mat.albedo_texture = load(SKIN)
	_skin_mat.albedo_color = Color(0.55, 0.5, 0.5)
	_skin_mat.roughness = 1.0
	_skin_mat.metallic_specular = 0.12
	_skin_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_skin_mat.uv1_triplanar = true
	_skin_mat.uv1_scale = Vector3(3, 3, 3)
	_skin_mat.emission_enabled = true
	_skin_mat.emission = Color.BLACK
	_hair_mat = StandardMaterial3D.new()
	_hair_mat.albedo_texture = load(HAIR)
	_hair_mat.albedo_color = Color(0.5, 0.45, 0.45)
	_hair_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_hair_mat.alpha_scissor_threshold = 0.35
	_hair_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_hair_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_hair_mat.roughness = 0.85
	_hair_mat.metallic_specular = 0.25
	_build()


# --- building ---------------------------------------------------------------------

func _build() -> void:
	_root = _pivot(self, Vector3(0, HIPS, 0))
	# Legs: very long and thin, a knob at the knee.
	for side: float in [-1.0, 1.0]:
		var leg := _pivot(_root, Vector3(0.08 * side, 0, 0))
		_limb(leg, 0.06, 0.035, 0.48)
		_filaments(leg, 9, 0.48)
		var shin := _pivot(leg, Vector3(0, -0.48, 0))
		_knob(shin, 0.04)
		_limb(shin, 0.04, 0.024, 0.46)
		_filaments(shin, 7, 0.46)
		var foot := _part(shin, SphereMesh.new(), Vector3(0.07, 0.05, 0.22), Vector3(0, -0.46, -0.06), _skin_mat)
		foot.rotation.x = 0.1
		_leg.append(leg)
		_shin.append(shin)
	# The body: a narrow, hunched thing under a coat of hanging black strings.
	_spine = _pivot(_root, Vector3.ZERO)
	_ribs = _part(_spine, SphereMesh.new(), Vector3(0.25, 0.86, 0.17), Vector3(0, 0.37, 0.01), _skin_mat)
	_part(_spine, SphereMesh.new(), Vector3(0.24, 0.12, 0.15), Vector3(0, TORSO - 0.05, 0.02), _skin_mat)  # narrow, sloping shoulders
	# The coat: ragged strings, from high in the middle down the sloping
	# shoulders, flaring out a little at the bottom (no square edges).
	for i in 56:
		var a := _rng.randf() * TAU
		var y := _rng.randf_range(0.22, TORSO - 0.04)
		var length := _rng.randf_range(0.45, 1.15)
		var high := clampf((y - 0.22) / (TORSO - 0.26), 0.0, 1.0)
		var reach := 0.12 * (1.0 - high * 0.75)
		var pivot := _pivot(_spine, Vector3(cos(a) * reach, y, sin(a) * 0.08))
		# The higher up, the more it falls outwards over the shoulder (a
		# slope from the neck, not a square top).
		var flare := -signf(cos(a)) * (_rng.randf_range(0.04, 0.15) + high * _rng.randf_range(0.35, 0.6))
		pivot.rotation = Vector3(_rng.randf_range(-0.12, 0.12), -a + PI / 2, flare)
		_card(pivot, _rng.randf_range(0.09, 0.17), length)
		pivot.set_meta("hang", pivot.rotation)
		_coat.append(pivot)
	_filaments(_spine, 14, TORSO, 0.12)
	# Neck: long and thin, jutting forward (it grows much longer in STRETCH).
	_neck = _pivot(_spine, Vector3(0, TORSO, 0))
	_neck_mesh = _limb(_neck, 0.032, 0.02, NECK, true)
	_filaments(_neck, 5, NECK, 0.03)
	_head = _pivot(_neck, Vector3(0, NECK, 0))
	# The back of its skull (under the hair) and the mask in front of it.
	_part(_head, SphereMesh.new(), Vector3(0.25, 0.34, 0.22), Vector3(0, 0.12, 0.04), _skin_mat)
	# The mask: a shell of old plaster, curved, its relief in a normal map
	# (brow, sockets, nose, lips, cracks), holes for the eyes and the mouth.
	var face := MeshInstance3D.new()
	face.mesh = _mask_mesh()
	_face_mat = StandardMaterial3D.new()
	_face_mat.albedo_texture = load(FACE_SHEET)
	_face_mat.normal_enabled = true
	_face_mat.normal_texture = load(FACE_NORMAL)
	_face_mat.normal_scale = 1.3
	_face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_face_mat.alpha_scissor_threshold = 0.5
	_face_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_face_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_face_mat.uv1_scale = Vector3(1.0 / FACES.size(), 0.5, 1)
	_face_mat.roughness = 0.8
	_face_mat.metallic_specular = 0.35
	_face_mat.emission_enabled = true
	_face_mat.emission_texture = _face_mat.albedo_texture
	_face_mat.emission_energy_multiplier = 0.05
	face.material_override = _face_mat
	_head.add_child(face)
	_meshes.append(face)
	# Behind the eye holes, only dark (it looked better without eyes:
	# user 2026-10-27); in the lunge, a pinprick of light deep in each.
	for side: float in [-1.0, 1.0]:
		var at := _mask_point(MASK_EYE.x * side, MASK_EYE.y)
		var prick := MeshInstance3D.new()
		var dot := SphereMesh.new()
		dot.radius = 0.004
		dot.height = 0.008
		prick.mesh = dot
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(1.0, 0.95, 0.85)
		prick.material_override = glow
		prick.position = at + Vector3(0, 0, 0.03)
		prick.visible = false
		_head.add_child(prick)
		_meshes.append(prick)
		_pricks.append(prick)
	_set_face("smile", 0)
	# Hair: long black strings falling from the scalp over its back, its
	# shoulders, and down either side of the mask to its chest.
	for i in 58:
		var front := i >= 46
		# (Never across the mask: behind it, or beside it edge-on.)
		var a := lerpf(-1.75, 1.75, i / 45.0) + _rng.randf_range(-0.05, 0.05) if not front else (-1.0 if i % 2 == 0 else 1.0) * PI / 2
		var length := _rng.randf_range(0.5, 1.1) if not front else _rng.randf_range(0.45, 0.85)
		var at := Vector3(sin(a) * 0.17, 0.25, cos(a) * 0.12 + 0.05)
		if front:
			at = Vector3(signf(a) * _rng.randf_range(0.19, 0.23), 0.2, _rng.randf_range(-0.06, 0.02))
		var pivot := _pivot(_head, at)
		pivot.rotation = Vector3(0.12 * cos(a) + (0.0 if front else 0.1), a, -0.15 * sin(a))
		_card(pivot, _rng.randf_range(0.1, 0.19), length)
		pivot.set_meta("hang", pivot.rotation)
		_hair_cards.append(pivot)
	# Arms: far too long; hands bigger than its head, long jointed fingers.
	for side: float in [-1.0, 1.0]:
		var arm := _pivot(_spine, Vector3(0.13 * side, TORSO - 0.08, 0))
		_limb(arm, 0.04, 0.025, 0.56)
		_filaments(arm, 5, 0.56)
		var fore := _pivot(arm, Vector3(0, -0.56, 0))
		_knob(fore, 0.032)
		_limb(fore, 0.03, 0.02, 0.6)
		_filaments(fore, 4, 0.6)
		var hand := _pivot(fore, Vector3(0, -0.6, 0))
		_part(hand, SphereMesh.new(), Vector3(0.17, 0.2, 0.06), Vector3(0, -0.09, 0), _skin_mat)
		var fingers: Array[Node3D] = []
		for f in 5:
			var thumb := f == 4
			var fx := (-0.06 + f * 0.04) * side if not thumb else 0.07 * -side
			var finger := _pivot(hand, Vector3(fx, -0.17 if not thumb else -0.07, 0))
			finger.rotation.z = (-0.25 + f * 0.17) * side if not thumb else 0.9 * -side
			var parent := finger
			for seg in 3:
				var l := (0.13 - seg * 0.025) * (0.7 if thumb else 1.0)
				var r := 0.016 - seg * 0.004
				_limb(parent, r, r * 0.7, l)
				var next := _pivot(parent, Vector3(0, -l, 0))
				if seg < 2:
					_finger_joints.append(next)
				parent = next
			# A claw at the end.
			var claw := _part(parent, CylinderMesh.new(), Vector3.ONE, Vector3(0, -0.03, 0), _skin_mat)
			(claw.mesh as CylinderMesh).top_radius = 0.008
			(claw.mesh as CylinderMesh).bottom_radius = 0.0
			(claw.mesh as CylinderMesh).height = 0.06
			(claw.mesh as CylinderMesh).radial_segments = 4
			fingers.append(finger)
		_arm.append(arm)
		_fore.append(fore)
		_hand.append(hand)
		_fingers.append(fingers)
	# The second pair: thinner, shorter, from low on its ribs, clutching.
	for side: float in [-1.0, 1.0]:
		var arm := _pivot(_spine, Vector3(0.1 * side, TORSO - 0.3, 0.02))
		_limb(arm, 0.03, 0.02, 0.44)
		_filaments(arm, 3, 0.44)
		var fore := _pivot(arm, Vector3(0, -0.44, 0))
		_knob(fore, 0.025)
		_limb(fore, 0.024, 0.016, 0.48)
		var hand := _pivot(fore, Vector3(0, -0.48, 0))
		_part(hand, SphereMesh.new(), Vector3(0.11, 0.13, 0.04), Vector3(0, -0.06, 0), _skin_mat)
		for f in 4:
			var finger := _pivot(hand, Vector3((-0.04 + f * 0.027) * side, -0.11, 0))
			finger.rotation = Vector3(0.6, 0, (-0.2 + f * 0.13) * side)
			_limb(finger, 0.011, 0.006, 0.17)
		_arm2.append(arm)
		_fore2.append(fore)


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## A limb hanging down from its pivot: thicker at the top, tapering.
## (`up`: from the pivot upwards, for the neck.)
func _limb(parent: Node3D, top: float, bottom: float, length: float, up := false) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = bottom if up else top
	cyl.bottom_radius = top if up else bottom
	cyl.height = length
	cyl.radial_segments = 7
	cyl.rings = 1
	return _part(parent, cyl, Vector3.ONE, Vector3(0, length * (0.5 if up else -0.5), 0), _skin_mat)


func _knob(parent: Node3D, r: float) -> void:
	_part(parent, SphereMesh.new(), Vector3.ONE * r * 2.2, Vector3.ZERO, _skin_mat)


func _part(parent: Node3D, mesh: Mesh, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = 0.5
		(mesh as SphereMesh).height = 1.0
		(mesh as SphereMesh).radial_segments = 10
		(mesh as SphereMesh).rings = 6
		m.scale = size
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	_meshes.append(m)
	return m


## A card of hanging black strings (hair, the coat), from its pivot down.
func _card(pivot: Node3D, width: float, length: float) -> void:
	var card := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, length)
	q.center_offset = Vector3(0, -length * 0.5, 0)
	card.mesh = q
	card.material_override = _hair_mat
	pivot.add_child(card)
	_meshes.append(card)


## Black filaments bristling off a limb (or the body): thin cards at odd angles.
func _filaments(parent: Node3D, count: int, length: float, radius := 0.04) -> void:
	for i in count:
		var card := MeshInstance3D.new()
		var q := QuadMesh.new()
		var l := _rng.randf_range(0.12, 0.3)
		q.size = Vector2(_rng.randf_range(0.05, 0.09), l)
		q.center_offset = Vector3(0, -l * 0.5, 0)
		card.mesh = q
		card.material_override = _hair_mat
		var a := _rng.randf() * TAU
		card.position = Vector3(cos(a) * radius, -_rng.randf() * length if radius < 0.1 else _rng.randf() * length, sin(a) * radius)
		card.rotation = Vector3(_rng.randf_range(-0.9, 0.9), a, _rng.randf_range(-0.9, 0.9) + PI * 0.15)
		parent.add_child(card)
		_meshes.append(card)


func set_layers(layers: int) -> void:
	for m in _meshes:
		m.layers = layers


func set_shadows(on: bool) -> void:
	for m in _meshes:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _set_face(face: String, frame: int) -> void:
	var i := maxi(0, FACES.find(face))
	if i == _face and frame == _face_frame:
		return
	_face = i
	_face_frame = frame
	_face_mat.uv1_offset = Vector3(float(i) / FACES.size(), frame * 0.5, 0)
	# The lunge: a pinprick of light in each hole.
	var face_name: String = FACES[i]
	for d in _pricks:
		d.visible = face_name == "open"


# --- poses ------------------------------------------------------------------------

## Joint rotations (radians) of each pose, and the body: hips height,
## lean, neck length. Unlisted joints are at rest.
static func _pose(p: int, cycle: float) -> Dictionary:
	var s := sin(cycle)
	var c := cos(cycle)
	match p:
		Entity.Pose.REACH:  # one arm out towards you, the fingers spread
			return {"arm1": -Vector3(-1.5, 0, -0.1), "fore1": -Vector3(-0.2, 0, 0), "arm0": -Vector3(0.1, 0, 0.15),
					"head": Vector3(0.1, 0, 0.2), "lean": 0.15, "spread": 1.0}
		Entity.Pose.TILT:  # the head on its side, far too far
			return {"head": Vector3(0, 0, 1.25), "neck": Vector3(0, 0, 0.5), "arm0": -Vector3(0, 0, 0.1), "arm1": -Vector3(0, 0, -0.1), "lean": 0.05}
		Entity.Pose.PEEK:  # bent forward, the hands by its face
			return {"lean": 0.7, "neck": Vector3(-0.5, 0, 0), "head": Vector3(-0.3, 0, 0), "arm0": Vector3(1.0, 0, -0.55), "arm1": Vector3(1.0, 0, 0.55),
					"fore0": Vector3(1.9, 0, 0), "fore1": Vector3(1.9, 0, 0), "hips": 1.0, "leg0": -Vector3(-0.5, 0, 0), "leg1": -Vector3(-0.5, 0, 0),
					"shin0": -Vector3(0.9, 0, 0), "shin1": -Vector3(0.9, 0, 0), "spread": 1.0}
		Entity.Pose.CROUCH:  # squatting, knees up by its head, arms hanging to the floor
			return {"hips": 0.55, "leg0": -Vector3(-2.2, 0, 0.3), "leg1": -Vector3(-2.2, 0, -0.3), "shin0": -Vector3(2.5, 0, 0), "shin1": -Vector3(2.5, 0, 0),
					"lean": 0.5, "arm0": -Vector3(-0.3, 0, 0.2), "arm1": -Vector3(-0.3, 0, -0.2), "head": Vector3(-0.2, 0, 0.2)}
		Entity.Pose.LUNGE:  # at your face: arms flung wide, the head down at you
			return {"hips": 0.9, "lean": 0.75, "neck": Vector3(-0.4, 0, 0), "head": Vector3(0.35, 0, 0),
					"arm0": -Vector3(-2.4, 0, 0.9), "arm1": -Vector3(-2.4, 0, -0.9), "fore0": -Vector3(-0.6, 0, 0), "fore1": -Vector3(-0.6, 0, 0),
					"leg0": -Vector3(-0.6, 0, 0), "leg1": -Vector3(0.3, 0, 0), "shin0": -Vector3(0.8, 0, 0), "shin1": -Vector3(0.4, 0, 0), "spread": 1.0}
		Entity.Pose.CRAWL:  # flat on its belly, dragging itself on its arms
			return {"hips": 0.22, "lean": 1.45, "neck": Vector3(-1.1, 0, 0), "head": Vector3(-0.2, 0, 0),
					"arm0": -Vector3(-2.6 + s * 0.4, 0, 0.3), "arm1": -Vector3(-2.6 - s * 0.4, 0, -0.3), "fore0": -Vector3(-0.8, 0, 0), "fore1": -Vector3(-0.8, 0, 0),
					"leg0": -Vector3(0.1, 0, 0.15), "leg1": -Vector3(0.1, 0, -0.15), "spread": 0.6}
		Entity.Pose.WALK:  # long stiff steps, the arms dangling, swinging late
			return {"leg0": -Vector3(-0.5 * s, 0, 0), "leg1": -Vector3(0.5 * s, 0, 0), "shin0": -Vector3(maxf(0.0, c) * 0.7, 0, 0), "shin1": -Vector3(maxf(0.0, -c) * 0.7, 0, 0),
					"arm0": -Vector3(0.35 * s, 0, 0.08), "arm1": -Vector3(-0.35 * s, 0, -0.08), "lean": 0.12, "hips": 1.0 - absf(c) * 0.03,
					"head": Vector3(0, 0, 0.12 * s)}
		Entity.Pose.GALLOP:  # on all fours, too fast, the back arched
			return {"hips": 0.78, "lean": 1.25, "neck": Vector3(-0.9, 0, 0),
					"arm0": -Vector3(-1.4 + s * 0.8, 0, 0.1), "arm1": -Vector3(-1.4 + s * 0.8, 0, -0.1), "fore0": -Vector3(-0.2, 0, 0), "fore1": -Vector3(-0.2, 0, 0),
					"leg0": -Vector3(-0.9 - s * 0.8, 0, 0), "leg1": -Vector3(-0.9 - s * 0.8, 0, 0), "shin0": -Vector3(1.4, 0, 0), "shin1": -Vector3(1.4, 0, 0)}
		Entity.Pose.STRETCH:  # stock still; only its neck grows, the head comes at you
			return {"neck_len": 3.0, "lean": 0.2, "neck": Vector3(-1.2, 0, 0), "head": Vector3(0.25, 0, 0.1), "arm0": -Vector3(0, 0, 0.05), "arm1": -Vector3(0, 0, -0.05)}
		Entity.Pose.RUN:  # upright, arms out at you, the knees high
			return {"leg0": -Vector3(-1.0 * s, 0, 0), "leg1": -Vector3(1.0 * s, 0, 0), "shin0": -Vector3(maxf(0.0, c) * 1.4, 0, 0), "shin1": -Vector3(maxf(0.0, -c) * 1.4, 0, 0),
					"arm0": -Vector3(-1.4 + s * 0.3, 0, 0.35), "arm1": -Vector3(-1.4 - s * 0.3, 0, -0.35), "fore0": -Vector3(-0.3, 0, 0), "fore1": -Vector3(-0.3, 0, 0),
					"lean": 0.35, "hips": 0.97 - absf(c) * 0.05, "head": Vector3(0.2, 0, 0), "spread": 1.0}
	# STAND: hanging there, arms down to its knees, the head a little on one side.
	return {"head": Vector3(0.05, 0, -0.15), "arm0": -Vector3(0.05, 0, 0.08), "arm1": -Vector3(0.05, 0, -0.08), "lean": 0.08}


## Each frame: the pose to hold (Entity.Pose), how far along a walk or
## gallop it is (`cycle`, metres walked), where it faces (`yaw`), who
## looks at it (`eye`), on the ceiling or not, its tint (how lit it is, the
## burn, the rage) and size; `jerky` when it runs at you (the stride
## jumps); `aware` when it is after them (only then does its head turn to
## whoever looks: otherwise it looks where it goes, and about); `talking`
## while its voice plays (the mask's mouth works).
func drive(delta: float, p: int, cycle: float, yaw: float, eye: Vector3, ceiling: bool, tint: Color, size: float, jerky: bool,
		aware := false, talking := false) -> void:
	_t += delta
	shown_yaw = yaw
	scale = Vector3.ONE * size
	var stride := cycle / (0.5 if p == Entity.Pose.GALLOP else 0.85) * PI
	var want := _pose(p, stride)
	# Stop-motion: it moves to its pose in held steps, a little off each
	# time; now and then it freezes, then jumps on.
	_step_in -= delta
	var step := _step_in <= 0.0
	if step:
		_step_in = 1.0 / STEP_FPS * (_rng.randf_range(0.6, 2.2) if jerky else _rng.randf_range(0.8, 1.3))
		if _rng.randf() < 0.05:
			_step_in += _rng.randf_range(0.25, 0.6)  # a held frame, too long
		_face_frame = (_face_frame + 1) % 2
		# A frame with a joint bent the wrong way.
		_wrong = ["shin0", "shin1", "fore0", "fore1", "neck", "fore2_0", "fore2_1"][_rng.randi() % 7] if _rng.randf() < 0.08 else ""
		for i in 10:
			_finger_twitch[i] = _rng.randf_range(-0.5, 0.6) if _rng.randf() < 0.25 else 0.0
	_twitches(delta)
	_set_face(_face_for(p, aware, talking, eye), _face_frame)
	# Ceiling: pressed flat against it, its face hanging down at you.
	if ceiling:
		want = {"arm0": -Vector3(-1.6, 0, 1.3), "arm1": -Vector3(-1.6, 0, -1.3), "fore0": -Vector3(-1.0, 0, 0), "fore1": -Vector3(-1.0, 0, 0),
				"leg0": -Vector3(0.4, 0, 0.6), "leg1": -Vector3(0.4, 0, -0.6), "shin0": -Vector3(-1.3, 0, 0), "shin1": -Vector3(-1.3, 0, 0),
				"head": Vector3(-0.6, 0, 0), "neck": Vector3(-0.9, 0, 0), "spread": 1.0}
		rotation = Vector3(-PI / 2, yaw, 0.0)
		position = Vector3(0.0, Level.HEIGHT - 0.3, 0.0) - Basis(Vector3.UP, yaw) * Vector3(0, 0, -1.0)
		_root.position.y = 0.0
	else:
		rotation = Vector3(0.0, yaw, _lurch)
		position = Vector3.ZERO
	# The second arms: folded up against it, fingers working, reaching when
	# the others reach (a beat late), twitching on their own.
	for side in 2:
		var main: Vector3 = want.get("arm%d" % side, REST.get("arm%d" % side, Vector3.ZERO))
		var out := -0.45 if side == 0 else 0.45
		want["arm2_%d" % side] = main * 0.6 + Vector3(0.55 + sin(_t * 2.3 + side) * 0.18, 0.0, out)
		want["fore2_%d" % side] = Vector3(1.3 + sin(_t * 3.1 + side * 2.0) * 0.25, 0.0, 0.0)
	var joints := {"leg0": _leg[0], "leg1": _leg[1], "shin0": _shin[0], "shin1": _shin[1], "arm0": _arm[0], "arm1": _arm[1],
			"fore0": _fore[0], "fore1": _fore[1], "neck": _neck, "head": _head,
			"arm2_0": _arm2[0], "arm2_1": _arm2[1], "fore2_0": _fore2[0], "fore2_1": _fore2[1]}
	for k: String in joints:
		var target: Vector3 = want.get(k, REST.get(k, Vector3.ZERO))
		if step:
			target += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * BOIL
			if k == _wrong:
				target = -target * 1.3 + Vector3(0.4 if k.begins_with("shin") else -0.4, 0, 0)
			_held[k] = target
		var held: Vector3 = _held.get(k, target)
		if k == "head":
			# (Kept apart: the look, the glances and the snaps go on top of it
			# each frame, never into it.)
			_head_rot = _head_rot.lerp(held, minf(1.0, delta * (30.0 if jerky else 16.0)))
			_head.rotation = _head_rot
			continue
		var node: Node3D = joints[k]
		node.rotation = node.rotation.lerp(held, minf(1.0, delta * (30.0 if jerky else 16.0)))
	var lean: float = want.get("lean", 0.0)
	_spine.rotation.x = lerpf(_spine.rotation.x, -lean, minf(1.0, delta * 12.0))
	if not ceiling:
		_root.position.y = lerpf(_root.position.y, HIPS * float(want.get("hips", 1.0)), minf(1.0, delta * 12.0))
	# It breathes: the ribs swell, slow and too deep.
	_ribs.scale = Vector3(0.25, 0.86, 0.17) * Vector3(1.0 + sin(_t * 1.6) * 0.05, 1.0, 1.0 + sin(_t * 1.6) * 0.09)
	var neck_len: float = want.get("neck_len", 1.0)
	_neck.scale.y = lerpf(_neck.scale.y, neck_len, minf(1.0, delta * 3.0))
	_head.scale = Vector3.ONE / Vector3(1.0, _neck.scale.y, 1.0)  # (the head keeps its shape)
	# Fingers: curled at rest, spread wide when it reaches; twitching.
	var spread: float = want.get("spread", 0.0)
	for h in 2:
		for i in 5:
			var f: Node3D = _fingers[h][i]
			var tw: float = _finger_twitch.get(h * 5 + i, 0.0)
			f.rotation.x = lerpf(f.rotation.x, lerpf(0.45, -0.15, spread) + tw, minf(1.0, delta * 18.0))
	for j in _finger_joints.size():
		var k: Node3D = _finger_joints[j]
		k.rotation.x = lerpf(k.rotation.x, lerpf(0.55, 0.1, spread) + float(_finger_twitch.get(j % 10, 0.0)) * 0.8, minf(1.0, delta * 18.0))
	# The head: after you, it turns to you in the world (a head on a bent
	# neck still holds itself upright to look at you); otherwise it looks
	# where it goes, and glances about. Either way, now and then it snaps
	# over to an angle and holds it.
	_head_yaw = yaw
	var look_at_you := eye != Vector3.INF and (aware or ceiling)
	var to_eye := eye - _head.global_position if eye != Vector3.INF else Vector3.ZERO
	if look_at_you and to_eye.length() > 0.1 and absf(to_eye.normalized().y) < 0.97:
		var look := Basis.looking_at(to_eye, Vector3.UP)
		var posed := _head.global_basis.orthonormalized()
		var keep := 0.55 if p == Entity.Pose.TILT else 0.15
		var q := Quaternion(look).slerp(Quaternion(posed), keep)
		_head.global_basis = Basis(q).scaled(Vector3.ONE * size)
	elif not ceiling:
		_head.rotate_object_local(Vector3.UP, _glance)
	if _snap_left > 0.0:
		_head.rotate_object_local(Vector3.FORWARD, _snap.z)
		_head.rotate_object_local(Vector3.RIGHT, _snap.x)
	var f := -_head.global_basis.z
	_head_yaw = atan2(-f.x, -f.z)
	# The hair and the coat hang straight down whatever the body does (bent
	# over, on all fours, upside down on the ceiling), and stir.
	var hang := lerpf(1.0, 0.45, clampf((lean - 0.5) / 0.7, 0.0, 1.0))
	for i in _hair_cards.size():
		_hang(_hair_cards[i], _head_yaw, sin(_t * 1.7 + i * 1.3) * 0.05, size, 1.0, 0.6 if ceiling else 0.45)
	for i in _coat.size():
		_hang(_coat[i], yaw, sin(_t * 1.3 + i) * 0.05, size, hang, 0.35)
	# The burn and the rage show as a red glow in the black; otherwise it is
	# just black.
	var red := maxf(0.0, tint.r - maxf(tint.g, tint.b) * 1.2)
	_skin_mat.emission = Color(red, red * 0.12, red * 0.08) * 0.6
	_face_mat.albedo_color = Color(minf(1.0, 0.5 + tint.r * 1.2), minf(1.0, 0.5 + tint.g * 1.2), minf(1.0, 0.5 + tint.b * 1.2))
	_face_mat.emission_energy_multiplier = 0.03 + tint.v * 0.12


## The wrongness between poses: the head snapping to an angle and holding
## it, the whole body lurching sideways, the head glancing about.
func _twitches(delta: float) -> void:
	_snap_in -= delta
	_snap_left -= delta
	if _snap_in <= 0.0:
		_snap_in = _rng.randf_range(1.2, 4.0)
		_snap_left = _rng.randf_range(0.15, 0.9)
		_snap = Vector3(_rng.randf_range(-0.35, 0.35), 0.0, _rng.randf_range(0.6, 1.3) * (-1.0 if _rng.randf() < 0.5 else 1.0))
	_lurch = move_toward(_lurch, 0.0, delta * 1.5)
	if _rng.randf() < delta * 0.25:
		_lurch = _rng.randf_range(-0.18, 0.18)
	_glance_in -= delta
	if _glance_in <= 0.0:
		_glance_in = _rng.randf_range(1.5, 4.5)
		_glance = _rng.randf_range(-1.1, 1.1) if _rng.randf() < 0.6 else 0.0


## Its face: the pose's own; while it talks, the mouth working (open,
## shut); after you and close, the grin splits wide; and now and then,
## for a moment, an expression it should not have.
func _face_for(p: int, aware: bool, talking: bool, eye: Vector3) -> String:
	var face: String = POSE_FACE[clampi(p, 0, POSE_FACE.size() - 1)]
	if face == "open":
		return face
	if talking:
		return "scream" if int(_t * 7.0) % 2 == 0 else face
	if aware and eye != Vector3.INF and eye.distance_to(_head.global_position) < 4.0 and face != "scream":
		return "beam"
	_mood_in -= get_process_delta_time()
	_mood_left -= get_process_delta_time()
	if _mood_in <= 0.0:
		_mood_in = _rng.randf_range(2.0, 6.0)
		_mood_left = _rng.randf_range(0.25, 1.2)
		_mood = ["sad", "grin", "happy", "smile", "beam"][_rng.randi() % 5]
	if _mood_left > 0.0:
		return _mood
	return face


## Moves the whole puppet so its face is at `at` (Vector3.INF: back to its
## feet). For the lunge and the hiding place, where the face must be.
func anchor_face(at: Vector3) -> void:
	if at == Vector3.INF:
		return
	var face := _head.global_position + _head.global_transform.basis.y * 0.07
	position += at - face  # (the entity itself is never turned nor scaled)


## A card of hair hanging from where it grows, straight down in the world
## (its own slight angle kept), whatever the body under it is doing.
func _hang(pivot: Node3D, yaw: float, sway: float, size: float, length: float, weight := 0.55) -> void:
	var r: Vector3 = pivot.get_meta("hang")
	var down := Basis.from_euler(Vector3(r.x + sway, yaw + r.y, r.z))
	var grown := ((pivot.get_parent() as Node3D).global_basis.orthonormalized() * Basis.from_euler(r)).orthonormalized()
	pivot.global_basis = grown.slerp(down, weight).scaled(Vector3(size, size * length, size))


## A point on the mask (in the mask's own units: x across, y down) in the
## head's space, on its curved surface.
func _mask_point(mx: float, my: float) -> Vector3:
	return MASK_AT + Vector3(mx * MASK_HALF, -(my - 0.35) * MASK_HALF, -_bulge(mx, my))


## How far the mask stands out at a point: a dome, a ridge of a nose.
static func _bulge(mx: float, my: float) -> float:
	var r2 := mx * mx + (my / 1.32) * (my / 1.32)
	var dome := sqrt(maxf(0.0, 1.0 - r2)) * MASK_BULGE
	var nose := 0.018 * exp(-((mx / 0.09) ** 2) - (((my - 0.05) / 0.3) ** 2))
	var brow := 0.008 * exp(-((my + 0.55) / 0.12) ** 2) * maxf(0.0, 1.0 - mx * mx)
	return dome + nose + brow


## The mask's shell: a curved grid over its cell, UVs for the sheet.
static func _mask_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 22
	var ny := 34
	var e := 0.01
	for j in ny + 1:
		for i in nx + 1:
			var u := float(i) / nx
			var v := float(j) / ny
			var mx := lerpf(MASK_X.x, MASK_X.y, u)
			var my := lerpf(MASK_Y.x, MASK_Y.y, v)
			var d := _bulge(mx, my)
			var ddx := (_bulge(mx + e, my) - _bulge(mx - e, my)) / (2.0 * e * MASK_HALF)
			var ddy := -(_bulge(mx, my + e) - _bulge(mx, my - e)) / (2.0 * e * MASK_HALF)
			st.set_normal(Vector3(-ddx, -ddy, -1.0).normalized())
			st.set_uv(Vector2(u, v))
			st.add_vertex(MASK_AT + Vector3(mx * MASK_HALF, -(my - 0.35) * MASK_HALF, -d))
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var dd := c + 1
			for k: int in [a, c, b, b, c, dd]:
				st.add_index(k)
	st.generate_tangents()
	return st.commit()
