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
var _credits: Label
var _caught_text := ""
var _win_tv_nodes: Array[CanvasItem] = []
var _thanks: Label
## The second night (Canal 9, The Husk): its own briefing and tape label.
var station := false
## The end of the first night offers the second (host: N).
var offer_station := false


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


func show_intro(player_count: int, tapes: int, entity_name := "") -> void:
	var crew := tr("EQUIPO DE %d") % player_count if player_count > 1 else tr("VAS SOLO")
	if entity_name != "":
		crew += " · " + tr("LA VISITA ES %s") % entity_name.to_upper()
	if station:
		# The second night: the master tapes, the costume, the loading dock.
		_show(Color.BLACK, tr("15-OCT-1989 · 03:10 · CANAL 9 · ESTUDIOS · %s\n\n1. ENCUENTRA %d MÁSTERES DEL PROGRAMA\n2. SAL POR EL MUELLE DE CARGA\n\nEl disfraz no se mueve si lo miras. La cámara no lo ve: tus ojos sí.\n\nCLIC DCHO: cámara · CLIC IZQ: flash · E: usar / esconderse · TAB: inventario\n\n(clic para empezar)") % [crew, tapes])
		_text.add_theme_font_size_override("font_size", FONT_SIZE - 3)
		_waiting_intro = true
		return
	# Three steps and the one rule; the rest is learned by playing (the TV
	# shows what the flash does).
	_show(Color.BLACK, tr("14-OCT-1989 · 23:52 · CALLE OLMOS 14 · %s\n\n1. INVESTIGA LA EXTRAÑA MÚSICA\n2. ENCUENTRA %d CINTAS\n3. VUELVE A LA FURGONETA\n\nAlgo vive en esta casa. Solo la cámara lo ve.\n\nCLIC DCHO: cámara · CLIC IZQ: flash · E: usar / esconderse · TAB: inventario\n\n(clic para empezar)") % [crew, tapes])
	_text.add_theme_font_size_override("font_size", FONT_SIZE - 3)  # (all of it on one screen)
	_waiting_intro = true


func show_caught(tapes: int, needed: int, time: float, is_host: bool) -> void:
	_show(NO_SIGNAL, tr("SIN SEÑAL\n\nCintas recuperadas: %d/%d · %s\n\n%s") % [tapes, needed, _clock(time), _next_line(is_host)])
	_caught_text = tr("SIN SEÑAL\n\nCintas recuperadas: %d/%d · %s") % [tapes, needed, _clock(time)]


## The best moments' list takes the bottom of the screen (it says R / M
## itself): the rest moves out of its way.
## The best moments' TV takes its place: the recovered tape's own TV when
## they got out (its show gives way), the middle of the screen when they
## did not (the text goes up). Returns where the TV goes.
func make_room() -> Rect2:
	if _credits:
		_credits.visible = false
	if not _win_tv_nodes.is_empty():
		for n in _win_tv_nodes:
			n.visible = false
		if _thanks:
			_thanks.position.y = 4  # (out of the way of whose clip it is)
		return WIN_TV
	if _caught_text != "":
		_text.text = _caught_text.replace("\n\n", "   ·   ")  # (one line: the TV goes under it)
		_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_text.offset_top = 4
	return Rect2(150, 58, 180, 130)



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
	music.bus = "Music"
	add_child(music)
	music.play()
	create_tween().tween_property(music, "volume_db", -8.0, 3.0)

	var col := VBoxContainer.new()
	col.position = Vector2(252, 40)
	col.custom_minimum_size = Vector2(200, 0)
	col.add_theme_constant_override("separation", 3)
	add_child(col)
	col.add_child(_win_label(tr("CINTA RECUPERADA"), 20, WIN_ACCENT))
	col.add_child(_win_label(tr("15-OCT-89 · CANAL 9 · MÁSTERES") if station else tr("14-OCT-89 · «¡TE ESTOY VIENDO!»"), 11, WIN_DIM))
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
	_thanks = footer
	var credits := _win_label(("Lost Signal - Analog Horror · demo · " + tr("Canal 9") + " · 1989      %s") % _next_line(is_host), 10, WIN_DIM)
	credits.position = Vector2(0, 247)
	credits.size = Vector2(480, 14)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.modulate.a = 0.0
	add_child(credits)
	_credits = credits

	await get_tree().create_timer(1.4).timeout
	col.add_child(_win_label("", 8, WIN_DIM))
	for line: String in lines:
		await _type(col, line, 12, WIN_TEXT)
		await get_tree().create_timer(0.35).timeout
	col.add_child(_win_label("", 8, WIN_DIM))
	var verdict := await _type(col, tr("Las copias serán destruidas."), 12, WIN_TEXT)
	await get_tree().create_timer(1.6).timeout
	# ...it does not stay that way.
	var gone := tr("destruidas.")
	var aired := tr("emitidas.")
	var steps := [gone, _corrupt(gone), _corrupt(aired), gone, _corrupt(aired), aired]
	for i in 6:
		verdict.text = tr("Las copias serán %s") % steps[i]
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
	var frame: int = TvShow.at(_win_t)[0]
	if fmod(_win_t, 7.0) > 6.9:
		frame = TvShow.STARE_DARK  # a frame that should not be on the tape
	_win_atlas.region = TvShow.region(frame)


func _build_win_tv() -> void:
	var cabinet := Panel.new()
	var wood := StyleBoxFlat.new()
	wood.bg_color = Color(0.16, 0.1, 0.06)
	wood.set_corner_radius_all(6)
	cabinet.add_theme_stylebox_override("panel", wood)
	cabinet.position = WIN_TV.position - Vector2(12, 10)
	cabinet.size = WIN_TV.size + Vector2(24, 34)
	add_child(cabinet)
	_win_tv_nodes.append(cabinet)
	var bezel := Panel.new()
	var plastic := StyleBoxFlat.new()
	plastic.bg_color = Color(0.05, 0.05, 0.05)
	plastic.set_corner_radius_all(12)
	bezel.add_theme_stylebox_override("panel", plastic)
	bezel.position = WIN_TV.position - Vector2(5, 5)
	bezel.size = WIN_TV.size + Vector2(10, 10)
	add_child(bezel)
	_win_tv_nodes.append(bezel)
	var screen := TextureRect.new()
	_win_atlas = AtlasTexture.new()
	_win_atlas.atlas = load(TvShow.SHEET)
	_win_atlas.region = Rect2(0, 0, 320, 240)
	screen.texture = _win_atlas
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.position = WIN_TV.position
	screen.size = WIN_TV.size
	add_child(screen)
	_win_tv_nodes.append(screen)
	var tape := ColorRect.new()
	tape.position = WIN_TV.position
	tape.size = WIN_TV.size
	var disturb := ShaderMaterial.new()
	disturb.shader = load("res://shaders/tv_disturb.gdshader")
	disturb.set_shader_parameter("disturb", 0.12)
	tape.material = disturb
	add_child(tape)
	_win_tv_nodes.append(tape)
	var glass := ColorRect.new()
	glass.position = WIN_TV.position
	glass.size = WIN_TV.size
	var crt := ShaderMaterial.new()
	crt.shader = load("res://shaders/crt_glass.gdshader")
	glass.material = crt
	add_child(glass)
	_win_tv_nodes.append(glass)
	var osd := _win_label("PLAY >", 12, Color(0.85, 0.95, 0.85))
	osd.position = WIN_TV.position + Vector2(8, 4)
	add_child(osd)
	_win_tv_nodes.append(osd)


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


## A word with a couple of letters eaten by the tape.
static func _corrupt(word: String) -> String:
	var chars := word.split("")
	for k in 2:
		chars[(k * 3 + 1) % maxi(1, chars.size() - 1)] = ["#", "%", "?"][k % 3]
	return "".join(chars)


func _next_line(is_host: bool) -> String:
	if is_host and offer_station:
		return tr("R: otra noche · N: la emisora · M: menú")
	return tr("R: otra noche · M: menú") if is_host else tr("Esperando al anfitrión · M: menú")


func _show(color: Color, text: String) -> void:
	_text.add_theme_font_size_override("font_size", FONT_SIZE)
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


## "La Visita es un jugador": the briefing of the one who plays it.
func show_pilot_intro(crew: int, tapes: int) -> void:
	_show(Color(0.08, 0.0, 0.0), tr("ERES LA VISITA\n\nHay %d en tu casa. Buscan %d cintas para llevárselas.\n\nCógelos a todos antes de que escapen. Solo te ven por la cámara; su flash te ciega.\n\nWASD andar · SHIFT correr · C agacharse · ESPACIO techo\nCLIC IZQ embestir gritando · Q sentirlos · E puerta / esconderte / mirar\n\n(clic para empezar)") % [crew, tapes])
	_text.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	_waiting_intro = true


## The end, for the one who played the entity.
func show_entity_end(won: bool, tapes: int, needed: int, time: float, is_host: bool) -> void:
	var head := tr("LA CASA ES TUYA") if won else tr("SE HAN ESCAPADO")
	_caught_text = head + "\n\n" + tr("Cintas que se llevaron: %d/%d · %s") % [tapes, needed, _clock(time)]
	_show(Color(0.1, 0.0, 0.0) if won else Color(0.02, 0.02, 0.04), _caught_text + "\n\n" + _next_line(is_host))


## A line at the top of the end screen (who was the entity).
func note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, 186)
	l.size = Vector2(480, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
