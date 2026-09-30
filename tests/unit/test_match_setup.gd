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
	assert_eq(s.slots[0]["character"], String(CharacterCatalog.for_player(0)["name"]))
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
	c.slots[0]["character"] = "Mage"
	c.seed = 99
	assert_ne(s.slots[0]["character"], "Mage")
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
