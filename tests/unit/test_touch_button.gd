extends GutTest
## TouchButton v2 states (design.md DS-CMP-04).

const SCENE := preload("res://src/ui/components/touch_button/touch_button.tscn")


func _button() -> TouchButton:
	var b := SCENE.instantiate() as TouchButton
	add_child_autofree(b)
	return b


func test_phase1_state_values_are_kept() -> void:
	assert_eq(TouchButton.State.IDLE, 0)
	assert_eq(TouchButton.State.PRESSED, 1)


func test_pressed_and_charging_squish_others_do_not() -> void:
	var b := _button()
	for s: int in [TouchButton.State.PRESSED, TouchButton.State.CHARGING]:
		b.set_state(s)
		assert_eq(b.scale, DS.PRESS_SQUISH, "state %d" % s)
	for s: int in [TouchButton.State.IDLE, TouchButton.State.DISABLED]:
		b.set_state(s)
		assert_eq(b.scale, Vector2.ONE, "state %d" % s)


func test_charge_is_clamped() -> void:
	var b := _button()
	b.set_charge(1.7)
	assert_eq(b.charge(), 1.0)
	b.set_charge(-1.0)
	assert_eq(b.charge(), 0.0)


func test_every_icon_draws() -> void:
	for icon: int in [TouchIcons.Icon.ATTACK, TouchIcons.Icon.JUMP, TouchIcons.Icon.GUARD, TouchIcons.Icon.GRAB]:
		var b := _button()
		b.icon = icon
		b.set_state(TouchButton.State.HIGHLIGHT)
		await get_tree().process_frame
		assert_eq(b.state(), TouchButton.State.HIGHLIGHT)


func test_repeated_same_state_keeps_the_pulse_running() -> void:
	var b := _button()
	b.set_state(TouchButton.State.HIGHLIGHT)
	b._process(0.1)
	var scale_before := b.scale
	b.set_state(TouchButton.State.HIGHLIGHT)
	assert_eq(b.scale, scale_before, "same state must not reset the pulse")
	assert_ne(b.scale, Vector2.ONE)



func test_icon_stays_above_the_caption_band() -> void:
	for d: float in [96.0, 116.0, 130.0, 170.0]:
		var layout := TouchButton.icon_layout(d)
		var center: Vector2 = layout["icon_center"]
		var half: float = layout["icon_half"]
		var caption_top: float = layout["caption_top"]
		assert_gt(half, 0.0, "d=%s icon has size" % d)
		assert_lte(center.y + half, caption_top, "d=%s icon clears the caption" % d)
		assert_gte(center.y - half, 0.0, "d=%s icon stays inside the button" % d)
