class_name TvBroadcast
extends Node3D
## The living-room television. It is still playing a tape of ¡Te estoy
## viendo! (TvShow): a man in the Vecinito costume, on a set that is this
## very living room, playing hide-and-seek with the children watching.
## Keep watching and it goes wrong:
##   it stops, hands down, the head tilted, both eyes on you, "TE ESTOY
##   VIENDO, <your name>"; then it cuts to EN DIRECTO: this room, now, seen
##   from the television, you in it, grey and grainy, and something standing
##   behind you, closer at every cut (only on that picture); the costume in
##   the dark, its mouth with an eye inside; static...
## ...and the emergency broadcast cuts in with the rules of the night
## (seal, header, the rules, a crawl). Later the broadcast turns: red, the
## seal with a face, other rules, and now and then a hijack (the torn
## costume head swaying in front of corrugated metal, a buzz).
## The host owns `state` and `watched` (replicated); every machine draws
## them for its own `viewer`.

signal alert_started

enum State { SHOW, INTERRUPT, ALERT, CORRUPT }

## Visual layer 4 (bit 8) is drawn only by the TV's own camera: what stands
## behind you on the live picture.
const FEED_LAYER := 8
const SCREEN_SIZE := Vector2i(320, 240)
const FEED_SIZE := Vector2i(160, 120)
const FONT_SIZE := 18
const CAPTION_SIZE := 22
const INTERRUPT_TIME := 1.1
const BG := Color(0.04, 0.1, 0.48)
const BG_CORRUPT := Color(0.33, 0.02, 0.02)
const LIGHT_SHOW := Color(0.95, 0.85, 0.7)
const LIGHT_FEED := Color(0.75, 0.82, 0.95)
const LIGHT_ALERT := Color(0.45, 0.55, 1.0)
const LIGHT_CORRUPT := Color(1.0, 0.35, 0.3)

var state := State.SHOW
## Seconds someone has watched the show (drives how wrong it has gone).
var watched := 0.0
## Whose screen this is (the live picture shows them, and their name).
var viewer: Player
## Off when the power goes; the corrupted broadcast turns it back on by
## itself (there is no power).
var powered := true

var _shown_state := State.SHOW
var _interrupt_left := 0.0
var _viewport: SubViewport
var _show: TextureRect
var _show_atlas: AtlasTexture
var _caption: Label
var _bug: Label
var _disturb_mat: ShaderMaterial
var _feed_vp: SubViewport
var _feed_cam: Camera3D
var _feed: Control
var _figure: Sprite3D
var _rig: Node3D
var _rig_tally: Node3D
var _rig_flashed := false
var _alert: Control
var _bg: ColorRect
var _seal: TextureRect
var _seal_atlas: AtlasTexture
var _title: Label
var _square: ColorRect
var _body: Label
var _crawl: Label
var _light: OmniLight3D
var _audio: AudioStreamPlayer3D
var _hum: AudioStreamPlayer3D
var _t := 0.0
var _hijack_in := 6.0
var _hijack_left := 0.0
var _whispered := false
var _rng := RandomNumberGenerator.new()
var _screen: MeshInstance3D


## Stands on the "V" cell, screen towards the nearest sofa.
func place(level: Level) -> void:
	var cells := level.spots_of("V")
	if cells.is_empty():
		queue_free()
		return
	var c: Vector3i = cells[0]
	position = level.center(c) + Vector3.UP * Level.TV_STAND_HEIGHT
	_build()
	var sofas := level.spots_of("s")
	if not sofas.is_empty():
		var best: Vector3i = sofas[0]
		for s: Vector3i in sofas:
			if Vector3(s - c).length() < Vector3(best - c).length():
				best = s
		var look := level.center(best)
		look.y = position.y
		look_at_from_position(position, look, Vector3.UP)
	else:
		for d in Level.DIRS:
			var n := c + Vector3i(d.x, 0, d.y)
			if level.is_walkable(n):
				var look := level.center(n)
				look.y = position.y
				look_at_from_position(position, look, Vector3.UP)
				break


## Host: someone is watching the show; after a while it goes wrong, then
## the alert cuts in.
## Where to sit to watch it (the sofa's cells, then the floor behind them),
## facing the screen: [position, yaw] for each viewer in turn.
func seat_for(i: int) -> Array:
	var level := get_parent() as Level
	var spots: Array = level.spots_of("s").duplicate()
	# The seat right in front of the screen first, then the ones beside it.
	var me := global_position
	spots.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return _flat_dist(level.center(a), me) < _flat_dist(level.center(b), me))
	var to_tv := Vector3.ZERO
	var at := global_position
	if i < spots.size():
		at = level.center(spots[i])
	elif not spots.is_empty():
		var back := _flat_dir(level.center(spots[0]) - global_position)
		at = level.center(spots[i % spots.size()]) + back * 0.9
	to_tv = _flat_dir(global_position - at)
	at += to_tv * 0.12  # sat forward on the cushion
	var floor_y := level.center(level.cell_of(at)).y
	# How wide to look: the set (and the camcorder on it) filling about
	# half of the picture, whatever the distance.
	var screen_c := global_position + Vector3.UP * 0.35
	var eye := Vector3(at.x, floor_y + Tuning.SEAT_EYE, at.z)
	var d := eye.distance_to(screen_c)
	var fov := clampf(rad_to_deg(2.0 * atan(0.75 / 0.5 * 0.5 / d)), 18.0, 60.0)
	var pitch := atan2(screen_c.y - eye.y, Vector2(screen_c.x - eye.x, screen_c.z - eye.z).length())
	return [Vector3(at.x, floor_y, at.z), atan2(-to_tv.x, -to_tv.z), fov, pitch]


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _flat_dir(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else Vector3.FORWARD


func watch(delta: float) -> void:
	if state != State.SHOW:
		return
	watched += delta
	if disturbance() >= 1.0:
		interrupt()


## 0 the show is fine .. 1 it is about to be cut.
func disturbance() -> float:
	return clampf((watched - Tuning.TV_DISTURB_AT) / Tuning.TV_DISTURB_TIME, 0.0, 1.0)


## Host: the emergency broadcast cuts the show (also if nobody watches).
func interrupt() -> void:
	if state != State.SHOW:
		return
	state = State.INTERRUPT
	_interrupt_left = INTERRUPT_TIME


## Host: the broadcast starts giving other rules.
func set_corrupted() -> void:
	state = State.CORRUPT


## Every machine: the power is gone, the screen dies.
func power_off() -> void:
	powered = false
	_screen.visible = false
	_audio.stop()
	_hum.stop()
	_set_feed(false)


func is_showing_text() -> bool:
	return state == State.ALERT or state == State.CORRUPT


## What the screen shows right now, for watching it full size.
func screen_texture() -> Texture2D:
	return _viewport.get_texture()


## The current broadcast text.
func text() -> String:
	return "%s\n\n%s" % [_title.text, _body.text]


## Every machine: show what `state` says (called when it changes).
func _apply_state() -> void:
	_shown_state = state
	match state:
		State.SHOW:
			_show.visible = true
			_alert.visible = false
		State.INTERRUPT:
			_set_feed(false)
			_caption.text = ""
			_audio.stream = Sfx.get_stream("static", true)
			_audio.volume_db = -6.0
			_audio.pitch_scale = 1.0
			_audio.play()
			_hum.stop()
		State.ALERT, State.CORRUPT:
			_show_rules(state == State.CORRUPT)


func _show_rules(p_corrupted: bool) -> void:
	if p_corrupted and not powered:
		powered = true
		_screen.visible = true
	_set_feed(false)
	_show.visible = false
	_caption.text = ""
	_bug.visible = false
	_alert.visible = true
	_disturb_mat.set_shader_parameter("disturb", 0.12 if p_corrupted else 0.02)
	_bg.color = BG_CORRUPT if p_corrupted else BG
	_seal_atlas.region = Rect2(96 if p_corrupted else 0, 0, 96, 96)
	if p_corrupted:
		_title.text = tr("AVISO - CANAL 9")
		_body.text = tr("ACTUALIZACIÓN:\n1. YA NO ES NECESARIO GRABAR.\n2. APAGUE LA CÁMARA.\n3. LA VISITA ES SU AMIGA.\n4. QUÉDESE QUIETO. YA LE HA VISTO.\n5. SI PREGUNTA DÓNDE ESTÁ, CONTÉSTELE.\nTE ESTOY VIENDO. TE ESTOY VIENDO.")
		_crawl.text = tr("TE ESTOY VIENDO · TE ESTOY VIENDO · NO HAY NADIE EN LA FURGONETA · TE ESTOY VIENDO · ")
	else:
		_title.text = tr("COMUNICADO")
		_body.text = tr("A LOS VECINOS DE LA CALLE OLMOS:\nESTA NOCHE HAY VISITA.\nNO LA BUSQUE CON LOS OJOS.\nA LA VISITA NO LE GUSTAN LAS FOTOS.\nSI ALGUIEN CANTA, NO LE DÉ LA ESPALDA.\nSI LE DICEN «TE ESTOY VIENDO», SIGA ANDANDO.\nSI PREGUNTA DÓNDE ESTÁ, NO CONTESTE.\nBUENAS NOCHES.")
		_crawl.text = tr("CANAL 9 · PERMANEZCAN EN SINTONÍA · NO ABRAN LA PUERTA · BUENAS NOCHES · ")
	_body.position.y = 92.0
	_crawl.position.x = SCREEN_SIZE.x
	_audio.stream = Sfx.get_stream("tv_tone", true)
	_audio.volume_db = -12.0 if p_corrupted else -24.0  # (the first one is a quiet notice)
	_audio.pitch_scale = 1.0
	_audio.play()


func _process(delta: float) -> void:
	_t += delta
	if state != _shown_state:
		_apply_state()
	var e := 0.75 + 0.12 * sin(_t * 23.0) * sin(_t * 7.0)
	match state:
		State.SHOW:
			e *= _play_show()
		State.INTERRUPT:
			# Snow, then the colour bars and the tone.
			var bars := _interrupt_left < 0.35
			_show.visible = true
			_show_atlas.region = TvShow.region(TvShow.BARS if bars else [TvShow.STATIC_A, TvShow.STATIC_B][int(_t * 20.0) % 2])
			_disturb_mat.set_shader_parameter("disturb", 0.2 if bars else 0.9)
			if bars and _audio.stream != Sfx.get_stream("tv_tone", true):
				_audio.stream = Sfx.get_stream("tv_tone", true)
				_audio.play()
			e *= _rng.randf_range(0.3, 1.2)
			if is_multiplayer_authority():
				_interrupt_left -= delta
				if _interrupt_left <= 0.0:
					state = State.ALERT
					alert_started.emit()
			else:
				_interrupt_left -= delta
		State.ALERT, State.CORRUPT:
			e *= _play_alert(delta)
	_light.light_energy = e if powered else 0.0


## The programme, and how it goes wrong (the energy of the screen's glow).
func _play_show() -> float:
	var p := disturbance()
	var cue: Array = TvShow.at(_t)
	var frame: int = cue[0]
	var caption: String = cue[1]
	var feed := false
	var glow := 1.0
	var who := viewer.display_name.to_upper() if viewer else tr("VECINITO")
	var s := p * Tuning.TV_DISTURB_TIME  # seconds into it going wrong
	if s >= 1.25 and s < 3.25:
		# It stops. Head tilted, both eyes on you, your name (two seconds).
		frame = TvShow.STARE
		caption = tr("TE ESTOY VIENDO, %s") % who
		glow = 0.7
	elif s >= 3.25:
		# Cuts: this room, now, from the television; the costume in the
		# dark; the eye in its mouth.
		var x := s - 3.25
		caption = ""
		if x < 0.5 or (x >= 0.7 and x < 1.25) or x >= 1.37:
			feed = true
		elif x < 0.7:
			frame = TvShow.STARE_DARK
		else:
			frame = TvShow.CLOSE
		if p > 0.88 and _rng.randf() < 0.3:
			feed = false
			frame = [TvShow.STATIC_A, TvShow.STATIC_B][_rng.randi() % 2]
		glow = 0.5
	_set_feed(feed)
	if feed:
		_place_figure(p)
		if p > 0.8 and not _whispered:
			_whispered = true
			Sfx.play_3d(self, global_position + Vector3.UP * 0.3, "voice_reverse", -2.0)
	_show_atlas.region = TvShow.region(frame)
	_caption.text = caption
	_bug.visible = not feed
	_disturb_mat.set_shader_parameter("disturb", clampf(p * 1.3, 0.0, 0.7) if not feed else 0.25)
	# The tape slows as it goes wrong; on the live picture, only a hum.
	_audio.pitch_scale = lerpf(1.0, 0.55, p)
	_audio.volume_db = -40.0 if feed else (-10.0 - 6.0 * p)
	_light.light_color = LIGHT_FEED if feed else LIGHT_SHOW.lerp(LIGHT_CORRUPT, p * 0.5)
	return glow * (0.85 + 0.15 * sin(_t * 3.1))


## The live picture: from the screen, looking out at the room. Its camera
## renders only while it is on.
func _set_feed(on: bool) -> void:
	if _feed == null or _feed.visible == on:
		return
	_feed.visible = on
	_show.visible = not on
	_figure.visible = on
	if _rig_tally:
		_rig_tally.visible = on
	_feed_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		# From the camcorder on top, framed on whoever sits watching.
		_feed_cam.global_transform = global_transform * Transform3D(Basis(), Vector3(0.06, 0.62, -0.32))
		if viewer:
			var aim := viewer.global_position + Vector3.UP * 0.9
			if aim.distance_to(_feed_cam.global_position) > 0.5:
				_feed_cam.look_at(aim, Vector3.UP)
			_feed_cam.fov = clampf(rad_to_deg(2.0 * atan(1.6 / maxf(1.0, aim.distance_to(_feed_cam.global_position)))), 30.0, 78.0)
		if not _hum.playing:
			_hum.play()
	else:
		_hum.stop()


## The camcorder on top fires its flash at the room (what you will do).
func _rig_flash() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(0.92, 0.96, 1.0)
	light.light_energy = 9.0
	light.omni_range = 9.0
	light.shadow_enabled = true
	add_child(light)
	light.global_position = _rig.global_position - global_transform.basis.z * 0.25
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(light.queue_free)
	Sfx.play_3d(self, light.global_position, "flash_fire", 0.0)
	Sfx.play_3d(self, _figure.global_position + Vector3.UP * 1.5, "voice_agony", -2.0)


## Behind whoever watches, a little closer at every cut (it is not there
## when you turn round: only the television sees it).
func _place_figure(p: float) -> void:
	if viewer == null:
		_figure.visible = false
		return
	var away := viewer.global_position - global_position
	away.y = 0.0
	var dist := lerpf(2.6, 0.55, clampf((p - 0.45) / 0.45, 0.0, 1.0))
	# Seen by the camera on the TV, it runs off (out of the room): the
	# camera sees it; you never do.
	var fleeing := p > 0.9
	if fleeing:
		# The camcorder on the set flashes it: burnt red, it runs off.
		if not _rig_flashed:
			_rig_flashed = true
			_rig_flash()
		dist = 0.55 + (p - 0.9) * 60.0
	_figure.modulate = Color(1.3, 0.25, 0.2) if fleeing else Color(0.8, 0.8, 0.8)
	_figure.frame = (Entity.Pose.RUN if fleeing else Entity.Pose.REACH) * Entity.sheet_columns() + (int(_t * 10.0) % Entity.sheet_columns() if fleeing else 0)
	if int(Entity.Pose.RUN) >= Entity.sheet_rows():
		_figure.frame = Entity.Pose.REACH * Entity.sheet_columns()
	var dir := away.normalized() if away.length() > 0.1 else -global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var from := viewer.global_position + Vector3.UP
	# Over their shoulder, not hidden right behind them.
	var to := from + dir * dist + dir.cross(Vector3.UP).normalized() * 0.55
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Tuning.LAYER_WORLD))
	if not hit.is_empty():
		to = from + dir * maxf(0.3, from.distance_to(hit.position) - 0.3)
	_figure.global_position = Vector3(to.x, viewer.global_position.y, to.z)


## The emergency broadcast (the energy of the glow).
func _play_alert(delta: float) -> float:
	var corrupt := state == State.CORRUPT
	_crawl.position.x -= delta * 34.0
	if _crawl.position.x < -_crawl.get_minimum_size().x:
		_crawl.position.x = SCREEN_SIZE.x
	_square.visible = corrupt and fmod(_t, 1.0) < 0.5
	_light.light_color = LIGHT_CORRUPT if corrupt else LIGHT_ALERT
	var e := 1.0
	if corrupt:
		if _rng.randf() < delta * 2.0:
			e *= 0.2
			_title.text = _glitch(tr("AVISO - CANAL 9"))
		# Now and then, a hijack: the torn head in front of the turning metal.
		if _hijack_left > 0.0:
			_hijack_left -= delta
			_show.visible = true
			_alert.visible = _hijack_left <= 0.0
			_show_atlas.region = TvShow.region(TvShow.INTRUDE_A + int(_t * 10.0) % 4)
			_disturb_mat.set_shader_parameter("disturb", 0.35)
			if _hijack_left <= 0.0:
				_show.visible = false
				_disturb_mat.set_shader_parameter("disturb", 0.12)
				_audio.stream = Sfx.get_stream("tv_tone", true)
				_audio.volume_db = -12.0
				_audio.play()
			return _rng.randf_range(0.5, 1.3)
		_hijack_in -= delta
		if _hijack_in <= 0.0 and powered:
			_hijack_in = _rng.randf_range(7.0, 14.0)
			_hijack_left = _rng.randf_range(0.6, 1.6)
			_alert.visible = false
			_audio.stream = Sfx.get_stream("intrusion_buzz", true)
			_audio.volume_db = -4.0
			_audio.play()
	return e


func _glitch(text: String) -> String:
	var chars := text.split("")
	for i in 3:
		chars[_rng.randi() % chars.size()] = ["#", "%", "?", "V"][_rng.randi() % 4]
	return "".join(chars)


## The set itself: a 1980s colour TV in a wood-veneer cabinet: the picture
## tube's dark plastic bezel round the screen, a strip under it with two
## knobs, push buttons, the channel display and a speaker grille, the
## tube's tapered back, little feet, and rabbit-ear aerials on top.
func _build_set() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/textures/wood_dark.png")
	wood.albedo_color = Color(0.85, 0.72, 0.6)
	wood.roughness = 0.55
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(2.5, 2.5, 2.5)
	var dark := StandardMaterial3D.new()
	dark.albedo_texture = load("res://assets/textures/plastic.png")
	dark.albedo_color = Color(0.16, 0.15, 0.14)
	dark.roughness = 0.45
	dark.uv1_triplanar = true
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.62, 0.6, 0.55)
	metal.metallic = 0.8
	metal.roughness = 0.3
	var grille := StandardMaterial3D.new()
	grille.albedo_color = Color(0.06, 0.055, 0.05)
	grille.roughness = 0.9
	# The cabinet: top, sides and base in wood, open at the front.
	_tv_box(wood, Vector3(0.68, 0.035, 0.34), Vector3(0, 0.505, -0.06))      # top
	_tv_box(wood, Vector3(0.68, 0.035, 0.34), Vector3(0, -0.015, -0.06))     # base
	_tv_box(wood, Vector3(0.035, 0.52, 0.34), Vector3(-0.3225, 0.245, -0.06))  # sides
	_tv_box(wood, Vector3(0.035, 0.52, 0.34), Vector3(0.3225, 0.245, -0.06))
	# The front: dark plastic, recessed a little behind the wood's edge.
	_tv_box(dark, Vector3(0.61, 0.5, 0.02), Vector3(0, 0.245, -0.215))
	# The bezel round the picture: a raised frame, the tube's rounded corners.
	var w := 0.48
	var h := 0.36
	var t := 0.03
	_tv_box(dark, Vector3(w + t * 2, t, 0.03), Vector3(0, 0.27 + h * 0.5 + t * 0.5, -0.232))
	_tv_box(dark, Vector3(w + t * 2, t, 0.03), Vector3(0, 0.27 - h * 0.5 - t * 0.5, -0.232))
	_tv_box(dark, Vector3(t, h, 0.03), Vector3(-w * 0.5 - t * 0.5, 0.27, -0.232))
	_tv_box(dark, Vector3(t, h, 0.03), Vector3(w * 0.5 + t * 0.5, 0.27, -0.232))
	# The strip under the picture: speaker grille, buttons, two knobs.
	for i in 9:
		_tv_box(grille, Vector3(0.16, 0.005, 0.004), Vector3(-0.2, 0.02 + i * 0.0075, -0.226))
	for i in 4:
		_tv_box(metal, Vector3(0.028, 0.018, 0.012), Vector3(0.02 + i * 0.036, 0.04, -0.229))
	for x: float in [0.21, 0.27]:
		var knob := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.019
		cyl.bottom_radius = 0.022
		cyl.height = 0.025
		cyl.radial_segments = 12
		knob.mesh = cyl
		knob.material_override = dark
		knob.rotation.x = PI / 2
		knob.position = Vector3(x, 0.042, -0.236)
		add_child(knob)
		var mark := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.003, 0.016, 0.003)
		mark.mesh = bar
		mark.material_override = metal
		mark.position = Vector3(x, 0.048, -0.25)
		mark.rotation.z = randf_range(-1.2, 1.2)
		add_child(mark)
	var brand := Label3D.new()
	brand.text = "VISTAVOX"
	brand.font_size = 22
	brand.pixel_size = 0.0012
	brand.modulate = Color(0.75, 0.65, 0.4)
	brand.position = Vector3(-0.2, 0.077, -0.227)
	brand.rotation.y = PI
	add_child(brand)
	# The picture tube's back: tapered, dark, with vents.
	var back := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.19
	cone.bottom_radius = 0.33
	cone.height = 0.24
	cone.radial_segments = 4
	cone.rings = 1
	back.mesh = cone
	back.material_override = dark
	back.rotation = Vector3(-PI / 2, 0, PI / 4)
	back.scale = Vector3(1.0, 1.0, 0.75)
	back.position = Vector3(0, 0.25, 0.22)
	add_child(back)
	# Little feet, and the rabbit ears on top.
	for x: float in [-0.27, 0.27]:
		for z: float in [-0.2, 0.08]:
			_tv_box(dark, Vector3(0.05, 0.02, 0.05), Vector3(x, -0.04, z))
	var base := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.04
	dome.height = 0.04
	dome.is_hemisphere = true
	base.mesh = dome
	base.material_override = dark
	base.position = Vector3(-0.18, 0.522, 0.0)
	add_child(base)
	for side: float in [-1.0, 1.0]:
		var rod := MeshInstance3D.new()
		var r := CylinderMesh.new()
		r.top_radius = 0.003
		r.bottom_radius = 0.004
		r.height = 0.42
		r.radial_segments = 5
		rod.mesh = r
		rod.material_override = metal
		rod.rotation = Vector3(0.15, 0, 0.55 * side)
		rod.position = Vector3(-0.18 - side * 0.1, 0.71, 0.03)
		add_child(rod)


func _tv_box(mat: Material, size: Vector3, pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	m.position = pos
	add_child(m)


func _label(size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l


func _build() -> void:
	_build_set()

	_viewport = SubViewport.new()
	_viewport.size = SCREEN_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)

	_show_atlas = AtlasTexture.new()
	_show_atlas.atlas = load(TvShow.SHEET)
	if _show_atlas.atlas == null:
		push_error("TvBroadcast: missing %s (run tools/gen_tv.py and import)" % TvShow.SHEET)
	_show_atlas.region = TvShow.region(TvShow.COVER_A)
	_show = TextureRect.new()
	_show.texture = _show_atlas
	_show.size = SCREEN_SIZE
	_viewport.add_child(_show)

	# The live picture: a camera in the screen looking out at the room.
	_feed_vp = SubViewport.new()
	_feed_vp.size = FEED_SIZE
	_feed_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_feed_vp)
	_feed_cam = Camera3D.new()
	_feed_cam.fov = 78.0
	_feed_cam.cull_mask = 1 | FEED_LAYER | PlayerAvatar.SELF_LAYER
	_feed_vp.add_child(_feed_cam)
	_feed_cam.current = true
	_feed = Control.new()
	_feed.size = SCREEN_SIZE
	_feed.visible = false
	_viewport.add_child(_feed)
	var feed_pic := TextureRect.new()
	feed_pic.texture = _feed_vp.get_texture()
	feed_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	feed_pic.stretch_mode = TextureRect.STRETCH_SCALE
	feed_pic.size = SCREEN_SIZE
	var feed_mat := ShaderMaterial.new()
	feed_mat.shader = load("res://shaders/tv_feed.gdshader")
	feed_pic.material = feed_mat
	_feed.add_child(feed_pic)
	var live := _label(16, Color(0.95, 0.95, 0.9))
	live.text = tr("● EN DIRECTO")
	live.position = Vector2(12, 8)
	live.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	_feed.add_child(live)
	var cam_label := _label(16, Color(0.9, 0.9, 0.85))
	cam_label.text = tr("CANAL 9 · SALÓN")
	cam_label.position = Vector2(12, SCREEN_SIZE.y - 26)
	_feed.add_child(cam_label)

	# What stands behind you, on that picture only.
	_figure = Sprite3D.new()
	_figure.texture = load(Entity.sheet())
	_figure.hframes = Entity.sheet_columns()
	_figure.vframes = Entity.sheet_rows()
	_figure.frame = Entity.Pose.REACH * Entity.sheet_columns()
	_figure.pixel_size = Entity.HEIGHT / Entity.frame_size().y
	_figure.offset = Vector2(0, Entity.frame_size().y * 0.5)
	_figure.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_figure.shaded = false
	_figure.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_figure.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_figure.modulate = Color(0.8, 0.8, 0.8)
	_figure.layers = FEED_LAYER
	_figure.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_figure.top_level = true
	_figure.visible = false
	add_child(_figure)

	# The station's mark and the captions, over the programme.
	_bug = _label(14, Color(1, 1, 1, 0.55))
	_bug.text = "9"
	_bug.position = Vector2(SCREEN_SIZE.x - 24, 8)
	_viewport.add_child(_bug)
	_caption = _label(CAPTION_SIZE, Color(1.0, 0.95, 0.4))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD
	_caption.position = Vector2(8, SCREEN_SIZE.y - 60)
	_caption.size = Vector2(SCREEN_SIZE.x - 16, 54)
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_viewport.add_child(_caption)

	# The emergency broadcast.
	_alert = Control.new()
	_alert.size = SCREEN_SIZE
	_alert.visible = false
	_viewport.add_child(_alert)
	_bg = ColorRect.new()
	_bg.size = SCREEN_SIZE
	_bg.color = BG
	_alert.add_child(_bg)
	var clip := Control.new()  # the rules crawl inside this window
	clip.position = Vector2(0, 84)
	clip.size = Vector2(SCREEN_SIZE.x, 128)
	clip.clip_contents = true
	_alert.add_child(clip)
	_body = _label(FONT_SIZE, Color(0.92, 0.92, 0.88))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body.position = Vector2(12, 0)
	_body.size = Vector2(SCREEN_SIZE.x - 24, 10)
	clip.add_child(_body)
	var band := ColorRect.new()
	band.size = Vector2(SCREEN_SIZE.x, 26)
	band.color = Color(0.9, 0.9, 0.85)
	_alert.add_child(band)
	_square = ColorRect.new()
	_square.position = Vector2(SCREEN_SIZE.x - 22, 7)
	_square.size = Vector2(12, 12)
	_square.color = Color(0.85, 0.08, 0.06)
	_alert.add_child(_square)
	_title = _label(20, Color(0.05, 0.05, 0.1))
	_title.position = Vector2(10, 0)
	_alert.add_child(_title)
	_seal_atlas = AtlasTexture.new()
	_seal_atlas.atlas = load(TvShow.SEALS)
	_seal_atlas.region = Rect2(0, 0, 96, 96)
	_seal = TextureRect.new()
	_seal.texture = _seal_atlas
	_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_seal.stretch_mode = TextureRect.STRETCH_SCALE
	_seal.position = Vector2(10, 32)
	_seal.size = Vector2(48, 48)
	_alert.add_child(_seal)
	var org := _label(16, Color(0.95, 0.85, 0.5))
	org.text = tr("PROTECCIÓN CIVIL\nCANAL 9 · SERVICIO PÚBLICO")
	org.position = Vector2(66, 38)
	_alert.add_child(org)
	var foot := ColorRect.new()
	foot.position = Vector2(0, SCREEN_SIZE.y - 24)
	foot.size = Vector2(SCREEN_SIZE.x, 24)
	foot.color = Color(0, 0, 0, 0.6)
	_alert.add_child(foot)
	_crawl = _label(16, Color(0.95, 0.95, 0.9))
	_crawl.position = Vector2(SCREEN_SIZE.x, SCREEN_SIZE.y - 23)
	_alert.add_child(_crawl)

	# Over everything, the tape: torn lines, roll, colour drain, snow.
	var overlay := ColorRect.new()
	overlay.size = SCREEN_SIZE
	_disturb_mat = ShaderMaterial.new()
	_disturb_mat.shader = load("res://shaders/tv_disturb.gdshader")
	overlay.material = _disturb_mat
	_viewport.add_child(overlay)

	var screen := MeshInstance3D.new()
	_screen = screen
	var quad := QuadMesh.new()
	quad.size = Vector2(0.48, 0.36)
	screen.mesh = quad
	screen.position = Vector3(0, 0.27, -0.242)
	screen.rotation.y = PI
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_texture = _viewport.get_texture()
	glass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR  # (nearest made small letters break up)
	screen.material_override = glass
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen)
	# The glass over the picture: it catches the lights of the room.
	var shine := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = quad.size
	shine.mesh = sq
	shine.position = screen.position + Vector3(0, 0, -0.006)
	shine.rotation.y = PI
	var gloss := StandardMaterial3D.new()
	gloss.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gloss.albedo_color = Color(0.7, 0.75, 0.8, 0.06)
	gloss.roughness = 0.05
	gloss.metallic_specular = 1.0
	shine.material_override = gloss
	shine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shine)
	# A camcorder sat on top of the set, looking at the sofa: what the live
	# picture comes from. Its red light comes on when it shows the room.
	_rig = GearModels.camcorder()
	_rig.position = Vector3(0.06, 0.56, -0.1)
	add_child(_rig)
	_rig_tally = _rig.get_node("Tally")
	var read := ReadableScreen.new()
	read.tv = self
	read.position = Vector3(0, 0.27, -0.25)
	add_child(read)

	_light = OmniLight3D.new()
	_light.light_color = LIGHT_SHOW
	_light.omni_range = 4.0
	_light.omni_attenuation = 1.6
	_light.light_volumetric_fog_energy = 1.5
	_light.position = Vector3(0, 0.3, -0.55)
	add_child(_light)

	_audio = AudioStreamPlayer3D.new()
	_audio.stream = Sfx.get_stream("show_theme", true)
	_audio.volume_db = -10.0
	_audio.unit_size = 2.0
	_audio.position.y = 0.3
	_audio.bus = "Effects"
	add_child(_audio)
	_audio.play()
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = Sfx.get_stream("drone", true)
	_hum.volume_db = -8.0
	_hum.unit_size = 2.0
	_hum.position.y = 0.3
	_hum.bus = "Effects"
	add_child(_hum)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["state", "watched"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	sync.replication_interval = 0.1
	add_child(sync)
