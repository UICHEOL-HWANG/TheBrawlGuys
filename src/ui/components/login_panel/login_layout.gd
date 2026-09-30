class_name LoginLayout
extends RefCounted
## The three LoginPanel layouts (design.md DS-CMP-14 🖼 candidates). Each takes the shared parts
## {logo, tagline, google, message, skip} and returns {root, mover, logo, items}: root fills the
## panel, mover is what the entrance slides (null = none), items are staggered in variant 3.

## Variant values mirror LoginPanel.Variant (CARD, SIDE, LOGO_DROP).
const CARD := 0
const SIDE := 1
const LOGO_DROP := 2
const SIDE_HEADING := "시작하기"


static func build(variant: int, parts: Dictionary) -> Dictionary:
	match variant:
		SIDE:
			return _side(parts)
		LOGO_DROP:
			return _logo_drop(parts)
	return _card(parts)


## ① Centered card: logo, tagline and buttons on one cream panel.
static func _card(parts: Dictionary) -> Dictionary:
	var root := _center()
	var card := UiPanel.new()
	card.custom_minimum_size.x = DS.PANEL_WIDTH
	root.add_child(card)
	var col := _column()
	card.add_child(col)
	_style_dark(parts["logo"], DS.SIZE_DISPLAY_L)
	_style_caption(parts["tagline"], false)
	_style_caption(parts["message"], false)
	_add_all(col, [parts["logo"], parts["tagline"], parts["google"], parts["message"], parts["skip"]])
	return {"root": root, "mover": card, "logo": parts["logo"], "items": [] as Array[Control]}


## ② Left vertical panel with the buttons, big outlined logo on the right.
static func _side(parts: Dictionary) -> Dictionary:
	var root := _full(Control.new())
	var side := UiPanel.new()
	side.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	side.offset_left = DS.S7
	side.offset_top = DS.S7
	side.offset_bottom = -DS.S7
	side.offset_right = DS.S7 + DS.SIDE_PANEL_WIDTH
	root.add_child(side)
	var col := _column()
	side.add_child(col)
	var heading := Label.new()
	heading.text = SIDE_HEADING
	_style_dark(heading, DS.SIZE_TITLE)
	_style_caption(parts["tagline"], false)
	_style_caption(parts["message"], false)
	_add_all(col, [heading, parts["tagline"], parts["google"], parts["message"], parts["skip"]])
	var right := CenterContainer.new()
	right.set_anchors_preset(Control.PRESET_FULL_RECT)
	right.offset_left = DS.S7 * 2 + DS.SIDE_PANEL_WIDTH
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
	style_world_text(parts["logo"], DS.SIZE_DISPLAY_XL)
	right.add_child(parts["logo"])
	return {"root": root, "mover": side, "logo": parts["logo"], "items": [] as Array[Control]}


## ③ Big outlined logo alone, buttons in a column under it (they stagger in after the drop).
static func _logo_drop(parts: Dictionary) -> Dictionary:
	var root := _center()
	var col := _column()
	root.add_child(col)
	style_world_text(parts["logo"], DS.SIZE_DISPLAY_XL)
	_style_caption(parts["tagline"], true)
	_style_caption(parts["message"], true)
	for key: String in ["google", "skip"]:
		(parts[key] as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for key: String in ["tagline", "message"]:
		(parts[key] as Control).custom_minimum_size.x = DS.PANEL_WIDTH  # wrapped labels need a width
	var items: Array[Control] = [parts["tagline"], parts["google"], parts["skip"], parts["message"]]
	_add_all(col, [parts["logo"], parts["tagline"], parts["google"], parts["skip"], parts["message"]])
	return {"root": root, "mover": null, "logo": parts["logo"], "items": items}


static func _center() -> CenterContainer:
	return _full(CenterContainer.new()) as CenterContainer


static func _full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func _column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", DS.S5)
	return col


static func _add_all(parent: Control, nodes: Array) -> void:
	for n: Control in nodes:
		parent.add_child(n)


static func _style_dark(l: Label, font_size: int) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", DS.UI_TEXT)


## World-overlay text (DS-TOK-02): cream fill, deep-teal outline, readable over the diorama.
static func style_world_text(l: Label, font_size: int) -> void:
	_style_dark(l, font_size)
	l.add_theme_color_override("font_color", DS.UI_SURFACE)
	l.add_theme_color_override("font_outline_color", DS.CANOPY_DEEP)
	l.add_theme_constant_override("outline_size", DS.LOGO_OUTLINE)


static func _style_caption(l: Label, over_world: bool) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", load(DS.FONT_CAPTION_PATH) as Font)
	l.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	l.add_theme_color_override("font_color", DS.UI_SURFACE if over_world else DS.UI_TEXT_SOFT)
	if over_world:
		l.add_theme_color_override("font_outline_color", DS.CANOPY_DEEP)
		l.add_theme_constant_override("outline_size", DS.TEXT_OUTLINE * 2)
