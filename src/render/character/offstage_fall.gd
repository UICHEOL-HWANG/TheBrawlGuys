class_name OffstageFall
extends RefCounted
## A body that has dropped past the floor lip leans into its fall and flails on the way down
## (arena-ringout A2): a walk-off pitches head first over the edge, a knocked-off body falls
## back. Render only: FighterView turns its model about the body center; the sim never turns.
## A tumbling launch is left to its own spin.

## How far under the floor top (every floor top is y = 0) a body has to be to count as off.
const LIP_DROP := 0.25
## Lean (rad, + = forward, toward the facing) and how fast it eases in and rights itself.
const LEAN := 0.9
const LEAN_RATE := 3.2
const RIGHTING := 9.0
## Side-to-side flail at full lean (rad) and its rate (Hz).
const FLAIL := 0.22
const FLAIL_HZ := 3.5


static func falling(view: Dictionary) -> bool:
	if bool(view.get("on_ground", true)) or bool(view.get("tumbling", false)):
		return false
	var state := int(view.get("state", Fighter.State.IDLE))
	if state == Fighter.State.KO or state == Fighter.State.HELD:
		return false
	return (view["pos"] as Vector3).y < -LIP_DROP


## The lean after delta: toward the fall's lean (back for a hit), or back to upright.
static func lean(angle: float, view: Dictionary, delta: float) -> float:
	if int(view.get("hitstop_ticks", 0)) > 0:
		return angle
	if not falling(view):
		return move_toward(angle, 0.0, RIGHTING * delta)
	var hit := int(view.get("state", Fighter.State.IDLE)) == Fighter.State.HITSTUN
	var target := -LEAN if hit else LEAN
	# eased in: fast at first, slowing into the full lean
	return move_toward(angle, target, maxf(absf(target - angle), 0.15) * LEAN_RATE * delta)


## Side roll (rad) at time t for a body leaning by angle: scales with the lean, zero upright.
static func flail(angle: float, t: float) -> float:
	return sin(t * TAU * FLAIL_HZ) * FLAIL * clampf(absf(angle) / LEAN, 0.0, 1.0)
