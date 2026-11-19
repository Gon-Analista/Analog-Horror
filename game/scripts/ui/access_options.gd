class_name AccessOptions
extends RefCounted
## The controls and accessibility rows shared by the main menu's options and
## the pause menu: mouse sensitivity, the inverted vertical axis and fewer
## flashes (saved by Settings). Each menu passes its own way of making a
## button, a label and a slider, so the rows look like the rest of it.


## Adds the rows to `box`. `button(text, action) -> Button`,
## `label(text) -> Label`, `slider(slider)` styles a slider.
static func add_rows(box: Container, button: Callable, label: Callable, style_slider: Callable) -> void:
	var row := HBoxContainer.new()
	var name_label: Label = label.call("  " + TranslationServer.translate("SENSIBILIDAD"))  # (lined up with the buttons' "  ")
	name_label.custom_minimum_size = Vector2(82, 0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = Settings.SENS_MIN
	slider.max_value = Settings.SENS_MAX
	slider.step = 0.05
	slider.value = Settings.mouse_sens
	slider.custom_minimum_size = Vector2(110, 12)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	style_slider.call(slider)
	var value: Label = label.call(" x%.2f" % Settings.mouse_sens)
	slider.value_changed.connect(func(v: float) -> void:
		Settings.set_mouse_sens(v)
		value.text = " x%.2f" % Settings.mouse_sens)
	row.add_child(slider)
	row.add_child(value)
	box.add_child(row)
	var invert: Button = button.call(invert_label(), func() -> void: pass)
	invert.pressed.connect(func() -> void:
		Settings.set_invert_y(not Settings.invert_y)
		invert.text = invert.text.left(2) + invert_label())
	box.add_child(invert)
	var flashes: Button = button.call(flashes_label(), func() -> void: pass)
	flashes.pressed.connect(func() -> void:
		Settings.set_reduce_flashes(not Settings.reduce_flashes)
		flashes.text = flashes.text.left(2) + flashes_label())
	flashes.tooltip_text = TranslationServer.translate("Menos ruido de imagen, destellos y cortes de color (fotosensibilidad)")
	box.add_child(flashes)


static func invert_label() -> String:
	return TranslationServer.translate("EJE Y: INVERTIDO") if Settings.invert_y else TranslationServer.translate("EJE Y: NORMAL")


static func flashes_label() -> String:
	return TranslationServer.translate("MENOS DESTELLOS: SÍ") if Settings.reduce_flashes else TranslationServer.translate("MENOS DESTELLOS: NO")


## The first button that can take the keyboard in `box` (visible), or null.
static func first_focus(box: Control) -> Control:
	for c in box.find_children("*", "", true, false):
		var control := c as Control
		if control and control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL and (control is Button or control is Slider):
			return control
	return null


## The menus' slider: a thin track, the filled part in the accent colour and
## a small square knob that lights up when picked (mouse or keyboard).
static func style_slider(slider: HSlider, text: Color, accent: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.25, 0.25, 0.24)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var img := Image.create(6, 10, false, Image.FORMAT_RGBA8)
	img.fill(text)
	slider.add_theme_icon_override("grabber", ImageTexture.create_from_image(img))
	var lit := Image.create(6, 10, false, Image.FORMAT_RGBA8)
	lit.fill(accent)
	slider.add_theme_icon_override("grabber_highlight", ImageTexture.create_from_image(lit))
	slider.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Buttons without their top and bottom margins: more rows fit.
static func tighten(box: Control) -> void:
	var tight := StyleBoxEmpty.new()
	tight.content_margin_top = 0
	tight.content_margin_bottom = 0
	for b in box.find_children("*", "Button", true, false):
		for state in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
			(b as Button).add_theme_stylebox_override(state, tight)
