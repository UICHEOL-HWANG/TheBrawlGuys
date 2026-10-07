extends GutTest
## The tutorial's "press this now" ring on a TouchButton: it sits on the button's rim (centred,
## never reaching past the edge, so the layout's gaps stay as they are), breathes on motion_slow
## and settles back to full, fades out when the step moves on, and holds still with reduce motion.

const SCENE := preload("res://src/ui/components/touch_button/touch_button.tscn")


func _button(d: float = 116.0) -> TouchButton:
	var b := SCENE.instantiate() as TouchButton
	add_child_autofree(b)
	b.set_diameter(d)
	b.position = Vector2(DS.S8, DS.S8)
	return b


func test_a_target_ring_breathes_then_fades_when_cleared() -> void:
	var b := _button()
	b.set_target(true)
	var ring := b.target_ring()
	assert_true(b.is_target())
	assert_true(ring.is_pulsing(), "an eased loop on motion_slow")
	assert_eq(ring.glow, 1.0, "starts at rest: the full ring")
	await wait_seconds(DS.MOTION_SLOW * 1.5)
	assert_lt(ring.glow, 1.0, "breathing out")
	assert_gt(ring.glow, TouchTargetRing.ALPHA_LOW - 0.01)
	b.set_target(false)
	assert_false(b.is_target())
	await wait_seconds(DS.MOTION_BASE + 0.1)
	assert_eq(ring.glow, 0.0, "faded away")
	assert_false(ring.is_pulsing())


func test_reduce_motion_holds_a_still_ring() -> void:
	var b := _button()
	b.set_target(true, true)
	var ring := b.target_ring()
	assert_false(ring.is_pulsing())
	await wait_seconds(DS.MOTION_SLOW * 1.5)
	assert_eq(ring.glow, 1.0, "full and still")
	b.set_target(true, false)
	assert_true(ring.is_pulsing(), "turning reduce motion off brings the breath back")


func test_repeated_calls_keep_the_breath_running() -> void:
	var b := _button()
	b.set_target(true)
	await wait_seconds(DS.MOTION_SLOW * 1.5)
	var glow := b.target_ring().glow
	b.set_target(true)
	assert_eq(b.target_ring().glow, glow, "the tutorial sets targets every frame")


func test_the_ring_is_centred_on_the_rim() -> void:
	for d: float in [116.0, 130.0, 170.0]:
		var b := _button(d)
		b.set_target(true)
		var ring := b.target_ring()
		assert_eq(ring.get_global_rect().get_center(), b.get_global_rect().get_center(), "centred at %d" % d)
		assert_eq(ring.radius() + TouchButton.RING_WIDTH * 0.5, d * 0.5, "outer edge = button edge at %d" % d)


func test_touch_input_rings_exactly_the_given_buttons() -> void:
	var touch := TouchInput.new()
	add_child_autofree(touch)
	touch.setup(LocalInput.new(), GameConfig.new())
	touch.set_targets(["attack", "guard"])
	var lit: Array = []
	for name: String in TouchLayout.BUTTONS:
		if (touch.buttons()[name] as TouchButton).is_target():
			lit.append(name)
	assert_eq(lit, ["attack", "guard"])
	touch.set_targets([])
	for b: TouchButton in touch.buttons().values():
		assert_false(b.is_target())
