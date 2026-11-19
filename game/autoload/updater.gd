extends Node
## Updates inside the game, without the itch app and without downloading
## the whole game again. The FIRST autoload.
##
## A full build (the .exe and .pck on itch.io) is the "base": its version is
## application/config/version. A patch is a .pck holding everything that
## changed since the base (cumulative: only the newest is kept), published
## encrypted in a public GitHub repo next to a manifest.json. In _init(),
## before Godot loads the other autoloads, scenes and scripts, the installed
## patch (user://patches/) is mounted over the base, so its files replace
## the base's. In _ready() the manifest is fetched; if there is a newer patch
## for this base, a window offers it (download, check, decrypt, restart).
## If the manifest belongs to a newer base with no way across (no bridge),
## the window points to the itch page instead. No connection, no manifest:
## the game plays what is installed and says nothing.
##
## RULES (see .agents/dev_guidelines.md, «Actualizaciones»):
##  - This script never names a class of the game (class_name): that would
##    load it, and everything it depends on, from the base before the patch
##    is mounted, and the patch would silently stop applying code. Only
##    engine classes (FileAccess, OS, ProjectSettings, JSON...).
##  - It cannot be patched itself, nor can project.godot, the engine or the
##    DLLs: those need a full build.
##
## Off in the editor, on the web, and when the game is started with test
## arguments ("-- --smoke" and the like). "--update-url <url>" tries
## another manifest (and is the only argument that keeps it on);
## "--update-auto" (with it) accepts on its own (local tests).

const MANIFEST_URL := "https://raw.githubusercontent.com/Gon-Analista/lost-signal-updates/main/manifest.json"
## The key the patches are encrypted with (tools/encrypt_patch.gd reads it
## from here). Not real security, the game carries it: it only keeps the
## public repo from handing out the assets.
const PATCH_KEY := "v3yyHrxBtSPOWEo0dyt9WmGJfwEpZs3Ju515I2nCWQMPE7MV"
const DIR := "user://patches/"
const STATE := "user://patches/state.json"
const LOG := "user://patches/updater.log"
const WINDOW := "res://ui/update_window.gd"
const TIMEOUT := 8.0
const BROADCAST_EVERY := 300.0

## The base (the full build installed) and what is running on it.
var base := ""
var version := ""
var bridge_version := ""
var enabled := true
var url := MANIFEST_URL
var auto := false
var _state := {}
var _manifest := {}
var _window: Node = null
var _offer := {}
var _http: HTTPRequest
var _poll := 0.0
## The first look at the manifest is over (answer, none, or no connection):
## the boot screen waits for it a moment.
var checked := false
signal check_done


func _init() -> void:
	base = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	version = base
	var args := OS.get_cmdline_user_args()
	var i := args.find("--update-url")
	if i < 0:
		i = OS.get_cmdline_args().find("--update-url")
		if i >= 0:
			args = OS.get_cmdline_args()
	if i >= 0 and i + 1 < args.size():
		url = args[i + 1]
		auto = args.has("--update-auto")
	elif not OS.get_cmdline_user_args().is_empty():
		enabled = false  # (a test run)
	if OS.has_feature("editor") or OS.has_feature("web"):
		enabled = false
	if enabled:
		_mount()


## The installed patch (and the bridge under it), over the base.
func _mount() -> void:
	_state = _read_json(STATE)
	if _state.is_empty():
		return
	if str(_state.get("base", "")) != base:
		# A new full build was installed: the old patches are no use.
		_log("new base %s (was %s): old patches removed" % [base, _state.get("base", "")])
		_wipe()
		_state = {}
		return
	var bridge: Dictionary = _state.get("bridge", {})
	if not bridge.is_empty():
		if _load_pack(str(bridge.get("file", ""))):
			bridge_version = str(bridge.get("version", ""))
			version = bridge_version
		else:
			_state.erase("bridge")
	var file := str(_state.get("file", ""))
	if file != "":
		if _load_pack(file):
			version = str(_state.get("version", version))
		else:
			_log("patch %s missing or broken: playing without it" % file)
			_state.erase("file")
			_state.erase("version")
	_write_json(STATE, _state)
	_reload_translations()
	_log("base %s, running %s" % [base, version])


func _load_pack(file: String) -> bool:
	if file == "" or not FileAccess.file_exists(DIR + file):
		return false
	return ProjectSettings.load_resource_pack(DIR + file, true)


## The translations are loaded before any autoload: from the patch now
## (texts changed by it), in place of the base's.
func _reload_translations() -> void:
	var paths: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	for p in paths:
		var res := ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REPLACE)
		var tr_new := res as Translation
		if tr_new == null:
			continue
		var old := TranslationServer.get_translation_object(tr_new.locale)
		if old and old != tr_new:
			TranslationServer.remove_translation(old)
		TranslationServer.add_translation(tr_new)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not enabled:
		checked = true
		return
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_manifest)
	_fetch()


func _process(delta: float) -> void:
	if not enabled or _http == null:
		return
	_poll += delta
	if _poll >= BROADCAST_EVERY and _http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED and _window == null:
		_poll = 0.0
		_fetch()


func _fetch() -> void:
	var sep := "&" if url.contains("?") else "?"
	_http.request(url + sep + "t=%d" % Time.get_unix_time_from_system())  # (past the CDN's cache)


func _on_manifest(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not checked:
		checked = true
		check_done.emit()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		return
	_manifest = data
	if _window == null:
		_check()


## What the manifest offers this installation.
func _check() -> void:
	var m := _manifest
	var mbase := str(m.get("base", ""))
	var patch: Dictionary = m.get("patch", {}) if m.get("patch") is Dictionary else {}
	var offer := {}
	if mbase == base:
		offer = patch
	elif bridge_version != "" and bridge_version == mbase:
		offer = patch  # (on a bridge to that base: its patches go on top)
	elif version == mbase and str(_state.get("file", "")) != "":
		# Already at that base through a patch: it becomes the bridge, and
		# the new base's patches go on top of it.
		offer = patch
		offer = offer.duplicate()
		offer["as_bridge"] = true
	elif m.get("legacy") is Dictionary and (m.legacy as Dictionary).has(base):
		offer = (m.legacy as Dictionary)[base]
	if not offer.is_empty() and _newer(str(offer.get("version", "")), version):
		_offer = offer
		_open("update")
		return
	if _newer(mbase, version):
		_open("itch")
		return
	_broadcast()


func _broadcast() -> void:
	if _window:
		return
	var b = _manifest.get("broadcast")
	if not b is Dictionary or str(b.get("id", "")) == "":
		return
	if str(_state.get("seen", "")) == str(b.id):
		return
	_state["seen"] = str(b.id)
	_write_json(STATE, _state)
	_open("broadcast")


func _open(kind: String) -> void:
	if _window:
		_window.queue_free()
	_window = (load(WINDOW) as Script).new()
	get_tree().root.add_child.call_deferred(_window)
	await get_tree().process_frame
	_window.call("setup", self, kind)
	if kind == "update" and auto:
		accept()


## The window's word.
func decline() -> void:
	if _window:
		_window.queue_free()
		_window = null
	_broadcast()


func open_page() -> void:
	OS.shell_open(str(_manifest.get("page", "https://nearq.itch.io/lost-signal")))


# --- what the window shows ------------------------------------------------------

func offer_version() -> String:
	return str(_offer.get("version", ""))


func offer_size() -> int:
	return int(_offer.get("size", 0))


func manifest_base() -> String:
	return str(_manifest.get("base", ""))


func broadcast_text(es: bool) -> String:
	var b = _manifest.get("broadcast")
	if not b is Dictionary:
		return ""
	return str(b.get("es" if es else "en", b.get("es", "")))


## The notes newer than what is running (up to the offered version).
func notes() -> Array:
	var out := []
	var list = _manifest.get("notes", [])
	if not list is Array:
		return out
	var top := offer_version() if not _offer.is_empty() else manifest_base()
	for n in list:
		if n is Dictionary and _newer(str(n.get("version", "")), version) and not _newer(str(n.get("version", "")), top):
			out.append(n)
	return out


# --- installing -----------------------------------------------------------------

## Downloads (in parts if there are), checks, decrypts, installs, restarts.
func accept() -> void:
	var o := _offer
	var ver := str(o.get("version", ""))
	var parts: Array = o.get("parts", []) if o.get("parts") is Array and not (o.get("parts") as Array).is_empty() else [o.get("file", "")]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var bin := DIR + "download.bin"
	var out := FileAccess.open(bin, FileAccess.WRITE)
	if out == null:
		_fail("no se puede escribir en %s" % DIR)
		return
	var total := int(o.get("size", 0))
	var done := 0
	var root := url.get_base_dir() + "/"
	for i in parts.size():
		var part_path := DIR + "download.part"
		var got := await _download(root + str(parts[i]), part_path, done, total)
		if not got:
			out.close()
			_cleanup_download()
			_fail("download")
			return
		var pf := FileAccess.open(part_path, FileAccess.READ)
		while pf.get_position() < pf.get_length():
			out.store_buffer(pf.get_buffer(1 << 20))
		done += pf.get_length()
		pf.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(part_path))
	out.close()
	if _sha256(bin) != str(o.get("sha256", "")).to_lower():
		_cleanup_download()
		_fail("sha256")
		return
	if _window:
		_window.call("progress", 1.0, total, total, true)
	await get_tree().process_frame
	var pck := "patch_%s.pck" % ver
	var enc := FileAccess.open_encrypted_with_pass(bin, FileAccess.READ, PATCH_KEY)
	var dst := FileAccess.open(DIR + pck + ".tmp", FileAccess.WRITE)
	if enc == null or dst == null:
		_cleanup_download()
		_fail("decrypt")
		return
	while enc.get_position() < enc.get_length():
		dst.store_buffer(enc.get_buffer(1 << 20))
	enc.close()
	dst.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + pck))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(DIR + pck + ".tmp"), ProjectSettings.globalize_path(DIR + pck))
	_cleanup_download()
	# The new state; the files no longer used go.
	var old_file := str(_state.get("file", ""))
	var state := {"base": base, "version": ver, "file": pck}
	if o.get("as_bridge", false):
		state["bridge"] = {"version": str(_state.get("version", "")), "file": old_file}
	elif _state.get("bridge") is Dictionary and bridge_version != "" and bridge_version == manifest_base():
		state["bridge"] = _state.bridge
	if _state.has("seen"):
		state["seen"] = _state.seen
	_write_json(STATE, state)
	var keep := [pck, "state.json", "updater.log"]
	if state.get("bridge") is Dictionary:
		keep.append(str(state.bridge.get("file", "")))
	for f in DirAccess.get_files_at(DIR):
		if not keep.has(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
	_log("installed %s (from %s); restarting" % [ver, version])
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()


func _download(from: String, to: String, done: int, total: int) -> bool:
	var http := HTTPRequest.new()
	http.download_file = to
	http.use_threads = true
	add_child(http)
	if http.request(from) != OK:
		http.queue_free()
		return false
	var finished := [false, false]
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		finished[0] = true
		finished[1] = result == HTTPRequest.RESULT_SUCCESS and code == 200)
	while not finished[0]:
		if _window:
			var now := done + http.get_downloaded_bytes()
			_window.call("progress", float(now) / maxf(1.0, total), now, total, false)
		await get_tree().process_frame
	http.queue_free()
	return finished[1]


func _sha256(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		ctx.update(f.get_buffer(1 << 20))
	return ctx.finish().hex_encode()


func _cleanup_download() -> void:
	for f in ["download.bin", "download.part"]:
		if FileAccess.file_exists(DIR + f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))


func _fail(why: String) -> void:
	_log("update failed: %s" % why)
	if _window:
		_window.call("failed")


# --- small things -----------------------------------------------------------------

## "0.1.10" > "0.1.9": by number, part by part.
static func _newer(a: String, b: String) -> bool:
	if a == "":
		return false
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false


func _wipe() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(DIR)):
		return
	for f in DirAccess.get_files_at(DIR):
		if f != "updater.log":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func _log(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open(LOG, FileAccess.READ_WRITE if FileAccess.file_exists(LOG) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line("%s  %s" % [Time.get_datetime_string_from_system(), text])
