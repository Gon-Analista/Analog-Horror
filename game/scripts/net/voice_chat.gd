class_name VoiceChat
extends Node
## Proximity voice. The microphone is read straight from the audio server
## (AudioServer.get_input_frames, at the device's own rate), filtered and
## resampled to 16 kHz, cleaned (high-pass, voice detection with pre-roll
## or push-to-talk, a slow automatic gain and a limiter), cut in 20 ms
## frames, compressed (mu-law, 16 KB/s while talking) and sent over the
## game's own connection (Epic P2P online, ENet on LAN).
## Each listener keeps a small jitter buffer per speaker (packets arrive in
## bursts over the internet): it waits for ~60 ms of voice, then feeds the
## speaker's 3D sound at a steady pace, hides a lost frame by repeating the
## last one softer, and skips ahead if it falls behind (never plays what
## was said seconds ago). Every voice plays from the speaker's head: it
## fades with distance and is muffled through walls (a ray every 0.1 s).
## The taken can still talk, but only to the other spectators. The host
## also learns who is talking: the entity is drawn to voices.
##
## (Epic's own voice rooms (RTC) can only change each participant's
## volume: no 3D position, no occlusion. So the voice rides on Epic's P2P
## and is spatialised here.)

const RATE := 16000
const FRAME := 320          # 20 ms at 16 kHz (50 packets a second, 322 bytes)
const VAD_MIN := 0.006      # RMS below this is never voice
const VAD_RATIO := 2.6      # ...and it must be this far above the noise floor
const VAD_HANGOVER := 0.45  # keep sending this long after the last loud frame
const PREROLL := 3          # frames sent from before the gate opened (the start of a word)
const TARGET_RMS := 0.22    # what the automatic gain aims at
const MAX_GAIN := 10.0
const JITTER_START := 3     # frames to wait for before playing a burst
const JITTER_MAX := 12      # more queued than this (240 ms): skip ahead
const FILL := 0.1           # seconds kept in the 3D player's buffer (enough at 20 fps)
const MIC_BUS := "VoiceIn"
const VOICE_BUS := "Voice"
const OPEN_CUTOFF := 8000.0
const WALL_CUTOFF := 900.0

enum Mode { OPEN, PUSH_TO_TALK, OFF }

var run: Run
## Dev: send a test tone instead of the microphone (--net-test).
var test_tone := false
## Host: peer id -> last time (s) they were heard. The entity listens.
var heard := {}
## Local: transmitting right now (for the HUD).
var transmitting := false
## Local: how loud the microphone is right now, 0..1 (for the options meter).
var mic_level := 0.0
var frames_received := 0

# Capture.
var _direct := false        # AudioServer.get_input_frames (else the old bus capture)
var _capture: AudioEffectCapture
var _mic: AudioStreamPlayer
var _lp := [Biquad.new(), Biquad.new()]  # anti-alias, before resampling
var _hp := Biquad.new()     # rumble, breath, desk knocks
var _src_rate := 48000.0
var _pos := 0.0
var _prev := 0.0
var _out := PackedFloat32Array()
var _floor := 0.01
var _open_left := 0.0
var _was_open := false
var _history: Array[PackedFloat32Array] = []
var _gain := 2.0
var _tone_phase := 0.0
var _seq := 0
# Playback.
var _voices := {}  # peer id -> Dictionary (see _voice_for)
var _occlusion_in := 0.0
var _clock := 0.0
static var _ulaw_decode := PackedFloat32Array()


## A second-order filter (RBJ cookbook), one sample at a time.
class Biquad:
	var b0 := 1.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func setup(kind: String, hz: float, rate: float, q := 0.7071) -> void:
		var w := TAU * hz / rate
		var alpha := sin(w) / (2.0 * q)
		var c := cos(w)
		var a0 := 1.0 + alpha
		if kind == "low":
			b0 = (1.0 - c) * 0.5 / a0
			b1 = (1.0 - c) / a0
			b2 = b0
		else:
			b0 = (1.0 + c) * 0.5 / a0
			b1 = -(1.0 + c) / a0
			b2 = b0
		a1 = -2.0 * c / a0
		a2 = (1.0 - alpha) / a0

	func run(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y


func setup(p_run: Run) -> void:
	run = p_run
	_make_bus()
	# Alone too: nobody hears you, but the entity does.
	if Net.voice_mode != Mode.OFF:
		start_mic()


## The bus every remote voice plays on (its volume is the "voice" slider).
func _make_bus() -> void:
	if AudioServer.get_bus_index(VOICE_BUS) < 0:
		AudioServer.add_bus()
		var v := AudioServer.bus_count - 1
		AudioServer.set_bus_name(v, VOICE_BUS)
		AudioServer.set_bus_send(v, "Master")
		var comp := AudioEffectCompressor.new()
		comp.threshold = -16.0
		comp.ratio = 2.5
		comp.attack_us = 5000.0
		comp.release_ms = 120.0
		AudioServer.add_bus_effect(v, comp)
		var room := AudioEffectReverb.new()
		room.room_size = 0.25
		room.damping = 0.7
		room.wet = 0.06
		room.dry = 1.0
		AudioServer.add_bus_effect(v, room)
	Settings.apply.call_deferred()  # its volume, once the Voice bus exists


## Opens the microphone (the device chosen in the options).
func start_mic() -> void:
	Settings.apply_mic_device()
	_direct = AudioServer.set_input_device_active(true) == OK
	if _direct:
		_src_rate = AudioServer.get_input_mix_rate()
	else:
		# Older path: a muted bus with a capture effect.
		if AudioServer.get_bus_index(MIC_BUS) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, MIC_BUS)
			AudioServer.set_bus_mute(i, true)
			var cap := AudioEffectCapture.new()
			cap.buffer_length = 0.5
			AudioServer.add_bus_effect(i, cap)
		_capture = AudioServer.get_bus_effect(AudioServer.get_bus_index(MIC_BUS), 0) as AudioEffectCapture
		_mic = AudioStreamPlayer.new()
		_mic.stream = AudioStreamMicrophone.new()
		_mic.bus = MIC_BUS
		add_child(_mic)
		_mic.play()
		_src_rate = AudioServer.get_mix_rate()
	for f: Biquad in _lp:
		f.setup("low", minf(7200.0, _src_rate * 0.45), _src_rate)
	_hp.setup("high", 110.0, RATE)


func _exit_tree() -> void:
	if _direct:
		AudioServer.set_input_device_active(false)


func _process(delta: float) -> void:
	_clock += delta
	if run == null:
		return
	_gather(delta)
	for id: int in _voices.keys():
		_feed(id)
	_occlusion_in -= delta
	if _occlusion_in <= 0.0:
		_occlusion_in = 0.1
		_update_voices()


# --- sending ------------------------------------------------------------------

func _gather(delta: float) -> void:
	if test_tone:
		var n := int(RATE * delta)
		for i in n:
			_tone_phase += TAU * 220.0 / RATE
			_out.append(sin(_tone_phase) * 0.3)
	else:
		var buf := PackedVector2Array()
		if _direct:
			var avail := AudioServer.get_input_frames_available()
			if avail > 0:
				buf = AudioServer.get_input_frames(avail)
		elif _capture != null:
			var avail := _capture.get_frames_available()
			if avail > 0:
				buf = _capture.get_buffer(avail)
		if not buf.is_empty():
			_resample(buf)
	while _out.size() >= FRAME:
		var frame := _out.slice(0, FRAME)
		_out = _out.slice(FRAME)
		_send(frame, FRAME / float(RATE))


## Device rate to 16 kHz: low-passed first (nothing above 7 kHz folds back
## as hiss), then read between samples.
func _resample(buf: PackedVector2Array) -> void:
	var step := _src_rate / RATE
	var lp0: Biquad = _lp[0]
	var lp1: Biquad = _lp[1]
	for v in buf:
		var x := lp1.run(lp0.run((v.x + v.y) * 0.5))
		# _pos: where the next 16 kHz sample falls, from the previous input sample.
		while _pos <= 1.0:
			_out.append(_hp.run(lerpf(_prev, x, _pos)))
			_pos += step
		_pos -= 1.0
		_prev = x


func _send(frame: PackedFloat32Array, seconds: float) -> void:
	var me := run.local_player
	var rms := _rms(frame)
	# The noise floor follows quiet stretches down fast and creeps up slowly.
	_floor = rms if rms < _floor else minf(_floor * 1.002, rms)
	_floor = maxf(_floor, 0.0005)
	mic_level = clampf(rms * 6.0, 0.0, 1.0)
	var open := false
	if test_tone:
		open = true
	elif Net.voice_mode == Mode.PUSH_TO_TALK:
		open = Input.is_action_pressed("push_to_talk")
	elif Net.voice_mode == Mode.OPEN:
		if rms > maxf(VAD_MIN, _floor * VAD_RATIO):
			_open_left = VAD_HANGOVER
		_open_left -= seconds
		open = _open_left > 0.0
	transmitting = open
	# Your own voice goes on your tape whenever you make a sound (not only
	# when the gate opens for the others: alone, or with push-to-talk, the
	# clips still have what you said, screamed, whispered).
	if run.replay and me != null and (rms > VAD_MIN or open):
		run.replay.note_voice(me.peer_id, _encode(_loud(frame)))
	_history.append(frame)
	if _history.size() > PREROLL + 1:
		_history.pop_front()
	if me == null or not open:
		if _was_open and me != null:
			_transmit(_faded(frame, false), me)  # the end, faded out (no click)
		_was_open = false
		return
	if not _was_open:
		# The gate just opened: the start of the word was in the frames before.
		for i in _history.size() - 1:
			_transmit(_faded(_history[i], true) if i == 0 else _history[i], me)
	_was_open = true
	_transmit(frame, me)


## Gain (slow: it should not pump), limiter, mu-law, out.
func _transmit(frame: PackedFloat32Array, me: Player) -> void:
	var rms := _rms(frame)
	# How loud it really was (before the gain): the entity hears this.
	var raw := clampi(int(rms * 1000.0), 0, 255)
	if rms > VAD_MIN:
		var want := clampf(TARGET_RMS / rms, 0.5, MAX_GAIN)
		_gain = lerpf(_gain, want, 0.2 if want < _gain else 0.02)
	var loud := _loud(frame)
	me.voice_level = maxf(me.voice_level, _level(loud))
	_seq = (_seq + 1) % 65536
	var packet := PackedByteArray([_seq & 0xFF, _seq >> 8, raw])
	var coded := _encode(loud)
	packet.append_array(coded)
	if not Net.is_solo():
		if me.alive:
			_voice.rpc(packet)
		else:
			for p: Player in run.players.values():
				if not p.alive and p != me and not p.is_bot:
					_voice.rpc_id(p.peer_id, packet)
	if multiplayer.is_server() and _audible(me, raw):
		heard[multiplayer.get_unique_id()] = _clock


## The gain and a soft limiter.
func _loud(frame: PackedFloat32Array) -> PackedFloat32Array:
	var loud := PackedFloat32Array()
	loud.resize(frame.size())
	for i in frame.size():
		var x := frame[i] * _gain
		loud[i] = x / (1.0 + absf(x) * 0.35) * 1.15  # soft limiter
	return loud


## Whether the entity hears this frame: anything, out in the open; hidden,
## only a real voice (a breath, the room, a fan in the mic do not count).
func _audible(p: Player, raw: int) -> bool:
	if p == null or not p.is_hidden():
		return true
	return raw >= Tuning.HIDDEN_VOICE_RAW


## Where voice detection opens, on the same 0..1 scale as mic_level.
func gate_level() -> float:
	return maxf(VAD_MIN, _floor * VAD_RATIO) * 6.0


static func _faded(frame: PackedFloat32Array, fade_in: bool) -> PackedFloat32Array:
	var out := frame.duplicate()
	var n := out.size()
	for i in n:
		var k := float(i) / n
		out[i] *= k if fade_in else 1.0 - k
	return out


# --- receiving ------------------------------------------------------------------

## Unreliable, with our own numbering: a frame that comes too late is
## thrown away (a reliable channel would queue them up and play what was
## said minutes ago).
@rpc("any_peer", "call_remote", "unreliable", 1)
func _voice(packet: PackedByteArray) -> void:
	var id := multiplayer.get_remote_sender_id()
	if packet.size() < 4:
		return
	frames_received += 1
	if multiplayer.is_server() and _audible(run.players.get(id), packet[2]):
		heard[id] = _clock
	var v := _voice_for(id)
	if v.is_empty():
		return
	var seq := packet[0] | (packet[1] << 8)
	var frames: Dictionary = v.frames
	if v.next >= 0:
		var behind: int = (int(v.next) - seq + 65536) % 65536
		if behind != 0 and behind < 32768:
			return  # its turn has passed
	frames[seq] = _decode(packet.slice(3))
	v.last_heard = _clock
	if run.replay:
		run.replay.note_voice(id, packet.slice(3))


## Keeps the speaker's 3D player a little ahead, from the jitter buffer.
func _feed(id: int) -> void:
	var v: Dictionary = _voices[id]
	if not is_instance_valid(v.player):
		return
	var pb: AudioStreamGeneratorPlayback = v.playback
	var frames: Dictionary = v.frames
	if pb == null:
		return
	if v.next < 0:
		# Waiting for the start of a burst: enough of it, or it has stopped coming.
		if frames.is_empty() or (frames.size() < JITTER_START and _clock - float(v.last_heard) < 0.08):
			return
		v.next = _oldest(frames)
	if frames.size() > JITTER_MAX:
		# Fallen behind: on to the newest few.
		while frames.size() > JITTER_START:
			frames.erase(_oldest(frames))
		v.next = _oldest(frames)
	var speaker: Player = run.players.get(id)
	var queued := int(v.capacity) - pb.get_frames_available()
	while queued < int(RATE * FILL) and pb.get_frames_available() >= FRAME:
		var seq: int = v.next
		var samples: PackedVector2Array
		if frames.has(seq):
			samples = frames[seq]
			frames.erase(seq)
			v.lost = 0
			v.last = samples
		elif not frames.is_empty() and int(v.lost) < 3:
			# Lost on the way: the last frame again, softer each time.
			v.lost = int(v.lost) + 1
			samples = (v.last as PackedVector2Array).duplicate()
			var k := 0.6 / float(v.lost)
			for i in samples.size():
				samples[i] *= k
		elif not frames.is_empty():
			v.next = _oldest(frames)
			continue
		else:
			v.next = -1  # the burst is over: wait for the next one
			break
		pb.push_buffer(samples)
		queued += samples.size()
		v.next = (seq + 1) % 65536
		if speaker:
			speaker.voice_level = maxf(speaker.voice_level, _level_stereo(samples))


static func _oldest(frames: Dictionary) -> int:
	# Sequence numbers wrap at 65536: the oldest is the one furthest behind the newest.
	var keys := frames.keys()
	var newest: int = keys[0]
	for k: int in keys:
		if (k - newest + 65536) % 65536 < 32768:
			newest = k
	var oldest := newest
	for k: int in keys:
		if (newest - k + 65536) % 65536 > (newest - oldest + 65536) % 65536:
			oldest = k
	return oldest


func _voice_for(id: int) -> Dictionary:
	if _voices.has(id):
		var known: Dictionary = _voices[id]
		if is_instance_valid(known.player):
			return known
	var p: Player = run.players.get(id)
	if p == null:
		return {}
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.5
	var player := AudioStreamPlayer3D.new()
	player.stream = gen
	player.bus = VOICE_BUS
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 3.5
	player.max_db = 18.0
	player.volume_db = 12.0
	player.max_distance = 24.0
	player.panning_strength = 0.8  # in headphones a voice right to one side is tiring
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	player.attenuation_filter_cutoff_hz = OPEN_CUTOFF
	player.attenuation_filter_db = -12.0
	player.position = Vector3(0, 0.05, 0)
	p.head.add_child(player)
	player.play()
	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	var entry := {"player": player, "playback": pb, "capacity": pb.get_frames_available() if pb else 0,
			"frames": {}, "next": -1, "last": PackedVector2Array(), "lost": 0, "last_heard": _clock}
	_voices[id] = entry
	return entry


## Who you can hear and how: muffled through walls, the taken only to the
## other spectators.
func _update_voices() -> void:
	var me := run.local_player
	var cam := get_viewport().get_camera_3d()
	if cam == null or me == null:
		return
	var space := cam.get_world_3d().direct_space_state
	for id: int in _voices.keys():
		var v: Dictionary = _voices[id]
		var player := v.player as AudioStreamPlayer3D
		var speaker: Player = run.players.get(id)
		if not is_instance_valid(player) or speaker == null:
			_voices.erase(id)
			continue
		if not speaker.alive and me.alive:
			player.volume_db = -80.0
			continue
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, player.global_position, Tuning.LAYER_WORLD)
		var blocked := not space.intersect_ray(q).is_empty()
		var target_cut := WALL_CUTOFF if blocked else OPEN_CUTOFF
		player.attenuation_filter_cutoff_hz = lerpf(player.attenuation_filter_cutoff_hz, target_cut, 0.5)
		player.volume_db = lerpf(player.volume_db, 6.0 if blocked else 12.0, 0.5)


static func _rms(frame: PackedFloat32Array) -> float:
	var sum := 0.0
	for x in frame:
		sum += x * x
	return sqrt(sum / maxf(1.0, frame.size()))


## How loud a frame is, 0..1, for the mouth.
static func _level(frame: PackedFloat32Array) -> float:
	return clampf(_rms(frame) * 3.5, 0.0, 1.0)


static func _level_stereo(frames: PackedVector2Array) -> float:
	var sum := 0.0
	for v in frames:
		sum += v.x * v.x
	return clampf(sqrt(sum / maxf(1.0, frames.size())) * 3.5, 0.0, 1.0)


# --- mu-law ------------------------------------------------------------------------

static func _encode(frame: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(frame.size())
	for i in frame.size():
		var x := clampi(int(frame[i] * 32767.0), -32767, 32767)
		var sign := 0x80 if x < 0 else 0
		var mag := mini(absi(x) + 132, 32767)
		var exponent := 7
		var mask := 0x4000
		while exponent > 0 and (mag & mask) == 0:
			exponent -= 1
			mask >>= 1
		var mantissa := (mag >> (exponent + 3)) & 0x0F
		out[i] = ~(sign | (exponent << 4) | mantissa) & 0xFF
	return out


static func _decode(data: PackedByteArray) -> PackedVector2Array:
	if _ulaw_decode.is_empty():
		_ulaw_decode.resize(256)
		for b in 256:
			var u := ~b & 0xFF
			var sign := u & 0x80
			var exponent := (u >> 4) & 0x07
			var mantissa := u & 0x0F
			var mag := ((mantissa << 3) + 132) << exponent
			mag -= 132
			_ulaw_decode[b] = (-mag if sign else mag) / 32767.0
	var out := PackedVector2Array()
	out.resize(data.size())
	for i in data.size():
		var s := _ulaw_decode[data[i]]
		out[i] = Vector2(s, s)
	return out
