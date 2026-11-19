extends Control
## Minimal naked-eye HUD: a dot, the interaction prompt, short messages and
## the panel that shows the TV full size (the picture while the show is on,
## the text once the alert cuts in). Hidden through the viewfinder (it has
## its own overlay). Drawn at the window's resolution. Bottom centre, always
## (alone too): the microphone meter, red when the entity can hear you.

const FONT_SIZE := 13
const MESSAGE_TIME := 2.5
const OBJECTIVE_TIME := 6.0
const AMBER := Color(1.0, 0.82, 0.3)
const TEXT := Color(0.9, 0.9, 0.84)
const BROADCAST_BG := Color(0.04, 0.09, 0.42, 0.94)
const SCREEN_SIZE := Vector2(256, 192)

var _player: Player
var voice: VoiceChat
var _tv: TvBroadcast
var _prompt: Label
var _message: Label
var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _panel_text: Label
var _picture: TextureRect
var _message_left := 0.0
## A change of goal: big in the middle for a few seconds, then a line at
## the top until it is done.
var _goal_title: Label
var _goal_line: Label
var _goal_reminder: Label
var _goal_left := 0.0
var _reading := false
var _run: Run
## Steps (path through the house) from you to the entity, refreshed often.
var _entity_steps := 999
var _steps_in := 0.0


func setup(player: Player, run: Run) -> void:
	_player = player
	_run = run
	_tv = run.tv
	run.message.connect(_show_message)
	run.read.connect(func(open: bool) -> void: _reading = open)
	_prompt = _label(Vector2(0, size.y - 46))
	_message = _label(Vector2(0, 36))
	run.objective.connect(_show_objective)
	_goal_title = _label(Vector2(0, roundf(size.y * 0.27)))
	_goal_title.add_theme_font_size_override("font_size", 26)
	_goal_title.add_theme_color_override("font_color", AMBER)
	_goal_title.add_theme_constant_override("outline_size", 6)
	_goal_line = _label(Vector2(0, roundf(size.y * 0.27) + 30))
	_goal_line.add_theme_font_size_override("font_size", 15)
	_goal_reminder = _label(Vector2(0, 18))
	_goal_reminder.add_theme_font_size_override("font_size", 11)
	_goal_reminder.add_theme_color_override("font_color", AMBER.darkened(0.15))
	for l in [_goal_title, _goal_line, _goal_reminder]:
		l.visible = false

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


func _show_objective(title: String, line: String, reminder: String) -> void:
	_goal_title.text = title
	_goal_line.text = line
	_goal_reminder.text = reminder
	_goal_left = OBJECTIVE_TIME


func _show_message(text: String) -> void:
	_message.text = text
	_message_left = MESSAGE_TIME


func _process(delta: float) -> void:
	if _player == null:
		return
	var at_eye := _player.camcorder.raise > 0.5
	var hint := _run.reload_hint() and not _reading  # (also through the viewfinder: that is where it runs out)
	if not _player.alive:
		_prompt.text = ""
	elif _reading:
		_prompt.text = tr("[E] Levantarse") if _tv.is_showing_text() else ""
	elif hint:
		_prompt.text = tr("[R] Recargar batería")
	else:
		_prompt.text = "" if _player.focus == null else String(_player.focus.call("prompt"))
	_prompt.visible = not at_eye or hint
	_steps_in -= delta
	if _steps_in <= 0.0:
		_steps_in = 0.3
		_entity_steps = _steps_to_entity()
	_message_left -= delta
	_goal_left -= delta
	var showing := _goal_left > 0.0 and _player.alive
	_goal_title.visible = showing
	_goal_line.visible = showing
	_goal_title.modulate.a = clampf(_goal_left, 0.0, 1.0)
	_goal_line.modulate.a = clampf(_goal_left, 0.0, 1.0)
	_goal_reminder.visible = not showing and _goal_reminder.text != "" and _player.alive and _run.phase == Run.Phase.PLAYING
	_message.visible = _message_left > 0.0
	_message.modulate.a = clampf(_message_left, 0.0, 1.0)
	_panel.visible = _reading and not at_eye and _player.input_enabled and _tv.is_showing_text()
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
	_draw_mic()
	# A friend's flash in the eyes: white, fading, with a purple afterimage.
	if _run and _run.dazzle > 0.0:
		var k := _run.dazzle
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 0.97, clampf(k * 1.3, 0.0, 1.0)))
		draw_circle(size * 0.5, 40.0 + 30.0 * (1.0 - k), Color(0.6, 0.3, 0.8, 0.35 * k))
	if _player == null or not _player.input_enabled or _player.camcorder.raise > 0.5:
		return
	draw_rect(Rect2((size * 0.5).floor(), Vector2.ONE), Color(0.8, 0.8, 0.75, 0.7))


## How far the entity is, in steps through the house (it hears voices by
## that, like VoiceChat tells it: Tuning.HEAR_VOICE steps). 999: asleep.
func _steps_to_entity() -> int:
	var entity := _run.entity
	if entity == null or entity.state == Entity.State.DORMANT or not _player.alive:
		return 999
	var level := _run.level
	var dist := level.layout.distances(level.nearest_walkable(level.cell_of(_player.global_position)))
	return int(dist.get(level.nearest_walkable(level.cell_of(entity.global_position)), 999))


## The microphone: how loud you are (the bar), where voice detection opens
## (the tick), and whether it is going out. Red, "TE OYE", when what you
## say reaches the entity; "TE ENCUENTRA" if you are hiding and it is close
## enough to tell where.
func _draw_mic() -> void:
	if voice == null:
		return
	# A vertical meter at the left edge, halfway down: it fills upwards.
	var font := get_theme_default_font()
	var bar := Rect2(8, floorf(size.y * 0.5) - 30.0, 5, 60)
	var dim := Color(0.6, 0.6, 0.56, 0.8)
	var label_at := Vector2(4, bar.end.y + 11)
	if Net.voice_mode == VoiceChat.Mode.OFF:
		draw_string(font, label_at, tr("MIC APAGADO"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dim)
		return
	var hears := voice.transmitting and _entity_steps <= int(Tuning.HEAR_VOICE) 			and (not _player.is_hidden() or voice.mic_level * 1000.0 / 6.0 >= Tuning.HIDDEN_VOICE_RAW)
	var finds := hears and _player.is_hidden() and _entity_steps <= 4
	var col := Color(0.95, 0.22, 0.15) if hears else (Color(1.0, 0.82, 0.3) if voice.transmitting else dim)
	draw_rect(bar.grow(1.0), Color(0.0, 0.0, 0.0, 0.7))
	draw_rect(bar, Color(0.28, 0.28, 0.26, 0.9))
	var fill := bar.size.y * clampf(voice.mic_level, 0.0, 1.0)
	draw_rect(Rect2(bar.position.x, bar.end.y - fill, bar.size.x, fill), col)
	if Net.voice_mode == VoiceChat.Mode.OPEN:
		var tick := bar.end.y - bar.size.y * clampf(voice.gate_level(), 0.0, 1.0)
		draw_rect(Rect2(bar.position.x - 1, tick, bar.size.x + 2, 1), Color(0.9, 0.9, 0.84, 0.8))
	draw_circle(Vector2(bar.position.x + 2.5, bar.position.y - 5), 2.0, col if voice.transmitting else Color(0.35, 0.35, 0.33))
	draw_string(font, label_at, tr("MIC"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.85, 0.8))
	var note_at := Vector2(bar.end.x + 5, bar.position.y + 6)
	if hears:
		draw_string(font, note_at, tr("¡TE ENCUENTRA!") if finds else tr("TE OYE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
	elif Net.voice_mode == VoiceChat.Mode.PUSH_TO_TALK and not voice.transmitting:
		draw_string(font, note_at, tr("[V]"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dim)