extends GutTest


func test_ramp_stops() -> void:
	assert_eq(DamageColor.for_percent(0.0), DS.UI_SURFACE)
	assert_eq(DamageColor.for_percent(50.0), DS.PETAL_YELLOW)
	assert_eq(DamageColor.for_percent(100.0), DS.FIRE)
	assert_eq(DamageColor.for_percent(150.0), DS.DANGER)
	assert_eq(DamageColor.for_percent(300.0), DS.DANGER)
	assert_eq(DamageColor.for_percent(-5.0), DS.UI_SURFACE)


func test_ramp_interpolates_between_stops() -> void:
	var mid := DamageColor.for_percent(25.0)
	var expected := DS.UI_SURFACE.lerp(DS.PETAL_YELLOW, 0.5)
	assert_almost_eq(mid.r, expected.r, 0.0001)
	assert_almost_eq(mid.g, expected.g, 0.0001)
	assert_almost_eq(mid.b, expected.b, 0.0001)
