extends GutTest
## Bot defense (combat-depth A, BotDefense): guards every other threat after a short reaction,
## rolls away from a charging foe on the un-guarded turns and toward the middle when threatened
## on the edge, and stops guarding once its guard meter runs low.


func _view(me_pos: Vector3, foe_pos: Vector3, foe_state: int = Fighter.State.IDLE, ratio: float = 1.0) -> Dictionary:
	return {
		"arena_radius": 10.0,
		"items": [],
		"fighters": [
			{"id": 0, "pos": foe_pos, "facing": Vector3(1, 0, 0), "state": foe_state, "on_ground": true,
				"jumps_left": 2, "item_kind": Fighter.NONE, "invuln_ticks": 0},
			{"id": 1, "pos": me_pos, "facing": Vector3(-1, 0, 0), "state": Fighter.State.IDLE, "on_ground": true,
				"jumps_left": 2, "item_kind": Fighter.NONE, "invuln_ticks": 0, "guard_hp_ratio": ratio},
		],
	}


## Samples `view` until the reaction delay has passed; returns the first reacting frame.
func _react(bot: BotController, view: Dictionary, c: GameConfig) -> InputFrame:
	for i: int in c.bot_guard_react_ticks:
		bot.sample(view)
	return bot.sample(view)


## Burns the first (guarded) threat so the next one is an un-guarded turn.
func _spend_guard_turn(bot: BotController, c: GameConfig) -> void:
	_react(bot, _view(Vector3(1.5, 0, 0), Vector3(0, 0, 0), Fighter.State.ATTACK), c)
	for i: int in c.bot_guard_ticks + 2:
		bot.sample(_view(Vector3(3.0, 0, 0), Vector3(0, 0, 0)))


func test_guards_a_threat_after_the_reaction_delay() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var attacking := _view(Vector3(1.5, 0, 0), Vector3(0, 0, 0), Fighter.State.ATTACK)
	assert_false(bot.sample(attacking).guard, "not a frame-perfect reaction")
	for i: int in c.bot_guard_react_ticks - 1:
		bot.sample(attacking)
	var f := bot.sample(attacking)
	assert_true(f.guard)
	assert_eq(Vector2(f.move_x, f.move_z), Vector2.ZERO, "a standing guard, not a roll")


func test_stops_guarding_when_the_meter_is_low() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var low := _view(Vector3(1.5, 0, 0), Vector3(0, 0, 0), Fighter.State.ATTACK, c.bot_guard_min_ratio - 0.05)
	assert_false(_react(bot, low, c).guard)


func test_rolls_away_from_a_charging_foe_on_the_unguarded_turn() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	_spend_guard_turn(bot, c)
	var f := _react(bot, _view(Vector3(1.5, 0, 0), Vector3(0, 0, 0), Fighter.State.CHARGE), c)
	assert_true(f.guard, "a roll is a guard press")
	assert_gt(f.move_x, 0.9, "away from the foe")
	assert_false(f.heavy, "not the special chord")


func test_does_not_roll_from_a_plain_attack_in_the_open() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	_spend_guard_turn(bot, c)
	var f := _react(bot, _view(Vector3(1.5, 0, 0), Vector3(0, 0, 0), Fighter.State.ATTACK), c)
	assert_false(f.guard, "the un-guarded turn stays un-guarded")


func test_rolls_toward_the_middle_when_threatened_on_the_edge() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	_spend_guard_turn(bot, c)
	var f := _react(bot, _view(Vector3(9.0, 0, 0), Vector3(9.0, 0, 1.0), Fighter.State.ATTACK), c)
	assert_true(f.guard)
	assert_lt(f.move_x, -0.5, "toward the middle")
