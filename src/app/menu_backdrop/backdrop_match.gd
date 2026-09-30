class_name BackdropMatch
extends RefCounted
## The menu backdrop brawl (design.md DS-LAY-03): four step-2 bots on a real World, stepped by
## the fixed 60 Hz ticker with the real rules (ring-outs, respawns, items). A finished match
## restarts after a short pause with the next seed. Sim and bots only: no input, no telemetry.

const PLAYERS := 4
const RESTART_DELAY_S := 2.0

var world: World
var prev_state: Dictionary = {}
var curr_state: Dictionary = {}

var _config: GameConfig
var _seed: int
var _setup: MatchSetup
var _ticker: FixedTicker
var _bots: Array[BotController] = []
var _over_s: float = 0.0
var _matches: int = 0


func _init(config: GameConfig, first_seed: int) -> void:
	_config = config
	_seed = first_seed
	_ticker = FixedTicker.new(config.max_ticks_per_frame)
	_start()


## Steps the sim for delta seconds; returns this frame's sim events (for guard wobbles).
func advance(delta: float) -> Array:
	var events: Array = []
	if bool(curr_state["match_over"]):
		_over_s += delta
		if _over_s >= RESTART_DELAY_S:
			_seed += 1
			_start()
		return events
	for i: int in _ticker.advance(delta):
		prev_state = curr_state
		var inputs: Array[InputFrame] = []
		for b: BotController in _bots:
			inputs.append(b.sample(curr_state))
		world.tick(inputs)
		curr_state = world.state_view()
		events.append_array(curr_state["events"])
	return events


func alpha() -> float:
	return _ticker.alpha()


func matches_started() -> int:
	return _matches


func _start() -> void:
	_setup = MatchSetup.all_bots(PLAYERS, _seed)
	world = World.new(_config, _setup.seed, PLAYERS, _setup.build_arena(_config))
	_bots.clear()
	for slot: int in _setup.bot_slots():
		_bots.append(BotController.new(slot, _config))
	curr_state = world.state_view()
	prev_state = curr_state
	_over_s = 0.0
	_matches += 1
