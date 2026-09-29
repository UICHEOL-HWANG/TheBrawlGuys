class_name World
extends RefCounted
## Pure game state (PRD §5.2). Never reference Node, SceneTree, Input, RenderingServer or PhysicsServer3D here.
## Tick order: Motion.step per fighter -> Motion.separate -> Combat.resolve -> Rules.apply -> winner.
## The config is a tracked sim input: its fingerprint is part of every snapshot (context D1).

const SNAPSHOT_VERSION := 2
const DEFAULT_PLAYER_COUNT := 2
const SNAPSHOT_TYPES := {
	"tick": TYPE_INT, "rng_seed": TYPE_INT, "rng_state": TYPE_INT, "config_fp": TYPE_INT,
	"match_over": TYPE_BOOL, "winner": TYPE_INT, "fighters": TYPE_ARRAY,
}

var config: GameConfig
var tick_count: int = 0
var fighters: Array[Fighter] = []
var match_over: bool = false
var winner_id: int = Rules.ONGOING
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Events produced by the most recent tick (plain data, e.g. hits and ring-outs).
var _events: Array[Dictionary] = []


func _init(p_config: GameConfig, p_seed: int = 0, p_player_count: int = DEFAULT_PLAYER_COUNT) -> void:
	config = p_config
	_rng.seed = p_seed
	for i: int in p_player_count:
		fighters.append(Rules.spawn_fighter(i, p_player_count, config))


func tick(inputs: Array[InputFrame]) -> void:
	_events = []
	if not match_over:
		var attack := AttackData.light_from(config)
		for f: Fighter in fighters:
			var input: InputFrame = inputs[f.id] if f.id < inputs.size() else InputFrame.neutral()
			Motion.step(f, input, config, attack)
		Motion.separate(fighters, config)
		_events.append_array(Combat.resolve(fighters, attack, config))
	tick_count += 1


func rand_int(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Plain value data only (ints/floats/Vector types/Arrays and Dictionaries of the same):
## never references to live sim objects, so the render layer can keep prev/curr copies
## that stay valid after later ticks.
func state_view() -> Dictionary:
	var views: Array[Dictionary] = []
	for f: Fighter in fighters:
		views.append(f.to_view())
	return {
		"tick": tick_count,
		"arena_radius": config.arena_radius,
		"match_over": match_over,
		"winner": winner_id,
		"fighters": views,
		"events": _events.duplicate(true),
	}


func snapshot() -> PackedByteArray:
	var data: Array[Dictionary] = []
	for f: Fighter in fighters:
		data.append(f.to_data())
	return var_to_bytes({
		"v": SNAPSHOT_VERSION,
		"tick": tick_count,
		"rng_seed": _rng.seed,
		"rng_state": _rng.state,
		"config_fp": config.fingerprint(),
		"match_over": match_over,
		"winner": winner_id,
		"fighters": data,
	})


func restore(data: PackedByteArray) -> bool:
	var decoded: Variant = bytes_to_var(data) if data.size() > 4 else null
	if not (decoded is Dictionary) or (decoded as Dictionary).get("v") != SNAPSHOT_VERSION:
		push_error("World.restore: incompatible snapshot")
		return false
	var s: Dictionary = decoded
	for key: String in SNAPSHOT_TYPES:
		if not s.has(key) or typeof(s[key]) != SNAPSHOT_TYPES[key]:
			push_error("World.restore: incomplete snapshot")
			return false
	if s["config_fp"] != config.fingerprint():
		push_error("World.restore: config mismatch")
		return false
	var restored: Array[Fighter] = []
	for d: Variant in s["fighters"]:
		var f: Fighter = Fighter.from_data(d) if d is Dictionary else null
		if f == null:
			push_error("World.restore: invalid fighter data")
			return false
		restored.append(f)
	tick_count = s["tick"]
	_rng.seed = s["rng_seed"]
	_rng.state = s["rng_state"]
	match_over = s["match_over"]
	winner_id = s["winner"]
	fighters = restored
	_events = []
	return true


func state_hash() -> int:
	return hash(snapshot())
