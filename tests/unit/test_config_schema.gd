extends GutTest


func _find(specs: Array[Dictionary], name: String) -> Dictionary:
	for s: Dictionary in specs:
		if s["name"] == name:
			return s
	return {}


func test_arena_radius_slider_spec() -> void:
	var s := _find(ConfigSchema.sliders_for(GameConfig.new()), "arena_radius")
	assert_false(s.is_empty(), "arena_radius must be exposed")
	assert_eq(s["group"], "Arena")
	assert_eq(s["min"], 4.0)
	assert_eq(s["max"], 20.0)
	assert_eq(s["step"], 0.1)
	assert_false(s["is_int"])


func test_int_property_is_flagged() -> void:
	var s := _find(ConfigSchema.sliders_for(GameConfig.new()), "max_ticks_per_frame")
	assert_true(s["is_int"])
	assert_eq(s["group"], "Loop")


func test_every_config_number_is_exposed() -> void:
	var specs := ConfigSchema.sliders_for(GameConfig.new())
	for name: String in ["move_speed", "gravity", "kill_y", "hitstun_factor", "cam_pitch", "cam_fov", "touch_hold_threshold"]:
		assert_false(_find(specs, name).is_empty(), "%s missing" % name)
