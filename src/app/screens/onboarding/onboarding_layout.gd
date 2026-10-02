class_name OnboardingLayout
extends RefCounted
## Shared layout of the onboarding screens (design.md DS-LAY-03 온보딩): the title on top, one
## UiPanel centered, 뒤로 bottom left and the key hint bottom right (ArenaSelectLayout). Inside the
## panel one column as wide as the login card's content (buttons and fields stretch to it), so
## every line shares the same left and right edge; GROUP_GAP between groups, ITEM_GAP inside a group
## (a button and the caption under its shadow, a field and its helper). Spacing from DS tokens only.
## Copy is written to fit one or two whole lines at this width (no orphan syllables).

const CONTENT_WIDTH := DS.LOGIN_CARD_WIDTH - DS.S6 * 2
const GROUP_GAP := DS.S5
const ITEM_GAP := DS.S3
const BACK_TEXT := "뒤로"
const BACKDROP_FOCUS := Vector2(0.0, 0.42)
const PANEL_POP_FROM := 0.9


## Builds the screen on root; back null leaves the bottom left empty. Returns the footer margin.
static func build(root: Control, title: String, groups: Array[Control], back: Control, hint: String) -> MarginContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := UiPanel.new()
	var col := _column(GROUP_GAP)
	for g: Control in groups:
		col.add_child(g)
	panel.add_child(col)
	var left := back
	if left == null:  # an empty slot as tall as 뒤로, so the hint sits where it does on every screen
		left = Control.new()
		left.custom_minimum_size.y = DS.BUTTON_HEIGHT
		left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var footer := ArenaSelectLayout.build(root, title, panel, left, ArenaSelectLayout.hint_label(hint))
	ArenaSelectLayout.apply_safe_area(footer, root.get_viewport())
	root.get_viewport().size_changed.connect(func() -> void:
		ArenaSelectLayout.apply_safe_area(footer, root.get_viewport()))
	# pops from its center once the container has sized it (never fires if the screen is gone)
	panel.resized.connect(func() -> void: UiMotion.pop_in(panel, PANEL_POP_FROM), CONNECT_ONE_SHOT)
	return footer


## Items stacked ITEM_GAP apart (a button over its caption).
static func group(items: Array[Control]) -> VBoxContainer:
	var g := _column(ITEM_GAP)
	for c: Control in items:
		g.add_child(c)
	return g


## Centered body text, wrapping at the column width.
static func body(text: String) -> Label:
	return _label(text, DS.FONT_BODY_PATH, DS.SIZE_BODY, DS.UI_TEXT)


## Centered small soft text (captions, helpers).
static func caption(text: String) -> Label:
	return _label(text, DS.FONT_CAPTION_PATH, DS.SIZE_CAPTION, DS.UI_TEXT_SOFT)


static func button(text: String, primary: bool) -> UiMenuButton:
	var b := UiMenuButton.new()
	b.text = text
	b.kind = UiMenuButton.Kind.PRIMARY if primary else UiMenuButton.Kind.SECONDARY
	return b


static func _column(gap: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = CONTENT_WIDTH
	col.add_theme_constant_override("separation", gap)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return col


static func _label(text: String, font_path: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = CONTENT_WIDTH
	l.add_theme_font_override("font", load(font_path) as Font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
