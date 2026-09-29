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
