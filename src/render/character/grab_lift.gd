class_name GrabLift
extends RefCounted
## A held fighter is drawn lifted a little off its feet (combat-motion A3): with the holder's
## arms out and the victim's flinch pose, it reads as "picked up" instead of two fighters
## overlapping. Render only (the sim keeps the victim on the ground); eased in and out per frame.

const HEIGHT := 0.28
const FRAMES := 6


static func step(current: float, held: bool) -> float:
	return move_toward(current, HEIGHT if held else 0.0, HEIGHT / FRAMES)
