extends GutTest
const PATH := "user://test_bot_progress.cfg"

func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)

func _setup() -> MatchSetup:
	return QuickMatchPrefs.new().build(1)

func test_completed_win_persists_and_duplicate_is_ignored() -> void:
	var progress := BotProgress.new(SettingsStore.new(PATH))
	var setup := _setup()
	assert_string_contains(progress.record(setup, {"match_over": true, "winner": 0}, "a"), "+30 XP")
	var restored := BotProgress.new(SettingsStore.new(PATH))
	assert_eq(restored.summary(CharacterData.BARBARIAN)["wins"], 1)
	assert_eq(restored.record(setup, {"match_over": true, "winner": 0}, "a"), "")
	assert_eq(restored.summary(CharacterData.BARBARIAN)["played"], 1)

func test_incomplete_and_other_modes_do_not_award_progress() -> void:
	var progress := BotProgress.new()
	var setup := _setup()
	assert_eq(progress.record(setup, {"match_over": false}, "a"), "")
	setup.mode = MatchSetup.MODE_ONLINE
	assert_eq(progress.record(setup, {"match_over": true, "winner": 0}, "b"), "")
	setup = MatchSetup.local_versus()
	assert_eq(progress.record(setup, {"match_over": true, "winner": 0}, "c"), "")
	assert_eq(progress.summary(CharacterData.BARBARIAN)["played"], 0)

func test_team_victory_counts_teammate_and_draw_is_not_a_loss() -> void:
	var progress := BotProgress.new()
	var setup := _setup()
	setup.set_rule(MatchRules.TEAM)
	setup.assign_characters({0: CharacterData.MAGE})
	progress.record(setup, {"match_over": true, "winner": 2}, "a")
	progress.record(setup, {"match_over": true, "winner": Rules.DRAW}, "b")
	var stats := progress.summary(CharacterData.MAGE)
	assert_eq(stats["wins"], 1)
	assert_eq(stats["draws"], 1)
	assert_eq(stats["losses"], 0)
	assert_eq(stats["xp"], 50)

func test_level_up_and_recent_history_are_bounded_and_newest_first() -> void:
	var progress := BotProgress.new()
	for i: int in 6:
		progress.record(_setup(), {"match_over": true, "winner": 0}, str(i))
	var reward := progress.record(_setup(), {"match_over": true, "winner": 1}, "last")
	assert_string_contains(reward, "레벨 업!")
	assert_eq(progress.summary(CharacterData.BARBARIAN)["level"], 3)
	assert_eq(progress.summary(CharacterData.BARBARIAN)["within"], 0)
	assert_eq(progress.recent().size(), 5)
	assert_eq(progress.recent()[0], "패")

func test_malformed_saved_counters_are_safe() -> void:
	var store := SettingsStore.new(PATH)
	store.set_value("bot_progress", "history", {"barbarian": {"played": -2, "wins": "bad"}, "recent": [42, "승", "invalid"]})
	var progress := BotProgress.new(store)
	assert_eq(progress.summary(CharacterData.BARBARIAN)["level"], 1)
	assert_eq(progress.recent(), ["승"] as Array[String])
	assert_string_contains(progress.record(_setup(), {"match_over": true, "winner": 0}, "a"), "+30 XP")

func test_challenges_use_only_local_stats_and_persist_without_duplicate_awards() -> void:
	var progress := BotProgress.new(SettingsStore.new(PATH))
	var rows: Array[Dictionary] = [
		{"slot": 1, "ringouts_scored": 99, "special_hits": 99},
		{"slot": 0, "ringouts_scored": 6, "special_hits": 8}]
	var first := progress.record(_setup(), {"match_over": true, "winner": 0}, "a", rows)
	assert_string_contains(first, "첫 승리")
	assert_false(first.contains("밀어내기 달인"))
	assert_eq(progress.summary(CharacterData.BARBARIAN)["ringouts"], 6)
	progress = BotProgress.new(SettingsStore.new(PATH))
	var second := progress.record(_setup(), {"match_over": true, "winner": 1}, "b", rows)
	assert_string_contains(second, "밀어내기 달인")
	assert_false(second.contains("첫 승리"))
	assert_eq(progress.record(_setup(), {"match_over": true, "winner": 0}, "b", rows), "")
	assert_eq(progress.summary(CharacterData.BARBARIAN)["ringouts"], 12)
	var third := progress.record(_setup(), {"match_over": true, "winner": 1}, "c", rows)
	assert_string_contains(third, "필살기 전문가")
	assert_false(third.contains("밀어내기 달인"))
	assert_string_contains(CharacterChallenges.next_text(progress.summary(CharacterData.BARBARIAN)), "모두 달성")
	assert_true(CharacterChallenges.completed(progress.summary(CharacterData.MAGE)).is_empty())

func test_existing_saves_keep_wins_and_start_new_combat_counters_at_zero() -> void:
	var store := SettingsStore.new(PATH)
	store.set_value("bot_progress", "history", {"barbarian": {"played": 5, "wins": 3, "draws": 0}})
	var progress := BotProgress.new(store)
	var stats := progress.summary(CharacterData.BARBARIAN)
	assert_eq(stats["xp"], 130)
	assert_eq(stats["ringouts"], 0)
	assert_eq(CharacterChallenges.completed(stats), ["첫 승리"] as Array[String])
	var reward := progress.record(_setup(), {"match_over": true, "winner": 0}, "new")
	assert_false(reward.contains("첫 승리"))
	assert_eq(progress.summary(CharacterData.BARBARIAN)["wins"], 4)

func test_incomplete_match_does_not_add_challenge_counters() -> void:
	var progress := BotProgress.new()
	progress.record(_setup(), {"match_over": false}, "unfinished", [
		{"slot": 0, "ringouts_scored": 10, "special_hits": 20}])
	assert_eq(progress.summary(CharacterData.BARBARIAN)["ringouts"], 0)
	assert_true(CharacterChallenges.completed(progress.summary(CharacterData.BARBARIAN)).is_empty())
