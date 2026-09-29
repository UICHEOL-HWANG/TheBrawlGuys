class_name ThemeBuilder
extends RefCounted
## Builds the project Theme from DS tokens (design.md DS-THM-01). Never hand-edit forest_theme.tres.


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = load(DS.FONT_BODY_PATH) as Font
	theme.default_font_size = DS.SIZE_BODY

	var panel := _surface(DS.RADIUS_L, DS.SHADOW_SOFT_OFFSET, DS.SHADOW_SOFT_SIZE)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)

	var normal := _surface(DS.RADIUS_PILL, DS.SHADOW_SOFT_OFFSET, DS.SHADOW_SOFT_SIZE)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", normal)
	theme.set_stylebox("pressed", "Button", _surface(DS.RADIUS_PILL, DS.SHADOW_PRESSED_OFFSET, DS.SHADOW_PRESSED_SIZE))
	theme.set_stylebox("disabled", "Button", _flat(DS.UI_SURFACE_DIM, DS.RADIUS_PILL))
	theme.set_stylebox("focus", "Button", _focus_ring())

	for type_name: String in ["Label", "Button"]:
		theme.set_color("font_color", type_name, DS.UI_TEXT)
	theme.set_color("font_hover_color", "Button", DS.UI_TEXT)
	theme.set_color("font_pressed_color", "Button", DS.UI_TEXT)
	theme.set_color("font_focus_color", "Button", DS.UI_TEXT)
	theme.set_color("font_disabled_color", "Button", DS.UI_TEXT_SOFT)
	return theme


static func _surface(radius: int, shadow_offset: Vector2, shadow_size: int) -> StyleBoxFlat:
	var sb := _flat(DS.UI_SURFACE, radius)
	sb.shadow_color = DS.UI_SHADOW
	sb.shadow_offset = shadow_offset
	sb.shadow_size = shadow_size
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
