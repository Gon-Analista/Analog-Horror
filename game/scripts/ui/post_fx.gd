extends ColorRect
## Drives the full-screen post shader from the local player's camcorder and
## the entity's distance. Pure local presentation.

var _player: Player
var _entity: Entity
var _run: Run
var _mat: ShaderMaterial


func setup(player: Player, entity: Entity, run: Run) -> void:
	_player = player
	_entity = entity
	_run = run
	_mat = material as ShaderMaterial


func _process(_delta: float) -> void:
	if _player == null:
		return
	var cam := _player.camcorder
	var caught := _run.phase == Run.Phase.CAUGHT
	var vhs := smoothstep(0.6, 1.0, cam.raise)
	var near := 0.0
	if _entity.state != Entity.State.DORMANT:
		var d := _player.global_position.distance_to(_entity.global_position)
		near = pow(clampf(1.0 - d / Tuning.STATIC_RANGE, 0.0, 1.0), 2.0) * 0.55
	_mat.set_shader_parameter("vhs", 1.0 if caught else vhs)
	_mat.set_shader_parameter("static_amount", near if cam.filming else 0.0)
	_mat.set_shader_parameter("hit", 1.0 if caught else 0.0)
	_mat.set_shader_parameter("dead", 1.0 if cam.battery <= 0.0 and not caught else 0.0)
