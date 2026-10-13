extends GutTest

var _hud: Hud


func before_each() -> void:
	_hud = Hud.new()
	add_child_autofree(_hud)
	_hud.setup(2, 3)


func _view(p1_damage: float, p2_stocks: int, p2_state: int = Fighter.State.IDLE) -> Dictionary:
	return {"fighters": [
		{"id": 0, "damage": p1_damage, "stocks": 3, "state": Fighter.State.IDLE},
		{"id": 1, "damage": 0.0, "stocks": p2_stocks, "state": p2_state},
	]}


func test_counters_show_rounded_damage() -> void:
	_hud.update_from(_view(41.6, 3))
	assert_eq(_hud.counter_text(0), "42%")
	assert_eq(_hud.counter_text(1), "0%")


func test_stocks_follow_the_view() -> void:
	_hud.update_from(_view(0.0, 1))
	assert_eq(_hud.stocks_shown(0), 3)
	assert_eq(_hud.stocks_shown(1), 1)


func test_result_banner_texts() -> void:
	assert_false(_hud.result_visible())
	_hud.show_result(0, 0)
	assert_true(_hud.result_visible())
	var banner := ResultBanner.new()
	add_child_autofree(banner)
	banner.show_result(1, 0)
	assert_eq(banner.title(), "패배…")
	banner.show_result(Rules.DRAW, 0)
	assert_eq(banner.title(), "무승부")
	banner.show_result(0, 0)
	assert_eq(banner.title(), "승리!")
	_hud.hide_result()
	await wait_seconds(DS.MOTION_BASE + 0.1)  # the banner fades out first
	assert_false(_hud.result_visible())


func test_frame_keeps_the_s5_margin_inside_the_safe_area() -> void:
	# desktop: the safe area is the whole viewport, so the margin is exactly s5
	assert_eq(_hud.frame_margin("left"), DS.S5)
	assert_eq(_hud.frame_margin("bottom"), HudStrip.EDGE, "the strip sits on the bottom edge (DS-LAY-02 v2)")


func test_result_banner_is_centered_and_the_strip_steps_aside() -> void:
	_hud.show_result(0, 0)
	await wait_seconds(DS.MOTION_BASE + 0.1)
	var screen := _hud.get_viewport().get_visible_rect()
	var r := _hud.banner().get_global_rect()
	assert_almost_eq(r.get_center().y, screen.get_center().y, 2.0, "centered vertically")
	assert_almost_eq(r.get_center().x, screen.get_center().x, 2.0, "centered across")
	assert_false(_hud.strip().visible, "the strip fades out under the banner")
	_hud.hide_result()
	assert_true(_hud.strip().visible)


func test_timed_result_uses_the_latest_scores() -> void:
	var view := _view(0.0, 3)
	view["mode"] = {"rule": MatchRules.TIMED, "scores": [0, 0]}
	_hud.update_from(view)
	view["mode"] = {"rule": MatchRules.TIMED, "scores": [4, 2]}
	_hud.update_from(view)
	_hud.show_result(0, 0)
	assert_eq(_hud.banner().detail(), "P1 4점 · P2 2점")

func test_online_result_offers_menu_and_clears_highlights_on_reset() -> void:
	var banner := _hud.banner()
	banner.set_menu_available(true)
	banner.set_restart_available(false)
	banner.set_highlights("P1 · 링아웃 3회")
	banner.show_result(0, 0)
	assert_true(banner.menu_button().has_focus())
	assert_eq(banner.highlights(), "P1 · 링아웃 3회")
	banner.hide_result()
	assert_eq(banner.highlights(), "")


func test_result_gauges_show_final_values_immediately_and_clear_on_restart() -> void:
	var banner := _hud.banner()
	banner.set_progress({"level": 2, "within": 40, "wins": 3, "ringouts": 7, "special_hits": 12})
	_hud.show_result(0, 0)
	assert_eq(banner.progress_values(), [40.0, 1.0, 7.0, 12.0] as Array[float])
	_hud.hide_result()
	assert_true(banner.progress_values().is_empty())
