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
	# The tape's lines stay 270 to the picture, whatever its resolution.
	_mat.set_shader_parameter("line_px", float(Settings.render_scale()))


func _process(_delta: float) -> void:
	if _player == null:
		return
	if _run.pilot and not (_run.replay and _run.replay.playing):
		# Played by someone: its own sight (EntityPilot, PilotHud), no tape.
		_mat.set_shader_parameter("vhs", 0.0)
		_mat.set_shader_parameter("static_amount", 0.0)
		_mat.set_shader_parameter("hit", 0.0)
		_mat.set_shader_parameter("dead", 0.0)
		return
	if _run.replay and _run.replay.playing:
		# Played back: a tape, nothing more (the picture of the night as it was).
		_mat.set_shader_parameter("vhs", 1.0)
		_mat.set_shader_parameter("static_amount", 0.04)
		_mat.set_shader_parameter("hit", 0.0)
		_mat.set_shader_parameter("dead", 0.0)
		return
	# Whose eyes: the local player, or whom they watch after being taken
	# (that view is always a camera feed).
	var p := _run.viewed_player()
	var spectating := p != _player
	var cam := p.camcorder
	var hit := _player.camcorder.reveal or _run.phase == Run.Phase.CAUGHT
	# Once it has every tape the camcorder's picture never recovers (the tape
	# stays chewed); the naked eye is untouched.
	var ruined := 0.0 if _entity.state == Entity.State.DORMANT or not _entity.enraged else smoothstep(0.5, 1.0, cam.raise)
	if spectating:
		ruined = 1.0 if _entity.enraged else 0.0
	var vhs := 1.0 if hit or spectating else maxf(maxf(smoothstep(0.6, 1.0, cam.raise), _run.rage_flash), ruined * 0.6)
	var near := 0.0
	if _entity.state != Entity.State.DORMANT:
		var d := p.global_position.distance_to(_entity.global_position)
		near = pow(clampf(1.0 - d / Tuning.STATIC_RANGE, 0.0, 1.0), 2.0) * 0.38  # interference near it (a little less than before)
	# Fewer flashes (Settings): the bursts of static and the hits toned down.
	var calm := Settings.flash_scale()
	_mat.set_shader_parameter("vhs", vhs)
	_mat.set_shader_parameter("static_amount", maxf(near if cam.filming or spectating else 0.0, ruined * 0.12) * calm)
	_mat.set_shader_parameter("hit", (1.0 if hit else maxf(_run.rage_flash * 0.8, ruined * 0.22)) * calm)
	_mat.set_shader_parameter("dead", 1.0 if not spectating and cam.battery <= 0.0 and not hit else 0.0)
