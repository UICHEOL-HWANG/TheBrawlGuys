extends GutTest
## Onboarding tutorial flow (Phase 5 T11, tracking-plan §3.3): missions run in order, each goal is
## detected from sim views/events, skip and completion are tracked with funnel payloads and
## persisted so a first-login tutorial is offered once. Detection per goal: test_tutorial_detector,
## mission data and device lines: test_tutorial_steps.

const Cases := preload("res://tests/unit/support/tutorial_cases.gd")
const PATH := "user://test_tutorial_flow.cfg"
const CONFIG_PATH := "res://src/config/default_config.tres"

var _tracked: Array = []
var _now_ms: int = 1000
var _config: GameConfig


func before_each() -> void:
	_tracked.clear()
	_now_ms = 1000
	_config = load(CONFIG_PATH) as GameConfig
	_remove()


func after_each() -> void:
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _progress() -> TutorialProgress:
	return TutorialProgress.new(SettingsStore.new(PATH))


func _flow(source: String = TutorialFlow.SOURCE_FIRST_LOGIN) -> TutorialFlow:
	var track := func(n: String, p: Dictionary) -> void:
		assert_eq(EventCatalog.validate(n, p).size(), 0, "%s follows the catalog" % n)
		_tracked.append([n, p])
	return TutorialFlow.new(track, _progress(), source, func() -> int: return _now_ms)


func _events(event_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Array in _tracked:
		if t[0] == event_name:
			out.append(t[1])
	return out


## Meets the flow's current goal with a synthetic tick (Cases shapes).
func _meet(flow: TutorialFlow, press: InputFrame = null) -> void:
	var c := Cases.met(flow.goal())
	flow.on_tick(c["prev"], c["curr"], c["events"], press if press != null else c["input"], 0, _config)


func test_start_tracks_the_source_and_opens_the_first_goal() -> void:
	var flow := _flow(TutorialFlow.SOURCE_REPLAY)
	var goals: Array = []
	flow.goal_changed.connect(func(s: String, g: String) -> void: goals.append([s, g]))
	flow.start("gamepad")
	assert_eq(_events("tutorial_started"), [{"source": "replay", "step_count": 8, "input_device": "gamepad"}])
	assert_eq(goals, [["move", "move"]])
	assert_eq(flow.phase(), TutorialFlow.Phase.RUNNING)


func test_every_step_completes_in_order_with_funnel_payloads() -> void:
	var flow := _flow()
	flow.start()
	for i: int in TutorialSteps.count():
		assert_eq(flow.step(), TutorialSteps.ORDER[i])
		_now_ms += 500
		for g: int in TutorialSteps.goals(flow.step()).size():
			_meet(flow)
		if i < TutorialSteps.count() - 1:
			assert_eq(flow.phase(), TutorialFlow.Phase.CELEBRATING, "waits for the success feedback")
			flow.advance()
	var done := _events("tutorial_step_completed")
	assert_eq(done.size(), 8)
	assert_eq(done[0], {"step": "move", "index": 1, "ms_in_step": 500, "attempts": 1})
	assert_eq(done[7]["step"], "special")
	assert_eq(done[7]["index"], 8)
	assert_eq(_events("tutorial_completed"), [{"total_ms": 4000, "step_count": 8}])
	assert_true(flow.is_done())
	assert_eq(_progress().status(), TutorialProgress.COMPLETED)


func test_two_goal_steps_need_both_goals_in_order() -> void:
	var flow := _flow()
	flow.start()
	for i: int in 5:
		_meet(flow)
		flow.advance()
	assert_eq(flow.step(), TutorialSteps.GRAB)
	assert_eq(flow.goal(), TutorialSteps.G_GRAB)
	var throw_first := Cases.met(TutorialSteps.G_THROW)
	flow.on_tick(throw_first["prev"], throw_first["curr"], throw_first["events"], InputFrame.neutral(), 0, _config)
	assert_eq(flow.goal(), TutorialSteps.G_GRAB, "a throw does not count before the grab")
	_meet(flow)
	assert_eq(flow.goal(), TutorialSteps.G_THROW)
	assert_eq(flow.phase(), TutorialFlow.Phase.RUNNING)
	_meet(flow)
	assert_eq(flow.phase(), TutorialFlow.Phase.CELEBRATING)


func test_attempts_count_new_presses_of_the_goal_buttons() -> void:
	var flow := _flow()
	flow.start()
	_meet(flow)
	flow.advance()
	var idle := Cases.idle()
	for press: bool in [true, false, true, false, true]:
		flow.on_tick(idle, idle, [], InputFrame.make(0, 0, press), 0, _config)
	_meet(flow)
	assert_eq(_events("tutorial_step_completed")[1]["attempts"], 3, "three jump presses (still held on the jump)")
	assert_eq(TutorialAttempts.presses(["special"], InputFrame.make(0, 0, false, false, true),
			InputFrame.make(0, 0, false, false, true, true)), 1, "the chord closes on guard")
	assert_eq(TutorialAttempts.presses(["move"], InputFrame.make(1, 0), InputFrame.make(0.5, 0)), 0, "still moving")


func test_nothing_is_detected_while_celebrating() -> void:
	var flow := _flow()
	flow.start()
	_meet(flow)
	var c := Cases.met(TutorialSteps.G_JUMP)
	flow.on_tick(c["prev"], c["curr"], c["events"], InputFrame.neutral(), 0, _config)
	assert_eq(_events("tutorial_step_completed").size(), 1)
	flow.advance()
	assert_eq(flow.step(), TutorialSteps.JUMP)


func test_skip_tracks_where_the_player_left_and_marks_it() -> void:
	var flow := _flow()
	var ended: Array = []
	flow.finished.connect(func(completed: bool) -> void: ended.append(completed))
	flow.start()
	_meet(flow)
	flow.advance()
	_now_ms += 700
	flow.skip()
	assert_eq(_events("tutorial_skipped"), [{"step": "jump", "index": 2, "ms_in_step": 700, "total_ms": 700}])
	assert_eq(ended, [false])
	assert_eq(_progress().status(), TutorialProgress.SKIPPED)
	flow.skip()
	assert_eq(_events("tutorial_skipped").size(), 1, "skipping twice counts once")


func test_a_skip_during_the_success_feedback_counts_against_the_next_mission() -> void:
	var flow := _flow()
	flow.start()
	_now_ms += 300
	_meet(flow)
	_now_ms += 400
	flow.skip()
	assert_eq(_events("tutorial_skipped"), [{"step": "jump", "index": 2, "ms_in_step": 0, "total_ms": 700}],
			"the move mission was completed, not abandoned")


func test_a_grab_that_times_out_goes_back_to_the_grab() -> void:
	var flow := _flow()
	var goals: Array = []
	flow.start()
	for i: int in 5:
		_meet(flow)
		flow.advance()
	_meet(flow)
	flow.goal_changed.connect(func(_s: String, g: String) -> void: goals.append(g))
	var idle := Cases.idle()
	var released := [{"type": "grab_release", "attacker": Cases.PLAYER, "target": Cases.DUMMY}]
	flow.on_tick(idle, idle, released, InputFrame.neutral(), 0, _config)
	assert_eq(flow.goal(), TutorialSteps.G_GRAB, "the card asks for the grab again")
	assert_eq(goals, [TutorialSteps.G_GRAB])
	var dummy_let_go := [{"type": "grab_release", "attacker": Cases.DUMMY, "target": Cases.PLAYER}]
	_meet(flow)
	flow.on_tick(idle, idle, dummy_let_go, InputFrame.neutral(), 0, _config)
	assert_eq(flow.goal(), TutorialSteps.G_THROW, "only the player's own hold counts")


func test_skip_after_completion_does_nothing() -> void:
	var flow := _flow()
	flow.start()
	for i: int in TutorialSteps.count():
		for g: int in TutorialSteps.goals(flow.step()).size():
			_meet(flow)
		flow.advance()
	flow.skip()
	assert_eq(_events("tutorial_skipped").size(), 0)
	assert_eq(_progress().status(), TutorialProgress.COMPLETED)


func test_progress_is_pending_until_completed_or_skipped_and_survives_reloads() -> void:
	assert_true(_progress().is_pending())
	_progress().mark(TutorialProgress.SKIPPED)
	assert_false(_progress().is_pending())
	_progress().mark(TutorialProgress.COMPLETED)
	assert_eq(_progress().status(), TutorialProgress.COMPLETED)
	_progress().mark(TutorialProgress.SKIPPED)
	assert_eq(_progress().status(), TutorialProgress.COMPLETED, "a skipped replay keeps the completion")
	SettingsStore.new(PATH).set_value(TutorialProgress.SECTION, TutorialProgress.KEY, 3)
	assert_true(_progress().is_pending(), "junk values read as pending")
