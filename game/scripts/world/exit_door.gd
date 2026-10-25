class_name ExitDoor
extends Area3D
## The front door back to the van. Only lets the team out with the quota.

var run: Run


func _ready() -> void:
	collision_layer = Tuning.LAYER_INTERACT
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 2.0, 0.3)
	shape.shape = box
	shape.position.y = 1.0
	add_child(shape)


func is_open() -> bool:
	return run != null and run.tapes_got >= run.tapes_needed


func prompt() -> String:
	if is_open():
		return tr("[E] Volver a la furgoneta")
	var missing := run.tapes_needed - run.tapes_got if run else 0
	return tr_n("Falta %d cinta", "Faltan %d cintas", missing) % missing
