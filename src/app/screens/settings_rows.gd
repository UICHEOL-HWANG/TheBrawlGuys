class_name SettingsRows
extends RefCounted
## Row builders for the settings screen (design.md DS-CMP-07 Panel contents): a labelled
## volume slider with its percent, and a labelled switch. Spacing and colours come from DS
## tokens; the slider handle is big enough for a thumb.

const KNOB := 36
const KNOB_RIM := 5.0
const TRACK_HEIGHT := 14
## Wider than a portrait phone; ArenaSelectLayout's WidthFit shrinks the panel to the screen.
const SLIDER_MIN_WIDTH := 420


static func text(content: String, size: int, color: Color, font_path: String = DS.FONT_BODY_PATH) -> Label:
	var l := Label.new()
	l.text = content
	l.add_theme_font_override("font", load(font_path) as Font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A name on the left, its percent on the right, the slider below. Returns the row; the slider
## and the percent label come back in `out` under "slider" and "value".
static func slider_row(name: String, out: Dictionary) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S2)
	var head := HBoxContainer.new()
	var title := text(name, DS.SIZE_BODY, DS.UI_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := text("", DS.SIZE_BODY, DS.UI_TEXT_SOFT)
	head.add_child(title)
	head.add_child(value)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = UserVolume.FULL
	slider.step = UserVolume.STEP
	slider.custom_minimum_size = Vector2(SLIDER_MIN_WIDTH, DS.S7)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_slider(slider)
	row.add_child(head)
	row.add_child(slider)
	out["slider"] = slider
	out["value"] = value
	return row


static func style_slider(slider: HSlider) -> void:
	var track := _bar(DS.UI_SURFACE_DIM)
	var fill := _bar(DS.UI_ACCENT)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob()
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)
	slider.add_theme_icon_override("grabber_disabled", knob)


## A switch row: the name and a one-line caption on the left, the check button on the right.
static func toggle_row(name: String, caption: String, toggle: CheckButton) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S5)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(text(name, DS.SIZE_BODY, DS.UI_TEXT))
	var hint := text(caption, DS.SIZE_CAPTION, DS.UI_TEXT_SOFT, DS.FONT_CAPTION_PATH)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(hint)
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	row.add_child(toggle)
	return row


## One panel column: rows stacked DS.S5 apart, at least a slider wide (so wrapped captions keep
## a readable width).
static func column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S5)
	col.custom_minimum_size.x = SLIDER_MIN_WIDTH
	return col


## Keys and d-pad cross between columns: ↓ from `upper` lands on `lower`, ↑ from `lower` on `upper`.
static func link_down(upper: Control, lower: Control) -> void:
	upper.focus_neighbor_bottom = upper.get_path_to(lower)
	lower.focus_neighbor_top = lower.get_path_to(upper)
	upper.focus_next = upper.get_path_to(lower)
	lower.focus_previous = lower.get_path_to(upper)


static func _bar(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(DS.RADIUS_PILL)
	sb.content_margin_top = TRACK_HEIGHT / 2.0
	sb.content_margin_bottom = TRACK_HEIGHT / 2.0
	return sb


static func _knob() -> ImageTexture:
	var img := Image.create(KNOB, KNOB, false, Image.FORMAT_RGBA8)
	var c := (KNOB - 1) / 2.0
	for y: int in KNOB:
		for x: int in KNOB:
			var d := Vector2(x - c, y - c).length()
			var edge := clampf(c + 0.5 - d, 0.0, 1.0)
			var ring := clampf(d - (c - KNOB_RIM), 0.0, 1.0)  # a fire-coloured rim round a cream centre
			var col := DS.UI_SURFACE.lerp(DS.UI_ACCENT, ring)
			col.a = edge
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
