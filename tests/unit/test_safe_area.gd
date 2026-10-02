extends GutTest
## Web safe area from the browser's env(safe-area-inset-*) (notched phones, viewport-fit=cover).


func test_insets_scale_from_css_px_to_the_viewport() -> void:
	var vp := Rect2(0, 0, 1704, 786)  # an 852x393 pt landscape iPhone at 2x
	var r := SafeArea.from_css_insets(vp, "0,59,21,59,852,393")
	assert_eq(r.position, Vector2(118, 0))
	assert_eq(r.size, Vector2(1704 - 236, 786 - 42))


func test_unreadable_or_degenerate_readings_keep_the_viewport() -> void:
	var vp := Rect2(0, 0, 800, 600)
	assert_eq(SafeArea.from_css_insets(vp, ""), vp, "no probe in the page")
	assert_eq(SafeArea.from_css_insets(vp, "0,0,0,0,0,0"), vp)
	assert_eq(SafeArea.from_css_insets(vp, "0,500,0,500,800,600"), vp, "insets wider than the screen")
