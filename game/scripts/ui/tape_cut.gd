class_name TapeCut
extends CanvasLayer
## Scene changes as a cut in the tape: the new scene comes up out of black
## through bands of static, with a short hiss. It is laid on the root (not on
## a scene), so it outlives the change; it frees itself when clear. Pure local
## presentation: the networked start still loads on every machine at once.
## (Not an autoload: project.godot cannot travel in a patch.)

const LAYER := 100
const TIME := 0.8

var _mat: ShaderMaterial
var _rect: ColorRect


## Cover the screen now and clear it over the next scene. Call it next to a
## change_scene_* call (before or after: it covers at once).
static func play(tree: SceneTree, time := TIME) -> void:
	if tree == null or DisplayServer.get_name() == "headless":
		return
	var old := tree.root.get_node_or_null("TapeCut")
	if old:
		old.free()
	var cut := TapeCut.new()
	cut.name = "TapeCut"
	tree.root.add_child.call_deferred(cut)
	cut._run.call_deferred(time)


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/tape_cut.gdshader")
	_mat.set_shader_parameter("amount", 1.0)
	_rect.material = _mat
	add_child(_rect)


func _run(time: float) -> void:
	_mat.set_shader_parameter("calm", Settings.flash_scale())
	var hiss := AudioStreamPlayer.new()
	hiss.stream = Sfx.get_stream("static")
	hiss.bus = "Effects"
	hiss.volume_db = -20.0 if not Settings.reduce_flashes else -28.0
	add_child(hiss)
	hiss.play()
	# Held a moment on black while the new scene builds, then it clears.
	await get_tree().create_timer(0.12, true, false, true).timeout
	var tw := create_tween().set_parallel()
	tw.tween_method(func(a: float) -> void: _mat.set_shader_parameter("amount", a), 1.0, 0.0, time)
	tw.tween_property(hiss, "volume_db", -60.0, time)
	await tw.finished
	queue_free()
