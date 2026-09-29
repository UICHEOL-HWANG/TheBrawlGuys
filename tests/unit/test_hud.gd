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
	assert_false(_hud.result_visible())
