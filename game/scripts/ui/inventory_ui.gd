class_name InventoryUI
extends Control
## The toolbar and the inventory (I).
##   Toolbar: bottom centre, the left and the right hand (what each holds;
##   the camcorder's battery, the flashlight on or off). Minimal: it shows
##   when something changes or is used, or when the mouse wheel moves, and
##   fades away after a moment.
##   Inventory: Tab opens it (you can still walk; you cannot look around or
##   use things). The bag and both hands; drag anything onto any slot to
##   swap them (also the hands with each other). Tab or Esc closes it.

const SLOT := 22.0
const GAP := 4.0
const SHOW_TIME := 2.5
const BG := Color(0.02, 0.02, 0.02, 0.55)
const EDGE := Color(0.85, 0.85, 0.8, 0.35)
const TEXT := Color(0.9, 0.9, 0.84)
const DIM := Color(0.6, 0.6, 0.56)
const ACCENT := Color(1.0, 0.82, 0.3)

var _player: Player
var _run: Run
var _icons: Texture2D
var _show_left := 0.0
var _alpha := 0.0
var _panel: Control


## One square of the inventory: shows its item; drag it onto another to swap.
class Slot:
	extends Control
	var ui: InventoryUI
	var slot := ""

	func _ready() -> void:
		custom_minimum_size = Vector2(SLOT, SLOT) * 1.4
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var item := ui.inventory().get_slot(slot)
		var hover := get_global_rect().has_point(get_global_mouse_position())
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.05, 0.85))
		draw_rect(Rect2(Vector2.ZERO, size), ACCENT if hover else EDGE, false, 1.0)
		ui.draw_icon(self, item, Rect2(Vector2(3, 3), size - Vector2(6, 6)), 1.0)
		tooltip_text = Inventory.item_name(item)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _get_drag_data(_at: Vector2) -> Variant:
		var item := ui.inventory().get_slot(slot)
		if item == "":
			return null
		var preview := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = ui._icons
		atlas.region = Inventory.icon_region(item)
		preview.texture = atlas
		preview.size = Vector2(SLOT, SLOT) * 1.4
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_drag_preview(preview)
		return {"inv_slot": slot}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("inv_slot") and ui.inventory().can_swap(String(data.inv_slot), slot)

	func _drop_data(_at: Vector2, data: Variant) -> void:
		ui.inventory().swap(String(data.inv_slot), slot)
		Sfx.play(self, "click", -10.0)


func setup(player: Player, run: Run) -> void:
	_player = player
	_run = run
	_icons = load("res://assets/textures/items.png")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.used.connect(_poke)
	_build_panel()
	_poke()


func inventory() -> Inventory:
	return _player.inventory


func _poke() -> void:
	_show_left = SHOW_TIME


func draw_icon(canvas: CanvasItem, item: String, rect: Rect2, alpha: float) -> void:
	if _icons == null:
		return
	var tint := Color(1, 1, 1, alpha * (0.45 if item == "" else 1.0))
	canvas.draw_texture_rect_region(_icons, rect, Inventory.icon_region(item), tint)


func _input(event: InputEvent) -> void:
	if _player == null:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_poke()
	if event.is_action_pressed("inventory"):
		_toggle(not _panel.visible)
		get_viewport().set_input_as_handled()
	elif _panel.visible and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_toggle(false)
		get_viewport().set_input_as_handled()


func _toggle(on: bool) -> void:
	if on and (not _player.alive or _player.is_hidden() or not _player.input_enabled or _run.reading or get_tree().paused):
		return
	_panel.visible = on
	_player.ui_open = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	Sfx.play(self, "click", -10.0, 0.8 if on else 0.7)
	_poke()


func _process(delta: float) -> void:
	if _player == null:
		return
	if _panel.visible and (not _player.alive or get_tree().paused):
		_toggle(false)
	_show_left = maxf(0.0, _show_left - delta)
	var want := 1.0 if (_show_left > 0.0 or _panel.visible) and _player.alive and _player.input_enabled else 0.0
	_alpha = move_toward(_alpha, want, delta * (6.0 if want > _alpha else 1.5))
	queue_redraw()


## The toolbar: the two hands, bottom centre.
func _draw() -> void:
	if _player == null or _alpha <= 0.01 or _panel.visible:
		return
	var font := get_theme_default_font()
	var y := size.y - SLOT - 5.0
	var x0 := floorf(size.x * 0.5) - SLOT - GAP * 0.5
	for i in 2:
		var side: String = Inventory.HANDS[i]
		var item := inventory().get_slot(side)
		var r := Rect2(x0 + i * (SLOT + GAP), y, SLOT, SLOT)
		draw_rect(r, Color(BG.r, BG.g, BG.b, BG.a * _alpha))
		draw_rect(r, Color(EDGE.r, EDGE.g, EDGE.b, EDGE.a * _alpha), false, 1.0)
		draw_icon(self, item, r.grow(-2.0), _alpha)
		if item == "camcorder":  # its battery, under it
			var b := clampf(_player.camcorder.battery / 100.0, 0.0, 1.0)
			var col := Color(0.4, 0.9, 0.45) if b > 0.25 else Color(1.0, 0.35, 0.25)
			draw_rect(Rect2(r.position.x + 2, r.end.y - 3, (SLOT - 4) * b, 2), Color(col.r, col.g, col.b, _alpha))
		elif item == "flashlight" and _player.light_on:
			draw_circle(r.position + Vector2(SLOT - 4, 4), 1.5, Color(1.0, 0.9, 0.5, _alpha))
	var spare := inventory().count("battery")
	if spare > 0:  # the spares in the bag, beside the hands
		var bx := x0 + 2.0 * (SLOT + GAP) + 1.0
		draw_icon(self, "battery", Rect2(bx, y + 3.0, SLOT - 6.0, SLOT - 6.0), _alpha)
		draw_string(font, Vector2(bx + SLOT - 5.0, y + SLOT - 4.0), "x%d" % spare, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(DIM.r, DIM.g, DIM.b, _alpha))
	draw_string(font, Vector2(x0 - 1, y - 2), tr("TAB · inventario"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(DIM.r, DIM.g, DIM.b, 0.7 * _alpha))


func _build_panel() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # clicks outside do not reach the game
	_panel.visible = false
	add_child(_panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(shade)
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.03, 0.92)
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	box.add_theme_stylebox_override("panel", style)
	_panel.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	box.add_child(col)
	col.add_child(_label(tr("INVENTARIO"), 14, ACCENT))
	var grid := GridContainer.new()
	grid.columns = Inventory.BAG_SIZE / 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for i in Inventory.BAG_SIZE:
		grid.add_child(_slot("bag%d" % i))
	col.add_child(grid)
	col.add_child(_label(tr("EN LAS MANOS"), 10, DIM))
	var hands := HBoxContainer.new()
	hands.add_theme_constant_override("separation", 10)
	for side: String in Inventory.HANDS:
		var v := VBoxContainer.new()
		v.add_child(_slot(side))
		v.add_child(_label(tr("IZQUIERDA") if side == "left" else tr("DERECHA"), 8, DIM))
		hands.add_child(v)
	col.add_child(hands)
	col.add_child(_label(tr("Arrastra para cambiar · TAB: cerrar"), 8, DIM))
	box.reset_size()
	box.position = ((Vector2(480, 270) - box.get_combined_minimum_size()) * 0.5).floor()


func _slot(id: String) -> Slot:
	var s := Slot.new()
	s.ui = self
	s.slot = id
	return s


func _label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l
