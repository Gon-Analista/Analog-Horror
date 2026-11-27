class_name Replay
extends Node
## The best moments of the night, played back at the end like a tape.
##
## Every machine records what it sees (players, the entity's drawing, doors,
## the power, sounds, flashes, deaths) a dozen times a second, and keeps
## only what is near a "moment": the host spots those (a catch, a flash in
## its face, its face at your hiding place...) and tells everyone the moment
## it happens, so each machine keeps the seconds around it from its own
## recording. At the end the host picks the best ones and starts them; every
## machine plays them back from its own copy at the same time, from the eyes
## of whoever lived it, with the entity drawn on the tape (the camera always
## sees it). Recordings never cross the network: only the moments' numbers.

const RATE := 12.0
## The longest any moment looks back (seconds of recording always kept).
const PRE_MAX := 10.0
const MAX_MOMENTS := 30
const MAX_CLIPS := 5
## Clips that overlap are joined, up to this long.
const MAX_CLIP := 16.0
## Each kind: [score, seconds before, seconds after].
const KINDS := {
	"caught": [100, 8.0, 3.0],
	"escape": [90, 10.0, 1.5],
	"peek": [70, 4.0, 4.0],
	"flash": [65, 6.0, 3.0],
	"drop": [60, 5.0, 3.0],
	"found": [55, 4.0, 5.0],
	"close": [50, 6.0, 3.0],
	"door": [45, 5.0, 3.0],
	"dazzle": [40, 3.0, 3.0],
	"rage": [35, 2.0, 5.0],
}

signal clips_ready
signal started(index: int)
signal stopped

var run: Run
## Local clock (Run.time, then on past the end).
var now := 0.0
## [t, entity, {id: player}, doors, dark, {peer id: body transform}]
var _frames: Array = []
## [t, kind, args]
var _events: Array = []
## id -> {kind, focus, name, at}
var moments := {}
## The host's pick: [{id, from, to}] (from/to: seconds around the moment).
var clips: Array = []
var _sample_in := 0.0
var _prune_in := 2.0
var _lamp_shadows: Array[bool] = []

# playback
var playing := false
var _queue: Array[int] = []
var _all := false
var _looped := 0
var _clip := -1
var _t := 0.0
var _t1 := 0.0
var _cursor := 0
var _event_cursor := 0
var _focus := 0
var _root: Node3D
var _camera: Camera3D
var _puppets := {}  # id -> {root, avatar, light, dying, voice}
var _bodies := {}  # peer id -> Node3D (a limp body, dragged as it was)
var _ent: Sprite3D
var _ent_face: Sprite3D
var _ent_model: EntityModel
var _husk: HuskModel
var _restore := {}
var _gap := 0.0


func setup(p_run: Run) -> void:
	run = p_run
	for lamp in run.level.lamps:
		_lamp_shadows.append(lamp.shadow_enabled)
	Sfx.listeners.append(_heard)


func _exit_tree() -> void:
	Sfx.listeners.erase(_heard)


func _process(delta: float) -> void:
	if playing:
		_play(delta)
		return
	if run.phase == Run.Phase.PLAYING:
		now = run.time
	else:
		now += delta  # the seconds after a catch still belong to its clip
		if now - run.time > 6.0:
			return
	_sample_in -= delta
	if _sample_in <= 0.0 and (_frames.is_empty() or now > _frames[-1][0]):
		_sample_in = 1.0 / RATE
		_frames.append(_sample())
	_prune_in -= delta
	if _prune_in <= 0.0:
		_prune_in = 2.0
		_prune()


# --- recording -----------------------------------------------------------------

func _sample() -> Array:
	var ps := {}
	for id: int in run.players:
		var p: Player = run.players[id]
		if not is_instance_valid(p):
			continue
		var speed := Vector2(p.velocity.x, p.velocity.z).length() if p.is_local else p._remote_speed
		ps[id] = [p.global_position, p.rotation.y, p.camera.global_transform, p.camera.fov, speed, p._pitch,
				p.camcorder.raise, p.camcorder.filming, p.crouch_amount, p.avatar.lying, p.avatar.lie_back,
				p.alive and (p.avatar.lying or p.net_hide == ""),
				p.flashlight.global_transform if p.flashlight.visible else null, p.holds("camcorder"), p.holds("flashlight")]
	var e := run.entity
	var s := e._sprite
	var local := s.transform
	local.origin -= _pull_of(e, e.viewer.camera.global_position if e.viewer else e.global_position)
	var ent := [e.global_position, e.state != Entity.State.DORMANT and not e.gone, local, s.frame, s.region_enabled, s.region_rect, s.hframes, s.vframes,
			s.offset, s.billboard, s.flip_h, s.modulate, e._face.visible, e._face.transform, e._face.region_rect, e.model_args.duplicate()]
	if e is Husk:
		ent.append([(e as Husk)._shown_look, (e as Husk)._shown_yaw])  # [16]: only its shadow is on the tape
	var doors := 0
	for i in run.level.doors.size():
		if run.level.doors[i].is_open:
			doors |= 1 << i
	var dark := not run.level.lamps.is_empty() and run.level.lamps[0].dead
	var bodies := {}
	for c in run.corpses:
		if is_instance_valid(c):
			bodies[c.peer_id] = c.global_transform
	return [now, ent, ps, doors, dark, bodies]


## How far the drawing is pulled towards whoever looks (Entity._present):
## taken out of the recording, put back towards the tape's eye.
static func _pull_of(e: Entity, eye: Vector3) -> Vector3:
	if e.state == Entity.State.FEEDING or e.viewer == null:
		return Vector3.ZERO
	var to := eye - e.global_position
	to.y = 0.0
	if to.length() <= 0.05:
		return Vector3.ZERO
	return to.normalized() * minf(0.45, to.length() * 0.35)


func _heard(id: String, at: Vector3, volume_db: float, max_db: float) -> void:
	if not playing:
		_events.append([now, "sfx", [id, at, volume_db, max_db]])


## What someone said (mu-law, as it came over the network, or our own).
func note_voice(id: int, data: PackedByteArray) -> void:
	if not playing:
		_events.append([now, "voice", [id, data]])


func note_flash(id: int) -> void:
	if not playing:
		_events.append([now, "flash", [id]])


func note_death(id: int, toward: Vector3) -> void:
	if not playing:
		_events.append([now, "death", [id, toward]])


## Everyone: the host saw a moment (same id on every machine).
func mark(id: int, kind: String, focus: int) -> void:
	if not KINDS.has(kind):
		return
	var p: Player = run.players.get(focus)
	moments[id] = {"kind": kind, "focus": focus, "name": p.display_name if p else "", "at": now}
	# Too many: the least worth seeing go (the same ones on every machine).
	while moments.size() > MAX_MOMENTS:
		var worst := -1
		for m: int in moments:
			if worst < 0 or _score(m) < _score(worst) or (_score(m) == _score(worst) and m < worst):
				worst = m
		moments.erase(worst)


func _score(id: int) -> int:
	return KINDS[moments[id].kind][0]


func _window(id: int) -> Vector2:
	var m: Dictionary = moments[id]
	var k: Array = KINDS[m.kind]
	return Vector2(m.at - k[1], m.at + k[2])


func _kept(t: float) -> bool:
	if t >= now - PRE_MAX:
		return true
	for id: int in moments:
		var w := _window(id)
		if t >= w.x - 0.5 and t <= w.y + 0.5:
			return true
	return false


func _prune() -> void:
	_frames = _frames.filter(func(f: Array) -> bool: return _kept(f[0]))
	_events = _events.filter(func(ev: Array) -> bool: return _kept(ev[0]))


## Host: the best moments, joined where they overlap, in the order they
## happened: [{id, from, to}] around each one's own time.
func pick() -> Array:
	var ids := moments.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return _score(a) > _score(b) or (_score(a) == _score(b) and a > b))
	var chosen: Array = []  # [id, Vector2 window]
	for id: int in ids:
		var w := _window(id)
		var joined := false
		for c: Array in chosen:
			var cw: Vector2 = c[1]
			if w.x < cw.y and w.y > cw.x:
				var u := Vector2(minf(w.x, cw.x), maxf(w.y, cw.y))
				if u.y - u.x <= MAX_CLIP:
					c[1] = u
				joined = true
				break
		if not joined and chosen.size() < MAX_CLIPS:
			chosen.append([id, w])
	chosen.sort_custom(func(a: Array, b: Array) -> bool: return a[1].x < b[1].x)
	var out: Array = []
	for c: Array in chosen:
		var at: float = moments[c[0]].at
		out.append({"id": c[0], "from": c[1].x - at, "to": c[1].y - at})
	return out


func set_clips(list: Array) -> void:
	clips = list.filter(func(c: Dictionary) -> bool: return moments.has(int(c.id)))
	clips_ready.emit()


## Whose clip it is (no titles: only the name).
func clip_name(i: int) -> String:
	return moments[int(clips[i].id)].name


# --- playback ------------------------------------------------------------------

## Everyone at once (the host's word): clip `i` over and over, or all of
## them one after another (-1), over and over.
func play(i: int) -> void:
	if clips.is_empty():
		return
	_queue.clear()
	_all = i < 0
	_looped = i
	if i < 0:
		for k in clips.size():
			_queue.append(k)
	elif i < clips.size():
		_queue.append(i)
	else:
		return
	if not playing:
		_begin()
	_next()


func stop() -> void:
	if not playing:
		return
	playing = false
	_queue.clear()
	_clip = -1
	_end_playback()
	stopped.emit()


func current() -> int:
	return _clip


func clip_time() -> float:
	return _t


func focus_name() -> String:
	var p: Player = run.players.get(_focus)
	return p.display_name if p else ""


func _next() -> void:
	if _queue.is_empty():
		# The tape winds back and plays again (until the host picks another).
		if _all:
			for k in clips.size():
				_queue.append(k)
		else:
			_queue.append(clamp(_looped, 0, clips.size() - 1))
	_clip = _queue.pop_front()
	var c: Dictionary = clips[_clip]
	var m: Dictionary = moments[int(c.id)]
	_t = m.at + float(c.from)
	_t1 = m.at + float(c.to)
	_focus = m.focus
	for id: int in _puppets:
		var v: AudioStreamPlayer3D = _puppets[id].voice
		var pb := v.get_stream_playback() as AudioStreamGeneratorPlayback
		if pb:
			pb.clear_buffer()
	_cursor = 0
	while _cursor < _frames.size() - 1 and _frames[_cursor + 1][0] <= _t:
		_cursor += 1
	_event_cursor = 0
	while _event_cursor < _events.size() and _events[_event_cursor][0] < _t:
		_event_cursor += 1
	for id: int in _puppets:
		var pup: Dictionary = _puppets[id]
		pup.dying = false
		pup.avatar.dying = false
		pup.avatar.rotation = Vector3.ZERO
	_gap = 0.35
	_apply_frame(true)
	started.emit(_clip)


func _begin() -> void:
	playing = true
	var world := run.level.get_parent()
	_restore = {"camera": run.level.get_viewport().get_camera_3d(), "doors": [], "dark": [], "corpses": [], "shown": {}}
	for d in run.level.doors:
		_restore.doors.append([d.is_open, d.amount])
	for lamp in run.level.lamps:
		_restore.dark.append([lamp.dead, lamp.shadow_enabled])
	for p: Player in run.players.values():
		_restore.shown[p] = p.visible
		p.visible = false
	for c in run.corpses:
		if is_instance_valid(c):
			_restore.corpses.append(c)
			c.visible = false
	run.entity.visible = false
	run.entity.process_mode = Node.PROCESS_MODE_DISABLED
	_root = Node3D.new()
	_root.name = "ReplayStage"
	world.add_child(_root)
	_camera = Camera3D.new()
	_camera.cull_mask = run.local_player.camera.cull_mask & ~(ViewModel.LAYER_MASK | PlayerAvatar.SELF_LAYER | HuskModel.NAKED_LAYER)
	_camera.near = 0.05
	_root.add_child(_camera)
	_camera.current = true
	for id: int in run.players:
		var p: Player = run.players[id]
		var holder := Node3D.new()
		_root.add_child(holder)
		var av := PlayerAvatar.new()
		av.tint = p.tint
		holder.add_child(av)
		var light := p.flashlight.duplicate(0) as SpotLight3D
		for child in light.get_children():
			child.queue_free()
		light.top_level = true
		light.visible = false
		_root.add_child(light)
		# Their voice, from their head, as it was heard.
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = VoiceChat.RATE
		gen.buffer_length = 1.0
		var voice := AudioStreamPlayer3D.new()
		voice.stream = gen
		voice.bus = VoiceChat.VOICE_BUS
		voice.unit_size = 3.5
		voice.max_db = 18.0
		voice.volume_db = 12.0
		voice.max_distance = 24.0
		voice.panning_strength = 0.8
		voice.position = Vector3(0, 1.45, 0)
		holder.add_child(voice)
		voice.play()
		_puppets[id] = {"root": holder, "avatar": av, "light": light, "dying": false, "voice": voice}
	_ent = run.entity._sprite.duplicate(0) as Sprite3D
	_ent.layers = 1
	_root.add_child(_ent)
	_ent_face = run.entity._face.duplicate(0) as Sprite3D
	_ent_face.layers = 1
	_root.add_child(_ent_face)
	if run.entity is Husk:
		_husk = HuskModel.new()
		_husk.setup(HuskModel.Pose.SLUMP, false)
		_husk.set_shadow_only(true)  # (the tape never shows it: its shadow does)
		_root.add_child(_husk)
	elif Entity.is_3d():
		var holder := Node3D.new()  # (the puppet places itself on its parent, like on the entity)
		_root.add_child(holder)
		_ent_model = EntityModel.new()
		holder.add_child(_ent_model)


func _end_playback() -> void:
	if _root:
		_root.queue_free()
		_root = null
		_husk = null
	_puppets.clear()
	_bodies.clear()
	var shown: Dictionary = _restore.get("shown", {})
	for p in shown:  # (untyped: one may have left and been freed meanwhile)
		if is_instance_valid(p):
			(p as Player).visible = shown[p]
	for c in _restore.get("corpses", []):
		if is_instance_valid(c):
			(c as Node3D).visible = true
	run.entity.visible = true
	run.entity.process_mode = Node.PROCESS_MODE_INHERIT
	var doors: Array = _restore.get("doors", [])
	for i in mini(doors.size(), run.level.doors.size()):
		var d: Door = run.level.doors[i]
		d.is_open = doors[i][0]
		d.amount = doors[i][1]
		d._apply()
	var dark: Array = _restore.get("dark", [])
	for i in mini(dark.size(), run.level.lamps.size()):
		run.level.lamps[i].dead = dark[i][0]
		run.level.lamps[i].shadow_enabled = dark[i][1]
	var cam: Camera3D = _restore.get("camera")
	if is_instance_valid(cam):
		cam.current = true


func _play(delta: float) -> void:
	if _clip < 0:
		return
	_t += delta
	if _gap > 0.0:
		_gap -= delta
	while _cursor < _frames.size() - 1 and _frames[_cursor + 1][0] <= _t:
		_cursor += 1
	while _event_cursor < _events.size() and _events[_event_cursor][0] <= _t:
		_fire(_events[_event_cursor])
		_event_cursor += 1
	_apply_frame(false)
	if _t >= _t1 or _frames.is_empty() or _cursor >= _frames.size() - 1 and _t > _frames[-1][0]:
		_next()


## Between-clip static: 0..1 (a cut on the tape).
func static_amount() -> float:
	return clampf(_gap / 0.35, 0.0, 1.0)


func _apply_frame(snap: bool) -> void:
	if _frames.is_empty():
		return
	var a: Array = _frames[_cursor]
	var b: Array = _frames[mini(_cursor + 1, _frames.size() - 1)]
	var span: float = b[0] - a[0]
	var w := clampf((_t - a[0]) / span, 0.0, 1.0) if span > 0.0 else 0.0
	var delta := get_process_delta_time()
	# The house: doors, the power.
	for i in run.level.doors.size():
		var d: Door = run.level.doors[i]
		var want := (int(a[3]) >> i) & 1 == 1
		if want != d.is_open:
			d.is_open = want
			d._swing = Door.SWING_TIME
		if snap:
			d.amount = 1.0 if want else 0.0
			d._apply()
	for i in run.level.lamps.size():
		var lamp: FlickerLight = run.level.lamps[i]
		lamp.dead = a[4]
		lamp.disturbance = 0.0
		lamp.shadow_enabled = _lamp_shadows[i] and not a[4]
	# The bodies of the taken, where they were (dragged off, thrown).
	var bodies: Dictionary = a[5] if a.size() > 5 else {}
	var bodies_b: Dictionary = b[5] if b.size() > 5 else {}
	for id: int in bodies:
		if not _bodies.has(id):
			_bodies[id] = _body_puppet(id)
		var xa: Transform3D = bodies[id]
		(_bodies[id] as Node3D).global_transform = xa.interpolate_with(bodies_b.get(id, xa), w)
	for id: int in _bodies:
		(_bodies[id] as Node3D).visible = bodies.has(id)
	# The players.
	var focus_cam := Transform3D.IDENTITY
	var focus_fov := 70.0
	var have_focus := false
	for id: int in _puppets:
		var pup: Dictionary = _puppets[id]
		var av: PlayerAvatar = pup.avatar
		var light: SpotLight3D = pup.light
		if not a[2].has(id):
			pup.root.visible = false
			light.visible = false
			continue
		var pa: Array = a[2][id]
		var pb: Array = b[2].get(id, pa)
		var holder: Node3D = pup.root
		if not pup.dying:
			holder.global_position = (pa[0] as Vector3).lerp(pb[0], w)
			holder.rotation.y = lerp_angle(pa[1], pb[1], w)
			av.lying = pa[9]
			av.lie_back = pa[10]
			av.set_has_camera(pa[13])
			av.set_has_light(pa[14])
			av.animate(delta, lerpf(pa[4], pb[4], w), lerpf(pa[5], pb[5], w), lerpf(pa[6], pb[6], w), pa[7], lerpf(pa[8], pb[8], w))
			av.visible = pa[11]
		elif not av.dying:
			av.visible = false
		holder.visible = id != _focus
		var cam: Transform3D = (pa[2] as Transform3D).interpolate_with(pb[2], w)
		if id == _focus:
			focus_cam = cam
			focus_fov = pa[3]
			have_focus = true
		light.visible = pa[12] != null
		if pa[12] != null:
			light.global_transform = (pa[12] as Transform3D).interpolate_with(pb[12] if pb[12] != null else pa[12], w)
	if not have_focus and not a[2].is_empty():
		var any: Array = a[2].values()[0]
		focus_cam = any[2]
		focus_fov = any[3]
	_camera.global_transform = focus_cam
	_camera.fov = focus_fov
	# The entity, as the tape saw it (always: the camera sees it).
	var ea: Array = a[1]
	var eb: Array = b[1]
	var at := (ea[0] as Vector3).lerp(eb[0], w)
	_ent.visible = ea[1]
	_ent.region_enabled = ea[4]
	_ent.hframes = ea[6]
	_ent.vframes = ea[7]
	if ea[4]:
		_ent.region_rect = ea[5]
	else:
		_ent.frame = clampi(ea[3], 0, ea[6] * ea[7] - 1)
	_ent.offset = ea[8]
	_ent.billboard = ea[9]
	_ent.flip_h = ea[10]
	_ent.modulate = ea[11]
	var local: Transform3D = ea[2]
	# Drawn a little towards the tape's eye, as it is towards a player's.
	var pull := Vector3.ZERO
	var to := focus_cam.origin - at
	to.y = 0.0
	if to.length() > 0.05:
		pull = to.normalized() * minf(0.45, to.length() * 0.35)
	_ent.global_transform = Transform3D(local.basis, at + local.origin + pull)
	_ent_face.visible = ea[12] and ea[1]
	if _husk and ea.size() > 16:
		_ent.visible = false
		_ent_face.visible = false
		_husk.global_position = at
		_husk.set_pose(ea[16][0])
		_husk.rotation.y = ea[16][1]
	if _ent_model and is_instance_valid(_ent_model):
		var args: Array = ea[15] if ea.size() > 15 else []
		_ent.visible = false
		_ent_face.visible = false
		_ent_model.visible = ea[1] and not args.is_empty()
		if not args.is_empty():
			(_ent_model.get_parent() as Node3D).global_position = at
			_ent_model.drive(get_process_delta_time(), args[0], args[1], args[2], focus_cam.origin, args[3], args[4], args[5], args[6],
					args[7] if args.size() > 7 else true, args[8] if args.size() > 8 else false)
			var face_at := -1.0
			if int(args[0]) == Entity.Pose.LUNGE:
				face_at = Entity.LUNGE_FACE_HEIGHT
			_ent_model.anchor_face(at + Vector3.UP * face_at if face_at > 0.0 else Vector3.INF)
	if ea[12]:
		_ent_face.region_rect = ea[14]
		_ent_face.modulate = ea[11]
		_ent_face.global_transform = Transform3D((ea[13] as Transform3D).basis, at + (ea[13] as Transform3D).origin)


func _fire(ev: Array) -> void:
	var args: Array = ev[2]
	match ev[1]:
		"sfx":
			Sfx.play_3d(_root, args[1], args[0], args[2], args[3])
		"flash":
			var pup: Dictionary = _puppets.get(int(args[0]), {})
			var from := _camera.global_position
			if not pup.is_empty() and int(args[0]) != _focus:
				from = (pup.root as Node3D).global_position + Vector3.UP * 1.4
			var light := OmniLight3D.new()
			light.light_color = Color(0.92, 0.96, 1.0)
			light.light_energy = 9.0
			light.omni_range = 10.0
			light.shadow_enabled = true
			_root.add_child(light)
			light.global_position = from + (-_camera.global_transform.basis.z * 0.3 if int(args[0]) == _focus else Vector3.ZERO)
			var tw := create_tween()
			tw.tween_property(light, "light_energy", 0.0, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tw.tween_callback(light.queue_free)
		"voice":
			var pup: Dictionary = _puppets.get(int(args[0]), {})
			if not pup.is_empty() and is_instance_valid(pup.voice):
				var pb := (pup.voice as AudioStreamPlayer3D).get_stream_playback() as AudioStreamGeneratorPlayback
				if pb and pb.get_frames_available() >= VoiceChat.FRAME:
					pb.push_buffer(VoiceChat._decode(args[1]))
		"death":
			var pup: Dictionary = _puppets.get(int(args[0]), {})
			if not pup.is_empty():
				pup.dying = true
				(pup.avatar as PlayerAvatar).play_death(args[1])


## A limp body like the one the taken left (Corpse: the same pose).
func _body_puppet(id: int) -> Node3D:
	var holder := Node3D.new()
	_root.add_child(holder)
	var av := PlayerAvatar.new()
	var p: Player = run.players.get(id)
	av.tint = p.tint if p else Color.WHITE
	holder.add_child(av)
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 977
	av.pose_dead(rng)
	av.set_has_camera(false)
	return holder
