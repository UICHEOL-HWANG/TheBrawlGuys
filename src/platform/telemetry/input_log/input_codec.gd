class_name InputCodec
extends RefCounted
## One InputFrame as a 24-bit int (platform A7): byte 0 = move_x step + 127, byte 1 = move_z step
## + 127, byte 2 = button bits. Move axes are quantized to 1/MOVE_STEPS (InputFrame.make), so the
## code is exact: unpack(pack(f)) gives bit-identical floats and the sim replays the same run.

const AXIS_OFFSET := InputFrame.MOVE_STEPS
const BYTE_MASK := 0xFF
const JUMP := 1
const LIGHT := 2
const HEAVY := 4
const GUARD := 8
const GRAB := 16
## pack(InputFrame.neutral()).
const NEUTRAL := AXIS_OFFSET | (AXIS_OFFSET << 8)


static func pack(f: InputFrame) -> int:
	var bits := (JUMP if f.jump else 0) | (LIGHT if f.light else 0) | (HEAVY if f.heavy else 0) \
			| (GUARD if f.guard else 0) | (GRAB if f.grab else 0)
	return _axis_byte(f.move_x) | (_axis_byte(f.move_z) << 8) | (bits << 16)


static func unpack(code: int) -> InputFrame:
	var f := InputFrame.new()
	f.move_x = axis(code, 0)
	f.move_z = axis(code, 1)
	var bits := buttons(code)
	f.jump = bits & JUMP != 0
	f.light = bits & LIGHT != 0
	f.heavy = bits & HEAVY != 0
	f.guard = bits & GUARD != 0
	f.grab = bits & GRAB != 0
	return f


## Button bits of a code (feature extraction reads presses without unpacking).
static func buttons(code: int) -> int:
	return (code >> 16) & BYTE_MASK


## Move axis 0 (x) or 1 (z); same expression as InputFrame.quantize_axis, so the float is identical.
static func axis(code: int, index: int) -> float:
	var b := (code >> (8 * index)) & BYTE_MASK
	return float(b - AXIS_OFFSET) / InputFrame.MOVE_STEPS


static func _axis_byte(v: float) -> int:
	return clampi(roundi(v * InputFrame.MOVE_STEPS), -AXIS_OFFSET, AXIS_OFFSET) + AXIS_OFFSET
