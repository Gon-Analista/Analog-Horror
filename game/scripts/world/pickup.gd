class_name Pickup
extends Area3D
## A tape or a battery lying in the house. On the interact layer so the
## player's ray finds it; Run decides what picking it up does.

enum Kind { TAPE, BATTERY }

var kind := Kind.TAPE


static func create(p_kind: Kind) -> Pickup:
	var p := Pickup.new()
	p.kind = p_kind
	return p


func _ready() -> void:
	collision_layer = Tuning.LAYER_INTERACT
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.25, 0.4)
	shape.shape = box
	shape.position.y = 0.12
	add_child(shape)
	if kind == Kind.TAPE:
		_build_tape()
	else:
		_build_battery()


func prompt() -> String:
	return tr("[E] Recoger cinta") if kind == Kind.TAPE else tr("[E] Recoger batería")


func _build_tape() -> void:
	var shell := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.19, 0.026, 0.105)
	shell.mesh = box
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = Color(0.05, 0.05, 0.05)
	plastic.roughness = 0.5
	shell.material_override = plastic
	shell.position.y = 0.013
	add_child(shell)
	var label := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.15, 0.075)
	label.mesh = quad
	label.rotation.x = -PI / 2
	label.position.y = 0.0265
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = load("res://assets/textures/tape_label.png")
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# A faint glow so a tape reads as "something there" in the dark.
	paper.emission_enabled = true
	paper.emission_texture = paper.albedo_texture
	paper.emission_energy_multiplier = 0.12
	label.material_override = paper
	add_child(label)


func _build_battery() -> void:
	var cell := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.045, 0.12)
	cell.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.15, 0.2, 0.32)
	m.metallic = 0.3
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = Color(0.2, 0.35, 0.6)
	m.emission_energy_multiplier = 0.1
	cell.material_override = m
	cell.position.y = 0.023
	add_child(cell)
