class_name ShotTour
extends Node
## Dev: a fixed camera tour that saves screenshots (at the internal 480x270)
## and quits, to review the look without playing:
##   godot --path game -- --shots <absolute dir>


func run_tour(main: Node, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var player: Player = main.player
	var entity: Entity = main.entity
	entity.set_physics_process(false)
	await _wait(1.5)

	await _pose_shot(player, Vector2(15.5, 11.5), PI / 2, 0.0, dir, "01_hallway")
	await _pose_shot(player, Vector2(11.5, 2.2), PI, -0.25, dir, "02_living_tv")
	await _pose_shot(player, Vector2(3.5, 2.2), PI * 0.85, -0.2, dir, "03_kitchen")

	# The entity 4 m ahead in the hallway: naked eye, then through the camcorder.
	entity.state = Entity.State.STALKING
	entity.global_position = Vector3(10.5, 0, 11.5)
	entity.look_at(Vector3(6.5, 0, 11.5), Vector3.UP)
	await _pose_shot(player, Vector2(6.5, 11.5), -PI / 2, 0.05, dir, "04_naked_eye")
	player.camcorder.force_held = true
	await _wait(0.8)
	await _shot(dir, "05_camcorder")
	entity.global_position = Vector3(8.0, 0, 11.5)
	entity.look_at(Vector3(6.5, 0, 11.5), Vector3.UP)
	await _wait(0.4)
	await _shot(dir, "06_camcorder_close")
	print("PERF fps=%d draw_calls=%d objects=%d vram=%.0fMB" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	print("SHOTS saved to ", dir)
	get_tree().quit()


func _pose_shot(player: Player, at: Vector2, yaw: float, pitch: float, dir: String, shot_name: String) -> void:
	player.global_position = Vector3(at.x, 0.0, at.y)
	player.set_view(yaw, pitch)
	await _wait(0.7)
	await _shot(dir, shot_name)


func _shot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(shot_name + ".png"))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
