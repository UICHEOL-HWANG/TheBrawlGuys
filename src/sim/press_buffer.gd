class_name PressBuffer
extends RefCounted
## Keeps one-tick presses (light, jump, grab) made while a fighter is frozen in hitstop and
## replays them on its first tick after the freeze (Phase 3 carry-over: hitstop used to swallow
## latched presses, dropping combo inputs). Held levels (heavy, guard) need no buffer: the
## current level applies once the freeze ends. Runs on the World's input copies before any step.

const LIGHT := 1
const JUMP := 2
const GRAB := 4


static func apply(fighters: Array[Fighter], frame: Array[InputFrame]) -> void:
	for f: Fighter in fighters:
		var input := frame[f.id]
		if f.hitstop_ticks > 0:
			f.held_presses |= mask_of(input)
		elif f.held_presses != 0:
			input.light = input.light or (f.held_presses & LIGHT) != 0
			input.jump = input.jump or (f.held_presses & JUMP) != 0
			input.grab = input.grab or (f.held_presses & GRAB) != 0
			f.held_presses = 0


static func mask_of(input: InputFrame) -> int:
	return (LIGHT if input.light else 0) | (JUMP if input.jump else 0) | (GRAB if input.grab else 0)
