class_name MatchFinale
extends Node
## Reveals the match result (design.md GD-CAM-02): first the finishing replay when the match ended
## on a ring-out — FinisherReplay ticks drawn on the MatchStage and presented (feel, SFX, the
## camera close shot on the knocked-out fighter) with Engine.time_scale slowed to its speed — then
## the winners cheer in a close shot (VictoryCeremony), then the banner comes up at the bottom
## while they keep cheering. A draw goes straight to the banner. Never writes to the sim;
## time_scale goes back to 1 on stop, reset and leaving the scene.

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
## The final sim view the winners cheer in, and who they are.
var _final: Dictionary = {}
var _winners: Array[int] = []
## Seconds since the cheer began (the close shot keeps easing after the banner); < 0 = none.
var _cheer_s: float = -1.0
var _banner_up: bool = false
var _reduce_motion: bool = false


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


## The match just ended (Hud.show_result arguments; final: the ending sim view). True while the
## replay or the cheer plays first (they present the ending tick); false when the banner is up.
func reveal(winner: int, viewer: int, final: Dictionary) -> bool:
	_winner = winner
	_viewer = viewer
	_final = final
	_winners = VictoryCeremony.winners(final)
	_reduce_motion = SpecialCutInDirector.reduce_motion_setting(SettingsStore.new())
	if not _replay.start(_reduce_motion):
		return _cheer()
	Engine.time_scale = _replay.speed()
	return true


## Accept, a tap or a click: cuts the replay short (on to the cheer), or the cheer (banner now).
func skip() -> void:
	if _replay.is_active():
		_end_replay()
		_cheer()
	elif is_playing():
		_show_banner()


## Whether this input skips a playing replay.
static func is_skip_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		return event.is_pressed()
	return event.is_action_pressed("ui_accept")


func is_playing() -> bool:
	return _replay.is_active() or (_cheer_s >= 0.0 and not _banner_up)


## One frame of the replay (delta is game time) or of the cheer; the banner shows when it ends.
func play(delta: float, local_slot: int, touch: TouchInput) -> void:
	if not _replay.is_active():
		_stage.draw(_final, _final, 1.0, delta)
		_presentation.present(_final, [], [], delta, local_slot, touch)
		if _cheer_s >= VictoryCeremony.SECONDS:
			_show_banner()
		return
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


## The winners' close shot eases in (and holds behind the banner) on real time.
func _process(delta: float) -> void:
	if _cheer_s < 0.0 or _replay.is_active():
		return
	_cheer_s += delta
	var weight := 0.0 if _reduce_motion else VictoryCeremony.camera_weight(_final, _winners, _cheer_s)
	_presentation.set_finisher_focus(VictoryCeremony.focus(_final, _winners), weight)


func stop() -> void:
	_end_replay()
	_cheer_s = -1.0
	_banner_up = false
	if _stage != null:
		_stage.set_cheering([])


func _end_replay() -> void:
	_replay.stop()
	_previous = {}
	Engine.time_scale = 1.0
	if _presentation != null:
		_presentation.set_finisher_focus(Vector3.ZERO, 0.0)


## The winners start cheering; with none (a draw) the banner comes up now. True while cheering.
func _cheer() -> bool:
	if _winners.is_empty():
		_show_banner()
		return false
	_cheer_s = 0.0
	_stage.set_cheering(_winners)
	return true


func _show_banner() -> void:
	_banner_up = true
	_hud.show_result(_winner, _viewer)
	revealed.emit()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
