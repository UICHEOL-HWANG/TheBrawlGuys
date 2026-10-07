class_name TouchActions
extends RefCounted
## What the touch buttons send to LocalInput (TouchInput): attack tap = light on release, hold =
## heavy charge (AttackButtonModel), sent once while held past the threshold and ended on
## release; jump and grab fire on press; guard holds while touched.

var _local: LocalInput
var _attack: AttackButtonModel
var _heavy_sent: bool = false


func _init(local: LocalInput, hold_threshold: float) -> void:
	_local = local
	_attack = AttackButtonModel.new(hold_threshold)


## Seconds the attack button has been charging (0 when not holding a heavy).
func charge_time(now: float) -> float:
	return _attack.charge_time(now)


func press(name: String, now: float) -> void:
	match name:
		"attack":
			_attack.press(now)
		"jump":
			_local.press_jump()
		"guard":
			_local.set_touch_guard(true)
		"grab":
			_local.press_grab()


func release(name: String, now: float, canceled: bool) -> void:
	match name:
		"attack":
			var result := _attack.release(now, canceled)
			if result == AttackButtonModel.Result.LIGHT:
				_local.press_light()
			elif result == AttackButtonModel.Result.HEAVY_RELEASE:
				_local.set_touch_heavy(true)  # a no-op when hold_attack already sent it
				_local.set_touch_heavy(false)
			_heavy_sent = false
		"guard":
			_local.set_touch_guard(false)


## Each frame the attack button is down: true while it holds a heavy (sent to LocalInput once).
func hold_attack(now: float) -> bool:
	if not _attack.holding_heavy(now):
		return false
	if not _heavy_sent:
		_heavy_sent = true
		_local.set_touch_heavy(true)
	return true
