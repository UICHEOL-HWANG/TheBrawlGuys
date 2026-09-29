extends GutTest
## Held buttons across frames and ticks (context E3).


func test_held_reads_true_every_tick() -> void:
	var h := HoldLatch.new()
	h.set_held(true)
	assert_true(h.consume())
	assert_true(h.consume())
	h.set_held(false)
	assert_false(h.consume())


func test_tap_between_ticks_still_reaches_one_tick() -> void:
	var h := HoldLatch.new()
	h.set_held(true)
	h.set_held(false)
	assert_true(h.consume(), "pressed and released inside one frame")
	assert_false(h.consume())


func test_press_marks_a_pending_tap() -> void:
	var h := HoldLatch.new()
	h.press()
	assert_true(h.consume())
	assert_false(h.consume())


func test_clear_drops_hold_and_pending() -> void:
	var h := HoldLatch.new()
	h.set_held(true)
	h.clear()
	assert_false(h.is_held())
	assert_false(h.consume())
