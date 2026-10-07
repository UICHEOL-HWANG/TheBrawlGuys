extends GutTest
## Menu components (design.md DS-CMP-06 MenuButton, DS-CMP-07 Panel).

const MENU_BUTTON := preload("res://src/ui/components/menu_button/menu_button.tscn")
const PANEL := preload("res://src/ui/components/panel/panel.tscn")


func _button() -> UiMenuButton:
	var b := MENU_BUTTON.instantiate() as UiMenuButton
	add_child_autofree(b)
	return b


func test_menu_button_states() -> void:
	var b := _button()
	assert_eq(b.state(), UiMenuButton.State.IDLE)
	assert_gte(b.custom_minimum_size.y, float(DS.BUTTON_HEIGHT))
	b.set_state(UiMenuButton.State.FOCUS)
	assert_eq(b.state(), UiMenuButton.State.FOCUS)
	var focus_box := b.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(focus_box.bg_color, DS.PETAL_YELLOW, "focus = yellow face")
	assert_eq(focus_box.border_width_bottom, Sticker.EDGE + Sticker.DEPTH_FOCUS, "key lifted")
	assert_eq(focus_box.expand_margin_top, float(Sticker.DEPTH_FOCUS - Sticker.DEPTH))
	b.set_state(UiMenuButton.State.PRESSED)
	var pressed_box := b.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(pressed_box.bg_color, DS.UI_ACCENT, "pressed = campfire face")
	assert_eq(pressed_box.border_width_bottom, Sticker.EDGE + Sticker.DEPTH_PRESSED, "key pushed down")
	b.set_state(UiMenuButton.State.DISABLED)
	assert_true(b.disabled)
	assert_eq((b.get_theme_stylebox("disabled") as StyleBoxFlat).bg_color, DS.UI_SURFACE_DIM)
	b.set_state(UiMenuButton.State.IDLE)
	assert_false(b.disabled)
	var idle := b.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(idle.bg_color, DS.UI_SURFACE, "primary = cream sticker key")
	assert_eq(idle.border_color, Sticker.OUTLINE)
	assert_eq(idle.border_width_bottom, Sticker.EDGE + Sticker.DEPTH)


func test_menu_button_secondary_uses_the_surface() -> void:
	var b := _button()
	b.set_kind(UiMenuButton.Kind.SECONDARY)
	var box := b.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(box.bg_color, DS.UI_SURFACE)
	assert_eq(box.border_width_bottom, Sticker.EDGE + Sticker.DEPTH_PRESSED, "flatter than primary")
	assert_eq(b.get_theme_color("font_color"), DS.UI_TEXT_SOFT, "quiet until focused")


func test_menu_button_ghost_is_an_outline_on_glass() -> void:
	var b := _button()
	b.set_kind(UiMenuButton.Kind.GHOST)
	var box := b.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(box.bg_color, DS.TRANSPARENT)
	assert_eq(box.border_color, DS.UI_SURFACE_70)
	assert_gt(box.border_width_top, 0)
	assert_eq(b.get_theme_color("font_color"), DS.UI_SURFACE, "white text over the glass")
	b.set_state(UiMenuButton.State.FOCUS)
	assert_eq((b.get_theme_stylebox("normal") as StyleBoxFlat).border_color, DS.PETAL_YELLOW)
	b.set_state(UiMenuButton.State.DISABLED)
	assert_eq((b.get_theme_stylebox("disabled") as StyleBoxFlat).bg_color, DS.TRANSPARENT)
	assert_eq(b.get_theme_color("font_disabled_color"), DS.UI_SURFACE_50)


func test_focus_never_overrides_disabled() -> void:
	var b := _button()
	b.set_state(UiMenuButton.State.DISABLED)
	b.mouse_entered.emit()
	assert_eq(b.state(), UiMenuButton.State.DISABLED)


func test_menu_button_press_squishes_and_releases() -> void:
	var b := _button()
	b.button_down.emit()
	assert_eq(b.state(), UiMenuButton.State.PRESSED)
	assert_eq(b.scale, DS.PRESS_SQUISH)
	b.button_up.emit()
	assert_ne(b.state(), UiMenuButton.State.PRESSED)
	await wait_seconds(DS.MOTION_SQUISH + 0.1)
	assert_almost_eq(b.scale.x, 1.0, 0.02)


func test_panel_is_a_dim_sticker_card() -> void:
	var p := PANEL.instantiate() as UiPanel
	add_child_autofree(p)
	var box := p.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(box.bg_color, DS.UI_SURFACE_DIM)
	assert_eq(box.corner_radius_top_left, DS.RADIUS_L)
	assert_eq(box.border_color, Sticker.OUTLINE)
	assert_eq(box.content_margin_left, float(DS.S4), "tight s4 inner margin")


func test_gallery_registers_the_menu_components() -> void:
	var g := (load("res://src/debug/ds_gallery.gd") as GDScript)
	var registered: Array[String] = []
	for entry: Array in g.get_script_constant_map()["COMPONENTS"]:
		registered.append(String(entry[1]))
	for path: String in ["res://src/ui/components/menu_button/menu_button.tscn",
			"res://src/ui/components/panel/panel.tscn"]:
		assert_true(registered.has(path), path)
