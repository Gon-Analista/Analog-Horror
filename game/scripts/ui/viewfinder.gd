extends Control
## Camcorder viewfinder overlay (REC, battery, counter, date, frame marks),
## drawn only while the camcorder is at the eye.

const WHITE := Color(0.92, 0.92, 0.88)
const RED := Color(0.95, 0.15, 0.1)
const FONT_SIZE := 13
const MARGIN := 14.0

var _player: Player
var _run: Run
var _tapes := 0
var _needed := 0
var _t := 0.0
var _white := 0.0
var _scare := 0.0


func setup(player: Player, run: Run) -> void:
	_player = player
	_run = run
	run.flash.connect(func() -> void: _white = 1.0)
	run.scared.connect(func() -> void: _scare = 1.5)
	run.tapes_changed.connect(func(got: int, needed: int) -> void:
		_tapes = got
		_needed = needed)


func _process(delta: float) -> void:
	_t += delta
	_white = maxf(0.0, _white - delta * 3.5)
	_scare = maxf(0.0, _scare - delta)
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var p := _run.viewed_player()
	var spectating := p != _player
	if p.camcorder.raise < 0.9 and not spectating:
		return
	var cam := p.camcorder
	var font := get_theme_default_font()
	var w := size.x
	var h := size.y
	var m := MARGIN
	var l := 10.0
	for c: Vector2 in [Vector2(m, m), Vector2(w - m, m), Vector2(m, h - m), Vector2(w - m, h - m)]:
		var sx := 1.0 if c.x < w * 0.5 else -1.0
		var sy := 1.0 if c.y < h * 0.5 else -1.0
		draw_line(c, c + Vector2(l * sx, 0), WHITE)
		draw_line(c, c + Vector2(0, l * sy), WHITE)
	if _white > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _white * 0.9 * Settings.flash_scale()))
	if _scare > 0.0:
		# Cuts: a frame of red, a frame of black, torn bars.
		# (Fewer flashes: the same cuts, much fainter.)
		var phase := int(_scare * 16.0) % 4
		var calm := Settings.flash_scale()
		if phase == 0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.0, 0.0, 0.45 * minf(1.0, _scare) * calm))
		elif phase == 2:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55 * minf(1.0, _scare) * calm))
		for i in 3:
			var y := fmod(_t * 900.0 + i * 97.0, size.y)
			draw_rect(Rect2(0, y, size.x, 3 + i * 2), Color(1, 1, 1, 0.25))
	if not spectating:
		# The flash: ready, or recharging.
		var ready := cam.flash_cooldown <= 0.0 and cam.battery >= (Tuning.FLASH_COST if Net.is_solo() else Tuning.FLASH_COST_COOP)
		var fx := w - m - 64.0
		var fy := h - m - 30.0
		draw_string(font, Vector2(fx, fy), tr("FLASH"), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, WHITE if ready else Color(0.6, 0.6, 0.58))
		if not ready:
			var k := 1.0 - cam.flash_cooldown / Tuning.FLASH_COOLDOWN
			draw_rect(Rect2(fx + 34, fy - 7, 26 * clampf(k, 0.0, 1.0), 4), WHITE)
		else:
			draw_circle(Vector2(fx + 40, fy - 5), 2.5, Color(1.0, 0.9, 0.4))
	var mid := Vector2(w, h) * 0.5
	draw_line(mid - Vector2(4, 0), mid + Vector2(4, 0), WHITE)
	draw_line(mid - Vector2(0, 4), mid + Vector2(0, 4), WHITE)

	var top := m + 12.0
	if spectating:
		# Watching a teammate's feed after being taken.
		var label := tr("CÁMARA DE %s") % p.display_name.to_upper()
		draw_string(font, Vector2(m + 4, top), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, p.tint.lightened(0.3))
		if cam.filming and fmod(_t, 1.0) < 0.6:
			draw_circle(Vector2(w - m - 30, top - 4), 3.0, RED)
		draw_string(font, Vector2(m + 4, top + 13), tr("CINTAS %d/%d · clic: otra cámara") % [_tapes, _needed], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, WHITE)
		return
	if cam.battery > 0.0:
		if fmod(_t, 1.0) < 0.6:
			draw_circle(Vector2(m + 8, top - 4), 3.0, RED)
		draw_string(font, Vector2(m + 15, top), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, WHITE)
	elif fmod(_t, 0.8) < 0.5:
		draw_string(font, Vector2(m + 4, top), tr("SIN BATERÍA"), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, RED)
	draw_string(font, Vector2(m + 4, top + 13), tr("CINTAS %d/%d") % [_tapes, _needed], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, WHITE)

	# battery: 4 segments
	var bx := w - m - 26.0
	draw_rect(Rect2(bx, top - 8, 22, 9), WHITE, false)
	draw_rect(Rect2(bx + 22, top - 6, 2, 5), WHITE)
	var segments := ceili(cam.battery / 25.0)
	var low := cam.battery < 25.0 and fmod(_t, 0.6) < 0.3
	for i in segments:
		if not low:
			draw_rect(Rect2(bx + 2 + i * 5, top - 6, 4, 5), WHITE)

	var spare := p.inventory.count("battery")
	if spare > 0:  # the spares in the bag, under it
		var text := "+%d" % spare
		draw_string(font, Vector2(w - m - 2 - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x, top + 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, WHITE)

	var secs := int(cam.tape_time)
	var counter := "%d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]
	var cw := font.get_string_size(counter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, Vector2(w - m - 4 - cw, h - m - 4), counter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, WHITE)
	var clock := 52 + int(_run.time / 60.0)
	draw_string(font, Vector2(m + 4, h - m - 16), "OCT.14 1989", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, WHITE)
	draw_string(font, Vector2(m + 4, h - m - 4), "PM %02d:%02d" % [11 + clock / 60, clock % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, WHITE)
