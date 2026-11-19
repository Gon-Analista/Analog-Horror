extends Node
## Dev: graphics benchmark. Loads a house, looks across a room of each kind
## (and one through the camcorder), and prints the average frame time and
## the GPU time of the 3D view at each spot, then quits. Run it before and
## after any visual change (dev_guidelines §9):
##   godot --path game res://scenes/dev/bench.tscn -- --seed 1 [--graphics low|high] [--frames N] [--bench-shots <dir>]
## --graphics is for this run only (not saved); --bench-shots also saves a
## screenshot of each spot.

const MAIN := preload("res://scenes/main.tscn")
## Room type, through the camcorder.
const SPOTS := [["hall", false], ["living", false], ["kitchen", false], ["kid", false], ["bedroom", false], ["hall", true]]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var frames := _arg(args, "--frames", "120").to_int()
	var shots := _arg(args, "--bench-shots", "")
	var gfx := _arg(args, "--graphics", "")
	if gfx == "low" or gfx == "high":
		Settings.graphics = gfx
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main := MAIN.instantiate()
	add_child(main)
	var player: Player = main.player
	var level: Level = main.level
	main.entity.set_physics_process(false)
	main.screens.visible = false  # the intro card would cover the screenshots
	var rid: RID = main.world.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	await _frames(30)
	print("BENCH graphics=%s (%s) gpu=%s" % [Settings.graphics, main.world.size, RenderingServer.get_video_adapter_name()])
	var total_frame := 0.0
	var total_gpu := 0.0
	var n := 0
	for spot: Array in SPOTS:
		if not _look_across(player, level, spot[0]):
			continue
		player.camcorder.force_held = spot[1]
		await _frames(20)
		var label: String = spot[0] + (" (visor)" if spot[1] else "")
		var t0 := Time.get_ticks_usec()
		var gpu := 0.0
		var calls := 0.0
		for f in frames:
			await RenderingServer.frame_post_draw
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var frame_ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
		gpu /= frames
		total_frame += frame_ms
		total_gpu += gpu
		n += 1
		print("BENCH %-15s frame %7.2f ms (%5.1f fps)  gpu3d %7.2f ms  draw calls %d" % [
				label, frame_ms, 1000.0 / frame_ms, gpu, int(calls / frames)])
		if shots != "":
			get_viewport().get_texture().get_image().save_png(shots.path_join("%d_%s.png" % [n, label.replace(" ", "_")]))
	if n > 0:
		print("BENCH media           frame %7.2f ms (%5.1f fps)  gpu3d %7.2f ms" % [
				total_frame / n, 1000.0 * n / total_frame, total_gpu / n])
	get_tree().quit()


## Stands in the walkable cell of the first room of `type` farthest from its
## middle and looks at the middle (as the screenshot tour does).
func _look_across(player: Player, level: Level, type: String) -> bool:
	for r: Dictionary in level.layout.rooms:
		if r.type != type:
			continue
		var rect: Rect2i = r.rect
		var f: int = r.floor
		var mid := Vector3(rect.position.x + rect.size.x * 0.5, f * Level.FLOOR_H + 0.9, rect.position.y + rect.size.y * 0.5)
		var best := Vector3i(-1, -1, -1)
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c := Vector3i(x, f, z)
				if level.is_walkable(c) and (best.x < 0 or level.center(c).distance_to(mid) > level.center(best).distance_to(mid)):
					best = c
		if best.x < 0:
			return false
		var to := mid - (level.center(best) + Vector3.UP * 1.6)
		player.global_position = level.center(best)
		player.set_view(atan2(-to.x, -to.z), clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.8, 0.8))
		return true
	return false


func _arg(args: PackedStringArray, key: String, default: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else default


func _frames(count: int) -> void:
	for k in count:
		await get_tree().process_frame
