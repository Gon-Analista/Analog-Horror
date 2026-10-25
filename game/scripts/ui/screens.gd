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


func show_escaped(tapes: int, needed: int, time: float, crew: int, survivors: PackedStringArray, is_host: bool) -> void:
	var who := ""
	if crew > 1:
		who = tr("Volvieron: %s") % (", ".join(survivors) if not survivors.is_empty() else "—") + "\n\n"
	_show(Color.BLACK, tr("CINTA 14-OCT-89 RECUPERADA\n\nCintas: %d/%d · %s\n\n%s%s") % [tapes, needed, _clock(time), who, _next_line(is_host)])


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
