class_name ExitDoor
extends Area3D
## The front door back to the van. Easy to find in the dark: a lamp above
## it, a red emergency sign, light leaking under it and the van's
## headlights through its little window. With the quota it lights up
## (headlights on full, the van honks) and lets the team out.
## Local -Z points into the house (Run orients it).

const WARM := Color(1.0, 0.82, 0.55)
const HEADLIGHTS := Color(0.85, 0.9, 1.0)

var run: Run
var _open_shown := false
var _lamp: OmniLight3D
var _window: StandardMaterial3D
var _leak: StandardMaterial3D
var _t := 0.0


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
	_build()


func is_open() -> bool:
	return run != null and run.tapes_got >= run.tapes_needed


func prompt() -> String:
	if is_open():
		return tr("[E] Volver a la furgoneta")
	var missing := run.tapes_needed - run.tapes_got if run else 0
	return tr_n("Falta %d cinta", "Faltan %d cintas", missing) % missing


func _process(delta: float) -> void:
	_t += delta
	var open := is_open()
	if open != _open_shown:
		_open_shown = open
		if open:
			Sfx.play_3d(self, global_position + Vector3.UP, "van_horn", -2.0)
	# Headlights through the door's window: steady and dim, on full once
	# the van is waiting for you.
	var w := 1.6 if open else 0.4 + 0.05 * sin(_t * 1.3)
	_window.emission_energy_multiplier = w
	_leak.emission_energy_multiplier = w * 1.4
	_lamp.light_energy = 1.4 if open else 0.9
	_lamp.light_color = HEADLIGHTS if open else WARM


func _build() -> void:
	# A small lamp over the door, always on (a separate circuit).
	var fixture := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.1
	fixture.mesh = sphere
	fixture.material_override = GearModels.flat(WARM, 3.0)
	fixture.position = Vector3(0, 2.32, -0.08)
	add_child(fixture)
	_lamp = OmniLight3D.new()
	_lamp.light_color = WARM
	_lamp.omni_range = 4.0
	_lamp.omni_attenuation = 1.3
	_lamp.light_volumetric_fog_energy = 1.2
	_lamp.position = Vector3(0, 2.2, -0.35)
	add_child(_lamp)
	# Emergency sign.
	var sign := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(0.5, 0.16, 0.05)
	sign.mesh = plate
	sign.material_override = GearModels.flat(Color(0.12, 0.02, 0.02))
	sign.position = Vector3(0, 2.5, -0.04)
	add_child(sign)
	var text := Label3D.new()
	text.text = tr("SALIDA")
	text.font_size = 40
	text.pixel_size = 0.0035
	text.modulate = Color(1.0, 0.25, 0.18)
	text.outline_size = 0
	text.position = Vector3(0, 2.5, -0.068)
	text.rotation.y = PI
	add_child(text)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.2, 0.15)
	glow.light_energy = 0.35
	glow.omni_range = 1.6
	glow.position = Vector3(0, 2.45, -0.2)
	add_child(glow)
	# The window in the door (see door_exit.png) and the gap under it.
	_window = GearModels.flat(HEADLIGHTS, 1.0).duplicate()
	var win := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.37, 0.3)
	win.mesh = q
	win.material_override = _window
	win.position = Vector3(0, 2.07, -0.004)
	win.rotation.y = PI
	add_child(win)
	_leak = GearModels.flat(WARM, 1.0).duplicate()
	var gap := MeshInstance3D.new()
	var strip := QuadMesh.new()
	strip.size = Vector2(0.86, 0.025)
	gap.mesh = strip
	gap.material_override = _leak
	gap.position = Vector3(0, 0.013, -0.004)
	gap.rotation.y = PI
	add_child(gap)
