class_name ReadableScreen
extends Area3D
## Lets the player watch a screen (the living-room TV) up close: the HUD
## shows it full size, since at 480x270 it is hard to see.

var tv: TvBroadcast


func _ready() -> void:
	collision_layer = Tuning.LAYER_INTERACT
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.62, 0.5, 0.1)
	shape.shape = box
	add_child(shape)


func prompt() -> String:
	return tr("[E] Leer el aviso") if tv.is_showing_text() else tr("[E] Ver la tele")
