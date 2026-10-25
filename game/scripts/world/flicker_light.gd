class_name FlickerLight
extends OmniLight3D
## Ceiling lamp of the evacuated house: unstable power that hums and dips
## now and then, and fails when the entity is close.

const ENERGY := 1.1
const BULB_GLOW := 2.5

var dead := false
## 0 calm .. 1 the entity is right under it (set by Run every frame).
var disturbance := 0.0
## Emissive material of the fixture; dims with the light.
var bulb: StandardMaterial3D
var _t := 0.0
var _dip := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(position)
	_t = _rng.randf() * 10.0


func _process(delta: float) -> void:
	var e := 0.0
	if not dead:
		_t += delta
		e = ENERGY * (0.95 + 0.05 * sin(_t * 41.0) * sin(_t * 13.0))
		if _dip > 0.0:
			_dip -= delta
			e *= 0.25
		elif _rng.randf() < delta * 0.08:
			_dip = _rng.randf_range(0.04, 0.18)
		if disturbance > 0.0 and _rng.randf() < disturbance * 0.6:
			e *= _rng.randf_range(0.0, 0.35)
		if disturbance > 0.85:
			e = 0.0
	light_energy = e
	if bulb:
		bulb.emission_energy_multiplier = e * BULB_GLOW
