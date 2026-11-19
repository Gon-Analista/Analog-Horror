class_name UiKit
extends RefCounted
## Shared look of the pure-UI screens (menu, pause, options, credits):
## printed material of the time. Cream type on black, a mustard accent, a
## thin rule and a bar that marks the focused line. Every control is built
## here so the screens stay consistent and keyboard navigable.
## Sizes are in base 480x270 coordinates (the UI is scaled by an integer).

const TEXT := Color(0.9, 0.9, 0.84)
const DIM := Color(0.6, 0.6, 0.58)
const ACCENT := Color(1.0, 0.82, 0.3)
const ALERT := Color(1.0, 0.55, 0.45)
const PANEL_BG := Color(0.02, 0.02, 0.03, 0.92)
const OUTLINE := Color(0, 0, 0, 0.85)
const FONT := 13
const FONT_SMALL := 11
const FONT_TITLE := 26


static func label(text: String, size_px := FONT, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	return l


## A menu line: "  TEXT" at rest, "> TEXT" in the accent with a faint bar
## when hovered or focused (the mouse focuses it too, so both agree).
static func button(text: String, action: Callable, size_px := FONT) -> Button:
	var b := Button.new()
	b.set_meta("label", text)
	b.text = "  " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", size_px)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_focus_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.5))
	b.add_theme_color_override("font_outline_color", OUTLINE)
	b.add_theme_constant_override("outline_size", 4)
	var none := StyleBoxEmpty.new()
	none.set_content_margin_all(1)
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(ACCENT, 0.1)
	bar.border_color = ACCENT
	bar.border_width_left = 2
	bar.set_content_margin_all(1)
	for state in ["normal", "disabled"]:
		b.add_theme_stylebox_override(state, none)
	for state in ["hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, bar)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(func() -> void:
		b.text = "> " + String(b.get_meta("label"))
		Sfx.play(b, "click", -22.0, 1.7))
	b.focus_exited.connect(func() -> void: b.text = "  " + String(b.get_meta("label")))
	b.pressed.connect(func() -> void:
		Sfx.play(b, "click", -4.0)
		action.call())
	return b


## Changes a UiKit button's text, keeping its focus marker.
static func set_button_text(b: Button, text: String) -> void:
	b.set_meta("label", text)
	b.text = ("> " if b.has_focus() else "  ") + text


static func edit(text: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.max_length = max_len
	e.add_theme_font_size_override("font_size", FONT)
	e.add_theme_color_override("font_placeholder_color", Color(DIM, 0.6))
	e.add_theme_color_override("caret_color", ACCENT)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.55)
	box.border_color = Color(DIM, 0.8)
	box.set_border_width_all(1)
	box.set_content_margin_all(2)
	var focus := box.duplicate() as StyleBoxFlat
	focus.border_color = ACCENT
	e.add_theme_stylebox_override("normal", box)
	e.add_theme_stylebox_override("focus", focus)
	e.add_theme_stylebox_override("read_only", box)
	return e


## A tape-counter style slider: a thin track, a solid notch.
static func slider(min_v: float, max_v: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.focus_mode = Control.FOCUS_ALL
	s.custom_minimum_size = Vector2(110, 10)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(DIM, 0.35)
	track.content_margin_top = 1
	track.content_margin_bottom = 1
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(TEXT, 0.8)
	fill.content_margin_top = 1
	fill.content_margin_bottom = 1
	var fill_hi := fill.duplicate() as StyleBoxFlat
	fill_hi.bg_color = ACCENT
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill_hi)
	s.add_theme_icon_override("grabber", _notch(TEXT))
	s.add_theme_icon_override("grabber_highlight", _notch(ACCENT))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(ACCENT, 0.5)
	focus.set_border_width_all(1)
	s.add_theme_stylebox_override("focus", focus)
	return s


static func rule(width: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(DIM, 0.45)
	r.custom_minimum_size = Vector2(width, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func panel_style(margin := 14.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.border_color = Color(DIM, 0.5)
	s.set_border_width_all(1)
	s.set_content_margin_all(margin)
	return s


static func _notch(color: Color) -> ImageTexture:
	var img := Image.create(4, 10, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
