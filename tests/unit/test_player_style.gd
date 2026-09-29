extends GutTest


func test_colors_and_shapes_are_paired_per_player() -> void:
	assert_eq(PlayerStyle.color(0), DS.P1)
	assert_eq(PlayerStyle.color(1), DS.P2)
	assert_eq(PlayerStyle.shape(0), PlayerStyle.Shape.CIRCLE)
	assert_eq(PlayerStyle.shape(1), PlayerStyle.Shape.TRIANGLE)
	assert_eq(PlayerStyle.label(1), "P2")


func test_polygons_have_the_right_vertex_counts() -> void:
	assert_eq(PlayerStyle.polygon(PlayerStyle.Shape.TRIANGLE, 10.0).size(), 3)
	assert_eq(PlayerStyle.polygon(PlayerStyle.Shape.SQUARE, 10.0).size(), 4)
	assert_eq(PlayerStyle.polygon(PlayerStyle.Shape.DIAMOND, 10.0).size(), 4)
	assert_eq(PlayerStyle.polygon(PlayerStyle.Shape.CIRCLE, 10.0).size(), PlayerStyle.CIRCLE_SEGMENTS)


func test_polygon_points_sit_on_the_radius_around_center() -> void:
	for p: Vector2 in PlayerStyle.polygon(PlayerStyle.Shape.DIAMOND, 10.0, Vector2(5, 5)):
		assert_almost_eq(p.distance_to(Vector2(5, 5)), 10.0, 0.0001)
