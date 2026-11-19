extends SceneTree
## Encrypts a patch .pck for publishing (tools/release.py runs it headless):
##   godot --headless --script tools/encrypt_patch.gd -- in.pck out.bin game/autoload/updater.gd
## The key is read from updater.gd (PATCH_KEY), so there is one place for it;
## the game decrypts with FileAccess.open_encrypted_with_pass and the same key.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("usage: -- in.pck out.bin updater.gd")
		quit(2)
		return
	var source := FileAccess.get_file_as_string(args[2])
	var re := RegEx.new()
	re.compile("PATCH_KEY\\s*:?=\\s*\"([^\"]+)\"")
	var m := re.search(source)
	if m == null:
		printerr("PATCH_KEY not found in %s" % args[2])
		quit(3)
		return
	var src := FileAccess.open(args[0], FileAccess.READ)
	var dst := FileAccess.open_encrypted_with_pass(args[1], FileAccess.WRITE, m.get_string(1))
	if src == null or dst == null:
		printerr("cannot open %s or %s" % [args[0], args[1]])
		quit(4)
		return
	while src.get_position() < src.get_length():
		dst.store_buffer(src.get_buffer(1 << 20))
	dst.close()
	print("ENCRYPTED %s -> %s" % [args[0], args[1]])
	quit(0)
