class_name LoginLayout
extends RefCounted
## LoginPanel layout (design.md DS-CMP-14, decided 2026-09-30 after the calm-forest reference):
## one frosted GlassCard centered on screen holding, top to bottom, the leaf emblem, the big
## white title, a letter-spaced tagline, the white Google pill, the status message, a helper
## line, the language link and (debug only) a skip link. Returns
## {root, card, parts: {name: Control}, items: stagger order, focus}; focus is the screen point
## (NDC, x right / y up) left free for the backdrop fight, beside the card.

const FOCUS := Vector2(0.58, -0.3)
const TITLE_SHADOW_OFFSET := Vector2(0, 3)
const CAPTION_SHADOW_OFFSET := Vector2(0, 1)


static func build() -> Dictionary:
	var root := CenterContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := GlassCard.new()
	card.custom_minimum_size.x = DS.LOGIN_CARD_WIDTH
	root.add_child(card)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", DS.S4)
	card.add_child(col)
	var parts := _parts()
	for key: String in ["emblem", "title", "tagline", "gap", "google", "message", "helper", "language", "skip"]:
		col.add_child(parts[key] as Control)
	var items: Array[Control] = []
	for key: String in ["emblem", "title", "tagline", "google", "message", "helper", "language", "skip"]:
		items.append(parts[key] as Control)
	return {"root": root, "card": card, "parts": parts, "items": items, "focus": FOCUS}


static func _parts() -> Dictionary:
	var google := GoogleButton.new()
	google.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var language := HBoxContainer.new()
	language.alignment = BoxContainer.ALIGNMENT_CENTER
	language.add_theme_constant_override("separation", DS.S2)
	language.add_child(LoginIcon.new(LoginIcon.Icon.GLOBE, DS.S5))
	var language_link := _link()
	language.add_child(language_link)
	var gap := Control.new()
	gap.custom_minimum_size.y = DS.S3
	var emblem := LoginIcon.new(LoginIcon.Icon.LEAF, DS.S8)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return {
		"emblem": emblem, "title": title_label(LoginText.TITLE), "tagline": _caption(true),
		"gap": gap, "google": google, "message": _caption(false), "helper": _caption(false),
		"language": language, "language_link": language_link, "skip": _link(),
	}


## Big white title with a soft shadow (also used by the title screen).
static func title_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(DS.FONT_DISPLAY_PATH) as Font)
	l.add_theme_font_size_override("font_size", DS.SIZE_DISPLAY_L)
	_white_with_shadow(l, TITLE_SHADOW_OFFSET, DS.S1)
	return l


static func _caption(spaced: bool) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font := load(DS.FONT_CAPTION_PATH) as Font
	if spaced:
		var wide := FontVariation.new()
		wide.base_font = font
		wide.spacing_glyph = DS.TRACKING_WIDE
		font = wide
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	_white_with_shadow(l, CAPTION_SHADOW_OFFSET, 0)
	return l


static func _link() -> LinkButton:
	var b := LinkButton.new()
	b.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", load(DS.FONT_CAPTION_PATH) as Font)
	b.add_theme_font_size_override("font_size", DS.SIZE_CAPTION)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, DS.UI_SURFACE)
	return b


static func _white_with_shadow(l: Label, offset: Vector2, spread: int) -> void:
	l.add_theme_color_override("font_color", DS.UI_SURFACE)
	l.add_theme_color_override("font_shadow_color", DS.TEXT_SHADOW)
	l.add_theme_constant_override("shadow_offset_x", int(offset.x))
	l.add_theme_constant_override("shadow_offset_y", int(offset.y))
	l.add_theme_constant_override("shadow_outline_size", spread)
