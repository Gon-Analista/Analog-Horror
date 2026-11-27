class_name Camcorder
extends Node
## The VHS camcorder, the only thing that shows the entity. The local
## player holds "film" to look through the viewfinder (filming drains the
## battery); for the others it follows what the owner replicates. What the
## host needs from each player is `filming` and the camera transform.

signal filming_changed(on: bool)
## Left click while filming: the flash went off (Run tells the host).
signal flash_fired

var battery := 100.0
## 0 lowered .. 1 at the eye.
var raise := 0.0
## Time on tape (the counter of the viewfinder).
var tape_time := 0.0
## Dev tours: keep it at the eye without input.
var force_held := false
## The capture: show the entity whatever the camcorder is doing.
var reveal := false
## The entity is leaning into our hiding place: it shows, to the naked eye too.
var peeked := false
var _was_filming := false
## After lowering it, a moment before it can go up again (no spamming).
var _cooldown := 0.0
var _was_held := false
## A punch-in of the lens (degrees), easing back (the screamer).
var fov_kick := 0.0
## Seconds until the flash has recharged.
var flash_cooldown := 0.0

@onready var _player: Player = get_parent()

var filming: bool:
	get:
		if not _player.is_local:
			return _player.net_filming and _player.alive
		return raise >= 0.95 and battery > 0.0 and _player.alive and _player.has_camera and _player.holds("camcorder")


func _process(delta: float) -> void:
	if _player.is_local:
		var held := force_held or (_player.input_enabled and _player.alive and not _player.ui_open and not _player.seated and _player.has_camera
				and _player.holds("camcorder") and Input.is_action_pressed("film"))
		_cooldown = maxf(0.0, _cooldown - delta)
		if _was_held and not held:
			_cooldown = Tuning.CAMCORDER_COOLDOWN
		if not _was_held and held and _cooldown > 0.0 and not force_held:
			held = false  # still lowering: wait for it
		else:
			_was_held = held
		raise = move_toward(raise, 1.0 if held else 0.0, delta / Tuning.CAMCORDER_RAISE_TIME)
		if filming:
			var drain := Tuning.BATTERY_DRAIN * (Tuning.SOLO_BATTERY_MULT if Net.is_solo() else 1.0)
			battery = maxf(0.0, battery - drain * delta)
			tape_time += delta
		if filming != _was_filming:
			_was_filming = filming
			filming_changed.emit(filming)
			if filming:
				Sfx.play(self, "rec_beep", -10.0)
				_player.used.emit()
		flash_cooldown = maxf(0.0, flash_cooldown - delta)
		if filming and Input.is_action_just_pressed("flash") and _player.input_enabled and not force_held:
			var cost := Tuning.FLASH_COST if Net.is_solo() else Tuning.FLASH_COST_COOP
			if flash_cooldown <= 0.0 and battery >= cost:
				battery -= cost
				flash_cooldown = Tuning.FLASH_COOLDOWN if Net.is_solo() else Tuning.FLASH_COOLDOWN_COOP
				flash_fired.emit()
				Sfx.play(self, "flash_charge", -16.0)
			else:
				Sfx.play(self, "click", -8.0, 0.6)  # not ready
	else:
		raise = move_toward(raise, _player.net_raise, delta / Tuning.CAMCORDER_RAISE_TIME)
	# FOV matters for the remote cameras too: the host checks their frame.
	var cam := _player.camera
	fov_kick = move_toward(fov_kick, 0.0, delta * 14.0)
	cam.fov = lerpf(Tuning.FOV, Tuning.FILM_FOV, smoothstep(0.0, 1.0, raise)) - fov_kick
	if _player.seated:
		cam.fov = _player.seat_fov  # sat: eyes on the screen
	if filming or reveal or peeked:
		cam.cull_mask |= Entity.LAYER_MASK
	else:
		cam.cull_mask &= ~Entity.LAYER_MASK
	# The Husk is the other way round: the eye sees it, the tape does not
	# (only its shadow). Taken, you see it whatever you hold.
	if filming and not reveal:
		cam.cull_mask &= ~HuskModel.NAKED_LAYER
	else:
		cam.cull_mask |= HuskModel.NAKED_LAYER


func add_battery(amount: float) -> void:
	battery = minf(100.0, battery + amount)
