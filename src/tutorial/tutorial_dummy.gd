class_name TutorialDummy
extends RefCounted
## The tutorial's practice partner (Phase 5 T11): stands still for every mission except the guard
## one, where it walks up to the player and swings a light attack every SWING_EVERY_TICKS so
## there is something to block. Attacks come out along facing, so it turns toward the player for
## one tick before each swing (like BotController).

const SWING_EVERY_TICKS := 80
const TURN_TICKS := 1

var _slot: int
var _target: int
var _range: float
## Counts down only while in range, so the first swing comes a moment after it arrives.
var _cooldown: int = SWING_EVERY_TICKS / 2
var _turned: int = 0


func _init(slot: int, target_slot: int, config: GameConfig) -> void:
	_slot = slot
	_target = target_slot
	_range = config.bot_attack_range


## active: the guard mission is on (otherwise the dummy does nothing).
func sample(view: Dictionary, active: bool) -> InputFrame:
	var me := TutorialDetector.fighter(view, _slot)
	var foe := TutorialDetector.fighter(view, _target)
	if not active or me.is_empty() or foe.is_empty() or int(me["state"]) == Fighter.State.KO \
			or int(foe["state"]) == Fighter.State.KO:
		_turned = 0
		return InputFrame.neutral()
	var a: Vector3 = me["pos"]
	var b: Vector3 = foe["pos"]
	var to := Vector2(b.x - a.x, b.z - a.z)
	if to.length() > _range:
		_turned = 0
		var dir := to.normalized()
		return InputFrame.make(dir.x, dir.y)
	return _swing(to.normalized())


func _swing(dir: Vector2) -> InputFrame:
	if _cooldown > 0:
		_cooldown -= 1
		return InputFrame.neutral()
	if _turned < TURN_TICKS:
		_turned += 1
		return InputFrame.make(dir.x, dir.y)
	_turned = 0
	_cooldown = SWING_EVERY_TICKS
	return InputFrame.make(0.0, 0.0, false, true)
