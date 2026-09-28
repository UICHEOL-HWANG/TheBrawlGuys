extends GutTest


func test_black_on_white_is_21() -> void:
	assert_almost_eq(ColorUtils.contrast_ratio(Color(0, 0, 0), Color(1, 1, 1)), 21.0, 0.01)


func test_same_color_is_1() -> void:
	assert_almost_eq(ColorUtils.contrast_ratio(Color(0.3, 0.6, 0.2), Color(0.3, 0.6, 0.2)), 1.0, 0.0001)


func test_order_does_not_matter() -> void:
	var a := Color(0.2, 0.3, 0.4)
	var b := Color(0.9, 0.9, 0.8)
	assert_almost_eq(ColorUtils.contrast_ratio(a, b), ColorUtils.contrast_ratio(b, a), 0.0001)
