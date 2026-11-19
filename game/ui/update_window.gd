extends CanvasLayer
## The updater's window (autoload/updater.gd loads it by path, never by
## class name). In the game's own register: a broadcast from Channel 9 on an
## old screen: tape noise over whatever is behind, scanlines, a dark panel
## with an amber edge, VT323, the OSD's "▶" and "■"; the download as a tape
## being wound on (a counter and a bar of blocks). Kinds: "update" (current
## → new, size, what is new, Update now / Not now), "itch" (a new full
## version: to the itch page), "broadcast" (a message), and the progress
## and failure of a download.

const AMBER := Color(1.0, 0.82, 0.3)
const TEXT := Color(0.88, 0.88, 0.84)
const DIM := Color(0.55, 0.55, 0.53)
const RED := Color(0.95, 0.35, 0.3)
const GREEN := Color(0.6, 0.95, 0.6)
const PANEL := Rect2(80, 30, 320, 210)
const TAGS := {"new": [AMBER, "NUEVO", "NEW"], "up": [GREEN, "MEJORA", "BETTER"], "fix": [Color(0.6, 0.8, 1.0), "ARREGLO", "FIX"]}

var _updater: Node
var _kind := ""
var _es := true
var _box: Control
var _noise: ShaderMaterial
var _bar: Label
var _status: Label
var _buttons: HBoxContainer
var _t := 0.0
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _busy := false


func setup(updater: Node, kind: String) -> void:
	_updater = updater
	_kind = kind
	_es = TranslationServer.get_locale().begins_with("es")
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	root.add_child(dim)
	var tape := ColorRect.new()
	tape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noise = ShaderMaterial.new()
	_noise.shader = load("res://shaders/tv_disturb.gdshader")
	tape.material = _noise
	root.add_child(tape)
	var frame := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.025, 0.035, 0.97)
	style.border_color = AMBER.darkened(0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", style)
	frame.position = PANEL.position
	frame.size = PANEL.size
	root.add_child(frame)
	_box = VBoxContainer.new()
	_box.position = PANEL.position + Vector2(14, 10)
	_box.size = PANEL.size - Vector2(28, 20)
	_box.add_theme_constant_override("separation", 3)
	root.add_child(_box)
	var glass := ColorRect.new()
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crt := ShaderMaterial.new()
	crt.shader = load("res://shaders/crt_glass.gdshader")
	glass.material = crt
	root.add_child(glass)
	match kind:
		"update":
			_build_update()
		"itch":
			_build_itch()
		_:
			_build_broadcast()


func _s(es: String, en: String) -> String:
	return es if _es else en


func _label(text: String, size_px: int, color: Color, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	(parent if parent else _box).add_child(l)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", AMBER)
	b.add_theme_color_override("font_focus_color", AMBER)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())  # (the "> " and the amber say it)
	b.focus_entered.connect(func() -> void: b.text = "> " + b.text.substr(2))
	b.focus_exited.connect(func() -> void: b.text = "  " + b.text.substr(2))
	b.mouse_entered.connect(func() -> void: b.text = "> " + b.text.substr(2))
	b.mouse_exited.connect(func() -> void: b.text = "  " + b.text.substr(2))
	b.pressed.connect(action)
	_buttons.add_child(b)
	return b


func _header(text: String) -> void:
	_label("▶ " + _s("CANAL 9 · SERVICIO TÉCNICO", "CHANNEL 9 · TECHNICAL SERVICE"), 9, DIM)
	_label(text, 18, AMBER)


func _buttons_row() -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(spacer)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 18)
	_box.add_child(_buttons)


func _build_update() -> void:
	_header(_s("SEÑAL NUEVA", "NEW SIGNAL"))
	var mb := float(_updater.call("offer_size")) / 1048576.0
	_label("%s  ▶  %s     %s" % [_updater.get("version"), _updater.call("offer_version"), ("%.1f MB" % mb) if mb >= 0.1 else "< 0.1 MB"], 12, TEXT)
	var notes: Array = _updater.call("notes")
	if not notes.is_empty():
		_label(_s("NOVEDADES", "WHAT'S NEW"), 9, DIM)
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 92)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_box.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 1)
		scroll.add_child(list)
		for n: Dictionary in notes:
			_label("— %s" % n.get("version", ""), 10, DIM, list)
			for item in n.get("items", []):
				if not item is Dictionary:
					continue
				var tag: Array = TAGS.get(str(item.get("t", "new")), TAGS["new"])
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 5)
				list.add_child(row)
				var t := _label(tag[1] if _es else tag[2], 9, tag[0], row)
				t.autowrap_mode = TextServer.AUTOWRAP_OFF
				t.custom_minimum_size = Vector2(46, 0)
				var txt := _label(str(item.get("es" if _es else "en", item.get("es", ""))), 10, TEXT, row)
				txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				txt.custom_minimum_size = Vector2(230, 0)
	_bar = _label("", 11, AMBER)
	_bar.autowrap_mode = TextServer.AUTOWRAP_OFF
	_bar.visible = false
	_status = _label("", 9, DIM)
	_status.visible = false
	_buttons_row()
	var go := _button(_s("ACTUALIZAR AHORA", "UPDATE NOW"), _accept)
	_button(_s("AHORA NO", "NOT NOW"), _close.bind(true))
	go.grab_focus.call_deferred()


func _build_itch() -> void:
	_header(_s("NUEVA VERSIÓN", "NEW VERSION"))
	_label(_s("La %s ya está en itch.io. Esta versión (%s) no se puede actualizar desde el juego: descarga la nueva desde la página." % [_updater.call("manifest_base"), _updater.get("version")],
			"Version %s is out on itch.io. This one (%s) cannot update itself: download the new one from the page." % [_updater.call("manifest_base"), _updater.get("version")]), 11, TEXT)
	var notes: Array = _updater.call("notes")
	for n: Dictionary in notes.slice(0, 1):
		for item in n.get("items", []).slice(0, 4):
			if item is Dictionary:
				_label("· " + str(item.get("es" if _es else "en", "")), 10, DIM)
	_buttons_row()
	var go := _button(_s("ABRIR ITCH.IO", "OPEN ITCH.IO"), func() -> void:
		_updater.call("open_page")
		_close(true))
	_button(_s("AHORA NO", "NOT NOW"), _close.bind(true))
	go.grab_focus.call_deferred()


func _build_broadcast() -> void:
	_header(_s("MENSAJE DE CANAL 9", "MESSAGE FROM CHANNEL 9"))
	_label(str(_updater.call("broadcast_text", _es)), 12, TEXT)
	_buttons_row()
	_button(_s("VALE", "OK"), _close.bind(true)).grab_focus.call_deferred()


func _accept() -> void:
	if _busy:
		return
	_busy = true
	for b in _buttons.get_children():
		b.queue_free()
	_bar.visible = true
	_status.visible = true
	_updater.call("accept")


## The download: a tape being wound on.
func progress(part: float, done: int, total: int, installing: bool) -> void:
	if _bar == null:
		return
	var n := 18
	var filled := clampi(int(part * n), 0, n)
	_bar.text = "%s %s%s %3d%%" % ["■" if installing else ("▶" if fmod(_t, 1.0) < 0.6 else " "), "▮".repeat(filled), "▯".repeat(n - filled), int(part * 100.0)]
	if installing:
		_status.text = _s("INSTALANDO · EL JUEGO SE REINICIARÁ", "INSTALLING · THE GAME WILL RESTART")
	else:
		_status.text = _s("REBOBINANDO LA CINTA  %.1f / %.1f MB", "WINDING THE TAPE  %.1f / %.1f MB") % [done / 1048576.0, total / 1048576.0]


func failed() -> void:
	_busy = false
	if _status:
		_status.visible = true
		_status.text = _s("SIN SEÑAL: no se pudo actualizar. Inténtalo más tarde.", "NO SIGNAL: the update failed. Try again later.")
		_status.add_theme_color_override("font_color", RED)
	if _buttons:
		_button(_s("CERRAR", "CLOSE"), _close.bind(true))


func _close(_declined: bool) -> void:
	Input.mouse_mode = _mouse_before
	if _updater:
		_updater.call("decline")
	else:
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	if _noise:
		# Tape noise: a little, with a roll now and then.
		_noise.set_shader_parameter("disturb", 0.08 + (0.25 if fmod(_t, 6.0) < 0.15 else 0.0))
