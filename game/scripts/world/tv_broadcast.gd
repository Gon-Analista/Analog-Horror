class_name TvBroadcast
extends Node3D
## The living-room television, stuck on the emergency broadcast. It gives
## the rules of the night... until it starts giving other ones (the
## authority turns: Informe §LOCAL58).

const SCREEN_SIZE := Vector2i(128, 96)
const BG := Color(0.05, 0.12, 0.55)
const BG_CORRUPT := Color(0.35, 0.02, 0.02)

var corrupted := false
var _viewport: SubViewport
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
	position = level.center(c) + Vector3.UP * Level.FURNITURE["V"].h
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


func show_rules(p_corrupted: bool) -> void:
	corrupted = p_corrupted
	_bg.color = BG_CORRUPT if corrupted else BG
	if corrupted:
		_title.text = tr("AVISO - CANAL 9")
		_body.text = tr("ACTUALIZACIÓN:\n1. YA NO ES NECESARIO GRABAR.\n2. APAGUE LA CÁMARA.\n3. LA VISITA ES SU AMIGA.\n4. RESPONDA CUANDO LE LLAMEN.\nHOLA VECINITO. HOLA VECINITO.")
	else:
		_title.text = tr("AVISO DE EMERGENCIA")
		_body.text = tr("CANAL 9 INFORMA:\nZONA EVACUADA.\n1. LA VISITA NO SE VE A SIMPLE VISTA.\n2. NO SE MUEVE MIENTRAS ES GRABADA.\n3. SI OYE LA CANCIÓN, NO LE DÉ LA ESPALDA.\n4. NO RESPONDA SI LE LLAMAN VECINITO.")
	_body.position.y = SCREEN_SIZE.y


func _process(delta: float) -> void:
	_t += delta
	# The text crawls up and starts again.
	_body.position.y -= delta * 9.0
	if _body.position.y < -_body.get_line_count() * 10.0:
		_body.position.y = SCREEN_SIZE.y
	var e := 0.75 + 0.12 * sin(_t * 23.0) * sin(_t * 7.0)
	if corrupted and _rng.randf() < delta * 2.0:
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
	_bg = ColorRect.new()
	_bg.size = SCREEN_SIZE
	_bg.color = BG
	_viewport.add_child(_bg)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 8)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body.position = Vector2(4, SCREEN_SIZE.y)
	_body.size = Vector2(SCREEN_SIZE.x - 8, 10)
	_viewport.add_child(_body)
	var band := ColorRect.new()
	band.size = Vector2(SCREEN_SIZE.x, 14)
	band.color = Color(0.85, 0.85, 0.8)
	_viewport.add_child(band)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 8)
	_title.add_theme_color_override("font_color", Color(0.05, 0.05, 0.1))
	_title.position = Vector2(4, 1)
	_viewport.add_child(_title)

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

	_light = OmniLight3D.new()
	_light.light_color = Color(0.45, 0.55, 1.0)
	_light.omni_range = 4.0
	_light.omni_attenuation = 1.6
	_light.light_volumetric_fog_energy = 1.5
	_light.position = Vector3(0, 0.3, -0.55)
	add_child(_light)

	_audio = AudioStreamPlayer3D.new()
	_audio.stream = Sfx.get_stream("tv_tone", true)
	_audio.volume_db = -14.0
	_audio.unit_size = 2.0
	_audio.position.y = 0.3
	add_child(_audio)
	_audio.play()
	show_rules(false)
