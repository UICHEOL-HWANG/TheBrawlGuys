extends GutTest
## PHASES test: tap < threshold -> one light; hold -> heavy for as long as it is held.

const T := 0.15


func test_tap_is_a_light_on_release() -> void:
	var m := AttackButtonModel.new(T)
	m.press(1.0)
	assert_false(m.holding_heavy(1.1))
	assert_eq(m.release(1.1), AttackButtonModel.Result.LIGHT)
	assert_false(m.is_down())


func test_hold_turns_into_heavy_at_the_threshold() -> void:
	var m := AttackButtonModel.new(T)
	m.press(1.0)
	assert_false(m.holding_heavy(1.0 + T - 0.001))
	assert_true(m.holding_heavy(1.0 + T))
	assert_almost_eq(m.charge_time(1.0 + T + 0.5), 0.5, 0.0001, "charge counts from the threshold")
	assert_eq(m.release(1.0 + T + 0.5), AttackButtonModel.Result.HEAVY_RELEASE)


func test_canceled_tap_does_nothing() -> void:
	var m := AttackButtonModel.new(T)
	m.press(1.0)
	assert_eq(m.release(1.05, true), AttackButtonModel.Result.NONE, "a canceled touch is not an attack")


func test_release_without_press_is_none() -> void:
	assert_eq(AttackButtonModel.new(T).release(2.0), AttackButtonModel.Result.NONE)
	assert_eq(AttackButtonModel.new(T).charge_time(2.0), 0.0)
