extends GutTest


func test_ui_text_meets_wcag_aa_on_surfaces() -> void:
	for bg: Color in [DS.UI_SURFACE, DS.UI_SURFACE_DIM]:
		assert_gt(ColorUtils.contrast_ratio(DS.UI_TEXT, bg), 4.5)
		assert_gt(ColorUtils.contrast_ratio(DS.UI_TEXT_SOFT, bg), 4.5)


func test_palette_has_no_pure_black() -> void:
	for key: String in DS.PALETTE:
		var c: Color = DS.PALETTE[key]
		assert_false(c.r == 0.0 and c.g == 0.0 and c.b == 0.0 and c.a == 1.0, "%s is pure black" % key)


func test_palette_a_anchor_values() -> void:
	assert_eq(DS.GRASS.to_html(false), "a5d65a")
	assert_eq(DS.CANOPY.to_html(false), "2e8c86")
	assert_eq(DS.WATER.to_html(false), "3a9fe3")
	assert_eq(DS.P1.to_html(false), "3e7bf0")


func test_damage_ramp_has_four_stops() -> void:
	assert_eq(DS.DAMAGE_RAMP.size(), 4)


func test_font_files_exist() -> void:
	for path: String in [DS.FONT_DISPLAY_PATH, DS.FONT_BODY_PATH, DS.FONT_CAPTION_PATH]:
		assert_true(ResourceLoader.exists(path), path)
