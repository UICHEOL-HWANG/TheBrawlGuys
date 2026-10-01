extends GutTest
## Bot knockdown play (combat-depth C, BotGetup): a lying bot picks a getup option per knockdown
## (stand, roll, attack or stay down), varied but deterministic; a tumbling bot sometimes techs by
## pressing guard just before it lands. Plus the perfect-guard cap (BotDefense): on most guard
## turns the bot raises its guard as the foe closes in, so the block is not a perfect guard.


func _me(state: int, pos: Vector3 = Vector3.ZERO, tumbling: bool = false, on_ground: bool = true) -> Dictionary:
	return {"id": 1, "pos": pos, "facing": Vector3(-1, 0, 0), "state": state, "on_ground": on_ground,
		"jumps_left": 2, "item_kind": Fighter.NONE, "invuln_ticks": 0, "tumbling": tumbling}


func _view(me: Dictionary, tick: int, foe_pos: Vector3 = Vector3(0, 0, 5), foe_state: int = Fighter.State.IDLE) -> Dictionary:
	var foe := {"id": 0, "pos": foe_pos, "facing": Vector3(1, 0, 0), "state": foe_state, "on_ground": true,
		"jumps_left": 2, "item_kind": Fighter.NONE, "invuln_ticks": 0}
	return {"tick": tick, "arena_radius": 10.0, "items": [], "fighters": [foe, me]}


## The bot's frame for one knockdown that starts at `tick`.
func _lying_frame(tick: int, foe_pos: Vector3 = Vector3(0, 0, 5)) -> InputFrame:
	var bot := BotController.new(1, GameConfig.new())
	return bot.sample(_view(_me(Fighter.State.KNOCKDOWN), tick, foe_pos))


func _kind(f: InputFrame) -> String:
	if f.light:
		return "attack"
	if f.move_x != 0.0 or f.move_z != 0.0:
		return "roll"
	if f.jump or f.guard:
		return "stand"
	return "wait"


func test_lying_bot_varies_its_getup_deterministically() -> void:
	var seen := {}
	for tick: int in 40:
		var a := _kind(_lying_frame(tick, Vector3(0, 0, 1.0)))
		assert_eq(_kind(_lying_frame(tick, Vector3(0, 0, 1.0))), a, "same view, same choice")
		seen[a] = true
	for kind: String in ["stand", "roll", "attack", "wait"]:
		assert_true(seen.has(kind), "%s happens" % kind)


func test_getup_roll_heads_away_from_the_foe() -> void:
	for tick: int in 40:
		var f := _lying_frame(tick, Vector3(0, 0, 1.0))
		if _kind(f) == "roll":
			assert_lt(f.move_z, 0.0, "away from the foe at +z")
			return
	fail_test("no roll seen")


func test_far_foe_turns_the_getup_attack_into_standing_up() -> void:
	for tick: int in 40:
		assert_ne(_kind(_lying_frame(tick, Vector3(0, 0, 6.0))), "attack", "nobody to hit at tick %d" % tick)


func test_tumbling_bot_sometimes_techs_just_before_landing() -> void:
	var c := GameConfig.new()
	var techs := 0
	for tick: int in 40:
		var bot := BotController.new(1, c)
		assert_false(bot.sample(_view(_me(Fighter.State.HITSTUN, Vector3(0, 4, 0), true, false), tick)).guard,
				"never presses high up")
		var low := _me(Fighter.State.HITSTUN, Vector3(0, c.bot_tech_height * 0.5, 0), true, false)
		techs += 1 if bot.sample(_view(low, tick + 1)).guard else 0
	assert_gt(techs, 0, "some knockdowns are teched")
	assert_lt(techs, 40, "not every one")


static func _guards(f: InputFrame) -> bool:
	return f != null and f.guard


const CYCLES := 120


## A foe closing in but not yet in the bot's swing range (BotDefense.decide with closing = true).
func test_most_guard_turns_raise_the_guard_before_the_swing() -> void:
	var c := GameConfig.new()
	var bot := BotDefense.new(1, c)
	assert_null(bot.decide(_me(Fighter.State.IDLE, Vector3(1.8, 0, 0)), {"id": 0, "pos": Vector3.ZERO,
			"state": Fighter.State.IDLE}, Vector2.ZERO, false), "not while it could attack instead")
	var me := _me(Fighter.State.IDLE, Vector3(1.8, 0, 0))
	var idle := _view(me, 0, Vector3.ZERO)["fighters"][0] as Dictionary
	var swinging := _view(me, 0, Vector3.ZERO, Fighter.State.ATTACK)["fighters"][0] as Dictionary
	var gone := _view(me, 0, Vector3(0, 0, 8))["fighters"][0] as Dictionary
	var early := 0
	var in_time := 0
	var tick := 0
	for cycle: int in CYCLES:
		var pre := _guards(bot.decide(me, idle, Vector2.ZERO, true, tick))
		var reacted := false
		for i: int in c.bot_guard_react_ticks + 1:
			tick += 1
			reacted = _guards(bot.decide(me, swinging, Vector2.ZERO, true, tick)) or reacted
		if cycle % 2 == 1:
			assert_false(pre or reacted, "the other turns never guard a plain swing (cycle %d)" % cycle)
		early += 1 if pre else 0
		in_time += 1 if reacted and not pre else 0
		for i: int in c.bot_guard_ticks + 5:
			tick += 1
			bot.decide(me, gone, Vector2.ZERO, true, tick)
	var turns := CYCLES / 2.0
	assert_gt(early, turns * (1.0 - c.bot_perfect_guard_chance) * 0.75, "most guard turns guard early (no perfect guard)")
	assert_gt(in_time, turns * c.bot_perfect_guard_chance * 0.5, "some turns react in time (perfect guards stay possible)")
	assert_lt(in_time, early)


func test_a_late_turn_still_guards_a_charge() -> void:
	var c := GameConfig.new()
	c.bot_perfect_guard_chance = 0.0
	var bot := BotDefense.new(1, c)
	var me := _me(Fighter.State.IDLE, Vector3(1.8, 0, 0))
	var charging := _view(me, 0, Vector3.ZERO, Fighter.State.CHARGE)["fighters"][0] as Dictionary
	var guarded := false
	for i: int in c.bot_guard_react_ticks + 1:
		guarded = _guards(bot.decide(me, charging, Vector2.ZERO)) or guarded
	assert_true(guarded, "a charge is slow enough to block without a perfect guard")
