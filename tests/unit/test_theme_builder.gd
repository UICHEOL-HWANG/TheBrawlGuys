extends GutTest

const THEME_PATH := "res://src/ui/theme/forest_theme.tres"


func test_panel_uses_surface_and_large_radius() -> void:
	var sb := ThemeBuilder.build().get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	assert_not_null(sb)
	assert_eq(sb.bg_color, DS.UI_SURFACE)
	assert_eq(sb.corner_radius_top_left, DS.RADIUS_L)
	assert_eq(sb.shadow_color, DS.UI_SHADOW)


func test_button_states() -> void:
	var t := ThemeBuilder.build()
	var normal := t.get_stylebox("normal", "Button") as StyleBoxFlat
	var pressed := t.get_stylebox("pressed", "Button") as StyleBoxFlat
	var focus := t.get_stylebox("focus", "Button") as StyleBoxFlat
	assert_eq(normal.shadow_offset, DS.SHADOW_SOFT_OFFSET)
	assert_eq(pressed.shadow_offset, DS.SHADOW_PRESSED_OFFSET)
	assert_eq(focus.border_color, DS.PETAL_YELLOW)
	assert_eq(focus.border_width_top, DS.STROKE_FOCUS)
	assert_false(focus.draw_center)
	assert_eq(t.get_color("font_focus_color", "Button"), DS.UI_TEXT, "focused buttons keep readable text")


func test_text_colors_and_font() -> void:
	var t := ThemeBuilder.build()
	assert_eq(t.get_color("font_color", "Label"), DS.UI_TEXT)
	assert_eq(t.get_color("font_color", "Button"), DS.UI_TEXT)
	assert_not_null(t.default_font)
	assert_eq(t.default_font_size, DS.SIZE_BODY)


func test_committed_theme_is_in_sync_with_builder() -> void:
	var saved := load(THEME_PATH) as Theme
	assert_not_null(saved, "run scripts/build_theme.gd")
	var a := saved.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	var b := ThemeBuilder.build().get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	assert_eq(a.bg_color, b.bg_color, "forest_theme.tres is stale — regenerate it")
	assert_eq(a.corner_radius_top_left, b.corner_radius_top_left)


func test_project_uses_forest_theme() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom", ""), THEME_PATH)
