extends GutTest
## Difficulty dial (PRD-BOT-03): every BotSkill value moves one way as d rises, presets are named
## dial points, the classic config bot is unchanged, and DDA can move a bot's d mid-match.

## Values that must not decrease with d (+1) or not increase (-1).
const DIRECTION := {
	"react_ticks": -1, "guard_chance": 1, "perfect_guard_chance": 1, "tech_chance": 1, "smart_getup": 1,
	"di_chance": 1, "cooldown_ticks": -1, "aim_error_deg": -1, "hesitate_chance": -1, "special_delay_ticks": -1,
}


func test_every_parameter_is_monotone_in_d() -> void:
	for key: String in DIRECTION:
		var prev := float(BotDifficulty.skill(0.0).get(key))
		for i: int in range(1, 21):
			var v := float(BotDifficulty.skill(i / 20.0).get(key))
			assert_true((v - prev) * DIRECTION[key] >= 0.0, "%s moves the wrong way at d=%.2f" % [key, i / 20.0])
			prev = v
		var lo := float(BotDifficulty.skill(0.0).get(key))
		var hi := float(BotDifficulty.skill(1.0).get(key))
		assert_true((hi - lo) * DIRECTION[key] > 0.0, "%s changes across the dial" % key)


func test_every_skill_value_has_an_anchor() -> void:
	for key: String in BotSkill.new().to_dict():
		if key != "d":
			assert_true(BotDifficulty.ANCHORS.has(key), "%s is on the dial" % key)


func test_d_is_clamped_and_kept() -> void:
	assert_eq(BotDifficulty.skill(-1.0).d, 0.0)
	assert_eq(BotDifficulty.skill(2.0).d, 1.0)
	assert_almost_eq(BotDifficulty.skill(0.37).d, 0.37, 0.0001)


func test_presets_are_ordered_dial_points() -> void:
	assert_lt(BotDifficulty.d_of("slow"), BotDifficulty.d_of("normal"))
	assert_lt(BotDifficulty.d_of("normal"), BotDifficulty.d_of("busy"))
	assert_eq(BotDifficulty.preset_name(0.05), "slow")
	assert_eq(BotDifficulty.preset_name(0.5), "normal")
	assert_eq(BotDifficulty.preset_name(0.95), "busy")
	assert_eq(BotDifficulty.d_of("unknown"), BotDifficulty.d_of(BotDifficulty.DEFAULT_PRESET))


func test_config_bot_keeps_the_classic_values() -> void:
	var c := GameConfig.new()
	var s := BotController.new(1, c).skill()
	assert_eq(s.d, BotSkill.NO_DIAL)
	assert_eq(s.react_ticks, c.bot_guard_react_ticks)
	assert_eq(s.cooldown_ticks, c.bot_attack_cooldown_ticks)
	assert_eq(s.hesitate_chance, 0.0)
	assert_eq(s.aim_error_deg, 0.0)
	assert_eq(s.guard_chance, 1.0)


func test_set_difficulty_changes_the_skill_every_part_reads() -> void:
	var bot := BotController.new(1, GameConfig.new(), 0.2)
	assert_almost_eq(bot.skill().d, 0.2, 0.0001)
	bot.set_difficulty(0.9)
	assert_almost_eq(bot.skill().d, 0.9, 0.0001)
	assert_ne(BotDifficulty.skill(0.2).params_hash(), BotDifficulty.skill(0.9).params_hash())


func test_noise_is_deterministic() -> void:
	var s := BotDifficulty.skill(0.1)
	for t: int in [0, 50, 500]:
		assert_eq(s.hesitating(3, t), s.hesitating(3, t))
		assert_eq(s.aim(Vector2.RIGHT, 3, t), s.aim(Vector2.RIGHT, 3, t))
	assert_eq(BotDifficulty.skill(1.0).aim(Vector2.RIGHT, 3, 7), Vector2.RIGHT, "no aim error at d = 1")
	assert_false(BotDifficulty.skill(1.0).hesitating(3, 7), "no hesitation at d = 1")


func test_low_d_hesitates_some_windows() -> void:
	var s := BotDifficulty.skill(0.0)
	var idle := 0
	for w: int in 200:
		idle += 1 if s.hesitating(2, w * BotSkill.WINDOW_TICKS) else 0
	assert_between(idle, 70, 150, "about hesitate_chance of the windows")
