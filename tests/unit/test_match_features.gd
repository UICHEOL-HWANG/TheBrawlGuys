extends GutTest
## Per-slot behaviour features (platform A8, analytics-strategy §3.2): input habits, spatial habits
## and match flow, computed from the inputs, views and events telemetry already receives.

const S := Fighter.State
const MINUTE := 60 * SimTime.TICK_RATE


static func _f(id: int, pos: Vector3, extra: Dictionary = {}) -> Dictionary:
	var f := {"id": id, "spawn_id": 0, "pos": pos, "state": S.IDLE, "on_ground": true, "damage": 0.0,
		"stocks": 3, "item_kind": -1}
	f.merge(extra, true)
	return f


func test_presses_are_rising_edges_per_action() -> void:
	var feats := InputFeatures.new(1)
	var frames := [InputFrame.make(0, 0, false, true), InputFrame.make(0, 0, false, true),
		InputFrame.make(0, 0), InputFrame.make(0, 0, true, true, true, true, true)]
	for t: int in frames.size():
		feats.observe([frames[t]])
	var s := feats.summary(0)
	assert_eq(s["press_light"], 2, "held light counts once, then again after release")
	assert_eq([s["press_jump"], s["press_heavy"], s["press_guard"], s["press_grab"]], [1, 1, 1, 1])
	assert_eq(s["press_special"], 1, "heavy + guard together is the special chord (X+C)")


func test_special_chord_counts_once_per_forming() -> void:
	var feats := InputFeatures.new(1)
	var frames := [InputFrame.make(0, 0, false, false, true), InputFrame.make(0, 0, false, false, true, true),
		InputFrame.make(0, 0, false, false, true, true), InputFrame.make(0, 0, false, false, false, true),
		InputFrame.make(0, 0, false, false, true, true)]
	for f: InputFrame in frames:
		feats.observe([f])
	var s := feats.summary(0)
	assert_eq(s["press_special"], 2, "chord formed on tick 1 (heavy held first) and again on tick 4")
	assert_eq(s["press_heavy"], 2)


func test_mash_ratio_counts_quick_repeats() -> void:
	var feats := InputFeatures.new(1)
	for t: int in 40:
		feats.observe([InputFrame.make(0, 0, false, t % 4 == 0 and t < 20 or t == 39)])
	var s := feats.summary(0)
	assert_eq(s["press_light"], 6)
	assert_almost_eq(float(s["mash_ratio"]), 4.0 / 6.0, 0.001, "presses 2..5 come within the window")


func test_direction_changes_guard_hold_and_idle_gaps() -> void:
	var feats := InputFeatures.new(1)
	var script := [[1.0, 0.0, 30], [0.0, 0.0, 10], [-1.0, 0.0, 30], [0.0, -1.0, 30]]
	for step: Array in script:
		for i: int in int(step[2]):
			feats.observe([InputFrame.make(step[0], step[1])])
	for i: int in InputFeatures.IDLE_GAP_TICKS + 10:
		feats.observe([InputFrame.neutral()])
	for i: int in 100:
		feats.observe([InputFrame.make(0, 0, false, false, false, true)])
	var s := feats.summary(0)
	assert_eq(s["direction_changes"], 2, "right -> left -> down; neutral in between is not a direction")
	assert_eq(s["idle_gaps"], 1)
	assert_almost_eq(float(s["guard_hold_ratio"]), 100.0 / (100 + 100 + InputFeatures.IDLE_GAP_TICKS + 10), 0.001)
	assert_gt(float(s["inputs_per_min"]), 0.0)


func test_spatial_features() -> void:
	var feats := SpatialFeatures.new(2)
	var prev: Array = []
	for t: int in 10:
		var fighters := [_f(0, Vector3(float(t), 0, 0), {"on_ground": t < 5, "item_kind": Item.Kind.BAT}),
			_f(1, Vector3(9.5, 0, 0))]
		feats.observe(prev, fighters, 10.0)
		prev = fighters
	var s0 := feats.summary(0)
	var s1 := feats.summary(1)
	assert_almost_eq(float(s0["distance_travelled"]), 9.0, 0.001)
	assert_almost_eq(float(s0["air_time_ratio"]), 0.5, 0.001)
	assert_almost_eq(float(s0["avg_nearest_opponent_dist"]), 5.0, 0.001, "mean of 9.5 .. 0.5")
	assert_eq(s0["item_hold_ticks"], {"bat": 10})
	assert_almost_eq(float(s1["edge_time_ratio"]), 1.0, 0.001, "9.5 of 10 is past 80 %")
	assert_eq(s1["item_hold_ticks"], {})


func test_ko_fighters_are_skipped() -> void:
	var feats := SpatialFeatures.new(2)
	feats.observe([], [_f(0, Vector3.ZERO), _f(1, Vector3(3, 0, 0), {"state": S.KO})], 10.0)
	assert_null(feats.summary(0)["avg_nearest_opponent_dist"], "no living opponent")
	assert_almost_eq(float(feats.summary(1)["air_time_ratio"]), 0.0, 0.001)


func test_combo_counts_hits_while_the_target_is_in_hitstun() -> void:
	var flow := FlowFeatures.new(2)
	var idle := [_f(0, Vector3.ZERO), _f(1, Vector3.ONE)]
	var stunned := [_f(0, Vector3.ZERO), _f(1, Vector3.ONE, {"state": S.HITSTUN})]
	var hit := {"type": "hit", "attacker": 0, "target": 1, "pos": Vector3.ZERO}
	flow.observe(1, [hit], idle, stunned)
	flow.observe(2, [hit], stunned, stunned)
	flow.observe(3, [hit], stunned, stunned)
	flow.observe(9, [hit], idle, stunned)
	assert_eq(flow.summary(0, "loss")["max_combo"], 3)


func test_first_blood_comeback_and_pickups() -> void:
	var flow := FlowFeatures.new(2)
	var even := [_f(0, Vector3.ZERO), _f(1, Vector3(1, 0, 0))]
	flow.observe(10, [{"type": "item_pickup", "id": 4, "kind": 0, "fighter": 0, "pos": Vector3.ZERO}], even, even)
	flow.observe(20, [{"type": "ringout", "id": 0, "attacker_slot": 1, "pos": Vector3.ZERO, "stocks_left": 2}],
			even, [_f(0, Vector3.ZERO, {"stocks": 2}), _f(1, Vector3(1, 0, 0))])
	flow.observe(30, [{"type": "item_pickup", "id": 5, "kind": 0, "fighter": 1, "pos": Vector3(9, 0, 0)}], even,
			[_f(0, Vector3.ZERO, {"stocks": 2}), _f(1, Vector3(9, 0, 0))])
	var s0 := flow.summary(0, "win")
	var s1 := flow.summary(1, "loss")
	assert_true(s1["first_blood"])
	assert_false(s0["first_blood"])
	assert_true(s0["comeback_win"], "won after trailing by a stock")
	assert_false(s1["comeback_win"])
	assert_eq(s0["first_item_tick"], 10)
	assert_eq(s0["contested_pickups"], 1, "slot 1 stood 1 m away")
	assert_eq(s1["contested_pickups"], 0)
	assert_null(FlowFeatures.new(1).summary(0, "win")["first_item_tick"])


func test_abandon_context() -> void:
	var flow := FlowFeatures.new(2)
	var fighters := [_f(0, Vector3.ZERO, {"stocks": 1}), _f(1, Vector3.ZERO, {"stocks": 3})]
	flow.observe(60, [{"type": "ringout", "id": 0, "attacker_slot": -1, "pos": Vector3.ZERO, "stocks_left": 1}],
			fighters, fighters)
	var ctx := flow.abandon_context(0, fighters, 120)
	assert_eq(ctx["stock_diff"], -2)
	assert_eq(ctx["ms_since_last_ringout"], 1000)
	assert_eq(FlowFeatures.new(2).abandon_context(0, fighters, 5)["ms_since_last_ringout"], -1)


func test_match_features_combine_rates_from_the_slot_summary() -> void:
	var feats := MatchFeatures.new(1)
	var base := {"hits": 3, "whiffs": 1, "damage_dealt": 30.0, "result": "win"}
	var s := feats.summary(0, base, MINUTE)
	assert_almost_eq(float(s["hit_accuracy"]), 0.75, 0.001)
	assert_almost_eq(float(s["damage_per_min"]), 30.0, 0.001)
	assert_null(feats.summary(0, {"hits": 0, "whiffs": 0, "damage_dealt": 0.0, "result": "win"}, MINUTE)["hit_accuracy"])
	for key: String in MatchFeatures.COLUMNS:
		assert_true(s.has(key), "summary has %s" % key)
