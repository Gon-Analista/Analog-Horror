class_name Entity
extends Node3D
## "La Visita": Vecinito, the cartoon mascot of ¡Hola, Vecinitos!, a show
## that was never aired. A hand-drawn ink sprite whose lines "boil" like
## old animation, drawn only on visual layer 2, which only a filming
## camcorder renders. Rules: it does not move while someone films it (and
## every time you find it again it is in another pose), it comes faster
## when nobody even looks its way. With several players it hunts the
## nearest one still standing and freezes if ANY of them films it. Its
## mind runs on the host, which replicates position, state and pose;
## presentation (sprite, shadow, audio) runs on every machine for the
## player watching there (`viewer`).

signal caught(player: Player)

const LAYER_MASK := 2  # visual layer 2
enum State { DORMANT, STALKING, FROZEN, FEEDING }
enum Pose { STAND, REACH, TILT, PEEK, CROUCH, LUNGE }

const SHEET := "res://assets/textures/entity_sheet.png"
const FRAME_SIZE := Vector2i(128, 224)
const BOIL_FRAMES := 3
const BOIL_FPS := 8.0
const HEIGHT := 2.4
## Height of the face centre in the LUNGE frame (metres above the feet).
const LUNGE_FACE_HEIGHT := 1.52
const FLASH_CHANCE := 0.25  # per second while filmed: a subliminal lunge frame
const FLASH_TIME := 0.07

var state := State.DORMANT
var level: Level
## Everyone in the run (the host hunts the alive ones).
var players: Array[Player] = []
## Who this machine's screen belongs to (the local player, or whom a caught
## player is watching): what decides if it is drawn and heard.
var viewer: Player
## Host: the player it is going for right now.
var target: Player
## Replicated position (clients glide to it).
var net_pos := Vector3.ZERO
## Escalation: tapes the team has taken.
var tapes := 0
var pose := Pose.STAND
var _path: Array[Vector2i] = []
var _repath := 0.0
var _step_acc := 0.0
var _last_pos := Vector3.ZERO
var _boil_t := 0.0
var _flash := 0.0
var _voice_in := 10.0
var _shown_state := State.DORMANT
var _sprite: Sprite3D
var _rng := RandomNumberGenerator.new()

@onready var jingle: AudioStreamPlayer3D = $Jingle
@onready var drone: AudioStreamPlayer3D = $Drone
@onready var voice: AudioStreamPlayer3D = $Voice
@onready var steps: AudioStreamPlayer3D = $Steps


func _ready() -> void:
	_build_sprite()
	jingle.stream = Sfx.get_stream("jingle", true)
	jingle.play()
	drone.stream = Sfx.get_stream("drone", true)
	drone.play()
	steps.stream = Sfx.get_stream("entity_step")
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["net_pos", "state", "pose", "tapes"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	sync.replication_interval = 1.0 / 30.0
	add_child(sync)


func wake() -> void:
	if state == State.DORMANT:
		state = State.STALKING


func speed() -> float:
	return Tuning.ENTITY_SPEED + Tuning.ENTITY_SPEED_PER_TAPE * tapes


## Whether `p` is filming it right now: camcorder up, inside the frame,
## within range and not behind a wall (head or chest is enough).
func is_filmed_by(p: Player) -> bool:
	if not p.camcorder.filming:
		return false
	var cam := p.camera
	var space := get_world_3d().direct_space_state
	for h: float in [1.0, 1.95]:
		var point := global_position + Vector3.UP * h
		if not cam.is_position_in_frustum(point):
			continue
		if cam.global_position.distance_to(point) > Tuning.FILM_RANGE:
			continue
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, point, Tuning.LAYER_WORLD)
		if space.intersect_ray(q).is_empty():
			return true
	return false


## The capture (host): it stands right in front of the camera, mouth open.
func lunge_at(p: Player) -> void:
	state = State.FEEDING
	pose = Pose.LUNGE
	var cam := p.camera
	var front := cam.global_position - cam.global_transform.basis.z * 0.85
	global_position = Vector3(front.x, cam.global_position.y - LUNGE_FACE_HEIGHT, front.z)
	net_pos = global_position


## Host: after taking someone, it goes on hunting the rest.
func resume() -> void:
	state = State.STALKING
	pose = Pose.STAND
	global_position.y = 0.0


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		global_position = global_position.lerp(net_pos, minf(1.0, delta * 10.0))
		return
	if state == State.STALKING or state == State.FROZEN:
		_think(delta)
	net_pos = global_position


func _alive() -> Array[Player]:
	var out: Array[Player] = []
	for p in players:
		if is_instance_valid(p) and p.alive:
			out.append(p)
	return out


func _process(delta: float) -> void:
	_present(delta)


func _think(delta: float) -> void:
	var alive := _alive()
	if alive.is_empty():
		return
	var filmed := false
	var seen := false
	target = alive[0]
	for p in alive:
		if is_filmed_by(p):
			filmed = true
		if p.camera.is_position_in_frustum(global_position + Vector3.UP):
			seen = true
		if p.global_position.distance_to(global_position) < target.global_position.distance_to(global_position):
			target = p
	var was := state
	state = State.FROZEN if filmed else State.STALKING
	if filmed:
		# Found again on camera: every time, in another pose.
		if was == State.STALKING:
			_new_pose()
		return
	var mult := 1.0 if seen else Tuning.ENTITY_UNSEEN_MULT
	_move(speed() * mult * delta, delta)
	if _flat(target.global_position - global_position).length() < Tuning.ENTITY_KILL_RANGE:
		state = State.FEEDING
		caught.emit(target)


func _move(dist: float, delta: float) -> void:
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.25
		var goal := level.nearest_walkable(level.cell_of(target.global_position))
		_path = level.path(level.cell_of(global_position), goal)
	while not _path.is_empty() and _flat(level.center(_path[0]) - global_position).length() < 0.05:
		_path.pop_front()
	var dest := target.global_position if _path.is_empty() else level.center(_path[0])
	var to := _flat(dest - global_position)
	var moved := minf(dist, to.length())
	if moved > 0.0001:
		global_position += to.normalized() * moved


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- local presentation ------------------------------------------------------

func _present(delta: float) -> void:
	# Found again on camera (the pose comes from the host): the tape dies.
	if state != _shown_state:
		if state == State.FROZEN and _shown_state == State.STALKING and viewer and viewer.camcorder.filming:
			Sfx.play(self, "filmed_sting", -6.0)
		if state == State.FEEDING:
			jingle.stop()
			drone.stop()
		elif _shown_state == State.FEEDING:
			jingle.play()
			drone.play()
		_shown_state = state

	# Footsteps from how far it actually moved (so every machine hears them).
	if state == State.STALKING:
		_step_acc += _flat(global_position - _last_pos).length()
		if _step_acc > 0.8:
			_step_acc = 0.0
			steps.pitch_scale = _rng.randf_range(0.8, 1.05)
			steps.play()
	_last_pos = global_position

	_boil_t += delta
	var shown_pose := pose
	if state == State.FROZEN:
		_flash -= delta
		if _flash <= 0.0 and _rng.randf() < FLASH_CHANCE * delta:
			_flash = FLASH_TIME
		if _flash > 0.0:
			shown_pose = Pose.LUNGE
	_sprite.frame = int(shown_pose) * BOIL_FRAMES + int(_boil_t * BOIL_FPS) % BOIL_FRAMES

	var shown := viewer != null and (viewer.camcorder.filming or viewer.camcorder.reveal)
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shown else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if viewer:
		# Unlit drawing: it fades with distance instead of with light.
		var d := global_position.distance_to(viewer.global_position)
		var v := lerpf(0.45, 0.16, clampf((d - 2.0) / 12.0, 0.0, 1.0))
		_sprite.modulate = Color(v, v * 0.95, v * 0.92)

	# Silent until woken. Then the show's song stops while it is filmed;
	# the drone never does.
	drone.stream_paused = state == State.DORMANT
	jingle.stream_paused = state == State.FROZEN or state == State.DORMANT
	jingle.volume_db = -18.0 if state == State.DORMANT else -7.0 + tapes
	jingle.pitch_scale = 1.0 - 0.02 * tapes
	_voice(delta)


## Now and then, while nobody films it, it greets you.
func _voice(delta: float) -> void:
	if state != State.STALKING or voice.playing:
		return
	_voice_in -= delta
	if _voice_in > 0.0:
		return
	_voice_in = _rng.randf_range(9.0, 16.0) - tapes
	var near := viewer != null and global_position.distance_to(viewer.global_position) < 6.0
	voice.stream = Sfx.get_stream("voice_whisper" if near and _rng.randf() < 0.6 else "voice_hola")
	voice.pitch_scale = _rng.randf_range(0.92, 1.0)
	voice.play()


func _new_pose() -> void:
	var choices := [Pose.STAND, Pose.REACH, Pose.TILT, Pose.PEEK, Pose.CROUCH]
	choices.erase(pose)
	pose = choices[_rng.randi() % choices.size()]


func _build_sprite() -> void:
	_sprite = Sprite3D.new()
	_sprite.texture = load(SHEET)
	if _sprite.texture == null:
		push_error("Entity: missing %s (run tools/gen_entity.py and import)" % SHEET)
	_sprite.hframes = BOIL_FRAMES
	_sprite.vframes = Pose.size()
	_sprite.pixel_size = HEIGHT / FRAME_SIZE.y
	_sprite.offset = Vector2(0, FRAME_SIZE.y * 0.5)
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.layers = LAYER_MASK
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)
