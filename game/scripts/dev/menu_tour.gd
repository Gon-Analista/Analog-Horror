class_name MenuTour
extends Node
## Dev: screenshots of the title screens (channel ident, warning, title
## with the focus on the first line, settings, credits), then quits:
##   godot --path game -- --menu-shots <absolute dir>


func run_tour(menu: Node, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var card := BootCard.new()
	menu.add_child(card)
	await _wait(1.2)
	await _shot(dir, "m1_ident")
	await _wait(2.6)
	await _shot(dir, "m2_warning")
	await card.done
	await _wait(0.4)
	menu._first_button.grab_focus()
	await _wait(0.6)
	await _shot(dir, "m3_title")
	menu._open_options()
	await _wait(0.3)
	await _shot(dir, "m4_options")
	menu._options.close()
	menu._open_credits()
	await _wait(0.3)
	await _shot(dir, "m5_credits")
	print("MENU SHOTS saved to ", dir)
	get_tree().quit()


func _shot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
