class_name LocalInput
extends RefCounted
## Local player input (PRD §3.1): keyboard actions -> one InputFrame per sim tick.
## Button presses are latched once per rendered frame (poll) and consumed per tick (context D6).
## Touch controls feed the same latches through press_jump / press_light (Task 11).

var _jump := ButtonLatch.new()
var _light := ButtonLatch.new()


func poll() -> void:
	if Input.is_action_just_pressed("p1_jump"):
		_jump.press()
	if Input.is_action_just_pressed("p1_light"):
		_light.press()


func press_jump() -> void:
	_jump.press()


func press_light() -> void:
	_light.press()


func sample() -> InputFrame:
	var move := _move_vector()
	return InputFrame.make(move.x, move.y, _jump.consume(), _light.consume())


func _move_vector() -> Vector2:
	return Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
