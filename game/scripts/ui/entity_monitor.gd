class_name EntityMonitor
extends Control
## Alt+F1: the entity's mind on screen, and you immortal while it is open.
## Only in development: from the editor (debug builds) or with --dev.
## A state-machine diagram (the current mode lit, the last transition in
## yellow), what it knows (target, who it sees, how old its clue is, the
## Director's patience), the log of its decisions with their reasons, the
## log of what it has said, and a button for every sound it can make.
## An overlay you can keep playing under: small see-through panels in the
## corners, the middle of the screen clear, the mouse still yours. Hold Alt
## to show the sound buttons and free the mouse to press them.
## Its mind runs on the host: on a client only the replicated state shows.

const BG := Color(0.02, 0.03, 0.04, 0.6)
const INK := Color(0.85, 0.88, 0.8)
const DIM := Color(0.5, 0.55, 0.5)
const LIT := Color(1.0, 0.75, 0.25)
const EDGE_LIT := Color(1.0, 0.95, 0.3)
const FONT := 8
const BOX := Vector2(44, 10)
const ORIGIN := Vector2(6, 18)
const GRAPH := Rect2(2, 2, 154, 132)
## Where each mode sits on the diagram.
const NODES := {
	Entity.Mode.WANDER: Vector2(52, 0),
	Entity.Mode.CORPSE: Vector2(0, 26),
	Entity.Mode.INVESTIGATE: Vector2(52, 26),
	Entity.Mode.AMBUSH: Vector2(104, 26),
	Entity.Mode.SEARCH: Vector2(52, 52),
	Entity.Mode.FOLLOW: Vector2(0, 78),
	Entity.Mode.CHASE: Vector2(52, 78),
	Entity.Mode.LURK: Vector2(104, 78),
	Entity.Mode.FLEE: Vector2(104, 52),
	Entity.Mode.STALK: Vector2(0, 52),
}
const CATCH := Vector2(52, 102)
## The transitions it can make (Entity._decide and the modes).
const EDGES := [
	[Entity.Mode.WANDER, Entity.Mode.INVESTIGATE], [Entity.Mode.WANDER, Entity.Mode.CORPSE],
	[Entity.Mode.WANDER, Entity.Mode.AMBUSH], [Entity.Mode.WANDER, Entity.Mode.CHASE],
	[Entity.Mode.WANDER, Entity.Mode.FOLLOW], [Entity.Mode.WANDER, Entity.Mode.LURK],
	[Entity.Mode.INVESTIGATE, Entity.Mode.SEARCH], [Entity.Mode.SEARCH, Entity.Mode.WANDER],
	[Entity.Mode.SEARCH, Entity.Mode.INVESTIGATE], [Entity.Mode.SEARCH, Entity.Mode.AMBUSH],
	[Entity.Mode.CHASE, Entity.Mode.SEARCH], [Entity.Mode.FOLLOW, Entity.Mode.CHASE],
	[Entity.Mode.FOLLOW, Entity.Mode.SEARCH], [Entity.Mode.LURK, Entity.Mode.CHASE],
	[Entity.Mode.LURK, Entity.Mode.SEARCH], [Entity.Mode.AMBUSH, Entity.Mode.CHASE],
	[Entity.Mode.AMBUSH, Entity.Mode.WANDER], [Entity.Mode.CORPSE, Entity.Mode.CHASE],
	[Entity.Mode.CORPSE, Entity.Mode.WANDER], [Entity.Mode.CORPSE, Entity.Mode.INVESTIGATE],
	[Entity.Mode.CHASE, Entity.Mode.FLEE], [Entity.Mode.LURK, Entity.Mode.FLEE], [Entity.Mode.FLEE, Entity.Mode.WANDER],
	[Entity.Mode.WANDER, Entity.Mode.FOLLOW], [Entity.Mode.WANDER, Entity.Mode.STALK], [Entity.Mode.STALK, Entity.Mode.FLEE],
]
const NAMES := {
	Entity.Mode.WANDER: "MERODEA", Entity.Mode.INVESTIGATE: "INVESTIGA", Entity.Mode.SEARCH: "BUSCA",  # i18n
	Entity.Mode.CHASE: "PERSIGUE", Entity.Mode.FOLLOW: "SIGUE", Entity.Mode.LURK: "ACECHA",  # i18n
	Entity.Mode.AMBUSH: "EMBOSCADA", Entity.Mode.CORPSE: "CADÁVER", Entity.Mode.FLEE: "HUYE", Entity.Mode.STALK: "SIGILO",  # i18n
	Entity.Mode.PEEK: "SE ASOMA",  # i18n
}
## Every sound it makes, to listen to one by one.
const SOUNDS := ["chase_scream", "chase_scream2", "chase_scream3", "voice_hunger", "voice_hunger2", "voice_agony", "voice_agony2", "flash_fire", "voice_line", "voice_line2", "voice_where", "voice_where2", "voice_where3",
		"voice_cry", "voice_cry2", "voice_moan", "voice_moan2", "voice_frustrated", "voice_frustrated2",
		"voice_giggle2", "voice_hum2", "laugh2", "voice_reverse", "voice_count", "voice_ready", "voice_lost",
		"voice_found", "voice_hum", "voice_giggle", "laugh", "rage", "entity_step", "jingle", "drone",
		"filmed_sting", "break_free", "caught", "death_scream", "intrusion_buzz", "body_thud"]

var _entity: Entity
var _player: Player
var _info: Label
var _log: Label
var _said: Label
var _refresh := 0.0
var _info_data := {}
var _grid: GridContainer
var _mouse_free := false
var _bot_note := ""


func setup(player: Player, entity: Entity) -> void:
	_player = player
	_entity = entity
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_info = _text(Vector2(330, 4), Vector2(146, 74), INK)
	_log = _text(Vector2(4, 210), Vector2(200, 58), DIM)
	_said = _text(Vector2(330, 80), Vector2(146, 44), DIM)
	var grid := GridContainer.new()
	_grid = grid
	grid.visible = false
	grid.columns = 4
	grid.position = Vector2(256, 130)
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 1)
	add_child(grid)
	# A new night straight away, as the crew or as the entity (the host;
	# as the entity with at least two bots to hunt if nobody else is here).
	for as_entity: bool in [false, true]:
		var go := Button.new()
		go.text = "> VISITA" if as_entity else "> JUGADOR"
		go.tooltip_text = tr("Empezar otra noche siendo la Visita") if as_entity else tr("Empezar otra noche como jugador")
		go.custom_minimum_size = Vector2(54, 0)
		go.add_theme_font_size_override("font_size", 7)
		go.add_theme_color_override("font_color", EDGE_LIT)
		go.focus_mode = Control.FOCUS_NONE
		go.pressed.connect(_new_night.bind(as_entity))
		grid.add_child(go)
	var bot := Button.new()
	bot.text = "+ BOT"
	bot.custom_minimum_size = Vector2(54, 0)
	bot.add_theme_font_size_override("font_size", 7)
	bot.add_theme_color_override("font_color", LIT)
	bot.focus_mode = Control.FOCUS_NONE
	bot.pressed.connect(func() -> void:
		var run := get_tree().current_scene.get_node_or_null("Run") as Run
		if run:
			_bot_note = run.spawn_bot())
	grid.add_child(bot)
	for id: String in SOUNDS:
		var b := Button.new()
		b.text = id.replace("voice_", "v:")
		b.custom_minimum_size = Vector2(54, 0)
		b.add_theme_font_size_override("font_size", 7)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: Sfx.play(self, id, -2.0))
		grid.add_child(b)


## Host: a new night now, playing the entity or one of the crew.
func _new_night(as_entity: bool) -> void:
	if not multiplayer.is_server():
		return
	if as_entity:
		Net.game_mode = Net.GameMode.VERSUS
		Net.entity_choice = multiplayer.get_unique_id()
		Net.bot_count = maxi(Net.bot_count, mini(2, Net.MAX_PLAYERS - Net.players.size()))
	else:
		Net.game_mode = Net.GameMode.NORMAL
	Net.start_game(randi())


func _text(pos: Vector2, size_px: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size_px
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", FONT)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F1 and k.alt_pressed:
		visible = not visible
		# Immortal while it is open (the host respects it: Player.net_god).
		_player.net_god = visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or _entity == null:
		return
	# Alt held: the sound buttons, and the mouse to press them.
	var alt := Input.is_key_pressed(KEY_ALT)
	if alt != _mouse_free:
		_mouse_free = alt
		_grid.visible = alt
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if alt else Input.MOUSE_MODE_CAPTURED
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.1
	size = get_viewport().get_visible_rect().size  # under a CanvasLayer anchors have no parent rect
	_info_data = _entity.debug_info()
	var d := _info_data
	var lines := PackedStringArray()
	lines.append(tr("ESTADO %s   POSE %s%s") % [Entity.State.keys()[d.state], d.pose, tr("   ENFURECIDA") if d.enraged else ""])
	lines.append(tr("MODO %s  (%.0f s)") % [tr(NAMES.get(d.mode, "?")), maxf(0.0, d.mode_left)])
	if multiplayer.is_server():
		lines.append(tr("OBJETIVO %s") % (d.target if d.target != "" else "-"))
		lines.append(tr("VE A %s") % (", ".join(d.seen) if not d.seen.is_empty() else tr("nadie")))
		var age: float = d.clue_age
		if age > Tuning.MEMORY:
			lines.append(tr("SABE nada de vosotros"))
		else:
			lines.append(tr("PISTA hace %.1f s · %s%s") % [age, tr("vista") if d.clue_seen else tr("oída"), tr(" · exacta") if d.clue_precise else ""])
		if d.clue_spot != "":
			lines.append(tr("TE VIO ESCONDERTE EN %s") % d.clue_spot)
		lines.append(tr("DIRECTOR calma %.0f / %.0f s") % [d.calm, d.patience])
	else:
		lines.append(tr("(su mente corre en el anfitrión)"))
	if _player:
		lines.append(tr("A TI %.1f m") % _player.global_position.distance_to(_entity.global_position))
	_info.text = "\n".join(lines)
	_log.text = tr("DECISIONES") + "\n" + "\n".join(_entity.events.slice(0, 6))
	_said.text = tr("HA DICHO") + "\n" + "\n".join(_entity.sounds.slice(0, 4))
	if _bot_note != "":
		_said.text += "\n" + _bot_note
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var font := get_theme_default_font()
	draw_rect(GRAPH, BG)
	draw_rect(Rect2(326, 2, 152, 124), BG)
	draw_rect(Rect2(2, 206, 204, 62), BG)
	draw_string(font, Vector2(6, 12), "LA VISITA (ALT+F1)  ALT: SONIDOS Y BOTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LIT)
	draw_string(font, Vector2(GRAPH.end.x - 40, 12), "INMORTAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.3, 0.25))
	if _info_data.is_empty():
		return
	var cur: int = _info_data.mode
	var edge: Array = _info_data.edge
	for e: Array in EDGES:
		var lit: bool = e[0] == edge[0] and e[1] == edge[1]
		_arrow(_centre(e[0]), _centre(e[1]), EDGE_LIT if lit else Color(0.3, 0.34, 0.3), 2.0 if lit else 1.0)
	for m: int in [Entity.Mode.CHASE, Entity.Mode.FOLLOW, Entity.Mode.LURK, Entity.Mode.SEARCH]:
		_arrow(_centre(m), ORIGIN + CATCH + BOX * 0.5, Color(0.45, 0.15, 0.12), 1.0)
	for m: int in NODES:
		var r := Rect2(ORIGIN + NODES[m], BOX)
		var on := m == cur
		draw_rect(r, LIT if on else Color(0.1, 0.12, 0.1))
		draw_rect(r, LIT if on else DIM, false, 1.0)
		draw_string(font, r.position + Vector2(2, 8), NAMES[m], HORIZONTAL_ALIGNMENT_LEFT, BOX.x - 3, FONT, Color.BLACK if on else INK)
	var feeding: bool = _info_data.state == Entity.State.FEEDING
	var cr := Rect2(ORIGIN + CATCH, BOX)
	draw_rect(cr, Color(0.8, 0.12, 0.08) if feeding else Color(0.18, 0.05, 0.04))
	draw_string(font, cr.position + Vector2(2, 8), "ATRAPA", HORIZONTAL_ALIGNMENT_LEFT, BOX.x - 3, FONT, INK)
	if _info_data.state == Entity.State.FROZEN:
		draw_string(font, ORIGIN + Vector2(100, 110), "ATURDIDA", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, Color(0.5, 0.8, 1.0))
	elif _info_data.state == Entity.State.DORMANT:
		draw_string(font, ORIGIN + Vector2(100, 110), "DORMIDA", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, DIM)


func _centre(m: int) -> Vector2:
	return ORIGIN + NODES[m] + BOX * 0.5


func _arrow(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var dir := (b - a).normalized()
	# Stop at the box edges.
	var from := a + dir * _to_edge(dir)
	var to := b - dir * _to_edge(dir)
	draw_line(from, to, color, width)
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([to, to - dir * 5.0 + side * 2.5, to - dir * 5.0 - side * 2.5]), color)


func _to_edge(dir: Vector2) -> float:
	var hx := BOX.x * 0.5 / maxf(absf(dir.x), 0.001)
	var hy := BOX.y * 0.5 / maxf(absf(dir.y), 0.001)
	return minf(hx, hy) + 1.0
