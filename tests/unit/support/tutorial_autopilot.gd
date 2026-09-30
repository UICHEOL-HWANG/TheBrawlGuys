extends RefCounted
## A scripted tutorial player for tests: for the current goal it walks to the dummy (or the bat)
## and presses what the card asks, pulsing one-tick buttons like LocalInput does. Plays against a
## real World so the detector sees genuine sim events.

const REACH := 1.1
const GRAB_REACH := 0.95
const CHARGE_TICKS := 30

var _tick: int = 0
var _charge: int = 0


func sample(view: Dictionary, goal: String) -> InputFrame:
	_tick += 1
	var me := TutorialDetector.fighter(view, TutorialDirector.PLAYER_SLOT)
	var foe := TutorialDetector.fighter(view, TutorialDirector.DUMMY_SLOT)
	var pulse := _tick % 2 == 0
	match goal:
		TutorialSteps.G_MOVE:
			return InputFrame.make(1.0 if (_tick / 40) % 2 == 0 else -1.0, 0.0)
		TutorialSteps.G_JUMP:
			return InputFrame.make(0.0, 0.0, _tick % 20 == 0)
		TutorialSteps.G_GUARD:
			return InputFrame.make(0.0, 0.0, false, false, false, true)
		TutorialSteps.G_THROW:
			return InputFrame.make(0.0, 0.0, false, false, false, false, pulse)
		TutorialSteps.G_ITEM_USE:
			return InputFrame.make(0.0, 0.0, false, pulse)
		TutorialSteps.G_SPECIAL:
			return InputFrame.make(0.0, 0.0, false, false, true, true)
		TutorialSteps.G_PICKUP:
			return _to_item(view, me, pulse)
	return _fight(goal, me, foe, pulse)


func _fight(goal: String, me: Dictionary, foe: Dictionary, pulse: bool) -> InputFrame:
	var reach := GRAB_REACH if goal == TutorialSteps.G_GRAB else REACH
	var to := _flat(me, foe["pos"])
	if to.length() > reach:
		_charge = 0
		return InputFrame.make(to.normalized().x, to.normalized().y)
	match goal:
		TutorialSteps.G_LIGHT_HIT:
			return InputFrame.make(0.0, 0.0, false, pulse)
		TutorialSteps.G_GRAB:
			return InputFrame.make(0.0, 0.0, false, false, false, false, pulse)
	_charge += 1
	var holding := _charge % (CHARGE_TICKS + 10) < CHARGE_TICKS
	return InputFrame.make(0.0, 0.0, false, false, holding)


func _to_item(view: Dictionary, me: Dictionary, pulse: bool) -> InputFrame:
	var items: Array = view.get("items", [])
	if items.is_empty():
		return InputFrame.neutral()
	var to := _flat(me, (items[0] as Dictionary)["pos"])
	if to.length() > 0.4:
		return InputFrame.make(to.normalized().x, to.normalized().y)
	return InputFrame.make(0.0, 0.0, false, false, false, false, pulse)


func _flat(me: Dictionary, target: Vector3) -> Vector2:
	var a: Vector3 = me["pos"]
	return Vector2(target.x - a.x, target.z - a.z)
