extends GutTest


func test_amplitude_scales_with_knockback_and_caps() -> void:
	var c := GameConfig.new()
	var s := ShakeModel.new(c)
	s.add(10.0, 0.0)
	s.update(0.0)
	assert_almost_eq(s.amplitude(), 10.0 * c.shake_per_knockback, 0.0001)
	var big := ShakeModel.new(c)
	big.add(1000.0, 0.0)
	big.update(0.0)
	assert_almost_eq(big.amplitude(), c.shake_max, 0.0001)


func test_shake_waits_for_hitstop_then_decays() -> void:
	var c := GameConfig.new()
	var s := ShakeModel.new(c)
	s.add(20.0, 0.1)
	s.update(0.05)
	assert_eq(s.amplitude(), 0.0, "still in hitstop")
	s.update(0.06)
	var start := s.amplitude()
	assert_gt(start, 0.0)
	s.update(0.5)
	assert_lt(s.amplitude(), start * 0.1, "exponential decay")


func test_offset_is_zero_without_shake_and_bounded_with_it() -> void:
	var c := GameConfig.new()
	var s := ShakeModel.new(c)
	assert_eq(s.update(0.016), Vector3.ZERO)
	s.add(1000.0, 0.0)
	for i: int in 30:
		assert_true(s.update(0.016).length() <= c.shake_max * 1.5)
