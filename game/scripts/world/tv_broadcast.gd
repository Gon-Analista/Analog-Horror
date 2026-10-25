class_name TvBroadcast
extends Node3D
## The living-room television. It is still showing ¡Hola, Vecinitos!, with
## Vecinito in his normal, friendly form. Keep watching and the show goes
## wrong: he stops waving and stares, his eyes empty, his jaw drops, the
## colour drains and the tape slows... then the emergency broadcast cuts in
## by itself with the rules of the night. Later it starts giving other
## rules (the authority turns: Informe §LOCAL58). The host owns `state`
## and `watched` (replicated); every machine draws them.

signal alert_started

enum State { SHOW, INTERRUPT, ALERT, CORRUPT }

const SCREEN_SIZE := Vector2i(320, 240)
const FONT_SIZE := 22
const SHOW_SHEET := "res://assets/textures/tv_show.png"
const SHOW_FRAMES := 6
const STATIC_FRAMES := [6, 7]
## Frames of the show going wrong, in order, and when each starts (0..1 of
## the disturbance).
const DISTURB_FRAMES := [8, 9, 10, 11]
const DISTURB_STEPS := [0.0, 0.3, 0.6, 0.85]
const SHOW_FPS := 6.0
const INTERRUPT_TIME := 0.9
const BG := Color(0.05, 0.12, 0.55)
const BG_CORRUPT := Color(0.35, 0.02, 0.02)
const LIGHT_SHOW := Color(0.85, 0.85, 1.0)
const LIGHT_ALERT := Color(0.45, 0.55, 1.0)
const LIGHT_CORRUPT := Color(1.0, 0.35, 0.3)

var state := State.SHOW
## Seconds someone has watched the show (drives how wrong it has gone).
var watched := 0.0
var _shown_state := State.SHOW
var _interrupt_left := 0.0
var _viewport: SubViewport
var _show: TextureRect
var _show_atlas: AtlasTexture
var _disturb_mat: ShaderMaterial
var _alert: Control
var _bg: ColorRect
var _title: Label
var _body: Label
var _light: OmniLight3D
var _audio: AudioStreamPlayer3D
var _t := 0.0
var _rng := RandomNumberGenerator.new()


## Stands on the "V" cell, screen towards the nearest sofa.
func place(level: Level) -> void:
	var cells := level.spots_of("V")
	if cells.is_empty():
		queue_free()
		return
	var c: Vector2i = cells[0]
	position = level.center(c) + Vector3.UP * Level.TV_STAND_HEIGHT
	_build()
	var sofas := level.spots_of("s")
	if not sofas.is_empty():
		var best: Vector2i = sofas[0]
		for s: Vector2i in sofas:
			if Vector2(s - c).length() < Vector2(best - c).length():
				best = s
		var look := level.center(best)
		look.y = position.y
		look_at_from_position(position, look, Vector3.UP)


## Host: someone is watching the show; after a while it goes wrong, then
## the alert cuts in.
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


## Every machine: show what `state` says (called when it changes).
func _apply_state() -> void:
	_shown_state = state
	match state:
		State.SHOW:
			_show.visible = true
			_alert.visible = false
		State.INTERRUPT:
			_disturb_mat.set_shader_parameter("disturb", 1.0)
			_audio.stream = Sfx.get_stream("static", true)
			_audio.volume_db = -6.0
			_audio.pitch_scale = 1.0
			_audio.play()
		State.ALERT, State.CORRUPT:
			_show_rules(state == State.CORRUPT)


func _show_rules(p_corrupted: bool) -> void:
	_show.visible = false
	_alert.visible = true
	_disturb_mat.set_shader_parameter("disturb", 0.15 if p_corrupted else 0.0)
	_bg.color = BG_CORRUPT if p_corrupted else BG
	if p_corrupted:
		_title.text = tr("AVISO - CANAL 9")
		_body.text = tr("ACTUALIZACIÓN:\n1. YA NO ES NECESARIO GRABAR.\n2. APAGUE LA CÁMARA.\n3. LA VISITA ES SU AMIGA.\n4. RESPONDA CUANDO LE LLAMEN.\nHOLA VECINITO. HOLA VECINITO.")
	else:
		_title.text = tr("AVISO DE EMERGENCIA")
		_body.text = tr("CANAL 9 INFORMA:\nZONA EVACUADA.\n1. LA VISITA NO SE VE A SIMPLE VISTA.\n2. NO SE MUEVE MIENTRAS ES GRABADA.\n3. SI OYE LA CANCIÓN, NO LE DÉ LA ESPALDA.\n4. NO RESPONDA SI LE LLAMAN VECINITO.")
	_body.position.y = SCREEN_SIZE.y
	_audio.stream = Sfx.get_stream("tv_tone", true)
	_audio.volume_db = -12.0
	_audio.play()


func is_showing_text() -> bool:
	return state == State.ALERT or state == State.CORRUPT


## What the screen shows right now, for watching it full size.
func screen_texture() -> Texture2D:
	return _viewport.get_texture()


## The current broadcast text.
func text() -> String:
	return "%s\n\n%s" % [_title.text, _body.text]


func _process(delta: float) -> void:
	_t += delta
	if state != _shown_state:
		_apply_state()
	var e := 0.75 + 0.12 * sin(_t * 23.0) * sin(_t * 7.0)
	match state:
		State.SHOW:
			var p := disturbance()
			var frame := int(_t * SHOW_FPS) % SHOW_FRAMES
			if p > 0.0:
				for i in DISTURB_STEPS.size():
					if p >= DISTURB_STEPS[i]:
						frame = DISTURB_FRAMES[i]
				if p > 0.85 and _rng.randf() < 0.25:
					frame = STATIC_FRAMES[_rng.randi() % 2]
			_show_atlas.region.position.x = frame * SCREEN_SIZE.x
			_disturb_mat.set_shader_parameter("disturb", p)
			# The tape slows down as it goes wrong.
			_audio.pitch_scale = lerpf(1.0, 0.5, p)
			e *= (0.85 + 0.15 * sin(_t * 3.1)) * (1.0 - 0.5 * p)
			_light.light_color = LIGHT_SHOW.lerp(LIGHT_CORRUPT, p * 0.6)
		State.INTERRUPT:
			_show_atlas.region.position.x = STATIC_FRAMES[int(_t * 20.0) % 2] * SCREEN_SIZE.x
			e *= _rng.randf_range(0.3, 1.2)
			if is_multiplayer_authority():
				_interrupt_left -= delta
				if _interrupt_left <= 0.0:
					state = State.ALERT
					alert_started.emit()
		State.ALERT, State.CORRUPT:
			# The text crawls up and starts again.
			_body.position.y -= delta * 9.0
			if _body.position.y < -_body.get_line_count() * FONT_SIZE:
				_body.position.y = SCREEN_SIZE.y
			_light.light_color = LIGHT_CORRUPT if state == State.CORRUPT else LIGHT_ALERT
			if state == State.CORRUPT and _rng.randf() < delta * 2.0:
				e *= 0.2
				_title.text = _glitch(tr("AVISO - CANAL 9"))
	_light.light_energy = e


func _glitch(text: String) -> String:
	var chars := text.split("")
	for i in 3:
		chars[_rng.randi() % chars.size()] = ["#", "%", "?", "V"][_rng.randi() % 4]
	return "".join(chars)


func _build() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.62, 0.5, 0.48)
	body.mesh = box
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = Color(0.1, 0.09, 0.08)
	plastic.roughness = 0.6
	body.material_override = plastic
	body.position.y = 0.25
	add_child(body)

	_viewport = SubViewport.new()
	_viewport.size = SCREEN_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)

	_show_atlas = AtlasTexture.new()
	_show_atlas.atlas = load(SHOW_SHEET)
	if _show_atlas.atlas == null:
		push_error("TvBroadcast: missing %s (run tools/gen_tv.py and import)" % SHOW_SHEET)
	_show_atlas.region = Rect2(0, 0, SCREEN_SIZE.x, SCREEN_SIZE.y)
	_show = TextureRect.new()
	_show.texture = _show_atlas
	_show.size = SCREEN_SIZE
	_viewport.add_child(_show)

	# Over the picture, the disturbance (reads this viewport's screen).
	var overlay := ColorRect.new()
	overlay.size = SCREEN_SIZE
	_disturb_mat = ShaderMaterial.new()
	_disturb_mat.shader = load("res://shaders/tv_disturb.gdshader")
	overlay.material = _disturb_mat
	_viewport.add_child(overlay)

	_alert = Control.new()
	_alert.size = SCREEN_SIZE
	_alert.visible = false
	_viewport.add_child(_alert)
	_bg = ColorRect.new()
	_bg.size = SCREEN_SIZE
	_bg.color = BG
	_alert.add_child(_bg)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", FONT_SIZE)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body.position = Vector2(10, SCREEN_SIZE.y)
	_body.size = Vector2(SCREEN_SIZE.x - 20, 10)
	_alert.add_child(_body)
	var band := ColorRect.new()
	band.size = Vector2(SCREEN_SIZE.x, 28)
	band.color = Color(0.85, 0.85, 0.8)
	_alert.add_child(band)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", FONT_SIZE)
	_title.add_theme_color_override("font_color", Color(0.05, 0.05, 0.1))
	_title.position = Vector2(10, 2)
	_alert.add_child(_title)
	_viewport.move_child(overlay, -1)

	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.48, 0.36)
	screen.mesh = quad
	screen.position = Vector3(0, 0.27, -0.242)
	screen.rotation.y = PI
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_texture = _viewport.get_texture()
	glass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	screen.material_override = glass
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen)
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
	add_child(_audio)
	_audio.play()
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
