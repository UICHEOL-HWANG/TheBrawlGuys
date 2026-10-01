extends GutTest
## Timed FFA (MatchRules.TIMED): unlimited respawns, +1 for a ring-out credited to the last
## attacker (within ringout_credit_time), -1 for a fall nobody caused, the highest score wins at
## time up and a tie goes to sudden death (tied players on one stock, everyone else out).


func _neutral(n: int) -> Array[InputFrame]:
	var a: Array[InputFrame] = []
	for i: int in n:
		a.append(InputFrame.neutral())
	return a


func _world(seconds: float = 120.0, count: int = 4) -> World:
	return World.new(GameConfig.new(), 1, count, null, [], MatchRules.timed(SimTime.to_ticks(seconds)))


func _drop(w: World, id: int) -> void:
	w.fighters[id].pos = Vector3(0, w.config.kill_y - 1, 0)
	w.fighters[id].on_ground = false
	w.fighters[id].invuln_ticks = 0


func test_ringouts_never_cost_a_stock() -> void:
	var w := _world()
	var before := w.fighters[1].stocks
	for i: int in 5:
		_drop(w, 1)
		w.tick(_neutral(4))
	assert_eq(w.fighters[1].stocks, before)
	assert_true(w.fighters[1].is_alive())
	assert_false(w.match_over)


func test_self_destruct_costs_a_point() -> void:
	var w := _world()
	_drop(w, 1)
	w.tick(_neutral(4))
	assert_eq(w.mode_state.scores, [0, -1, 0, 0] as Array[int])
	var score_events := (w.state_view()["events"] as Array).filter(func(e: Dictionary) -> bool:
		return e["type"] == "score")
	assert_eq(score_events.size(), 1)
	assert_eq(int(score_events[0]["id"]), 1)
	assert_eq(int(score_events[0]["delta"]), -1)


func test_ringout_after_a_hit_scores_for_the_attacker() -> void:
	var w := _world()
	w.mode_state.note_hit(2, 1, w.tick_count)
	_drop(w, 1)
	w.tick(_neutral(4))
	assert_eq(w.mode_state.scores, [0, 0, 1, 0] as Array[int])


func test_old_hit_no_longer_credits() -> void:
	var w := _world()
	w.mode_state.note_hit(2, 1, w.tick_count)
	for i: int in SimTime.to_ticks(w.config.ringout_credit_time) + 2:
		w.tick(_neutral(4))
	_drop(w, 1)
	w.tick(_neutral(4))
	assert_eq(w.mode_state.scores, [0, -1, 0, 0] as Array[int])


func test_hit_events_set_the_last_attacker() -> void:
	var w := _world()
	w.fighters[0].pos = Vector3(0, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[1].pos = Vector3(0.9, 0, 0)
	var inputs := _neutral(4)
	inputs[0] = InputFrame.make(0, 0, false, true)
	w.tick(inputs)
	for t: int in 12:
		w.tick(_neutral(4))
	assert_gt(w.fighters[1].damage, 0.0)
	_drop(w, 1)
	w.tick(_neutral(4))
	assert_eq(w.mode_state.scores[0], 1)


func test_clock_counts_down_in_the_view() -> void:
	var w := _world(2.0)
	w.tick(_neutral(4))
	assert_eq(int(w.state_view()["mode"]["ticks_left"]), SimTime.to_ticks(2.0) - 1)


func test_time_up_highest_score_wins() -> void:
	var w := _world(1.0)
	w.mode_state.scores[3] = 2
	for i: int in SimTime.to_ticks(1.0):
		w.tick(_neutral(4))
	assert_true(w.match_over)
	assert_eq(w.winner_id, 3)


func test_tie_goes_to_sudden_death() -> void:
	var w := _world(1.0)
	w.mode_state.scores[0] = 2
	w.mode_state.scores[2] = 2
	for i: int in SimTime.to_ticks(1.0):
		w.tick(_neutral(4))
	assert_false(w.match_over)
	assert_true(w.mode_state.sudden_death)
	assert_eq(w.fighters[0].stocks, 1)
	assert_eq(w.fighters[2].stocks, 1)
	assert_false(w.fighters[1].is_alive())
	assert_false(w.fighters[3].is_alive())
	_drop(w, 2)
	w.tick(_neutral(4))
	assert_true(w.match_over)
	assert_eq(w.winner_id, 0)


func test_snapshot_round_trip_keeps_mode_state() -> void:
	var w := _world(5.0)
	w.mode_state.note_hit(2, 1, 0)
	_drop(w, 1)
	for i: int in 30:
		w.tick(_neutral(4))
	var snap := w.snapshot()
	var other := _world(5.0)
	assert_true(other.restore(snap))
	assert_eq(other.mode_state.scores, w.mode_state.scores)
	assert_eq(other.mode_state.ticks_left, w.mode_state.ticks_left)
	assert_eq(other.mode_state.rules.mode, MatchRules.TIMED)
	for i: int in 40:
		w.tick(_neutral(4))
		other.tick(_neutral(4))
	assert_eq(other.state_hash(), w.state_hash())


func test_snapshot_version_bumped_for_modes() -> void:
	assert_eq(WorldCodec.VERSION, 10, "v10 = knockdown fields (v9) + match mode state")
	assert_true(Fighter.DATA_TYPES.has("ally_mask"))
