class_name World
extends RefCounted
## Pure game state (PRD §5.2). Never reference Node, SceneTree, Input, RenderingServer or PhysicsServer3D here.

const SNAPSHOT_VERSION := 1

var config: GameConfig
var tick_count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_config: GameConfig, p_seed: int = 0) -> void:
	config = p_config
	_rng.seed = p_seed


func tick(_inputs: Array[InputFrame]) -> void:
	tick_count += 1


func rand_int(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Plain value data only (ints/floats/Vector types/Arrays and Dictionaries of the same):
## never references to live sim objects, so the render layer can keep prev/curr copies
## that stay valid after later ticks.
func state_view() -> Dictionary:
	return {"tick": tick_count}


func snapshot() -> PackedByteArray:
	return var_to_bytes({
		"v": SNAPSHOT_VERSION,
		"tick": tick_count,
		"rng_seed": _rng.seed,
		"rng_state": _rng.state,
	})


func restore(data: PackedByteArray) -> bool:
	var decoded: Variant = bytes_to_var(data) if data.size() > 4 else null
	if not (decoded is Dictionary) or (decoded as Dictionary).get("v") != SNAPSHOT_VERSION:
		push_error("World.restore: incompatible snapshot")
		return false
	var s: Dictionary = decoded
	# Validate all required keys are present and correct type before mutating state
	if not (s.has("tick") and s["tick"] is int and
			s.has("rng_seed") and s["rng_seed"] is int and
			s.has("rng_state") and s["rng_state"] is int):
		push_error("World.restore: incomplete snapshot")
		return false
	tick_count = s["tick"]
	_rng.seed = s["rng_seed"]
	_rng.state = s["rng_state"]
	return true


func state_hash() -> int:
	return hash(snapshot())
