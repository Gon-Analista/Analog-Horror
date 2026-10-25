extends Control
## Minimal naked-eye HUD: a dot, the interaction prompt and short messages.
## Hidden through the viewfinder (it has its own overlay).

const FONT_SIZE := 8
const MESSAGE_TIME := 2.5

var _player: Player
var _prompt: Label
var _message: Label
var _message_left := 0.0


func setup(player: Player, run: Run) -> void:
	_player = player
	run.message.connect(_show_message)
	_prompt = _label(Vector2(0, size.y - 40))
	_message = _label(Vector2(0, 40))


func _label(pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = Vector2(size.x, 12)
	add_child(l)
	return l


func _show_message(text: String) -> void:
	_message.text = text
	_message_left = MESSAGE_TIME


func _process(delta: float) -> void:
	if _player == null:
		return
	var at_eye := _player.camcorder.raise > 0.5
	_prompt.text = "" if _player.focus == null else String(_player.focus.call("prompt"))
	_prompt.visible = not at_eye
	_message_left -= delta
	_message.visible = _message_left > 0.0
	_message.modulate.a = clampf(_message_left, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _player == null or not _player.input_enabled or _player.camcorder.raise > 0.5:
		return
	draw_rect(Rect2((size * 0.5).floor(), Vector2.ONE), Color(0.8, 0.8, 0.75, 0.7))
