extends Control
## The first screen: the LOST SIGNAL card (the same one as the boot
## splash, so it carries straight on from it) while the menu loads in the
## background and the updater takes its first look at the manifest. At the
## bottom, a tape-style loader: a blinking ▶, a bar of blocks, what it is
## doing ("CARGANDO", "BUSCANDO SEÑAL"); tape noise over all of it, the
## logo slipping now and then like a bad tracking. If the updater opens its
## window, this waits behind it. Test runs (any "-- --flag") go straight on.

const MENU := "res://scenes/menu.tscn"
const SPLASH := "res://assets/branding/splash.png"
const MIN_TIME := 1.4   # seen at least this long (it is not a flash)
const MAX_WAIT := 3.5   # the updater's first look: no longer than this
const AMBER := Color(1.0, 0.82, 0.3)
const DIM := Color(0.55, 0.55, 0.53)

var _t := 0.0
var _logo: TextureRect
var _bar: Label
var _status: Label
var _noise: ShaderMaterial
var _progress := [0.0]
var _going := false
## A key or a click during the photosensitivity notice.
var _skip := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := args.find("--boot-shot")  # dev: a picture of this screen
	if not args.is_empty() and shot < 0:
		get_tree().change_scene_to_file.call_deferred(MENU)
		return
	if shot >= 0 and shot + 1 < args.size():
		# (With --notice: the photosensitivity notice instead.)
		get_tree().create_timer(3.5 if args.has("--notice") else 1.0).timeout.connect(func() -> void:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(args[shot + 1])
			get_tree().quit())
	ResourceLoader.load_threaded_request(MENU)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0156863, 0.0156863, 0.0235294)
	add_child(bg)
	_logo = TextureRect.new()
	_logo.texture = load(SPLASH)
	_logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_logo)
	_bar = _label(9, AMBER, 218)
	_status = _label(8, DIM, 231)
	var tape := ColorRect.new()
	tape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noise = ShaderMaterial.new()
	_noise.shader = load("res://shaders/tv_disturb.gdshader")
	tape.material = _noise
	add_child(tape)


func _label(size_px: int, color: Color, y: float) -> Label:
	var l := Label.new()
	l.position = Vector2(0, y)
	l.size = Vector2(480, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	add_child(l)
	return l


func _process(delta: float) -> void:
	if _logo == null or _going:
		return
	_t += delta
	var status := ResourceLoader.load_threaded_get_status(MENU, _progress)
	var loaded := status == ResourceLoader.THREAD_LOAD_LOADED
	var updater := get_node_or_null("/root/Updater")
	var checking := updater != null and not bool(updater.get("checked")) and _t < MAX_WAIT
	var window_open := updater != null and updater.get("_window") != null and is_instance_valid(updater.get("_window"))
	# The bar: loading the menu fills most of it; the signal check the rest.
	var part := float(_progress[0]) * 0.8 + (0.2 if not checking else clampf(_t / MAX_WAIT, 0.0, 1.0) * 0.2)
	var n := 22
	var filled := clampi(int(part * n), 0, n)
	_bar.text = "%s %s%s" % ["▶" if fmod(_t, 1.0) < 0.6 else " ", "▮".repeat(filled), "▯".repeat(n - filled)]
	var es := TranslationServer.get_locale().begins_with("es")
	if not loaded:
		_status.text = "CARGANDO" if es else "LOADING"
	elif checking:
		_status.text = ("BUSCANDO SEÑAL" if es else "SEARCHING FOR SIGNAL") + ".".repeat(int(_t * 3.0) % 4)
	elif window_open:
		_status.text = "SEÑAL ENCONTRADA" if es else "SIGNAL FOUND"
	else:
		_status.text = "SEÑAL ESTABLE" if es else "SIGNAL STABLE"
	# Bad tracking now and then: the logo slips, the noise flares.
	var glitch := fmod(_t, 2.7) < 0.08 or fmod(_t + 1.1, 4.3) < 0.05
	_logo.position = Vector2(randf_range(-3, 3), randf_range(-1, 1)) if glitch else Vector2.ZERO
	_noise.set_shader_parameter("disturb", 0.35 if glitch else 0.07)
	if loaded and not checking and not window_open and _t >= MIN_TIME:
		_going = true
		if not Settings.photosensitivity_seen or OS.get_cmdline_user_args().has("--notice"):
			await _notice()
		var scene := ResourceLoader.load_threaded_get(MENU) as PackedScene
		get_tree().change_scene_to_packed(scene)
		TapeCut.play(get_tree())


## The first time only: the flashing-lights notice, on the same card (a
## key or a click goes on once it has been up a moment).
func _notice() -> void:
	Settings.photosensitivity_seen = true
	Settings.save()
	_skip = false
	_logo.modulate.a = 0.12
	_logo.position = Vector2.ZERO
	_noise.set_shader_parameter("disturb", 0.04)
	_bar.text = ""
	_status.text = ""
	var title := _label(16, AMBER, 70)
	title.text = tr("AVISO DE FOTOSENSIBILIDAD")
	var body := _label(11, Color(0.86, 0.86, 0.82), 98)
	body.size = Vector2(400, 90)
	body.position.x = 40
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = tr("Este juego tiene luces que parpadean, destellos y ruido de imagen intermitente que pueden afectar a personas con epilepsia fotosensible.\nEn OPCIONES > CONTROLES Y ACCESIBILIDAD puedes activar «MENOS DESTELLOS».")
	_status.text = tr("(pulsa una tecla para seguir)")
	_status.modulate.a = 0.0
	var shown := 0.0
	while shown < 7.0:
		await get_tree().process_frame
		shown += get_process_delta_time()
		_status.modulate.a = clampf((shown - 1.2) * 2.0, 0.0, 1.0)
		if shown > 1.2 and _skip:
			break
	title.queue_free()
	body.queue_free()


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		_skip = true
