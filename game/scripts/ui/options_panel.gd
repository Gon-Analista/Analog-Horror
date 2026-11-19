class_name OptionsPanel
extends PanelContainer
## Settings screen shared by the title menu and the pause menu: look,
## audio and picture (dev_guidelines §7). Changes apply live and are
## saved when it closes. Sized to fit the 480x270 base screen.

signal closed

const LABEL_W := 112.0
const VALUE_W := 34.0

var _rows := {}
var _first: Control


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_style(10))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(UiKit.label(tr("AJUSTES"), 16, UiKit.ACCENT))
	col.add_child(UiKit.rule(262))
	_section(col, tr("CONTROL"))
	_first = _slider_row(col, "mouse_sens", tr("Sensibilidad"), func(v: float) -> String: return "%.2fx" % v)
	_toggle_row(col, "invert_y", tr("Invertir eje Y"))
	_slider_row(col, "fov", tr("Campo de visión"), func(v: float) -> String: return "%d°" % int(v))
	_section(col, tr("SONIDO"))
	_slider_row(col, "vol_master", tr("Volumen general"), _percent)
	_slider_row(col, "vol_music", tr("Música"), _percent)
	_slider_row(col, "vol_sfx", tr("Efectos"), _percent)
	_section(col, tr("IMAGEN"))
	_slider_row(col, "brightness", tr("Brillo"), func(v: float) -> String: return "%.2f" % v)
	_slider_row(col, "vhs_fx", tr("Efectos VHS"), _percent)
	_toggle_row(col, "fullscreen", tr("Pantalla completa"))
	col.add_child(UiKit.spacer(4))
	col.add_child(UiKit.rule(262))
	col.add_child(UiKit.spacer(2))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	buttons.add_child(UiKit.button(tr("VOLVER"), close))
	buttons.add_child(UiKit.button(tr("RESTABLECER"), func() -> void:
		Settings.reset()
		_refresh()))
	Settings.changed.connect(_refresh)
	visible = false


func open() -> void:
	_refresh()
	visible = true
	if _first:
		_first.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	Settings.save()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _section(col: VBoxContainer, title: String) -> void:
	col.add_child(UiKit.spacer(3))
	col.add_child(UiKit.label(title, UiKit.FONT_SMALL, UiKit.DIM))


func _name_label(row: HBoxContainer, title: String, control: Control) -> void:
	var name_l := UiKit.label(title)
	name_l.custom_minimum_size = Vector2(LABEL_W, 0)
	row.add_child(name_l)
	control.focus_entered.connect(func() -> void: name_l.add_theme_color_override("font_color", UiKit.ACCENT))
	control.focus_exited.connect(func() -> void: name_l.add_theme_color_override("font_color", UiKit.TEXT))


func _slider_row(col: VBoxContainer, key: String, title: String, fmt: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var r: Array = Settings.RANGES[key]
	var s := UiKit.slider(r[0], r[1], r[2], float(Settings.get_value(key)))
	_name_label(row, title, s)
	row.add_child(s)
	var value_l := UiKit.label("", UiKit.FONT, UiKit.DIM)
	value_l.custom_minimum_size = Vector2(VALUE_W, 0)
	value_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_l)
	s.value_changed.connect(func(v: float) -> void:
		value_l.text = fmt.call(v)
		Settings.set_value(key, v))
	s.mouse_entered.connect(s.grab_focus)
	value_l.text = fmt.call(s.value)
	_rows[key] = s
	col.add_child(row)
	return s


func _toggle_row(col: VBoxContainer, key: String, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var b := UiKit.button("", func() -> void: Settings.set_value(key, not bool(Settings.get_value(key))))
	_name_label(row, title, b)
	row.add_child(b)
	_rows[key] = b
	col.add_child(row)
	_update_toggle(key)


func _update_toggle(key: String) -> void:
	var b: Button = _rows[key]
	UiKit.set_button_text(b, "[%s]" % (tr("SÍ") if bool(Settings.get_value(key)) else tr("NO")))


func _refresh() -> void:
	for key: String in _rows:
		var c: Control = _rows[key]
		if c is HSlider:
			(c as HSlider).set_value_no_signal(float(Settings.get_value(key)))
			(c as HSlider).value_changed.emit((c as HSlider).value)
		else:
			_update_toggle(key)


func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)
