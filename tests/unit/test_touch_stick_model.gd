extends GutTest


func test_inactive_stick_reads_zero() -> void:
	assert_eq(TouchStickModel.new(100.0, 0.15).vector(), Vector2.ZERO)


func test_vector_is_normalized_by_radius_and_clamped() -> void:
	var m := TouchStickModel.new(100.0, 0.15)
	m.begin(Vector2(200, 500))
	m.move(Vector2(250, 500))
	assert_almost_eq(m.vector().x, 0.5, 0.0001)
	m.move(Vector2(500, 500))
	assert_almost_eq(m.vector().length(), 1.0, 0.0001, "clamped to unit length")
	assert_eq(m.knob(), Vector2(300, 500), "knob stops at the rim")


func test_dead_zone_reads_zero() -> void:
	var m := TouchStickModel.new(100.0, 0.15)
	m.begin(Vector2(0, 0))
	m.move(Vector2(10, 0))
	assert_eq(m.vector(), Vector2.ZERO)


func test_screen_down_is_positive() -> void:
	var m := TouchStickModel.new(100.0, 0.0)
	m.begin(Vector2(0, 0))
	m.move(Vector2(0, 80))
	assert_gt(m.vector().y, 0.0, "screen down = toward the camera = +z")


func test_end_releases() -> void:
	var m := TouchStickModel.new(100.0, 0.0)
	m.begin(Vector2(0, 0))
	m.move(Vector2(50, 0))
	m.end()
	assert_false(m.active())
	assert_eq(m.vector(), Vector2.ZERO)
