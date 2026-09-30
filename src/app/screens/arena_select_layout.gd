class_name ArenaSelectLayout
extends RefCounted
## Arena select layout (Phase 4 T7, design.md DS-LAY-02/03): the title on top, the card row
## centered on screen, and a footer inside the safe area with 뒤로 at the bottom left and the key
## hint at the bottom right. Containers only, spacing from DS tokens, so it follows UI scaling.


## Adds the title, the centered cards and the footer to root; returns the footer margin
## (apply_safe_area keeps it clear of notches and gesture bars).
static func build(root: Control, title: String, cards: Control, back: Control, hint: Control) -> MarginContainer:
	var head := VBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_gap(DS.S6))
	head.add_child(LoginLayout.title_label(title))
	root.add_child(head)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(cards)
	root.add_child(center)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
	row.add_child(hint)
	margin.add_child(row)
	root.add_child(margin)
	return margin


## Footer margins: s6 inside the device safe area on the left, right and bottom.
static func apply_safe_area(margin: MarginContainer, viewport: Viewport) -> void:
	var vp := viewport.get_visible_rect()
	var safe := SafeArea.rect(viewport)
	margin.add_theme_constant_override("margin_left", int(safe.position.x - vp.position.x) + DS.S6)
	margin.add_theme_constant_override("margin_right", int(vp.end.x - safe.end.x) + DS.S6)
	margin.add_theme_constant_override("margin_bottom", int(vp.end.y - safe.end.y) + DS.S6)


## A secondary 뒤로 that keys skip (they move between cards; X / Esc goes back).
static func back_button(text: String) -> UiMenuButton:
	var b := UiMenuButton.new()
	b.text = text
	b.kind = UiMenuButton.Kind.SECONDARY
	b.focus_mode = Control.FOCUS_NONE
	return b


static func hint_label(text: String) -> Label:
	var hint := Label.new()
	hint.text = text
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", load(DS.FONT_CAPTION_PATH) as Font)
	hint.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	hint.add_theme_color_override("font_color", DS.UI_TEXT)  # dark on the light menu haze
	return hint


static func _gap(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap
