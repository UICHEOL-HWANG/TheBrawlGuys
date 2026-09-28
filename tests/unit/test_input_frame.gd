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
