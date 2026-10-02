extends Node
## Match scene (PRD §5.4, platform B1): fixed 60 Hz sim + interpolated rendering of a MatchSetup — local
## players (PRD-LOCAL-01) or bots, items, HUD, result, restart, telemetry; camera, feel and sound live in
## MatchPresentation; NetMatch (src/net) extends it online. The app sets `setup` and `menu_available`.

signal menu_requested

const CONFIG_PATH := "res://src/config/default_config.tres"
## Default setup slots; debug scenes that extend this script address fighters by them.
const LOCAL_PLAYER := 0
const BOT_PLAYER := 1

var setup: MatchSetup = null
## Shows "메뉴로" on the result banner (only when an app shell can take the player back).
var menu_available: bool = false
## The signed-in player's nickname (App: ProfileStore); shown on their card when they play alone.
var nickname: String = ""
## Seed for each rematch (App: MatchSeed.fresh); empty = rematches replay setup.seed (debug scenes).
var new_seed: Callable = Callable()

var _config: GameConfig
var _world: World
var _ticker: FixedTicker
var _stage: MatchStage
var _presentation: MatchPresentation
## The finishing replay before the result banner (GD-CAM-02).
var _finale: MatchFinale
var _locals: LocalPlayers
var _touch: TouchInput
## The match's bots: dial, probe, DDA and bot tracking (PRD-BOT-03~06).
var _squad: BotSquad
var _hud: Hud
var _result_shown: bool = false
## Platform A6: reads sim/view events only, never writes to the sim.
var _tracking: MatchTracking
## Render interpolation contract: views lerp prev -> curr by _alpha.
var _prev_state: Dictionary = {}
var _curr_state: Dictionary = {}
var _alpha: float = 0.0
var _debug := MatchDebugInfo.new()


func _ready() -> void:
	_tracking = _new_tracking()  # load time starts here
	_config = load(CONFIG_PATH) as GameConfig
	if _config == null:
		push_error("main: GameConfig missing at %s" % CONFIG_PATH)
		get_tree().quit(1)
		set_process(false)
		return
	if setup == null:
		setup = MatchSetup.vs_bots(_player_count(), MatchSetup.DEFAULT_SEED)
	InputBindings.apply()
	_ticker = FixedTicker.new(_config.max_ticks_per_frame)
	_config.changed.connect(func() -> void: _ticker.max_ticks_per_frame = _config.max_ticks_per_frame)
	_stage = MatchStage.new()
	add_child(_stage)
	_stage.setup(_config, setup.seed, setup.player_count(), setup.arena_id, setup.characters())
	_presentation = MatchPresentation.new()
	add_child(_presentation)
	_presentation.setup(_config)
	_finale = MatchFinale.new()
	add_child(_finale)
	_build_ui()
	_finale.setup(_config, _stage, _presentation, _hud)
	_finale.revealed.connect(func() -> void: _tracking.on_result_shown())
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
	add_child(_debug)
	_debug.setup(_config)


## Match telemetry; the tutorial (extends main) swaps in a silent one (it is not a match).
func _new_tracking() -> MatchTracking:
	return MatchTracking.new(Analytics.track, MatchRecorder.create_default())


## Fighter count of the default setup; scenes that extend main override it (perf_match uses four).
func _player_count() -> int:
	return MatchSetup.DEFAULT_PLAYERS


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
	_finale.reset()
	if _world != null and new_seed.is_valid():
		setup.seed = int(new_seed.call())  # rematch: same line-up, new randomness
	_world = setup.build_world(_config)
	_squad = BotSquadFactory.for_setup(setup, _config)
	_hud.setup(setup.player_count(), _config.stocks, _world.state_view()["mode"], setup.characters(), _config)
	_hud.set_menu_available(menu_available)
	_hud.show_name(setup.local_slot(), nickname if setup.local_slots().size() == 1 else "")
	_result_shown = false
	_curr_state = _world.state_view()
	_prev_state = _curr_state
	_presentation.restart()
	setup.set_input_devices(_locals.input_devices())
	_tracking.begin(setup, _world, _squad.context())
	_tracking.telemetry().set_slot_extras(_squad.slot_summary)


## One input per slot in slot order: the local device or that slot's bot.
func _gather_inputs() -> Array[InputFrame]:
	var inputs: Array[InputFrame] = []
	for s: Dictionary in setup.slots:
		if s["controller"] == MatchSetup.CONTROLLER_LOCAL:
			inputs.append(_locals.sample(int(s["slot"])))
		else:
			inputs.append(_squad.sample(int(s["slot"]), _curr_state))
	return inputs


func _process(delta: float) -> void:
	_locals.poll()
	if _finale.is_playing():
		_finale.play(delta, setup.local_slot(), _touch)
		return
	var ticks := _ticker.advance(delta)
	var events: Array = []
	var view_events: Array = []
	for i: int in ticks:
		_prev_state = _curr_state
		var inputs := _gather_inputs()
		_step(inputs)
		var tick_view_events := ViewEvents.detect(_prev_state["fighters"], _curr_state["fighters"], _config)
		events.append_array(_curr_state["events"])
		view_events.append_array(tick_view_events)
		_tracking.on_tick(_curr_state["events"], tick_view_events, _curr_state, inputs)
		_squad.after_tick(_curr_state, _tracking.telemetry())
		_finale.record(_curr_state)
		_after_tick(inputs)
	_alpha = _ticker.alpha()
	if bool(_curr_state["match_over"]) and not _result_shown:
		_result_shown = true
		_tracking.finish(_curr_state)
		Analytics.set_user_properties(_squad.finish(_curr_state))
		# The banner speaks for the lone human, or names the winner when two share the screen.
		var viewer := setup.local_slot() if _locals.slots().size() == 1 else ResultBanner.NO_LOCAL
		if _finale.reveal(int(_curr_state["winner"]), viewer):  # the replay presents this frame's events
			_hud.update_from(_curr_state, events)
			return
	_stage.draw(_prev_state, _curr_state, _alpha, delta)
	_stage.on_events(events)
	_hud.update_from(_curr_state, events)
	_presentation.set_hud_reserve(_hud.reserve())
	_presentation.present(_curr_state, events, view_events, delta, setup.local_slot(), _touch)
	_tracking.on_frame_time(delta)
	_debug.on_frame(delta, ticks, _world.tick_count, _alpha)


## One sim tick on the gathered inputs, leaving its view in _curr_state (NetMatch clients predict).
func _step(inputs: Array[InputFrame]) -> void:
	var started := Time.get_ticks_usec()
	_world.tick(inputs)
	_debug.add_sim_cost(Time.get_ticks_usec() - started)
	_curr_state = _world.state_view()


## After each sim tick (_curr_state is its view); scenes that extend main hook in here.
func _after_tick(_inputs: Array[InputFrame]) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if _finale.is_playing() and MatchFinale.is_skip_event(event):
		_finale.skip()
		get_viewport().set_input_as_handled()
	elif _result_shown and event.is_action_pressed("ui_accept"):
		_start_match()


func _exit_tree() -> void:
	if _locals != null:
		_locals.detach()
	if _tracking != null:
		_tracking.close_for_exit(_curr_state)
