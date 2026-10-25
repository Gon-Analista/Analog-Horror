class_name Screens
extends Control
## Full-screen cards: the intro briefing, the capture ("no signal") and
## the escape. Styled as material of the time, not as menus.

signal intro_done

const FONT_SIZE := 13
const NO_SIGNAL := Color(0.04, 0.1, 0.55)

var _bg: ColorRect
var _text: Label
var _waiting_intro := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_text = Label.new()
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = 40
	_text.offset_right = -40
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.add_theme_font_size_override("font_size", FONT_SIZE)
	_text.add_theme_color_override("font_color", Color(0.88, 0.88, 0.84))
	add_child(_text)
	visible = false


func show_intro(player_count: int) -> void:
	var crew := tr("Equipo de %d.") % player_count if player_count > 1 else tr("Vas solo.")
	_show(Color.BLACK, tr("14 DE OCTUBRE DE 1989 — 23:52\nZONA EVACUADA · CALLE OLMOS 14\n\n%s Recuperad %d cintas de «¡Hola, Vecinitos!» y volved a la furgoneta.\nAntes de nada, mirad la televisión del salón.\n\nClic derecho: cámara · F: linterna · E: usar · Shift: correr\n\n(clic para empezar)") % [crew, Tuning.TAPES_NEEDED])
	_waiting_intro = true


func show_caught(tapes: int, needed: int, time: float, is_host: bool) -> void:
	_show(NO_SIGNAL, tr("SIN SEÑAL\n\nCintas recuperadas: %d/%d · %s\n\n%s") % [tapes, needed, _clock(time), _next_line(is_host)])


## The escape: the recovered tape plays on an old TV (the show as it was,
## with the odd wrong frame), the report types itself out, and a line at
## the end does not say what it should. Then the thanks for the demo.
func show_escaped(tapes: int, needed: int, time: float, crew: int, escaper: String, survivors: PackedStringArray, is_host: bool) -> void:
	_bg.color = Color(0.012, 0.012, 0.02)
	_text.text = ""
	modulate.a = 0.0
	visible = true
	create_tween().tween_property(self, "modulate:a", 1.0, 1.2)
	_build_win_tv()
	var music := AudioStreamPlayer.new()
	music.stream = Sfx.get_stream("menu_theme", true)
	music.volume_db = -40.0
	add_child(music)
	music.play()
	create_tween().tween_property(music, "volume_db", -8.0, 3.0)

	var col := VBoxContainer.new()
	col.position = Vector2(252, 40)
	col.custom_minimum_size = Vector2(200, 0)
	col.add_theme_constant_override("separation", 3)
	add_child(col)
	col.add_child(_win_label(tr("CINTA RECUPERADA"), 20, WIN_ACCENT))
	col.add_child(_win_label(tr("14-OCT-89 · «¡HOLA, VECINITOS!»"), 11, WIN_DIM))
	var lines := [tr("Cintas: %d/%d") % [tapes, needed], tr("Tiempo: %s") % _clock(time)]
	if crew > 1:
		lines.append(tr("Salió primero: %s") % escaper)
		var lost := crew - survivors.size()
		lines.append(tr("Volvieron: %s") % ", ".join(survivors) if lost == 0 else tr("No volvieron: %d") % lost)
	var footer := _win_label(tr("GRACIAS POR JUGAR LA DEMO"), 18, WIN_ACCENT)
	footer.position = Vector2(0, 222)
	footer.size = Vector2(480, 22)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.modulate.a = 0.0
	add_child(footer)
	var credits := _win_label(tr("¡Hola, Vecinitos! · prototipo · Canal 9 · 1989      %s") % _next_line(is_host), 10, WIN_DIM)
	credits.position = Vector2(0, 247)
	credits.size = Vector2(480, 14)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.modulate.a = 0.0
	add_child(credits)

	await get_tree().create_timer(1.4).timeout
	col.add_child(_win_label("", 8, WIN_DIM))
	for line: String in lines:
		await _type(col, line, 12, WIN_TEXT)
		await get_tree().create_timer(0.35).timeout
	col.add_child(_win_label("", 8, WIN_DIM))
	var verdict := await _type(col, tr("Las copias serán destruidas."), 12, WIN_TEXT)
	await get_tree().create_timer(1.6).timeout
	# ...it does not stay that way.
	for i in 6:
		verdict.text = tr("Las copias serán %s") % ["destruidas.", "d#str%idas.", "em#t?das.", "destruidas.", "e%itidas.", "emitidas."][i]
		verdict.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if i % 2 == 0 else WIN_TEXT)
		await get_tree().create_timer(0.08).timeout
	verdict.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	await get_tree().create_timer(1.0).timeout
	create_tween().tween_property(footer, "modulate:a", 1.0, 1.5)
	await get_tree().create_timer(0.8).timeout
	create_tween().tween_property(credits, "modulate:a", 1.0, 1.2)


const WIN_TEXT := Color(0.88, 0.88, 0.84)
const WIN_DIM := Color(0.55, 0.55, 0.53)
const WIN_ACCENT := Color(1.0, 0.82, 0.3)
const WIN_TV := Rect2(28, 36, 200, 150)

var _win_atlas: AtlasTexture
var _win_t := 0.0


func _process(delta: float) -> void:
	if _win_atlas == null:
		return
	_win_t += delta
	var frame := int(_win_t * 6.0) % 6
	if fmod(_win_t, 7.0) > 6.9:
		frame = 11  # a frame that should not be on the tape
	_win_atlas.region.position.x = frame * 320


func _build_win_tv() -> void:
	var cabinet := Panel.new()
	var wood := StyleBoxFlat.new()
	wood.bg_color = Color(0.16, 0.1, 0.06)
	wood.set_corner_radius_all(6)
	cabinet.add_theme_stylebox_override("panel", wood)
	cabinet.position = WIN_TV.position - Vector2(12, 10)
	cabinet.size = WIN_TV.size + Vector2(24, 34)
	add_child(cabinet)
	var bezel := Panel.new()
	var plastic := StyleBoxFlat.new()
	plastic.bg_color = Color(0.05, 0.05, 0.05)
	plastic.set_corner_radius_all(12)
	bezel.add_theme_stylebox_override("panel", plastic)
	bezel.position = WIN_TV.position - Vector2(5, 5)
	bezel.size = WIN_TV.size + Vector2(10, 10)
	add_child(bezel)
	var screen := TextureRect.new()
	_win_atlas = AtlasTexture.new()
	_win_atlas.atlas = load("res://assets/textures/tv_show.png")
	_win_atlas.region = Rect2(0, 0, 320, 240)
	screen.texture = _win_atlas
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.position = WIN_TV.position
	screen.size = WIN_TV.size
	add_child(screen)
	var tape := ColorRect.new()
	tape.position = WIN_TV.position
	tape.size = WIN_TV.size
	var disturb := ShaderMaterial.new()
	disturb.shader = load("res://shaders/tv_disturb.gdshader")
	disturb.set_shader_parameter("disturb", 0.12)
	tape.material = disturb
	add_child(tape)
	var glass := ColorRect.new()
	glass.position = WIN_TV.position
	glass.size = WIN_TV.size
	var crt := ShaderMaterial.new()
	crt.shader = load("res://shaders/crt_glass.gdshader")
	glass.material = crt
	add_child(glass)
	var osd := _win_label("PLAY >", 12, Color(0.85, 0.95, 0.85))
	osd.position = WIN_TV.position + Vector2(8, 4)
	add_child(osd)


func _win_label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l


## A line that types itself out, like a teletext page.
func _type(parent: Control, text: String, size_px: int, color: Color) -> Label:
	var l := _win_label("", size_px, color)
	parent.add_child(l)
	for i in text.length():
		l.text = text.left(i + 1)
		if i % 2 == 0:
			Sfx.play(self, "click", -22.0, 1.6)
		await get_tree().create_timer(0.03).timeout
	return l


func _next_line(is_host: bool) -> String:
	return tr("R: otra noche · M: menú") if is_host else tr("Esperando al anfitrión · M: menú")


func _show(color: Color, text: String) -> void:
	_bg.color = color
	_text.text = text
	modulate.a = 1.0
	visible = true


func _clock(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _input(event: InputEvent) -> void:
	if not _waiting_intro:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo):
		_waiting_intro = false
		get_viewport().set_input_as_handled()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.8)
		tw.tween_callback(func() -> void:
			visible = false
			intro_done.emit())
