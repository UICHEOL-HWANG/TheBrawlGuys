class_name LocalInput
extends RefCounted
## Local player input (PRD §3.1): keyboard actions -> one InputFrame per sim tick.
## Button presses are latched once per rendered frame (poll) and consumed per tick (context D6).
## Touch controls feed the same latches through press_jump / press_light (Task 11).

var _jump := ButtonLatch.new()
var _light := ButtonLatch.new()
## Set by TouchInput; when the stick is held it overrides the keyboard move vector.
var touch_stick: TouchStickModel = null
## Process frame of the last reset(); poll() ignores keys still "just pressed" in that frame.
var _reset_frame: int = -1


func poll() -> void:
	if Engine.get_process_frames() == _reset_frame:
		return
	if Input.is_action_just_pressed("p1_jump"):
		_jump.press()
	if Input.is_action_just_pressed("p1_light"):
		_light.press()


func press_jump() -> void:
	_jump.press()


func press_light() -> void:
	_light.press()


## Drops any latched press (e.g. the Space that confirmed a restart also counts as p1_jump).
## Called from input handling, so the same frame's poll() must not re-latch the key.
func reset() -> void:
	_reset_frame = Engine.get_process_frames()
	_jump.consume()
	_light.consume()


func sample() -> InputFrame:
	var move := _move_vector()
	return InputFrame.make(move.x, move.y, _jump.consume(), _light.consume())


func _move_vector() -> Vector2:
	if touch_stick != null and touch_stick.active():
		return touch_stick.vector()
	return Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
