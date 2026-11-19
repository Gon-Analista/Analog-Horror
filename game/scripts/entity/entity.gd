class_name Entity
extends Node3D
## "La Visita": Vecinito, the cartoon mascot of ¡Te estoy viendo!, a show
## that was never aired. A hand-drawn ink sprite whose lines "boil" like
## old animation, drawn only on visual layer 2, which only a filming
## camcorder renders.
##
## Rules that never change: it does not move while someone films it (and is
## in another pose each time you find it again); with all the tapes gone it
## tears free of the camera after a moment and is faster.
##
## It does not know where you are. It finds out (host only):
##   sight    a clear line from its eyes, ~140 degrees ahead of it (any side
##            when very close); 14 m if your flashlight is on, 6 m if not,
##            less crouched. Under a bed or in a wardrobe it cannot see you;
##            under a table only from close by or by your light.
##   hearing  running, walking, talking, taking a tape... measured in steps
##            through the house (sound goes along corridors, not through walls).
##   filming  when someone stops filming it, it knows where they stood.
## What it learns is a clue (where, how sure, how old) that fades. Then:
##   WANDER       knows nothing: roams the rooms it has not seen for a while
##   INVESTIGATE  heard something: goes to the noise, not to you
##   SEARCH       found nothing there: checks around (and under the beds,
##                tables and wardrobes on the way), asking where you are
##   CHASE        sees you: "¡te estoy viendo!" and straight for you; out of
##                sight for a moment, it goes where you were heading
##   FOLLOW       saw someone alone: behind them, still when they turn
##   LURK         saw you from afar: waits behind a corner near you, leaning out
##   AMBUSH       the Director guessed where you are going: it waits there
##   CORPSE       goes back for a body, drags it around laughing and throws it
## It only catches someone it can reach: close, on the same floor, nothing
## between (never through a wall or a corner), and not hidden, unless it
## checks the hiding place and has a reason to find you there.
## Presentation (sprite, shadow, audio) runs on every machine for the
## player watching there (`viewer`).

signal caught(player: Player)
## Host: something worth seeing again at the end (Replay): "peek", "drop", "found".
signal moment(kind: String, who: Player)

const LAYER_MASK := 2  # visual layer 2
enum State { DORMANT, STALKING, FROZEN, FEEDING }
enum Pose { STAND, REACH, TILT, PEEK, CROUCH, LUNGE, CRAWL, WALK, GALLOP, STRETCH, RUN }
enum Mode { CHASE, FOLLOW, LURK, CORPSE, WANDER, INVESTIGATE, SEARCH, AMBUSH, FLEE, STALK, PEEK }

## The drawing: the new one (tools/gen_entity_v2.py, the costume from the
## show) or the classic ink one (tools/gen_entity.py); Net.entity_style.
## [path, frame size, columns, rows]: the new one has 4 columns (boil
## frames, or the steps of the walk and the gallop) and the walk and
## gallop rows; the classic one 3 columns and no gait rows.
const SHEETS := [["res://assets/textures/entity_sheet_v2.png", Vector2i(192, 336), 4, 11],
		["res://assets/textures/entity_sheet.png", Vector2i(128, 224), 3, 7]]


## Net.entity_style 2: the Visita in 3D (EntityModel); where a drawing is
## still needed (the TV, the end), the new one.
const STYLE_3D := 2


static func is_3d() -> bool:
	return Net.entity_style == STYLE_3D


static func _sheet_index() -> int:
	return 0 if Net.entity_style >= SHEETS.size() else Net.entity_style


static func sheet() -> String:
	return SHEETS[_sheet_index()][0]


static func frame_size() -> Vector2i:
	return SHEETS[_sheet_index()][1]


static func sheet_columns() -> int:
	return SHEETS[_sheet_index()][2]


static func sheet_rows() -> int:
	return SHEETS[_sheet_index()][3]

const BOIL_FRAMES := 3
const BOIL_FPS := 8.0
const HEIGHT := 2.4
## Height of the face centre in the LUNGE frame (metres above the feet).
const LUNGE_FACE_HEIGHT := 1.52
## Face height in the PEEK frame (hands by its face, peering).
const PEEK_FACE_HEIGHT := 2.05
const PEEK_LOW_SCALE := 0.55
const FLASH_CHANCE := 0.25  # per second while filmed: a subliminal lunge frame
const FLASH_TIME := 0.07
const EYE := 1.9
const SENSE_EVERY := 0.15
## Its voice, a little louder than the rest (the last tape's scream is apart).
## (Players found its loudest sounds too loud, 2026-11-04: -6 dB, the
## screams -9 dB.)
const VOICE_DB := 6.0
## Its screams (chasing, burnt, found out) this much louder again.
const SCREAM_BOOST := 2.0
## Everything it makes is this much louder (not the screamer: that is Run's).
const LOUD := 8.0
## Its 3D players may go this loud up close (Godot clamps at 3 dB by default).
const MAX_DB := 10.0
## Lines with a second take (<line>2.wav, tools/gen_entity_audio.py).
const TAKES := ["voice_hunger", "voice_agony", "voice_line", "voice_count", "voice_ready", "voice_lost", "voice_found", "voice_hum",
		"voice_giggle", "laugh", "voice_cry", "voice_moan", "voice_frustrated", "voice_reverse"]
const NO_CELL := Vector3i(-1, -1, -1)

var state := State.DORMANT
var mode := Mode.WANDER
var level: Level
## Everyone in the run (the host hunts the alive ones).
var players: Array[Player] = []
## Bodies of the taken (the host plays with them).
var corpses: Array[Corpse] = []
## Who this machine's screen belongs to (the local player, or whom a caught
## player is watching): what decides if it is drawn and heard.
var viewer: Player
## Host: the player it is going for right now.
var target: Player
## Host: who has been talking (VoiceChat). It hears voices.
var voices: VoiceChat
## Replicated position (clients glide to it).
var net_pos := Vector3.ZERO
## Escalation: tapes the team has taken.
var tapes := 0
var pose := Pose.STAND
## All the tapes are gone: the camera only holds it for a moment, and it
## knows where everyone is who is not hiding.
var enraged := false
## Just woken: silent (no song, no voice) and keeping away. Replicated.
var quiet := false
## Leaning in under a bed or a table: drawn small enough to fit the gap. Replicated.
var peek_low := false
## Host: woken, its cry still to come (it waits for the TV to be left).
var cry_pending := false
## Waiting on the ceiling (an ambush from above): drawn upside down up
## there, it drops when someone walks under it. Replicated.
var on_ceiling := false
## Dev/tests: it always knows where you are and chases.
var hunt_only := false
## Host: the one that knows where everybody is (see Director).
var director: Director
## The flash: it comes apart where it stands (VANISH_TIME), then it is
## gone a while, somewhere else, unseen and silent, and comes back from
## where it chose. Replicated (every machine shows it coming apart, then
## nothing).
var vanishing := false
var gone := false
const VANISH_TIME := 0.75
var _vanish_left := 0.0
var _gone_left := 0.0
var _vanish_t := 0.0
## "La Visita es un jugador": the peer who controls it (0: the house, the AI).
## The same on every machine. Its own machine moves it (EntityPilot) and
## tells the host, who passes it on; the host still decides every catch.
var pilot_id := 0
## This machine is the one controlling it (it is not drawn here: you are it).
var piloted_here := false

# what it knows (host)
var _seen: Array[Player] = []
var _motion := {}  # Player -> [last position, velocity]
var _dist := {}    # steps from its cell, refreshed with the senses
var _sense_in := 0.0
var _clue_pos := Vector3.ZERO
var _clue_age := INF
var _clue_player: Player
var _clue_precise := false
var _clue_seen := false
var _clue_vel := Vector3.ZERO
var _clue_spot: HideSpot  # it saw them crawl in here
var _heard_new := false
var _facing := Vector3.FORWARD
var _filmer: Player
var _clock := 0.0
## The monitor (Alt+F1): what it decided and why, and what it said.
var events: Array[String] = []
var sounds: Array[String] = []
var _last_edge := [Mode.WANDER, Mode.WANDER]
var _ready_in := 0.0
# movement and modes
var _path: Array[Vector3i] = []
var _repath := 0.0
var _mode_left := 0.0
var _unfilmed := 0.0
var _filmed_time_last := 0.0
var _filmed_time := 0.0
var _shout_in := 0.0
var _where_in := 4.0
# CHASE
var _chase_goal := Vector3.ZERO
var _lost := false
# WANDER
var _wander_to := NO_CELL
var _wander_pause := 0.0
var _wander_up := false
var _visited := {}  # room -> clock
# SEARCH
var _search: Array[Dictionary] = []  # {cell, spot}
var _pause := 0.0
var _checking: HideSpot
# LURK / AMBUSH
var _hide := NO_CELL
var _hide_dir := Vector3.ZERO
var _ambush_at := NO_CELL
var _ceiling := false  # this wait is on the ceiling, not behind a corner
# Found out while it lay in wait (filmed): it stares, cries out, then fury.
var _found_out := false
var _found_t := 0.0
var _shrieked := false
var _fury := 0.0
var _behind_t := -1.0
var _grace := 0.0
## The hiding place it is leaning into (Mode.PEEK).
var _peek_spot: HideSpot
## Time spent lying in wait lately (it must not camp: Tuning.CAMP_MAX).
var _camp := 0.0
## Enraged: how soon it sniffs towards somebody again.
var _rage_sniff := 0.0
## Going over a stable door (along the ceiling).
var _over_door := false
## Up on the ceiling for a door's window: this long more once past it.
var _ceiling_hold := 0.0
const CEILING_HOLD := 1.6
## It climbs up this far before a door with a broken window.
const TRANSOM_REACH := 2.3
var _feeding_for := 0.0
## Carrying off the one it just took (it pays nobody any mind until it is done).
var _taking_away := false
## Running presentation: when the next jerk comes, the frame held, the twitch.
var _face: Sprite3D
var _jerk_t := 0.0
var _jerk_col := 0
var _twitch := Vector3.ZERO
var _behind_dir := Vector3.BACK
var _turned_t := 0.0
var _burst := 0.0
# The flash: who burned it, where it runs to, how long it lies low, and from
# which side it came last time (it comes back another way).
var _flash_immune := 0.0
var _stagger := 0.0
var _burned_by: Player
var _flee_to := NO_CELL
var _recover := 0.0
var _last_attack_dir := Vector3.ZERO
var _peek_in := 2.0
var _peek_left := 0.0
var _peek := 0.0
var _corner_time := 0.0
# CORPSE
var _corpse: Corpse
var _drag_to := NO_CELL
var _drag_left := 0.0
# presentation
var _step_acc := 0.0
var _last_pos := Vector3.ZERO
var _boil_t := 0.0
var _stride := 0.0
var _gait_speed := 0.0
var _flash := 0.0
var _glitch := 0.0
var _shown_state := State.DORMANT
var _sting_cooldown := 0.0
var _was_on_cam := false
var _scare := 0.0
var _burn := 0.0
var _turn := 0.0
var _song_on := true
var _song_left := 10.0
var _sprite: Sprite3D
## In 3D (Net.entity_style 2): the puppet instead of the drawing, and what it
## was last told (Replay records it): [pose, cycle, yaw, ceiling, tint, size, jerky].
var _model: EntityModel
var model_args: Array = []
var _model_yaw := 0.0
var _model_last := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

@onready var jingle: AudioStreamPlayer3D = $Jingle
@onready var drone: AudioStreamPlayer3D = $Drone
@onready var voice: AudioStreamPlayer3D = $Voice
@onready var steps: AudioStreamPlayer3D = $Steps
## Its breath on your neck while it stalks you from behind.
var _breath := AudioStreamPlayer3D.new()


func _ready() -> void:
	_build_sprite()
	jingle.stream = Sfx.get_stream("jingle", true)
	jingle.play()
	drone.stream = Sfx.get_stream("drone", true)
	drone.play()
	steps.stream = Sfx.get_stream("entity_step")
	voice.volume_db = VOICE_DB
	_breath.stream = Sfx.get_stream("neck_breath", true)
	_breath.unit_size = 0.8
	_breath.max_distance = 6.0
	_breath.position = Vector3.UP * 1.5
	add_child(_breath)
	_breath.volume_db = LOUD
	drone.volume_db += LOUD
	for player: AudioStreamPlayer3D in [jingle, drone, voice, steps, _breath]:
		player.bus = "Effects"
		player.max_db = MAX_DB
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["net_pos", "state", "pose", "tapes", "enraged", "mode", "on_ceiling", "quiet", "peek_low", "vanishing", "gone"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	sync.replication_interval = 1.0 / 30.0
	add_child(sync)


func wake() -> void:
	if state == State.DORMANT:
		state = State.STALKING
		_set_mode(Mode.WANDER, 0.0, "despierta")
		# It comes in as far as it can from everyone (nobody is taken the
		# moment the broadcast ends) and says nothing until the TV is left
		# alone (Run calls cry()); then one sound, far off, where it is, and
		# for a while no sound at all.
		_grace = Tuning.WAKE_GRACE
		quiet = true
		cry_pending = true
		_far_from_everyone()
		director = Director.new()
		director.setup(self)
		director.hold(4.0)  # a moment before the first nudge


## Host: the cry it comes in with (once nobody is at the TV any more).
func cry() -> void:
	if cry_pending:
		cry_pending = false
		_wake_cry.rpc(global_position)


func speed() -> float:
	var s := Tuning.ENTITY_SPEED + Tuning.ENTITY_SPEED_PER_TAPE * tapes
	if Net.is_solo():
		s *= Tuning.SOLO_ENTITY_SPEED_MULT
	if _fury > 0.0:
		s *= Tuning.FURY_SPEED_MULT
	if _burst > 0.0:
		s *= Tuning.BURST_SPEED_MULT
	return s * Tuning.RAGE_SPEED_MULT if enraged else s


## 0 with no tapes taken, 1 with all of them: it gets bolder.
func aggression() -> float:
	return clampf(float(tapes) / maxf(1.0, Net.tape_count), 0.0, 1.0)


## Whether `p` is filming it right now: camcorder up, inside the frame,
## within range and not behind a wall (head or chest is enough).
func is_filmed_by(p: Player) -> bool:
	if not p.camcorder.filming or gone:
		return false
	var view := _view_of(p)
	var space := get_world_3d().direct_space_state
	for h: float in [0.6, 1.0, 1.4, 1.95]:  # (low too: seen between the boards, crouched)
		var point := global_position + Vector3.UP * h
		if not _in_frame(p, view, point):
			continue
		if view.origin.distance_to(point) > Tuning.FILM_RANGE:
			continue
		var q := PhysicsRayQueryParameters3D.create(view.origin, point, Tuning.LAYER_WORLD)
		if space.intersect_ray(q).is_empty():
			return true
	return false


## Where `p` films from: their own camera on their machine; for the others,
## the view they last sent (position, yaw, pitch), not the smoothed body.
func _view_of(p: Player) -> Transform3D:
	if p.is_local:
		return p.camera.global_transform
	var eye := p.camera.global_position - p.global_position
	return Transform3D(Basis.from_euler(Vector3(p.net_pitch, p.net_yaw, 0.0)), p.net_pos + eye)


func _in_frame(p: Player, view: Transform3D, point: Vector3) -> bool:
	if p.is_local:
		return p.camera.is_position_in_frustum(point)
	var local := view.affine_inverse() * point
	if local.z > -0.05:
		return false
	var fov := lerpf(Tuning.FOV, Tuning.FILM_FOV, smoothstep(0.0, 1.0, p.net_raise))
	var t := tan(deg_to_rad(fov * 0.5)) * -local.z
	return absf(local.y) <= t and absf(local.x) <= t * (16.0 / 9.0)


## The capture (host): it stands right in front of the camera, mouth open
## (under a bed: its face at the floor, looking in).
func lunge_at(p: Player) -> void:
	_drop_corpse()
	state = State.FEEDING
	pose = Pose.LUNGE
	var cam := p.camera
	var front := cam.global_position - cam.global_transform.basis.z * 0.85
	global_position = Vector3(front.x, cam.global_position.y - LUNGE_FACE_HEIGHT, front.z)
	net_pos = global_position


## Local (the one taken): its face cutting in and out of the lens.
func screamer(seconds: float) -> void:
	_scare = seconds


## Host: after taking someone, it goes on with the rest (it does not know
## where they are).
func resume() -> void:
	state = State.STALKING
	pose = Pose.STAND
	if is_piloted():
		_set_mode(Mode.WANDER, 0.0, "suelta a su presa (jugador)")
		return
	global_position = level.center(level.nearest_walkable(level.cell_of(global_position)))
	_clue_age = INF
	_seen.clear()
	# It takes the body away with it and leaves it somewhere far: the
	# others get a moment to get away.
	var body: Corpse = null
	for c in corpses:
		if is_instance_valid(c) and c.is_free() and c.global_position.distance_to(global_position) < 3.5:
			body = c
	if body and not _alive().is_empty():
		_corpse = body
		_taking_away = true
		_set_mode(Mode.CORPSE, 25.0, "se lleva el cuerpo")
		return
	_set_mode(Mode.WANDER, 0.0, "vuelve tras atrapar a alguien")


## Host: a noise at `pos` that carries `radius` steps through the house
## (Run: tapes and batteries taken, camcorders dropped or picked up).
func hear(pos: Vector3, radius: float) -> void:
	if state == State.DORMANT or level == null or is_piloted():
		return
	if _steps_to(pos) <= radius:
		_clue_pos = level.center(level.nearest_walkable(level.cell_of(pos)))
		_clue_age = 0.0
		_clue_player = null
		_clue_precise = false
		_clue_seen = false
		_heard_new = true


## Host (Director): a vague nudge towards somewhere.
func hint(pos: Vector3) -> void:
	_clue_pos = pos
	_clue_age = 0.0
	_clue_player = null
	_clue_precise = false
	_clue_seen = false
	if mode in [Mode.WANDER, Mode.SEARCH] or (mode == Mode.CORPSE and not _carrying()):
		_set_mode(Mode.INVESTIGATE, 20.0, "pista vaga del director")


## Host (Director): go and wait behind a corner of `dest`, where `p` is
## going, out of their sight. False if there is no such corner (or it is busy).
func ambush(p: Player, dest: Vector3i) -> bool:
	if mode in [Mode.CHASE, Mode.FOLLOW, Mode.PEEK] or _carrying() or enraged or hunt_only or camping():
		return false
	var look := level.center(dest) + Vector3.UP * 1.4
	var up := _rng.randf() < 0.5 and _pick_ceiling(level.nearest_walkable(level.cell_of(p.global_position)), dest)
	if not up and not _pick_corner(dest, [p.camera.global_position, look], look, 2, 7):
		return false
	target = p
	_ambush_at = dest
	_set_mode(Mode.AMBUSH, Tuning.AMBUSH_TIME, "emboscada del director" + (" (en el techo)" if up else ""))
	_ceiling = up
	return true


## A cell on the way from `from` to `to`, 2-4 steps short of `to` (a
## doorway if there is one): it will wait on the ceiling above it.
func _pick_ceiling(from: Vector3i, to: Vector3i) -> bool:
	var route := level.path(from, to)
	if route.size() < 4:
		return false
	var best := NO_CELL
	for i in range(maxi(0, route.size() - 5), route.size() - 2):
		var c := route[i]
		if level.char_at(c) == "S" or _too_close(c):
			continue
		if best.x < 0 or level.char_at(c) == "D":
			best = c
	if best.x < 0:
		return false
	_hide = best
	_hide_dir = Vector3.ZERO
	return true


## Is `p` facing away from it (their back to it)?
func _back_to_me(p: Player) -> bool:
	var fwd := -_view_of(p).basis.z
	var to_me := _flat(global_position - p.global_position).normalized()
	return Vector3(fwd.x, 0, fwd.z).normalized().dot(to_me) < -0.35


## Stealth: silent and very fast up to just behind them. There it breathes
## "te estoy viendo"... and waits. The moment they turn round and see it,
## it takes them. If they never turn, after 5 s it takes them anyway. Only
## a flash (theirs, if they are quick, or a friend's) saves them.
func _stalk(delta: float) -> void:
	if target == null or not target.alive or target.is_hidden():
		_mode_left = 0.0
		return
	var back := _flat(_view_of(target).basis.z).normalized()
	var spot := target.global_position + back * Tuning.STALK_DISTANCE
	var cell := level.cell_of(spot)
	if not level.is_walkable(cell):
		spot = target.global_position + back * 0.6
	if _behind_t < 0.0:
		# Closing in, silent, fast.
		_walk_to(spot, speed() * Tuning.STALK_SPEED_MULT * delta, delta)
		if _flat(spot - global_position).length() < 0.5:
			_behind_t = 0.0
			_behind_dir = back  # it stays on that side: turning round finds it
			_turned_t = 0.0
			_say("voice_line")  # right at their ear: "te estoy viendo"
			_note(events, "detrás de %s" % target.display_name)
		return
	# Right behind them, keeping there as they walk (not as they turn).
	spot = target.global_position + _behind_dir * Tuning.STALK_DISTANCE
	if not level.is_walkable(level.cell_of(spot)):
		spot = target.global_position + _behind_dir * 0.6
	global_position = global_position.lerp(Vector3(spot.x, target.global_position.y, spot.z), minf(1.0, delta * 10.0))
	_behind_t += delta
	var view := _view_of(target)
	var sees_me := false
	for h: float in [1.0, 1.7]:
		var point := global_position + Vector3.UP * h
		var local := view.affine_inverse() * point
		if local.z < -0.05 and absf(local.x) < -local.z * 1.2 and absf(local.y) < -local.z * 0.9:
			sees_me = true
	if sees_me:
		_turned_t += delta  # they turned round: a heartbeat, then
	if _turned_t > Tuning.STALK_REACTION or _behind_t > Tuning.STALK_LIMIT:
		_note(events, ("%s se da la vuelta" if _turned_t > 0.0 else "%s no se gira a tiempo") % target.display_name)
		state = State.FEEDING
		caught.emit(target)


## Host: would a flash from `p` right now catch it? (Their camcorder up,
## it in their frame, close enough, nothing in between.)
func flash_hits(p: Player) -> bool:
	if state == State.DORMANT or state == State.FEEDING or _flash_immune > 0.0 or mode == Mode.FLEE or vanishing or gone:
		return false
	var view := _view_of(p)
	if mode == Mode.PEEK and p == target:
		# Its face, right at the opening of where they hide.
		return _in_flash(p, view, global_position + Vector3.UP * PEEK_FACE_HEIGHT * (PEEK_LOW_SCALE if peek_low else 1.0))
	var space := get_world_3d().direct_space_state
	# Anywhere on its body, and where it looks from: if it can see you past
	# a door frame, your flash reaches it too. Hanging from the ceiling its
	# body hangs down from there.
	var heights: Array[float] = [EYE, 0.4, 0.9, 1.4, 1.9]
	if on_ceiling:
		heights = [EYE, Level.HEIGHT - 0.3, Level.HEIGHT - 0.8, Level.HEIGHT - 1.3, Level.HEIGHT - 1.8]
	var side := view.basis.x.normalized() * 0.3
	for h: float in heights:
		for off: Vector3 in [Vector3.ZERO, side, -side]:
			var point := global_position + Vector3.UP * h + off
			if not _in_flash(p, view, point) or view.origin.distance_to(point) > Tuning.FLASH_RANGE:
				continue
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(view.origin, point, Tuning.LAYER_WORLD)).is_empty():
				return true
	return false


## In the frame, with some slack: the flash lights more than the picture.
func _in_flash(p: Player, view: Transform3D, point: Vector3) -> bool:
	var local := view.affine_inverse() * point
	if local.z > -0.05:
		return false
	var fov: float = p.camera.fov if p.is_local else lerpf(Tuning.FOV, Tuning.FILM_FOV, smoothstep(0.0, 1.0, p.net_raise))
	var t := tan(deg_to_rad(fov * 0.5)) * -local.z * Tuning.FLASH_SLACK
	return absf(local.y) <= t and absf(local.x) <= t * (16.0 / 9.0)


## Host: the flash caught it. It screams in agony and runs on all fours to
## somewhere far from whoever burned it, out of their sight; there it lies
## low for a while, then comes back another way (_comeback). Enraged, it
## only reels for a moment.
func flashed(p: Player) -> void:
	# In company the flashes do not chain: after one, it shrugs the next
	# ones off for a while (more players, longer).
	_flash_immune = Tuning.FLASH_IMMUNE + Tuning.FLASH_IMMUNE_PER_FRIEND * (_alive().size() - 1)
	_say("voice_agony")
	_note(events, "el flash de %s la quema" % p.display_name)
	if enraged or hunt_only:
		_stagger = Tuning.FLASH_STAGGER
		return
	_drop_corpse()
	_found_out = false
	_burn_fx.rpc()
	_burned_by = p
	_last_attack_dir = _flat(global_position - p.global_position).normalized()
	# It does not run: it comes apart where it stands, and is gone.
	on_ceiling = false
	vanishing = true
	_vanish_left = VANISH_TIME
	_vanish_fx.rpc(global_position)
	_note(events, "se deshace con el flash de %s" % p.display_name)


## Host: gone, it is put where it will come back from: out of everyone's
## sight, at a fair distance (8-15 steps from the nearest of them), as near
## as it can to where the one who burned it is going.
func _strategic_cell() -> Vector3i:
	var alive := _alive()
	var maps: Array[Dictionary] = []
	for q in alive:
		maps.append(level.layout.distances(level.nearest_walkable(level.cell_of(q.global_position))))
	if maps.is_empty():
		return level.nearest_walkable(level.cell_of(global_position))
	var dest := director.predict(_burned_by) if director and _burned_by and _burned_by.alive else NO_CELL
	var to_dest := level.layout.distances(dest) if dest.x >= 0 else {}
	var space := get_world_3d().direct_space_state
	var best := NO_CELL
	var best_score := -INF
	for c: Vector3i in maps[0].keys():
		var d := 9999
		for m in maps:
			d = mini(d, int(m.get(c, 9999)))
		if d < 8 or d > 15:
			continue
		# Far in a straight line too (8 steps round can be just the other
		# side of a wall, or right overhead on the floor above).
		var close := false
		for q in alive:
			var off := level.center(c) - q.global_position
			if off.length() < 7.0 or Vector2(off.x, off.z).length() < 5.0:
				close = true
				break
		if close:
			continue
		var seen := false
		for q in alive:
			if q.camera.global_position.distance_to(level.center(c)) < 16.0 and _clear(space, q.camera.global_position, level.center(c) + Vector3.UP * 1.2):
				seen = true
				break
		if seen:
			continue
		var score := -absf(d - 11.0) + _rng.randf() * 1.5
		if to_dest.has(c):
			score += maxf(0.0, 7.0 - float(to_dest[c])) * 0.8  # waiting where they are going
		if score > best_score:
			best_score = score
			best = c
	if best.x < 0:
		_far_from_everyone()
		return level.cell_of(global_position)
	return best


## Every machine: it comes apart: a burst of ash and soot, a tearing of static.
@rpc("authority", "call_local", "reliable")
func _vanish_fx(at: Vector3) -> void:
	_vanish_t = 0.0
	Sfx.play_3d(get_parent(), at + Vector3.UP * 1.2, "static", -12.0)  # (a tear, not a blast: it was far too loud)
	var ash := CPUParticles3D.new()
	ash.one_shot = true
	ash.explosiveness = 0.85
	ash.amount = 90
	ash.lifetime = 1.6
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(0.3, 1.0, 0.3)
	ash.direction = Vector3.UP
	ash.spread = 70.0
	ash.initial_velocity_min = 0.4
	ash.initial_velocity_max = 2.2
	ash.gravity = Vector3(0, 0.6, 0)
	ash.damping_min = 1.0
	ash.damping_max = 2.5
	ash.scale_amount_min = 0.5
	ash.scale_amount_max = 1.6
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	ash.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.9, 0.25, 0.12, 1.0))   # embers first...
	ramp.add_point(0.25, Color(0.08, 0.05, 0.05, 1.0))  # ...then soot
	ramp.set_color(ramp.get_point_count() - 1, Color(0.02, 0.02, 0.02, 0.0))
	ash.color_ramp = ramp
	get_parent().add_child(ash)
	ash.global_position = at + Vector3.UP * 1.1
	ash.emitting = true
	get_tree().create_timer(2.5).timeout.connect(ash.queue_free)


func _flee(delta: float) -> void:
	if _flee_to.x < 0:
		_mode_left = 0.0
	else:
		_walk_to(level.center(_flee_to), speed() * Tuning.FLEE_SPEED_MULT * delta, delta)
		if _flat(level.center(_flee_to) - global_position).length() < 0.4:
			_mode_left = 0.0
	if _mode_left <= 0.0:
		# Out of sight: it lies low, silent, then plans its way back.
		var crowd := clampf((_alive().size() - 1) / 3.0, 0.0, 1.0)  # in company it is back sooner
		_recover = _rng.randf_range(Tuning.RECOVER_MIN, Tuning.RECOVER_MAX) * lerpf(1.0, 0.35, crowd)
		_set_mode(Mode.WANDER, 0.0, "se esconde a recuperarse")
		_wander_pause = _recover


## Back from licking its wounds: never the same way twice. From the other
## side of whoever burned it, from the ceiling over where they go, behind
## them, or after somebody else.
func _comeback(alive: Array[Player]) -> void:
	var who := _burned_by if _burned_by and _burned_by.alive else null
	var others := alive.filter(func(q: Player) -> bool: return q != who and not q.is_hidden())
	var r := _rng.randf()
	if who == null or (r < 0.2 and not others.is_empty()):
		var other: Player = others[_rng.randi() % others.size()] if not others.is_empty() else who
		if other:
			target = other
			_learn(other, false, false)
			_set_mode(Mode.INVESTIGATE, 20.0, "vuelve a por otro")
		return
	target = who
	_learn(who, true, false)
	if r < 0.55 and not camping() and _flank(who):
		_set_mode(Mode.LURK, _rng.randf_range(7.0, 11.0), "vuelve por el otro lado")
		return
	var dest := director.predict(who) if director else NO_CELL
	if r < 0.8 and dest.x >= 0 and not camping() and _pick_ceiling(level.nearest_walkable(level.cell_of(who.global_position)), dest):
		_set_mode(Mode.AMBUSH, Tuning.AMBUSH_TIME, "vuelve por el techo")
		_ceiling = true
		return
	_set_mode(Mode.FOLLOW, _rng.randf_range(14.0, 22.0), "vuelve por detrás, en silencio")


## A corner near `p` on the side away from where it came at them last time.
func _flank(p: Player) -> bool:
	var at := level.nearest_walkable(level.cell_of(p.global_position))
	var dist := level.layout.distances(at)
	var space := get_world_3d().direct_space_state
	var eye := p.camera.global_position
	var best := INF
	var found := NO_CELL
	var found_dir := Vector3.ZERO
	for c: Vector3i in dist.keys():
		var n := int(dist[c])
		if n < 3 or n > 8 or c.y != at.y:
			continue
		var side := _flat(level.center(c) - p.global_position).normalized()
		if side.dot(_last_attack_dir) > -0.2 or _too_close(c):
			continue  # not from the same side again, never right beside them
		if _clear(space, eye, level.center(c) + Vector3.UP * 1.4):
			continue
		for d in Level.DIRS:
			var nb := c + Vector3i(d.x, 0, d.y)
			if level.is_walkable(nb) and _clear(space, eye, level.center(nb) + Vector3.UP * 1.4):
				var score := float(n) + _rng.randf() * 2.0
				if score < best:
					best = score
					found = c
					found_dir = Vector3(d.x, 0, d.y)
				break
	if found.x < 0:
		return false
	_hide = found
	_hide_dir = found_dir
	return true


## A hiding place must not be right next to anyone (it would seem to
## appear out of thin air at their side).
func _too_close(c: Vector3i) -> bool:
	var at := level.center(c)
	for p in _alive():
		if absf(at.y - p.global_position.y) < 1.5 and _flat(at - p.global_position).length() < Tuning.HIDE_MIN_DIST:
			return true
	return false


## Busy with someone, or close to someone (the Director leaves it alone).
func engaged(alive: Array[Player]) -> bool:
	if mode in [Mode.CHASE, Mode.FOLLOW, Mode.LURK, Mode.AMBUSH, Mode.FLEE, Mode.STALK] or _recover > 0.0:
		return true
	for p in alive:
		if _steps_to(p.global_position) <= 3:
			return true
	return false


func velocity_of(p: Player) -> Vector3:
	return _motion[p][1] if _motion.has(p) else Vector3.ZERO


func is_alone(p: Player, alive: Array[Player]) -> bool:
	for q in alive:
		if q != p and q.global_position.distance_to(p.global_position) < Tuning.LONE_RANGE:
			return false
	return true


## Its voice is not a beacon: half the time it throws it, and the line
## comes from a room 6-12 steps away from where it really is.
func _speak(line: String) -> void:
	if quiet:
		return
	if _rng.randf() < Tuning.VOICE_THROW_CHANCE:
		var far: Array[Vector3i] = []
		for c: Vector3i in _dist.keys():
			if int(_dist[c]) >= 6 and int(_dist[c]) <= 12:
				far.append(c)
		if not far.is_empty():
			_say_at.rpc(_take(line), level.center(far[_rng.randi() % far.size()]) + Vector3.UP * 1.6)
			return
	_say(line)


@rpc("authority", "call_local", "reliable")
func _say_at(line: String, at: Vector3) -> void:
	_note(sounds, line + " (lanzada)")
	Sfx.play_3d(get_parent(), at, line, VOICE_DB, MAX_DB)


## "¿Dónde estás?" in one of its three versions (never the same twice running).
func _where_line() -> String:
	var lines := ["voice_where", "voice_where2", "voice_where3"]
	if not sounds.is_empty():
		for l in lines:
			if sounds[0].ends_with(l):
				lines.erase(l)
				break
	return lines[_rng.randi() % lines.size()]


func _note(list: Array[String], text: String) -> void:
	var t := Time.get_ticks_msec() / 1000
	list.push_front("%02d:%02d  %s" % [t / 60 % 60, t % 60, text])
	if list.size() > 12:
		list.resize(12)


## For the monitor (Alt+F1). Only the host knows its mind; elsewhere the
## knowledge fields are empty.
func debug_info() -> Dictionary:
	return {
		"state": state, "mode": mode, "mode_left": _mode_left, "edge": _last_edge,
		"target": target.display_name if target else "",
		"seen": _seen.map(func(p: Player) -> String: return p.display_name),
		"clue_age": _clue_age, "clue_seen": _clue_seen, "clue_precise": _clue_precise,
		"clue_spot": String(_clue_spot.name) if _clue_spot else "",
		"calm": director._calm if director else 0.0,
		"patience": director._patience() if director else 0.0,
		"enraged": enraged, "pose": Pose.keys()[pose],
	}


## Where it thinks someone is (for tests and the F3 overlay): INF age = no idea.
func clue_age() -> float:
	return _clue_age


func is_piloted() -> bool:
	return pilot_id != 0


func _physics_process(delta: float) -> void:
	if piloted_here and state != State.FEEDING and not (is_multiplayer_authority() and mode == Mode.PEEK):
		if is_multiplayer_authority():
			_pilot_host_tick(delta)
		return  # (EntityPilot moves it)
	if not is_multiplayer_authority():
		global_position = global_position.lerp(net_pos, minf(1.0, delta * 10.0))
		return
	if is_piloted():
		_pilot_host_tick(delta)
		return
	# Never stuck holding someone (a catch that was not followed up).
	_feeding_for = _feeding_for + delta if state == State.FEEDING else 0.0
	if _feeding_for > 6.0 and not _alive().is_empty():
		_note(events, "se suelta (atascada)")
		resume()
	if state == State.STALKING or state == State.FROZEN:
		_think(delta)
		_door_guard()
	net_pos = global_position


## Host, played by someone: no mind of its own, only the clocks.
func _pilot_host_tick(delta: float) -> void:
	_flash_immune = maxf(0.0, _flash_immune - delta)
	if _grace > 0.0 and not cry_pending:
		_grace -= delta
		if _grace <= 0.0:
			quiet = false
	net_pos = global_position


func _alive() -> Array[Player]:
	var out: Array[Player] = []
	for p in players:
		if is_instance_valid(p) and p.alive:
			out.append(p)
	return out


func _process(delta: float) -> void:
	_present(delta)


# --- the mind (host) ----------------------------------------------------------------

func _think(delta: float) -> void:
	var alive := _alive()
	if alive.is_empty():
		return
	_clock += delta
	var filmer: Player = null
	for p in alive:
		if is_filmed_by(p):
			filmer = p
	_fury = maxf(0.0, _fury - delta)
	_burst = maxf(0.0, _burst - delta)
	_flash_immune = maxf(0.0, _flash_immune - delta)
	# Burned by the flash: coming apart, then gone (somewhere else, unseen,
	# silent), then back from there.
	if vanishing:
		_vanish_left -= delta
		if _vanish_left <= 0.0:
			vanishing = false
			gone = true
			# (The mode first: leaving PEEK puts it back by the hiding place,
			# which must not undo where it goes: it came back right on you.)
			_set_mode(Mode.WANDER, 0.0, "desaparece; volverá desde otro sitio")
			on_ceiling = false
			global_position = level.center(_strategic_cell())
			net_pos = global_position
			var crowd := clampf((alive.size() - 1) / 3.0, 0.0, 1.0)
			_gone_left = _rng.randf_range(Tuning.RECOVER_MIN, Tuning.RECOVER_MAX) * lerpf(1.0, 0.45, crowd)
		return
	if gone:
		_gone_left -= delta
		if _gone_left <= 0.0:
			gone = false
			_comeback(alive)
		return
	# Stunned by a flash (enraged): it reels where it stands.
	if _stagger > 0.0:
		_stagger -= delta
		state = State.FROZEN
		return
	state = State.STALKING
	# Caught on camera while it lay in wait (corner, ceiling): it is found
	# out. It stays where it is, looking at you; after 2 s, "¡te estoy
	# viendo!", and it comes.
	# Only if it sees you filming it: otherwise it does not know.
	if filmer and (mode == Mode.LURK or mode == Mode.AMBUSH) and not _found_out and _sees_now(filmer):
		_found_out = true
		_found_t = 0.0
		_shrieked = false
		target = filmer
		pose = Pose.STAND
		_learn(filmer, true, true)
		_note(events, "%s la descubre esperando" % filmer.display_name)
	if _found_out:
		_found_t += delta
		# It looks at you, and its neck grows: the head comes at you on it,
		# smiling. Then it screams and runs.
		if _found_t > 0.35:
			pose = Pose.STRETCH
		if _found_t >= Tuning.FOUND_OUT_STARE and not _shrieked:
			_shrieked = true
			pose = Pose.STAND
			_scream()
			moment.emit("found", target)
	if _found_out:
		# Staring back at you until the 2 s are up, then it comes, furious.
		if not _shrieked:
			return
		_found_out = false
		_fury = Tuning.FURY_TIME
		_burst = Tuning.BURST_TIME  # it bursts out at you, far too fast
		if on_ceiling:
			_drop_fx.rpc()
		_start_chase("la has descubierto: viene furiosa")
	# (Seeing it while it walks about does not tell it where you are.)
	_unfilmed += delta
	_clue_age += delta
	if _ready_in > 0.0:
		_ready_in -= delta
		if _ready_in <= 0.0:
			_say("voice_ready")
	_shout_in -= delta
	_sense_in -= delta
	if _sense_in <= 0.0:
		_sense_in = SENSE_EVERY
		_sense(alive)
	_decide(alive, delta)
	if director and not enraged and not hunt_only:
		director.tick(delta, alive)
	match mode:
		Mode.CHASE:
			_chase(delta)
		Mode.FOLLOW:
			_follow(delta)
		Mode.LURK, Mode.AMBUSH:
			_wait_at_corner(delta, alive)
		Mode.CORPSE:
			_play_with_body(delta)
		Mode.WANDER:
			_wander(delta, alive)
		Mode.INVESTIGATE:
			_investigate(delta)
		Mode.SEARCH:
			_search_around(delta, alive)
		Mode.FLEE:
			_flee(delta)
		Mode.STALK:
			_stalk(delta)
		Mode.PEEK:
			_peek_hidden()
	_camp = clampf(_camp + (delta if mode in [Mode.LURK, Mode.AMBUSH] else -delta * 0.5), 0.0, Tuning.CAMP_MAX * 2.0)
	if mode != Mode.FOLLOW:
		_stared = 0.0
	_watch_stuck(delta)
	if state == State.STALKING:
		_try_catch(alive)


# --- senses ----------------------------------------------------------------------

func _sense(alive: Array[Player]) -> void:
	_seen.clear()
	_dist = level.layout.distances(level.nearest_walkable(level.cell_of(global_position)))
	var space := get_world_3d().direct_space_state
	for p in alive:
		var m: Array = _motion.get(p, [p.global_position, Vector3.ZERO])
		var vel: Vector3 = (p.global_position - m[0]) / SENSE_EVERY
		_motion[p] = [p.global_position, (m[1] as Vector3).lerp(vel, 0.5)]
		if _can_see(space, p):
			_seen.append(p)
			_learn(p, true, true)
			continue
		# Gone from sight right into a hiding place: it saw where.
		if p.is_hidden() and _clue_player == p and _clue_seen and _clue_age < 1.2:
			_clue_spot = _spot_of(p)
			_clue_pos = p.global_position
		var reach := _noise_of(p)
		if reach > 0.0:
			var n := _steps_to(p.global_position)
			if n <= reach:
				_learn_heard(p, n, reach)


func _can_see(space: PhysicsDirectSpaceState3D, p: Player) -> bool:
	var eye := global_position + Vector3.UP * EYE
	var spot := _spot_of(p)
	if spot:
		if spot.conceals():
			return false
		var low := p.global_position + Vector3.UP * 0.35
		var dl := eye.distance_to(low)
		if dl > Tuning.TABLE_SIGHT and not (p.net_light and dl < Tuning.SIGHT_DARK):
			return false
		return _clear(space, eye, low)
	var crouched := p.net_crouch
	var chest := p.global_position + Vector3.UP * (0.6 if crouched else 1.15)
	var to := chest - eye
	var d := to.length()
	var reach := Tuning.SIGHT_LIGHT if p.net_light else Tuning.SIGHT_DARK
	if crouched:
		reach *= Tuning.SIGHT_CROUCH_MULT
	if d > reach:
		return false
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	# Ahead of it; from any side when very close, or when the light is on nearby.
	if d > Tuning.SIGHT_FEEL and flat.dot(_facing) < Tuning.SIGHT_CONE and not (p.net_light and d < 8.0):
		return false
	return _clear(space, eye, chest) or _clear(space, eye, p.global_position + Vector3.UP * (0.8 if crouched else 1.55))


## How many steps away its noise carries right now (0 = silent).
func _noise_of(p: Player) -> float:
	return _noise_base(p) * (Tuning.RAGE_HEARING if enraged else 1.0)


func _noise_base(p: Player) -> float:
	var r := 0.0
	if _talking(p, 0.4):
		r = Tuning.HEAR_VOICE
	if p.is_hidden():
		return r
	var v := velocity_of(p)
	var spd := Vector2(v.x, v.z).length()
	if p.net_crouch:
		if spd > 0.5:
			r = maxf(r, Tuning.HEAR_CROUCH)
	elif spd > 3.3:
		r = maxf(r, Tuning.HEAR_RUN)
	elif spd > 0.8:
		r = maxf(r, Tuning.HEAR_WALK)
	return r


func _talking(p: Player, within: float) -> bool:
	return voices != null and voices.heard.has(p.peer_id) and voices._clock - float(voices.heard[p.peer_id]) < within


func _learn(p: Player, precise: bool, seen: bool) -> void:
	_clue_player = p
	_clue_pos = p.global_position
	_clue_age = 0.0
	_clue_precise = precise
	_clue_seen = seen
	_clue_vel = velocity_of(p)
	if not p.is_hidden():
		_clue_spot = null


## Heard, not seen: roughly where (less sure the further), unless the
## sight is fresher.
func _learn_heard(p: Player, n: int, reach: float) -> void:
	if _clue_seen and _clue_age < 0.6:
		return
	var err := 2.5 * float(n) / reach
	var guess := p.global_position + Vector3(_rng.randf_range(-err, err), 0.0, _rng.randf_range(-err, err))
	_clue_pos = level.center(level.nearest_walkable(level.cell_of(guess)))
	_clue_player = p
	_clue_age = 0.0
	_clue_precise = n <= 2
	_clue_seen = false
	_heard_new = true
	# Talking in a hiding place with it close by gives the place away.
	if p.is_hidden() and n <= 4 and _talking(p, 0.4):
		_clue_spot = _spot_of(p)
		_clue_precise = true
		_clue_pos = p.global_position


func _steps_to(pos: Vector3) -> int:
	if _dist.is_empty():
		_dist = level.layout.distances(level.nearest_walkable(level.cell_of(global_position)))
	return int(_dist.get(level.nearest_walkable(level.cell_of(pos)), 999))


func _spot_of(p: Player) -> HideSpot:
	if not p.is_hidden():
		return null
	return level.get_node_or_null(p.net_hide) as HideSpot


func _clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Tuning.LAYER_WORLD)).is_empty()


# --- deciding --------------------------------------------------------------------

func _decide(alive: Array[Player], delta: float) -> void:
	_mode_left -= delta
	if _grace > 0.0 and not cry_pending:
		# Just woken: silent for a while after its cry (it hunts all the same).
		_grace -= delta
		if _grace <= 0.0:
			quiet = false
			_where_in = _rng.randf_range(3.0, 8.0)  # and then it starts to be heard
	if mode == Mode.FLEE:
		_heard_new = false
		return
	if _recover > 0.0:
		_recover -= delta
		_heard_new = false
		if _recover <= 0.0:
			_comeback(alive)
		return
	if mode == Mode.PEEK:
		return  # leaning into a hiding place: nothing else matters
	if enraged and not hunt_only:
		# It does not know where you are, but it hunts harder: every few
		# seconds it goes to sniff around somebody (roughly where), and it
		# hears further and checks more hiding places (_noise_of, _plan_search).
		_rage_sniff -= delta
		if _rage_sniff <= 0.0 and _seen.is_empty() and mode in [Mode.WANDER, Mode.SEARCH] and director:
			_rage_sniff = Tuning.RAGE_SNIFF_EVERY
			var who := director.pick(alive)
			if who:
				hint(director.vague(who))
	if hunt_only:
		# (Debug: it knows where everyone is... except who is hiding.)
		var t := _nearest_open(alive)
		if t:
			target = t
			_learn(t, true, true)
			_seen.clear()
			_seen.append(t)
			if mode != Mode.CHASE:
				_set_mode(Mode.CHASE, 999.0, "enfurecida: sabe dónde estáis")
			return
	if not _seen.is_empty():
		# Someone it can see in a hiding place (under a table): once it is
		# at the opening, it leans in, like anywhere else.
		for q in _seen:
			var sp := _spot_of(q)
			if sp and global_position.distance_to(level.center(sp.access)) < 1.6:
				_peek_into(sp, q)
				return
		var p := _seen[0]
		for q in _seen:
			if _pull(q) < _pull(p):
				p = q
		match mode:
			Mode.CHASE, Mode.FOLLOW, Mode.STALK:
				if mode == Mode.CHASE:
					target = p
			Mode.LURK, Mode.AMBUSH:
				# Close enough to jump out.
				if global_position.distance_to(p.global_position) < 3.2:
					target = p
					_start_chase("sale de la esquina")
			Mode.CORPSE:
				if _taking_away:
					pass  # carrying off its kill: not now
				elif _carrying():
					_drag_left = minf(_drag_left, 0.4)  # throws it at them
				else:
					_react(p, alive)
			_:
				_react(p, alive)
		_heard_new = false
		return
	match mode:
		Mode.FOLLOW:
			if _clue_age > 4.0:
				_start_search("pierde al que seguía")
		Mode.STALK:
			if _clue_age > 3.0 and _behind_t < 0.0:
				_start_search("pierde a quien acechaba")
		Mode.WANDER:
			if _heard_new:
				if not _hide_from_noise():
					_set_mode(Mode.INVESTIGATE, 20.0, "oye algo")
		Mode.CORPSE:
			if _heard_new and not _carrying() and not _taking_away:
				_drop_corpse()
				_set_mode(Mode.INVESTIGATE, 20.0, "oye algo y suelta el cuerpo")
		Mode.SEARCH:
			if _heard_new and _search_far():
				_set_mode(Mode.INVESTIGATE, 20.0, "oye algo en otro sitio")
	_heard_new = false
	if _mode_left <= 0.0:
		match mode:
			Mode.CHASE, Mode.FOLLOW, Mode.LURK, Mode.INVESTIGATE:
				_start_search("se acaba el tiempo")
			Mode.SEARCH:
				if _rng.randf() < 0.4:
					_speak("voice_frustrated")
				_set_mode(Mode.WANDER, 0.0, "no encuentra a nadie")
				if director:
					director.search_failed(alive)
			Mode.AMBUSH:
				# Nobody came: frustrated, and the Director may set another.
				if _rng.randf() < 0.3:
					_speak("voice_frustrated")
				_set_mode(Mode.WANDER, 0.0, "nadie pasa por la emboscada")
				if director:
					director.search_failed(alive)
			Mode.CORPSE:
				_drop_corpse()
				_set_mode(Mode.WANDER, 0.0, "se cansa del cuerpo")


## It just spotted someone: chase, or something worse.
func _react(p: Player, alive: Array[Player]) -> void:
	target = p
	if enraged:
		_start_chase("te ve (enfurecida)")
		return
	var d := global_position.distance_to(p.global_position)
	var bold := aggression()
	var r := _rng.randf()
	# Their back to it: silence, and it is behind them before they know.
	if d > 2.5 and _back_to_me(p) and r < (0.75 if is_alone(p, alive) else 0.5):
		_behind_t = -1.0
		_set_mode(Mode.STALK, 20.0, "te ve de espaldas: sigilo")
		return
	if is_alone(p, alive) and d > 3.0 and r < 0.4 - bold * 0.2:
		_set_mode(Mode.FOLLOW, _rng.randf_range(14.0, 22.0), "ve a alguien solo")
	elif d > 4.0 and r < 0.8 - bold * 0.3 and not camping() and _pick_corner(level.nearest_walkable(level.cell_of(p.global_position)),
			[p.camera.global_position], p.camera.global_position, 3, 8):
		_set_mode(Mode.LURK, _rng.randf_range(6.0, 10.0), "te ve de lejos: se esconde")
	else:
		_start_chase("te ve")


## Heard someone close: half the time it does not go out to them, it gets
## behind a corner on their side and waits for them to come past.
func _hide_from_noise() -> bool:
	var p := _clue_player
	if p == null or p.is_hidden() or camping() or _rng.randf() > 0.6 or _steps_to(p.global_position) > 14:
		return false
	var at := level.nearest_walkable(level.cell_of(p.global_position))
	var up := _rng.randf() < 0.4 and _pick_ceiling(level.nearest_walkable(level.cell_of(global_position)), at)
	if not up and not _pick_corner(at, [p.camera.global_position], p.camera.global_position, 2, 6):
		return false
	target = p
	_set_mode(Mode.LURK, _rng.randf_range(7.0, 11.0), "te oye venir: se esconde" + (" en el techo" if up else ""))
	_ceiling = up
	return true


func _start_chase(why := "") -> void:
	_set_mode(Mode.CHASE, 30.0, why)
	_lost = false
	_where_in = minf(_where_in, _rng.randf_range(2.0, 4.0))
	if _shout_in <= 0.0:
		_shout_in = 8.0
		_scream()  # desperate to have you


func _start_search(why := "") -> void:
	_set_mode(Mode.SEARCH, Tuning.SEARCH_TIME, why)
	_search = _plan_search(level.nearest_walkable(level.cell_of(_clue_pos)))
	_pause = 0.0
	_checking = null
	_where_in = _rng.randf_range(0.5, 2.0)


func _set_mode(m: Mode, seconds: float, why := "") -> void:
	if m != Mode.CORPSE:
		_taking_away = false
	if mode == Mode.PEEK and m != Mode.PEEK:
		# Out of the hiding place's opening, back on the floor.
		var face := global_position + Vector3.UP * PEEK_FACE_HEIGHT * (PEEK_LOW_SCALE if peek_low else 1.0)
		global_position = level.center(level.nearest_walkable(level.cell_of(Vector3(face.x, face.y - 0.3, face.z))))
		net_pos = global_position
		peek_low = false
	if m != mode or why != "":
		_last_edge = [mode, m]
		_note(events, "%s > %s  %s" % [Mode.keys()[mode], Mode.keys()[m], why])
	if on_ceiling and m != Mode.LURK and m != Mode.AMBUSH and is_multiplayer_authority():
		_drop_fx.rpc()  # it lets go of the ceiling
	mode = m
	_mode_left = seconds
	_ceiling = false
	on_ceiling = false
	_corner_time = 0.0
	if m != Mode.LURK and m != Mode.AMBUSH:
		_found_out = false
	_path.clear()
	_repath = 0.0
	_peek = 0.0
	if pose in [Pose.TILT, Pose.CROUCH] and m != Mode.CORPSE:
		pose = Pose.STAND
	if m == Mode.LURK or m == Mode.AMBUSH:
		_peek_in = 1.5


func _search_far() -> bool:
	return _search.is_empty() or _flat(_clue_pos - level.center(_search[0].cell)).length() > 4.0


func _nearest_open(alive: Array[Player]) -> Player:
	var best: Player = null
	for p in alive:
		if p.is_hidden():
			continue
		if best == null or _steps_to(p.global_position) < _steps_to(best.global_position):
			best = p
	return best


## How strongly it goes for `p`: distance, but someone who has just been
## talking counts as much closer.
func _pull(p: Player) -> float:
	var d := p.global_position.distance_to(global_position)
	if _talking(p, Tuning.VOICE_LURE_TIME):
		d *= Tuning.VOICE_LURE_MULT
	return d


# --- modes -----------------------------------------------------------------------

func _chase(delta: float) -> void:
	var seeing := target != null and _seen.has(target)
	if seeing:
		_lost = false
		var sp := _spot_of(target)
		_chase_goal = level.center(sp.access) if sp else target.global_position
	elif not _lost and _clue_age > Tuning.LOSE_AFTER:
		# Out of sight: on to where they were heading.
		_lost = true
		var ahead := _clue_pos + Vector3(_clue_vel.x, 0.0, _clue_vel.z) * 1.2
		_chase_goal = level.center(level.nearest_walkable(level.cell_of(ahead)))
	elif not _lost:
		_chase_goal = _clue_pos
	var looked_at := false
	for p in _alive():
		if p.camera.is_position_in_frustum(global_position + Vector3.UP):
			looked_at = true
	# Chasing it is loud: laughing, moaning, giggling at your back.
	_where_in -= delta
	if _where_in <= 0.0:
		_where_in = _rng.randf_range(4.0, 7.0)
		var r := _rng.randf()
		if r < 0.7:
			_scream()
		else:
			_say("laugh")
	# It hunts on all fours, faster than it walks.
	# Running upright after you: fast, filmed or not (faster still unseen).
	# (Never slower than a brisk walk: it was crawling after you at first.)
	var pace := maxf(Tuning.CHASE_MIN_SPEED, speed() * Tuning.CHASE_SPEED_MULT) * (1.2 if not looked_at else 1.0)
	_walk_to(_chase_goal, pace * delta, delta)
	if _lost and _flat(_chase_goal - global_position).length() < 0.4:
		if _rng.randf() < 0.6:
			_say("voice_lost" if _rng.randf() < 0.5 else "voice_frustrated")
		_start_search("te pierde de vista")


## Stared at this long while it follows (a statue), it charges.
const STARE_LIMIT := 3.0
var _stared := 0.0
## Never stuck: standing still this long when it should be moving, it comes
## apart and comes back from somewhere else (as after a flash).
const STUCK_LIMIT := 9.0
var _still_at := Vector3.ZERO
var _still_for := 0.0


## Behind whoever is alone: catch up, freeze when they turn, creep while
## they look away, and lunge when it is right behind them.
func _follow(delta: float) -> void:
	if target == null or not target.alive:
		_mode_left = 0.0
		return
	var goal := target.global_position if _seen.has(target) else _clue_pos
	var d := global_position.distance_to(goal)
	var looking := target.camera.is_position_in_frustum(global_position + Vector3.UP * 1.2)
	if d > Tuning.FOLLOW_FAR:
		_walk_to(goal, maxf(Tuning.CHASE_MIN_SPEED * 0.85, speed() * 1.15) * delta, delta)
	elif looking and _seen.has(target):
		# Still as a statue while they look this way... but not for ever:
		# stared at too long, it comes for them.
		_stared += delta
		if _stared > STARE_LIMIT:
			_stared = 0.0
			_burst = Tuning.BURST_TIME
			_start_chase("se harta de que la mires: va a por ti")
	elif d > Tuning.FOLLOW_STRIKE:
		_walk_to(goal, speed() * 0.55 * delta, delta)
	elif _seen.has(target):
		_start_chase("te alcanza por detrás")
	else:
		_start_search("te pierde")


## LURK (near the target) and AMBUSH (where they are going): get behind the
## corner, then lean out now and then; out it comes when they are close.
func _wait_at_corner(delta: float, alive: Array[Player]) -> void:
	if target == null or not target.alive or _hide.x < 0:
		_mode_left = 0.0
		return
	var spot := level.center(_hide)
	if _flat(spot - global_position).length() > 0.45 and _peek <= 0.0:
		on_ceiling = _ceiling and level.stair_end_near(global_position).x < 0
		_walk_to(spot, speed() * 1.3 * delta, delta)
		return
	if _ceiling:
		on_ceiling = true
		pose = Pose.CRAWL
		global_position = spot
		for p in alive:
			var d := p.global_position - spot
			if not p.is_hidden() and absf(d.y) < 1.2 and Vector2(d.x, d.z).length() < 1.3:
				# Right under it: it lets go.
				on_ceiling = false
				pose = Pose.LUNGE
				target = p
				_note(events, "cae del techo sobre %s" % p.display_name)
				_drop_fx.rpc()
				moment.emit("drop", p)
				_start_chase("cae del techo")
				return
		return
	# The one it waits for went elsewhere: a new corner (or the ceiling)
	# nearer to where they are now.
	_corner_time += delta
	if mode == Mode.LURK and _corner_time > Tuning.CORNER_PATIENCE and _steps_to(target.global_position) > 6:
		_corner_time = 0.0
		var at := level.nearest_walkable(level.cell_of(target.global_position))
		var up := _rng.randf() < 0.35 and _pick_ceiling(level.nearest_walkable(level.cell_of(global_position)), at)
		if up or _pick_corner(at, [target.camera.global_position], target.camera.global_position, 2, 6):
			_ceiling = up
			_note(events, "cambia de escondite" + (" (al techo)" if up else ""))
			return
	# Someone right round the corner (heard, not seen): it comes out.
	for p in alive:
		if not p.is_hidden() and _steps_to(p.global_position) <= 2:
			target = p
			_start_chase("estás a la vuelta de la esquina")
			return
	# Waiting for them: it only leans out when someone is coming.
	var someone_near := false
	for p in alive:
		if _steps_to(p.global_position) <= 9:
			someone_near = true
	_peek_in -= delta
	if _peek_left > 0.0:
		_peek_left -= delta
		_peek = move_toward(_peek, 1.0, delta * 3.0)
		pose = Pose.TILT
	else:
		_peek = move_toward(_peek, 0.0, delta * 3.0)
		if _peek_in <= 0.0 and (someone_near or mode == Mode.LURK):
			_peek_in = _rng.randf_range(2.0, 4.0)
			_peek_left = _rng.randf_range(1.0, 1.8)
	global_position = spot + _hide_dir * 0.38 * _peek


## A cell `lo`-`hi` steps from `centre` that none of `unseen_from` can see,
## right next to a cell that `look_from` sees: a corner to wait behind.
func _pick_corner(centre: Vector3i, unseen_from: Array, look_from: Vector3, lo: int, hi: int) -> bool:
	var dist := level.layout.distances(centre)
	var space := get_world_3d().direct_space_state
	var best := INF
	var found := NO_CELL
	var found_dir := Vector3.ZERO
	for c: Vector3i in dist.keys():
		var n_steps := int(dist[c])
		if n_steps < lo or n_steps > hi or c.y != centre.y or _too_close(c):
			continue
		var hidden := true
		for eye: Vector3 in unseen_from:
			if _clear(space, eye, level.center(c) + Vector3.UP * 1.4):
				hidden = false
				break
		if not hidden:
			continue
		for d in Level.DIRS:
			var n := c + Vector3i(d.x, 0, d.y)
			if level.is_walkable(n) and _clear(space, look_from, level.center(n) + Vector3.UP * 1.4):
				var score := float(n_steps) + _rng.randf() * 1.5
				if score < best:
					best = score
					found = c
					found_dir = Vector3(d.x, 0, d.y)
				break
	if found.x < 0:
		return false
	_hide = found
	_hide_dir = found_dir
	return true


## Knows nothing: roams, room by room, the ones it has not seen for a
## while first, stopping now and then to listen. Sometimes it goes back for
## a body instead.
func _wander(delta: float, alive: Array[Player]) -> void:
	var here := level.cell_of(global_position)
	var room := level.layout.room_at(level.nearest_walkable(here))
	if room >= 0:
		_visited[room] = _clock
	_where_in -= delta
	if _where_in <= 0.0:
		_where_in = _rng.randf_range(10.0, 18.0)
		var r := _rng.randf()
		if _rng.randf() < 0.1:
			return  # now and then, nothing
		_speak(_where_line() if r < 0.3 else ("voice_hum" if r < 0.5 else ("voice_giggle" if r < 0.65 else ("voice_cry" if r < 0.85 else "voice_moan"))))
	if _wander_pause > 0.0:
		_wander_pause -= delta
		on_ceiling = _wander_up and level.stair_end_near(global_position).x < 0
		return
	if _wander_to.x < 0 or _flat(level.center(_wander_to) - global_position).length() < 0.3:
		if _wander_to.x >= 0:
			_wander_pause = _rng.randf_range(0.8, 2.5)
			pose = Pose.TILT if _rng.randf() < 0.4 else Pose.STAND
		var body := _free_corpse()
		var nobody := true
		for p in alive:
			if p.global_position.distance_to(global_position) < 8.0:
				nobody = false
		if body and nobody and _rng.randf() < 0.25:
			_corpse = body
			_set_mode(Mode.CORPSE, 18.0, "vuelve a por un cuerpo")
			return
		_wander_to = _next_room_cell()
		_wander_up = _rng.randf() < Tuning.CEILING_WALK_CHANCE
		return
	on_ceiling = _wander_up and level.stair_end_near(global_position).x < 0
	if on_ceiling:
		for p in alive:
			var d := p.global_position - global_position
			if not p.is_hidden() and absf(d.y) < 1.2 and Vector2(d.x, d.z).length() < 1.1:
				on_ceiling = false
				_wander_up = false
				target = p
				_note(events, "cae del techo sobre %s" % p.display_name)
				_drop_fx.rpc()
				moment.emit("drop", p)
				_start_chase("cae del techo")
				return
	_walk_to(level.center(_wander_to), speed() * Tuning.WANDER_SPEED_MULT * delta, delta)


func _next_room_cell() -> Vector3i:
	var rooms := level.layout.rooms
	var best := -1
	var best_score := -INF
	for i in rooms.size():
		var score := _clock - float(_visited.get(i, -60.0)) + _rng.randf() * 25.0
		if score > best_score:
			best_score = score
			best = i
	var r: Dictionary = rooms[best]
	var rect: Rect2i = r.rect
	var cells: Array[Vector3i] = []
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector3i(x, r.floor, z)
			if level.is_walkable(c) and _dist.has(c):
				cells.append(c)
	if cells.is_empty():
		return level.nearest_walkable(level.cell_of(global_position))
	return cells[_rng.randi() % cells.size()]


func _investigate(delta: float) -> void:
	_where_in -= delta
	if _where_in <= 0.0:
		_where_in = _rng.randf_range(6.0, 10.0)
		var r := _rng.randf()
		_speak(_where_line() if r < 0.5 else ("voice_giggle" if r < 0.75 else "voice_hum"))
	_walk_to(_clue_pos, speed() * delta, delta)
	if _flat(_clue_pos - global_position).length() < 0.4:
		_start_search("llega al ruido y no hay nadie")


## Around where the clue was: a few points nearby (rooms first) and the
## hiding places on the way, nearest first. Where it saw someone crawl in,
## it looks there first.
func _plan_search(centre: Vector3i) -> Array[Dictionary]:
	var dist := level.layout.distances(centre)
	var out: Array[Dictionary] = [{"cell": centre, "spot": _clue_spot}]
	if _clue_spot:
		out[0].cell = _clue_spot.access
	var spots: Array[HideSpot] = []
	for s in level.hide_spots:
		if s != _clue_spot and dist.has(s.access) and int(dist[s.access]) <= 5:
			spots.append(s)
	spots.sort_custom(func(a: HideSpot, b: HideSpot) -> bool: return int(dist[a.access]) < int(dist[b.access]))
	for s in spots.slice(0, 4 if enraged else 2):
		out.append({"cell": s.access, "spot": s})
	var rooms_seen := {}
	var cells: Array = dist.keys()
	cells.shuffle()
	for c: Vector3i in cells:
		var n := int(dist[c])
		var room := level.layout.room_at(c)
		if n < 2 or n > 6 or rooms_seen.has(room):
			continue
		rooms_seen[room] = true
		out.append({"cell": c, "spot": null})
		if rooms_seen.size() >= 3:
			break
	# Visit them in a sensible order: always the nearest next.
	var ordered: Array[Dictionary] = [out.pop_front()]
	while not out.is_empty():
		var from: Vector3i = ordered[-1].cell
		var k := 0
		for i in out.size():
			if Vector3(out[i].cell - from).length() < Vector3(out[k].cell - from).length():
				k = i
		ordered.append(out.pop_at(k))
	return ordered


func _search_around(delta: float, alive: Array[Player]) -> void:
	_where_in -= delta
	if _where_in <= 0.0:
		_where_in = _rng.randf_range(7.0, 12.0)
		var r := _rng.randf()
		_speak(_where_line() if r < 0.6 else ("voice_giggle" if r < 0.75 else "voice_cry"))
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			if _checking and _check_spot(_checking, alive):
				return
			_checking = null
			pose = Pose.STAND
			_search.pop_front()
		return
	if _search.is_empty():
		_mode_left = 0.0
		return
	var point: Dictionary = _search[0]
	var at := level.center(point.cell)
	if _flat(at - global_position).length() > 0.3:
		_walk_to(at, speed() * Tuning.SEARCH_SPEED_MULT * delta, delta)
		return
	_checking = point.spot
	if _checking:
		# Bends down to look under it / opens the wardrobe a crack.
		pose = Pose.CROUCH
		_pause = 1.4
		_facing = (_checking.inside - global_position).normalized()
	else:
		pose = Pose.TILT  # listening
		_pause = _rng.randf_range(0.8, 1.8)


## Whoever hides in `spot` is found if it saw them go in, if they talk or if
## their light gives them away. Otherwise it moves on, a hand's width away.
func _check_spot(spot: HideSpot, alive: Array[Player]) -> bool:
	for p in alive:
		if finds_in(spot, p):
			_peek_into(spot, p)
			return true
	return false


## Found someone hiding: first it leans in and shows its face, close, for
## Tuning.PEEK_TIME (time to raise the camera and flash it); then it takes
## them. Coming out of the hiding place starts a chase instead.
func _peek_into(spot: HideSpot, p: Player) -> void:
	_drop_corpse()
	target = p
	_peek_spot = spot
	_set_mode(Mode.PEEK, Tuning.PEEK_TIME, "se asoma al escondite de %s" % p.display_name)
	on_ceiling = false
	pose = Pose.PEEK
	var eye := spot.inside + Vector3.UP * spot.eye()
	var out := _flat(spot.facing).normalized()
	var low := spot.eye() < 0.6
	peek_low = low
	# Its face right in front of their eyes. Under a bed or a table it
	# squeezes into the gap (drawn smaller), its chin on the floor.
	var at := eye + out * (0.75 if low else 1.05)
	var face_y := spot.inside.y + clampf(spot.eye(), 0.17, 0.35) if low else eye.y
	global_position = Vector3(at.x, face_y - PEEK_FACE_HEIGHT * (PEEK_LOW_SCALE if low else 1.0), at.z)
	net_pos = global_position
	_say("voice_found")
	_note(events, "te encuentra escondido (%s)" % p.display_name)
	moment.emit("peek", p)


func _peek_hidden() -> void:
	if target == null or not target.alive or _peek_spot == null:
		resume()
		return
	if target.net_hide != String(_peek_spot.name):
		_start_chase("sale del escondite")
		return
	if _mode_left <= 0.0:
		state = State.FEEDING
		caught.emit(target)


## It has been lying in wait too much lately: it goes and looks instead.
func camping() -> bool:
	return _camp > Tuning.CAMP_MAX


func finds_in(spot: HideSpot, p: Player) -> bool:
	return not p.net_god and p.net_hide == String(spot.name) and (spot == _clue_spot or _talking(p, 3.0) or p.net_light)


## Goes back for a body, drags it somewhere laughing, throws it.
func _play_with_body(delta: float) -> void:
	if _corpse == null or not is_instance_valid(_corpse):
		_mode_left = 0.0
		return
	if _corpse.carrier != self:
		if global_position.distance_to(_corpse.global_position) > 0.9:
			_walk_to(_corpse.global_position, speed() * 1.1 * delta, delta)
			return
		_corpse.grab(self)
		pose = Pose.CROUCH
		_say("laugh")
		var here := level.nearest_walkable(level.cell_of(global_position))
		var far := level.layout.distances(here)
		var options: Array[Vector3i] = []
		var lo := 9 if _taking_away else 5
		var hi := 16 if _taking_away else 11
		for c: Vector3i in far.keys():
			if int(far[c]) >= lo and int(far[c]) <= hi and c.y == here.y and not _too_close(c):
				options.append(c)
		_drag_to = options[_rng.randi() % options.size()] if not options.is_empty() else here
		_drag_left = 14.0 if _taking_away else 7.0
		return
	_drag_left -= delta
	var arrived := _flat(level.center(_drag_to) - global_position).length() < 0.5
	if not arrived and _drag_left > 0.0:
		_walk_to(level.center(_drag_to), speed() * 0.75 * delta, delta)
		return
	if _taking_away:
		# Left there, on the floor, far from where it happened.
		_taking_away = false
		_corpse.throw_to(global_position + _facing * 0.6)
		_corpse = null
		_set_mode(Mode.WANDER, 0.0, "deja el cuerpo lejos")
		return
	# Throw it: at someone it can see, or anywhere along an open line.
	_corpse.throw_to(_throw_target())
	_say("laugh")
	pose = Pose.LUNGE
	_corpse = null
	if not _seen.is_empty():
		target = _seen[0]
		_start_chase("lanza el cuerpo y te ve")
	else:
		_set_mode(Mode.WANDER, 0.0, "lanza el cuerpo")


func _throw_target() -> Vector3:
	var space := get_world_3d().direct_space_state
	for p in _seen:
		var to := p.global_position - global_position
		if to.length() < 9.0 and _clear(space, global_position + Vector3.UP, p.global_position + Vector3.UP):
			return global_position + to * maxf(0.0, (to.length() - 1.2) / to.length())
	var here := level.cell_of(global_position)
	var dirs := Level.DIRS.duplicate()
	dirs.shuffle()
	for d: Vector2i in dirs:
		var last := here
		for i in range(1, 5):
			var c := here + Vector3i(d.x * i, 0, d.y * i)
			if not level.is_walkable(c):
				break
			last = c
		if last != here:
			return level.center(last)
	return global_position


func _carrying() -> bool:
	return _corpse != null and is_instance_valid(_corpse) and _corpse.carrier == self


func _drop_corpse() -> void:
	if _carrying():
		_corpse.carrier = null
	_corpse = null


func _free_corpse() -> Corpse:
	for c in corpses:
		if is_instance_valid(c) and c.is_free():
			return c
	return null


## Only someone it can actually reach: close, on its floor, not hidden, and
## nothing in between (never through a wall, a corner or furniture).
func _try_catch(alive: Array[Player]) -> void:
	if _taking_away:
		return  # busy carrying off the last one
	if on_ceiling:
		return  # up there, out of reach (it drops first)
	var space := get_world_3d().direct_space_state
	for p in alive:
		if p.is_hidden() or p.net_god:
			continue
		var d := global_position - p.global_position
		var flat := Vector2(d.x, d.z).length()
		if absf(d.y) > 1.2 or flat > Tuning.ENTITY_KILL_RANGE:
			continue
		# Both ways: a ray that starts inside a wall does not see that wall.
		var a := global_position + Vector3.UP
		var b := p.global_position + Vector3.UP
		if _clear(space, a, b) and _clear(space, b, a):
			_note(events, "atrapa a %s" % p.display_name)
			target = p
			state = State.FEEDING
			caught.emit(p)
			return


## Along the grid (stairs included) towards a point.
func _walk_to(goal_pos: Vector3, dist: float, delta: float) -> void:
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.25
		var goal := level.nearest_walkable(level.cell_of(goal_pos))
		var here := level.nearest_walkable(level.cell_of(global_position))
		var stair := level.stair_end_near(global_position)
		if stair.x >= 0:
			here = stair  # on the flight: from the end it is nearer to
		_path = level.path(here, goal)
		# Off the middle of its cell (it was peeking, or closing in on a
		# point): back to the middle first, or it would cut the corner
		# through the wall on its way to the next cell.
		if not _path.is_empty() and stair.x < 0:
			var step := Vector3(_path[0] - here)
			var off := _flat(global_position - level.center(here))
			var along := Vector3(step.x, 0.0, step.z).normalized()
			if (off - along * off.dot(along)).length() > 0.08 or level.cell_of(global_position) != here:
				_path.push_front(here)
	while not _path.is_empty() and (level.center(_path[0]) - global_position).length() < 0.06:
		_path.pop_front()
	if not _path.is_empty() and _door_in_way(_path[0]):
		return
	var dest := goal_pos if _path.is_empty() else level.center(_path[0])
	if _path.is_empty():
		# Inside the goal's cell: straight to the point, but never into
		# furniture (a hidden body) or a wall.
		var cell := level.cell_of(goal_pos)
		if not level.is_walkable(cell):
			dest = level.center(level.nearest_walkable(cell))
		dest.y = global_position.y
	var to := dest - global_position
	var moved := minf(dist, to.length())
	if moved > 0.0001:
		global_position += to.normalized() * moved
		var flat := _flat(to)
		if flat.length() > 0.01:
			_facing = flat.normalized()


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Whether it can see `p` right now (lying in wait it watches the way they come).
func _sees_now(p: Player) -> bool:
	return _seen.has(p) or (global_position.distance_to(p.global_position) < 8.0
			and _clear(get_world_3d().direct_space_state, global_position + Vector3.UP * EYE, p.camera.global_position))


## A closed door between it and the next cell: a whole door it opens
## (slowly, creaking) and waits for; one with a broken window over it it
## goes through the window, along the ceiling, and leaves shut.
func _door_in_way(next: Vector3i) -> bool:
	var door := level.door_at(next)
	if door == null:
		door = level.door_at(level.cell_of(global_position))
	if door == null or not door.blocks():
		return false  # (coming down again: _door_guard, once well past it)
	if door.transom:
		if not _over_door:
			_over_door = true
			on_ceiling = true
			_note(events, "pasa por la ventana rota de encima de la puerta")
		_ceiling_hold = CEILING_HOLD
		return false
	if door.ready_to_move() and not door.is_open:
		door.set_open.rpc(true, true, door.swing_from(global_position))
		_note(events, "abre una puerta")
	return true


## Last word on doors, after everything else this frame (modes and
## ceilings set elsewhere must not let it walk through one): inside the
## doorway of a shut door with a broken window over it, it is up there,
## going through the window; a shut door without one it never stands in
## (it opens it).
func _door_guard() -> void:
	var here := level.cell_of(global_position)
	var door := level.door_at(here)
	# A shut door with a broken window over it, coming up on its way: it is
	# up on the ceiling well before it gets there, and stays up there a
	# while after (it does not climb at the last moment, nor drop at once).
	if _transom_ahead():
		if not _over_door:
			_note(events, "sube al techo para pasar por la ventana de una puerta")
		_over_door = true
		on_ceiling = true
		_ceiling_hold = CEILING_HOLD
	if door and door.blocks():
		if door.transom:
			_over_door = true
			on_ceiling = true
			_ceiling_hold = CEILING_HOLD
		else:
			if door.ready_to_move() and not door.is_open:
				door.set_open.rpc(true, true, door.swing_from(global_position))
			# Back out of the leaf until it is open.
			var back := level.nearest_walkable(here + Vector3i(door.axis.x, 0, door.axis.y) * (1 if (global_position - door.global_position).dot(Vector3(door.axis.x, 0, door.axis.y)) > 0 else -1))
			global_position = global_position.move_toward(level.center(back), 0.05)
	elif _over_door:
		_ceiling_hold -= get_physics_process_delta_time()
		if _ceiling_hold <= 0.0:
			_over_door = false
			if mode != Mode.LURK and mode != Mode.AMBUSH:
				on_ceiling = false


## A shut door with a broken window over it, within the next steps of its
## way (or right by it).
func _transom_ahead() -> bool:
	var cells: Array[Vector3i] = [level.cell_of(global_position)]
	for i in mini(3, _path.size()):
		cells.append(_path[i])
	for c in cells:
		var d := level.door_at(c)
		if d and d.transom and d.blocks() and d.global_position.distance_to(global_position) < TRANSOM_REACH:
			return true
	return false


## Every machine: the flash burns it: it flushes red and turns its back.
@rpc("authority", "call_local", "reliable")
func _burn_fx() -> void:
	_burn = 1.0
	_turn = 0.22


## Every machine: the thump of it landing from the ceiling.
## It comes into the house as far as it can be from everyone (they are
## wherever the broadcast left them, not at the door): the walkable cell
## whose nearest player is the most steps away.
func _far_from_everyone() -> void:
	var maps: Array[Dictionary] = []
	for p in _alive():
		maps.append(level.layout.distances(level.nearest_walkable(level.cell_of(p.global_position))))
	if maps.is_empty():
		return
	var best := level.nearest_walkable(level.cell_of(global_position))
	var best_d := -1
	for c: Vector3i in maps[0].keys():
		var d := 9999
		for m in maps:
			d = mini(d, int(m.get(c, 9999)))
		if d > best_d:
			best_d = d
			best = c
	global_position = level.center(best)
	net_pos = global_position
	_note(events, "aparece a %d pasos del más cercano" % best_d)


## Every machine: the cry when it comes in, from where it is (far away),
## carried through the house.
@rpc("authority", "call_local", "reliable")
func _wake_cry(at: Vector3) -> void:
	_note(sounds, "wake_cry")
	var p := AudioStreamPlayer3D.new()
	p.stream = Sfx.get_stream("wake_cry")
	p.unit_size = 7.0
	p.max_db = MAX_DB
	p.volume_db = -8.0  # lower and further off (it is somewhere deep in the house)
	p.attenuation_filter_cutoff_hz = 1500.0  # muffled by the walls in between
	p.bus = "Effects"
	get_parent().add_child(p)
	p.global_position = at + Vector3.UP * 1.6
	p.finished.connect(p.queue_free)
	p.play()
	Sfx.heard("wake_cry", p.global_position, p.volume_db, MAX_DB)


@rpc("authority", "call_local", "reliable")
func _drop_fx() -> void:
	_note(sounds, "cae del techo")
	Sfx.play_3d(get_parent(), global_position, "body_thud", (LOUD - 2.0) - (22.0 if piloted_here else 0.0), MAX_DB)


## What it says tells you what it knows: "¿dónde estás?", crying, moaning
## while it looks; "¡te estoy viendo!" when it has found you; a growl of
## frustration when it loses you; the same shout when you catch it lying in wait.
## Host: picks one of the line's takes, and every machine plays that one.
func _say(line: String) -> void:
	_play_line.rpc(_take(line))


## Chasing: the shriek (one of its three takes), over anything else it says.
func _scream() -> void:
	_play_line.rpc(["chase_scream", "chase_scream2", "chase_scream3"][_rng.randi() % 3])


## One of the takes of a line (<line>.wav, <line>2.wav).
func _take(line: String) -> String:
	if TAKES.has(line) and _rng.randf() < 0.5:
		return line + "2"
	return line


@rpc("authority", "call_local", "reliable")
func _play_line(line: String) -> void:
	var urgent := line.begins_with("voice_line") or line.begins_with("chase_scream")
	if voice.playing and not urgent:
		return
	_note(sounds, line)
	voice.stream = Sfx.get_stream(line)
	# Its screams over everything else it says.
	var scream := line.begins_with("chase_scream") or line.begins_with("voice_agony") or line.begins_with("voice_hunger")
	voice.volume_db = VOICE_DB + (SCREAM_BOOST if scream else 0.0) - (26.0 if piloted_here else 0.0)  # (its own, right in its ears)
	voice.pitch_scale = _rng.randf_range(0.94, 1.02)
	voice.play()
	Sfx.heard(line, voice.global_position, voice.volume_db, MAX_DB)


## Squeezing under the boards of a barricaded doorway (it crawls there).
func _under_boards() -> bool:
	if level == null:
		return false
	for cell: Vector3i in level.spots_of("U"):
		if (level.center(cell) - global_position).length() < 0.75:
			return true
	return false


# --- local presentation ------------------------------------------------------

func _present(delta: float) -> void:
	# Leaning into where you hide: you see its face, camcorder or not (it
	# has opened the doors, it is right there).
	if viewer:
		viewer.camcorder.peeked = mode == Mode.PEEK and state == State.STALKING and viewer.is_hidden() 				and _flat(global_position - viewer.global_position).length() < 2.5
	# Found on camera: the tape dies for an instant (not more than every 3 s).
	var on_cam := viewer != null and viewer.camcorder.filming and state != State.DORMANT and is_filmed_by(viewer)
	if false and on_cam and not _was_on_cam and _sting_cooldown <= 0.0:  # (no sting on camera any more)
		Sfx.play(self, "filmed_sting", -6.0)
		_sting_cooldown = 3.0
	_was_on_cam = on_cam
	if state != _shown_state:
		if state == State.FEEDING:
			jingle.stop()
			drone.stop()
		elif _shown_state == State.FEEDING:
			jingle.play()
			drone.play()
		_shown_state = state

	# Footsteps from how far it actually moved (so every machine hears them).
	# Stalking someone, it treads softly.
	var sneaking := mode in [Mode.FOLLOW, Mode.LURK, Mode.AMBUSH, Mode.STALK] and not enraged
	var step_len := _flat(global_position - _last_pos).length()
	_stride += step_len
	_gait_speed = lerpf(_gait_speed, step_len / maxf(delta, 0.001), minf(1.0, delta * 8.0))
	if state == State.STALKING and not gone and not vanishing:
		_step_acc += step_len
		if _step_acc > (1.3 if mode == Mode.CHASE or mode == Mode.FLEE else 0.8):
			_step_acc = 0.0
			steps.pitch_scale = _rng.randf_range(0.8, 1.05)
			steps.volume_db = (-40.0 if mode == Mode.STALK else -14.0) if sneaking else (-8.0 if mode in [Mode.WANDER, Mode.SEARCH] else -3.0)  # (a little lower than the rest)
			if piloted_here:
				steps.volume_db -= 16.0  # (its own, in its ears)
			steps.play()
	_last_pos = global_position

	_sting_cooldown -= delta
	_boil_t += delta * (1.8 if enraged else 1.0)
	var shown_pose := pose
	if _under_boards():
		shown_pose = Pose.CRAWL
	elif on_ceiling:
		shown_pose = Pose.STAND  # pressed flat to it, the whole body
	if on_cam:
		_flash -= delta
		if _flash <= 0.0 and _rng.randf() < FLASH_CHANCE * delta:
			_flash = FLASH_TIME
		if _flash > 0.0:
			_glitch = 1.0
	var cols := sheet_columns()
	var col := int(_boil_t * BOIL_FPS) % cols
	var moving := _gait_speed > 0.25 and state == State.STALKING
	# On all fours only running from the flash; chasing, it runs upright.
	var galloping := moving and mode == Mode.FLEE and not on_ceiling
	var running := moving and mode == Mode.CHASE and not on_ceiling
	if galloping:
		shown_pose = Pose.GALLOP
		col = int(_stride / 0.45) % cols
	elif running:
		# Running at you screaming, mouth and eyes wide; and wrong: the
		# stride jerks (a frame held too long, then two at once), the head
		# twitches, now and then the whole body lurches sideways.
		shown_pose = Pose.RUN
		_jerk_t -= delta
		if _jerk_t <= 0.0:
			_jerk_t = _rng.randf_range(0.05, 0.22)
			_jerk_col = (_jerk_col + (2 if _rng.randf() < 0.3 else 1)) % cols
			_twitch = Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf_range(-0.03, 0.05), 0.0) if _rng.randf() < 0.35 else Vector3.ZERO
		col = _jerk_col
	elif moving and shown_pose == Pose.STAND and not on_ceiling:
		shown_pose = Pose.WALK
		col = int(_stride / 0.55) % cols
	if int(shown_pose) >= sheet_rows():  # the classic drawing has no gait rows
		shown_pose = Pose.CRAWL if shown_pose == Pose.GALLOP else Pose.STAND
	if not on_ceiling:
		if _sprite.region_enabled:  # (off the ceiling: the whole sheet again)
			_sprite.region_enabled = false
			_sprite.hframes = sheet_columns()
			_sprite.vframes = sheet_rows()
			_sprite.offset = Vector2(0, frame_size().y * 0.5)
		_sprite.frame = int(shown_pose) * cols + col

	_sprite.visible = state != State.DORMANT and not piloted_here and not gone  # (you do not see yourself)
	var shown := viewer != null and (viewer.camcorder.filming or viewer.camcorder.reveal)
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shown else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if viewer:
		# Unlit drawing: it fades with distance instead of with light.
		var d := global_position.distance_to(viewer.global_position)
		var v := lerpf(0.45, 0.16, clampf((d - 2.0) / 12.0, 0.0, 1.0))
		_sprite.modulate = Color(v * 1.25, v * 0.6, v * 0.55) if enraged else Color(v, v * 0.95, v * 0.92)
		# Burned by the flash: red hot, fading as it runs (its back to you,
		# darker, as it flees).
		_burn = maxf(0.0, _burn - delta * 0.45)
		if _burn > 0.0 or mode == Mode.FLEE:
			var hot := maxf(_burn, 0.35 if mode == Mode.FLEE else 0.0)
			_sprite.modulate = _sprite.modulate.lerp(Color(1.3 * v + 0.35 * hot, 0.08, 0.06), hot)
	# Enraged: bigger, redder, never quite still.
	_sprite.scale = Vector3.ONE * (PEEK_LOW_SCALE if mode == Mode.PEEK and peek_low else (1.12 if enraged else 1.0))
	_sprite.position = Vector3(_rng.randf_range(-0.025, 0.025), 0.0, _rng.randf_range(-0.025, 0.025)) if enraged else Vector3.ZERO
	# On the ceiling: pressed flat against it, the whole body spread, the
	# face looking down, its head towards you (to judge the drop).
	_sprite.flip_v = false
	if on_ceiling:
		_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		var to := Vector3.FORWARD
		if viewer:
			to = _flat(viewer.global_position - global_position)
			to = to.normalized() if to.length() > 0.05 else Vector3.FORWARD
		_sprite.rotation = Vector3(PI / 2, atan2(to.x, to.z), 0.0)
		_sprite.position = Vector3(0.0, Level.HEIGHT - 0.04, 0.0) - to * HEIGHT * 0.45
		var fs := frame_size()
		var face_col := int(_boil_t * BOIL_FPS) % sheet_columns()
		_face.region_rect = Rect2(face_col * fs.x, int(Pose.STAND) * fs.y, fs.x, fs.y * 0.3)
		# The flat body without its head (the face above stands in for it).
		_sprite.hframes = 1
		_sprite.vframes = 1
		_sprite.frame = 0
		_sprite.region_enabled = true
		_sprite.region_rect = Rect2(face_col * fs.x, int(Pose.STAND) * fs.y + fs.y * 0.28, fs.x, fs.y * 0.72)
		_sprite.offset = Vector2(0, fs.y * 0.36)
		_face.position = _sprite.position + to * HEIGHT * 0.86 - Vector3.UP * 0.32
		_face.modulate = _sprite.modulate
	_face.visible = on_ceiling and _sprite.visible
	if is_3d():
		_present_model(shown_pose, running, shown, delta)
	if on_ceiling:
		pass
	elif _sprite.region_enabled:
		_sprite.region_enabled = false
		_sprite.hframes = sheet_columns()
		_sprite.vframes = sheet_rows()
		_sprite.offset = Vector2(0, frame_size().y * 0.5)
		_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_sprite.rotation = Vector3.ZERO
	else:
		_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_sprite.rotation = Vector3.ZERO
		if mode == Mode.CHASE and _gait_speed > 0.25:
			_sprite.position += _twitch
			_sprite.rotation.z = _twitch.x * 1.2  # the body jerks over
	# The screamer: cut after cut between its face and its face closer,
	# jolting, on the taken player's screen.
	if _scare > 0.0:
		_scare -= delta
		var cut := int(_scare * 14.0) % 2 == 0
		_sprite.frame = int(Pose.LUNGE) * sheet_columns() + (int(_scare * 20.0) % sheet_columns())
		_sprite.scale = Vector3.ONE * (1.55 if cut else 1.0)
		_sprite.position = Vector3(_rng.randf_range(-0.08, 0.08), (-0.55 if cut else 0.0) + _rng.randf_range(-0.04, 0.04), 0.0)
		return
	_sprite.flip_h = mode == Mode.FLEE
	if _turn > 0.0:
		_turn -= delta
		_sprite.scale.x *= absf(cos((1.0 - _turn / 0.22) * PI))
	# The flash while filmed: the picture of it tears for an instant
	# (stretched, slid sideways), the same drawing, not another one.
	_glitch = maxf(0.0, _glitch - delta * 12.0)
	if _glitch > 0.0:
		_sprite.scale = Vector3(1.0 + _rng.randf_range(-0.25, 0.4), 1.0 + _rng.randf_range(-0.15, 0.3), 1.0) * _sprite.scale.x
		_sprite.position.x += _rng.randf_range(-0.35, 0.35)
	# Burned by the flash: the drawing comes apart, smeared sideways and
	# crushed down, flickering out, white-hot to red.
	var apart := _coming_apart(delta)
	if apart > 0.0:
		_sprite.scale = Vector3(1.0 + apart * 0.9 + _rng.randf_range(-0.2, 0.3), maxf(0.05, 1.0 - apart * 0.85 + _rng.randf_range(-0.1, 0.1)), 1.0) * _sprite.scale.x
		_sprite.position.x += _rng.randf_range(-0.3, 0.3) * apart
		_sprite.visible = _sprite.visible and _rng.randf() > apart * 0.55
		_sprite.modulate = _sprite.modulate.lerp(Color(1.6, 0.55, 0.35), 1.0 - apart)
	# The drawing is a flat card wider than a doorway: drawn a little towards
	# whoever looks, so its edges never sink into the walls beside it.
	if viewer and state != State.FEEDING:
		var to := _flat(viewer.camera.global_position - global_position)
		if to.length() > 0.05:
			_sprite.position += to.normalized() * minf(0.45, to.length() * 0.35)

	# Silent until woken. Its song tells what it is doing: loud when it
	# chases, far and thin while it looks for you, gone (only steps, or
	# nothing at all) when it is stalking or lying in wait. The drone never stops.
	drone.stream_paused = state == State.DORMANT or quiet or gone
	# Stalking you it makes no sound but this: breathing on the back of your
	# neck, louder the closer it is.
	var breathing := mode == Mode.STALK and state == State.STALKING and viewer != null and not piloted_here 			and global_position.distance_to(viewer.global_position) < 5.0
	if breathing and not _breath.playing:
		_breath.play(_rng.randf() * 3.0)
	elif not breathing and _breath.playing:
		_breath.stop()
	# Out of a chase its song is not a beacon either: a phrase, then long
	# silences (only the drone, its steps, the house).
	_song_left -= delta
	if _song_left <= 0.0:
		_song_on = not _song_on
		_song_left = _rng.randf_range(10.0, 16.0) if _song_on else _rng.randf_range(6.0, 12.0)
	# It is only silent lying in wait (sneaking) and just after waking.
	var singing := Tuning.ENTITY_SONG and (_song_on or enraged or mode == Mode.CHASE) and not quiet
	jingle.stream_paused = state == State.DORMANT or sneaking or not singing or gone
	var vol := -10.0
	match mode:
		Mode.CHASE:
			vol = -6.0 + tapes
		Mode.SEARCH, Mode.INVESTIGATE:
			vol = -14.0
	jingle.volume_db = -18.0 if state == State.DORMANT else vol + LOUD
	jingle.pitch_scale = 1.25 if enraged else 1.0 - 0.02 * tapes


## In 3D: the puppet takes the drawing's place, in the same pose, facing
## where it goes (or, standing, whoever looks at it); its face is put where
## the drawing's would be when it peeks in or lunges at you.
func _present_model(shown_pose: Pose, running: bool, shown: bool, delta: float) -> void:
	if _model == null:
		_model = EntityModel.new()
		add_child(_model)
		_model.set_layers(LAYER_MASK)
	_sprite.visible = false
	_face.visible = false
	_model.visible = state != State.DORMANT and not piloted_here and not gone
	_model.set_shadows(shown)
	var moved := global_position - _model_last
	moved.y = 0.0
	_model_last = global_position
	var eye := viewer.camera.global_position if viewer else Vector3.INF
	# After them (or at them): it faces you and its head turns to you.
	# Otherwise it does not know where you are, and does not look at you.
	var aware := mode in [Mode.CHASE, Mode.STALK, Mode.FOLLOW, Mode.PEEK] or state == State.FEEDING or _scare > 0.0 \
			or shown_pose == Pose.STRETCH or shown_pose == Pose.LUNGE or on_ceiling
	var want := _model_yaw
	if moved.length() > 0.004 and not on_ceiling and mode != Mode.PEEK and state != State.FEEDING:
		want = atan2(-moved.x, -moved.z)
	elif eye != Vector3.INF and aware:
		var to := eye - global_position
		want = atan2(-to.x, -to.z)
	# (Its face at you at once when it peeks in or lunges: no turning round.)
	var snap := mode == Mode.PEEK or state == State.FEEDING or _scare > 0.0
	_model_yaw = want if snap else lerp_angle(_model_yaw, want, minf(1.0, delta * (14.0 if running else 6.0)))
	var pose_now: int = Pose.LUNGE if _scare > 0.0 else shown_pose
	var size := PEEK_LOW_SCALE if mode == Mode.PEEK and peek_low else (1.12 if enraged else 1.0)
	if _scare > 0.0:
		size *= 1.35 if int(_scare * 14.0) % 2 == 0 else 1.0  # (the screamer's cuts)
	if _glitch > 0.0:
		size *= 1.0 + _rng.randf_range(-0.15, 0.25)
	var talking := voice.playing
	model_args = [pose_now, _stride, _model_yaw, on_ceiling, _sprite.modulate, size, running, aware, talking]
	_model.drive(delta, pose_now, _stride, _model_yaw, eye, on_ceiling, _sprite.modulate, size, running, aware, talking)
	# Burned by the flash: the puppet comes apart the same way.
	var apart := _coming_apart(0.0)
	if apart > 0.0:
		_model.scale = Vector3(1.0 + apart * 0.7 + _rng.randf_range(-0.15, 0.25), maxf(0.05, 1.0 - apart * 0.85), 1.0 + apart * 0.7) * size
		_model.visible = _model.visible and _rng.randf() > apart * 0.55
	# Its face where the drawing's face is (the lunge, the hiding place).
	var face_at := -1.0
	if pose_now == Pose.LUNGE:
		face_at = LUNGE_FACE_HEIGHT
	elif mode == Mode.PEEK:
		face_at = PEEK_FACE_HEIGHT * (PEEK_LOW_SCALE if peek_low else 1.0)
	_model.anchor_face(global_position + Vector3.UP * face_at if face_at > 0.0 else Vector3.INF)


## 0 normally; while it comes apart (the flash), how far along (0..1).
func _coming_apart(delta: float) -> float:
	if not vanishing:
		return 0.0
	_vanish_t += delta
	return clampf(_vanish_t / VANISH_TIME, 0.0, 1.0)


## Host: never stuck in one place doing nothing (a way it cannot find, a
## standoff): after STUCK_LIMIT without getting anywhere, when it should
## be (not lying in wait, not looking into a hiding place, not with a
## body), it comes apart and comes back from where it chooses.
func _watch_stuck(delta: float) -> void:
	if global_position.distance_to(_still_at) > 0.5 or mode in [Mode.LURK, Mode.AMBUSH, Mode.PEEK, Mode.CORPSE] \
			or _found_out or _wander_pause > 0.0 or _pause > 0.0:
		_still_at = global_position
		_still_for = 0.0
		return
	_still_for += delta
	if _still_for < STUCK_LIMIT:
		return
	_still_for = 0.0
	var near: Player = null
	for p in _alive():
		if near == null or p.global_position.distance_to(global_position) < near.global_position.distance_to(global_position):
			near = p
	_burned_by = near
	on_ceiling = false
	vanishing = true
	_vanish_left = VANISH_TIME
	_vanish_fx.rpc(global_position)
	_note(events, "atascada: se deshace y volverá desde otro sitio")


func _new_pose() -> void:
	var choices := [Pose.STAND, Pose.REACH, Pose.TILT, Pose.PEEK, Pose.CROUCH]
	choices.erase(pose)
	pose = choices[_rng.randi() % choices.size()]


func _build_sprite() -> void:
	_sprite = Sprite3D.new()
	_sprite.texture = load(sheet())
	if _sprite.texture == null:
		push_error("Entity: missing %s (run tools/gen_entity_v2.py / gen_entity.py and import)" % sheet())
	_sprite.hframes = sheet_columns()
	_sprite.vframes = sheet_rows()
	_sprite.pixel_size = HEIGHT / frame_size().y
	_sprite.offset = Vector2(0, frame_size().y * 0.5)
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.layers = LAYER_MASK
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)
	# On the ceiling the body lies flat against it, but the face always
	# looks at you, a cut-out like the rest of it (the head of its frame).
	_face = _sprite.duplicate() as Sprite3D
	_face.hframes = 1
	_face.vframes = 1
	_face.region_enabled = true
	_face.offset = Vector2.ZERO
	_face.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_face.visible = false
	add_child(_face)
