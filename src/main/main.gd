extends Node
## Entry point: fixed 60 Hz sim loop + interpolated rendering (docs/PRD.md §5.4).
## Phase 2: local player (keyboard + four-button touch) vs bot step 2, items, HUD, charge gauges,
## grab hints, game feel, result and restart.

const CONFIG_PATH := "res://src/config/default_config.tres"
const SEED := 1
const PLAYER_COUNT := 2
const LOCAL_PLAYER := 0
const BOT_PLAYER := 1
## Smoothing factor for the per-tick sim cost shown in the debug panel.
const SIM_COST_SMOOTHING := 0.1

var _config: GameConfig
var _world: World
var _ticker: FixedTicker
var _camera: CameraRig
var _panel: ConfigPanel
var _local_input: LocalInput
var _touch: TouchInput
var _bot: BotController
var _views: Array[FighterView] = []
var _item_layer: ItemLayer
var _grab_hint: GrabHint
var _gauges: ChargeGaugeLayer
var _hud: Hud
var _feel: FeelDirector
var _result_shown: bool = false
## Render interpolation contract: views lerp prev -> curr by _alpha.
var _prev_state: Dictionary = {}
var _curr_state: Dictionary = {}
var _alpha: float = 0.0
var _tps_ticks: int = 0
var _tps_time: float = 0.0
var _tps: float = 0.0
var _sim_us: float = 0.0


func _ready() -> void:
	_config = load(CONFIG_PATH) as GameConfig
	if _config == null:
		push_error("main: GameConfig missing at %s" % CONFIG_PATH)
		get_tree().quit(1)
		set_process(false)
		return
	InputBindings.apply()
	_ticker = FixedTicker.new(_config.max_ticks_per_frame)
	_config.changed.connect(func() -> void: _ticker.max_ticks_per_frame = _config.max_ticks_per_frame)

	var env := EnvironmentRig.new()
	add_child(env)
	env.setup()
	var arena := ArenaView.new()
	add_child(arena)
	arena.setup(_config)
	var decor := DecorView.new()
	add_child(decor)
	decor.setup(_config, SEED)
	_camera = CameraRig.new()
	add_child(_camera)
	_camera.setup(_config)
	_feel = FeelDirector.new()
	add_child(_feel)
	_feel.setup(_config, _camera)
	for i: int in PLAYER_COUNT:
		var view := FighterView.new()
		add_child(view)
		view.setup(i, _config)
		_views.append(view)
	_item_layer = ItemLayer.new()
	add_child(_item_layer)
	_item_layer.setup(_config)
	_grab_hint = GrabHint.new()
	add_child(_grab_hint)
	_grab_hint.setup(_config)

	_local_input = LocalInput.new()
	_touch = TouchInput.new()
	add_child(_touch)
	_touch.setup(_local_input, _config)
	_gauges = ChargeGaugeLayer.new()
	add_child(_gauges)
	_hud = Hud.new()
	add_child(_hud)
	_hud.restart_requested.connect(_start_match)
	if OS.is_debug_build():
		_panel = ConfigPanel.new()
		add_child(_panel)
		_panel.setup(_config)
	_start_match()


func get_world() -> World:
	return _world


func get_hud() -> Hud:
	return _hud


func get_item_layer() -> ItemLayer:
	return _item_layer


func _start_match() -> void:
	_local_input.reset()
	_feel.reset()
	_world = World.new(_config, SEED, PLAYER_COUNT)
	_bot = BotController.new(BOT_PLAYER, _config)
	_hud.setup(PLAYER_COUNT, _config.stocks)
	_result_shown = false
	_curr_state = _world.state_view()
	_prev_state = _curr_state


func _gather_inputs() -> Array[InputFrame]:
	var inputs: Array[InputFrame] = [_local_input.sample(), _bot.sample(_curr_state)]
	return inputs


func _process(delta: float) -> void:
	_local_input.poll()
	var ticks := _ticker.advance(delta)
	var events: Array = []
	for i: int in ticks:
		_prev_state = _curr_state
		var started := Time.get_ticks_usec()
		_world.tick(_gather_inputs())
		_sim_us = lerpf(_sim_us, float(Time.get_ticks_usec() - started), SIM_COST_SMOOTHING)
		_curr_state = _world.state_view()
		events.append_array(_curr_state["events"])
	_alpha = _ticker.alpha()
	_draw_fighters()
	_item_layer.sync(_prev_state["items"], _curr_state["items"], _alpha, int(_curr_state["tick"]))
	_hud.update_from(_curr_state)
	_feel.on_events(events)
	_wobble_guards(events)
	_update_local_hints()
	_camera.follow(_camera_targets(), delta)
	_gauges.update_from(_curr_state, _config, _camera.unproject)
	if bool(_curr_state["match_over"]) and not _result_shown:
		_result_shown = true
		_hud.show_result(int(_curr_state["winner"]), LOCAL_PLAYER)
	_update_info(delta, ticks)


func _unhandled_input(event: InputEvent) -> void:
	if _result_shown and event.is_action_pressed("ui_accept"):
		_start_match()


func _draw_fighters() -> void:
	var prev: Array = _prev_state["fighters"]
	var curr: Array = _curr_state["fighters"]
	var tick := int(_curr_state["tick"])
	for i: int in _views.size():
		var before: Dictionary = prev[i] if i < prev.size() else {}
		_views[i].apply(before, curr[i], _alpha, tick)


func _wobble_guards(events: Array) -> void:
	for e: Dictionary in events:
		if String(e["type"]) == "guard_hit":
			var id := int(e["target"])
			if id < _views.size():
				_views[id].wobble()


## Grab button highlight, grab target ring and disabled touch buttons for the local player.
func _update_local_hints() -> void:
	var me: Dictionary = _curr_state["fighters"][LOCAL_PLAYER]
	var active := int(me["state"]) != Fighter.State.KO and not bool(_curr_state["match_over"])
	_touch.set_enabled(active)
	var ctx := GrabContext.evaluate(_curr_state, LOCAL_PLAYER, _config)
	var kind := int(ctx["kind"])
	_touch.set_grab_highlight(active and kind != GrabContext.Kind.NONE)
	if active and (kind == GrabContext.Kind.ITEM or kind == GrabContext.Kind.FIGHTER):
		_grab_hint.show_at(ctx["pos"])
	else:
		_grab_hint.hide_hint()


func _camera_targets() -> PackedVector3Array:
	var r := _config.arena_radius
	var pts := PackedVector3Array([Vector3(-r, 0, 0), Vector3(r, 0, 0), Vector3(0, 0, -r), Vector3(0, 0, r)])
	for f: Dictionary in _curr_state["fighters"]:
		if int(f["state"]) != Fighter.State.KO:
			pts.append(f["pos"])
	return pts


func _update_info(delta: float, ticks: int) -> void:
	_tps_ticks += ticks
	_tps_time += delta
	if _tps_time >= 1.0:
		_tps = _tps_ticks / _tps_time
		_tps_ticks = 0
		_tps_time = 0.0
	if _panel == null:
		return
	_panel.set_info("tick %d · %.0f tps · sim %.3f ms · alpha %.2f · %d fps" % [
		_world.tick_count, _tps, _sim_us / 1000.0, _alpha, Engine.get_frames_per_second()])
