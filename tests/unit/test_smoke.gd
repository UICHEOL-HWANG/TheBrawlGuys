extends GutTest


func test_static_typing_is_enforced() -> void:
	var level: int = ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration")
	assert_eq(level, 2, "untyped_declaration must be an error")


func test_renderer_is_mobile_with_web_compatibility() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "mobile")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.web"), "gl_compatibility")


func test_project_has_main_scene() -> void:
	assert_ne(ProjectSettings.get_setting("application/run/main_scene", ""), "", "main scene must be set")
