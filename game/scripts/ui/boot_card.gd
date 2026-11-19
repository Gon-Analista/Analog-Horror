class_name BootCard
extends Control
## Plays once per launch before the title: the channel's ident, then the
## warning card (flashing images, loud sounds, headphones). Any key or
## click skips the current card. Part of the fiction, not a menu.

signal done

const IDENT_TIME := 2.4
const WARNING_TIME := 5.0
const FADE := 0.5

var _skip := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_run.call_deferred()


func _run() -> void:
	var ident := _card()
	ident.add_child(_centered(UiKit.label(tr("CANAL 9"), UiKit.FONT_TITLE, UiKit.ACCENT), -14))
	ident.add_child(_centered(UiKit.label(tr("EMISIÓN DEL 14 DE OCTUBRE DE 1989"), UiKit.FONT_SMALL, UiKit.DIM), 14))
	ident.add_child(_bars())
	await _play(ident, IDENT_TIME, "tv_tone")

	var warn := _card()
	var text := UiKit.label(tr("AVISO\n\nEsta emisión contiene luces parpadeantes, imágenes\nintermitentes y sonidos fuertes. Puedes suavizar los\nefectos en AJUSTES.\n\nSe recomienda jugar a oscuras y con auriculares."), UiKit.FONT, UiKit.TEXT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_child(_centered(text, 0))
	await _play(warn, WARNING_TIME, "")

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE)
	await tw.finished
	done.emit()
	queue_free()


func _play(card: Control, hold: float, sound: String) -> void:
	_skip = false
	card.modulate.a = 0.0
	var tone: AudioStreamPlayer
	if sound != "":
		tone = AudioStreamPlayer.new()
		tone.stream = Sfx.get_stream(sound)
		tone.bus = Settings.BUS_SFX
		tone.volume_db = -24.0
		add_child(tone)
		tone.play()
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, FADE)
	var t := 0.0
	while t < hold and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()
	tw.kill()
	tw = create_tween()
	tw.tween_property(card, "modulate:a", 0.0, FADE * 0.6)
	if tone:
		tw.parallel().tween_property(tone, "volume_db", -60.0, FADE * 0.6)
	await tw.finished
	if tone:
		tone.queue_free()
	card.queue_free()


func _card() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _centered(l: Label, dy: float) -> Label:
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.offset_top = dy
	l.offset_bottom = dy
	return l


## A thin strip of test-card colour bars under the ident.
func _bars() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.position = Vector2(240 - 84, 168)
	for c in [Color(0.75, 0.75, 0.75), Color(0.75, 0.75, 0.0), Color(0.0, 0.75, 0.75), Color(0.0, 0.75, 0.0),
			Color(0.75, 0.0, 0.75), Color(0.75, 0.0, 0.0), Color(0.0, 0.0, 0.75)]:
		var bar := ColorRect.new()
		bar.color = c
		bar.custom_minimum_size = Vector2(24, 4)
		row.add_child(bar)
	return row


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_skip = true
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_skip = true
		get_viewport().set_input_as_handled()
