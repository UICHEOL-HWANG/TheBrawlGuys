extends GutTest
## Tutorial goal detection (Phase 5 T11): each goal is met by the player's own action in the sim
## view/events and never by the dummy's, a standing player or another goal's action.

const Cases := preload("res://tests/unit/support/tutorial_cases.gd")
const CONFIG_PATH := "res://src/config/default_config.tres"

var _config: GameConfig


func before_each() -> void:
	_config = load(CONFIG_PATH) as GameConfig


func _met(goal: String, prev: Dictionary, curr: Dictionary, events: Array, memo: Dictionary = {},
		input: InputFrame = null) -> bool:
	return TutorialDetector.met(goal, prev, curr, events, Cases.PLAYER, _config, memo, input)


func test_every_goal_is_met_by_its_own_tick() -> void:
	for goal: String in TutorialSteps.KEYS:
		var c := Cases.met(goal)
		assert_true(_met(goal, c["prev"], c["curr"], c["events"], {}, c["input"]), "%s is met" % goal)


func test_no_goal_is_met_while_nothing_happens() -> void:
	for goal: String in TutorialSteps.KEYS:
		assert_false(_met(goal, Cases.idle(), Cases.idle(), []), "%s is not met idle" % goal)


func test_a_goal_is_only_met_by_its_own_action() -> void:
	for goal: String in TutorialSteps.KEYS:
		for other: String in TutorialSteps.KEYS:
			if other == goal:
				continue
			var c := Cases.met(other)
			assert_false(_met(goal, c["prev"], c["curr"], c["events"], {}, c["input"]),
					"%s is not met by %s" % [goal, other])


func test_move_sums_running_distance_and_ignores_a_respawn() -> void:
	var memo := {}
	var step := Vector3(TutorialDetector.MOVE_DISTANCE * 0.4, 0.0, 0.0)
	var a := Cases.view()
	var b := Cases.view({"pos": step})
	assert_false(_met(TutorialSteps.G_MOVE, a, b, [], memo), "not far enough yet")
	var teleport := Cases.view({"pos": step * 10.0, "spawn_id": 1})
	assert_false(_met(TutorialSteps.G_MOVE, b, teleport, [], memo), "a respawn is not running")
	var c := Cases.view({"pos": step * 10.0 + step * 2.0, "spawn_id": 1})
	assert_true(_met(TutorialSteps.G_MOVE, teleport, c, [], memo), "two more runs make it")


func test_the_dummy_hitting_or_grabbing_never_counts() -> void:
	var hit := [{"type": "hit", "attacker": Cases.DUMMY, "target": Cases.PLAYER, "power": 3.0}]
	assert_false(_met(TutorialSteps.G_LIGHT_HIT, Cases.idle(), Cases.attacking(AttackSet.Kind.LIGHT_1), hit))
	var grab := [{"type": "grab", "attacker": Cases.DUMMY, "target": Cases.PLAYER}]
	assert_false(_met(TutorialSteps.G_GRAB, Cases.idle(), Cases.idle(), grab))
	var blocked := [{"type": "guard_hit", "attacker": Cases.PLAYER, "target": Cases.DUMMY}]
	assert_false(_met(TutorialSteps.G_GUARD, Cases.idle(), Cases.idle(), blocked), "the dummy blocking")


func test_a_jump_needs_a_jump_press_not_a_step_off_a_ledge() -> void:
	var c := Cases.met(TutorialSteps.G_JUMP)
	assert_false(_met(TutorialSteps.G_JUMP, c["prev"], c["curr"], [], {}, InputFrame.neutral()),
			"walking off an edge also spends a jump")
	var memo := {}
	assert_false(_met(TutorialSteps.G_JUMP, Cases.idle(), Cases.idle(), [], memo, InputFrame.make(0, 0, true)))
	assert_true(_met(TutorialSteps.G_JUMP, c["prev"], c["curr"], [], memo, InputFrame.neutral()),
			"the jump may leave the ground a tick after the press")
	for i: int in TutorialDetector.JUMP_WINDOW_TICKS:
		_met(TutorialSteps.G_JUMP, Cases.idle(), Cases.idle(), [], memo, InputFrame.neutral())
	assert_false(_met(TutorialSteps.G_JUMP, c["prev"], c["curr"], [], memo, InputFrame.neutral()), "too late")


func test_perfect_guard_counts_as_guarding() -> void:
	var e := [{"type": "perfect_guard", "fighter": Cases.PLAYER, "attacker": Cases.DUMMY}]
	assert_true(_met(TutorialSteps.G_GUARD, Cases.idle(), Cases.idle(), e))


func test_a_tapped_heavy_is_not_a_charged_hit() -> void:
	var heavy := AttackSet.Kind.HEAVY
	var tap := [{"type": "hit", "attacker": Cases.PLAYER, "target": Cases.DUMMY, "power": 1.0, "attack_kind": heavy}]
	assert_false(_met(TutorialSteps.G_CHARGED_HIT, Cases.idle(), Cases.attacking(AttackSet.Kind.HEAVY), tap))
	var charged := Actions.charge_mul(SimTime.to_ticks(TutorialDetector.MIN_CHARGE_S), _config)
	var held := [{"type": "hit", "attacker": Cases.PLAYER, "target": Cases.DUMMY, "power": charged,
		"attack_kind": heavy}]
	assert_true(_met(TutorialSteps.G_CHARGED_HIT, Cases.idle(), Cases.attacking(AttackSet.Kind.HEAVY), held))
	assert_false(_met(TutorialSteps.G_LIGHT_HIT, Cases.idle(), Cases.attacking(AttackSet.Kind.HEAVY), held),
			"a heavy hit is not a light one")


func test_a_bat_swing_uses_the_item() -> void:
	var swing := Cases.attacking(AttackSet.Kind.BAT)
	assert_true(_met(TutorialSteps.G_ITEM_USE, Cases.idle(), swing, []))
	assert_false(_met(TutorialSteps.G_ITEM_USE, swing, swing, []), "only the start of the swing")


func test_a_missing_player_meets_nothing() -> void:
	var empty := {"fighters": [], "events": []}
	assert_false(_met(TutorialSteps.G_JUMP, empty, empty, []))
