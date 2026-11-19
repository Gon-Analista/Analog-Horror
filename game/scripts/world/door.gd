class_name Door
extends Area3D
## A door in a doorway (a "D" cell of the house), hinged at one post of the
## frame on one side; it swings 90 degrees into the passage. E opens or
## closes it (Run asks the host). Over some there is a transom window with
## its glass broken (Level builds it): the entity does not open those doors,
## it goes through the window, along the ceiling, and leaves them shut.
## No abusing it: it cannot be worked while it swings or right after
## (COOLDOWN), and it will not close on anyone standing in it or with the
## entity close by (it holds it). The entity opens a closed door in its way
## (slowly, creaking). Closed, the panel blocks the way, sight, the voice
## and the flash (it is on the world layer).
## The area itself is what the player's ray finds (prompt()).

const SWING_TIME := 0.5
const ENTITY_SWING_TIME := 1.1
const COOLDOWN := 0.9
const WIDTH := 0.9
const HEIGHT := 2.04
const THICK := 0.045

var cell := Vector3i.ZERO
## The passage runs along `axis` (x or z); the panel sits at the face on
## `face` (+1/-1 along it) and is hinged on `hinge` (+1/-1 across it).
var axis := Vector2i(1, 0)
var face := 1
var hinge := 1
## A broken window over it: the entity's way through when it is shut.
var transom := false
var is_open := false
## 0 closed .. 1 open (animated on every machine).
var amount := 0.0
var _swing := SWING_TIME
var _cool := 0.0
var _pivot: Node3D
var _open_angle := 0.0
## Which way it opens: into the passage (-1) or into the room on its side (+1),
## away from whoever opens it.
var swing := -1
var _angle_in := 0.0
var _angle_out := 0.0
## Room to open into the room: the floor beside the doorway on the hinge
## side is clear (else it always opens into the passage, never blocking).
var _can_open_out := false
var _leaf_shape: CollisionShape3D
var _audio: AudioStreamPlayer3D
static var _mats := {}


func setup(p_cell: Vector3i, p_axis: Vector2i, p_face: int, p_hinge: int, p_transom: bool, start_open: bool) -> void:
	cell = p_cell
	axis = p_axis
	face = p_face
	hinge = p_hinge
	transom = p_transom
	is_open = start_open
	amount = 1.0 if start_open else 0.0


func _ready() -> void:
	add_to_group("doors")
	collision_layer = Tuning.LAYER_INTERACT
	collision_mask = 0
	monitoring = false
	var level := get_parent() as Level
	var n := Vector3(axis.x, 0, axis.y) * face
	var across := Vector3(-axis.y, 0, axis.x)
	position = level.center(cell)
	if is_open:
		swing = -1
	# The interact box: the whole doorway.
	# The interact box: a slab on the leaf's side of the doorway (not the
	# whole cell: it got in the way of looking at things past it).
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, HEIGHT, 0.3) if axis.y != 0 else Vector3(0.3, HEIGHT, 0.9)
	shape.shape = box
	shape.position = Vector3.UP * HEIGHT * 0.5 + n * 0.32
	add_child(shape)
	# The pivot at the hinge, just inside the frame on the `face` side.
	_pivot = Node3D.new()
	_pivot.position = n * (Level.CELL * 0.5 - 0.07) + across * hinge * (WIDTH * 0.5 + 0.01)
	add_child(_pivot)
	var closed_dir := -across * hinge      # from the hinge to the latch, closed
	_angle_in = closed_dir.signed_angle_to(-n, Vector3.UP)   # open into the passage
	_angle_out = closed_dir.signed_angle_to(n, Vector3.UP)   # ...or into the room
	_open_angle = _angle_in
	var front := cell + Vector3i(axis.x, 0, axis.y) * face
	var side := Vector3i(-axis.y, 0, axis.x) * hinge
	var out := Vector3i(axis.x, 0, axis.y) * face
	_can_open_out = true
	for c: Vector3i in [front, front + side, front + out, front + out + side]:
		if not level.is_walkable(c) or level.char_at(c) in ["D", "U", "S"]:
			_can_open_out = false
	var h := HEIGHT - (Level.LINTEL - Level.TRANSOM_LINTEL if transom else 0.0)
	var body := AnimatableBody3D.new()
	body.collision_layer = Tuning.LAYER_WORLD
	body.collision_mask = 0
	body.sync_to_physics = false  # (it follows the pivot at once; true left it behind)
	_pivot.add_child(body)
	var bshape := CollisionShape3D.new()
	var bbox := BoxShape3D.new()
	bbox.size = _sized(closed_dir, WIDTH, THICK, h)
	bshape.shape = bbox
	bshape.position = closed_dir * WIDTH * 0.5 + Vector3.UP * h * 0.5
	body.add_child(bshape)
	_leaf_shape = bshape
	_build_panel(level, body, closed_dir, n, h)
	_audio = AudioStreamPlayer3D.new()
	_audio.bus = "Effects"
	_audio.unit_size = 3.0
	_audio.position = Vector3.UP * 1.2
	add_child(_audio)
	_apply()


## The leaf: a frame of rails and stiles round two sunk panels, brass
## knobs on both sides.
func _build_panel(level: Level, body: Node3D, along: Vector3, n: Vector3, h: float) -> void:
	var mid := along * WIDTH * 0.5
	var out := n
	_part(level, body, "wood_dark", mid + Vector3.UP * h * 0.5, _sized(along, WIDTH, THICK, h))
	var panels: Array[Vector2] = [Vector2(0.12, 0.95), Vector2(1.08, h - 0.12)]
	for side: float in [1.0, -1.0]:
		for pr in panels:
			var c := mid + Vector3.UP * (pr.x + pr.y) * 0.5 + out * side * (THICK * 0.5 + 0.004)
			_part(level, body, "wood_trim", c, _sized(along, WIDTH - 0.2, 0.008, pr.y - pr.x))
		var knob := along * (WIDTH - 0.08) + Vector3.UP * 0.95 + out * side * (THICK * 0.5 + 0.03)
		_part(level, body, "brass", knob, Vector3(0.05, 0.05, 0.05))
	# One mesh per leaf (three materials), shared by the leaves of the same
	# size and orientation.
	MeshMerge.merge_children(body, [], "door %s %s %.2f" % [along.round(), out.round(), h], "Leaf")


func _part(level: Level, parent: Node3D, key: String, at: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	if not _mats.has(key):  # the house's material, mapped in world space (it moves)
		var m := level.mat(key).duplicate() as StandardMaterial3D
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		_mats[key] = m
	mi.material_override = _mats[key]
	mi.position = at
	parent.add_child(mi)


func _sized(along: Vector3, l: float, d: float, h: float) -> Vector3:
	return Vector3(l, h, d) if absf(along.x) > 0.5 else Vector3(d, h, l)


func prompt() -> String:
	if is_open:
		return tr("[E] Cerrar la puerta")
	return tr("[E] Abrir la puerta")


## Can it be opened or closed right now (not swinging, not just used)?
func ready_to_move() -> bool:
	return _cool <= 0.0 and (amount <= 0.0 or amount >= 1.0)


## Closed enough to stand in the way (the entity waits for more than this).
func blocks() -> bool:
	return amount < 0.75


## Which way to open it, for someone at `from`: away from them.
func swing_from(from: Vector3) -> int:
	var n := Vector3(axis.x, 0, axis.y) * face
	return -1 if (from - global_position).dot(n) > 0.0 or not _can_open_out else 1


## Host -> everyone: open or close it. `slow`: the entity, creaking.
## `toward`: when opening, -1 into the passage, +1 into the room (see swing_from).
@rpc("authority", "call_local", "reliable")
func set_open(on: bool, slow := false, toward := -1) -> void:
	if on == is_open:
		return
	is_open = on
	if on and amount <= 0.0:
		swing = toward
		_open_angle = _angle_in if swing < 0 else _angle_out
	_swing = ENTITY_SWING_TIME if slow else SWING_TIME
	_cool = COOLDOWN + _swing
	_audio.stream = Sfx.get_stream("door_creak" if slow else ("door_open" if on else "door_close"))
	_audio.volume_db = 0.0 if slow else -4.0
	_audio.play()


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	var target := 1.0 if is_open else 0.0
	if amount != target:
		amount = move_toward(amount, target, delta / _swing)
		_apply()


func _apply() -> void:
	if _leaf_shape:
		# Open (or nearly), the leaf stands against the wall: nothing to
		# bump into in the passage.
		_leaf_shape.set_deferred("disabled", amount > 0.6)
	if _pivot:
		var k := amount * amount * (3.0 - 2.0 * amount)
		_pivot.rotation.y = _open_angle * k
