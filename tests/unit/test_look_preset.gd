extends GutTest
## Soft toon v2 look presets (context F6) and the character material.


func after_each() -> void:
	LookPreset.apply(LookPreset.Look.A)


func test_three_presets_for_the_gate() -> void:
	var a := LookPreset.values_for(LookPreset.Look.A)
	var b := LookPreset.values_for(LookPreset.Look.B)
	var c := LookPreset.values_for(LookPreset.Look.C)
	assert_eq(a["rim"], 0.35, "A is the design.md DS-VIS-01 draft")
	assert_eq(a["outline"], 0.0)
	assert_gt(b["rim"], a["rim"])
	assert_gt(b["saturation"], 1.0)
	assert_gt(c["outline"], 0.0, "C is the character-only outline option")


func test_uniforms_for_maps_presets_to_shader_uniforms() -> void:
	var c := LookPreset.uniforms_for(LookPreset.Look.C)
	assert_eq(c.keys().size(), 4)
	assert_almost_eq(float(c["ds_rim_strength"]), 0.25, 0.0001)
	assert_almost_eq(float(c["ds_char_saturation"]), 1.0, 0.0001)
	assert_almost_eq(float(c["ds_outline_width"]), 0.012, 0.0001)
	assert_eq(c["ds_outline_color"], DS.CANOPY_DEEP)
	var b := LookPreset.uniforms_for(LookPreset.Look.B)
	assert_almost_eq(float(b["ds_rim_strength"]), 0.5, 0.0001)
	assert_almost_eq(float(b["ds_char_saturation"]), 1.15, 0.0001)
	assert_almost_eq(float(b["ds_outline_width"]), 0.0, 0.0001)
	assert_eq(LookPreset.uniforms_for(9), LookPreset.uniforms_for(LookPreset.Look.A), "unknown falls back to A")


func test_apply_records_the_applied_look() -> void:
	LookPreset.apply(LookPreset.Look.C)
	assert_eq(LookPreset.last_applied, LookPreset.Look.C)
	LookPreset.apply(LookPreset.Look.B)
	assert_eq(LookPreset.last_applied, LookPreset.Look.B)


func test_unknown_look_falls_back_to_a() -> void:
	assert_eq(LookPreset.values_for(9), LookPreset.values_for(LookPreset.Look.A))


func test_character_material_is_cached_with_outline_pass() -> void:
	var tex := PlaceholderTexture2D.new()
	var m1 := ToonMaterials.character(tex)
	var m2 := ToonMaterials.character(tex)
	assert_same(m1, m2, "one material per texture")
	assert_true(bool(m1.get_shader_parameter("is_character")))
	assert_true(bool(m1.get_shader_parameter("use_texture")))
	assert_not_null(m1.next_pass, "outline pass attached (width 0 hides it)")
	var plain := ToonMaterials.character(null)
	assert_false(bool(plain.get_shader_parameter("use_texture")))


func test_look_group_is_presentation_only() -> void:
	var a := GameConfig.new()
	var b := GameConfig.new()
	b.look_preset = 2
	assert_eq(a.fingerprint(), b.fingerprint())
