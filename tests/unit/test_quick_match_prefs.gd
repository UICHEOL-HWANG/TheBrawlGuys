extends GutTest

const PATH := "user://test_quick_match_prefs.cfg"

func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)

func test_default_is_a_valid_fresh_bot_match() -> void:
	var setup := QuickMatchPrefs.new().build(817)
	assert_eq(setup.seed, 817)
	assert_eq(setup.local_slots(), [0] as Array[int])
	assert_eq(setup.characters()[0], CharacterData.BARBARIAN)
	assert_true(setup.validate().is_empty())
	assert_ne(setup.characters()[0], setup.characters()[1])

func test_remembers_selection_across_reload_without_restoring_seed_or_devices() -> void:
	var store := SettingsStore.new(PATH)
	var prefs := QuickMatchPrefs.new(store)
	var setup := MatchSetup.vs_bots(2, 11)
	setup.set_rule(MatchRules.TEAM)
	setup.set_teams([0, 0, 1, 1])
	setup.arena_id = ArenaCatalog.STAGE_IDS[2]
	setup.assign_characters({0: CharacterData.MAGE})
	setup.set_input_devices({0: "gamepad:7"})
	prefs.remember(setup)
	var restored := QuickMatchPrefs.new(store).build(99)
	assert_eq(restored.seed, 99)
	assert_eq(restored.rule, MatchRules.TEAM)
	assert_eq(restored.teams, [0, 0, 1, 1] as Array[int])
	assert_eq(restored.arena_id, setup.arena_id)
	assert_eq(restored.characters()[0], CharacterData.MAGE)
	assert_eq(restored.slots[0]["input_device"], PlatformEnv.default_input_device())
	assert_true(restored.validate().is_empty())
	restored.teams[0] = 1
	assert_eq(prefs.build(100).teams[0], 0)

func test_corrupt_preferences_fall_back_to_playable_defaults() -> void:
	var store := SettingsStore.new(PATH)
	store.set_value("quick_match", "selection", {"rule": 8, "arena": "removed", "character": [], "teams": [null]})
	var setup := QuickMatchPrefs.new(store).build(1)
	assert_eq(setup.rule, MatchRules.STOCK)
	assert_true(setup.validate().is_empty())
	store.set_value("quick_match", "selection", {"rule": MatchRules.TEAM, "teams": [0, "0", 1, 1]})
	setup = QuickMatchPrefs.new(store).build(1)
	assert_true(setup.validate().is_empty())
	assert_eq(setup.team_split(), MatchRules.default_teams(4))

func test_local_versus_does_not_replace_bot_preferences() -> void:
	var prefs := QuickMatchPrefs.new()
	var setup := MatchSetup.local_versus()
	setup.assign_characters({0: CharacterData.MAGE, 1: CharacterData.KNIGHT})
	prefs.remember(setup)
	assert_eq(prefs.build(1).characters()[0], CharacterData.BARBARIAN)

func test_highlights_only_include_local_players() -> void:
	var rows: Array[Dictionary] = [
		{"slot": 0, "ringouts_scored": 3, "items_used": 2, "special_hits": 1},
		{"slot": 1, "ringouts_scored": 1, "items_used": 0, "special_hits": 4},
		{"slot": 2, "ringouts_scored": 9}]
	var words := ResultHighlights.lines(rows, [0, 1])
	assert_string_contains(words, "P1 · 링아웃 3회")
	assert_string_contains(words, "P2 · 링아웃 1회")
	assert_false(words.contains("P3"))


func test_lobby_character_pick_preserves_team_rule_arena_and_survives_reload() -> void:
	var store := SettingsStore.new(PATH)
	var prefs := QuickMatchPrefs.new(store)
	var setup := MatchSetup.vs_bots()
	setup.set_rule(MatchRules.TEAM)
	setup.set_teams([0, 0, 1, 1])
	setup.arena_id = ArenaCatalog.STAGE_IDS[2]
	setup.assign_characters({0: CharacterData.BARBARIAN})
	prefs.remember(setup)
	prefs.choose_character(CharacterData.MAGE)
	prefs.choose_character("invalid")
	var restored := QuickMatchPrefs.new(store).build(812)
	assert_eq(restored.characters()[0], CharacterData.MAGE)
	assert_eq(restored.rule, setup.rule)
	assert_eq(restored.arena_id, setup.arena_id)
	assert_eq(restored.teams, setup.teams)
	assert_true(restored.validate().is_empty())
	assert_eq(restored.characters().count(CharacterData.MAGE), 1)
