extends GutTest
## Character select input routing (Phase 5 T9, PRD-LOCAL-01): which player a key, pad button or
## stick push belongs to, and what it does. Alone, every device drives P1 (arena select keys
## too); with two humans P1 = arrows · Z · X, P2 = A D · F · G and each pad drives the player
## GamepadAssigner gave it (A confirms, B cancels, d-pad / stick browse).

const R := preload("res://src/app/screens/character_select_input.gd")


func _key(code: Key, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	e.echo = echo
	return e


func _button(device: int, button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = true
	return e


func _stick(device: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = value
	return e


func _pads(owner: Dictionary) -> Callable:
	return func(device: int) -> int: return int(owner.get(device, -1))


func _cmd(r: Dictionary) -> Array:
	return [r.get("seat", -1), r.get("cmd", R.NONE), r.get("step", 0), r.get("device", "")]


func test_alone_every_device_drives_p1() -> void:
	var r := R.new(false, _pads({}))
	assert_eq(_cmd(r.route(_key(KEY_RIGHT))), [0, R.MOVE, 1, "keyboard"])
	assert_eq(_cmd(r.route(_key(KEY_Z))), [0, R.CONFIRM, 0, "keyboard"])
	assert_eq(_cmd(r.route(_key(KEY_ENTER))), [0, R.CONFIRM, 0, "keyboard"])
	assert_eq(_cmd(r.route(_key(KEY_ESCAPE))), [0, R.CANCEL, 0, "keyboard"])
	assert_eq(_cmd(r.route(_key(KEY_X))), [0, R.CANCEL, 0, "keyboard"])
	assert_eq(_cmd(r.route(_button(3, JOY_BUTTON_A))), [0, R.CONFIRM, 0, "gamepad"], "any pad")
	assert_eq(_cmd(r.route(_button(3, JOY_BUTTON_DPAD_LEFT))), [0, R.MOVE, -1, "gamepad"])
	assert_eq(_cmd(r.route(_key(KEY_Z, true))), [0, R.HELD, 0, "keyboard"], "key repeat is swallowed, not repeated")
	assert_eq(_cmd(r.route(_key(KEY_Q, true))), [-1, R.NONE, 0, ""], "unmapped repeats are left alone")


func test_two_players_split_the_keyboard() -> void:
	var r := R.new(true, _pads({}))
	assert_eq(_cmd(r.route(_key(KEY_LEFT))), [0, R.MOVE, -1, "keyboard"])
	assert_eq(_cmd(r.route(_key(KEY_Z))), [0, R.CONFIRM, 0, "keyboard"])
	assert_eq(_cmd(r.route(_key(KEY_X))), [0, R.CANCEL, 0, "keyboard"])
	assert_eq(_cmd(r.route(_key(KEY_D))), [1, R.MOVE, 1, "keyboard"])
	assert_eq(_cmd(r.route(_key(KEY_A))), [1, R.MOVE, -1, "keyboard"])
	assert_eq(_cmd(r.route(_key(KEY_F))), [1, R.CONFIRM, 0, "keyboard"])
	assert_eq(_cmd(r.route(_key(KEY_G))), [1, R.CANCEL, 0, "keyboard"])
	assert_eq(_cmd(r.route(_key(KEY_SPACE))), [-1, R.NONE, 0, ""], "P1's jump key is not a menu key here")


func test_two_players_each_pad_drives_its_owner() -> void:
	var r := R.new(true, _pads({4: 1, 7: 0}))
	assert_eq(_cmd(r.route(_button(4, JOY_BUTTON_A))), [1, R.CONFIRM, 0, "gamepad"])
	assert_eq(_cmd(r.route(_button(7, JOY_BUTTON_B))), [0, R.CANCEL, 0, "gamepad"])
	assert_eq(_cmd(r.route(_button(9, JOY_BUTTON_A))), [-1, R.NONE, 0, ""], "a pad nobody holds does nothing")


func test_each_seat_latches_its_own_stick() -> void:
	var r := R.new(true, _pads({4: 1, 7: 0}))
	assert_eq(_cmd(r.route(_stick(4, 0.9))), [1, R.MOVE, 1, "gamepad"])
	assert_eq(_cmd(r.route(_stick(7, 0.9))), [0, R.MOVE, 1, "gamepad"], "P1's stick has its own latch")
	var held := r.route(_stick(4, 1.0))
	assert_eq(held.get("cmd", R.NONE), R.HELD, "a held stick is swallowed, not repeated")
	r.route(_stick(4, 0.0))
	assert_eq(_cmd(r.route(_stick(4, -0.8))), [1, R.MOVE, -1, "gamepad"])
