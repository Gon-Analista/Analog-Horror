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


func setup(player: Player, run: Run) -> void:
	_player = player
	_run = run
	run.tapes_changed.connect(func(got: int, needed: int) -> void:
		_tapes = got
		_needed = needed)


func _process(delta: float) -> void:
	_t += delta
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

	var secs := int(cam.tape_time)
	var counter := "%d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]
	var cw := font.get_string_size(counter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, Vector2(w - m - 4 - cw, h - m - 4), counter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, WHITE)
	var clock := 52 + int(_run.time / 60.0)
	draw_string(font, Vector2(m + 4, h - m - 16), "OCT.14 1989", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, WHITE)
	draw_string(font, Vector2(m + 4, h - m - 4), "PM %02d:%02d" % [11 + clock / 60, clock % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, WHITE)
