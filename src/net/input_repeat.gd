class_name NetInputRepeat
extends RefCounted
## What to assume when a player's next input is unknown (host: a late client packet; client: every
## other fighter during prediction): the last known input with its one-tick presses (jump, light,
## grab) cleared, so movement, charging and guarding carry on but nothing is pressed twice.

const HELD_MASK := InputCodec.HEAVY | InputCodec.GUARD
const PRESS_MASK := InputCodec.JUMP | InputCodec.LIGHT | InputCodec.GRAB


static func held_only(code: int) -> int:
	return (code & 0xFFFF) | ((InputCodec.buttons(code) & HELD_MASK) << 16)


## code with the one-tick presses of `from` added (two inputs folded into one tick).
static func add_presses(code: int, from: int) -> int:
	return code | ((InputCodec.buttons(from) & PRESS_MASK) << 16)
