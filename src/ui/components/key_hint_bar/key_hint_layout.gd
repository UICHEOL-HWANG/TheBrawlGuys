class_name KeyHintLayout
extends RefCounted
## Building blocks of the KeyHintBar (design.md DS-CMP-16): the translucent strip, cap rows,
## cap groups with a caption under them and the player tag of local 2-player bars.

const CAP_GAP := DS.S1


## Caps in a centered row (the arrow cluster's rows).
static func cap_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", CAP_GAP)
	return row


## Inverted-T arrow cluster: up on top, left · down · right below.
static func arrow_stack(top: Array[Control], bottom: Array[Control]) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", CAP_GAP)
	for part: Array[Control] in [top, bottom]:
		var row := cap_row()
		for c: Control in part:
			row.add_child(c)
		stack.add_child(row)
	return stack


## Parts stacked over a caption (bottom-aligned so every caption sits on one line).
static func group(parts: Array, caption_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", DS.S1)
	for p: Control in parts:
		p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(p)
	box.add_child(caption(caption_text))
	return box


static func caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(DS.FONT_CAPTION_PATH) as Font)
	l.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	l.add_theme_color_override("font_color", DS.UI_TEXT)
	return l


## "P1" / "P2" in the player's color (DS-VIS-03: color + number), vertically centered.
static func tag(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	l.add_theme_font_size_override("font_size", DS.SIZE_BODY)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", DS.UI_SURFACE)
	l.add_theme_constant_override("outline_size", DS.TEXT_OUTLINE)
	return l


## compact (two bars on a narrow screen): s3 side padding instead of s5.
static func panel_box(compact: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DS.UI_SURFACE_50
	sb.set_corner_radius_all(DS.RADIUS_L)
	sb.content_margin_left = DS.S3 if compact else DS.S5
	sb.content_margin_right = DS.S3 if compact else DS.S5
	sb.content_margin_top = DS.S3
	sb.content_margin_bottom = DS.S2
	return sb
