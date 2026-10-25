extends Control
## Minimal naked-eye HUD: a dot, the interaction prompt, short messages and
## the panel that shows the TV full size (the picture while the show is on,
## the text once the alert cuts in). Hidden through the viewfinder (it has
## its own overlay). Drawn at the window's resolution.

const FONT_SIZE := 13
const MESSAGE_TIME := 2.5
const TEXT := Color(0.9, 0.9, 0.84)
const BROADCAST_BG := Color(0.04, 0.09, 0.42, 0.94)
const SCREEN_SIZE := Vector2(256, 192)

var _player: Player
var _tv: TvBroadcast
var _prompt: Label
var _message: Label
var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _panel_text: Label
var _picture: TextureRect
var _message_left := 0.0
var _reading := false


func setup(player: Player, run: Run) -> void:
	_player = player
	_tv = run.tv
	run.message.connect(_show_message)
	run.read.connect(func(open: bool) -> void: _reading = open)
	_prompt = _label(Vector2(0, size.y - 46))
	_message = _label(Vector2(0, 36))

	_panel = PanelContainer.new()
	_panel_style = StyleBoxFlat.new()
	_panel_style.border_color = Color(0.1, 0.09, 0.08)
	_panel_style.set_border_width_all(6)
	_panel_style.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", _panel_style)
	_panel.position = Vector2((size.x - SCREEN_SIZE.x) * 0.5 - 6, 18)
	var box := Control.new()
	box.custom_minimum_size = SCREEN_SIZE
	_panel.add_child(box)
	_picture = TextureRect.new()
	_picture.size = SCREEN_SIZE
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(_picture)
	_panel_text = Label.new()
	_panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_panel_text.position = Vector2(10, 8)
	_panel_text.size = SCREEN_SIZE - Vector2(20, 16)
	_panel_text.add_theme_font_size_override("font_size", FONT_SIZE)
	_panel_text.add_theme_color_override("font_color", TEXT)
	box.add_child(_panel_text)
	_panel.visible = false
	add_child(_panel)


func _label(pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = Vector2(size.x, 16)
	add_child(l)
	return l


func _show_message(text: String) -> void:
	_message.text = text
	_message_left = MESSAGE_TIME


func _process(delta: float) -> void:
	if _player == null:
		return
	var at_eye := _player.camcorder.raise > 0.5
	if not _player.alive:
		_prompt.text = ""
	elif _reading:
		_prompt.text = tr("[E] Dejar de mirar")
	else:
		_prompt.text = "" if _player.focus == null else String(_player.focus.call("prompt"))
	_prompt.visible = not at_eye
	_message_left -= delta
	_message.visible = _message_left > 0.0
	_message.modulate.a = clampf(_message_left, 0.0, 1.0)
	_panel.visible = _reading and not at_eye and _player.input_enabled
	if _panel.visible:
		var text_mode := _tv.is_showing_text()
		_picture.visible = not text_mode
		_panel_text.visible = text_mode
		if text_mode:
			_panel_text.text = _tv.text()
			_panel_style.bg_color = TvBroadcast.BG_CORRUPT if _tv.state == TvBroadcast.State.CORRUPT else BROADCAST_BG
		else:
			_picture.texture = _tv.screen_texture()
			_panel_style.bg_color = Color.BLACK
	queue_redraw()


func _draw() -> void:
	if _player == null or not _player.input_enabled or _player.camcorder.raise > 0.5:
		return
	draw_rect(Rect2((size * 0.5).floor(), Vector2.ONE), Color(0.8, 0.8, 0.75, 0.7))
