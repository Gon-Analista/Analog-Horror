class_name PauseMenu
extends Control
## Esc during the night: resume, settings, back to the title, quit. Solo
## pauses the world; online it keeps going (dev_guidelines §6) and the
## player only stops acting.

var _player: Player
var _box: VBoxContainer
var _panel: PanelContainer
var _options: OptionsPanel
var _note: Label
var _resume: Button


func setup(player: Player) -> void:
	_player = player
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	center.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	_panel.add_child(row)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 2)
	_box.custom_minimum_size = Vector2(150, 0)
	row.add_child(_box)
	_box.add_child(UiKit.label(tr("PAUSA") if _is_solo() else tr("MENÚ"), 16, UiKit.ACCENT))
	_box.add_child(UiKit.rule(140))
	_box.add_child(UiKit.spacer(4))
	_resume = UiKit.button(tr("SEGUIR"), close)
	_box.add_child(_resume)
	_box.add_child(UiKit.button(tr("AJUSTES"), _open_options))
	_box.add_child(UiKit.button(tr("VOLVER AL MENÚ"), func() -> void: Net.end_session()))
	_box.add_child(UiKit.button(tr("SALIR DEL JUEGO"), func() -> void:
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)))
	_box.add_child(UiKit.spacer(4))
	_note = UiKit.label(tr("La noche sigue: en grupo\nel mundo no se detiene.") if not _is_solo() else "", UiKit.FONT_SMALL, UiKit.ALERT)
	_box.add_child(_note)

	var help := VBoxContainer.new()
	help.add_theme_constant_override("separation", 0)
	row.add_child(help)
	help.add_child(UiKit.label(tr("CONTROLES"), UiKit.FONT_SMALL, UiKit.DIM))
	help.add_child(UiKit.spacer(3))
	for pair: Array in [
			[tr("Clic derecho"), tr("Grabar")],
			[tr("F"), tr("Linterna")],
			[tr("E"), tr("Usar")],
			[tr("Shift"), tr("Correr")],
			[tr("C"), tr("Agacharse")],
			[tr("F11"), tr("Pantalla completa")],
			[tr("Esc"), tr("Este menú")]]:
		var line := HBoxContainer.new()
		var k := UiKit.label(pair[0], UiKit.FONT, UiKit.TEXT)
		k.custom_minimum_size = Vector2(70, 0)
		line.add_child(k)
		line.add_child(UiKit.label(pair[1], UiKit.FONT, UiKit.DIM))
		help.add_child(line)

	_options = OptionsPanel.new()
	center.add_child(_options)
	_options.closed.connect(func() -> void:
		_panel.visible = true
		_resume.grab_focus())
	visible = false


func open() -> void:
	if visible or Transition.busy:
		return
	visible = true
	_panel.visible = true
	_player.menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _is_solo():
		get_tree().paused = true
	_resume.grab_focus()


func close() -> void:
	if not visible:
		return
	_options.close()
	visible = false
	_player.menu_open = false
	get_tree().paused = false
	if _player.alive and _player.input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if not visible:
		open()
	elif not _options.visible:
		close()


func _open_options() -> void:
	_panel.visible = false
	_options.open()


func _is_solo() -> bool:
	return Net.mode == Net.Mode.SOLO and Net.players.size() <= 1
