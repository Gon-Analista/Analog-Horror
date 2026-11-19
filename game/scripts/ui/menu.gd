extends Control
## Title and lobby. A dark room lit only by an old TV playing the show on a
## worn tape that now and then goes wrong for a moment; the sign-off music
## plays. Solo, create a room (online code), join with a
## code (or a LAN address, for development), see who is in, start.
## Dev flags (after "--"): --smoke / --shots go straight to the house;
## --net-test host|client runs the two-window online check on LAN;
## --menu-shot <file.png> saves a screenshot of this screen and quits
## (with --options, of the options panel; --access, of the controls and
## accessibility; --credits, of the credits). The arrow keys and Enter work
## the menu too: the first arrow press picks the first button.

const SHOW_SHEET := "res://assets/textures/tv_show.png"
const FRAME := Vector2i(320, 240)
## The TV in the room (base 480x270 coordinates).
const TV_RECT := Rect2(236, 38, 224, 168)
const TEXT := Color(0.9, 0.9, 0.84)
const DIM := Color(0.6, 0.6, 0.58)
const ACCENT := Color(1.0, 0.82, 0.3)
const FONT_TITLE := 26
const FONT := 13

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
var _options_box: VBoxContainer
var _access_box: VBoxContainer
var _credits_box: VBoxContainer
var _title: TextureRect
## The options were open when the language changed (the menu is rebuilt).
static var _reopen_options := false
## The options' microphone meter (talk to see it move).
var _mic_meter: ColorRect
var _mic_on := false
var _name_row: Control
var _name_edit: LineEdit
var _code_edit: LineEdit
var _status: Label
var _room: Label
var _list: GridContainer
var _start: Button
var _lobby_tapes: Button
var _lobby_mode: Button
var _lobby_bots: Button


func _ready() -> void:
	Controls.setup()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var args := OS.get_cmdline_user_args()
	if args.has("--smoke") or args.has("--shots"):
		Net.ensure_solo_players()
		get_tree().change_scene_to_file.call_deferred(Net.GAME_SCENE)
		return
	_build()
	if _reopen_options:
		_reopen_options = false
		_show_options(true)
	Net.players_changed.connect(_refresh_lobby)
	Net.session_failed.connect(func(reason: String) -> void:
		_status.text = reason
		_show_main())
	if Net.last_message != "":
		_status.text = Net.last_message
	var shot := args.find("--menu-shot")
	if shot >= 0 and shot + 1 < args.size():
		if args.has("--options"):  # dev: the options panel instead
			_show_options(true)
		elif args.has("--access"):
			_show_access(true)
		elif args.has("--credits"):
			_show_credits(true)
		elif args.has("--lobby"):  # dev: a full room
			Net.code = "LRXSB"
			Net.players = {1: {"name": "nearQ", "slot": 0}, 2: {"name": "Tomatesixseven", "slot": 1}, 3: {"name": "Lucía", "slot": 2}}
			if args.has("--versus"):
				Net.game_mode = Net.GameMode.VERSUS
				Net.bot_count = 1
			_show_lobby()
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[shot + 1])
		get_tree().quit()
	var t := args.find("--net-test")
	if t >= 0 and t + 1 < args.size():
		_net_test(args[t + 1])


## Esc goes back: out of the controls, the options, the credits or the
## room. An arrow key with nothing picked picks the first button.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_focus_next"):
		if get_viewport().gui_get_focus_owner() == null:
			_focus(_current_box())
			get_viewport().set_input_as_handled()
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_ESCAPE:
		return
	if _access_box.visible:
		_show_access(false)
	elif _options_box.visible:
		_show_options(false)
	elif _credits_box.visible:
		_show_credits(false)
	elif _lobby_box.visible:
		_leave()
	get_viewport().set_input_as_handled()


## The panel on screen now.
func _current_box() -> Control:
	for box: Control in [_access_box, _options_box, _credits_box, _lobby_box]:
		if box.visible:
			return box
	return _main_box


## The keyboard goes to the first button of `box`.
func _focus(box: Control) -> void:
	var first := AccessOptions.first_focus(box)
	if first:
		first.grab_focus()


## After a panel changes: if the keyboard was in use, it follows to the new
## one (a mouse player never sees a picked button).
func _refocus() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null or owner is LineEdit and owner.is_visible_in_tree():
		return
	if not owner.is_visible_in_tree() or not _current_box().is_ancestor_of(owner):
		_focus(_current_box())


func _process(delta: float) -> void:
	_t += delta
	_meter(delta)
	# The show on a worn tape: every so often it goes wrong for a moment.
	var frame: int = TvShow.at(_t)[0]
	if _glitch > 0.0:
		_glitch -= delta
		frame = TvShow.STARE if _glitch > 0.12 else TvShow.STATIC_A + _rng.randi() % 2
	elif _rng.randf() < delta * 0.12:
		_glitch = 0.35
	_atlas.region = TvShow.region(frame)
	_disturb.set_shader_parameter("disturb", 0.75 if _glitch > 0.0 else 0.1 + 0.04 * sin(_t * 0.7))
	_glow.modulate.a = (0.55 if _glitch > 0.0 else 0.85) + 0.08 * sin(_t * 9.0) * sin(_t * 2.3)
	if _title:
		var jump := _glitch > 0.0
		_title.position = Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-1.0, 1.0)) if jump else Vector2.ZERO
		_title.modulate = Color(1.2, 0.85, 0.85, 0.8) if jump else Color(1, 1, 1, 0.94 + 0.06 * sin(_t * 13.0) * sin(_t * 3.1))


# --- actions ---------------------------------------------------------------------

func _solo() -> void:
	Net.my_name = _player_name()
	Net.start_solo()


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
	n = n if n != "" else tr("Operador")
	if n != Settings.player_name and Net.test_role == "":  # (dev tests keep yours)
		Settings.player_name = n  # remembered for next time
		Settings.save()
	return n


func _net_test(role: String) -> void:
	Net.test_role = role
	_name_edit.text = "Anfitrión" if role == "host" else "Invitado"
	if role == "host":
		if OS.get_cmdline_user_args().has("--net-versus"):
			Net.game_mode = Net.GameMode.VERSUS  # (the guest plays the entity)
		_host_lan()
		var args := OS.get_cmdline_user_args()
		var n := args.find("--net-players")
		var want := int(args[n + 1]) if n >= 0 and n + 1 < args.size() else 2
		while Net.players.size() < want:
			await Net.players_changed
		await get_tree().create_timer(0.5).timeout
		for id: int in Net.players:
			if id != 1:
				Net.entity_choice = id
		Net.start_game(7)
	else:
		_code_edit.text = "127.0.0.1"
		await get_tree().create_timer(0.8).timeout
		_join()


# --- lobby ---------------------------------------------------------------------

func _show_main() -> void:
	_main_box.visible = true
	_lobby_box.visible = false
	_name_row.visible = true
	_refocus()


func _show_lobby() -> void:
	_main_box.visible = false
	_lobby_box.visible = true
	_refresh_lobby()
	_refocus()


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
	Net.bot_count = clampi(Net.bot_count, 0, Net.MAX_PLAYERS - ids.size())
	for i in Net.bot_count:
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = Net.COLORS[(ids.size() + i) % Net.COLORS.size()]
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		row.add_child(_label(" " + tr("Bot %d") % (i + 1) + tr("  (IA)"), FONT, DIM))
		_list.add_child(row)
	for i in range(ids.size() + Net.bot_count, Net.MAX_PLAYERS):
		_list.add_child(_label(tr("  · libre"), FONT, DIM))
	_name_row.visible = false  # (your name is in the list)
	_start.visible = Net.is_host()
	_lobby_tapes.visible = Net.is_host()
	_lobby_mode.visible = Net.is_host()
	if not Net.players.has(Net.entity_choice):
		Net.entity_choice = 0
	_lobby_mode.text = _lobby_mode.text.left(2) + _mode_label()
	_lobby_bots.visible = Net.is_host()
	_lobby_bots.text = _lobby_bots.text.left(2) + tr("BOTS: %d") % Net.bot_count
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
	# The screen; the set (tools/gen_menu_tv.py) goes over it, its glass cut out.
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
	var set_art := TextureRect.new()
	set_art.texture = load("res://assets/branding/menu_tv.png")
	set_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	set_art.stretch_mode = TextureRect.STRETCH_SCALE
	set_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_art.position = Vector2(214, 0)
	set_art.size = Vector2(266, 262)
	set_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(set_art)

	_music = AudioStreamPlayer.new()
	_music.stream = Sfx.get_stream("menu_theme", true)
	_music.volume_db = -40.0
	_music.bus = "Music"
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", -6.0, 2.5)

	var col := VBoxContainer.new()
	col.position = Vector2(26, 22)
	col.custom_minimum_size = Vector2(250, 0)
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	# The title (tools/gen_branding.py): a tape that is going. Now and then
	# it jumps, like the TV beside it.
	_title = TextureRect.new()
	_title.texture = load("res://assets/branding/title.png")
	_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_title.custom_minimum_size = Vector2(178, 44)
	var holder := Control.new()  # the title shakes inside it without moving the rest
	holder.custom_minimum_size = _title.custom_minimum_size
	holder.add_child(_title)
	_title.size = _title.custom_minimum_size
	col.add_child(holder)
	col.add_child(_label(tr("UNIDAD DE RECUPERACIÓN · CANAL 9 · 1989"), 11, DIM))
	col.add_child(_spacer(2))

	var name_row := HBoxContainer.new()
	name_row.add_child(_label(tr("NOMBRE "), FONT, DIM))
	_name_edit = _edit(Net.my_name, 16)
	_name_edit.custom_minimum_size = Vector2(140, 0)
	name_row.add_child(_name_edit)
	col.add_child(name_row)
	_name_row = name_row
	col.add_child(_spacer(6))

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 2)
	col.add_child(_main_box)
	_main_box.add_child(_button(tr("JUGAR SOLO"), _solo))
	_main_box.add_child(_tapes_button())
	_main_box.add_child(_button(tr("OPCIONES"), func() -> void: _show_options(true)))
	_main_box.add_child(_button(tr("CREAR SALA ONLINE"), _host))
	_join_box = HBoxContainer.new()
	_main_box.add_child(_join_box)
	_join_box.add_child(_button(tr("UNIRSE"), _join))
	_code_edit = _edit("", 15)
	_code_edit.placeholder_text = tr("código")
	_code_edit.custom_minimum_size = Vector2(90, 0)
	_join_box.add_child(_code_edit)
	if OS.is_debug_build():
		_join_box.add_child(_button(tr("LAN"), _host_lan))  # development: a room on the local network
	_main_box.add_child(_button(tr("CRÉDITOS"), func() -> void: _show_credits(true)))
	_main_box.add_child(_button(tr("SALIR"), func() -> void: get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)))

	_build_options(col)
	_build_access(col)
	_build_credits(col)

	_lobby_box = VBoxContainer.new()
	_lobby_box.visible = false
	_lobby_box.add_theme_constant_override("separation", 3)
	col.add_child(_lobby_box)
	var code_row := HBoxContainer.new()
	_lobby_box.add_child(code_row)
	_room = _label("", 16, ACCENT)
	code_row.add_child(_room)
	code_row.add_child(_button(tr("COPIAR"), func() -> void:
		DisplayServer.clipboard_set(Net.code)
		_status.text = tr("Código %s copiado: pégalo a tus amigos") % Net.code))
	_lobby_box.add_child(_label(tr("Pasa el código a tus amigos (hasta 4)."), 11, DIM))
	_list = GridContainer.new()  # two players a row: everything fits on screen
	_list.columns = 2
	_list.add_theme_constant_override("h_separation", 14)
	_lobby_box.add_child(_list)
	_lobby_tapes = _tapes_button()
	_lobby_box.add_child(_lobby_tapes)
	# The night: all against the house, or one of you is the entity (at
	# random or someone in particular): one button goes round them all.
	_lobby_mode = _button(_mode_label(), func() -> void:
		var ids := Net.players.keys()
		ids.sort()
		var options: Array = [-1, 0]  # normal, the entity at random, then each player
		options.append_array(ids)
		var now := -1 if Net.game_mode == Net.GameMode.NORMAL else Net.entity_choice
		var next: int = options[(options.find(now) + 1) % options.size()]
		Net.game_mode = Net.GameMode.NORMAL if next < 0 else Net.GameMode.VERSUS
		Net.entity_choice = maxi(next, 0)
		_refresh_lobby())
	_lobby_mode.tooltip_text = tr("Uno de vosotros controla a la Visita (2 jugadores o más)")
	var mode_row := HBoxContainer.new()  # (the mode and the bots on one line: it all fits)
	mode_row.add_theme_constant_override("separation", 6)
	_lobby_box.add_child(mode_row)
	mode_row.add_child(_lobby_mode)
	# Crew played by the house: to fill the room, or to hunt as the entity.
	_lobby_bots = _button(tr("BOTS: %d") % Net.bot_count, func() -> void:
		var free := Net.MAX_PLAYERS - Net.players.size()
		Net.bot_count = 0 if Net.bot_count >= free else Net.bot_count + 1
		_refresh_lobby())
	_lobby_bots.tooltip_text = tr("Compañeros manejados por la casa (para llenar la sala o para cazarlos siendo la Visita)")
	mode_row.add_child(_lobby_bots)
	_start = _button(tr("EMPEZAR LA NOCHE"), func() -> void: Net.start_game(randi()))
	_lobby_box.add_child(_start)
	_lobby_box.add_child(_button(tr("SALIR DE LA SALA"), _leave))

	_status = _label("", 11, Color(1.0, 0.55, 0.45))
	_status.position = Vector2(26, 250)
	_status.size = Vector2(430, 14)
	add_child(_status)
	var help := _label(tr("Auriculares recomendados."), 10, DIM)
	help.position = Vector2(330, 252)
	add_child(help)


## How many tapes the night asks for (the house grows with them): click for
## more, right click for fewer.
func _tapes_button() -> Button:
	var b := _button(_tapes_label(), func() -> void: pass)
	var step := func(by: int) -> void:
		var n := Net.tape_count + by
		if n > HouseGenerator.MAX_TAPES:
			n = HouseGenerator.MIN_TAPES
		elif n < HouseGenerator.MIN_TAPES:
			n = HouseGenerator.MAX_TAPES
		Net.tape_count = n
		b.text = b.text.left(2) + _tapes_label()
	b.pressed.connect(step.bind(1))
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			step.call(-1))
	b.tooltip_text = tr("Clic: más cintas · clic derecho: menos")
	return b


func _mode_label() -> String:
	if Net.game_mode == Net.GameMode.NORMAL:
		return tr("MODO: NORMAL")
	return tr("MODO: VISITA AL AZAR") if Net.entity_choice == 0 else tr("MODO: VISITA ES %s") % Net.name_of(Net.entity_choice)


func _tapes_label() -> String:
	var n := Net.tape_count
	var house := tr("casa pequeña") if n <= 6 else tr("casa grande") if n < HouseGenerator.TWO_FLOORS_FROM else tr("dos plantas") if n <= 10 else tr("casa enorme")
	return tr("CINTAS: %d · %s") % [n, house]


## Screen, volumes, microphone and the entity's look (saved by Settings).
func _build_options(col: Control) -> void:
	_options_box = VBoxContainer.new()
	_options_box.visible = false
	_options_box.add_theme_constant_override("separation", 1)
	col.add_child(_options_box)
	var screen := _button(_screen_label(), func() -> void: pass)
	screen.pressed.connect(func() -> void:
		Settings.set_fullscreen(not Settings.fullscreen)
		screen.text = screen.text.left(2) + _screen_label())
	_options_box.add_child(screen)
	for pair: Array in [["master", tr("GENERAL")], ["music", tr("MÚSICA")], ["effects", tr("EFECTOS")], ["voice", tr("CHAT DE VOZ")]]:
		var row := HBoxContainer.new()
		var name_label := _label("  " + pair[1], FONT, TEXT)
		name_label.custom_minimum_size = Vector2(82, 0)
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Settings.volume[pair[0]]
		slider.custom_minimum_size = Vector2(120, 14)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_style_slider(slider)
		var key: String = pair[0]
		slider.value_changed.connect(func(v: float) -> void: Settings.set_volume(key, v))
		row.add_child(slider)
		_options_box.add_child(row)
	var mic := _button(_mic_label(), func() -> void: pass)
	mic.pressed.connect(func() -> void:
		Net.voice_mode = (Net.voice_mode + 1) % 3
		Settings.save()
		mic.text = mic.text.left(2) + _mic_label())
	_options_box.add_child(mic)
	var device := _button(_device_label(), func() -> void: pass)
	device.pressed.connect(func() -> void:
		var list := Settings.mic_devices()
		var i := list.find(Settings.mic_device)
		Settings.set_mic_device(list[(i + 1) % list.size()])
		device.text = device.text.left(2) + _device_label())
	_options_box.add_child(device)
	# The microphone's level, a thin bar under its button (talk to see it move).
	var meter_bg := ColorRect.new()
	meter_bg.color = Color(0.25, 0.25, 0.24)
	meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_bg.anchor_top = 1.0
	meter_bg.anchor_bottom = 1.0
	meter_bg.offset_left = 12
	meter_bg.offset_right = 160
	meter_bg.offset_top = -2
	_mic_meter = ColorRect.new()
	_mic_meter.color = ACCENT
	_mic_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mic_meter.size = Vector2(0, 2)
	meter_bg.add_child(_mic_meter)
	device.add_child(meter_bg)
	var gfx := _button(_graphics_label(), func() -> void: pass)
	gfx.pressed.connect(func() -> void:
		Settings.set_graphics("low" if Settings.graphics == "high" else "high")
		gfx.text = gfx.text.left(2) + _graphics_label())
	_options_box.add_child(gfx)
	# The language: every text is rebuilt, so the menu starts again.
	var lang := _button(_language_label(), func() -> void: pass)
	lang.pressed.connect(func() -> void:
		var list := Settings.languages()
		var i := list.find(Settings.current_language())
		Settings.set_language(list[(i + 1) % list.size()])
		_reopen_options = true
		get_tree().reload_current_scene.call_deferred())
	_options_box.add_child(lang)
	# Controls and accessibility on a page of their own (no room for more
	# rows here), on the same line as going back.
	var last := HBoxContainer.new()
	last.add_theme_constant_override("separation", 10)
	last.add_child(_button(tr("VOLVER"), func() -> void: _show_options(false)))
	last.add_child(_button(tr("CONTROLES Y ACCESIBILIDAD"), func() -> void: _show_access(true)))
	_options_box.add_child(last)
	_tighten(_options_box)


## Many rows: tighter buttons than the main menu's, so all of them fit.
func _tighten(box: Control) -> void:
	AccessOptions.tighten(box)


func _show_options(on: bool) -> void:
	_options_box.visible = on
	_access_box.visible = false
	_credits_box.visible = false
	_main_box.visible = not on
	_name_row.visible = not on
	_refocus()


## Mouse sensitivity, the vertical axis and fewer flashes (AccessOptions).
func _build_access(col: Control) -> void:
	_access_box = VBoxContainer.new()
	_access_box.visible = false
	_access_box.add_theme_constant_override("separation", 2)
	col.add_child(_access_box)
	_access_box.add_child(_label(tr("CONTROLES Y ACCESIBILIDAD"), FONT, ACCENT))
	AccessOptions.add_rows(_access_box, _button, func(text: String) -> Label: return _label(text, FONT, TEXT), _style_slider)
	_access_box.add_child(_spacer(4))
	var keys := _label(tr("WASD moverse · RATÓN mirar · SHIFT correr\nC agacharse · E usar · F linterna · R pilas\nCLIC DCHO cámara · CLIC IZQ flash\nTAB inventario · V hablar · ESC pausa"), 10, DIM)
	_access_box.add_child(keys)
	_access_box.add_child(_spacer(4))
	_access_box.add_child(_button(tr("VOLVER"), func() -> void: _show_access(false)))
	_tighten(_access_box)


func _show_access(on: bool) -> void:
	_access_box.visible = on
	_options_box.visible = not on
	_main_box.visible = false
	_name_row.visible = false
	_refocus()


## Who made it and with what.
func _build_credits(col: Control) -> void:
	_credits_box = VBoxContainer.new()
	_credits_box.visible = false
	_credits_box.add_theme_constant_override("separation", 1)
	col.add_child(_credits_box)
	_credits_box.add_child(_label(tr("CRÉDITOS"), FONT, ACCENT))
	_credits_box.add_child(_spacer(2))
	for pair: Array in [
			[tr("UN JUEGO DE"), "nearQ"],
			[tr("MÚSICA Y SONIDO"), tr("síntesis propia")],
			[tr("MOTOR"), "Godot Engine (MIT)"],
			[tr("ONLINE"), "Epic Online Services · EOSG (MIT)"],
			[tr("FUENTE"), "VT323 · Peter Hull (SIL OFL)"]]:
		var row := HBoxContainer.new()
		var what := _label(pair[0], 11, DIM)
		what.custom_minimum_size = Vector2(78, 0)
		row.add_child(what)
		row.add_child(_label(pair[1], FONT, TEXT))
		_credits_box.add_child(row)
	_credits_box.add_child(_spacer(4))
	_credits_box.add_child(_label(tr("Gracias por grabar con nosotros."), 11, DIM))
	_credits_box.add_child(_spacer(2))
	_credits_box.add_child(_button(tr("VOLVER"), func() -> void: _show_credits(false)))
	_tighten(_credits_box)


func _show_credits(on: bool) -> void:
	_credits_box.visible = on
	_main_box.visible = not on
	_name_row.visible = not on
	_refocus()


func _style_slider(slider: HSlider) -> void:
	AccessOptions.style_slider(slider, TEXT, ACCENT)


func _screen_label() -> String:
	return tr("PANTALLA: COMPLETA (F11)") if Settings.fullscreen else tr("PANTALLA: VENTANA (F11)")


func _graphics_label() -> String:
	return tr("GRÁFICOS: ALTOS (960x540)") if Settings.graphics == "high" else tr("GRÁFICOS: BAJOS (480x270)")


func _language_label() -> String:
	return tr("IDIOMA: %s") % Settings.language_name(Settings.current_language())


func _device_label() -> String:
	var device := Settings.mic_device
	var shown := tr("EL DEL SISTEMA") if device == "Default" else device.to_upper()
	if shown.length() > 26:
		shown = shown.left(25) + "…"
	return tr("ENTRADA: %s") % shown


## While the options are open the microphone is listened to, for the meter.
func _meter(delta: float) -> void:
	var want := _options_box != null and _options_box.visible
	if want != _mic_on:
		_mic_on = want
		if want:
			Settings.apply_mic_device()
		AudioServer.set_input_device_active(want)
	if not _mic_on:
		return
	var n := AudioServer.get_input_frames_available()
	var level := 0.0
	if n > 0:
		var sum := 0.0
		for v in AudioServer.get_input_frames(n):
			sum += v.x * v.x
		level = clampf(sqrt(sum / n) * 8.0, 0.0, 1.0)
	var full := (_mic_meter.get_parent() as Control).size.x
	var w := lerpf(_mic_meter.size.x, full * level, minf(1.0, delta * 12.0))
	_mic_meter.size = Vector2(w, 2)


func _mic_label() -> String:
	return [tr("MICRÓFONO: ABIERTO"), tr("MICRÓFONO: PULSA V"), tr("MICRÓFONO: APAGADO")][Net.voice_mode]


func _set_busy(busy: bool) -> void:
	for b in _main_box.find_children("*", "Button", true, false):
		(b as Button).disabled = busy


func _label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", FONT)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_focus_color", ACCENT)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	b.add_theme_constant_override("outline_size", 4)
	b.mouse_entered.connect(func() -> void: b.text = "> " + b.text.substr(2))
	b.mouse_exited.connect(func() -> void:
		if not b.has_focus():
			b.text = "  " + b.text.substr(2))
	b.focus_entered.connect(func() -> void: b.text = "> " + b.text.substr(2))
	b.focus_exited.connect(func() -> void: b.text = "  " + b.text.substr(2))
	b.pressed.connect(func() -> void:
		Sfx.play(self, "click", -4.0)
		action.call())
	return b


func _edit(text: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.max_length = max_len
	e.add_theme_font_size_override("font_size", FONT)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.55)
	box.border_color = Color(0.6, 0.6, 0.58, 0.8)
	box.set_border_width_all(1)
	box.set_content_margin_all(2)
	e.add_theme_stylebox_override("normal", box)
	e.add_theme_stylebox_override("focus", box)
	return e


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
