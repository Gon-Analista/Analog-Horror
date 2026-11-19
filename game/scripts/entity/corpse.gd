class_name Corpse
extends Node3D
## What is left of someone the entity took: their body, limp on the floor.
## Visible to everyone (no camera needed), which is the point: the entity
## comes back for it, drags it around and throws it, and without a
## camcorder you only see a body sliding and flying by itself. The host
## moves it; position, rotation and state are replicated.

enum CState { LYING, DRAGGED, FLYING }

const THROW_TIME := 0.75

var peer_id := 0
var tint := Color.WHITE
var cstate := CState.LYING
## Host: who drags it (the entity), and the throw in progress.
var carrier: Node3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _t := 0.0
var _spin := Vector3.ZERO
var _shown := CState.LYING
var _avatar: PlayerAvatar
var _rng := RandomNumberGenerator.new()


func setup(id: int, p_tint: Color) -> void:
	peer_id = id
	tint = p_tint
	name = "Corpse%d" % id


func _ready() -> void:
	_rng.seed = peer_id * 977
	_avatar = PlayerAvatar.new()
	_avatar.tint = tint
	add_child(_avatar)
	_avatar.pose_dead(_rng)
	_avatar.set_has_camera(false)
	_lie()
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["position", "rotation", "cstate"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	sync.replication_interval = 1.0 / 30.0
	add_child(sync)


func is_free() -> bool:
	return cstate == CState.LYING and carrier == null


## Host: the entity takes hold of it.
func grab(by: Node3D) -> void:
	carrier = by
	cstate = CState.DRAGGED


## Host: thrown towards `to` (on the floor), tumbling through the air.
func throw_to(to: Vector3) -> void:
	carrier = null
	cstate = CState.FLYING
	_from = global_position + Vector3.UP * 0.8
	_to = to
	_t = 0.0
	_spin = Vector3(_rng.randf_range(-9, 9), _rng.randf_range(-6, 6), _rng.randf_range(-9, 9))


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		match cstate:
			CState.DRAGGED:
				if carrier == null or not is_instance_valid(carrier):
					cstate = CState.LYING
					_lie()
				else:
					# Dragged by the ankles along the floor, trailing behind it.
					var trail := global_position - carrier.global_position
					trail.y = 0.0
					var want := carrier.global_position + (trail.normalized() * 0.9 if trail.length() > 0.05 else Vector3(0.9, 0, 0))
					want.y = carrier.global_position.y + 0.14
					global_position = global_position.lerp(want, minf(1.0, delta * 8.0))
					var look := carrier.global_position
					look.y = global_position.y
					if global_position.distance_to(look) > 0.1:
						look_at(look, Vector3.UP)
					rotate_object_local(Vector3.RIGHT, -PI / 2)
			CState.FLYING:
				_t += delta / THROW_TIME
				var k := minf(_t, 1.0)
				var p := _from.lerp(_to, k)
				p.y += sin(k * PI) * 1.4
				global_position = p
				rotation += _spin * delta
				if _t >= 1.0:
					global_position = _to
					cstate = CState.LYING
					_lie()
	# Every machine: the thud when it lands, the scrape while dragged.
	if cstate != _shown:
		if _shown == CState.FLYING and cstate == CState.LYING:
			Sfx.play_3d(get_parent(), global_position, "body_thud", 0.0)
		_shown = cstate


func _lie() -> void:
	rotation = Vector3(-PI / 2, _rng.randf() * TAU, 0.0)
	global_position.y = floorf(global_position.y / Level.FLOOR_H + 0.3) * Level.FLOOR_H + 0.14 if is_inside_tree() else position.y
