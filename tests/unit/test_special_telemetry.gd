extends "res://tests/unit/support/special_telemetry_case.gd"
## Special-move tracking (Phase 5 T10, docs/tracking-plan.md §3.5): gauge_full, special_used and
## special_hit (one per activation, sent once its ring-out window is decided) plus the specials /
## special_hits slot counters, from a fixed synthetic sim event sequence.


func test_gauge_full_names_the_slot_character_and_match_time() -> void:
	_full(90, 1, "mage")
	assert_eq(_names(), ["match_started", "gauge_full"])
	var p := _props("gauge_full")
	assert_eq(p["slot"], 1)
	assert_eq(p["character"], "mage")
	assert_almost_eq(float(p["match_time_s"]), 1.5, 0.001)


func test_special_used_measures_time_since_full_and_the_nearest_foe_damage() -> void:
	_full(60, 0, "barbarian")
	_start(90, 0, "barbarian", SpecialCatalog.GROUND_SLAM)
	var p := _props("special_used")
	assert_eq(p["slot"], 0)
	assert_eq(p["character"], "barbarian")
	assert_eq(p["special"], SpecialCatalog.GROUND_SLAM)
	assert_eq(p["ms_since_full"], 500)
	assert_almost_eq(float(p["target_damage"]), 40.0, 0.001, "slot 1 is the nearest living foe")


func test_special_used_without_a_seen_gauge_full_reports_minus_one() -> void:
	_start(10, 2, "knight", SpecialCatalog.SPIN_SLASH)
	assert_eq(_props("special_used")["ms_since_full"], -1)


func test_special_hit_waits_for_the_ringout_window_then_reports_one_activation() -> void:
	_start(10, 2, "knight", SpecialCatalog.SPIN_SLASH)
	_special_hit(20, 2, 0, "knight", SpecialCatalog.SPIN_SLASH)
	_special_hit(21, 2, 1, "knight", SpecialCatalog.SPIN_SLASH)
	assert_false(_names().has("special_hit"), "held until the ring-out is decided")
	_frame(20 + StockLoss.WINDOW_TICKS + 1)
	assert_eq(_names().count("special_hit"), 1, "first hit of the activation only")
	var p := _props("special_hit")
	assert_eq(p["slot"], 2)
	assert_eq(p["character"], "knight")
	assert_eq(p["targets_hit"], 2)
	assert_eq(p["target_slot"], 0, "first target")
	assert_false(p["caused_ringout"])


func test_special_hit_followed_by_the_target_ringing_out_is_sent_at_once() -> void:
	_start(10, 0, "barbarian", SpecialCatalog.GROUND_SLAM)
	_special_hit(22, 0, 1, "barbarian", SpecialCatalog.GROUND_SLAM)
	_ringout(80, 1)
	assert_eq(_names().count("special_hit"), 1)
	assert_true(_props("special_hit")["caused_ringout"])
	_frame(400)
	assert_eq(_names().count("special_hit"), 1, "not sent twice")


func test_open_special_hit_is_flushed_before_match_ended() -> void:
	_start(10, 1, "mage", SpecialCatalog.BIG_FIREBALL)
	_special_hit(40, 1, 2, "mage", SpecialCatalog.BIG_FIREBALL)
	_view["match_over"] = true
	_view["winner"] = 1
	_t.end(_view)
	var names := _names()
	assert_true(names.find("special_hit") >= 0 and names.find("special_hit") < names.find("match_ended"))


func test_slot_summaries_count_specials_and_special_hits() -> void:
	_start(10, 0, "barbarian", SpecialCatalog.GROUND_SLAM)
	_special_hit(22, 0, 1, "barbarian", SpecialCatalog.GROUND_SLAM)
	_special_hit(22, 0, 2, "barbarian", SpecialCatalog.GROUND_SLAM)
	_start(300, 0, "barbarian", SpecialCatalog.GROUND_SLAM)
	_view["match_over"] = true
	_view["winner"] = 0
	_t.end(_view)
	var p0: Dictionary = _props("match_ended")["players"][0]
	assert_eq(p0["specials"], 2)
	assert_eq(p0["special_hits"], 2)
	assert_eq(_t.player_rows()[0]["specials"], 2, "match_players.specials")
	assert_eq(_t.player_rows()[0]["special_hits"], 2)
	assert_eq(_props("match_ended")["players"][1]["specials"], 0)
