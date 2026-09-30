extends "res://tests/unit/support/special_telemetry_case.gd"
## special_hit.caused_ringout edge cases (Phase 5 T10): only the ring-out credited to the caster
## (StockLoss last attacker) counts, same-tick ring-outs, later targets, a second special of the
## same slot, dead time left out of ms_since_full, malformed events, and the sim's event order.


func test_ringout_credited_to_someone_else_is_not_caused_by_the_special() -> void:
	_start(10, 0, "barbarian", SpecialCatalog.GROUND_SLAM)
	_special_hit(22, 0, 1, "barbarian", SpecialCatalog.GROUND_SLAM)
	_frame(40, [{"type": "hit", "attacker": 2, "target": 1, "attack_kind": K.HEAVY, "pos": Vector3.ZERO}])
	_ringout(80, 1)
	assert_false(_names().has("special_hit"), "slot 2 got the ring-out credit (StockLoss last attacker)")
	_frame(22 + StockLoss.WINDOW_TICKS + 1)
	assert_false(_props("special_hit")["caused_ringout"])


func test_gimmick_ringout_is_not_caused_by_the_special() -> void:
	_start(10, 0, "barbarian", SpecialCatalog.GROUND_SLAM)
	_special_hit(22, 0, 1, "barbarian", SpecialCatalog.GROUND_SLAM)
	_frame(60, [{"type": "gimmick_damage", "kind": "campfire", "target": 1, "pos": Vector3.ZERO}])
	_ringout(80, 1)
	_t.end(_view, true)
	assert_false(_props("special_hit")["caused_ringout"])


func test_same_tick_hit_and_ringout_is_caused_by_the_special() -> void:
	_start(10, 1, "mage", SpecialCatalog.BIG_FIREBALL)
	var hit := [
		{"type": "hit", "attacker": 1, "target": 2, "attack_kind": K.SPECIAL, "pos": Vector3.ZERO},
		{"type": "special_hit", "attacker": 1, "target": 2, "pos": Vector3.ZERO, "knockback": 9.0,
			"character": "mage", "special": SpecialCatalog.BIG_FIREBALL},
	]
	_ringout(30, 2, hit)
	assert_eq(_names().count("special_hit"), 1)
	assert_true(_props("special_hit")["caused_ringout"])


func test_ringout_of_a_later_target_counts() -> void:
	_start(10, 2, "knight", SpecialCatalog.SPIN_SLASH)
	_special_hit(20, 2, 0, "knight", SpecialCatalog.SPIN_SLASH)
	_special_hit(24, 2, 1, "knight", SpecialCatalog.SPIN_SLASH)
	_ringout(70, 1)
	var p := _props("special_hit")
	assert_true(p["caused_ringout"])
	assert_eq(p["targets_hit"], 2)
	assert_eq(p["target_slot"], 0)


func test_second_special_of_the_same_slot_sends_the_open_one_first() -> void:
	_start(10, 0, "barbarian", SpecialCatalog.GROUND_SLAM)
	_special_hit(22, 0, 1, "barbarian", SpecialCatalog.GROUND_SLAM)
	_start(60, 0, "barbarian", SpecialCatalog.GROUND_SLAM)
	var names := _names()
	assert_eq(names.count("special_hit"), 1)
	assert_lt(names.find("special_hit"), names.rfind("special_used"), "sent before the second special_used")
	assert_false(_props("special_hit")["caused_ringout"])


func test_malformed_events_are_skipped_not_fatal() -> void:
	_frame(5, [{"type": "special_start"}, {"type": "special_hit", "attacker": 0}, {"type": "gauge_full"}])
	assert_eq(_names(), ["match_started"])
	assert_push_warning("SpecialTelemetry")


func test_ms_since_full_leaves_out_time_spent_ko() -> void:
	_full(60, 0, "barbarian")
	_frame(100, [], {0: {"state": S.KO}})
	_frame(160, [], {0: {"state": S.AIR}})
	_start(180, 0, "barbarian", SpecialCatalog.GROUND_SLAM)
	assert_eq(_props("special_used")["ms_since_full"], 1000, "120 ticks minus 60 ticks KO")


func test_sim_emits_a_tick_s_hits_before_its_ringouts() -> void:
	var config := GameConfig.new()
	var chars: Array[String] = CharacterData.IDS.duplicate()
	var w := World.new(config, 11, 4, null, chars)
	var bots: Array[BotController] = []
	for i: int in 4:
		bots.append(BotController.new(i, config))
	var checked := 0
	while not w.match_over and w.tick_count < 7200:
		var inputs: Array[InputFrame] = []
		for b: BotController in bots:
			inputs.append(b.sample(w.state_view()))
		w.tick(inputs)
		var types: Array = (w.state_view()["events"] as Array).map(func(e: Dictionary) -> String: return e["type"])
		var first_ringout := types.find("ringout")
		if first_ringout >= 0:
			checked += 1
			for kind: String in ["hit", "special_hit", "guard_hit"]:
				assert_true(types.rfind(kind) < first_ringout, "tick %d: %s after a ringout" % [w.tick_count, kind])
	assert_gt(checked, 0, "some ring-outs happened")
