class_name TumbleSpin
extends RefCounted
## A strong launch tumbles (Fighter.tumble): the body flips backward head over heels while it
## flies, then rights itself fast once the tumble ends (a landing, a knockdown, a tech) —
## polish-pass 7, the "과장된 넉백" read. Render only: CharacterModel.set_tumble turns the
## drawn model about its body center; the sim capsule never turns.

## Flip speed (rad/s, negative: the head goes backward, away from the facing).
const RATE := -TAU * 1.6
## How fast the body rights itself after the tumble (rad/s).
const RIGHTING := TAU * 3.0


static func spinning(view: Dictionary) -> bool:
	var state := int(view.get("state", Fighter.State.IDLE))
	var flying := state == Fighter.State.HITSTUN or state == Fighter.State.AIR
	return flying and bool(view.get("tumbling", false)) and not bool(view.get("on_ground", true))


## The flip angle after delta: spinning on, or eased back to upright along the shorter way.
static func step(angle: float, spin: bool, delta: float) -> float:
	if spin:
		return wrapf(angle + RATE * delta, -TAU, TAU)
	return move_toward(wrapf(angle, -PI, PI), 0.0, RIGHTING * delta)
