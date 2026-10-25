extends Control
## Title and lobby. A dark room lit only by an old TV playing the show on a
## worn tape that now and then goes wrong for a moment; the sign-off music
## plays. Solo, create a room (online code), join with a
## code (or a LAN address, for development), see who is in, start.
## Dev flags (after "--"): --smoke / --shots go straight to the house;
## --net-test host|client runs the two-window online check on LAN;
## --menu-shot <file.png> saves a screenshot of this screen and quits.

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
var _name_edit: LineEdit
var _code_edit: LineEdit
var _status: Label
var _room: Label
var _list: VBoxContainer
var _start: Button


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


func _show_lobby() -> void:
	_main_box.visible = false
	_lobby_box.visible = true
	_refresh_lobby()


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
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", -6.0, 2.5)

	var col := VBoxContainer.new()
	col.position = Vector2(26, 22)
	col.custom_minimum_size = Vector2(250, 0)
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	col.add_child(_label("¡HOLA, VECINITOS!", FONT_TITLE, ACCENT))
	col.add_child(_label(tr("UNIDAD DE RECUPERACIÓN · CANAL 9 · 1989"), 11, DIM))
	col.add_child(_spacer(12))

	var name_row := HBoxContainer.new()
	name_row.add_child(_label(tr("NOMBRE "), FONT, DIM))
	_name_edit = _edit(Net.my_name, 16)
	_name_edit.custom_minimum_size = Vector2(140, 0)
	name_row.add_child(_name_edit)
	col.add_child(name_row)
	col.add_child(_spacer(6))

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 2)
	col.add_child(_main_box)
	_main_box.add_child(_button(tr("JUGAR SOLO"), _solo))
	_main_box.add_child(_button(tr("CREAR SALA ONLINE"), _host))
	_join_box = HBoxContainer.new()
	_main_box.add_child(_join_box)
	_join_box.add_child(_button(tr("UNIRSE"), _join))
	_code_edit = _edit("", 15)
	_code_edit.placeholder_text = tr("código")
	_code_edit.custom_minimum_size = Vector2(90, 0)
	_join_box.add_child(_code_edit)
	if OS.is_debug_build():
		_main_box.add_child(_button(tr("CREAR SALA LAN (desarrollo)"), _host_lan))
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
	b.mouse_entered.connect(func() -> void: b.text = "> " + text)
	b.mouse_exited.connect(func() -> void: b.text = "  " + text)
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
