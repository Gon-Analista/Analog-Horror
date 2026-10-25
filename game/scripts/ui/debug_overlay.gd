extends Label
## F3: frame time, draw calls, objects, video memory and run state. The
## first place to look when something gets slow (dev_guidelines §9).

var _player: Player
var _entity: Entity
var _refresh := 0.0


func setup(player: Player, entity: Entity) -> void:
	_player = player
	_entity = entity
	visible = false
	add_theme_font_size_override("font_size", 8)
	add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	add_theme_color_override("font_shadow_color", Color.BLACK)
	position = Vector2(4, 4)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible
	elif event.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.25
	var lines := PackedStringArray()
	lines.append("FPS %d  frame %.1f ms" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	lines.append("draw calls %d  objects %d  prims %dk" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
	lines.append("vram %.0f MB  nodes %d" % [Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	if _entity and _player:
		lines.append("entity %s  d=%.1f m  battery %d%%" % [Entity.State.keys()[_entity.state], _player.global_position.distance_to(_entity.global_position), int(_player.camcorder.battery)])
	text = "\n".join(lines)
