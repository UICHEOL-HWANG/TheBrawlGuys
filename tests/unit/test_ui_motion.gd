extends GutTest
## Motion tokens (design.md DS-TOK-05) shared by every UI transition.


func test_token_specs_match_design() -> void:
	var fast := UiMotion.spec(UiMotion.Token.FAST)
	assert_eq(fast["duration"], DS.MOTION_FAST)
	assert_eq(fast["trans"], Tween.TRANS_QUAD)
	assert_eq(fast["ease"], Tween.EASE_OUT)
	assert_eq(UiMotion.spec(UiMotion.Token.BASE)["duration"], DS.MOTION_BASE)
	var squish := UiMotion.spec(UiMotion.Token.SQUISH)
	assert_eq(squish["duration"], DS.MOTION_SQUISH)
	assert_eq(squish["trans"], Tween.TRANS_ELASTIC)
	var slow := UiMotion.spec(UiMotion.Token.SLOW)
	assert_eq(slow["duration"], DS.MOTION_SLOW)
	assert_eq(slow["trans"], Tween.TRANS_CUBIC)
	assert_eq(slow["ease"], Tween.EASE_IN_OUT)


func test_pop_in_then_fade_out() -> void:
	var c := Control.new()
	add_child_autofree(c)
	c.visible = false
	UiMotion.pop_in(c, 0.6)
	assert_true(c.visible)
	await wait_seconds(DS.MOTION_SQUISH + 0.1)
	assert_almost_eq(c.scale.x, 1.0, 0.02)
	assert_almost_eq(c.modulate.a, 1.0, 0.02)
	UiMotion.fade_out(c)
	await wait_seconds(DS.MOTION_BASE + 0.1)
	assert_false(c.visible, "hidden once faded")


func test_banner_and_counter_use_the_tokens() -> void:
	var banner := (load("res://src/ui/components/result_banner/result_banner.tscn") as PackedScene).instantiate() as ResultBanner
	add_child_autofree(banner)
	banner.show_result(0, 0)
	assert_lt(banner.modulate.a, 1.0, "the banner fades in")
	await wait_seconds(DS.MOTION_SQUISH + 0.1)
	assert_almost_eq(banner.modulate.a, 1.0, 0.02)
	banner.hide_result()
	await wait_seconds(DS.MOTION_BASE + 0.1)
	assert_false(banner.visible)


func test_losing_a_stock_bumps_its_marker() -> void:
	var s := (load("res://src/ui/components/stock_icons/stock_icons.tscn") as PackedScene).instantiate() as StockIcons
	add_child_autofree(s)
	s.setup(0, 3)
	await wait_process_frames(1)
	s.set_stocks(2)
	assert_ne((s.get_child(2) as Control).scale, Vector2.ONE, "the lost stock pops")
