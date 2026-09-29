class_name SimTime
extends RefCounted
## Fixed simulation clock (PRD §5.4). Durations in GameConfig are seconds; the sim counts ticks.

const TICK_RATE := 60
const TICK_DT := 1.0 / TICK_RATE


static func to_ticks(seconds: float) -> int:
	return maxi(roundi(seconds * TICK_RATE), 0)
