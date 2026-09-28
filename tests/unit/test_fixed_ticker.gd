extends GutTest


func test_sixty_frames_at_60fps_yield_sixty_ticks() -> void:
	var t := FixedTicker.new(5)
	var total := 0
	for i: int in 60:
		total += t.advance(1.0 / 60.0)
	assert_eq(total, 60)


func test_30fps_frame_runs_two_ticks() -> void:
	var t := FixedTicker.new(5)
	assert_eq(t.advance(1.0 / 30.0), 2)


func test_120fps_frames_alternate_zero_and_one_tick() -> void:
	var t := FixedTicker.new(5)
	assert_eq(t.advance(1.0 / 120.0), 0)
	assert_eq(t.advance(1.0 / 120.0), 1)


func test_variable_deltas_sum_to_one_second() -> void:
	var t := FixedTicker.new(10)
	var total := 0
	for d: float in [0.010, 0.020, 0.005, 0.030, 0.035, 0.100, 0.100, 0.100, 0.100, 0.100, 0.100, 0.100, 0.100, 0.100]:
		total += t.advance(d)
	assert_eq(total, 60)


func test_long_stall_is_capped_and_backlog_dropped() -> void:
	var t := FixedTicker.new(5)
	assert_eq(t.advance(1.0), 5, "cap ticks per frame")
	assert_lt(t.alpha(), 1.0, "backlog beyond cap is dropped")
	assert_eq(t.advance(0.0), 0, "no catch-up spiral on next frame")


func test_alpha_is_fraction_of_next_tick() -> void:
	var t := FixedTicker.new(5)
	t.advance(FixedTicker.TICK_DT * 0.25)
	assert_almost_eq(t.alpha(), 0.25, 0.0001)
