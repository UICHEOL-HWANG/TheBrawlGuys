extends "res://src/main/main.gd"
## Onboarding tutorial scene (Phase 5 T11, PRD-UI-02): the match scene on the classic arena with
## the player (Barbarian, so there is a special) against a TutorialDummy, run by a
## TutorialDirector. The TutorialOverlay card tells the current mission for the device in hand,
## the KeyHintBar rings the keys to press (shown even if the player hid it, without saving that),
## a success pauses on "좋아요!" for FEEDBACK_S, then the next mission. 건너뛰기 / Esc / Start →
## confirm → menu_requested (the app goes back to the title); finishing shows "튜토리얼 완료!"
## with 타이틀로. The skip dialog pauses the sim. Not a match: no match telemetry, no upload.

const PLAYER_CHARACTER := "barbarian"
const FEEDBACK_S := 1.2
const PREFIX := "p1"
## Stick travel that counts as using the pad (resting sticks drift a little).
const STICK_THRESHOLD := 0.5

## tutorial_started.source: TutorialFlow.SOURCE_FIRST_LOGIN or SOURCE_REPLAY.
var source: String = TutorialFlow.SOURCE_REPLAY
var progress: TutorialProgress = null
var track: Callable = func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props)

var _director: TutorialDirector
var _overlay: TutorialOverlay
var _celebrate_left: float = -1.0
## Last device the player touched: keyboard | gamepad | touch ("" = none yet).
var _last_device: String = ""
var _shown_device: String = ""
## Set once the player leaves (skip or 타이틀로): later presses during the curtain do nothing.
var _leaving: bool = false


func _ready() -> void:
	if setup == null:
		setup = TutorialDirector.match_setup(PLAYER_CHARACTER)
	if progress == null:
		progress = TutorialProgress.new()
	super._ready()


func director() -> TutorialDirector:
	return _director


func overlay() -> TutorialOverlay:
	return _overlay


func _new_tracking() -> MatchTracking:
	return MatchTracking.new(func(_n: String, _p: Dictionary) -> void: pass, MatchRecorder.new(null),
			MatchCounter.new(""))


func _build_ui() -> void:
	super._build_ui()
	var hints := _hud.key_hints()
	if hints != null:
		for b: KeyHintBar in hints.bars():
			b.set_state(KeyHintBar.State.SHOWN, false)
	_overlay = TutorialOverlay.new()
	add_child(_overlay)
	_overlay.skip_confirmed.connect(func() -> void: _director.flow.skip())
	_overlay.exit_requested.connect(_leave)
	_overlay.resumed.connect(func() -> void: _locals.reset())  # the button that resumed is not a jump


## Once: the tutorial never ends in a result, so nothing restarts it (a second run would track a
## second tutorial_started).
func _start_match() -> void:
	if _director != null:
		return
	super._start_match()
	var flow := TutorialFlow.new(track, progress, source)
	_director = TutorialDirector.new(_config, flow)
	flow.goal_changed.connect(_on_goal)
	flow.step_completed.connect(_on_step_completed)
	flow.finished.connect(_on_finished)
	_director.begin(_world, _device()[0])
	_hud.set_unlimited_stocks()  # TutorialStaging keeps everyone at 99: show "∞", not the config's 3
	_curr_state = _world.state_view()
	_prev_state = _curr_state


func _gather_inputs() -> Array[InputFrame]:
	return [_locals.sample(TutorialDirector.PLAYER_SLOT), _director.dummy_input(_curr_state)]


func _after_tick(inputs: Array[InputFrame]) -> void:
	_director.after_tick(_curr_state, inputs[TutorialDirector.PLAYER_SLOT])


func _process(delta: float) -> void:
	if _overlay == null or _overlay.is_paused():
		return
	super._process(delta)
	if _celebrate_left > 0.0:
		_celebrate_left -= delta
		if _celebrate_left <= 0.0:
			_director.flow.advance()
	_refresh_hints()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_last_device = TutorialText.DEVICE_KEYBOARD
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion \
			and absf((event as InputEventJoypadMotion).axis_value) > STICK_THRESHOLD):
		_last_device = TutorialText.DEVICE_GAMEPAD
	elif event is InputEventScreenTouch:
		_last_device = TutorialText.DEVICE_TOUCH


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if TutorialOverlay.is_back_event(event):
		_overlay.on_back()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


## [device, pad family]: touch while the touch controls show, else the last device used, else a
## pad if P1 holds one, else the keyboard.
func _device() -> Array[String]:
	var pad := _locals.pads().device_for(PREFIX)
	var device := TutorialText.DEVICE_KEYBOARD
	if _touch != null and _touch.visible:
		device = TutorialText.DEVICE_TOUCH
	elif _last_device == TutorialText.DEVICE_GAMEPAD or (_last_device.is_empty() and pad != GamepadAssigner.NO_DEVICE):
		device = TutorialText.DEVICE_GAMEPAD
	var family := SelectPrompts.pad_family(Input.get_joy_name(pad)) if pad >= 0 else SelectPrompts.FAMILY_XBOX
	return [device, family]


func _line() -> String:
	var d := _device()
	return TutorialText.line(_director.flow.goal(), d[0], d[1], PREFIX)


func _refresh_hints() -> void:
	var hints := _hud.key_hints()
	if hints != null:
		hints.bar().set_highlight(_director.keys_to_press())
	_overlay.set_top_inset(_hud.top_bottom())
	var device := "|".join(_device())
	if device != _shown_device:
		_shown_device = device
		_overlay.card().set_line(_line())


func _on_goal(step: String, _goal: String) -> void:
	var flow := _director.flow
	_overlay.card().show_mission(flow.index() + 1, TutorialSteps.count(), TutorialSteps.title(step), _line(),
			flow.goal_index())
	if flow.goal_index() > 0:
		_presentation.play_ui("ui_click")


func _on_step_completed(_step: String, _index: int) -> void:
	_presentation.play_ui("ui_confirm")
	if not _director.flow.is_done():
		_overlay.card().show_success()
		_celebrate_left = FEEDBACK_S


func _on_finished(completed: bool) -> void:
	_celebrate_left = -1.0
	if completed:
		_overlay.card().show_complete()
	else:
		_leave()


func _leave() -> void:
	if not _leaving:
		_leaving = true
		menu_requested.emit()
