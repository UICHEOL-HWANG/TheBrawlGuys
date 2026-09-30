extends Node
## Match scene: fixed 60 Hz sim loop + interpolated rendering (docs/PRD.md §5.4) for the
## MatchSetup it is given (platform B1) — local keyboard/touch/pad (up to two humans, PRD-LOCAL-01)
## or a bot per slot, items, HUD,
## result, restart and telemetry; camera, feel and sound live in MatchPresentation. The app shell
## sets `setup` and `menu_available` before adding it; run alone (main.tscn) it plays 1 vs bot.

signal menu_requested

const CONFIG_PATH := "res://src/config/default_config.tres"
const SEED := MatchSetup.DEFAULT_SEED
const PLAYER_COUNT := MatchSetup.DEFAULT_PLAYERS
## Default setup slots; debug scenes that extend this script address fighters by them.
const LOCAL_PLAYER := 0
const BOT_PLAYER := 1

var setup: MatchSetup = null
## Shows "메뉴로" on the result banner (only when an app shell can take the player back).
var menu_available: bool = false
## Seed for each rematch (the App passes MatchSeed.fresh); empty = rematches replay setup.seed
## (perf / debug scenes, main.tscn alone).
var new_seed: Callable = Callable()

var _config: GameConfig
var _world: World
var _ticker: FixedTicker
var _stage: MatchStage
var _presentation: MatchPresentation
var _panel: ConfigPanel
var _locals: LocalPlayers
var _touch: TouchInput
var _bots: Array[BotController] = []
var _hud: Hud
var _result_shown: bool = false
## Platform A6: reads sim/view events only, never writes to the sim.
var _tracking: MatchTracking
## Render interpolation contract: views lerp prev -> curr by _alpha.
var _prev_state: Dictionary = {}
var _curr_state: Dictionary = {}
var _alpha: float = 0.0
var _stats := TickStats.new()


func _ready() -> void:
	_tracking = MatchTracking.new(Analytics.track, MatchRecorder.create_default())  # load time starts here
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
	_stage = MatchStage.new()
	add_child(_stage)
	_stage.setup(_config, setup.seed, setup.player_count(), setup.arena_id, setup.characters())
	_presentation = MatchPresentation.new()
	add_child(_presentation)
	_presentation.setup(_config)
	_build_ui()
	LookPreset.apply(_config.look_preset)
	_config.changed.connect(func() -> void: LookPreset.apply(_config.look_preset))
	_config.changed.connect(func() -> void: AudioBuses.ensure(_config))
	_start_match()


func _build_ui() -> void:
	_locals = LocalPlayers.new(setup.local_slots())
	_locals.attach()
	_touch = TouchInput.new()
	add_child(_touch)
	_touch.setup(_locals.primary(), _config)
	_touch.button_pressed.connect(func(_n: String) -> void: _presentation.play_ui("ui_click"))
	_hud = Hud.new()
	add_child(_hud)
	_hud.restart_requested.connect(_start_match)
	_hud.restart_requested.connect(func() -> void: _presentation.play_ui("ui_confirm"))
	_hud.menu_requested.connect(func() -> void:
		_tracking.on_menu()
		menu_requested.emit())
	if not _locals.slots().is_empty():
		_hud.show_key_hints(_locals.hint_players(), func() -> bool: return _touch.visible)
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
	_locals.reset()
	_stage.clear_items()
	if _world != null and new_seed.is_valid():
		setup.seed = int(new_seed.call())  # rematch: same line-up, new randomness
	_world = World.new(_config, setup.seed, setup.player_count(), setup.build_arena(_config), setup.characters())
	_bots.clear()
	for slot: int in setup.bot_slots():
		_bots.append(BotController.new(slot, _config))
	_hud.setup(setup.player_count(), _config.stocks)
	_hud.set_menu_available(menu_available)
	_result_shown = false
	_curr_state = _world.state_view()
	_prev_state = _curr_state
	_presentation.restart()
	setup.set_input_devices(_locals.input_devices())
	_tracking.begin(setup, _world)


## One input per slot in slot order: the local device or that slot's bot.
func _gather_inputs() -> Array[InputFrame]:
	var inputs: Array[InputFrame] = []
	var next_bot := 0
	for s: Dictionary in setup.slots:
		if s["controller"] == MatchSetup.CONTROLLER_LOCAL:
			inputs.append(_locals.sample(int(s["slot"])))
		else:
			inputs.append(_bots[next_bot].sample(_curr_state))
			next_bot += 1
	return inputs


func _process(delta: float) -> void:
	_locals.poll()
	var ticks := _ticker.advance(delta)
	var events: Array = []
	var view_events: Array = []
	for i: int in ticks:
		_prev_state = _curr_state
		var inputs := _gather_inputs()
		var started := Time.get_ticks_usec()
		_world.tick(inputs)
		_stats.add_sim_cost(Time.get_ticks_usec() - started)
		_curr_state = _world.state_view()
		var tick_view_events := ViewEvents.detect(_prev_state["fighters"], _curr_state["fighters"], _config)
		events.append_array(_curr_state["events"])
		view_events.append_array(tick_view_events)
		_tracking.on_tick(_curr_state["events"], tick_view_events, _curr_state, inputs)
	_alpha = _ticker.alpha()
	_stage.draw(_prev_state, _curr_state, _alpha, delta)
	_stage.on_events(events)
	_hud.update_from(_curr_state)
	_presentation.present(_curr_state, events, view_events, delta, setup.local_slot(), _touch)
	if bool(_curr_state["match_over"]) and not _result_shown:
		_result_shown = true
		_hud.show_result(int(_curr_state["winner"]), _result_viewer())
		_tracking.finish(_curr_state)
	_stats.add_frame(delta, ticks)
	_tracking.on_frame_time(delta)
	if _panel != null:
		_panel.set_info(_stats.info(_world.tick_count, _alpha))


func _unhandled_input(event: InputEvent) -> void:
	if _result_shown and event.is_action_pressed("ui_accept"):
		_start_match()


## Whose win or loss the banner speaks for: the lone human, or nobody when two share the screen.
func _result_viewer() -> int:
	return setup.local_slot() if _locals.slots().size() == 1 else ResultBanner.NO_LOCAL


func _exit_tree() -> void:
	if _locals != null:
		_locals.detach()
	if _tracking != null:
		_tracking.close_for_exit(_curr_state)
