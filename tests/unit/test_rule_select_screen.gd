extends GutTest
## Rule select (combat-depth D): three options 스톡 / 팀전 2:2 / 시간제, arrows / stick move,
## Z / Enter confirm, Esc goes back, a tap picks; tracked as rule_selected / select_cancelled.

var _tracked: Array = []
var _chosen: Array = []


func _screen() -> RuleSelectScreen:
	_tracked.clear()
	_chosen.clear()
	var s := RuleSelectScreen.new()
	s.track = func(n: String, p: Dictionary) -> void:
		assert_eq(EventCatalog.validate(n, p).size(), 0, n)
		_tracked.append([n, p])
	s.rule_chosen.connect(func(r: String) -> void: _chosen.append(r))
	add_child_autofree(s)
	return s


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func _stick(value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = value
	return e


func test_offers_the_three_rules_in_order() -> void:
	var s := _screen()
	assert_eq(s.rule_ids(), [MatchRules.STOCK, MatchRules.TEAM, MatchRules.TIMED] as Array[String])
	assert_eq(s.buttons().map(func(b: UiMenuButton) -> String: return b.text), ["스톡", "팀전 2:2", "시간제"])


func test_keyboard_moves_and_confirms() -> void:
	var s := _screen()
	await wait_process_frames(1)
	s._input(_key(KEY_RIGHT))
	s._input(_key(KEY_RIGHT))
	assert_eq(s.focus_index(), 2)
	s._input(_key(KEY_Z))
	assert_eq(_chosen, [MatchRules.TIMED])
	assert_eq(_tracked.back()[0], "rule_selected")
	assert_eq(int(_tracked.back()[1]["browse_count"]), 2)
	assert_eq(_tracked.back()[1]["focused"], [MatchRules.STOCK, MatchRules.TEAM, MatchRules.TIMED] as Array[String],
			"candidates in focus order, the default first")


func test_stick_steps_once_per_push_and_wraps() -> void:
	var s := _screen()
	await wait_process_frames(1)
	for v: float in [-0.6, -0.9, -1.0]:
		s._input(_stick(v))
	assert_eq(s.focus_index(), 2, "one push left wraps to the last option")


func test_tap_picks_and_escape_goes_back() -> void:
	var s := _screen()
	await wait_process_frames(1)
	s.buttons()[1].pressed.emit()
	assert_eq(_chosen, [MatchRules.TEAM])
	var other := _screen()
	await wait_process_frames(1)
	var left := [false]
	other.cancelled.connect(func() -> void: left[0] = true)
	other._input(_key(KEY_ESCAPE))
	assert_true(left[0])
	assert_eq(_tracked.back()[1]["screen"], "rule")


func test_timed_caption_reads_the_config() -> void:
	var c := GameConfig.new()
	c.timed_duration = 90.0
	assert_string_contains(String(RuleOptions.entries(c)[2]["caption"]), "1분 30초")
	assert_eq(RuleOptions.duration_text(120.0), "2분")
	assert_eq(RuleOptions.duration_text(45.0), "45초")


func test_confirm_on_the_back_button_goes_back() -> void:
	var s := _screen()
	await wait_process_frames(1)
	var left := [false]
	s.cancelled.connect(func() -> void: left[0] = true)
	s.back_button().focus_mode = Control.FOCUS_ALL
	s.back_button().grab_focus()
	s._input(_key(KEY_ENTER))
	assert_true(left[0])
	assert_true(_chosen.is_empty(), "no rule picked")
