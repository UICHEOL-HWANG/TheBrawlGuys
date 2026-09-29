class_name FixedTicker
extends RefCounted
## Fixed 60 Hz accumulator (PRD §5.4). Caps ticks per frame to avoid the spiral of death.

const TICK_RATE := SimTime.TICK_RATE
const TICK_DT := SimTime.TICK_DT
## Absorbs float drift so 60 frames of 1/60 s give exactly 60 ticks.
const EPSILON := 1e-9

var max_ticks_per_frame: int
var _accumulator: float = 0.0


func _init(p_max_ticks_per_frame: int = 5) -> void:
	max_ticks_per_frame = p_max_ticks_per_frame


func advance(delta: float) -> int:
	_accumulator += maxf(delta, 0.0)
	var ticks := 0
	while _accumulator + EPSILON >= TICK_DT and ticks < max_ticks_per_frame:
		_accumulator -= TICK_DT
		ticks += 1
	if _accumulator + EPSILON >= TICK_DT:
		_accumulator = 0.0
	_accumulator = maxf(_accumulator, 0.0)
	return ticks


func alpha() -> float:
	return clampf(_accumulator / TICK_DT, 0.0, 0.9999)
