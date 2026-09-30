extends GutTest
## Offline replay verification (platform A7, analytics-strategy §1): a match export (header +
## match_inputs rows) re-run in a fresh World must end on the recorded final_state_hash; anything
## else is a MISMATCH and the match is left out of analysis.

const BotMatchRun := preload("res://tests/unit/support/bot_match_run.gd")
const FIXTURE := "user://replay_fixture_test.json"
const ARENA := "log_bridge"
const TICKS := 1200

var _export: Dictionary = {}


func before_all() -> void:
	var run := BotMatchRun.play(ARENA, 2, 21, TICKS)
	_export = MatchExport.build(run["telemetry"])
	assert_eq(MatchExport.save(_export, FIXTURE), OK)


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))


func test_export_round_trips_through_a_json_file() -> void:
	var loaded := MatchExport.load_file(FIXTURE)
	assert_eq(loaded["format"], MatchExport.FORMAT)
	assert_eq(int(loaded["match"]["final_state_hash"]), int(_export["match"]["final_state_hash"]))
	assert_eq((loaded["inputs"] as Array).size(), 2)


func test_fixture_file_replays_ok() -> void:
	var result := ReplayVerifier.verify(MatchExport.load_file(FIXTURE), GameConfig.new())
	assert_true(result["ok"], ReplayVerifier.line(result))
	assert_eq(result["ticks"], int(_export["match"]["duration_ticks"]))
	assert_string_starts_with(ReplayVerifier.line(result), "OK")


func test_wrong_final_hash_is_a_mismatch() -> void:
	var tampered := _export.duplicate(true)
	tampered["match"]["final_state_hash"] = 1
	var result := ReplayVerifier.verify(tampered, GameConfig.new())
	assert_false(result["ok"])
	assert_eq(result["reason"], ReplayVerifier.REASON_HASH)
	assert_string_starts_with(ReplayVerifier.line(result), "MISMATCH")


func test_other_sim_config_is_refused_before_replaying() -> void:
	var other := GameConfig.new()
	other.move_speed += 0.5
	var result := ReplayVerifier.verify(_export, other)
	assert_false(result["ok"])
	assert_eq(result["reason"], ReplayVerifier.REASON_CONFIG)


func test_other_sim_version_is_refused() -> void:
	var old := _export.duplicate(true)
	old["match"]["sim_version"] = World.SNAPSHOT_VERSION - 1
	assert_eq(ReplayVerifier.verify(old, GameConfig.new())["reason"], ReplayVerifier.REASON_SIM_VERSION)


func test_broken_exports_are_errors_not_crashes() -> void:
	assert_eq(ReplayVerifier.verify({}, GameConfig.new())["reason"], ReplayVerifier.REASON_FORMAT)
	var no_inputs := _export.duplicate(true)
	no_inputs["inputs"] = []
	assert_eq(ReplayVerifier.verify(no_inputs, GameConfig.new())["reason"], ReplayVerifier.REASON_INPUTS)
	assert_true(MatchExport.load_file("user://does_not_exist.json").is_empty())


func test_verify_file_reads_the_fixture() -> void:
	assert_true(ReplayVerifier.verify_file(FIXTURE, GameConfig.new())["ok"])


func test_character_matches_replay_with_their_characters() -> void:
	var picks := {0: CharacterData.MAGE, 1: CharacterData.BARBARIAN}
	var run := BotMatchRun.play(ARENA, 2, 5, TICKS, null, picks)
	var export := MatchExport.build(run["telemetry"])
	assert_eq(export["players"][0]["character"], CharacterData.MAGE, "match_players carries the character")
	var result := ReplayVerifier.verify(export, GameConfig.new())
	assert_true(result["ok"], ReplayVerifier.line(result))
	var stripped := export.duplicate(true)
	for p: Dictionary in stripped["players"]:
		p["character"] = CharacterData.DEFAULT
	assert_eq(ReplayVerifier.verify(stripped, GameConfig.new())["reason"], ReplayVerifier.REASON_HASH,
			"the characters change the match, so the verifier must use them")


func test_exports_before_characters_reached_the_sim_replay_as_classic() -> void:
	var old := _export.duplicate(true)
	old["match"]["event_schema_version"] = ReplayVerifier.CHARACTERS_SINCE_SCHEMA - 1
	for p: Dictionary in old["players"]:
		p["character"] = "Knight"  # schema 4 stored the slot model name; the sim ran classic
	var result := ReplayVerifier.verify(old, GameConfig.new())
	assert_true(result["ok"], ReplayVerifier.line(result))
