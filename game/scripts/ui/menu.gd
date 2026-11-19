extends Control
## Title and lobby. A dark room lit only by an old TV playing the show on a
## worn tape that now and then goes wrong for a moment; the sign-off music
## plays. Solo, create a room (online code), join with a
## code (or a LAN address, for development), see who is in, start.
## Dev flags (after "--"): --smoke / --shots go straight to the house;
## --net-test host|client runs the two-window online check on LAN;
## --menu-shot <file.png> saves a screenshot of this screen and quits;
## --menu-shots <dir> saves the title screens (ident, warning, settings...).

const SHOW_SHEET := "res://assets/textures/tv_show.png"
const FRAME := Vector2i(320, 240)
## The TV in the room (base 480x270 coordinates).
const TV_RECT := Rect2(236, 38, 224, 168)
const TEXT := UiKit.TEXT
const DIM := UiKit.DIM
const ACCENT := UiKit.ACCENT
const FONT_TITLE := UiKit.FONT_TITLE
const FONT := UiKit.FONT
## The title card (channel ident and warnings) plays once per launch.
static var _boot_shown := false

var _atlas: AtlasTexture
var _music: AudioStreamPlayer
var _glow: TextureRect
var _disturb: ShaderMaterial
var _glitch := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _main_box: VBoxContainer
var _join_box: HBoxContainer
var _lobby_box: VBoxContainer
var _name_edit: LineEdit
var _code_edit: LineEdit
var _status: Label
var _room: Label
var _list: VBoxContainer
var _start: Button
var _col: VBoxContainer
var _overlay: Control
var _options: OptionsPanel
var _credits: PanelContainer
var _first_button: Button


func _ready() -> void:
	Controls.setup()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var args := OS.get_cmdline_user_args()
	if args.has("--smoke") or args.has("--shots"):
		Net.ensure_solo_players()
		get_tree().change_scene_to_file.call_deferred(Net.GAME_SCENE)
		return
	_build()
	Net.players_changed.connect(_refresh_lobby)
	Net.session_failed.connect(func(reason: String) -> void:
		_status.text = reason
		_show_main())
	if Net.last_message != "":
		_status.text = Net.last_message
	var tour := args.find("--menu-shots")
	if tour >= 0 and tour + 1 < args.size():
		_boot_shown = true
		var mt := MenuTour.new()
		add_child(mt)
		mt.run_tour(self, args[tour + 1])
		return
	var dev := args.has("--menu-shot") or args.has("--net-test")
	if not _boot_shown and not dev:
		_boot_shown = true
		var card := BootCard.new()
		add_child(card)
		await card.done
	if not dev:
		_first_button.grab_focus()
	var shot := args.find("--menu-shot")
	if shot >= 0 and shot + 1 < args.size():
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[shot + 1])
		get_tree().quit()
	var t := args.find("--net-test")
	if t >= 0 and t + 1 < args.size():
		_net_test(args[t + 1])


func _process(delta: float) -> void:
	_t += delta
	# The show on a worn tape: every so often it goes wrong for a moment.
	var frame := int(_t * 6.0) % 6
	if _glitch > 0.0:
		_glitch -= delta
		frame = 8 if _glitch > 0.12 else 6 + _rng.randi() % 2
	elif _rng.randf() < delta * 0.12:
		_glitch = 0.35
	_atlas.region.position.x = frame * FRAME.x
	_disturb.set_shader_parameter("disturb", 0.75 if _glitch > 0.0 else 0.1 + 0.04 * sin(_t * 0.7))
	_glow.modulate.a = (0.55 if _glitch > 0.0 else 0.85) + 0.08 * sin(_t * 9.0) * sin(_t * 2.3)


# --- actions ---------------------------------------------------------------------

func _solo() -> void:
	Net.my_name = _player_name()
	_set_busy(true)
	await Transition.cover()
	Net.start_solo()


func _start_night() -> void:
	_start.disabled = true
	await Transition.cover()
	Net.start_game(randi())


func _host() -> void:
	Net.my_name = _player_name()
	_status.text = tr("Creando sala…")
	_set_busy(true)
	var ok: bool = await Net.host_online()
	_set_busy(false)
	if ok:
		_show_lobby()


func _join() -> void:
	var code := _code_edit.text.strip_edges()
	if code == "":
		_status.text = tr("Escribe el código de la sala")
		return
	Net.my_name = _player_name()
	_status.text = tr("Buscando la sala…")
	_set_busy(true)
	var ok: bool
	if code.count(".") == 3:  # an address: LAN game (development)
		ok = Net.join_lan(code)
	else:
		ok = await Net.join_online(code)
	_set_busy(false)
	if ok:
		_status.text = tr("Conectando…")
		_show_lobby()


func _host_lan() -> void:
	Net.my_name = _player_name()
	if Net.host_lan():
		_show_lobby()


func _leave() -> void:
	Net.end_session()


func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else "Operador"


func _net_test(role: String) -> void:
	Net.test_role = role
	_name_edit.text = "Anfitrión" if role == "host" else "Invitado"
	if role == "host":
		_host_lan()
		while Net.players.size() < 2:
			await Net.players_changed
		await get_tree().create_timer(0.5).timeout
		Net.start_game(7)
	else:
		_code_edit.text = "127.0.0.1"
		await get_tree().create_timer(0.8).timeout
		_join()


# --- lobby ---------------------------------------------------------------------

func _show_main() -> void:
	_main_box.visible = true
	_lobby_box.visible = false
	_first_button.grab_focus()


func _show_lobby() -> void:
	_main_box.visible = false
	_lobby_box.visible = true
	_refresh_lobby()
	if _start.visible:
		_start.grab_focus()


func _refresh_lobby() -> void:
	if not _lobby_box.visible:
		return
	match Net.mode:
		Net.Mode.LAN:
			_room.text = tr("SALA LAN · %s") % Net.code
		_:
			_room.text = tr("CÓDIGO DE SALA: %s") % Net.code
	for child in _list.get_children():
		child.queue_free()
	var ids := Net.players.keys()
	ids.sort()
	for id: int in ids:
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = Net.color_of(id)
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var label := _label(" %s%s" % [Net.name_of(id), tr("  (anfitrión)") if id == 1 else ""], FONT, TEXT)
		row.add_child(label)
		_list.add_child(row)
	for i in range(ids.size(), Net.MAX_PLAYERS):
		_list.add_child(_label(tr("  · libre"), FONT, DIM))
	_start.visible = Net.is_host()
	_start.disabled = false
	_status.text = "" if Net.is_host() else tr("Esperando a que el anfitrión empiece…")


# --- building the screen -----------------------------------------------------------

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var room := ColorRect.new()
	room.set_anchors_preset(Control.PRESET_FULL_RECT)
	room.color = Color(0.015, 0.015, 0.025)
	add_child(room)
	# The TV's light spilling into the dark room.
	_glow = TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(0.35, 0.5, 0.75, 0.32))
	g.set_color(1, Color(0.35, 0.5, 0.75, 0.0))
	grad.gradient = g
	grad.width = 128
	grad.height = 128
	_glow.texture = grad
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.position = TV_RECT.get_center() - Vector2(260, 200)
	_glow.size = Vector2(520, 400)
	add_child(_glow)
	# The set: a wooden cabinet, the bezel, the screen.
	var cabinet := Panel.new()
	var wood := StyleBoxFlat.new()
	wood.bg_color = Color(0.16, 0.1, 0.06)
	wood.border_color = Color(0.08, 0.05, 0.03)
	wood.set_border_width_all(2)
	wood.set_corner_radius_all(6)
	cabinet.add_theme_stylebox_override("panel", wood)
	cabinet.position = TV_RECT.position - Vector2(14, 12)
	cabinet.size = TV_RECT.size + Vector2(28, 44)
	add_child(cabinet)
	var bezel := Panel.new()
	var plastic := StyleBoxFlat.new()
	plastic.bg_color = Color(0.05, 0.05, 0.05)
	plastic.set_corner_radius_all(14)
	bezel.add_theme_stylebox_override("panel", plastic)
	bezel.position = TV_RECT.position - Vector2(6, 6)
	bezel.size = TV_RECT.size + Vector2(12, 12)
	add_child(bezel)
	for k in 2:  # knobs
		var knob := Panel.new()
		var round := StyleBoxFlat.new()
		round.bg_color = Color(0.25, 0.22, 0.2)
		round.set_corner_radius_all(6)
		knob.add_theme_stylebox_override("panel", round)
		knob.position = Vector2(TV_RECT.end.x - 40 + k * 18, TV_RECT.end.y + 12)
		knob.size = Vector2(11, 11)
		add_child(knob)
	var screen := TextureRect.new()
	_atlas = AtlasTexture.new()
	_atlas.atlas = load(SHOW_SHEET)
	_atlas.region = Rect2(0, 0, FRAME.x, FRAME.y)
	screen.texture = _atlas
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # before the size, or it clamps to the texture
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.position = TV_RECT.position
	screen.size = TV_RECT.size
	add_child(screen)
	var tape := ColorRect.new()
	tape.position = TV_RECT.position
	tape.size = TV_RECT.size
	_disturb = ShaderMaterial.new()
	_disturb.shader = load("res://shaders/tv_disturb.gdshader")
	tape.material = _disturb
	add_child(tape)
	var lines := ColorRect.new()  # scanlines and curvature shade over the glass
	lines.position = TV_RECT.position
	lines.size = TV_RECT.size
	var crt := ShaderMaterial.new()
	crt.shader = load("res://shaders/crt_glass.gdshader")
	lines.material = crt
	add_child(lines)

	_music = AudioStreamPlayer.new()
	_music.stream = Sfx.get_stream("menu_theme", true)
	_music.volume_db = -40.0
	_music.bus = Settings.BUS_MUSIC
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", -6.0, 2.5)

	var col := VBoxContainer.new()
	_col = col
	col.position = Vector2(26, 22)
	col.custom_minimum_size = Vector2(196, 0)
	col.add_theme_constant_override("separation", 3)
	add_child(col)
	col.add_child(_label("¡HOLA, VECINITOS!", FONT_TITLE, ACCENT))
	col.add_child(_label(tr("UNIDAD DE RECUPERACIÓN · CANAL 9 · 1989"), 11, DIM))
	col.add_child(UiKit.spacer(3))
	col.add_child(UiKit.rule(170))
	col.add_child(UiKit.spacer(6))

	var name_row := HBoxContainer.new()
	name_row.add_child(_label(tr("NOMBRE "), FONT, DIM))
	_name_edit = _edit(Net.my_name, 16)
	_name_edit.custom_minimum_size = Vector2(140, 0)
	name_row.add_child(_name_edit)
	col.add_child(name_row)
	col.add_child(UiKit.spacer(6))

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 1)
	col.add_child(_main_box)
	_first_button = _button(tr("JUGAR SOLO"), _solo)
	_main_box.add_child(_first_button)
	_main_box.add_child(_button(tr("CREAR SALA ONLINE"), _host))
	_join_box = HBoxContainer.new()
	_main_box.add_child(_join_box)
	_join_box.add_child(_button(tr("UNIRSE"), _join))
	_code_edit = _edit("", 15)
	_code_edit.placeholder_text = tr("código")
	_code_edit.custom_minimum_size = Vector2(90, 0)
	_code_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_code_edit.text_submitted.connect(func(_t: String) -> void: _join())
	_join_box.add_child(_code_edit)
	if OS.is_debug_build():
		_main_box.add_child(_button(tr("CREAR SALA LAN (desarrollo)"), _host_lan))
	_main_box.add_child(UiKit.spacer(4))
	_main_box.add_child(_button(tr("AJUSTES"), _open_options))
	_main_box.add_child(_button(tr("CRÉDITOS"), _open_credits))
	_main_box.add_child(_button(tr("SALIR"), func() -> void: get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)))

	_lobby_box = VBoxContainer.new()
	_lobby_box.visible = false
	_lobby_box.add_theme_constant_override("separation", 3)
	col.add_child(_lobby_box)
	_room = _label("", 16, ACCENT)
	_lobby_box.add_child(_room)
	_lobby_box.add_child(_label(tr("Pasa el código a tus amigos (hasta 4)."), 11, DIM))
	_list = VBoxContainer.new()
	_lobby_box.add_child(_list)
	_start = _button(tr("EMPEZAR LA NOCHE"), _start_night)
	_lobby_box.add_child(_start)
	_lobby_box.add_child(_button(tr("SALIR DE LA SALA"), _leave))

	_status = _label("", 11, UiKit.ALERT)
	_status.position = Vector2(26, 250)
	_status.size = Vector2(300, 14)
	add_child(_status)
	var help := _label(tr("v%s · Auriculares recomendados") % ProjectSettings.get_setting("application/config/version", "0"), 10, DIM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.position = Vector2(254, 252)
	help.size = Vector2(206, 12)
	add_child(help)

	# Settings and credits open centred over a dimmed room.
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	_options = OptionsPanel.new()
	center.add_child(_options)
	_options.closed.connect(_close_overlay)
	_credits = _build_credits()
	center.add_child(_credits)


func _build_credits() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(10))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	box.add_child(UiKit.label(tr("CRÉDITOS"), 16, ACCENT))
	box.add_child(UiKit.rule(300))
	box.add_child(UiKit.spacer(4))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	for pair: Array in [
			[tr("MOTOR"), "Godot Engine (MIT)"],
			[tr("RED"), "Epic Online Services\nplugin EOSG, Delano Lourenco (MIT)"],
			[tr("TIPOGRAFÍA"), "VT323, Peter Hull (SIL OFL 1.1)"],
			[tr("MÚSICA Y SONIDO"), tr("Síntesis original del proyecto")],
			[tr("ARTE"), tr("Texturas y la Visita, originales")]]:
		var k := UiKit.label(pair[0], UiKit.FONT_SMALL, DIM)
		k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		k.custom_minimum_size = Vector2(0, 14)
		k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(k)
		grid.add_child(UiKit.label(pair[1], FONT, TEXT))
	box.add_child(UiKit.spacer(6))
	box.add_child(UiKit.label(tr("Gracias por jugar con la tele encendida."), UiKit.FONT_SMALL, DIM))
	box.add_child(UiKit.spacer(3))
	box.add_child(UiKit.rule(300))
	box.add_child(UiKit.spacer(2))
	box.add_child(_button(tr("VOLVER"), _close_overlay))
	panel.visible = false
	return panel


func _open_options() -> void:
	_overlay.visible = true
	_options.open()


func _open_credits() -> void:
	_overlay.visible = true
	_credits.visible = true
	(_credits.find_children("*", "Button", true, false)[0] as Button).grab_focus()


func _close_overlay() -> void:
	_credits.visible = false
	_overlay.visible = false
	_show_main()


func _unhandled_input(event: InputEvent) -> void:
	if _credits and _credits.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_overlay()


func _set_busy(busy: bool) -> void:
	for b in _main_box.find_children("*", "Button", true, false):
		(b as Button).disabled = busy


func _label(text: String, size_px: int, color: Color) -> Label:
	return UiKit.label(text, size_px, color)


func _button(text: String, action: Callable) -> Button:
	return UiKit.button(text, action)


func _edit(text: String, max_len: int) -> LineEdit:
	return UiKit.edit(text, max_len)
