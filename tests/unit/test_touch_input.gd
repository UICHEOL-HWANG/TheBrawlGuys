extends GutTest

var _local: LocalInput
var _touch: TouchInput


func before_each() -> void:
	InputBindings.apply()
	_local = LocalInput.new()
	_touch = TouchInput.new()
	add_child_autofree(_touch)
	_touch.setup(_local, GameConfig.new())


func _touch_event(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


func _drag_event(index: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	return e


func test_tap_attack_fires_light_on_release() -> void:
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), true))
	assert_false(_local.sample().light, "nothing on press")
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), false))
	assert_true(_local.sample().light, "light on release")


func test_jump_fires_on_press() -> void:
	_touch._unhandled_input(_touch_event(1, _touch.jump_center(), true))
	assert_true(_local.sample().jump)


func test_stick_drag_moves_and_release_stops() -> void:
	var start := _touch.stick_zone_point()
	_touch._unhandled_input(_touch_event(0, start, true))
	_touch._unhandled_input(_drag_event(0, start + Vector2(140, 0)))
	assert_gt(_local.sample().move_x, 0.9)
	_touch._unhandled_input(_touch_event(0, start + Vector2(140, 0), false))
	assert_eq(_local.sample().move_x, 0.0)


func test_stick_and_attack_work_at_the_same_time() -> void:
	var start := _touch.stick_zone_point()
	_touch._unhandled_input(_touch_event(0, start, true))
	_touch._unhandled_input(_drag_event(0, start + Vector2(0, -140)))
	_touch._unhandled_input(_touch_event(1, _touch.attack_center(), true))
	_touch._unhandled_input(_touch_event(1, _touch.attack_center(), false))
	var f := _local.sample()
	assert_lt(f.move_z, -0.9)
	assert_true(f.light)


func test_fourth_finger_is_ignored() -> void:
	_touch._unhandled_input(_touch_event(3, _touch.jump_center(), true))
	assert_false(_local.sample().jump, "index 3 belongs to the debug panel gesture")


func test_hold_attack_becomes_heavy_and_release_ends_it() -> void:
	_touch.time_override = 10.0
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), true))
	_touch.time_override = 10.5
	_touch._process(0.0)
	assert_true(_local.sample().heavy, "held past the threshold -> heavy")
	assert_true(_local.sample().heavy, "stays held")
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), false))
	var f := _local.sample()
	assert_false(f.heavy, "release ends the charge; the sim swings")
	assert_false(f.light, "a hold is not also a light")


func test_short_hold_released_between_frames_still_swings_heavy() -> void:
	_touch.time_override = 10.0
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), true))
	_touch.time_override = 10.3
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), false))
	assert_true(_local.sample().heavy, "past the threshold but no frame ran: one tick of heavy")
	assert_false(_local.sample().heavy)


func test_guard_held_while_touched() -> void:
	_touch._unhandled_input(_touch_event(1, _touch.button_center("guard"), true))
	assert_true(_local.sample().guard)
	_touch._unhandled_input(_touch_event(1, _touch.button_center("guard"), false))
	assert_false(_local.sample().guard)


func test_grab_fires_on_press() -> void:
	_touch._unhandled_input(_touch_event(2, _touch.button_center("grab"), true))
	assert_true(_local.sample().grab)


func test_canceled_attack_touch_does_not_attack() -> void:
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), true))
	var cancel := _touch_event(0, _touch.attack_center(), false)
	cancel.canceled = true
	_touch._unhandled_input(cancel)
	assert_false(_local.sample().light)


func test_focus_loss_releases_every_finger() -> void:
	var start := _touch.stick_zone_point()
	_touch._unhandled_input(_touch_event(0, start, true))
	_touch._unhandled_input(_drag_event(0, start + Vector2(140, 0)))
	_touch._unhandled_input(_touch_event(1, _touch.button_center("guard"), true))
	_touch._unhandled_input(_touch_event(2, _touch.attack_center(), true))
	_touch._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var f := _local.sample()
	assert_eq(f.move_x, 0.0, "stick let go")
	assert_false(f.guard, "guard let go")
	assert_false(f.light, "a canceled attack touch is not a tap")


func test_layout_follows_the_config() -> void:
	var c := GameConfig.new()
	var touch := TouchInput.new()
	add_child_autofree(touch)
	touch.setup(LocalInput.new(), c)
	var arc := touch.button_center("guard")
	c.touch_layout = TouchLayout.Variant.GRID
	c.emit_changed()
	assert_ne(touch.button_center("guard"), arc, "debug panel can switch layouts live for the gate")


func test_buttons_carry_their_icons() -> void:
	var b: Dictionary = _touch.buttons()
	assert_eq((b["attack"] as TouchButton).icon, TouchIcons.Icon.ATTACK)
	assert_eq((b["grab"] as TouchButton).icon, TouchIcons.Icon.GRAB)
	assert_true((b["grab"] as TouchButton).dim_when_idle, "grab rests at 60% until it has a target")


func test_grab_highlight_and_disable() -> void:
	var grab := _touch.buttons()["grab"] as TouchButton
	_touch.set_grab_highlight(true)
	assert_eq(grab.state(), TouchButton.State.HIGHLIGHT)
	_touch.set_grab_highlight(false)
	assert_eq(grab.state(), TouchButton.State.IDLE)
	_touch.set_enabled(false)
	for b: TouchButton in _touch.buttons().values():
		assert_eq(b.state(), TouchButton.State.DISABLED)
	_touch._unhandled_input(_touch_event(1, _touch.jump_center(), true))
	assert_false(_local.sample().jump, "disabled buttons ignore touches")


func test_attack_shows_charging_while_held() -> void:
	_touch.time_override = 20.0
	_touch._unhandled_input(_touch_event(0, _touch.attack_center(), true))
	_touch.time_override = 20.65
	_touch._process(0.0)
	var attack := _touch.buttons()["attack"] as TouchButton
	assert_eq(attack.state(), TouchButton.State.CHARGING)
	assert_almost_eq(attack.charge(), 0.5, 0.01, "(0.65 - 0.15) s of a 1 s max charge")
