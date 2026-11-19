class_name ReplayUI
extends Control
## The best moments at the end, on an old TV: the clips play on its screen
## (the night's own picture, through the tape), one over and over or all of
## them in a row; arrows either side to go through them (the host: LEFT /
## RIGHT or A / D; SPACE all in a row), and under it only whose clip it is.
## When they got out, it is the recovered tape's own TV.

const TEXT := Color(0.88, 0.88, 0.84)
const DIM := Color(0.55, 0.55, 0.53)
const ACCENT := Color(1.0, 0.82, 0.3)

var _run: Run
var _replay: Replay
## What the tape covers while it plays (and gives back after).
var _hide: Array[CanvasItem] = []
var _was_visible: Array[bool] = []
var _tv: Control
var _screen: TextureRect
var _tape_mat: ShaderMaterial
var _osd: Label
var _stamp: Label
var _name: Label
var _count: Label
var _left: Label
var _right: Label
var _arrow_flash := [0.0, 0.0]
var _shown := -1
var _t := 0.0


func setup(run: Run, hide: Array[CanvasItem]) -> void:
	_run = run
	_replay = run.replay
	_hide = hide
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replay.clips_ready.connect(_show_tv)
	_replay.started.connect(_on_started)
	_replay.stopped.connect(_on_stopped)


func _label(size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(color: Color, radius: int, rect: Rect2) -> Panel:
	var p := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", box)
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## The TV, where the end screen makes room for it.
func _show_tv() -> void:
	var rect: Rect2 = _run.screens.make_room()
	_tv = Control.new()
	_tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tv)
	_tv.add_child(_panel(Color(0.16, 0.1, 0.06), 6, Rect2(rect.position - Vector2(12, 10), rect.size + Vector2(24, 34))))
	_tv.add_child(_panel(Color(0.05, 0.05, 0.05), 12, Rect2(rect.position - Vector2(5, 5), rect.size + Vector2(10, 10))))
	# The screen: the night's picture while a clip plays (the world's own
	# view, tape and all), snow when nothing does.
	var dark := ColorRect.new()
	dark.position = rect.position
	dark.size = rect.size
	dark.color = Color(0.03, 0.03, 0.04)
	_tv.add_child(dark)
	_screen = TextureRect.new()
	_screen.position = rect.position
	_screen.size = rect.size
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_screen.texture = (_run.level.get_viewport() as SubViewport).get_texture()
	_screen.visible = false
	_tv.add_child(_screen)
	var tape := ColorRect.new()
	tape.position = rect.position
	tape.size = rect.size
	_tape_mat = ShaderMaterial.new()
	_tape_mat.shader = load("res://shaders/tv_disturb.gdshader")
	tape.material = _tape_mat
	_tv.add_child(tape)
	var glass := ColorRect.new()
	glass.position = rect.position
	glass.size = rect.size
	var crt := ShaderMaterial.new()
	crt.shader = load("res://shaders/crt_glass.gdshader")
	glass.material = crt
	_tv.add_child(glass)
	_osd = _label(11, Color(0.85, 0.95, 0.85))
	_osd.position = rect.position + Vector2(7, 3)
	_tv.add_child(_osd)
	_stamp = _label(9, Color(0.85, 0.95, 0.85))
	_stamp.position = rect.position + Vector2(rect.size.x - 112, rect.size.y - 16)
	_stamp.size = Vector2(106, 12)
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tv.add_child(_stamp)
	# Arrows either side; under it, whose clip it is and which of how many.
	_left = _label(22, TEXT)
	_left.text = "◀"
	_left.position = Vector2(rect.position.x - 36, rect.get_center().y - 14)
	_left.pivot_offset = Vector2(8, 12)
	_tv.add_child(_left)
	_right = _label(22, TEXT)
	_right.text = "▶"
	_right.position = Vector2(rect.end.x + 18, rect.get_center().y - 14)
	_right.pivot_offset = Vector2(8, 12)
	_tv.add_child(_right)
	_name = _label(15, ACCENT)
	_name.position = Vector2(rect.position.x - 40, rect.end.y + 25)
	_name.size = Vector2(rect.size.x + 80, 18)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tv.add_child(_name)
	_count = _label(9, DIM)
	_count.position = Vector2(rect.position.x, rect.end.y + 42)
	_count.size = Vector2(rect.size.x, 12)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tv.add_child(_count)
	var host := multiplayer.is_server()
	var hint := _label(9, DIM)
	hint.position = Vector2(0, 256)
	hint.size = Vector2(480, 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = tr("◀ ▶ cambiar · ESPACIO: todos seguidos · R: otra noche · M: menú") if host else tr("Elige el anfitrión · M: menú")
	add_child(hint)
	if not host:
		_left.modulate.a = 0.35
		_right.modulate.a = 0.35
	_update_labels(0)


func _on_started(i: int) -> void:
	if _was_visible.is_empty():
		for c in _hide:
			_was_visible.append(c.visible)
			c.visible = false
	if _screen:
		_screen.visible = true
	# The arrow that went there lights up (on every screen).
	if _shown >= 0 and i != _shown and _replay.clips.size() > 1:
		var forward := i == (_shown + 1) % _replay.clips.size()
		_arrow_flash[1 if forward else 0] = 0.3
	_shown = i
	_update_labels(i)


func _on_stopped() -> void:
	for i in _was_visible.size():
		_hide[i].visible = _was_visible[i]
	_was_visible.clear()
	if _screen:
		_screen.visible = false


func _update_labels(i: int) -> void:
	if _name == null or _replay.clips.is_empty():
		return
	i = clampi(i, 0, _replay.clips.size() - 1)
	_name.text = _replay.clip_name(i).to_upper()
	_count.text = "%d / %d" % [i + 1, _replay.clips.size()]


func _process(delta: float) -> void:
	if _tv == null:
		return
	_t += delta
	var playing := _replay.playing
	_osd.text = ("PLAY ▶" if fmod(_t, 1.0) < 0.6 else "PLAY") if playing else "■"
	_tape_mat.set_shader_parameter("disturb", (0.06 + _replay.static_amount() * 0.8) if playing else 0.7)
	# Recorded at: the night began at 23:52 (the intro's card).
	var s := 23 * 3600 + 52 * 60 + int(_replay.clip_time())
	_stamp.text = "14-OCT-89 %02d:%02d:%02d" % [(s / 3600) % 24, (s / 60) % 60, s % 60] if playing else ""
	for k in 2:
		_arrow_flash[k] = maxf(0.0, _arrow_flash[k] - delta)
		var l: Label = _left if k == 0 else _right
		l.add_theme_color_override("font_color", ACCENT if _arrow_flash[k] > 0.0 else TEXT)
		l.scale = Vector2.ONE * (1.3 if _arrow_flash[k] > 0.0 else 1.0)
