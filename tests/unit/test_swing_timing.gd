extends GutTest
## SwingTiming (combat-motion A1): sim attack ticks -> a time in the swing clip, so the strike
## lands on the first active tick and the recovery eases back instead of fast-forwarding.

const PLAN := {"clip": "x", "start": 0.2, "contact": 0.5, "end": 1.1}


func _frames(startup: int, active: int, recovery: int) -> AttackData:
	var a := AttackData.new()
	a.startup_ticks = startup
	a.active_ticks = active
	a.recovery_ticks = recovery
	return a


func test_starts_at_the_cocked_pose() -> void:
	assert_almost_eq(SwingTiming.clip_time(1.0, _frames(4, 3, 8), PLAN), 0.2, 0.0001)


func test_contact_lands_on_the_first_active_tick() -> void:
	var f := _frames(4, 3, 8)
	assert_almost_eq(SwingTiming.clip_time(5.0, f, PLAN), 0.5, 0.0001, "attack_ticks = startup + 1")
	assert_lt(SwingTiming.clip_time(4.0, f, PLAN), 0.5, "still winding up on the last startup tick")


func test_windup_accelerates_into_the_hit() -> void:
	var f := _frames(10, 2, 10)
	var early := SwingTiming.clip_time(1.0 + 2.0, f, PLAN) - SwingTiming.clip_time(1.0, f, PLAN)
	var late := SwingTiming.clip_time(11.0, f, PLAN) - SwingTiming.clip_time(9.0, f, PLAN)
	assert_gt(late, early, "ease-in: the last startup ticks cover more of the clip")


func test_active_frames_hold_near_the_strike_pose() -> void:
	var f := _frames(4, 4, 8)
	var during := SwingTiming.clip_time(9.0, f, PLAN) - SwingTiming.clip_time(5.0, f, PLAN)
	assert_between(during, 0.0, (1.1 - 0.5) * 0.25, "the impact pose reads instead of sweeping past")


func test_recovery_eases_out_and_ends_at_end() -> void:
	var f := _frames(4, 3, 8)
	assert_almost_eq(SwingTiming.clip_time(16.0, f, PLAN), 1.1, 0.0001)
	var first := SwingTiming.clip_time(10.0, f, PLAN) - SwingTiming.clip_time(8.0, f, PLAN)
	var last := SwingTiming.clip_time(16.0, f, PLAN) - SwingTiming.clip_time(14.0, f, PLAN)
	assert_gt(first, last, "ease-out: the follow-through slows into the rest pose")


func test_clamps_outside_the_attack() -> void:
	var f := _frames(4, 3, 8)
	assert_almost_eq(SwingTiming.clip_time(0.0, f, PLAN), 0.2, 0.0001)
	assert_almost_eq(SwingTiming.clip_time(99.0, f, PLAN), 1.1, 0.0001)


func test_no_startup_snaps_to_contact() -> void:
	assert_almost_eq(SwingTiming.clip_time(1.0, _frames(0, 2, 4), PLAN), 0.5, 0.0001)


func test_is_monotonic() -> void:
	var f := _frames(6, 3, 13)
	var last := -1.0
	for i: int in 100:
		var t := SwingTiming.clip_time(float(i) * 0.25, f, PLAN)
		assert_true(t >= last - 0.000001, "tick %.2f" % (i * 0.25))
		last = t
