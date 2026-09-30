extends GutTest
## Decor geometry (Phase 4 review): splashes only over real water, an exact occlusion test that
## thin posts cannot slip through, and occluders registered from their base, not their center.


func _decor(id: String) -> DecorView:
	var c := GameConfig.new()
	var d := DecorView.new()
	add_child_autofree(d)
	d.setup(c, 5, ArenaCatalog.build(id, c))
	return d


func test_only_the_classic_meadow_has_the_decor_lake() -> void:
	assert_true(ArenaDressings.has_decor_lake(ArenaCatalog.DEFAULT_ID))
	assert_true(ArenaDressings.has_decor_lake("nope"), "unknown ids dress as the classic meadow")
	for id: String in ArenaCatalog.stage_ids():
		assert_false(ArenaDressings.has_decor_lake(id), "%s has no meadow lake" % id)


func test_dry_ring_outs_on_other_arenas_do_not_splash() -> void:
	var over_lake := {"zone": "blast", "pos": Vector3(24, -1, 0)}
	assert_true(DecorView.is_water_ringout(over_lake, 10.0, true), "classic: over the meadow lake")
	assert_false(DecorView.is_water_ringout(over_lake, 10.0, false), "no lake there on other arenas")
	assert_true(DecorView.is_water_ringout({"zone": "water", "pos": Vector3.ZERO}, 10.0, false))
	var c := GameConfig.new()
	var ringout := {"type": "ringout", "zone": "kill_y", "pos": Vector3(c.arena_radius + DecorView.LAKE_OFFSET, -9, 0)}
	assert_eq(String(SfxDirector.sound_for(ringout, c, false)["name"]), "ringout_whistle")
	assert_eq(String(SfxDirector.sound_for(ringout, c, true)["name"]), "ringout_splash")


func test_a_thin_post_on_a_sight_line_blocks() -> void:
	var eye := Vector3(0, 12, 20)
	var target := Vector3(0, 0, 0)
	var targets := PackedVector3Array([target])
	# Between two of the old 32 samples, thinner than their spacing.
	var at := eye.lerp(target, 0.5 + 0.5 / 32.0)
	var base := Vector3(at.x, at.y - 0.5, at.z)
	assert_true(DecorOcclusion.blocks(eye, targets, base, 0.01, 1.0), "a 1 cm post exactly on the line")
	var beside := base + Vector3(0.05, 0, 0)
	assert_false(DecorOcclusion.blocks(eye, targets, beside, 0.01, 1.0), "just beside the line")
	var below := Vector3(at.x, at.y - 3.0, at.z)
	assert_false(DecorOcclusion.blocks(eye, targets, below, 0.5, 1.0), "under the line")
	var flat := PackedVector3Array([Vector3(0, 2, -10)])
	var level := Vector3(0, 2, 10)
	assert_true(DecorOcclusion.blocks(level, flat, Vector3(0, 1, 0), 0.2, 2.0), "a level sight line through the slab")
	assert_false(DecorOcclusion.blocks(level, flat, Vector3(0, 3, 0), 0.2, 2.0), "a level line under the slab")


func test_the_rock_registers_its_base() -> void:
	var d := _decor(ArenaCatalog.DEFAULT_ID)
	var rock := {}
	for o: Dictionary in d.occluders():
		if is_equal_approx(float(o["radius"]), DecorView.ROCK_SCALE.x * 0.5):
			rock = o
	assert_false(rock.is_empty(), "the rock is shown")
	var center_y := DecorView.GROUND_Y + DecorView.ROCK_LIFT
	assert_almost_eq((rock["pos"] as Vector3).y, center_y - DecorView.ROCK_SCALE.y * 0.5, 0.001)


func test_bridge_posts_register_their_base() -> void:
	var d := _decor("log_bridge")
	var arena := ArenaCatalog.build("log_bridge", GameConfig.new())
	var water_y := arena.ringout_zones[0].center.y
	var posts := 0
	for o: Dictionary in d.occluders():
		if is_equal_approx(float(o["radius"]), LogBridgeView.POST_RADIUS):
			posts += 1
			assert_almost_eq((o["pos"] as Vector3).y, water_y, 0.001, "post base on the water")
	assert_eq(posts, 4)
