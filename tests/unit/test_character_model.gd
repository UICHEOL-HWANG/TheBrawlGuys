extends GutTest
## KayKit character wrapper (context F3): toon materials, hidden accessories, fitted to the
## fighter capsule height with the feet on the floor.


func _model(index: int) -> CharacterModel:
	var m := CharacterModel.new()
	add_child_autofree(m)
	assert_true(m.setup(CharacterCatalog.for_player(index), GameConfig.new()))
	return m


func test_fits_the_capsule_height_with_feet_on_the_floor() -> void:
	var c := GameConfig.new()
	for i: int in 4:
		var m := _model(i)
		assert_almost_eq(m.visible_height(), c.fighter_height, 0.05, "slot %d height" % i)
		assert_almost_eq(m.foot_y(), 0.0, 0.03, "slot %d feet" % i)


func test_uses_soft_toon_and_hides_accessories() -> void:
	var entry := CharacterCatalog.for_player(0)
	var m := _model(0)
	for node: Node in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if (entry["hide"] as Array).has(String(mesh.name)):
			assert_false(mesh.visible, "%s hidden" % mesh.name)
		else:
			var mat := mesh.get_surface_override_material(0) as ShaderMaterial
			assert_not_null(mat, "%s uses a toon override" % mesh.name)
			assert_true(bool(mat.get_shader_parameter("is_character")))


func test_exposes_its_animation_player() -> void:
	assert_not_null(_model(1).animation_player())


func test_bad_entry_reports_failure() -> void:
	var m := CharacterModel.new()
	add_child_autofree(m)
	assert_false(m.setup({"name": "Nope", "path": "res://missing.glb", "hide": []}, GameConfig.new()))
	assert_push_error("CharacterModel")
