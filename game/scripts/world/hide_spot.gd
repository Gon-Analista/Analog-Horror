class_name HideSpot
extends Area3D
## A place to hide: under a bed or a table, or inside a wardrobe. E goes in
## (the body goes under the furniture, the view drops to floor level) and E
## again comes out where you went in. The entity cannot see you under a bed
## or in a wardrobe; under a table only from close by or by your light.
## It can still check the spot when it searches (Entity._check_spot), and it
## finds you if it saw you go in, if you talk or if your light is on.
## Built by Level with the furniture, with the same name on every machine
## (Hide<n>), so a player can say where they are hiding (Player.net_hide).

enum Kind { BED, TABLE, WARDROBE }

var kind := Kind.BED
## Where the hidden body lies (inside the furniture's footprint, on the floor).
var inside := Vector3.ZERO
## The free cell in front, from where you crawl in and the entity looks in.
var access := Vector3i.ZERO
## Which way the opening faces (the view looks out of it).
var facing := Vector3.FORWARD
## How deep the furniture is, front to back (from the opening).
var depth := 1.0
## The furniture's size (metres).
var size := Vector3.ONE


func setup(p_kind: Kind, centre: Vector3, p_size: Vector3, p_access: Vector3i, p_facing: Vector3) -> void:
	kind = p_kind
	inside = Vector3(centre.x, centre.y - p_size.y * 0.5, centre.z)
	access = p_access
	facing = p_facing
	depth = p_size.z if absf(p_facing.z) > 0.5 else p_size.x
	size = p_size
	position = centre
	collision_layer = Tuning.LAYER_INTERACT
	collision_mask = 0
	monitoring = false
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = p_size + Vector3(0.08, 0.04, 0.08)  # just outside the furniture's collider
	shape.shape = box
	add_child(shape)


## Eye height inside (from the floor).
## A wardrobe seen from inside (only the one hiding in it builds it): its
## dark wooden walls all round and the two doors, shut but for a crack of
## light down the middle; children "DoorL"/"DoorR" (hinged at the sides)
## swing open when the entity pulls them.
func make_inside(level: Level) -> Node3D:
	var root := Node3D.new()
	var m := level.mat("wood_dark").duplicate() as StandardMaterial3D
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.55, 0.5, 0.45)
	var out := facing.normalized()
	var across := Vector3(-out.z, 0, out.x)
	var w := size.x if absf(out.z) > 0.5 else size.z
	var h := size.y - 0.06
	var d := depth - 0.06
	var box := func(at: Vector3, s_along: float, s_out: float, s_h: float, parent: Node3D) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(s_along, s_h, s_out) if absf(across.x) > 0.5 else Vector3(s_out, s_h, s_along)
		mi.mesh = bm
		mi.material_override = m
		mi.position = at
		parent.add_child(mi)
		return mi
	box.call(-out * (d * 0.5), w, 0.02, h, root)                        # back
	for k: float in [-1.0, 1.0]:
		box.call(across * k * (w * 0.5 - 0.01), 0.02, d, h, root)        # sides
	box.call(Vector3.UP * (h * 0.5), w, d, 0.02, root)                  # top
	box.call(Vector3.UP * (h * 0.5 - 0.12) - out * 0.05, w - 0.06, 0.025, 0.025, root)  # the hanging rail
	var gap := 0.03
	var leaf := (w - gap) * 0.5
	for k: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "DoorL" if k < 0 else "DoorR"
		hinge.position = out * (d * 0.5) + across * k * (w * 0.5)
		root.add_child(hinge)
		box.call(-across * k * (leaf * 0.5), leaf, 0.025, h, hinge)
	root.position = Vector3.UP * 0.0
	return root


func eye() -> float:
	match kind:
		Kind.BED:
			return 0.16
		Kind.TABLE:
			return 0.5
	return 1.5


## How well it hides you from sight: a table only partly.
func conceals() -> bool:
	return kind != Kind.TABLE


func prompt() -> String:
	var me := _local_player()
	if me and me.hiding == self:
		return tr("[E] Salir")
	match kind:
		Kind.BED:
			return tr("[E] Esconderse bajo la cama")
		Kind.TABLE:
			return tr("[E] Esconderse bajo la mesa")
	return tr("[E] Esconderse en el armario")


func _local_player() -> Player:
	for p in get_tree().get_nodes_in_group("players"):
		if (p as Player).is_local:
			return p
	return null
