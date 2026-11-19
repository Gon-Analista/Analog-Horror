extends Node
## Player settings (autoload `Settings`): look, audio, picture. Saved to
## user://settings.cfg and applied at startup, so they survive between runs.
## Purely local: nothing here is replicated.

signal changed

const PATH := "user://settings.cfg"
const SECTION := "settings"
## Audio buses (default_bus_layout.tres). "Voice" is kept for the future
## proximity chat so it can be mixed above the house.
const BUS_MUSIC := &"Music"
const BUS_SFX := &"Sfx"
const BUS_VOICE := &"Voice"

const DEFAULTS := {
	"mouse_sens": 1.0,     # multiplier of Tuning.MOUSE_SENS
	"invert_y": false,
	"fov": 75.0,
	"vol_master": 0.9,
	"vol_music": 0.8,
	"vol_sfx": 0.9,
	"vhs_fx": 1.0,         # VHS noise, tracking, chroma and lamp flicker (never the gain)
	"brightness": 1.0,
	"fullscreen": false,
}
## Limits, for the options sliders: [min, max, step].
const RANGES := {
	"mouse_sens": [0.2, 3.0, 0.05],
	"fov": [60.0, 95.0, 1.0],
	"vol_master": [0.0, 1.0, 0.05],
	"vol_music": [0.0, 1.0, 0.05],
	"vol_sfx": [0.0, 1.0, 0.05],
	"vhs_fx": [0.25, 1.0, 0.05],
	"brightness": [0.7, 1.5, 0.05],
}

var _values := {}
## 0..1 applied on top of the music and effects (scene transitions fade
## them; the transition's own hiss goes straight to Master).
var _fade := 1.0


func _ready() -> void:
	_values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key: String in DEFAULTS:
			var v: Variant = cfg.get_value(SECTION, key, DEFAULTS[key])
			if typeof(v) == typeof(DEFAULTS[key]):
				_values[key] = v
	_apply_audio()
	# The dev tours and headless tests keep the window as the project sets it.
	if not DisplayServer.get_name() == "headless":
		_apply_window()


## F11 works everywhere (title, house, end screens).
func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action("fullscreen") and event.is_action_pressed("fullscreen"):
		toggle_fullscreen()


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key) or _values[key] == value:
		return
	_values[key] = value
	if key.begins_with("vol_"):
		_apply_audio()
	elif key == "fullscreen":
		_apply_window()
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	for key: String in _values:
		cfg.set_value(SECTION, key, _values[key])
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Settings: could not save %s (error %d)" % [PATH, err])


func reset() -> void:
	_values = DEFAULTS.duplicate()
	_apply_audio()
	_apply_window()
	changed.emit()


func toggle_fullscreen() -> void:
	set_value("fullscreen", not bool(get_value("fullscreen")))
	save()


# --- shortcuts for the systems that read them -------------------------------------

func mouse_sens() -> float:
	return Tuning.MOUSE_SENS * float(get_value("mouse_sens"))


func fov() -> float:
	return float(get_value("fov"))


func vhs_fx() -> float:
	return float(get_value("vhs_fx"))


func brightness() -> float:
	return float(get_value("brightness"))


## Transitions fade the whole mix through this (0..1).
func set_fade(f: float) -> void:
	_fade = clampf(f, 0.0, 1.0)
	_apply_audio()


func get_fade() -> float:
	return _fade


# --- applying --------------------------------------------------------------------

func _apply_audio() -> void:
	_set_bus(&"Master", float(get_value("vol_master")))
	_set_bus(BUS_MUSIC, float(get_value("vol_music")) * _fade)
	_set_bus(BUS_SFX, float(get_value("vol_sfx")) * _fade)


func _set_bus(bus: StringName, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.001)


func _apply_window() -> void:
	var full := bool(get_value("fullscreen"))
	var is_full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if full != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
