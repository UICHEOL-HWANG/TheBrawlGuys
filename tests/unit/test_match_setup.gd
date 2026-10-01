extends GutTest
## MatchSetup (platform B1): the value object menu screens fill and the match scene reads.


func test_vs_bots_has_one_local_slot_and_bots() -> void:
	var s := MatchSetup.vs_bots(3, 7)
	assert_eq(s.mode, MatchSetup.MODE_BOT)
	assert_eq(s.arena_id, MatchSetup.ARENA_DEFAULT)
	assert_eq(s.seed, 7)
	assert_eq(s.player_count(), 3)
	assert_eq(s.local_slot(), 0)
	assert_eq(s.bot_slots(), [1, 2] as Array[int])
	assert_eq(s.slots[1]["controller"], MatchSetup.CONTROLLER_BOT)
	assert_eq(s.slots[1]["input_device"], MatchSetup.INPUT_BOT)
	assert_eq(s.slots[0]["character"], CharacterData.DEFAULT, "classic fighter until a character is picked")
	assert_eq(s.validate().size(), 0)


func test_all_bots_has_no_local_slot() -> void:
	var s := MatchSetup.all_bots(4, 3)
	assert_eq(s.local_slot(), -1)
	assert_eq(s.bot_slots().size(), 4)
	assert_eq(s.validate().size(), 0)


func test_validate_reports_problems() -> void:
	var s := MatchSetup.new()
	assert_gt(s.validate().size(), 0, "no slots")
	s = MatchSetup.vs_bots(2, 1)
	s.slots[1]["controller"] = "remote"
	assert_string_contains(s.validate()[0], "controller")
	s = MatchSetup.vs_bots(2, 1)
	s.slots[1]["slot"] = 5
	assert_string_contains(s.validate()[0], "slot")


func test_arena_id_selects_the_sim_arena() -> void:
	var cfg := GameConfig.new()
	var s := MatchSetup.vs_bots(2, 1)
	assert_eq(s.arena_id, ArenaCatalog.DEFAULT_ID)
	assert_eq(s.build_arena(cfg).id, ArenaCatalog.DEFAULT_ID)
	s.arena_id = "log_bridge"
	assert_eq(s.validate().size(), 0)
	assert_eq(s.build_arena(cfg).id, "log_bridge")
	s.arena_id = "nowhere"
	assert_string_contains(s.validate()[0], "arena")
	assert_eq(s.build_arena(cfg).id, ArenaCatalog.DEFAULT_ID, "unknown ids fall back to classic")


func test_copy_is_independent() -> void:
	var s := MatchSetup.vs_bots(2, 1)
	var c := s.copy()
	c.slots[0]["character"] = CharacterData.MAGE
	c.seed = 99
	assert_ne(s.slots[0]["character"], CharacterData.MAGE)
	assert_eq(s.seed, 1)


func test_telemetry_setup_comes_from_the_match_setup() -> void:
	var s := MatchSetup.vs_bots(3, 9)
	var t := TelemetrySetup.from_match_setup(s)
	assert_eq(t["mode"], MatchSetup.MODE_BOT)
	assert_eq(t["arena"], MatchSetup.ARENA_DEFAULT)
	assert_eq(t["seed"], 9)
	assert_eq(t["local_slot"], 0)
	var slots: Array = t["slots"]
	assert_eq(slots.size(), 3)
	assert_false(bool(slots[0]["is_bot"]))
	assert_true(bool(slots[2]["is_bot"]))
	assert_eq(slots[2]["input_device"], MatchSetup.INPUT_BOT)
	assert_eq(slots[1]["character"], s.slots[1]["character"])
	assert_false(String(t["match_id"]).is_empty())


func test_local_versus_has_two_local_slots_then_bots() -> void:
	var s := MatchSetup.local_versus(4, 5)
	assert_eq(s.mode, MatchSetup.MODE_LOCAL_2P)
	assert_eq(s.seed, 5)
	assert_eq(s.local_slots(), [0, 1] as Array[int])
	assert_eq(s.local_slot(), 0, "P1 is the primary local slot")
	assert_eq(s.bot_slots(), [2, 3] as Array[int], "optional bots fill the remaining slots")
	assert_eq(s.slots[1]["input_device"], MatchSetup.INPUT_KEYBOARD, "P2 starts on the keyboard")
	assert_eq(s.slots[1]["character"], CharacterData.DEFAULT, "classic until the character select fills it")
	assert_eq(s.validate().size(), 0)
	assert_eq(MatchSetup.local_versus().player_count(), 2, "1 vs 1 by default")


func test_input_devices_update_local_slots_only() -> void:
	var s := MatchSetup.local_versus(3)
	var before: Dictionary = s.slots[1]
	s.set_input_devices({0: "gamepad", 1: "gamepad", 2: "gamepad"})
	assert_eq(s.slots[0]["input_device"], "gamepad")
	assert_eq(s.slots[1]["input_device"], "gamepad")
	assert_eq(s.slots[2]["input_device"], MatchSetup.INPUT_BOT, "bots keep 'bot'")
	assert_eq(before["input_device"], MatchSetup.INPUT_KEYBOARD, "slot entries are replaced, not mutated")
	var t := TelemetrySetup.from_match_setup(s)
	assert_eq(t["slots"][1]["input_device"], "gamepad", "P2's device reaches the telemetry slots")


func test_characters_lists_each_slot_in_order() -> void:
	var s := MatchSetup.vs_bots(3, 1)
	assert_eq(s.characters(), ["", "", ""] as Array[String])
	s.assign_characters({0: CharacterData.MAGE})
	assert_eq(s.characters()[0], CharacterData.MAGE)


func test_assign_characters_gives_bots_distinct_characters_from_the_seed() -> void:
	var s := MatchSetup.vs_bots(4, 11)
	var before: Dictionary = s.slots[1]
	s.assign_characters({0: CharacterData.KNIGHT})
	var picks := s.characters()
	assert_eq(picks[0], CharacterData.KNIGHT, "the human keeps the pick")
	for id: String in picks:
		assert_true(CharacterData.IDS.has(id), "every slot plays a real character")
	var unique := {}
	for id: String in picks:
		unique[id] = true
	assert_eq(unique.size(), 4, "four players, four different characters")
	assert_eq(before["character"], CharacterData.DEFAULT, "slot entries are replaced, not mutated")
	var again := MatchSetup.vs_bots(4, 11)
	again.assign_characters({0: CharacterData.KNIGHT})
	assert_eq(again.characters(), picks, "same seed and picks: same bot characters")
	var first := MatchSetup.vs_bots(2, 1)
	first.assign_characters({0: CharacterData.KNIGHT})
	var seeds_differ := false
	for seed: int in range(2, 20):
		var other := MatchSetup.vs_bots(2, seed)
		other.assign_characters({0: CharacterData.KNIGHT})
		seeds_differ = seeds_differ or other.characters()[1] != first.characters()[1]
		assert_ne(other.characters()[1], CharacterData.KNIGHT, "a bot avoids the human's character")
	assert_true(seeds_differ, "the seed changes which character a bot gets")


func test_assign_characters_allows_humans_to_share_a_character() -> void:
	var s := MatchSetup.local_versus(4, 3)
	s.assign_characters({0: CharacterData.ROGUE, 1: CharacterData.ROGUE})
	var picks := s.characters()
	assert_eq([picks[0], picks[1]], [CharacterData.ROGUE, CharacterData.ROGUE], "a mirror match is allowed")
	assert_false(picks.slice(2).has(CharacterData.ROGUE), "bots take the characters left over")
	assert_ne(picks[2], picks[3])


func test_validate_rejects_unknown_characters() -> void:
	var s := MatchSetup.vs_bots(2, 1)
	s.slots[1] = s.slots[1].merged({"character": "wizard"}, true)
	assert_string_contains(s.validate()[0], "character")


func test_rule_defaults_to_stock_and_copies() -> void:
	var s := MatchSetup.vs_bots(2, 1)
	assert_eq(s.rule, MatchRules.STOCK)
	s.set_rule(MatchRules.TIMED)
	assert_eq(s.copy().rule, MatchRules.TIMED)


func test_team_rule_fills_four_slots_with_bots() -> void:
	var s := MatchSetup.local_versus(2, 1)
	s.set_rule(MatchRules.TEAM)
	assert_eq(s.player_count(), 4)
	assert_eq(s.local_slots(), [0, 1] as Array[int], "humans keep their slots")
	assert_eq(s.bot_slots(), [2, 3] as Array[int])
	assert_true(s.validate().is_empty(), str(s.validate()))
	var rules := s.build_rules(GameConfig.new())
	assert_eq(rules.mode, MatchRules.TEAM)
	assert_eq(rules.teams, [0, 1, 0, 1] as Array[int])


func test_back_to_stock_shrinks_the_line_up() -> void:
	var s := MatchSetup.vs_bots(2, 1)
	s.set_rule(MatchRules.TEAM)
	s.set_rule(MatchRules.STOCK)
	assert_eq(s.player_count(), MatchSetup.DEFAULT_PLAYERS)
	assert_eq(s.build_rules(GameConfig.new()).mode, MatchRules.STOCK)


func test_validate_rejects_team_without_four_slots() -> void:
	var s := MatchSetup.vs_bots(2, 1)
	s.rule = MatchRules.TEAM
	assert_false(s.validate().is_empty())
	s.rule = "nope"
	assert_string_contains(s.validate()[0], "rule")
