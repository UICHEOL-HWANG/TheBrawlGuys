class_name InputFrame
extends RefCounted
## One tick of player intent. Keyboard, touch, bot and network all produce this (PRD §3.1).

var move_x: float = 0.0
var move_z: float = 0.0
var jump: bool = false
var light: bool = false
var heavy: bool = false
var guard: bool = false
var grab: bool = false

## Move axes are quantized to 1/MOVE_STEPS so keyboard, touch, bot and network inputs are
## bit-identical for the same intent (context D5).
const MOVE_STEPS := 127


static func neutral() -> InputFrame:
	return InputFrame.new()


func copy() -> InputFrame:
	var f := InputFrame.new()
	f.move_x = move_x
	f.move_z = move_z
	f.jump = jump
	f.light = light
	f.heavy = heavy
	f.guard = guard
	f.grab = grab
	return f


## Never -0.0: a tiny negative intent is plain zero, as the input log stores it (InputCodec);
## -0.0 would flip an atan2 facing or aim and the replay would drift.
static func quantize_axis(v: float) -> float:
	var q := roundf(clampf(v, -1.0, 1.0) * MOVE_STEPS) / MOVE_STEPS
	return 0.0 if q == 0.0 else q


static func make(mx: float, mz: float, p_jump: bool = false, p_light: bool = false,
		p_heavy: bool = false, p_guard: bool = false, p_grab: bool = false) -> InputFrame:
	var f := InputFrame.new()
	f.move_x = quantize_axis(mx)
	f.move_z = quantize_axis(mz)
	f.jump = p_jump
	f.light = p_light
	f.heavy = p_heavy
	f.guard = p_guard
	f.grab = p_grab
	return f
