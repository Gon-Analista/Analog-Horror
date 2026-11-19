extends CanvasLayer
## Scene transitions (autoload `Transition`): the picture tears into static
## and cuts to black, the mix fades with it, then the next scene comes back
## the same way. Above every other layer and running through pauses.

const COVER_TIME := 0.45
const REVEAL_TIME := 0.7

var _rect: ColorRect
var _mat: ShaderMaterial
var _hiss: AudioStreamPlayer
var _tween: Tween
var busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/tape_cut.gdshader")
	_rect.material = _mat
	add_child(_rect)
	_hiss = AudioStreamPlayer.new()
	_hiss.stream = Sfx.get_stream("static", true)
	_hiss.volume_db = -60.0  # Master: the game's mix fades under it
	add_child(_hiss)
	_set_amount(0.0)


## Fades to black through static. Await it.
func cover(time := COVER_TIME) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_hiss.play()
	await _animate(1.0, time, 0.0)


## Comes back from black. Await it if needed.
func reveal(time := REVEAL_TIME) -> void:
	await _animate(0.0, time, 1.0)
	_hiss.stop()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Covers, changes scene, reveals the new one.
func change_scene(path: String) -> void:
	if busy:
		return
	busy = true
	await cover()
	await swap_and_reveal(path)


## Changes scene under the cover (call after cover()) and reveals it.
func swap_and_reveal(path: String) -> void:
	busy = true
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	busy = false
	reveal()


## Changes scene at once (a networked start: every machine must load now)
## and reveals it from black.
func cut_to(path: String) -> void:
	_set_amount(1.0)
	Settings.set_fade(0.0)
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	reveal()


func _animate(target: float, time: float, mix_target: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_method(_set_amount, float(_mat.get_shader_parameter("amount")), target, time)
	_tween.tween_method(Settings.set_fade, Settings.get_fade(), mix_target, time)
	_tween.tween_property(_hiss, "volume_db", -22.0 if target > 0.5 else -60.0, time)
	await _tween.finished


func _set_amount(a: float) -> void:
	_mat.set_shader_parameter("amount", a)
	_rect.visible = a > 0.001
