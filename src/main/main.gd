extends Node
## Entry point: fixed 60 Hz sim loop + interpolated rendering (docs/PRD.md §5.4).

const CONFIG_PATH := "res://src/config/default_config.tres"
const SEED := 1
const PLAYER_COUNT := 2

var _config: GameConfig
var _world: World
var _ticker: FixedTicker
var _camera: CameraRig
var _panel: ConfigPanel
## Render interpolation contract: views lerp prev -> curr by _alpha (consumed from Phase 1).
var _prev_state: Dictionary = {}
var _curr_state: Dictionary = {}
var _alpha: float = 0.0
var _tps_ticks: int = 0
var _tps_time: float = 0.0
var _tps: float = 0.0


func _ready() -> void:
	_config = load(CONFIG_PATH) as GameConfig
	if _config == null:
		push_error("main: GameConfig missing at %s" % CONFIG_PATH)
		get_tree().quit(1)
		return
	_world = World.new(_config, SEED)
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
	_panel = ConfigPanel.new()
	add_child(_panel)
	_panel.setup(_config)

	_curr_state = _world.state_view()
	_prev_state = _curr_state


func _process(delta: float) -> void:
	var ticks := _ticker.advance(delta)
	for i: int in ticks:
		_prev_state = _curr_state
		_world.tick(_neutral_inputs())
		_curr_state = _world.state_view()
	_alpha = _ticker.alpha()
	_camera.follow(_arena_bounds(), delta)
	_update_info(delta, ticks)


func _neutral_inputs() -> Array[InputFrame]:
	var inputs: Array[InputFrame] = []
	for i: int in PLAYER_COUNT:
		inputs.append(InputFrame.neutral())
	return inputs


func _arena_bounds() -> PackedVector3Array:
	var r := _config.arena_radius
	return PackedVector3Array([Vector3(-r, 0, 0), Vector3(r, 0, 0), Vector3(0, 0, -r), Vector3(0, 0, r)])


func _update_info(delta: float, ticks: int) -> void:
	_tps_ticks += ticks
	_tps_time += delta
	if _tps_time >= 1.0:
		_tps = _tps_ticks / _tps_time
		_tps_ticks = 0
		_tps_time = 0.0
	_panel.set_info("tick %d · %.0f tps · alpha %.2f · %d fps" % [_world.tick_count, _tps, _alpha, Engine.get_frames_per_second()])
