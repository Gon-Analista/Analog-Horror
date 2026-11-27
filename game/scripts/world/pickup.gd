class_name Pickup
extends Area3D
## A tape, a battery or a camcorder lying in the house. On the interact
## layer so the player's ray finds it; Run decides what picking it up does.
## A camcorder keeps its battery charge; one dropped by someone taken by the
## entity keeps recording on the floor (red light on).

enum Kind { TAPE, BATTERY, CAMERA }

var kind := Kind.TAPE
## CAMERA: charge left (0-100) and whether it was left by a victim.
var battery := 100.0
var recording := false
## TAPE at Canal 9: a U-matic master of the programme, not a VHS copy.
var master := false
var _led: Node3D
var _glow: OmniLight3D


static func create(p_kind: Kind, p_master := false) -> Pickup:
	var p := Pickup.new()
	p.kind = p_kind
	p.master = p_master and p_kind == Kind.TAPE
	return p


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = Tuning.LAYER_INTERACT
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.25, 0.4)
	shape.shape = box
	shape.position.y = 0.12
	add_child(shape)
	if kind == Kind.CAMERA:
		_build_camera()
	elif kind == Kind.TAPE:
		_build_tape()
		# It is rewinding: you can find it by ear.
		var whir := AudioStreamPlayer3D.new()
		whir.bus = "Effects"
		whir.stream = Sfx.get_stream("tape_whir", true)
		whir.volume_db = -14.0
		whir.unit_size = 1.2
		whir.max_distance = 9.0
		whir.position.y = 0.05
		add_child(whir)
		whir.play()
	else:
		_build_battery()


func prompt() -> String:
	match kind:
		Kind.TAPE:
			return tr("[E] Recoger máster") if master else tr("[E] Recoger cinta")
		Kind.CAMERA:
			return tr("[E] Coger la cámara (%d%%)") % int(battery)
	return tr("[E] Recoger batería")


func _build_camera() -> void:
	var cam := GearModels.camcorder()
	cam.position.y = 0.06
	cam.rotation = Vector3(0.0, randf() * TAU, PI / 2 if recording else 0.0)
	add_child(cam)
	if recording:
		(cam.get_node("Tally") as Node3D).visible = true
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.1, 0.05)
		glow.light_energy = 0.4
		glow.omni_range = 1.2
		glow.position.y = 0.15
		add_child(glow)


func _build_tape() -> void:
	var model := GearModels.umatic() if master else GearModels.tape()
	model.rotation.y = randf() * TAU
	add_child(model)
	_no_shadow(model)


func _build_battery() -> void:
	var model := GearModels.battery()
	model.rotation.y = randf() * TAU
	add_child(model)
	_no_shadow(model)
	# Its charge light blinks, slowly: easy to spot across a dark room.
	_led = model.get_node("Led")
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.3, 1.0, 0.45)
	glow.light_energy = 0.15
	glow.omni_range = 0.6
	glow.position.y = 0.08
	add_child(glow)
	_glow = glow


## A few centimetres tall: its shadow would not show, but it would be drawn
## again in every shadow pass that reaches it (the flashlight, lamps).
func _no_shadow(model: Node) -> void:
	for m in GearModels.meshes(model):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	if _led:
		var on := fmod(Time.get_ticks_msec() / 1000.0 + get_instance_id() % 7, 2.0) < 0.25
		_led.visible = on
		_glow.visible = on
