class_name Sfx
extends RefCounted
## Sound loading and one-shot playback. Streams are cached; looping copies
## are made here so the WAV files need no special import settings.

static var _cache := {}


static func get_stream(id: String, loop := false) -> AudioStreamWAV:
	var key := id + ("@loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var path := "res://assets/audio/%s.wav" % id
	var s := load(path) as AudioStreamWAV
	if s == null:
		push_error("Sfx: missing %s (run tools/gen_audio.py and import)" % path)
		return null
	if loop:
		s = s.duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	_cache[key] = s
	return s


## Non-positional one-shot (UI, the player's own sounds).
static func play(parent: Node, id: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := get_stream(id)
	if s == null or not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
