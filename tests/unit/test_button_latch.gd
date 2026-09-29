extends GutTest


func test_consume_returns_false_without_press() -> void:
	assert_false(ButtonLatch.new().consume())


func test_press_is_consumed_exactly_once() -> void:
	var l := ButtonLatch.new()
	l.press()
	assert_true(l.consume(), "first tick sees the press")
	assert_false(l.consume(), "second tick does not see it again")


func test_press_survives_frames_without_ticks() -> void:
	var l := ButtonLatch.new()
	l.press()
	# a frame with zero sim ticks consumes nothing; the next tick still sees it
	assert_true(l.consume())


func test_multiple_presses_before_a_tick_collapse_to_one() -> void:
	var l := ButtonLatch.new()
	l.press()
	l.press()
	assert_true(l.consume())
	assert_false(l.consume())
