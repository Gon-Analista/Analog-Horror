class_name ModelShots
extends Node
## Dev: the Visita's 3D puppet in every pose, lit, without the tape, from
## the front and three-quarters, saved as screenshots, then quits:
##   godot --path game -- --model-shots <dir>


func run_shots(main: Node, dir: String) -> void:
	var level: Level = main.level
	var line := level.find_line(6)
	var start: Vector3i = line[0]
	var d: Vector2i = line[1]
	var fwd := Vector3(d.x, 0, d.y)
	for c in main.get_node("UILayer").get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	main.get_node("WorldView/World/PostLayer/PostFX").visible = false
	main.entity.visible = false
	main.player.visible = false
	var holder := Node3D.new()
	level.add_child(holder)
	holder.global_position = level.center(start) + fwd * 3.0
	var model := EntityModel.new()
	holder.add_child(model)
	var lamp := OmniLight3D.new()
	lamp.omni_range = 8.0
	lamp.light_energy = 2.2
	level.add_child(lamp)
	lamp.global_position = level.center(start) + fwd * 1.2 + Vector3.UP * 2.0
	var cam := Camera3D.new()
	cam.fov = 60.0
	level.add_child(cam)
	cam.current = true
	var poses := Entity.Pose.keys()
	for view in 2:
		var side := Vector3(-fwd.z, 0, fwd.x)
		var eye := level.center(start) + Vector3.UP * 1.5 + (side * 1.6 if view == 1 else Vector3.ZERO)
		cam.global_position = eye
		cam.look_at(holder.global_position + Vector3.UP * 1.3, Vector3.UP)
		for i in poses.size() + 1:
			var ceiling := i == poses.size()
			var p := Entity.Pose.STAND if ceiling else i
			var t := 0.0
			var to := eye - holder.global_position
			var yaw := atan2(-to.x, -to.z)
			while t < 0.6:
				var delta := get_process_delta_time()
				model.drive(delta, p, t * 2.0, yaw, eye, ceiling, Color(0.45, 0.43, 0.41), 1.0, p == Entity.Pose.RUN)
				await get_tree().process_frame
				t += delta
			await RenderingServer.frame_post_draw
			var name := "ceiling" if ceiling else String(poses[i]).to_lower()
			get_viewport().get_texture().get_image().save_png(dir.path_join("%d_%s.png" % [view, name]))
	get_tree().quit()
