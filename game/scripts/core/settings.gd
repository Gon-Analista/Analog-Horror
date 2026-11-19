extends Node
## The player's settings (autoload `Settings`): full screen, the volumes
## (general, music, effects, voice chat), the entity's look, the mic mode
## and the language (the system's the first time: Spanish for Spanish,
## English for anything without a translation of its own). Saved in user://settings.cfg and applied at start. F11 toggles
## full screen anywhere. The game opens in full screen unless the player
## chose a window.

const PATH := "user://settings.cfg"
const WINDOW := Vector2i(1440, 810)
## Volume key -> audio bus. "Voice" is made by VoiceChat (with its effects),
## so it is applied when it exists.
const BUSES := {"master": "Master", "music": "Music", "effects": "Effects", "voice": "Voice"}

var fullscreen := true
## The name the player chose (the menu fills it in).
var player_name := ""
var volume := {"master": 0.8, "music": 0.7, "effects": 1.0, "voice": 1.0}
## The microphone for the voice chat ("Default": the system's).
var mic_device := "Default"
## Graphics: "high" renders the house at 960x540, "low" at 480x270 (the
## original, for very modest PCs).
var graphics := "high"
## Language code ("": the system's). See tools/i18n.py for adding one.
var language := ""
## The "[R]" hint for the first camcorder that runs out has been shown.
var reload_hint_seen := false
## The language the game is written in (its texts are the keys).
const SOURCE_LANGUAGE := "es"
## Each language's name in itself, for the options. (A new language with
## no entry here shows its English name.)
const NATIVE := {"es": "ESPAÑOL", "en": "ENGLISH", "pt": "PORTUGUÊS", "fr": "FRANÇAIS", "de": "DEUTSCH",
		"it": "ITALIANO", "pl": "POLSKI", "ru": "РУССКИЙ", "tr": "TÜRKÇE", "ja": "日本語", "ko": "한국어", "zh": "中文"}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	# The loudest moments (screams, the catch) are held under the ceiling
	# instead of clipping.
	var fx := AudioServer.get_bus_index("Effects")
	var limited := false
	for k in AudioServer.get_bus_effect_count(fx):
		limited = limited or AudioServer.get_bus_effect(fx, k) is AudioEffectHardLimiter
	if not limited:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(fx, limiter)
	_migrate()
	_load()
	apply_language()
	apply()


func apply() -> void:
	for key: String in BUSES:
		_apply_bus(key)
	# Dev runs (tests, screenshot tours) keep their fixed window.
	var args := OS.get_cmdline_user_args()
	for flag in ["--smoke", "--shots", "--net-test", "--menu-shot"]:
		if args.has(flag):
			_set_window_mode(false)
			return
	_set_window_mode(fullscreen)


func set_volume(key: String, value: float) -> void:
	volume[key] = clampf(value, 0.0, 1.0)
	_apply_bus(key)
	save()


## Every language the game has: the one it is written in and every
## translation loaded (project.godot, internationalization).
func languages() -> PackedStringArray:
	var out := PackedStringArray([SOURCE_LANGUAGE])
	for code in TranslationServer.get_loaded_locales():
		var base := code.split("_")[0]
		if not out.has(base):
			out.append(base)
	return out


func language_name(code: String) -> String:
	return NATIVE.get(code, TranslationServer.get_locale_name(code).to_upper())


## The chosen language, or the system's if the game has it (else English).
func current_language() -> String:
	var args := OS.get_cmdline_user_args()
	var forced := args.find("--lang")  # dev: screenshots in each language
	if forced >= 0 and forced + 1 < args.size():
		return args[forced + 1]
	if language != "" and languages().has(language):
		return language
	var system := OS.get_locale_language()
	return system if languages().has(system) else "en"


func apply_language() -> void:
	TranslationServer.set_locale(current_language())
	TvShow.forget()  # its captions are translated once


func set_language(code: String) -> void:
	language = code
	apply_language()
	save()


## The microphones the system offers ("Default" first).
func mic_devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func set_mic_device(device: String) -> void:
	mic_device = device
	apply_mic_device()
	save()


## The chosen microphone, if it is still plugged in (else the system's).
func apply_mic_device() -> void:
	var device := mic_device if mic_devices().has(mic_device) else "Default"
	if AudioServer.input_device != device:
		AudioServer.input_device = device


## How many times 480x270 the 3D world is rendered at.
func render_scale() -> int:
	return 1 if graphics == "low" else 2


func set_graphics(value: String) -> void:
	graphics = value
	save()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_set_window_mode(on)
	save()


## Full screen, or back to the 1440x810 window, centred.
func _set_window_mode(full: bool) -> void:
	if full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size() == WINDOW:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOW)
	var screen := DisplayServer.screen_get_size()
	DisplayServer.window_set_position(DisplayServer.screen_get_position() + (screen - WINDOW) / 2)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	for key: String in volume:
		cfg.set_value("audio", key, volume[key])
	cfg.set_value("game", "voice_mode", Net.voice_mode)
	cfg.set_value("game", "name", player_name)
	cfg.set_value("audio", "mic_device", mic_device)
	cfg.set_value("game", "language", language)
	cfg.set_value("display", "graphics", graphics)
	cfg.set_value("game", "reload_hint_seen", reload_hint_seen)
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	for key: String in volume:
		volume[key] = float(cfg.get_value("audio", key, volume[key]))
	Net.voice_mode = int(cfg.get_value("game", "voice_mode", Net.voice_mode))
	player_name = str(cfg.get_value("game", "name", ""))
	mic_device = str(cfg.get_value("audio", "mic_device", "Default"))
	language = str(cfg.get_value("game", "language", ""))
	graphics = str(cfg.get_value("display", "graphics", "high"))
	reload_hint_seen = bool(cfg.get_value("game", "reload_hint_seen", false))
	if player_name != "":
		Net.my_name = player_name


## The game was called "Señal Perdida": its settings lived in that folder.
## Brought over once, so nobody loses their name, volumes or microphone.
func _migrate() -> void:
	if FileAccess.file_exists(PATH):
		return
	var old := OS.get_user_data_dir().get_base_dir().path_join("Señal Perdida").path_join("settings.cfg")
	if FileAccess.file_exists(old):
		DirAccess.copy_absolute(old, ProjectSettings.globalize_path(PATH))


func _apply_bus(key: String) -> void:
	var i := AudioServer.get_bus_index(BUSES[key])
	if i < 0:
		return
	var v: float = volume[key]
	AudioServer.set_bus_mute(i, v < 0.01)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F11:
		set_fullscreen(not fullscreen)
		get_viewport().set_input_as_handled()
