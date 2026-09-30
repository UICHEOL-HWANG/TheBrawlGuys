class_name StickNav
extends RefCounted
## Left stick -> one menu step per push (Phase 4 review). Joypad motion arrives as a stream of
## events, so an action check fires on every one past the deadzone; this latches the direction
## when the stick passes PRESS and re-arms only once it falls back under RELEASE.

const PRESS := 0.5
const RELEASE := 0.3

var axis: JoyAxis = JOY_AXIS_LEFT_X
var _latched: int = 0


## -1 / +1 when this motion event starts a push along the axis, else 0.
func step(event: InputEventJoypadMotion) -> int:
	if event.axis != axis:
		return 0
	var v := event.axis_value
	if absf(v) < RELEASE:
		_latched = 0
		return 0
	if absf(v) < PRESS:
		return 0
	var dir := 1 if v > 0.0 else -1
	if dir == _latched:
		return 0
	_latched = dir
	return dir
