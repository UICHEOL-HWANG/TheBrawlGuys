extends GutTest
## DDA (PRD-BOT-06): hysteresis, cooldown and step cap of the decision; only bots facing the
## human move; the exported models predict in GDScript what Python predicted (fixtures).

const HUMAN := 0
const PARITY_EPS := 1e-6


func _cfg() -> GameConfig:
	var c := GameConfig.new()
	c.dda_target_low = 0.45
	c.dda_target_high = 0.60
	c.dda_hysteresis = 0.05
	c.dda_gain = 0.6
	c.dda_max_step = 0.1
	c.dda_cooldown_s = 4.0
	return c


func test_inside_the_band_does_nothing() -> void:
	var plan := DdaController.decide(0.55, false, 10000, _cfg())
	assert_false(plan["adjusting"])
	assert_eq(plan["step"], 0.0)


func test_hysteresis_needs_a_clear_exit_then_runs_back_into_the_band() -> void:
	var c := _cfg()
	assert_false(DdaController.decide(0.63, false, 10000, c)["adjusting"], "0.63 is inside high + hysteresis")
	var plan := DdaController.decide(0.70, false, 10000, c)
	assert_true(plan["adjusting"])
	assert_gt(float(plan["step"]), 0.0, "player ahead -> bots harder")
	assert_eq(plan["reason"], DdaController.AHEAD)
	var still := DdaController.decide(0.62, true, 10000, c)
	assert_true(still["adjusting"], "keeps adjusting until back inside the band")
	assert_false(DdaController.decide(0.58, true, 10000, c)["adjusting"])


func test_step_is_capped_and_signed() -> void:
	var c := _cfg()
	assert_almost_eq(float(DdaController.decide(1.0, false, 10000, c)["step"]), c.dda_max_step, 1e-6)
	var low := DdaController.decide(0.0, false, 10000, c)
	assert_almost_eq(float(low["step"]), -c.dda_max_step, 1e-6)
	assert_eq(low["reason"], DdaController.BEHIND)
	var small := DdaController.decide(0.66, true, 10000, c)
	assert_almost_eq(float(small["step"]), c.dda_gain * (0.66 - 0.525), 1e-6)


func test_cooldown_blocks_steps() -> void:
	var c := _cfg()
	var ticks := roundi(c.dda_cooldown_s * SimTime.TICK_RATE)
	assert_eq(DdaController.decide(0.9, true, ticks - 1, c)["step"], 0.0)
	assert_ne(DdaController.decide(0.9, true, ticks, c)["step"], 0.0)


func test_relative_probability_is_even_at_the_fair_share() -> void:
	assert_almost_eq(DdaController.relative(0.25, 0.25), 0.5, 1e-6)
	assert_almost_eq(DdaController.relative(0.5, 0.5), 0.5, 1e-6)
	assert_eq(DdaController.relative(0.9, 0.25), 1.0)


## A model that only sees d_diff: a strong human (d_self high) wins.
func _model() -> LinearModel:
	return LinearModel.from_dict({"name": "t", "kind": "logistic", "features": ["d_diff"], "mean": [0.0],
		"scale": [0.1], "coef": [1.0], "intercept": 0.0})


func _team_view(tick: int) -> Dictionary:
	var fighters: Array = []
	for i: int in 4:
		fighters.append({"id": i, "pos": Vector3(i, 0, 0), "state": Fighter.State.IDLE, "damage": 0.0, "stocks": 3})
	return {"tick": tick, "arena_radius": 10.0, "fighters": fighters,
		"mode": {"rule": MatchRules.TEAM, "teams": [0, 1, 0, 1], "scores": []}}


func test_only_bots_facing_the_human_move() -> void:
	var c := _cfg()
	var bots := {}
	for slot: int in [1, 2, 3]:
		bots[slot] = BotController.new(slot, c, 0.3)
	var dda := DdaController.new(c, _model(), bots, [HUMAN] as Array[int], func(s: int) -> float:
		return 0.9 if s == HUMAN else bots[s].skill().d)
	var events := dda.step(_team_view(DdaController.interval_ticks(c) * 10))
	assert_eq(events.size(), 2, "the two foes, not the teammate")
	assert_almost_eq(bots[1].skill().d, 0.4, 1e-4)
	assert_almost_eq(bots[3].skill().d, 0.4, 1e-4)
	assert_almost_eq(bots[2].skill().d, 0.3, 1e-4, "teammate untouched")
	assert_eq(int(dda.adjustments[1]), 1)
	assert_eq(String(events[0]["reason"]), DdaController.AHEAD)


func test_only_evaluates_on_the_interval() -> void:
	var c := _cfg()
	var bots := {1: BotController.new(1, c, 0.3)}
	var dda := DdaController.new(c, _model(), bots, [HUMAN] as Array[int], func(s: int) -> float:
		return 0.9 if s == HUMAN else 0.3)
	assert_eq(dda.step(_team_view(DdaController.interval_ticks(c) + 1)).size(), 0)
	assert_eq(dda.win_prob(HUMAN), -1.0)


func test_features_match_the_python_names() -> void:
	var f := DdaFeatures.of(_team_view(120), HUMAN, {HUMAN: 0.8})
	assert_eq(f.keys().size(), DdaFeatures.FEATURES.size())
	for key: String in DdaFeatures.FEATURES:
		assert_true(f.has(key), key)
	assert_almost_eq(float(f["t"]), 2.0, 1e-6)
	assert_almost_eq(float(f["d_diff"]), 0.3, 1e-6)
	assert_eq(float(f["is_team"]), 1.0)
	assert_eq(float(f["side_stocks"]), 6.0, "team side = both teammates")


func _parity(path: String) -> void:
	var m := LinearModel.load_json(path)
	assert_not_null(m, "%s loads" % path)
	if m == null:
		return
	assert_gt(m.fixtures.size(), 0, "fixtures exported")
	for fx: Dictionary in m.fixtures:
		assert_almost_eq(m.predict(fx["x"]), float(fx["y"]), PARITY_EPS)


func test_win_prob_model_matches_python() -> void:
	_parity(BotSquadFactory.WIN_PROB_PATH)
	for key: String in LinearModel.load_json(BotSquadFactory.WIN_PROB_PATH).features:
		assert_true(DdaFeatures.FEATURES.has(key), "%s is built in GDScript" % key)


func test_skill_estimator_matches_python() -> void:
	_parity(BotSquadFactory.ESTIMATOR_PATH)
	for key: String in ProbeObserver.FEATURES:
		assert_true(LinearModel.load_json(BotSquadFactory.ESTIMATOR_PATH).features.has(key), key)
