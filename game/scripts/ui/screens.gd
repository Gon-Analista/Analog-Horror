class_name Screens
extends Control
## Full-screen cards: the intro briefing, the capture ("no signal") and
## the escape. Styled as material of the time, not as menus: a VCR's
## on-screen display in the corner, the heading, a report that types
## itself out after a beat of silence, and the options last.

signal intro_done

const FONT_SIZE := 13
const TITLE_SIZE := 26
const NO_SIGNAL := Color(0.04, 0.1, 0.55)
const TEXT := Color(0.88, 0.88, 0.84)
const DIM := Color(0.62, 0.62, 0.6)
## Characters per second of the typed report.
const TYPE_SPEED := 55.0
## Silence after the heading before the report starts.
const PAUSE_BEFORE_REPORT := 1.1
const PAUSE_BEFORE_OPTIONS := 0.9

var _bg: ColorRect
var _osd: Label
var _title: Label
var _body: Label
var _footer: Label
var _waiting_intro := false
var _tween: Tween
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_osd = _make_label(FONT_SIZE, TEXT)
	_osd.position = Vector2(18, 12)
	_osd.size = Vector2(200, 16)
	_title = _make_label(TITLE_SIZE, TEXT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body = _make_label(FONT_SIZE, TEXT)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_footer = _make_label(11, DIM)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visible = false


func _make_label(size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 3)
	add_child(l)
	return l


func show_intro(player_count: int) -> void:
	var crew := tr("Equipo de %d.") % player_count if player_count > 1 else tr("Vas solo.")
	_show(Color.BLACK, "",
		tr("14 DE OCTUBRE DE 1989 — 23:52"),
		tr("ZONA EVACUADA · CALLE OLMOS 14\n\n%s Recuperad %d cintas de «¡Hola, Vecinitos!» y volved a la furgoneta.\nAntes de nada, mirad la televisión del salón.\n\nClic derecho: cámara · F: linterna · E: usar · Shift: correr · Esc: menú") % [crew, Tuning.TAPES_NEEDED],
		tr("clic para empezar"), 0.3)
	_waiting_intro = true


func show_caught(tapes: int, needed: int, time: float, is_host: bool) -> void:
	_show(NO_SIGNAL, "CH 09",
		tr("SIN SEÑAL"),
		tr("Cintas recuperadas: %d/%d\nTiempo en la casa: %s") % [tapes, needed, _clock(time)],
		_next_line(is_host), PAUSE_BEFORE_REPORT)


func show_escaped(tapes: int, needed: int, time: float, crew: int, survivors: PackedStringArray, is_host: bool) -> void:
	var report := tr("Cintas: %d/%d\nTiempo en la casa: %s") % [tapes, needed, _clock(time)]
	if crew > 1:
		report += "\n\n" + tr("Volvieron: %s") % (", ".join(survivors) if not survivors.is_empty() else "—")
	_show(Color.BLACK, "PLAY",
		tr("CINTA 14-OCT-89 RECUPERADA"),
		report, _next_line(is_host), PAUSE_BEFORE_REPORT)


func _next_line(is_host: bool) -> String:
	return tr("R: otra noche · M: menú") if is_host else tr("Esperando al anfitrión · M: menú")


func _show(color: Color, osd: String, title: String, body: String, footer: String, pause: float) -> void:
	if _tween:
		_tween.kill()
	_bg.color = color
	_osd.text = osd
	_title.text = title
	_body.text = body
	_footer.text = footer
	_layout()
	modulate.a = 1.0
	visible = true
	_body.visible_ratio = 0.0
	_footer.modulate.a = 0.0
	# Heading at once (with a flicker), silence, the report types itself
	# out, then the options.
	_tween = create_tween()
	_title.modulate.a = 0.0
	for a in [1.0, 0.2, 1.0]:
		_tween.tween_property(_title, "modulate:a", a, 0.06)
	_tween.tween_interval(pause)
	_tween.tween_property(_body, "visible_ratio", 1.0, maxf(body.length() / TYPE_SPEED, 0.2))
	_tween.tween_interval(PAUSE_BEFORE_OPTIONS if pause > 0.5 else 0.2)
	_tween.tween_property(_footer, "modulate:a", 1.0, 0.5)


func _layout() -> void:
	var w := size.x
	var body_lines := _body.text.count("\n") + 1
	var block := TITLE_SIZE + 14 + body_lines * 14
	var top := (size.y - block) * 0.5 - 8
	_title.position = Vector2(20, top)
	_title.size = Vector2(w - 40, TITLE_SIZE + 4)
	_body.position = Vector2(40, top + TITLE_SIZE + 14)
	_body.size = Vector2(w - 80, body_lines * 14)
	_footer.position = Vector2(20, size.y - 30)
	_footer.size = Vector2(w - 40, 14)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# The OSD blinks like a VCR's; the intro's prompt pulses once it shows.
	_osd.visible = fmod(_t, 1.2) < 0.8
	if _waiting_intro and _footer.modulate.a > 0.99:
		_footer.self_modulate.a = 0.55 + 0.45 * sin(_t * 3.0)


func _clock(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _input(event: InputEvent) -> void:
	if not _waiting_intro:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo):
		_waiting_intro = false
		get_viewport().set_input_as_handled()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if _tween:
			_tween.kill()
		_footer.self_modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.8)
		tw.tween_callback(func() -> void:
			visible = false
			intro_done.emit())
