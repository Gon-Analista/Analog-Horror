class_name PauseMenu
extends Control
## Esc: the pause menu (continue, options, back to the main menu, quit).
## Alone, or as the host, it pauses the night for everyone, and the others
## see that the host has paused. A guest's menu does not stop the game.

const BG := Color(0.0, 0.0, 0.0, 0.72)
const TEXT := Color(0.88, 0.88, 0.84)
const ACCENT := Color(1.0, 0.82, 0.3)
const DIM := Color(0.55, 0.55, 0.53)

var run: Run
var _panel: VBoxContainer
var _options: VBoxContainer
var _notice: Label
var _open := false


func setup(p_run: Run) -> void:
	run = p_run
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	run.paused_changed.connect(_on_paused)

	_panel = VBoxContainer.new()
	_panel.position = Vector2(180, 70)
	_panel.add_theme_constant_override("separation", 3)
	_panel.visible = false
	add_child(_panel)
	_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := _label(tr("PAUSA"), 20, ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(title)
	_panel.add_child(_button(tr("CONTINUAR"), close))
	_panel.add_child(_button(tr("OPCIONES"), func() -> void:
		_options.visible = not _options.visible
		_centre()))
	_panel.add_child(_button(tr("MENÚ PRINCIPAL"), func() -> void:
		get_tree().paused = false
		Net.end_session()))
	_panel.add_child(_button(tr("SALIR DEL JUEGO"), func() -> void: get_tree().quit()))

	_options = VBoxContainer.new()
	_options.position = Vector2(180, 168)
	_options.visible = false
	add_child(_options)
	var screen := _button(_screen_label(), func() -> void: pass)
	screen.pressed.connect(func() -> void:
		Settings.set_fullscreen(not Settings.fullscreen)
		screen.text = "  " + _screen_label())
	_options.add_child(screen)
	for pair: Array in [["master", tr("GENERAL")], ["music", tr("MÚSICA")], ["effects", tr("EFECTOS")], ["voice", tr("CHAT DE VOZ")]]:
		var row := HBoxContainer.new()
		var l := _label("  " + pair[1], 12, TEXT)
		l.custom_minimum_size = Vector2(82, 0)
		row.add_child(l)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Settings.volume[pair[0]]
		slider.custom_minimum_size = Vector2(110, 12)
		slider.focus_mode = Control.FOCUS_NONE
		var key: String = pair[0]
		slider.value_changed.connect(func(v: float) -> void: Settings.set_volume(key, v))
		row.add_child(slider)
		_options.add_child(row)
	var device := _button(_device_label(), func() -> void: pass)
	device.pressed.connect(func() -> void:
		var list := Settings.mic_devices()
		var i := list.find(Settings.mic_device)
		Settings.set_mic_device(list[(i + 1) % list.size()])
		device.text = "  " + _device_label())
	_options.add_child(device)

	_notice = _label(tr("EL ANFITRIÓN HA PAUSADO LA PARTIDA"), 16, ACCENT)
	_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice.position = Vector2(110, 120)
	_notice.visible = false
	add_child(_notice)
	visible = true


func open() -> void:
	_open = true
	_panel.visible = true
	_centre()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if multiplayer.is_server():
		run.request_pause(true)
	queue_redraw()


func close() -> void:
	_open = false
	_panel.visible = false
	_options.visible = false
	if run.phase == Run.Phase.PLAYING and not run.reading:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if multiplayer.is_server():
		run.request_pause(false)
	queue_redraw()


## The menu (and the options under it) in the middle of the screen.
func _centre() -> void:
	var screen := get_viewport_rect().size
	_panel.reset_size()
	_options.reset_size()
	var total := _panel.size.y + (_options.size.y + 6.0 if _options.visible else 0.0)
	var top := (screen.y - total) * 0.5
	_panel.position = Vector2((screen.x - _panel.size.x) * 0.5, top)
	_options.position = Vector2((screen.x - _options.size.x) * 0.5, top + _panel.size.y + 6.0)
	_notice.reset_size()
	_notice.position = Vector2((screen.x - _notice.size.x) * 0.5, screen.y * 0.4)


func _on_paused(on: bool) -> void:
	# Guests: the host paused (or carried on).
	_notice.visible = on and not multiplayer.is_server()
	_centre()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if _open or _notice.visible:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BG)


func _screen_label() -> String:
	return tr("PANTALLA: COMPLETA (F11)") if Settings.fullscreen else tr("PANTALLA: VENTANA (F11)")


func _label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _device_label() -> String:
	var device := Settings.mic_device
	var shown := tr("EL DEL SISTEMA") if device == "Default" else device.to_upper()
	if shown.length() > 26:
		shown = shown.left(25) + "…"
	return tr("MICRÓFONO: %s") % shown


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.pressed.connect(func() -> void:
		Sfx.play(self, "click", -4.0)
		action.call())
	return b
