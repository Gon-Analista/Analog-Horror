class_name StationNight
extends Control
## The second night's own pieces (propuesta): the building's public address
## and your eyelids.
##   * Megafonía: the three-note chime, a voice from the ceiling speakers
##     you cannot quite make out, and what it says as a subtitle. It gives
##     the rules at first; once the broadcast has turned (TV_CORRUPT_AT
##     masters), it lies. Every machine plays the same lines at the same
##     events (the tapes, the blackout and the wake are already shared), so
##     nothing of its own goes over the network.
##   * The blink: when the host says you blink (Husk._blink), black lids
##     close and open over the picture for a moment. It moved.

const PA_DB := -4.0
const LINE_TIME := 6.5

var run: Run
var husk: Husk
var _top: ColorRect
var _bottom: ColorRect
var _sub: Label
var _sub_left := 0.0
var _said := {}
var _queue: Array[String] = []
var _busy := 0.0
var _woke := false
var _speaker: AudioStreamPlayer


func setup(p_run: Run, p_husk: Husk) -> void:
	run = p_run
	husk = p_husk
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var lid := ColorRect.new()
		lid.color = Color(0.0, 0.0, 0.0)
		lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lid.visible = false
		add_child(lid)
		if i == 0:
			_top = lid
		else:
			_bottom = lid
	_sub = Label.new()
	_sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)  # (the bottom is the viewfinder's)
	_sub.offset_top = 26
	_sub.offset_bottom = 48
	_sub.offset_left = 30
	_sub.offset_right = -30
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	_sub.add_theme_font_size_override("font_size", 11)
	_sub.add_theme_color_override("font_color", Color(0.86, 0.9, 0.78))
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_sub.add_theme_constant_override("outline_size", 4)
	_sub.modulate.a = 0.0
	add_child(_sub)
	_speaker = AudioStreamPlayer.new()
	_speaker.bus = "Effects"
	_speaker.volume_db = PA_DB
	add_child(_speaker)
	run.tapes_changed.connect(_on_tapes)


func _process(delta: float) -> void:
	if run == null:
		return
	_blink_lids()
	# The lines, one after the other.
	_busy -= delta
	if _busy <= 0.0 and not _queue.is_empty():
		_announce(_queue.pop_front())
	_sub_left -= delta
	_sub.modulate.a = move_toward(_sub.modulate.a, 1.0 if _sub_left > 0.0 else 0.0, delta * 3.0)
	if run.phase != Run.Phase.PLAYING:
		return
	if run.time > 3.0:
		_say("start")
	if not _woke and husk.state != Entity.State.DORMANT:
		_woke = true
		_say("wake")
	if run.time > 140.0 and run.tapes_got < Tuning.TV_CORRUPT_AT:
		_say("camera")


func _blink_lids() -> void:
	var b := husk.blink if husk else 0.0
	var on := b > 0.0
	_top.visible = on
	_bottom.visible = on
	if not on:
		return
	var k := 1.0 - b / Husk.BLINK_TIME
	var closed := clampf(sin(k * PI) * 1.7, 0.0, 1.0)
	var h := size.y * 0.5 * closed
	_top.position = Vector2.ZERO
	_top.size = Vector2(size.x, h)
	_bottom.position = Vector2(0, size.y - h)
	_bottom.size = Vector2(size.x, h)


func _on_tapes(got: int, needed: int) -> void:
	if got <= 0:
		return
	if got >= needed:
		_say("all")
	elif got == run.blackout_at():
		_say("blackout")
	if got >= Tuning.TV_CORRUPT_AT and got < needed:
		# The broadcast has turned: so has the voice on the speakers.
		_say("lie_look" if not _said.has("lie_look") else "lie_film")


## Each line once a night.
func _say(key: String) -> void:
	if _said.has(key):
		return
	_said[key] = true
	_queue.append(key)


func _announce(key: String) -> void:
	var text := _text_for(key)
	_speaker.stream = Sfx.get_stream("pa_chime")
	_speaker.play()
	_busy = LINE_TIME + 1.5
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree():
		return
	# Its voice: the costume's, through the building's speakers.
	_speaker.stream = Sfx.get_stream("husk_voicebox2" if key == "all" else "pa_voice")
	_speaker.play()
	_sub.text = text
	_sub_left = LINE_TIME


func _text_for(key: String) -> String:
	match key:
		"start":
			return tr("MEGAFONÍA: «Personal de Canal 9: recojan los másteres del programa y salgan por el muelle de carga.»")
		"wake":
			return tr("MEGAFONÍA: «Recuerden: el muñeco no se mueve mientras alguien lo mira.»")
		"camera":
			return tr("MEGAFONÍA: «La cámara no lo ve. Sus ojos sí.»")
		"blackout":
			return tr("MEGAFONÍA: «Corte de luz en el edificio. Usen las linternas. No dejen de mirarlo.»")
		"lie_look":
			return tr("MEGAFONÍA: «Puede dejar de mirarlo. Apague la linterna. Descanse los ojos.»")
		"lie_film":
			return tr("MEGAFONÍA: «Grabe al muñeco para el archivo. Mírelo por la cámara.»")
		"all":
			return tr("MEGAFONÍA: «¡Hola, vecinito! ¡Te estoy viendo!»")
	return ""
