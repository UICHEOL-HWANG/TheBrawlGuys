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
	assert_eq(focus_box.border_width_top, DS.STROKE_FOCUS, "focus ring")
	assert_eq(focus_box.border_color, DS.PETAL_YELLOW)
	b.set_state(UiMenuButton.State.DISABLED)
	assert_true(b.disabled)
	assert_eq((b.get_theme_stylebox("disabled") as StyleBoxFlat).bg_color, DS.UI_SURFACE_DIM)
	b.set_state(UiMenuButton.State.IDLE)
	assert_false(b.disabled)
	assert_eq((b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, DS.UI_ACCENT, "primary = accent")


func test_menu_button_secondary_uses_the_surface() -> void:
	var b := _button()
	b.set_kind(UiMenuButton.Kind.SECONDARY)
	assert_eq((b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, DS.UI_SURFACE)


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


func test_panel_uses_surface_tokens() -> void:
	var p := PANEL.instantiate() as UiPanel
	add_child_autofree(p)
	var box := p.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(box.bg_color, DS.UI_SURFACE)
	assert_eq(box.corner_radius_top_left, DS.RADIUS_L)
	assert_eq(box.shadow_size, DS.SHADOW_SOFT_SIZE)


func test_gallery_registers_the_menu_components() -> void:
	var g := (load("res://src/debug/ds_gallery.gd") as GDScript)
	var registered: Array[String] = []
	for entry: Array in g.get_script_constant_map()["COMPONENTS"]:
		registered.append(String(entry[1]))
	for path: String in ["res://src/ui/components/menu_button/menu_button.tscn",
			"res://src/ui/components/panel/panel.tscn"]:
		assert_true(registered.has(path), path)
