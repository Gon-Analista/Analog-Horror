class_name CrouchHint
extends Area3D
## On the boards nailed across a doorway: tells the player they can crouch
## under them. Interacting does nothing; it only carries the prompt.


func _ready() -> void:
	collision_layer = Tuning.LAYER_INTERACT
	collision_mask = 0
	monitoring = false


func prompt() -> String:
	return tr("[C] Agáchate para pasar")
