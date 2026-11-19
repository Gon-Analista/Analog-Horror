class_name PilotHud
extends Control
## The screen of whoever plays the entity, kept to the edges of its sight:
## top left, the crew it still has to take (a figure each, crossed out once
## taken) and the tapes they have; bottom centre, its breath for the hunt
## and what it can do (an icon each, darkened while it recovers, the
## seconds left); in the view, the ripples of what it hears through the
## walls (or an arrow at the edge, when it is behind it) and how far away
## those it feels are. Its sight itself (red, the heat of the living) is
## EntityPilot's: a shader and a material, not this.

## The icons' order in pilot_icons.png (tools/gen_pilot.py).
const ICONS := ["grab", "speak", "ceiling", "sense", "look"]
const SHEET := "res://assets/textures/pilot_icons.png"
const BONE := Color(0.89, 0.82, 0.73)
const BLOOD := Color(0.75, 0.1, 0.08)
const DIM := Color(0.45, 0.32, 0.3)
const SLOT := Vector2(26, 26)
const GAP := 5.0

var pilot: EntityPilot
var _sheet: Texture2D
var _status: Label
var _prompt: Label
var _status_t := 0.0
var _ready_flash := {}  # icon -> seconds of the "ready" glow left
var _was_cd := {}


func setup(p: EntityPilot) -> void:
	pilot = p
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet = load(SHEET)
	_status = _label(16, BLOOD, Vector2(0, 96))
	_prompt = _label(11, BONE, Vector2(0, 168))


func _label(size_px: int, color: Color, at: Vector2) -> Label:
	var l := Label.new()
	l.position = at
	l.size = Vector2(480, 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.0, 0.0, 0.95))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## [icon, key, seconds of cooldown left, cooldown length, usable now]
func _skills() -> Array:
	var p := pilot
	return [
		["grab", tr("CLIC IZQ"), p.attack_cd, Tuning.PILOT_CHARGE_TIME + Tuning.PILOT_ATTACK_COOLDOWN, p.lunge <= 0.0],
		["ceiling", tr("ESPACIO"), p._ceiling_cd + p.climb, Tuning.PILOT_CEILING_COOLDOWN, true],
		["sense", "Q", p.sense_cd, Tuning.PILOT_SENSE_COOLDOWN * (0.5 if p.entity.enraged else 1.0), true],
		["look", "E", p._search_cd, Tuning.PILOT_SEARCH_COOLDOWN, p.focus != null or p.hidden != null],
	]


func _process(delta: float) -> void:
	if pilot == null:
		return
	var run := pilot.run
	visible = run.phase == Run.Phase.PLAYING and not (run.replay and run.replay.playing) and not run.screens.visible  # (not over the briefing)
	var status := ""
	if pilot.asleep():
		status = tr("DUERMES · despiertas cuando acabe la emisión de la tele")
	elif pilot.feeding():
		status = tr("TE ALIMENTAS")
	elif pilot.stun > 0.0:
		status = tr("¡EL FLASH TE CIEGA!")
	elif pilot.exhausted:
		status = tr("sin aliento")
	if status != _status.text:
		_status_t = 0.0
	_status_t += delta
	_status.text = status
	_status.modulate.a = clampf(_status_t * 4.0, 0.0, 1.0) * (0.75 + 0.25 * sin(_status_t * 5.0))
	_status.position.x = randf_range(-1.0, 1.0) if pilot.stun > 0.0 else 0.0
	_prompt.text = pilot.prompt()
	for s: Array in _skills():
		var cd: bool = s[2] > 0.05
		if _was_cd.get(s[0], false) and not cd:
			_ready_flash[s[0]] = 0.35
		_was_cd[s[0]] = cd
		_ready_flash[s[0]] = maxf(0.0, float(_ready_flash.get(s[0], 0.0)) - delta)
	queue_redraw()


func _draw() -> void:
	if pilot == null or not visible or pilot.asleep():
		return
	var font := get_theme_default_font()
	_draw_crew(font)
	_draw_heard(font)
	_draw_skills(font)


## Top left: one figure for each of them (crossed out once taken), the tapes.
func _draw_crew(font: Font) -> void:
	var x := 12.0
	for q: Player in pilot.run.players.values():
		if q.peer_id == pilot.entity.pilot_id:
			continue
		var c := BONE if q.alive else DIM
		draw_circle(Vector2(x + 4, 13), 3.2, c)
		draw_rect(Rect2(x + 1, 17, 6, 9), c)
		if not q.alive:
			draw_line(Vector2(x - 1, 10), Vector2(x + 9, 27), BLOOD, 1.5)
			draw_line(Vector2(x + 9, 10), Vector2(x - 1, 27), BLOOD, 1.5)
		x += 13.0
	var run := pilot.run
	draw_string(font, Vector2(x + 6, 24), tr("CINTAS %d/%d") % [run.tapes_got, run.tapes_needed], HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			BLOOD if run.tapes_got >= run.tapes_needed else BONE)


## What it hears through the walls: ripples where it came from; behind it
## or off the edge, a chevron at the rim pointing that way. Those it feels
## (Q) glow through the walls in 3D; here, only how far.
func _draw_heard(font: Font) -> void:
	var cam := pilot.camera
	var k := size / cam.get_viewport().get_visible_rect().size
	for p: Array in pilot.pings:
		var age: float = p[1]
		var life := clampf(1.0 - age / 1.6, 0.0, 1.0)
		var col := BLOOD if p[2] == "run" else (Color(0.95, 0.55, 0.35) if p[2] == "voice" else Color(0.8, 0.3, 0.22))
		var at: Array = _on_screen(cam, p[0], k)
		if at[1]:
			_chevron(at[0], at[2], col, life)
			continue
		for ring in 3:
			var rr := 2.0 + age * (10.0 + ring * 5.0)
			var c := col
			c.a = life * (0.9 - ring * 0.28)
			draw_arc(at[0], rr, 0.0, TAU, 28, c, 1.2 + (2 - ring) * 0.4, true)
		var dot := col
		dot.a = life
		draw_circle(at[0], 1.6, dot)
	for q in pilot.sensed():
		var at: Array = _on_screen(cam, q.global_position + Vector3.UP * 1.6, k)
		var d := int(q.global_position.distance_to(pilot.body.global_position))
		var c := BLOOD
		c.a = 0.9
		if at[1]:
			_chevron(at[0], at[2], c, 1.0)
		else:
			draw_string(font, at[0] + Vector2(-8, -4), "%d m" % d, HORIZONTAL_ALIGNMENT_CENTER, 16, 10, c)


func _chevron(at: Vector2, angle: float, col: Color, alpha: float) -> void:
	var c := col
	c.a = alpha * 0.9
	var f := Vector2.from_angle(angle)
	var s := f.orthogonal()
	draw_colored_polygon(PackedVector2Array([at + f * 6.0, at - f * 3.0 + s * 4.5, at - f * 1.0, at - f * 3.0 - s * 4.5]), c)


## Bottom centre: its breath, then what it can do.
func _draw_skills(font: Font) -> void:
	var skills := _skills()
	var total := skills.size() * SLOT.x + (skills.size() - 1) * GAP
	var x0 := (size.x - total) * 0.5
	var y := size.y - SLOT.y - 16.0
	# Breath: a thin bar that empties as it hunts.
	var bar := Rect2(Vector2(x0, y - 7), Vector2(total, 3))
	draw_rect(bar.grow(1.0), Color(0.03, 0.0, 0.0, 0.8))
	var fill := bar
	fill.size.x = total * pilot.stamina / pilot.max_stamina()
	var hunting := pilot.move == EntityPilot.Move.SPRINT
	draw_rect(fill, DIM if pilot.exhausted else (Color(1.0, 0.25, 0.18) if hunting else BLOOD))
	for i in skills.size():
		var s: Array = skills[i]
		var r := Rect2(Vector2(x0 + i * (SLOT.x + GAP), y), SLOT)
		var left: float = s[2]
		var ready := left <= 0.05 and bool(s[4])
		draw_rect(r.grow(1.0), Color(0.02, 0.0, 0.0, 0.85))
		draw_rect(r, Color(0.16, 0.02, 0.02, 0.9) if ready else Color(0.07, 0.01, 0.01, 0.9))
		var cell := Rect2(ICONS.find(s[0]) * 32, 0, 32, 32)
		draw_texture_rect_region(_sheet, r.grow(-2.0), cell, Color(1, 1, 1, 1.0 if ready else 0.35))
		if left > 0.05:
			var part := clampf(left / maxf(0.1, float(s[3])), 0.0, 1.0)
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * part)), Color(0.0, 0.0, 0.0, 0.55))
			draw_string(font, r.position + Vector2(0, 18), str(ceili(left)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, BONE)
		var glow: float = _ready_flash.get(s[0], 0.0)
		draw_rect(r, Color(1.0, 0.35, 0.25, 0.3 + glow * 2.0) if ready else Color(0.3, 0.06, 0.05, 0.6), false, 1.0)
		draw_string(font, r.position + Vector2(0, r.size.y + 9), s[1], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, DIM if not ready else BONE)


## Where a point falls on screen: [position, off the view, angle]. Off the
## view (or behind it), the position is on the rim, towards it.
func _on_screen(cam: Camera3D, point: Vector3, k: Vector2) -> Array:
	var local := cam.global_transform.affine_inverse() * point
	var margin := 14.0
	var c := size * 0.5
	if local.z < -0.1:
		var p := cam.unproject_position(point) * k
		if p.x > margin and p.y > margin and p.x < size.x - margin and p.y < size.y - margin:
			return [p, false, 0.0]
	var dir := Vector2(local.x, -local.y if local.z < 0.0 else 0.0)
	if dir.length() < 0.001:
		dir = Vector2(0, 1)
	if local.z >= -0.1 and absf(local.x) < 0.3:
		dir = Vector2(0, 1)  # right behind: at the bottom
	dir = dir.normalized()
	var s := minf((size.x * 0.5 - margin) / maxf(0.001, absf(dir.x)), (size.y * 0.5 - margin) / maxf(0.001, absf(dir.y)))
	return [c + dir * s, true, dir.angle()]
