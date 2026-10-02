extends GutTest
## Finishing replay (design.md GD-CAM-02): a render-side buffer of tick views replayed slowly from
## just before the last hit on the fighter whose ring-out ended the match.

const DT := 1.0 / 60.0
const VICTIM := 1


func _frame(tick: int, events: Array = [], victim_state: int = Fighter.State.IDLE) -> Dictionary:
	return {"tick": tick, "events": events, "fighters": [
		{"id": 0, "pos": Vector3.ZERO, "state": Fighter.State.IDLE},
		{"id": VICTIM, "pos": Vector3(float(tick), 0.0, 0.0), "state": victim_state},
	]}


func _hit(target: int) -> Dictionary:
	return {"type": "hit", "attacker": 0, "target": target, "pos": Vector3.ZERO}


func _ringout(id: int) -> Dictionary:
	return {"type": "ringout", "id": id, "pos": Vector3.ZERO, "stocks_left": 0, "zone": "kill_y"}


## Ticks 0..last; a hit on hit_target at hit_tick (-1 = none) and the ring-out on the last tick.
func _record(replay: FinisherReplay, last: int, hit_tick: int, hit_target: int = VICTIM) -> void:
	for t: int in last + 1:
		var events: Array = []
		if t == hit_tick:
			events.append(_hit(hit_target))
		if t == last:
			events.append(_ringout(VICTIM))
		replay.record(_frame(t, events, Fighter.State.KO if t == last else Fighter.State.IDLE))


## Game-time steps (the caller slows Engine.time_scale to speed()).
func _play_to_end(replay: FinisherReplay) -> Array:
	var steps: Array = []
	for i: int in 10000:
		var step := replay.advance(DT * replay.speed())
		steps.append(step)
		if bool(step["done"]):
			break
	return steps


func test_no_replay_without_a_ringout_on_the_last_tick() -> void:
	var replay := FinisherReplay.new()
	for t: int in 30:
		replay.record(_frame(t))
	assert_false(replay.start())
	assert_false(replay.is_active())


func test_starts_just_before_the_last_hit_on_the_victim() -> void:
	var replay := FinisherReplay.new()
	_record(replay, 90, 60)
	assert_true(replay.start())
	assert_true(replay.is_active())
	assert_eq(replay.victim(), VICTIM)
	assert_eq(replay.start_tick(), 60 - SimTime.to_ticks(FinisherReplay.LEAD_S))


func test_ignores_hits_on_other_fighters() -> void:
	var replay := FinisherReplay.new()
	_record(replay, 90, 60, 0)
	assert_true(replay.start())
	assert_eq(replay.start_tick(), 90 - SimTime.to_ticks(FinisherReplay.NO_HIT_LEAD_S))


func test_without_a_hit_replays_the_fall() -> void:
	var replay := FinisherReplay.new()
	_record(replay, 90, -1)
	assert_true(replay.start())
	assert_eq(replay.start_tick(), 90 - SimTime.to_ticks(FinisherReplay.NO_HIT_LEAD_S))


func test_buffer_keeps_only_the_last_seconds() -> void:
	var replay := FinisherReplay.new()
	_record(replay, 600, 10)  # the hit is older than the buffer
	assert_true(replay.start())
	assert_eq(replay.start_tick(), 600 - SimTime.to_ticks(FinisherReplay.NO_HIT_LEAD_S))


func test_emits_each_replayed_tick_once_in_order() -> void:
	var replay := FinisherReplay.new()
	_record(replay, 90, 60)
	replay.start()
	var ticks: Array = []
	var types: Array = []
	for step: Dictionary in _play_to_end(replay):
		for f: Dictionary in step["frames"]:
			ticks.append(int(f["tick"]))
			for e: Dictionary in f["events"]:
				types.append(String(e["type"]))
	var expected: Array = range(replay.start_tick() + 1, 91)
	assert_eq(ticks, expected)
	assert_eq(types, ["hit", "ringout"])


func test_interpolates_between_consecutive_ticks() -> void:
	var replay := FinisherReplay.new()
	_record(replay, 90, 60)
	replay.start()
	var step := replay.advance(DT * 0.5)
	assert_eq(int(step["curr"]["tick"]) - int(step["prev"]["tick"]), 1)
	assert_between(float(step["alpha"]), 0.0, 1.0)


func test_slow_around_the_hit_then_faster_through_the_flight() -> void:
	var replay := FinisherReplay.new()
	_record(replay, 120, 60)
	replay.start()
	assert_eq(replay.speed(), FinisherReplay.SLOW_SPEED)
	var seen_fast := false
	for i: int in 10000:
		var step := replay.advance(DT * replay.speed())
		seen_fast = seen_fast or replay.speed() == FinisherReplay.FAST_SPEED
		if bool(step["done"]):
			break
	assert_true(seen_fast, "the flight plays faster than the hit")
	assert_lt(FinisherReplay.SLOW_SPEED, FinisherReplay.FAST_SPEED)
	assert_lt(FinisherReplay.FAST_SPEED, 1.0)


func test_ends_after_the_tail_and_stops() -> void:
	var replay := FinisherReplay.new()
	_record(replay, 90, 60)
	replay.start()
	var steps := _play_to_end(replay)
	assert_true(bool(steps.back()["done"]))
	assert_eq(int(steps.back()["curr"]["tick"]), 90)
	replay.stop()
	assert_false(replay.is_active())
	assert_eq(replay.speed(), 1.0, "normal speed when idle")


func test_close_shot_eases_in_and_back_out() -> void:
	var replay := FinisherReplay.new()
	_record(replay, 90, 60)
	replay.start()
	assert_eq(replay.camera_weight(), 0.0)
	var peak := 0.0
	var last := 0.0
	for i: int in 10000:
		var step := replay.advance(DT * replay.speed())
		assert_lt(absf(replay.camera_weight() - last), 0.2, "no jumps")
		last = replay.camera_weight()
		peak = maxf(peak, last)
		if bool(step["done"]):
			break
	assert_almost_eq(peak, 1.0, 0.001)
	assert_almost_eq(last, 0.0, 0.001, "back on the match framing before the banner")


func test_reduce_motion_keeps_the_camera_still() -> void:
	var replay := FinisherReplay.new()
	_record(replay, 90, 60)
	replay.start(true)
	for i: int in 10000:
		var step := replay.advance(DT * replay.speed())
		assert_eq(replay.camera_weight(), 0.0)
		if bool(step["done"]):
			break


func test_focus_follows_the_victim_and_holds_once_knocked_out() -> void:
	var replay := FinisherReplay.new()
	_record(replay, 90, 60)
	replay.start()
	var at := replay.focus(replay.advance(DT))
	assert_between(at.x, float(replay.start_tick()), float(replay.start_tick()) + 2.0)
	var steps := _play_to_end(replay)
	assert_almost_eq(replay.focus(steps.back()).x, 89.0, 0.5, "last position before the KO")


func test_ticks_after_the_ending_one_are_not_recorded() -> void:
	var replay := FinisherReplay.new()
	for t: int in 91:
		var f := _frame(t, [_ringout(VICTIM)] if t == 90 else [])
		f["match_over"] = t >= 90
		replay.record(f)
	var after := _frame(91)
	after["match_over"] = true
	replay.record(after)  # the same frame ran one more (empty) tick past the end
	assert_true(replay.start())
	assert_eq(replay.victim(), VICTIM)


func test_clear_drops_the_buffer() -> void:
	var replay := FinisherReplay.new()
	_record(replay, 90, 60)
	replay.clear()
	assert_false(replay.start())
