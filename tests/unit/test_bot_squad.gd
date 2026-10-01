extends GutTest
## BotSquad (PRD-BOT-04~06): variants, the probe hand-off, bot tracking rows and summaries, the
## persisted skill rating and the A/B bucket. Played on a real World so the views are genuine.

const HUMAN := 0


func _play(squad: BotSquad, ticks: int, telemetry: MatchTelemetry = null) -> World:
	var config := GameConfig.new()
	var chars: Array[String] = ["barbarian", "knight"]
	var w := World.new(config, 3, 2, null, chars)
	var human := BotController.new(HUMAN, config, 0.6)
	var view := w.state_view()
	for i: int in ticks:
		w.tick([human.sample(view), squad.sample(1, view)] as Array[InputFrame])
		view = w.state_view()
		if telemetry != null:
			telemetry.on_frame(view["events"], [], view)
		squad.after_tick(view, telemetry)
	return w


func _squad(variant: String, rating: SkillRating = null, probe: bool = true) -> BotSquad:
	var c := GameConfig.new()
	c.dda_probe_stage_s = 1.0
	return BotSquad.new(c, [1] as Array[int], [HUMAN] as Array[int], {"variant": variant, "probe": probe,
		"rating": rating, "win_prob": BotSquadFactory.model(BotSquadFactory.WIN_PROB_PATH),
		"estimator": BotSquadFactory.model(BotSquadFactory.ESTIMATOR_PATH)})


func test_bot_only_match_has_no_variant() -> void:
	var s := BotSquad.new(GameConfig.new(), [0, 1] as Array[int], [] as Array[int], {"variant": BotSquad.ON, "d": 0.3})
	assert_eq(s.variant(), BotSquad.NONE)
	assert_eq(s.context()["dda_variant"], null)
	assert_almost_eq(s.bot(1).skill().d, 0.3, 1e-6)


func test_probe_estimates_and_on_arm_starts_from_it() -> void:
	var s := _squad(BotSquad.ON)
	_play(s, 4 * 60 + 5)
	var summary := s.slot_summary(1)
	assert_eq(summary["probe_target_slot"], HUMAN)
	assert_not_null(summary["probe_estimate"], "estimator ran")
	assert_eq((summary["probe_features"] as Dictionary).size(), ProbeObserver.FEATURES.size())
	assert_almost_eq(s.bot(1).skill().d, float(summary["probe_estimate"]), 0.11, "start from the estimate (DDA may nudge once)")


func test_off_arm_keeps_the_normal_preset() -> void:
	var s := _squad(BotSquad.OFF)
	_play(s, 4 * 60 + 70)
	assert_almost_eq(s.bot(1).skill().d, BotDifficulty.d_of("normal"), 1e-6)
	assert_eq(int(s.slot_summary(1)["dda_adjustments"]), 0)


func test_tracking_rows_reach_telemetry_and_summary_keys_are_complete() -> void:
	var s := _squad(BotSquad.ON)
	var t := MatchTelemetry.new(func(_n: String, _p: Variant) -> void: pass)
	var setup := MatchSetup.vs_bots(2, 3)
	t.begin(TelemetrySetup.from_match_setup(setup, GameConfig.new(), s.context()))
	t.set_slot_extras(s.slot_summary)
	_play(s, 5 * 60, t)
	var types := {}
	for r: Dictionary in t.event_rows():
		types[r["type"]] = int(types.get(r["type"], 0)) + 1
	assert_eq(int(types.get("probe_stage", 0)), BotProbe.STAGES.size())
	assert_gt(int(types.get("bot_intent", 0)), 0)
	t.end({"tick": 300, "match_over": false, "winner": -1, "fighters": []}, true)
	for row: Dictionary in t.player_rows():
		for key: String in EventCatalog.BOT_TRACKING_KEYS:
			assert_true(row.has(key), key)
	assert_eq(t.match_row()["dda_variant"], BotSquad.ON)


func test_intent_rows_are_capped() -> void:
	var tracker := BotTracker.new(3, 1)
	var bot := BotController.new(1, GameConfig.new(), 0.5)
	var logged := 0
	for tick: int in 200:
		bot.intent().say("a" if tick % 2 == 0 else "b", InputFrame.neutral())
		logged += 0 if tracker.sample(tick, 1, bot).is_empty() else 1
	assert_eq(logged, 3)
	assert_eq(tracker.rows_logged(), 3)


func test_rating_persists_and_blends() -> void:
	var path := "user://test_skill_rating.cfg"
	var r := SkillRating.new(path)
	assert_eq(r.matches(), 0)
	assert_eq(r.record(0.8, 0.3), 0.8, "first observation taken as is")
	assert_almost_eq(r.record(0.2, 0.5), 0.5, 1e-6)
	var again := SkillRating.new(path)
	assert_eq(again.matches(), 2)
	assert_almost_eq(again.rating(), 0.5, 1e-6)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_finish_moves_the_rating_toward_the_result() -> void:
	var rating := SkillRating.new()
	var s := _squad(BotSquad.ON, rating)
	_play(s, 4 * 60 + 5)
	s.finish({"match_over": false})
	assert_eq(rating.matches(), 0, "unfinished matches do not count")
	var bot_d := s.bot(1).skill().d
	s.finish({"match_over": true, "winner": HUMAN})
	assert_eq(rating.matches(), 1)
	assert_almost_eq(rating.rating(), clampf(bot_d + GameConfig.new().dda_rating_result_step, 0.0, 1.0), 1e-3,
		"a win puts the human above the bots' d")
	var next := _squad(BotSquad.ON, rating, false)
	assert_almost_eq(next.bot(1).skill().d, rating.rating(), 1e-6, "next match starts from the rating")
	assert_almost_eq(float(next.slot_summary(HUMAN)["skill_rating"]), rating.rating(), 1e-6)


func test_variant_bucket_is_stable_and_settings_win() -> void:
	var c := GameConfig.new()
	var a := BotSquadFactory.variant(c, "auto", "device-a")
	assert_eq(BotSquadFactory.variant(c, "auto", "device-a"), a)
	assert_eq(BotSquadFactory.variant(c, "on", "device-a"), BotSquad.ON)
	assert_eq(BotSquadFactory.variant(c, "off", "device-a"), BotSquad.OFF)
	c.dda_on_share = 1.0
	assert_eq(BotSquadFactory.variant(c, "auto", "device-b"), BotSquad.ON)
	c.dda_enabled = 0
	assert_eq(BotSquadFactory.variant(c, "on", "device-b"), BotSquad.OFF)
	var on := 0
	c = GameConfig.new()
	for i: int in 400:
		on += 1 if BotSquadFactory.variant(c, "auto", "dev%d" % i) == BotSquad.ON else 0
	assert_between(on, 160, 240, "about dda_on_share of devices")
