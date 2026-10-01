class_name NetInputRepeat
extends RefCounted
## What to assume when a player's next input is unknown (host: a late client packet; client: every
## other fighter during prediction): the last known input with its one-tick presses (jump, light,
## grab) cleared, so movement, charging and guarding carry on but nothing is pressed twice.

const HELD_MASK := InputCodec.HEAVY | InputCodec.GUARD


static func held_only(code: int) -> int:
	return (code & 0xFFFF) | ((InputCodec.buttons(code) & HELD_MASK) << 16)
