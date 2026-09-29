extends GutTest
## Item visuals (design.md DS-VIS-05).


func _item(id: int, kind: int, state: int, pos: Vector3, fuse: int = Item.UNLIT) -> Dictionary:
	return {"id": id, "kind": kind, "state": state, "pos": pos, "uses": 5, "fuse_ticks": fuse}


func test_shadow_grows_as_the_box_falls() -> void:
	assert_almost_eq(ItemView.shadow_scale(12.0, 12.0), ItemView.SHADOW_MIN_SCALE, 0.0001)
	assert_almost_eq(ItemView.shadow_scale(0.0, 12.0), 1.0, 0.0001)
	assert_gt(ItemView.shadow_scale(3.0, 12.0), ItemView.shadow_scale(9.0, 12.0))


func test_fuse_blinks_only_when_lit() -> void:
	assert_false(ItemView.fuse_visible(Item.UNLIT, 0))
	var seen := {}
	for t: int in 60:
		seen[ItemView.fuse_visible(60, t)] = true
	assert_eq(seen.size(), 2, "a lit fuse blinks on and off")


func test_kind_colors_are_point_colors() -> void:
	assert_eq(ItemView.kind_color(Item.Kind.BOMB), DS.BERRY)
	for kind: int in [Item.Kind.BAT, Item.Kind.BOMB, Item.Kind.ROCK]:
		assert_ne(ItemView.kind_color(kind), DS.GRASS, "items must stand out from the grass")


func test_falling_box_shows_box_and_shadow_then_the_item() -> void:
	var v := ItemView.new()
	add_child_autofree(v)
	v.setup(Item.Kind.BAT, GameConfig.new())
	var falling := _item(0, Item.Kind.BAT, Item.State.FALLING, Vector3(1, 6, 1))
	v.apply(falling, falling, 1.0, 0)
	assert_true(v.box_visible())
	assert_true(v.shadow_visible())
	assert_false(v.shape_visible())
	var ground := _item(0, Item.Kind.BAT, Item.State.GROUND, Vector3(1, 0, 1))
	v.apply(falling, ground, 1.0, 1)
	assert_false(v.box_visible())
	assert_false(v.shadow_visible())
	assert_true(v.shape_visible())


func test_layer_tracks_items_by_id() -> void:
	var layer := ItemLayer.new()
	add_child_autofree(layer)
	layer.setup(GameConfig.new())
	var a := _item(3, Item.Kind.ROCK, Item.State.GROUND, Vector3.ZERO)
	var b := _item(4, Item.Kind.BOMB, Item.State.GROUND, Vector3(1, 0, 0))
	layer.sync([], [a, b], 1.0, 0)
	assert_eq(layer.view_count(), 2)
	layer.sync([a, b], [b], 1.0, 1)
	assert_eq(layer.view_count(), 1, "a picked-up item's view goes away")
	assert_not_null(layer.view(4))


func test_layer_interpolates_moving_items() -> void:
	var layer := ItemLayer.new()
	add_child_autofree(layer)
	layer.setup(GameConfig.new())
	var before := _item(1, Item.Kind.ROCK, Item.State.THROWN, Vector3(0, 1, 0))
	var after := _item(1, Item.Kind.ROCK, Item.State.THROWN, Vector3(2, 1, 0))
	layer.sync([before], [after], 0.5, 1)
	assert_eq(layer.view(1).position, Vector3(1, 1, 0))
