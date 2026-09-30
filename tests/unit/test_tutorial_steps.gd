extends GutTest
## Tutorial missions and their instruction lines (Phase 5 T11, DS-TOK-06): the planned order with
## a title and keys for every goal; P1's InputMap keys on the keyboard, pad face buttons by family,
## the on-screen controls on touch, and every line finished.


func test_missions_run_in_the_planned_order() -> void:
	assert_eq(TutorialSteps.ORDER, ["move", "jump", "light_attack", "heavy_attack", "guard", "grab_throw",
		"item", "special"] as Array[String])
	for step: String in TutorialSteps.ORDER:
		assert_false(TutorialSteps.title(step).is_empty(), "%s has a card title" % step)
		for goal: String in TutorialSteps.goals(step):
			assert_false(TutorialSteps.keys(goal).is_empty(), "%s rings keys" % goal)


func test_instruction_lines_follow_the_device() -> void:
	InputBindings.apply()
	var kb := TutorialText.line(TutorialSteps.G_JUMP, TutorialText.DEVICE_KEYBOARD)
	assert_string_contains(kb, KeyHintSource.cap("jump").text)
	assert_string_contains(kb, "키로")
	assert_string_contains(TutorialText.line(TutorialSteps.G_MOVE, TutorialText.DEVICE_KEYBOARD), "방향키로")
	var pad := TutorialText.line(TutorialSteps.G_SPECIAL, TutorialText.DEVICE_GAMEPAD)
	assert_string_contains(pad, "Y+RB 버튼을")
	var ps := TutorialText.line(TutorialSteps.G_JUMP, TutorialText.DEVICE_GAMEPAD, SelectPrompts.FAMILY_PS)
	assert_string_contains(ps, "× 버튼으로")
	var touch := TutorialText.line(TutorialSteps.G_GRAB, TutorialText.DEVICE_TOUCH)
	assert_string_contains(touch, "잡기 버튼")
	for goal: String in TutorialSteps.KEYS:
		for device: String in [TutorialText.DEVICE_KEYBOARD, TutorialText.DEVICE_GAMEPAD, TutorialText.DEVICE_TOUCH]:
			var line := TutorialText.line(goal, device)
			assert_false(line.is_empty() or line.contains("{"), "%s/%s is a finished line" % [goal, device])
