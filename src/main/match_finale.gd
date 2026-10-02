class_name MatchFinale
extends Node
## Reveals the match result (design.md GD-CAM-02): the banner right away, or first the finishing
## replay when the match ended on a ring-out — FinisherReplay ticks drawn on the MatchStage and
## presented (feel, SFX, the camera close shot on the knocked-out fighter) with Engine.time_scale
## slowed to its speed. Never writes to the sim; time_scale goes back to 1 on stop, reset and
## leaving the scene.

## The banner is up (right away or after the replay).
signal revealed

var _config: GameConfig
var _stage: MatchStage
var _presentation: MatchPresentation
var _hud: Hud
var _winner: int = -1
var _viewer: int = ResultBanner.NO_LOCAL
var _replay := FinisherReplay.new()
## The last tick presented, so view events (trails, dust) compare consecutive ticks.
var _previous: Dictionary = {}


func setup(config: GameConfig, stage: MatchStage, presentation: MatchPresentation, hud: Hud) -> void:
	_config = config
	_stage = stage
	_presentation = presentation
	_hud = hud


## Every sim tick's view, in order.
func record(view: Dictionary) -> void:
	_replay.record(view)


## A new match: nothing playing, nothing buffered.
func reset() -> void:
	stop()
	_replay.clear()


## The match just ended (Hud.show_result arguments). True while the replay plays first (it presents
## the ending tick itself); false when the banner is already up.
func reveal(winner: int, viewer: int) -> bool:
	_winner = winner
	_viewer = viewer
	if not _replay.start(SpecialCutInDirector.reduce_motion_setting(SettingsStore.new())):
		_show_banner()
		return false
	Engine.time_scale = _replay.speed()
	return true


## Cuts the replay short and shows the banner (accept, a tap or a click while it plays).
func skip() -> void:
	if is_playing():
		stop()
		_show_banner()


## Whether this input skips a playing replay.
static func is_skip_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		return event.is_pressed()
	return event.is_action_pressed("ui_accept")


func is_playing() -> bool:
	return _replay.is_active()


## One frame of the replay (delta is game time); the banner shows when it ends.
func play(delta: float, local_slot: int, touch: TouchInput) -> void:
	var step := _replay.advance(delta)
	var events: Array = []
	var view_events: Array = []
	for f: Dictionary in step["frames"]:
		var before: Dictionary = _previous if not _previous.is_empty() else step["prev"]
		events.append_array(f["events"])
		view_events.append_array(ViewEvents.detect(before["fighters"], f["fighters"], _config))
		_previous = f
	_stage.draw(step["prev"], step["curr"], float(step["alpha"]), delta)
	_stage.on_events(events)
	var at := _replay.focus(step)
	at.y = maxf(at.y, DecorView.GROUND_Y)  # a fall past the edge keeps the shot on the arena
	_presentation.set_finisher_focus(at, _replay.camera_weight())
	_presentation.present(step["curr"], events, view_events, delta, local_slot, touch)
	Engine.time_scale = _replay.speed()
	if bool(step["done"]):
		skip()


func stop() -> void:
	_replay.stop()
	_previous = {}
	Engine.time_scale = 1.0
	if _presentation != null:
		_presentation.set_finisher_focus(Vector3.ZERO, 0.0)


func _show_banner() -> void:
	_hud.show_result(_winner, _viewer)
	revealed.emit()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
