class_name HuskModel
extends Node3D
## The Husk in 3D: the walking costume of Vecinito, the bear from the
## Saturday show, and nobody inside it. Mustard fur gone grey at the seams,
## a big round head on a body too wide for it, a cream snout with the smile
## sewn shut in black thread, plastic eyes (one hanging loose), a red felt
## bow tie, white four-fingered gloves, padded feet. Between the head and
## the body, where a neck should be, a gap: black, empty. The zip down the
## back is open a hand's width.
## It never moves while it is seen, so it has no animation: one held pose
## (Pose), changed between looks. Each pose is one merged mesh (one draw
## call per material), shared by every copy (MeshMerge cache).
## The Husk's own model goes on NAKED_LAYER (the eye sees it, the
## camcorder's camera leaves it out; it still casts its shadow); the
## costumes in the wardrobe, its doubles, are plain props on layer 1.

enum Pose { SLUMP, STAND, REACH, TILT, STRIDE, CROUCH, CLOSE, LUNGE }

const NAKED_LAYER := 32  # visual layer 6: eyes only, never on tape
## How tall it stands (feet to the top of the ears), for the checks.
const HEIGHT := 1.95

## Joint angles of each pose, in degrees (x pitch forward +, z roll), and
## where the hips are (drop, lean). Unlisted joints stay at rest.
const POSES := {
	Pose.SLUMP: {"drop": 0.05, "lean": 14.0, "head": Vector3(52, 8, 10), "arm_l": Vector3(4, 0, 6), "arm_r": Vector3(2, 0, -5),
			"fore_l": Vector3(-6, 0, 0), "fore_r": Vector3(-4, 0, 0), "knee_l": 10.0, "knee_r": 12.0, "leg_l": Vector3(-4, 0, 0), "leg_r": Vector3(-6, 0, 0)},
	Pose.STAND: {"head": Vector3(-4, 0, 0), "arm_l": Vector3(0, 0, 9), "arm_r": Vector3(0, 0, -9)},
	Pose.REACH: {"lean": 8.0, "head": Vector3(10, -12, -24), "arm_r": Vector3(-82, 6, -4), "fore_r": Vector3(-8, 0, 0),
			"arm_l": Vector3(6, 0, 12), "leg_l": Vector3(-12, 0, 0), "knee_l": 14.0},
	Pose.TILT: {"head": Vector3(6, 10, 74), "arm_l": Vector3(0, 0, 4), "arm_r": Vector3(0, 0, -4), "fore_l": Vector3(-10, 0, 0)},
	Pose.STRIDE: {"lean": 18.0, "head": Vector3(-14, 0, 0), "leg_l": Vector3(-34, 0, 0), "knee_l": 18.0, "leg_r": Vector3(22, 0, 0), "knee_r": 30.0,
			"arm_l": Vector3(30, 0, 10), "arm_r": Vector3(-38, 0, -10), "fore_r": Vector3(-24, 0, 0), "drop": 0.06},
	Pose.CROUCH: {"drop": 0.36, "lean": 42.0, "head": Vector3(-46, 0, 8), "leg_l": Vector3(-70, 0, -8), "knee_l": 110.0,
			"leg_r": Vector3(-64, 0, 8), "knee_r": 104.0, "arm_l": Vector3(-30, 0, 6), "arm_r": Vector3(-26, 0, -6), "fore_l": Vector3(-6, 0, 0)},
	Pose.CLOSE: {"lean": 22.0, "head": Vector3(-6, 0, -16), "arm_l": Vector3(-64, -10, 20), "arm_r": Vector3(-70, 10, -20),
			"fore_l": Vector3(-30, 0, 0), "fore_r": Vector3(-26, 0, 0), "knee_l": 8.0, "knee_r": 8.0},
	Pose.LUNGE: {"lean": 34.0, "drop": 0.1, "head": Vector3(-30, 0, 6), "arm_l": Vector3(-104, -14, 14), "arm_r": Vector3(-100, 14, -14),
			"leg_l": Vector3(-40, 0, 0), "knee_l": 34.0, "leg_r": Vector3(26, 0, 0), "knee_r": 20.0},
}

static var _mats := {}
static var _meshes := {}
## The whole costume is built at full mascot size and shrunk to fit under
## a door (Level.LINTEL).
const SCALE := 0.88

var pose := -1
var _body: MeshInstance3D


## `naked`: the Husk itself (layer NAKED_LAYER); otherwise a prop (a
## costume on the rack, its double).
func setup(p_pose: int, naked: bool) -> void:
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.layers = NAKED_LAYER if naked else 1
	add_child(_body)
	set_pose(p_pose)


func set_pose(p: int) -> void:
	if p == pose:
		return
	pose = p
	_body.mesh = mesh_for(p)


## Shadow only (seen through the camcorder by the one holding it is not
## needed: the layer does that; this is for the replay copy).
func set_shadow_only(on: bool) -> void:
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func mesh_for(p: int) -> ArrayMesh:
	if _meshes.has(p):
		return _meshes[p]
	var root := Node3D.new()
	_build(root, POSES.get(p, {}))
	# Standing on the floor whatever the pose (the lowest point at y = 0).
	var low := INF
	for child in root.get_children():
		var mi := child as MeshInstance3D
		low = minf(low, (mi.transform * mi.mesh.get_aabb()).position.y)
	for child in root.get_children():
		(child as Node3D).position.y -= low
	var merged := MeshMerge.merge_children(root, [], "husk_pose_%d" % p)
	var mesh := merged.mesh as ArrayMesh
	root.free()
	_meshes[p] = mesh
	return mesh


static func _mat(key: String, tint := Color.WHITE, scale := 1.5, rough := 1.0) -> StandardMaterial3D:
	var cache := "%s@%s" % [key, tint.to_html()]
	if _mats.has(cache):
		return _mats[cache]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/%s.png" % key) as Texture2D
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = rough
	_mats[cache] = m
	return m


## A texture laid flat on a face (the snout's stitches, the eyes): no
## triplanar, alpha cut.
static func _decal(key: String) -> StandardMaterial3D:
	var cache := "decal@" + key
	if _mats.has(cache):
		return _mats[cache]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/%s.png" % key) as Texture2D
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.35 if key == "husk_eye" else 1.0
	_mats[cache] = m
	return m


static func _put(root: Node3D, mesh: Mesh, m: Material, xf: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.transform = Transform3D(Basis().scaled(Vector3.ONE * SCALE), Vector3.ZERO) * xf
	root.add_child(mi)


static func _ball(r: float, rings := 6, segs := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.rings = rings
	s.radial_segments = segs
	return s


static func _tube(top: float, bottom: float, h: float, segs := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


static func _boxm(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func _quadm(w: float, h: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	return q


static func _rot(deg: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)))


## Facing -Z, feet at y = 0. Joints are composed by hand (MeshMerge takes
## each part's own transform, so the parts are all children of `root`).
static func _build(root: Node3D, p: Dictionary) -> void:
	var fur := _mat("husk_fur", Color.WHITE, 1.6)
	var fur_dark := _mat("husk_fur", Color(0.62, 0.58, 0.52), 1.6)  # the seams, the soles, gone grey
	var cream := _mat("husk_glove", Color(1.0, 0.93, 0.78), 2.0)
	var glove := _mat("husk_glove", Color.WHITE, 2.0)
	var felt := _mat("husk_felt", Color.WHITE, 3.0)
	var inside := _mat("husk_inside", Color.WHITE, 2.0)
	var plastic := _mat("husk_inside", Color(0.5, 0.45, 0.4), 4.0, 0.3)
	var zip := _mat("metal", Color(0.7, 0.68, 0.6), 4.0, 0.5)
	var drop: float = p.get("drop", 0.0)
	var lean: float = p.get("lean", 0.0)
	var hips := Transform3D(_rot(Vector3(-lean, 0, 0)), Vector3(0, 0.82 - drop, 0))  # forward is -Z: lean pitches -x
	# --- legs: thigh, knee, shin, a padded foot ---
	for side: int in [-1, 1]:
		var name := "l" if side < 0 else "r"
		var leg: Vector3 = p.get("leg_" + name, Vector3.ZERO)
		var knee: float = p.get("knee_" + name, 0.0)
		# The legs stay under the hips (the lean is the body's): undo it.
		var hip := Transform3D(_rot(Vector3(-leg.x, leg.y, leg.z)), Vector3(side * 0.17, 0.82 - drop, 0))
		_put(root, _tube(0.14, 0.12, 0.38), fur, hip * Transform3D(Basis(), Vector3(0, -0.19, 0)))
		var kn := hip * Transform3D(_rot(Vector3(-knee, 0, 0)), Vector3(0, -0.38, 0))
		_put(root, _ball(0.125), fur_dark, kn)
		_put(root, _tube(0.12, 0.13, 0.34), fur, kn * Transform3D(Basis(), Vector3(0, -0.17, 0)))
		var ankle := kn * Transform3D(_rot(Vector3(knee + leg.x, 0, 0)), Vector3(0, -0.34, 0))
		_put(root, _boxm(Vector3(0.26, 0.15, 0.38)), fur, ankle * Transform3D(Basis(), Vector3(0, 0.0, -0.07)))
		_put(root, _boxm(Vector3(0.27, 0.04, 0.39)), fur_dark, ankle * Transform3D(Basis(), Vector3(0, -0.075, -0.07)))  # the sole
		for t in 3:  # the toes, sewn lines
			_put(root, _boxm(Vector3(0.015, 0.1, 0.06)), fur_dark, ankle * Transform3D(Basis(), Vector3((t - 1) * 0.07, 0.0, -0.255)))
	# --- the body: a barrel of fur, a cream belly, the zip down the back ---
	var spine := hips
	_put(root, _ball(0.5, 8, 12), fur, spine * Transform3D(Basis().scaled(Vector3(0.68, 0.82, 0.58)), Vector3(0, 0.3, 0)))
	_put(root, _ball(0.5, 6, 10), cream, spine * Transform3D(Basis().scaled(Vector3(0.48, 0.58, 0.2)), Vector3(0, 0.24, -0.2)))
	_put(root, _boxm(Vector3(0.02, 0.56, 0.02)), zip, spine * Transform3D(_rot(Vector3(-8, 0, 0)), Vector3(-0.045, 0.36, 0.285)))
	_put(root, _boxm(Vector3(0.07, 0.5, 0.02)), inside, spine * Transform3D(_rot(Vector3(-8, 0, 0)), Vector3(0, 0.38, 0.28)))  # open: nothing in there
	_put(root, _boxm(Vector3(0.02, 0.56, 0.02)), zip, spine * Transform3D(_rot(Vector3(-8, 0, 0)), Vector3(0.045, 0.36, 0.285)))
	# --- arms: shoulder, elbow, glove ---
	for side: int in [-1, 1]:
		var name := "l" if side < 0 else "r"
		var arm: Vector3 = p.get("arm_" + name, Vector3.ZERO)
		var fore: Vector3 = p.get("fore_" + name, Vector3.ZERO)
		var sh := spine * Transform3D(_rot(Vector3(-arm.x, arm.y, -arm.z + side * 4)), Vector3(side * 0.33, 0.56, 0))
		_put(root, _ball(0.115), fur, sh)
		_put(root, _tube(0.1, 0.095, 0.36), fur, sh * Transform3D(Basis(), Vector3(0, -0.18, 0)))
		var el := sh * Transform3D(_rot(Vector3(-fore.x, fore.y, fore.z)), Vector3(0, -0.36, 0))
		_put(root, _tube(0.095, 0.085, 0.32), fur, el * Transform3D(Basis(), Vector3(0, -0.16, 0)))
		_put(root, _tube(0.1, 0.1, 0.05), glove, el * Transform3D(Basis(), Vector3(0, -0.32, 0)))  # the cuff
		var wrist := el * Transform3D(Basis(), Vector3(0, -0.38, 0))
		_put(root, _boxm(Vector3(0.15, 0.13, 0.07)), glove, wrist)  # the palm, flat to the leg
		for f in 3:  # three fat fingers and a thumb, cartoon gloves
			var fx := (f - 1) * 0.045
			_put(root, _tube(0.022, 0.024, 0.11, 6), glove, wrist * Transform3D(_rot(Vector3(-8 * f, 0, 0)), Vector3(fx, -0.11, 0)))
		_put(root, _tube(0.022, 0.024, 0.08, 6), glove, wrist * Transform3D(_rot(Vector3(0, 0, side * 50)), Vector3(-side * 0.08, -0.01, -0.02)))
	# --- the gap where a neck should be: black, empty ---
	_put(root, _tube(0.14, 0.17, 0.14), inside, spine * Transform3D(Basis(), Vector3(0, 0.73, 0)))
	# The bow tie, red felt.
	for side: int in [-1, 1]:
		_put(root, _boxm(Vector3(0.11, 0.08, 0.04)), felt, spine * Transform3D(_rot(Vector3(0, 0, side * 12)), Vector3(side * 0.065, 0.64, -0.17)))
	_put(root, _boxm(Vector3(0.04, 0.05, 0.05)), felt, spine * Transform3D(Basis(), Vector3(0, 0.64, -0.18)))
	# --- the head, sat on nothing, a little askew ---
	var hd: Vector3 = p.get("head", Vector3.ZERO)
	var head := spine * Transform3D(_rot(Vector3(-hd.x, hd.y, hd.z + 3)), Vector3(0.015, 0.8, 0))
	_put(root, _ball(0.5, 8, 12), fur, head * Transform3D(Basis().scaled(Vector3(0.64, 0.58, 0.58)), Vector3(0, 0.27, 0)))
	_put(root, _tube(0.15, 0.18, 0.06), fur_dark, head * Transform3D(Basis(), Vector3(0, 0.03, 0)))  # the rim, worn through
	# The snout, the stitched smile, the nose.
	_put(root, _tube(0.5, 0.5, 0.14, 12), cream, head * Transform3D(_rot(Vector3(90, 0, 0)) * Basis.from_scale(Vector3(0.32, 1, 0.2)), Vector3(0, 0.16, -0.26)))
	_put(root, _quadm(0.24, 0.12), _decal("husk_muzzle"), head * Transform3D(_rot(Vector3(0, 180, 0)), Vector3(0, 0.15, -0.332)))
	_put(root, _ball(0.045, 4, 8), plastic, head * Transform3D(Basis().scaled(Vector3(1.3, 0.9, 1)), Vector3(0, 0.215, -0.34)))
	# The eyes: plastic domes; the left one hangs from a thread, turned.
	for side: int in [-1, 1]:
		var loose := side < 0
		var eye_at := Vector3(side * 0.12, 0.36 if not loose else 0.31, -0.25 if not loose else -0.27)
		var eye_rot := Vector3(0, 180, 0) if not loose else Vector3(-28, 200, 34)
		var e := head * Transform3D(_rot(eye_rot), eye_at)
		_put(root, _ball(0.07, 4, 8), cream, e * Transform3D(Basis().scaled(Vector3(1, 1, 0.55)), Vector3.ZERO))
		_put(root, _quadm(0.12, 0.12), _decal("husk_eye"), e * Transform3D(Basis(), Vector3(0, 0, 0.04)))
	_put(root, _boxm(Vector3(0.006, 0.05, 0.006)), inside, head * Transform3D(_rot(Vector3(0, 0, 20)), Vector3(-0.115, 0.345, -0.26)))  # the thread
	# The ears: round, one bent over at the top.
	for side: int in [-1, 1]:
		var bent := side > 0
		var ear := head * Transform3D(_rot(Vector3(90, 0, side * (18 if not bent else 62))), Vector3(side * 0.22, 0.5 if not bent else 0.47, 0.02))
		_put(root, _tube(0.1, 0.1, 0.06, 10), fur, ear)
		_put(root, _tube(0.065, 0.065, 0.062, 10), cream, ear * Transform3D(Basis(), Vector3(0, -0.004, 0)))
