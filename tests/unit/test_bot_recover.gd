extends GutTest
## next-polish 1: a launched bot off the arena saves itself — its air jump near the apex, an air
## dodge toward the floor once the jump is spent and the floor is within the dodge's reach —
## instead of jumping only after it has dropped under the floor (BotRecover).

var _c := GameConfig.new()
var _arena: ArenaData


func before_each() -> void:
	_arena = ArenaCatalog.default(_c)


func _me(x: float, y: float, jumps: int = 1, dodge_used: bool = false, state: int = Fighter.State.AIR) -> Dictionary:
	return {"id": 0, "pos": Vector3(x, y, 0), "on_ground": false, "state": state, "jumps_left": jumps,
		"air_dodge_used": dodge_used}


## Feeds two ticks (so it sees the vertical motion) and returns the second decision.
func _decide(from_y: float, me: Dictionary, skill: BotSkill = BotSkill.from_config(_c)) -> InputFrame:
	var r := BotRecover.new(_c)
	var before := me.duplicate()
	before["pos"] = Vector3((me["pos"] as Vector3).x, from_y, 0)
	r.decide(before, _arena, Vector2(-1, 0), skill, 0)
	return r.decide(me, _arena, Vector2(-1, 0), skill, 1)


func test_nothing_to_recover_on_or_over_the_floor() -> void:
	var r := BotRecover.new(_c)
	var standing := _me(11.0, 0.0)
	standing["on_ground"] = true
	assert_null(r.decide(standing, _arena, Vector2(-1, 0), BotSkill.from_config(_c), 0))
	assert_null(r.decide(_me(5.0, 1.0), _arena, Vector2(-1, 0), BotSkill.from_config(_c), 0))


func test_a_launch_is_left_to_di() -> void:
	assert_null(_decide(1.0, _me(11.0, 1.2, 1, false, Fighter.State.HITSTUN)))


func test_jumps_at_the_apex_not_while_still_rising() -> void:
	var rising := _decide(0.8, _me(11.0, 1.0))
	assert_false(rising.jump, "a jump while rising wastes its height")
	assert_lt(rising.move_x, 0.0, "steers home")
	var falling := _decide(1.2, _me(11.0, 1.0))
	assert_true(falling.jump)
	assert_lt(falling.move_x, 0.0)


func test_air_dodges_home_once_the_jump_is_spent_and_the_floor_is_in_reach() -> void:
	var gap := _c.air_dodge_distance * 0.5
	var f := BotRecover.new(_c).decide(_me(_c.arena_radius + gap, 1.0, 0), _arena, Vector2(-1, 0), BotSkill.from_config(_c), 0)
	assert_true(f.guard, "air dodge")
	assert_lt(f.move_x, 0.0, "toward the floor")


func test_no_dodge_out_of_reach_spent_or_under_the_lip() -> void:
	var far := _decide(1.2, _me(_c.arena_radius + _c.air_dodge_distance * 1.5, 1.0, 0))
	assert_false(far.guard, "too far: the dodge cannot reach")
	var spent := _decide(1.2, _me(_c.arena_radius + 0.5, 1.0, 0, true))
	assert_false(spent.guard, "one air dodge per airtime")
	var low := _decide(-0.2, _me(_c.arena_radius + 0.5, -0.4, 0))
	assert_false(low.guard, "a hover under the floor top can never land")


func test_a_weak_bot_keeps_the_old_habit() -> void:
	var weak := BotSkill.from_config(_c)
	weak.recover_chance = 0.0
	assert_null(_decide(1.2, _me(11.0, 1.0), weak), "above the floor: left to the other logic, as before")
	assert_true(_decide(0.0, _me(11.0, -0.3), weak).jump, "jumps once under it")
	var stunned := _me(11.0, -0.3, 1, false, Fighter.State.HITSTUN)
	assert_true(_decide(0.0, stunned, weak).jump, "in any state, as before")


func test_the_recovery_roll_holds_for_the_whole_fall() -> void:
	var half := BotSkill.from_config(_c)
	half.recover_chance = 0.5
	var r := BotRecover.new(_c)
	var first := r.decide(_me(11.0, 1.0), _arena, Vector2(-1, 0), half, 0)
	for t: int in range(1, 200):
		var f := r.decide(_me(11.0, 1.0 - t * 0.001), _arena, Vector2(-1, 0), half, t)
		assert_eq(f == null, first == null, "tick %d plays the fall the same way" % t)


func test_the_air_dodge_press_is_fresh_every_other_tick() -> void:
	var r := BotRecover.new(_c)
	var me := _me(_c.arena_radius + 0.5, 1.0, 0)
	var s := BotSkill.from_config(_c)
	var a := r.decide(me, _arena, Vector2(-1, 0), s, 0)
	var b := r.decide(me, _arena, Vector2(-1, 0), s, 1)
	var c := r.decide(me, _arena, Vector2(-1, 0), s, 2)
	assert_true(a.guard)
	assert_false(b.guard, "let go, so the next press is new (a held guard never dodges)")
	assert_true(c.guard)


func test_the_dial_moves_recovery_skill() -> void:
	assert_lt(BotDifficulty.skill(0.0).recover_chance, BotDifficulty.skill(1.0).recover_chance)
	assert_eq(BotSkill.from_config(_c).recover_chance, 1.0, "the config bot recovers every time")


func test_the_view_says_whether_the_air_dodge_is_spent() -> void:
	var f := Fighter.new()
	f.air_dodge_used = true
	assert_true(bool(f.to_view()["air_dodge_used"]))


## A bot knocked just past the edge with its jump spent lands back on the floor.
func test_a_bot_knocked_just_off_the_edge_gets_back() -> void:
	var w := World.new(_c, 3)
	var bot := BotController.new(0, _c)
	var f := w.fighters[0]
	w.fighters[1].pos = Vector3(-6, 0, 0)
	f.pos = Vector3(_c.arena_radius + 1.0, 1.2, 0)
	f.vel = Vector3(1.0, 3.0, 0)
	f.on_ground = false
	f.jumps_left = 0
	f.set_state(Fighter.State.AIR)
	var start := f.spawn_id
	for i: int in 90:
		var inputs: Array[InputFrame] = [bot.sample(w.state_view()), InputFrame.neutral()]
		w.tick(inputs)
	assert_eq(f.spawn_id, start, "never rang out")
	assert_true(f.on_ground, "back on the floor")
