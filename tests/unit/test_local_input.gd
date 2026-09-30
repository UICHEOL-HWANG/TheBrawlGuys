extends GutTest
## Local 2-player input (PRD-LOCAL-01, PRD §3.2): P2 keys, the per-player special chord (heavy +
## guard on the same tick: P1 X+C, P2 G+H, pad Y+RB) and gamepad auto-assignment.

const P2_KEYS := {
	"p2_left": KEY_A, "p2_right": KEY_D, "p2_up": KEY_W, "p2_down": KEY_S,
	"p2_jump": KEY_Q, "p2_light": KEY_F, "p2_heavy": KEY_G, "p2_guard": KEY_H, "p2_grab": KEY_J,
}


func before_each() -> void:
	InputBindings.apply()


func after_each() -> void:
	for prefix: String in InputBindings.PREFIXES:
		for action: String in InputBindings.actions(prefix):
			Input.action_release(action)
		PadBindings.unbind(prefix)


func _keys(action: String) -> Array[int]:
	var keys: Array[int] = []
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			keys.append((ev as InputEventKey).physical_keycode)
	return keys


func _pad_button(device: int, button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = true
	return ev


func test_p2_actions_exist_with_the_user_keys() -> void:
	for action: String in P2_KEYS:
		assert_true(InputMap.has_action(action), action)
		assert_eq(_keys(action), [P2_KEYS[action]] as Array[int], action)


func test_player_keys_do_not_overlap() -> void:
	var p1: Array[int] = []
	for action: String in InputBindings.actions("p1"):
		p1.append_array(_keys(action))
	for action: String in InputBindings.actions("p2"):
		for key: int in _keys(action):
			assert_false(p1.has(key), "%s key %d is also a P1 key" % [action, key])
	assert_false(p1.has(KEY_F2) or _keys("p2_guard").has(KEY_F2), "F2 stays the key-bar toggle")


func test_p2_input_reads_only_p2_actions() -> void:
	var p1 := LocalInput.new()
	var p2 := LocalInput.new("p2")
	assert_eq(p1.prefix(), "p1", "P1 is the default")
	Input.action_press("p2_right")
	Input.action_press("p2_up")
	var f2 := p2.sample()
	assert_gt(f2.move_x, 0.0)
	assert_lt(f2.move_z, 0.0)
	assert_eq(p1.sample().move_x, 0.0, "WASD does not move P1")
	Input.action_release("p2_right")
	Input.action_release("p2_up")
	Input.action_press("p1_left")
	assert_eq(p2.sample().move_x, 0.0, "arrows do not move P2")


func test_p2_presses_latch_like_p1() -> void:
	var p2 := LocalInput.new("p2")
	await get_tree().process_frame
	Input.action_press("p2_jump")
	Input.action_press("p2_light")
	Input.action_press("p2_grab")
	p2.poll()
	var a := p2.sample()
	assert_true(a.jump and a.light and a.grab)
	var b := p2.sample()
	assert_false(b.jump or b.light or b.grab, "a press reaches exactly one tick")


func test_special_chord_is_heavy_and_guard_per_player() -> void:
	assert_eq(InputBindings.special_actions("p1"), ["p1_heavy", "p1_guard"] as Array[String])
	assert_eq(InputBindings.special_actions("p2"), ["p2_heavy", "p2_guard"] as Array[String])
	assert_eq(KeyHintSource.combo_text(InputBindings.special_actions("p1")), "X+C")
	assert_eq(KeyHintSource.combo_text(InputBindings.special_actions("p2")), "G+H")


func test_p2_special_reaches_one_tick_with_heavy_and_guard() -> void:
	var p1 := LocalInput.new()
	var p2 := LocalInput.new("p2")
	await get_tree().process_frame
	Input.action_press("p2_heavy")
	Input.action_press("p2_guard")
	p1.poll()
	p2.poll()
	var f := p2.sample()
	assert_true(f.heavy and f.guard, "G+H on the same tick is P2's special input")
	var other := p1.sample()
	assert_false(other.heavy or other.guard, "P2's chord never reaches P1")


func test_special_taps_in_separate_frames_before_a_tick_still_share_it() -> void:
	# G tapped and released, then H pressed, both before the next tick: one frame carries both.
	var p2 := LocalInput.new("p2")
	await get_tree().process_frame
	Input.action_press("p2_heavy")
	p2.poll()
	Input.action_release("p2_heavy")
	await get_tree().process_frame
	Input.action_press("p2_guard")
	p2.poll()
	var f := p2.sample()
	assert_true(f.heavy and f.guard)
	var next := p2.sample()
	assert_false(next.heavy, "the tapped heavy is spent")


func test_one_key_alone_is_not_the_special() -> void:
	var p2 := LocalInput.new("p2")
	await get_tree().process_frame
	Input.action_press("p2_heavy")
	p2.poll()
	var f := p2.sample()
	assert_true(f.heavy)
	assert_false(f.guard)


func test_first_pad_goes_to_the_first_player_without_one() -> void:
	var pads := GamepadAssigner.new(["p1", "p2"] as Array[String])
	assert_eq(pads.device_for("p1"), GamepadAssigner.NO_DEVICE)
	pads.connect_device(4)
	assert_eq(pads.device_for("p1"), 4)
	assert_eq(pads.device_for("p2"), GamepadAssigner.NO_DEVICE)
	pads.connect_device(2)
	assert_eq(pads.device_for("p2"), 2, "the second pad to connect goes to P2, whatever its id")
	pads.connect_device(7)
	assert_eq(pads.player_for(7), "", "a third pad waits")


func test_disconnect_frees_the_player_and_a_waiting_pad_takes_over() -> void:
	var pads := GamepadAssigner.new(["p1", "p2"] as Array[String])
	for d: int in [0, 1, 2]:
		pads.connect_device(d)
	pads.disconnect_device(0)
	assert_eq(pads.device_for("p1"), 2, "the waiting pad fills the freed player")
	assert_eq(pads.device_for("p2"), 1, "other players keep their pad")
	pads.disconnect_device(2)
	assert_eq(pads.device_for("p1"), GamepadAssigner.NO_DEVICE)
	pads.connect_device(0)
	assert_eq(pads.device_for("p1"), 0, "a reconnected pad fills the first padless player")


func test_duplicate_and_unknown_events_are_ignored() -> void:
	var pads := GamepadAssigner.new(["p1", "p2"] as Array[String])
	pads.connect_device(3)
	pads.connect_device(3)
	assert_eq(pads.device_for("p2"), GamepadAssigner.NO_DEVICE, "the same pad twice is one pad")
	pads.disconnect_device(9)
	assert_eq(pads.device_for("p1"), 3)


func test_single_player_takes_the_first_pad() -> void:
	var pads := GamepadAssigner.new(["p1"] as Array[String])
	pads.sync([5, 1] as Array[int])
	assert_eq(pads.device_for("p1"), 1, "pads present at start go in id order")


func test_assignment_binds_the_pad_to_that_players_actions_only() -> void:
	var pads := GamepadAssigner.new(["p1", "p2"] as Array[String])
	pads.connect_device(6)
	pads.connect_device(3)
	var jump := _pad_button(3, JOY_BUTTON_A)
	assert_true(InputMap.event_is_action(jump, "p2_jump"), "pad 3 = P2")
	assert_false(InputMap.event_is_action(jump, "p1_jump"))
	assert_true(InputMap.event_is_action(_pad_button(6, JOY_BUTTON_A), "p1_jump"), "pad 6 = P1")
	assert_true(InputMap.event_is_action(_pad_button(3, JOY_BUTTON_Y), "p2_heavy"))
	assert_true(InputMap.event_is_action(_pad_button(3, JOY_BUTTON_RIGHT_SHOULDER), "p2_guard"))
	var stick := InputEventJoypadMotion.new()
	stick.device = 3
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	assert_true(InputMap.event_is_action(stick, "p2_right"))


func test_unassignment_removes_the_pad_and_keeps_the_keys() -> void:
	var pads := GamepadAssigner.new(["p1", "p2"] as Array[String])
	pads.connect_device(0)
	pads.connect_device(1)
	pads.disconnect_device(1)
	assert_false(InputMap.event_is_action(_pad_button(1, JOY_BUTTON_A), "p2_jump"), "pad 1 unbound")
	assert_eq(_keys("p2_jump"), [KEY_Q] as Array[int], "keyboard keys stay")
	assert_true(InputMap.event_is_action(_pad_button(0, JOY_BUTTON_A), "p1_jump"))


func test_input_device_label_follows_the_pad() -> void:
	var pads := GamepadAssigner.new(["p1", "p2"] as Array[String])
	assert_eq(pads.input_device("p2", "keyboard"), "keyboard")
	pads.connect_device(0)
	pads.connect_device(1)
	assert_eq(pads.input_device("p1", "touch"), "gamepad")
	assert_eq(pads.input_device("p2", "keyboard"), "gamepad")
