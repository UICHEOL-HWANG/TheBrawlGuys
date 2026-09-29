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
