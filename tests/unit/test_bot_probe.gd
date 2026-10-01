extends GutTest
## Opening probe (PRD-BOT-05): the stage machine walks frontal -> edge -> ranged -> punish on its
## clock, ProbeObserver turns views into reaction / response / tech / punish features, and the
## probing bot plays the script only while the probe is active.

const BOT := 1
const TARGET := 0


func _fighter(id: int, pos: Vector3, state: int, damage: float = 0.0) -> Dictionary:
	return {"id": id, "pos": pos, "facing": Vector3(-1, 0, 0) if id == BOT else Vector3(1, 0, 0), "state": state,
		"on_ground": true, "jumps_left": 2, "item_kind": Fighter.NONE, "invuln_ticks": 0, "damage": damage,
		"stocks": 3, "tumbling": false, "is_dodging": false, "style": "", "special": "", "gauge": 0.0}


func _view(tick: int, bot_state: int = Fighter.State.IDLE, target_state: int = Fighter.State.IDLE,
		bot_damage: float = 0.0) -> Dictionary:
	return {"tick": tick, "arena_radius": 10.0, "items": [], "fighters": [
		_fighter(TARGET, Vector3(0, 0, 0), target_state), _fighter(BOT, Vector3(1.5, 0, 0), bot_state, bot_damage)]}


func test_stages_advance_on_the_clock_and_report_results() -> void:
	var probe := BotProbe.new(BOT, TARGET, GameConfig.new(), 10)
	assert_true(probe.active())
	assert_eq(probe.stage_name(), "frontal")
	var ended: Array[String] = []
	for t: int in 41:
		var e := probe.observe(_view(100 + t))
		if not e.is_empty():
			ended.append(String(e["stage"]))
			for key: String in ProbeObserver.FEATURES:
				assert_true((e["result"] as Dictionary).has(key), key)
	assert_eq(ended, BotProbe.STAGES)
	assert_false(probe.active())
	assert_eq(probe.stage_name(), "done")
	assert_eq(probe.observe(_view(200)), {}, "nothing after the last stage")


func test_observer_measures_a_guard_reaction() -> void:
	var obs := ProbeObserver.new(BOT, TARGET)
	obs.observe(_view(0))
	obs.observe(_view(1, Fighter.State.ATTACK))
	for t: int in range(2, 6):
		obs.observe(_view(t, Fighter.State.ATTACK))
	obs.observe(_view(6, Fighter.State.ATTACK, Fighter.State.GUARD))
	var f := ProbeObserver.features(obs.total)
	assert_eq(int(obs.total["threats"]), 1)
	assert_almost_eq(float(f["react_ticks"]), 5.0, 0.001)
	assert_almost_eq(float(f["response_rate"]), 1.0, 0.001)


func test_unanswered_threat_counts_without_a_reaction() -> void:
	var obs := ProbeObserver.new(BOT, TARGET)
	obs.observe(_view(0))
	obs.observe(_view(1, Fighter.State.ATTACK))
	for t: int in range(2, 60):
		obs.observe(_view(t))
	var f := ProbeObserver.features(obs.total)
	assert_eq(float(f["response_rate"]), 0.0)
	assert_eq(float(f["react_ticks"]), ProbeObserver.NO_REACTION_TICKS)


func test_whiff_punished_in_time() -> void:
	var obs := ProbeObserver.new(BOT, TARGET)
	obs.observe(_view(0))
	obs.mark_whiff(1)
	obs.observe(_view(1))
	obs.observe(_view(20, Fighter.State.HITSTUN, Fighter.State.IDLE, 8.0))
	obs.mark_whiff(100)
	obs.observe(_view(100, Fighter.State.IDLE, Fighter.State.IDLE, 8.0))
	obs.observe(_view(200, Fighter.State.IDLE, Fighter.State.IDLE, 8.0))
	assert_almost_eq(float(ProbeObserver.features(obs.total)["punish_rate"]), 0.5, 0.001)


func test_features_never_nan_without_samples() -> void:
	var f := ProbeObserver.features(ProbeObserver.new_counters())
	for key: String in ProbeObserver.FEATURES:
		assert_false(is_nan(float(f[key])), key)


func test_probing_bot_follows_the_script_then_plays_normally() -> void:
	var bot := BotController.new(BOT, GameConfig.new(), 0.5)
	bot.probe = BotProbe.new(BOT, TARGET, GameConfig.new(), 5)
	bot.sample(_view(1))
	assert_string_starts_with(bot.intent().name, "probe_")
	for t: int in 25:
		bot.probe.observe(_view(t))
	bot.sample(_view(30))
	assert_false(bot.intent().name.begins_with("probe_"), "back to normal play after the probe")
