class_name Camcorder
extends Node
## The VHS camcorder, the only thing that shows the entity. Hold "film" to
## look through the viewfinder; filming drains the battery. What the host
## will need from each player is just `filming` and the camera transform.

signal filming_changed(on: bool)

var battery := 100.0
## 0 lowered .. 1 at the eye.
var raise := 0.0
## Time on tape (the counter of the viewfinder).
var tape_time := 0.0
## Dev tours: keep it at the eye without input.
var force_held := false
## The capture: show the entity whatever the camcorder is doing.
var reveal := false
var _was_filming := false

@onready var _player: Player = get_parent()

var filming: bool:
	get:
		return raise >= 0.95 and battery > 0.0


func _process(delta: float) -> void:
	var held := force_held or (_player.input_enabled and Input.is_action_pressed("film"))
	raise = move_toward(raise, 1.0 if held else 0.0, delta / Tuning.CAMCORDER_RAISE_TIME)
	if filming:
		battery = maxf(0.0, battery - Tuning.BATTERY_DRAIN * delta)
		tape_time += delta
	if filming != _was_filming:
		_was_filming = filming
		filming_changed.emit(filming)
		if filming:
			Sfx.play(self, "rec_beep", -10.0)
	var cam := _player.camera
	cam.fov = lerpf(Tuning.FOV, Tuning.FILM_FOV, smoothstep(0.0, 1.0, raise))
	if filming or reveal:
		cam.cull_mask |= Entity.LAYER_MASK
	else:
		cam.cull_mask &= ~Entity.LAYER_MASK


func add_battery(amount: float) -> void:
	battery = minf(100.0, battery + amount)
