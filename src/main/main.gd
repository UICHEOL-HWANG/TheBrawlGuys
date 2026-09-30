extends Node
## Match scene: fixed 60 Hz sim loop + interpolated rendering (docs/PRD.md §5.4) for the
## MatchSetup it is given (platform B1) — local keyboard/touch or a bot per slot, items, HUD,
## charge gauges, grab hints, game feel, result, restart and telemetry. The app shell sets
## `setup` and `menu_available` before adding it; run alone (main.tscn) it plays 1 vs bot.

signal menu_requested

const CONFIG_PATH := "res://src/config/default_config.tres"
const SEED := MatchSetup.DEFAULT_SEED
const PLAYER_COUNT := MatchSetup.DEFAULT_PLAYERS
## Default setup slots; debug scenes that extend this script address fighters by them.
const LOCAL_PLAYER := 0
const BOT_PLAYER := 1
## Smoothing factor for the per-tick sim cost shown in the debug panel.
const SIM_COST_SMOOTHING := 0.1

var setup: MatchSetup = null
## Shows "메뉴로" on the result banner (only when an app shell can take the player back).
var menu_available: bool = false

var _config: GameConfig
var _world: World
var _ticker: FixedTicker
var _stage: MatchStage
var _camera: CameraRig
var _panel: ConfigPanel
var _local_input: LocalInput
var _touch: TouchInput
var _bots: Array[BotController] = []
var _grab_hint: GrabHint
var _gauges: ChargeGaugeLayer
var _hud: Hud
var _feel: FeelDirector
var _sfx: SfxDirector
var _music: MusicDirector
var _result_shown: bool = false
## Platform A6: reads sim/view events only, never writes to the sim.
var _tracking: MatchTracking
## Render interpolation contract: views lerp prev -> curr by _alpha.
var _prev_state: Dictionary = {}
var _curr_state: Dictionary = {}
var _alpha: float = 0.0
var _stats := TickStats.new()


func _ready() -> void:
	_config = load(CONFIG_PATH) as GameConfig
	if _config == null:
		push_error("main: GameConfig missing at %s" % CONFIG_PATH)
		get_tree().quit(1)
		set_process(false)
		return
	if setup == null:
		setup = MatchSetup.vs_bots(_player_count(), SEED)
	InputBindings.apply()
	_ticker = FixedTicker.new(_config.max_ticks_per_frame)
	_config.changed.connect(func() -> void: _ticker.max_ticks_per_frame = _config.max_ticks_per_frame)
	_build_world()
	_build_ui()
	LookPreset.apply(_config.look_preset)
	_config.changed.connect(func() -> void: LookPreset.apply(_config.look_preset))
	_config.changed.connect(func() -> void: AudioBuses.ensure(_config))
	_tracking = MatchTracking.new(Analytics.track, MatchRecorder.create_default())
	_start_match()


func _build_world() -> void:
	_stage = MatchStage.new()
	add_child(_stage)
	_stage.setup(_config, setup.seed, setup.player_count())
	_camera = CameraRig.new()
	add_child(_camera)
	_camera.setup(_config)
	_feel = FeelDirector.new()
	add_child(_feel)
	_feel.setup(_config, _camera)
	_sfx = SfxDirector.new()
	add_child(_sfx)
	_sfx.setup(_config)
	_music = MusicDirector.new()
	add_child(_music)
	_music.setup(_config)
	_grab_hint = GrabHint.new()
	add_child(_grab_hint)
	_grab_hint.setup(_config)


func _build_ui() -> void:
	_local_input = LocalInput.new()
	_touch = TouchInput.new()
	add_child(_touch)
	_touch.setup(_local_input, _config)
	_touch.button_pressed.connect(func(_n: String) -> void: _sfx.play_ui("ui_click"))
	_gauges = ChargeGaugeLayer.new()
	add_child(_gauges)
	_hud = Hud.new()
	add_child(_hud)
	_hud.restart_requested.connect(_start_match)
	_hud.restart_requested.connect(func() -> void: _sfx.play_ui("ui_confirm"))
	_hud.menu_requested.connect(func() -> void: menu_requested.emit())
	if OS.is_debug_build():
		_panel = ConfigPanel.new()
		add_child(_panel)
		_panel.setup(_config)


## Fighter count of the default setup; scenes that extend main override it (perf_match uses four).
func _player_count() -> int:
	return PLAYER_COUNT


func get_world() -> World:
	return _world


func get_hud() -> Hud:
	return _hud


func get_item_layer() -> ItemLayer:
	return _stage.item_layer()


func get_telemetry() -> MatchTelemetry:
	return _tracking.telemetry()


func _start_match() -> void:
	_tracking.close_for_restart(_curr_state, _result_shown)
	_local_input.reset()
	_feel.reset()
	_stage.clear_items()
	_world = World.new(_config, setup.seed, setup.player_count(), setup.build_arena(_config))
	_bots.clear()
	for slot: int in setup.bot_slots():
		_bots.append(BotController.new(slot, _config))
	_hud.setup(setup.player_count(), _config.stocks)
	_hud.set_menu_available(menu_available)
	_result_shown = false
	_curr_state = _world.state_view()
	_prev_state = _curr_state
	_music.play_battle()
	_tracking.begin(setup)


## One input per slot in slot order: the local device or that slot's bot.
func _gather_inputs() -> Array[InputFrame]:
	var inputs: Array[InputFrame] = []
	var next_bot := 0
	for s: Dictionary in setup.slots:
		if s["controller"] == MatchSetup.CONTROLLER_LOCAL:
			inputs.append(_local_input.sample())
		else:
			inputs.append(_bots[next_bot].sample(_curr_state))
			next_bot += 1
	return inputs


func _process(delta: float) -> void:
	_local_input.poll()
	var ticks := _ticker.advance(delta)
	var events: Array = []
	var view_events: Array = []
	for i: int in ticks:
		_prev_state = _curr_state
		var started := Time.get_ticks_usec()
		_world.tick(_gather_inputs())
		_stats.add_sim_cost(Time.get_ticks_usec() - started, SIM_COST_SMOOTHING)
		_curr_state = _world.state_view()
		var tick_view_events := ViewEvents.detect(_prev_state["fighters"], _curr_state["fighters"], _config)
		events.append_array(_curr_state["events"])
		view_events.append_array(tick_view_events)
		_tracking.on_tick(_curr_state["events"], tick_view_events, _curr_state)
	_alpha = _ticker.alpha()
	_stage.draw(_prev_state, _curr_state, _alpha, delta)
	_present(events, view_events, delta)
	if bool(_curr_state["match_over"]) and not _result_shown:
		_result_shown = true
		_hud.show_result(int(_curr_state["winner"]), setup.local_slot())
		_tracking.finish(_curr_state)
	_update_info(delta, ticks)


func _present(events: Array, view_events: Array, delta: float) -> void:
	_hud.update_from(_curr_state)
	_music.update_from(_curr_state)
	_feel.on_events(events)
	_feel.on_view_events(view_events)
	_sfx.on_events(events)
	_sfx.on_events(view_events)
	_stage.wobble_guards(events)
	LocalHints.update(_curr_state, setup.local_slot(), _config, _touch, _grab_hint)
	_camera.follow(_camera_targets(), delta)
	_gauges.update_from(_curr_state, _config, _camera.unproject)


func _unhandled_input(event: InputEvent) -> void:
	if _result_shown and event.is_action_pressed("ui_accept"):
		_start_match()


func _exit_tree() -> void:
	if _tracking != null:
		_tracking.close_for_exit(_curr_state)


func _camera_targets() -> PackedVector3Array:
	var pts := CameraFraming.arena_anchors(_config.arena_radius, _config.cam_arena_share)
	for f: Dictionary in _curr_state["fighters"]:
		if int(f["state"]) != Fighter.State.KO:
			pts.append(f["pos"])
	return pts


func _update_info(delta: float, ticks: int) -> void:
	_stats.add_frame(delta, ticks)
	if _panel != null:
		_panel.set_info("tick %d · %s · alpha %.2f · %d fps" % [
			_world.tick_count, _stats.text(), _alpha, Engine.get_frames_per_second()])
