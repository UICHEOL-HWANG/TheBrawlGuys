extends GutTest


func before_each() -> void:
	InputBindings.apply()


func after_each() -> void:
	for action: String in InputBindings.P1:
		Input.action_release(action)


func test_all_p1_actions_exist_with_their_keys() -> void:
	for action: String in InputBindings.P1:
		assert_true(InputMap.has_action(action), action)
		var keys: Array[int] = []
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventKey:
				keys.append((ev as InputEventKey).physical_keycode)
		for key: int in InputBindings.P1[action]:
			assert_has(keys, key, "%s bound to %d" % [action, key])


func test_apply_is_idempotent() -> void:
	InputBindings.apply()
	InputBindings.apply()
	assert_eq(InputMap.action_get_events("p1_jump").size(), (InputBindings.P1["p1_jump"] as Array).size())


func test_local_input_reads_move_actions() -> void:
	var local := LocalInput.new()
	Input.action_press("p1_right")
	Input.action_press("p1_up")
	var f := local.sample()
	assert_gt(f.move_x, 0.0)
	assert_lt(f.move_z, 0.0, "screen up is away from the camera (-z)")
	assert_almost_eq(Vector2(f.move_x, f.move_z).length(), 1.0, 0.02, "diagonal is normalized")


func test_latched_press_reaches_exactly_one_tick() -> void:
	var local := LocalInput.new()
	local.press_jump()
	local.press_light()
	var first := local.sample()
	var second := local.sample()
	assert_true(first.jump and first.light)
	assert_false(second.jump or second.light)


func test_reset_clears_latched_presses() -> void:
	var local := LocalInput.new()
	local.press_jump()
	local.press_light()
	local.reset()
	var f := local.sample()
	assert_false(f.jump or f.light, "a press latched before a restart must not fire in the new match")


func test_poll_in_the_same_frame_as_reset_is_ignored() -> void:
	# The Space that confirms a restart is still "just pressed" when _process polls later that frame.
	var local := LocalInput.new()
	Input.action_press("p1_jump")
	local.reset()
	local.poll()
	assert_false(local.sample().jump, "the restart key must not latch a jump in the new match")


func test_poll_resumes_on_the_next_frame_after_reset() -> void:
	var local := LocalInput.new()
	local.reset()
	await get_tree().process_frame
	Input.action_press("p1_jump")
	local.poll()
	assert_true(local.sample().jump)
