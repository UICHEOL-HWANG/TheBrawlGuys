class_name AttackButtonModel
extends RefCounted
## Touch attack button gesture (PRD §3.3): a tap shorter than touch_hold_threshold is a light
## attack on release; holding past it is a held heavy (charge) that swings on release. A canceled
## tap does nothing; a canceled charge still releases (the sim cannot un-charge), except on focus
## loss, where TouchInput cancels every finger and then resets the input latches so nothing fires
## afterwards. Time is passed in (seconds) so the model stays pure.

enum Result { NONE, LIGHT, HEAVY_RELEASE }

const UP := -1.0
## Float slack so a hold measured exactly at the threshold counts (1.15 - 1.0 < 0.15 in doubles).
const EPSILON := 0.000001

var threshold: float
var _down_at: float = UP


func _init(p_threshold: float) -> void:
	threshold = p_threshold


func press(t: float) -> void:
	_down_at = t


func is_down() -> bool:
	return _down_at != UP


func holding_heavy(t: float) -> bool:
	return is_down() and t - _down_at >= threshold - EPSILON


## Seconds of charge (0 until the hold turns into a heavy).
func charge_time(t: float) -> float:
	return maxf(t - _down_at - threshold, 0.0) if is_down() else 0.0


func release(t: float, canceled: bool = false) -> int:
	if not is_down():
		return Result.NONE
	var heavy := holding_heavy(t)
	_down_at = UP
	if heavy:
		return Result.HEAVY_RELEASE
	return Result.NONE if canceled else Result.LIGHT
