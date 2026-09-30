class_name TutorialFlow
extends RefCounted
## The tutorial's mission order and funnel tracking (Phase 5 T11, tracking-plan §3.3): steps in
## TutorialSteps order, each a run of goals checked every tick by TutorialDetector. A finished
## step pauses in CELEBRATING until advance() (the scene shows its success feedback first); the
## last one finishes the tutorial at once. skip() ends it from any step (during the success
## feedback it counts against the next mission, which the player never saw start). Both mark
## TutorialProgress so a first-login tutorial is not offered again. Event index is 1-based (the
## card's "n/8").

signal goal_changed(step: String, goal: String)
signal step_completed(step: String, index: int)
signal finished(completed: bool)

enum Phase { IDLE, RUNNING, CELEBRATING, DONE }

const SOURCE_FIRST_LOGIN := "first_login"
const SOURCE_REPLAY := "replay"

var _track: Callable
var _progress: TutorialProgress
var _source: String
var _clock: Callable
var _phase: int = Phase.IDLE
var _index: int = 0
var _goal: int = 0
var _started_ms: int = 0
var _step_ms: int = 0
var _attempts: int = 0
var _memo: Dictionary = {}
var _last_input: InputFrame = null


func _init(track: Callable, progress: TutorialProgress, source: String,
		clock_ms: Callable = Time.get_ticks_msec) -> void:
	_track = track
	_progress = progress
	_source = source
	_clock = clock_ms


## input_device: the player's device when the tutorial opens ("keyboard" | "gamepad" | "touch").
func start(input_device: String = "") -> void:
	if _phase != Phase.IDLE:
		return
	_started_ms = _now()
	var props := {"source": _source, "step_count": TutorialSteps.count()}
	if not input_device.is_empty():
		props["input_device"] = input_device
	_track.call("tutorial_started", props)
	_enter(0)


func phase() -> int:
	return _phase


func index() -> int:
	return _index


func step() -> String:
	return TutorialSteps.id_at(_index)


func goal() -> String:
	var goals := TutorialSteps.goals(step())
	return String(goals[_goal]) if _goal < goals.size() else ""


## Which goal of the current step is on (0 = first).
func goal_index() -> int:
	return _goal


func is_done() -> bool:
	return _phase == Phase.DONE


## One sim tick: counts new presses of the goal's buttons, then checks the goal.
func on_tick(prev: Dictionary, curr: Dictionary, events: Array, input: InputFrame, slot: int,
		config: GameConfig) -> void:
	if _phase == Phase.RUNNING:
		_attempts += TutorialAttempts.presses(TutorialSteps.tries(goal()), _last_input, input)
		if TutorialDetector.met(goal(), prev, curr, events, slot, config, _memo, input):
			_goal_met()
		elif goal() == TutorialSteps.G_THROW and TutorialDetector.grab_lost(events, slot):
			_goal = 0  # the hold timed out: grab again
			_memo = {}
			goal_changed.emit(step(), goal())
	_last_input = input


## After the success feedback: the next step.
func advance() -> void:
	if _phase == Phase.CELEBRATING:
		_enter(_index + 1)


func skip() -> void:
	if _phase == Phase.DONE or _phase == Phase.IDLE:
		return
	var between := _phase == Phase.CELEBRATING
	var at := _index + 1 if between else _index
	_phase = Phase.DONE
	_track.call("tutorial_skipped", {"step": TutorialSteps.id_at(at), "index": at + 1,
		"ms_in_step": 0 if between else _now() - _step_ms, "total_ms": _now() - _started_ms})
	_progress.mark(TutorialProgress.SKIPPED)
	finished.emit(false)


func _enter(i: int) -> void:
	_index = i
	_goal = 0
	_memo = {}
	_attempts = 0
	_step_ms = _now()
	_phase = Phase.RUNNING
	goal_changed.emit(step(), goal())


func _goal_met() -> void:
	_memo = {}
	if _goal + 1 < TutorialSteps.goals(step()).size():
		_goal += 1
		goal_changed.emit(step(), goal())
		return
	_track.call("tutorial_step_completed", {"step": step(), "index": _index + 1,
		"ms_in_step": _now() - _step_ms, "attempts": maxi(_attempts, 1)})
	var last := _index + 1 >= TutorialSteps.count()
	_phase = Phase.DONE if last else Phase.CELEBRATING
	step_completed.emit(step(), _index + 1)
	if last:
		_track.call("tutorial_completed", {"total_ms": _now() - _started_ms, "step_count": TutorialSteps.count()})
		_progress.mark(TutorialProgress.COMPLETED)
		finished.emit(true)


func _now() -> int:
	return int(_clock.call())
