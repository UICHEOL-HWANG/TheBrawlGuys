extends GutTest
## Arena select input edge cases (Phase 4 review): the left stick steps once per push, the screen
## works again when it is shown after a pick, hovering after a pick changes nothing, a card only
## picks on a press and release on itself, and the layout keeps the cards centered with 뒤로 and
## the key hint apart at the bottom.

const CARD := preload("res://src/ui/components/select_card/select_card.tscn")

var _tracked: Array = []


func _screen() -> ArenaSelectScreen:
	_tracked.clear()
	var s := ArenaSelectScreen.new()
	s.track = func(n: String, p: Dictionary) -> void: _tracked.append([n, p])
	add_child_autofree(s)
	return s


func _stick(value: float, axis: JoyAxis = JOY_AXIS_LEFT_X) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _mouse(pressed: bool, at: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	return e


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func test_holding_the_stick_steps_once_per_push() -> void:
	var s := _screen()
	await wait_process_frames(1)
	for v: float in [0.6, 0.8, 1.0, 0.9, 0.7]:
		s._input(_stick(v))
	assert_eq(s.focus_index(), 1, "one step for one push")
	s._input(_stick(0.4))
	assert_eq(s.focus_index(), 1, "between release and press: still latched")
	s._input(_stick(0.1))
	s._input(_stick(0.9))
	assert_eq(s.focus_index(), 2, "re-armed under the deadzone")
	for v: float in [-0.7, -1.0, -0.8]:
		s._input(_stick(v))
	assert_eq(s.focus_index(), 1, "a push the other way steps back once")
	s._input(_stick(1.0, JOY_AXIS_LEFT_Y))
	assert_eq(s.focus_index(), 1, "the vertical axis does not browse")
	s.confirm()
	assert_eq(_tracked[0][1]["browse_count"], 3)


func test_a_held_stick_does_not_leak_into_gui_focus_navigation() -> void:
	var s := _screen()
	await wait_process_frames(2)
	for v: float in [0.6, 0.8, 1.0, 0.9, 0.7, 0.8]:
		s.get_viewport().push_input(_stick(v))
	assert_eq(s.focus_index(), 1, "one step through the whole input pipeline")
	assert_true(s.cards()[1].has_focus(), "the GUI focus did not run on")


func test_a_stick_held_through_a_pick_is_re_armed_on_return() -> void:
	var s := _screen()
	await wait_process_frames(1)
	s._input(_stick(1.0))
	s.confirm()
	s.visible = false
	s.visible = true
	s._input(_stick(1.0))
	assert_eq(s.focus_index(), 2, "the first push after coming back steps")


func test_stick_nav_latch() -> void:
	var nav := StickNav.new()
	assert_eq(nav.step(_stick(0.8)), 1)
	assert_eq(nav.step(_stick(0.9)), 0)
	assert_eq(nav.step(_stick(-0.9)), -1, "flicking straight across fires the other way")
	assert_eq(nav.step(_stick(0.0)), 0)
	assert_eq(nav.step(_stick(-0.6)), -1)


func test_the_screen_works_again_when_shown_after_a_pick() -> void:
	var s := _screen()
	await wait_process_frames(1)
	s.move(1)
	s.confirm()
	assert_eq(s.cards()[1].state(), SelectCard.State.SELECTED)
	s.visible = false
	s.visible = true
	await wait_process_frames(1)
	assert_ne(s.cards()[1].state(), SelectCard.State.SELECTED, "the old pick is cleared")
	watch_signals(s)
	s._input(_key(KEY_RIGHT))
	assert_eq(s.focus_index(), 2, "input works again")
	s._input(_key(KEY_Z))
	assert_signal_emitted_with_parameters(s, "arena_chosen", [s.card_ids()[2]])
	assert_eq(_tracked.back()[1]["browse_count"], 1, "browsing counts per visit")


func test_hovering_after_a_pick_changes_nothing() -> void:
	var s := _screen()
	await wait_process_frames(1)
	s.confirm()
	s.cards()[3].mouse_entered.emit()
	s.cards()[3].focus_entered.emit()
	assert_eq(s.focus_index(), 0, "focus stays on the pick")
	assert_eq(s.cards()[3].mouse_filter, Control.MOUSE_FILTER_IGNORE, "cards stop taking the mouse")


func test_a_card_needs_press_and_release_on_itself() -> void:
	var c := CARD.instantiate() as SelectCard
	add_child_autofree(c)
	await wait_process_frames(1)
	watch_signals(c)
	var inside := c.size * 0.5
	c._gui_input(_mouse(false, inside))
	assert_signal_not_emitted(c, "pressed", "a release without a press")
	c._gui_input(_mouse(true, inside))
	c._gui_input(_mouse(false, c.size + Vector2(40, 40)))
	assert_signal_not_emitted(c, "pressed", "dragged off before releasing")
	c._gui_input(_mouse(true, inside))
	c._gui_input(_mouse(false, inside))
	assert_signal_emit_count(c, "pressed", 1)


func test_cards_sit_in_the_middle_and_the_footer_is_split() -> void:
	var s := _screen()
	await wait_process_frames(2)
	var vp := s.get_viewport().get_visible_rect()
	var top := INF
	var bottom := -INF
	for c: SelectCard in s.cards():
		top = minf(top, c.get_global_rect().position.y)
		bottom = maxf(bottom, c.get_global_rect().end.y)
	assert_almost_eq((top + bottom) * 0.5, vp.get_center().y, float(DS.S5), "cards centered vertically")
	var back := s.back_button().get_global_rect()
	var hint := s.hint_label().get_global_rect()
	assert_lt(back.position.x, vp.size.x * 0.25, "뒤로 at the bottom left")
	assert_gt(hint.end.x, vp.size.x * 0.75, "the hint at the bottom right")
	assert_gte(hint.position.x - back.end.x, float(DS.S6), "a clear gap between them")
