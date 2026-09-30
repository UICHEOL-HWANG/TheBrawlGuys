extends GutTest
## Procedural item models (design.md DS-VIS-05, Phase 4 T8): one model per kind, crack stages on
## bats, a burning fuse on bombs, spinning thrown rocks and hand offsets for carried items.


func _model(kind: int) -> ItemModel:
	var m := ItemModels.create(kind)
	add_child_autofree(m)
	return m


func test_registry_makes_one_model_per_kind() -> void:
	assert_true(_model(Item.Kind.BAT) is BatModel)
	assert_true(_model(Item.Kind.BOMB) is BombModel)
	assert_true(_model(Item.Kind.ROCK) is RockModel)
	var crate := ItemModels.crate()
	assert_true(crate is CrateModel)
	crate.free()


func test_every_model_is_built_from_several_parts() -> void:
	for kind: int in [Item.Kind.BAT, Item.Kind.BOMB, Item.Kind.ROCK]:
		var m := _model(kind)
		assert_gt(m.part_count(), 0, "kind %d has geometry" % kind)
	var crate := ItemModels.crate()
	add_child_autofree(crate)
	assert_gte(crate.part_count(), CrateModel.PLANKS_PER_SIDE * 2, "planks and metal bands")


func test_models_fit_their_old_footprint() -> void:
	var crate := ItemModels.crate()
	add_child_autofree(crate)
	var box := crate.bounds()
	assert_almost_eq(box.size.y, CrateModel.SIZE, CrateModel.SIZE * 0.25)
	assert_almost_eq(box.position.y, 0.0, 0.05, "sits on the ground")
	for kind: int in [Item.Kind.BAT, Item.Kind.BOMB, Item.Kind.ROCK]:
		var b := _model(kind).bounds()
		assert_gt(b.size.length(), 0.3, "kind %d is big enough to read" % kind)
		assert_lt(b.size.length(), 1.6, "kind %d is not huge" % kind)


func test_bat_cracks_more_as_uses_run_out() -> void:
	assert_eq(BatModel.crack_stage(5, 5), 0, "a fresh bat has no cracks")
	var last := 0
	for uses: int in range(5, 0, -1):
		var stage := BatModel.crack_stage(uses, 5)
		assert_gte(stage, last)
		last = stage
	assert_eq(BatModel.crack_stage(1, 5), BatModel.MAX_CRACKS, "the last swing is fully cracked")
	var bat := _model(Item.Kind.BAT) as BatModel
	bat.max_uses = 5
	bat.show_state({"uses": 1, "state": Item.State.GROUND}, 0)
	assert_eq(bat.cracks_shown(), BatModel.MAX_CRACKS)
	bat.show_state({"uses": 5, "state": Item.State.GROUND}, 0)
	assert_eq(bat.cracks_shown(), 0)


func test_unlit_bomb_has_no_spark() -> void:
	var bomb := _model(Item.Kind.BOMB) as BombModel
	bomb.show_state({"fuse_ticks": Item.UNLIT, "state": Item.State.GROUND}, 0)
	assert_false(bomb.spark_visible())
	assert_almost_eq(BombModel.burn_left(Item.UNLIT, 120), 1.0, 0.001, "full fuse")


func test_bomb_spark_burns_down_the_fuse() -> void:
	var total := 120
	assert_gt(BombModel.burn_left(120, total), BombModel.burn_left(30, total))
	var bomb := _model(Item.Kind.BOMB) as BombModel
	bomb.fuse_total = total
	bomb.show_state({"fuse_ticks": 100, "state": Item.State.THROWN}, 0)
	var early := bomb.spark_height()
	bomb.show_state({"fuse_ticks": 10, "state": Item.State.THROWN}, 0)
	assert_lt(bomb.spark_height(), early, "the spark creeps toward the body")


func test_bomb_blinks_faster_before_it_explodes() -> void:
	var total := 120
	assert_gt(BombModel.blink_hz(10, total), BombModel.blink_hz(110, total))
	assert_gt(_toggles(10, total), _toggles(110, total), "more blinks per second near the end")
	assert_false(BombModel.spark_on(Item.UNLIT, total, 0))


func _toggles(fuse: int, total: int) -> int:
	var n := 0
	var last := BombModel.spark_on(fuse, total, 0)
	for t: int in range(1, 60):
		var now := BombModel.spark_on(fuse, total, t)
		if now != last:
			n += 1
		last = now
	return n


func test_rock_spins_only_when_thrown() -> void:
	var rock := _model(Item.Kind.ROCK) as RockModel
	rock.show_state({"state": Item.State.GROUND}, 30)
	assert_eq(rock.spin_angle(), 0.0)
	rock.show_state({"state": Item.State.THROWN}, 10)
	var a := rock.spin_angle()
	rock.show_state({"state": Item.State.THROWN}, 20)
	assert_ne(rock.spin_angle(), a, "tumbles in flight")


func test_rock_is_faceted() -> void:
	var arrays := RockModel.faceted_mesh().surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size() % 3, 0, "flat triangles, no shared vertices")
	assert_gte(verts.size() / 3, 20, "at least an icosahedron")


func test_every_kind_has_a_hand_offset() -> void:
	for kind: int in [Item.Kind.BAT, Item.Kind.BOMB, Item.Kind.ROCK]:
		assert_ne(ItemModels.hold_transform(kind), Transform3D.IDENTITY, "kind %d sits in the hand" % kind)
