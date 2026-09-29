extends GutTest


func test_show_and_hide() -> void:
	var hint := GrabHint.new()
	add_child_autofree(hint)
	hint.setup(GameConfig.new())
	assert_false(hint.is_shown())
	hint.show_at(Vector3(2, 0, 3))
	assert_true(hint.is_shown())
	assert_eq(Vector2(hint.position.x, hint.position.z), Vector2(2, 3))
	hint.hide_hint()
	assert_false(hint.is_shown())
