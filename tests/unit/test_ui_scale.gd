extends GutTest
## Responsive UI scale (design.md DS-LAY-04): phones get readable captions and 44 CSS px touch
## targets, tablets a moderate boost, desktop keeps 1.0; portrait touch devices get the rotate
## prompt, which blocks input underneath.

const APPLIER := preload("res://src/app/ui_scaler.gd")


func _caption_css(css: Vector2, f: float) -> float:
	return DS.SIZE_CAPTION * UiScale.base_scale(css) * f


func test_desktop_sizes_keep_the_original_look() -> void:
	for css: Vector2 in [Vector2(1920, 1080), Vector2(1280, 720), Vector2(1024, 768)]:
		assert_eq(UiScale.factor(css, false), 1.0, str(css))
		assert_eq(UiScale.classify(css, false), UiScale.DESKTOP, str(css))
	assert_eq(UiScale.factor(Vector2(1920, 1080), true), 1.0, "a big touch screen is a desktop")


func test_phone_landscape_captions_reach_12_css_px() -> void:
	for css: Vector2 in [Vector2(812, 375), Vector2(667, 375), Vector2(740, 360)]:
		var f := UiScale.factor(css, true)
		assert_eq(UiScale.classify(css, true), UiScale.PHONE, str(css))
		assert_gte(_caption_css(css, f), DS.CAPTION_MIN_PHONE_CSS - 0.01, str(css))
		assert_lt(_caption_css(css, f), DS.CAPTION_MIN_PHONE_CSS + 1.0, "no more than needed " + str(css))
		var smallest_button := DS.TOUCH_TARGET_BASE_MIN * UiScale.base_scale(css) * f
		assert_gte(smallest_button, DS.TOUCH_TARGET_MIN_CSS, "touch target " + str(css))


func test_chosen_phone_and_tablet_factors() -> void:
	assert_eq(UiScale.factor(Vector2(812, 375), true), 1.6)
	assert_eq(UiScale.factor(Vector2(667, 375), true), 1.6)
	assert_eq(UiScale.factor(Vector2(740, 360), true), 1.65)
	assert_eq(UiScale.factor(Vector2(1024, 768), true), 1.15, "tablet: moderate")
	assert_eq(UiScale.classify(Vector2(1024, 768), true), UiScale.TABLET)


func test_phone_layout_keeps_room_for_the_menus() -> void:
	var size := UiScale.layout_size(Vector2(740, 360), UiScale.factor(Vector2(740, 360), true))
	assert_gt(size.y, 640.0, "enough height for a compact login card")
	assert_gt(size.x, 1300.0)


func test_a_very_short_phone_window_still_fits_the_menus() -> void:
	# iPhone landscape in Safari with the address and tab bars: only ~280 CSS px tall.
	var css := Vector2(760, 282)
	var f := UiScale.factor(css, true)
	assert_eq(f, 1.65)
	assert_gte(UiScale.layout_size(css, f).y, UiScale.MIN_LAYOUT_HEIGHT, "nothing cut off at the bottom")
	assert_gt(f, 1.0, "still enlarged as far as it fits")


func test_small_desktop_window_scales_like_a_phone() -> void:
	assert_eq(UiScale.classify(Vector2(812, 375), false), UiScale.PHONE)
	assert_gt(UiScale.factor(Vector2(812, 375), false), 1.0)


func test_portrait_touch_asks_to_rotate() -> void:
	var p := UiScale.profile(Vector2(375, 812), true)
	assert_eq(p["orientation"], UiScale.PORTRAIT)
	assert_true(p["rotate"])
	assert_lte(float(p["ui_scale"]), DS.UI_SCALE_MAX)
	assert_false(UiScale.profile(Vector2(812, 375), true)["rotate"], "landscape plays")
	assert_false(UiScale.profile(Vector2(600, 900), false)["rotate"], "no touch: no prompt")


func test_unknown_window_is_desktop_one() -> void:
	assert_eq(UiScale.factor(Vector2.ZERO, false), 1.0)
	assert_eq(UiScale.profile(Vector2.ZERO, false)["ui_scale"], 1.0)


func test_tracking_props_are_the_three_globals() -> void:
	var t := UiScale.tracking(UiScale.profile(Vector2(812, 375), true))
	assert_eq(t, {"viewport_class": "phone", "orientation": "landscape", "ui_scale": 1.6})


func _applier() -> Node:
	var a: Node = APPLIER.new()
	a.set("live", false)
	add_child_autofree(a)
	return a


func test_applier_shows_the_rotate_prompt_in_portrait() -> void:
	var a := _applier()
	a.call("apply", UiScale.profile(Vector2(375, 812), true))
	var overlay := a.call("overlay") as RotateOverlay
	assert_true(overlay.is_active())
	assert_true(overlay.visible)
	a.call("apply", UiScale.profile(Vector2(812, 375), true))
	assert_false(overlay.is_active(), "rotated to landscape: gone")


func test_rotate_prompt_swallows_input() -> void:
	var a := _applier()
	a.call("apply", UiScale.profile(Vector2(375, 812), true))
	var overlay := a.call("overlay") as RotateOverlay
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	assert_true(overlay.blocks(touch))
	a.call("apply", UiScale.profile(Vector2(812, 375), true))
	assert_false(overlay.blocks(touch))


func test_applier_keeps_desktop_scale() -> void:
	var a := _applier()
	a.call("apply", UiScale.profile(Vector2(1920, 1080), false))
	assert_eq(float(a.call("applied_factor")), 1.0)
	assert_false((a.call("overlay") as RotateOverlay).is_active())


## Every phone layout must still hold the widest bottom/center blocks without shrinking text.
func test_bars_and_banners_fit_the_smallest_phone_layout() -> void:
	var css := Vector2(740, 360)
	var room := UiScale.layout_size(css, UiScale.factor(css, true)) - Vector2.ONE * DS.S5 * 2
	var bar := (load("res://src/ui/components/key_hint_bar/key_hint_bar.tscn") as PackedScene).instantiate() as Control
	var banner := (load("res://src/ui/components/result_banner/result_banner.tscn") as PackedScene).instantiate() as ResultBanner
	for c: Control in [bar, banner]:
		add_child_autofree(c)
	banner.set_menu_available(true)
	await wait_process_frames(2)
	for c: Control in [bar, banner]:
		var need := c.get_combined_minimum_size()
		assert_lte(need.x, room.x, "%s width" % c.name)
		assert_lte(need.y, room.y, "%s height" % c.name)
