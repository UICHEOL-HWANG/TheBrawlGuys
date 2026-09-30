extends GutTest
## Reproducibility header (platform A7, analytics-strategy §1 "재현성 계약"): everything a headless
## replay needs, plus the identity/version stamps every analysis joins on.


func _setup() -> Dictionary:
	var config := GameConfig.new()
	var context := {"session_id": 1_700_000_000_000, "user_match_seq": 4, "loss_streak": 2}
	return TelemetrySetup.from_match_setup(MatchSetup.vs_bots(3, 9), config, context)


func test_header_carries_the_replay_contract() -> void:
	var t := _setup()
	assert_eq(t["seed"], 9)
	assert_eq(t["arena"], MatchSetup.ARENA_DEFAULT)
	assert_eq(t["config_fingerprint"], GameConfig.new().fingerprint())
	assert_eq(t["sim_version"], World.SNAPSHOT_VERSION)
	assert_eq(t["event_schema_version"], EventCatalog.SCHEMA_VERSION)
	assert_eq(t["session_id"], 1_700_000_000_000)
	assert_eq(t["user_match_seq"], 4)
	assert_eq(t["config_variant"], TelemetrySetup.VARIANT_CONTROL)


func test_slots_name_their_controller_and_bot_tuning() -> void:
	var slots: Array = _setup()["slots"]
	assert_eq(slots[0]["controller"], MatchSetup.CONTROLLER_LOCAL)
	assert_null(slots[0]["bot_difficulty"], "humans have no bot difficulty")
	assert_null(slots[0]["bot_params_hash"])
	assert_eq(slots[1]["controller"], MatchSetup.CONTROLLER_BOT)
	assert_eq(slots[1]["bot_difficulty"], TelemetrySetup.BOT_DIFFICULTY_DEFAULT)
	assert_eq(slots[1]["bot_params_hash"], TelemetrySetup.bot_params_hash(GameConfig.new()))


func test_slots_name_the_style_of_their_character() -> void:
	var setup := MatchSetup.vs_bots(3, 9)
	setup.set_characters({0: CharacterData.KNIGHT, 1: CharacterData.MAGE})
	var slots: Array = TelemetrySetup.from_match_setup(setup)["slots"]
	assert_eq([slots[0]["character"], slots[0]["style"]], [CharacterData.KNIGHT, StyleCatalog.WEAPON])
	assert_eq([slots[1]["character"], slots[1]["style"]], [CharacterData.MAGE, StyleCatalog.RANGED])
	assert_eq([slots[2]["character"], slots[2]["style"]], [CharacterData.DEFAULT, StyleCatalog.CLASSIC],
			"a slot without a character is the classic fighter")


func test_bot_params_hash_follows_the_bot_group_only() -> void:
	var base := GameConfig.new()
	var tuned := GameConfig.new()
	tuned.bot_guard_ticks += 5
	assert_ne(TelemetrySetup.bot_params_hash(tuned), TelemetrySetup.bot_params_hash(base))
	var sim_only := GameConfig.new()
	sim_only.move_speed += 1.0
	assert_eq(TelemetrySetup.bot_params_hash(sim_only), TelemetrySetup.bot_params_hash(base))


func test_without_config_or_context_the_fields_are_null() -> void:
	var t := TelemetrySetup.from_match_setup(MatchSetup.vs_bots())
	assert_null(t["config_fingerprint"])
	assert_null(t["session_id"])
	assert_null(t["user_match_seq"])


func test_match_counter_counts_per_user_and_persists() -> void:
	var path := "user://test_match_seq.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var counter := MatchCounter.new(path)
	assert_eq(counter.next("u-1"), 1)
	assert_eq(counter.next("u-1"), 2)
	assert_eq(counter.next(""), 1, "signed-out matches count separately")
	assert_eq(MatchCounter.new(path).next("u-1"), 3, "survives a restart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_in_memory_counter_writes_nothing() -> void:
	var counter := MatchCounter.new("")
	assert_eq(counter.next("u"), 1)
	assert_eq(counter.next("u"), 2)


static func _base_setup() -> Dictionary:
	return {"match_id": "m-1", "mode": "bot", "arena": "classic", "seed": 7, "local_slot": 0,
		"started_at": "2026-09-30T12:00:00Z", "slots": [
			{"slot": 0, "is_bot": false, "character": "Knight", "style": "default", "input_device": "keyboard"},
			{"slot": 1, "is_bot": true, "character": "Barbarian", "style": "default", "input_device": "bot"}]}


static func _end_view() -> Dictionary:
	var fighters: Array = []
	for id: int in 2:
		fighters.append({"id": id, "spawn_id": 0, "pos": Vector3.ZERO, "state": 0, "on_ground": true,
			"damage": 0.0, "stocks": 3, "attack_kind": 0, "attack_ticks": 0})
	return {"tick": 60, "arena_radius": 10.0, "match_over": false, "winner": -1, "fighters": fighters}


func test_match_row_carries_the_reproducibility_header() -> void:
	var t := MatchTelemetry.new(func(_n: String, _p: Dictionary) -> void: pass)
	var setup := _base_setup()
	setup.merge({"config_fingerprint": 123, "sim_version": World.SNAPSHOT_VERSION, "event_schema_version": 2,
		"session_id": 1_700_000_000_000, "user_match_seq": 3, "config_variant": "control"})
	setup["slots"][1].merge({"controller": "bot", "bot_difficulty": "normal", "bot_params_hash": 77})
	t.begin(setup)
	t.end(_end_view(), false, 987654321)
	var m := t.match_row()
	assert_eq(m["config_fingerprint"], 123)
	assert_eq(m["sim_version"], World.SNAPSHOT_VERSION)
	assert_eq(m["event_schema_version"], 2)
	assert_eq(m["final_state_hash"], 987654321)
	assert_eq(m["session_id"], 1_700_000_000_000)
	assert_eq(m["user_match_seq"], 3)
	assert_eq(m["config_variant"], "control")
	var bot: Dictionary = t.player_rows()[1]
	assert_eq(bot["controller"], "bot")
	assert_eq(bot["bot_difficulty"], "normal")
	assert_eq(bot["bot_params_hash"], 77)
	assert_eq(t.player_rows()[0]["controller"], "local", "derived from is_bot when the setup has none")
