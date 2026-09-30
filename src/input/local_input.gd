class_name LocalInput
extends RefCounted
## Local player input (PRD §3.1-3.2): one player's actions ("<prefix>_*", PRD-LOCAL-01: p1 / p2,
## keys and any assigned pad) and touch controls -> one InputFrame per sim tick. Presses (jump, light, grab) are latched once per rendered frame and consumed per
## tick (Phase 1 D6); held buttons (heavy, guard) go through HoldLatch so a tap is never lost
## (context E3). Touch feeds the same latches through press_* / set_touch_*.

var _jump := ButtonLatch.new()
var _light := ButtonLatch.new()
var _grab := ButtonLatch.new()
var _heavy := HoldLatch.new()
var _guard := HoldLatch.new()
var _touch_heavy: bool = false
var _touch_guard: bool = false
## Set by TouchInput; when the stick is held it overrides the keyboard move vector.
var touch_stick: TouchStickModel = null
## Process frame of the last reset(); poll() ignores keys still "just pressed" in that frame.
var _reset_frame: int = -1
var _prefix: String
## Action names by short name ("jump" -> "p2_jump"), built once.
var _a: Dictionary = {}


func _init(p_prefix: String = "p1") -> void:
	_prefix = p_prefix
	for n: String in InputBindings.NAMES:
		_a[n] = InputBindings.action(p_prefix, n)


func prefix() -> String:
	return _prefix


func poll() -> void:
	if Engine.get_process_frames() == _reset_frame:
		return
	if Input.is_action_just_pressed(_a["jump"]):
		_jump.press()
	if Input.is_action_just_pressed(_a["light"]):
		_light.press()
	if Input.is_action_just_pressed(_a["grab"]):
		_grab.press()
	if Input.is_action_just_pressed(_a["heavy"]):
		_heavy.press()
	if Input.is_action_just_pressed(_a["guard"]):
		_guard.press()
	_heavy.set_held(Input.is_action_pressed(_a["heavy"]) or _touch_heavy)
	_guard.set_held(Input.is_action_pressed(_a["guard"]) or _touch_guard)


func press_jump() -> void:
	_jump.press()


func press_light() -> void:
	_light.press()


func press_grab() -> void:
	_grab.press()


func set_touch_heavy(held: bool) -> void:
	_touch_heavy = held
	_heavy.set_held(held or _key_held(_a["heavy"]))


func set_touch_guard(held: bool) -> void:
	_touch_guard = held
	_guard.set_held(held or _key_held(_a["guard"]))


## Drops any latched press (e.g. the Space that confirmed a restart also counts as p1_jump).
## Called from input handling, so the same frame's poll() must not re-latch the key.
func reset() -> void:
	_reset_frame = Engine.get_process_frames()
	_jump.consume()
	_light.consume()
	_grab.consume()
	_heavy.clear()
	_guard.clear()


func sample() -> InputFrame:
	var move := _move_vector()
	return InputFrame.make(move.x, move.y, _jump.consume(), _light.consume(),
			_heavy.consume(), _guard.consume(), _grab.consume())


func _move_vector() -> Vector2:
	if touch_stick != null and touch_stick.active():
		return touch_stick.vector()
	return Input.get_vector(_a["left"], _a["right"], _a["up"], _a["down"])


static func _key_held(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)
