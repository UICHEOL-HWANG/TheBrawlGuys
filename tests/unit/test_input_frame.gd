extends GutTest


func test_neutral_frame_has_no_intent() -> void:
	var f := InputFrame.neutral()
	assert_eq(f.move_x, 0.0)
	assert_eq(f.move_z, 0.0)
	assert_false(f.jump or f.light or f.heavy or f.guard or f.grab)


func test_copy_is_independent() -> void:
	var a := InputFrame.neutral()
	a.move_x = 0.5
	a.jump = true
	var b := a.copy()
	b.move_x = -1.0
	b.jump = false
	assert_eq(a.move_x, 0.5)
	assert_true(a.jump)
	assert_eq(b.move_x, -1.0)


func test_quantize_axis_snaps_to_steps_and_clamps() -> void:
	assert_eq(InputFrame.quantize_axis(0.0), 0.0)
	assert_eq(InputFrame.quantize_axis(1.5), 1.0)
	assert_eq(InputFrame.quantize_axis(-2.0), -1.0)
	var q := InputFrame.quantize_axis(0.3333)
	assert_almost_eq(q * InputFrame.MOVE_STEPS, roundf(q * InputFrame.MOVE_STEPS), 0.00001)


## A tiny negative intent rounds to zero, never to -0.0: the input log (InputCodec) can only store
## +0, and -0.0 flips the sign of an aim or facing (atan2) so the replay would drift.
func test_quantize_axis_never_returns_negative_zero() -> void:
	# No -0.0 literal here: GDScript pools equal constants, so it would also turn 0.0 into -0.0.
	for v: float in [-0.001, -1.0 / (InputFrame.MOVE_STEPS * 3.0)]:
		var q := InputFrame.quantize_axis(v)
		assert_eq(var_to_bytes(q), var_to_bytes(0.0), "%s quantizes to +0.0" % v)
	var f := InputFrame.make(-0.001, -0.001)
	assert_eq(var_to_bytes(InputCodec.unpack(InputCodec.pack(f)).move_x), var_to_bytes(f.move_x),
			"the logged axis is bit-identical")


func test_make_quantizes_and_sets_buttons() -> void:
	var f := InputFrame.make(0.70710678, -0.70710678, true, true)
	assert_eq(f.move_x, InputFrame.quantize_axis(0.70710678))
	assert_eq(f.move_z, InputFrame.quantize_axis(-0.70710678))
	assert_true(f.jump)
	assert_true(f.light)
	assert_false(f.heavy or f.guard or f.grab)
