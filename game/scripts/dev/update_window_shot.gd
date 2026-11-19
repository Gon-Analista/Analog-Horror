extends SceneTree
## Dev: pictures of the updater's window (each kind) over the menu, with a
## made-up offer, then quits:
##   godot --path game --script res://scripts/dev/update_window_shot.gd -- <dir>


class FakeUpdater:
	extends Node
	var version := "0.4.0"
	func offer_version() -> String: return "0.4.2"
	func offer_size() -> int: return 3800000
	func manifest_base() -> String: return "0.5.0"
	func broadcast_text(es: bool) -> String:
		return "Esta noche, a las 22:00, prueba abierta del modo Visita. ¡Venid todos!" if es else "Tonight at 22:00: open test of the Visitor mode. Come along!"
	func notes() -> Array:
		return [{"version": "0.4.2", "items": [
			{"t": "new", "es": "La Visita ahora tiene dos brazos más.", "en": "The Visitor has two more arms."},
			{"t": "up", "es": "El grito al perseguirte es más grave.", "en": "Its chase scream is deeper."},
			{"t": "fix", "es": "Ya no reaparece encima de ti tras el flash.", "en": "It no longer reappears on top of you after the flash."}]},
			{"version": "0.4.1", "items": [{"t": "fix", "es": "El ratón vuelve tras Alt+Tab.", "en": "The mouse comes back after Alt+Tab."}]}]
	func accept() -> void: pass
	func decline() -> void: pass
	func open_page() -> void: pass


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	var menu := (load("res://scenes/menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	var fake := FakeUpdater.new()
	root.add_child(fake)
	for kind in ["update", "progress", "itch", "broadcast"]:
		var w: Node = (load("res://ui/update_window.gd") as Script).new()
		root.add_child(w)
		w.call("setup", fake, "update" if kind == "progress" else kind)
		if kind == "progress":
			w.call("_accept")
			w.call("progress", 0.42, 1600000, 3800000, false)
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("window_%s.png" % kind))
		w.queue_free()
		await process_frame
	quit()
