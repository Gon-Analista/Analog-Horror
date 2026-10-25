class_name Controls
extends RefCounted
## Input actions, created at startup (not in project.godot) so a settings
## menu can remap them later from one list.

const KEYS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E],
	"flashlight": [KEY_F],
	"restart": [KEY_R],
	"debug_overlay": [KEY_F3],
	"fullscreen": [KEY_F11],
}
const MOUSE := {
	"film": MOUSE_BUTTON_RIGHT,
}


static func setup() -> void:
	for action: String in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action: String in MOUSE:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE[action]
		InputMap.action_add_event(action, mb)
