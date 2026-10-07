class_name ThemeBuilder
extends RefCounted
## Builds the project Theme from DS tokens (design.md DS-THM-01). Never hand-edit forest_theme.tres.


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = load(DS.FONT_BODY_PATH) as Font
	theme.default_font_size = DS.SIZE_BODY

	var panel := _sticker(DS.UI_SURFACE_DIM, DS.RADIUS_L, Sticker.DEPTH)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)

	var normal := _sticker(DS.UI_SURFACE, DS.RADIUS_PILL, Sticker.DEPTH_PRESSED)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", normal)
	theme.set_stylebox("pressed", "Button", _sticker(DS.UI_SURFACE, DS.RADIUS_PILL, 0))
	theme.set_stylebox("disabled", "Button", _flat(DS.UI_SURFACE_DIM, DS.RADIUS_PILL))
	theme.set_stylebox("focus", "Button", _focus_ring())

	for type_name: String in ["Label", "Button"]:
		theme.set_color("font_color", type_name, DS.UI_TEXT)
	theme.set_color("font_hover_color", "Button", DS.UI_TEXT)
	theme.set_color("font_pressed_color", "Button", DS.UI_TEXT)
	theme.set_color("font_focus_color", "Button", DS.UI_TEXT)
	theme.set_color("font_disabled_color", "Button", DS.UI_TEXT_SOFT)
	return theme


## DS-CMP-06/07 v2 comic sticker look for the stock controls (toggles, plain panels).
static func _sticker(bg: Color, radius: int, depth: int) -> StyleBoxFlat:
	var sb := Sticker.box(bg, radius, depth)
	sb.set_content_margin_all(DS.S4)
	sb.content_margin_bottom = DS.S4 + depth  # text centered on the face, above the key edge
	return sb


static func _flat(bg: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(DS.S4)
	return sb


static func _focus_ring() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = DS.PETAL_YELLOW
	sb.set_border_width_all(DS.STROKE_FOCUS)
	sb.set_corner_radius_all(DS.RADIUS_PILL)
	return sb
