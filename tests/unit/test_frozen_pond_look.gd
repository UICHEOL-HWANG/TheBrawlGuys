extends GutTest
## Frozen pond look (DS-THM-02, DS-VIS-04): ice theme, ice floors and patches, the snowy bank
## dressing and the snowfall that follows quality and reduce motion.


func _decor() -> DecorView:
	var d := DecorView.new()
	add_child_autofree(d)
	d.setup(GameConfig.new(), 5, ArenaCatalog.build(FrozenPondArena.ID, GameConfig.new()))
	return d


func test_theme_is_snow_white_ice_over_cold_water() -> void:
	var t := ArenaTheme.for_id("frozen_pond")
	assert_true(t.ice_floor)
	assert_eq(t.floor_top, DS.ICE)
	assert_eq(t.rim, DS.ICE_DEEP)
	assert_eq(t.sun_color, DS.SUN_COOL, "cool winter sun")
	assert_false(ArenaTheme.for_id("log_bridge").ice_floor, "other arenas keep their floors")


func test_ice_floors_are_ice_slabs_and_a_ring() -> void:
	var t := ArenaTheme.for_id("frozen_pond")
	var ring := FloorMesh.build(ArenaShape.ring(Vector3.ZERO, 9.0, 5.5).to_view(), t)
	var slab := FloorMesh.build(ArenaShape.box(Vector3(1, 0, 2), Vector2(4, 4)).to_view(), t)
	assert_gt(ring.get_child_count(), 2, "top, walls and lip")
	assert_true((ring.get_child(0) as MeshInstance3D).mesh is ArrayMesh, "a flat annulus top")
	assert_eq(slab.position, Vector3(1, 0, 2))
	var top := (slab.get_child(0) as MeshInstance3D).mesh as BoxMesh
	assert_eq(top.size.x, 4.0, "a solid slab, not a board deck")
	ring.free()
	slab.free()


func test_patches_are_ice_views_drawing_their_own_floor() -> void:
	var v := ArenaView.new()
	add_child_autofree(v)
	v.setup(GameConfig.new(), FrozenPondArena.ID)
	assert_eq(v.gimmick_views().size(), FrozenPondArena.PATCH_CENTERS.size())
	for gv: GimmickView in v.gimmick_views():
		assert_true(gv is IcePatchView)
		assert_gt(gv.owned_floor(), 0, "draws its own floor")


func test_bank_dressing_stands_props_on_snow_not_water() -> void:
	var d := _decor()
	var dressing := d.dressing() as FrozenPondView
	assert_not_null(dressing)
	assert_true(is_nan(dressing.prop_ground(Vector3(11, 0, 0))), "open water by the ice")
	assert_eq(dressing.prop_ground(Vector3(20, 0, 0)), FrozenPondView.BANK_TOP, "the snowy bank")
	assert_false(dressing.inner_flowers(), "no flowers on ice")
	assert_false(dressing.outer_flowers(), "nor on snow")
	for c: Node in d.get_children():
		assert_false(c is FlowerPatch, "no flower patches in winter")
	assert_gt(dressing.occluders().size(), 0, "snowy pines on the bank")


func test_snowfall_follows_quality_and_reduce_motion() -> void:
	var c := GameConfig.new()
	c.quality_level = Quality.Level.HIGH
	var high := Snowfall.new()
	add_child_autofree(high)
	high.setup(c, false)
	assert_eq(high.flake_count(), Snowfall.FLAKES)
	c.quality_level = Quality.Level.LOW
	var low := Snowfall.new()
	add_child_autofree(low)
	low.setup(c, false)
	assert_eq(low.flake_count(), roundi(Snowfall.FLAKES * 0.5), "half the flakes on low quality")
	var calm := Snowfall.new()
	add_child_autofree(calm)
	calm.setup(c, true)
	assert_eq(calm.flake_count(), 0, "reduce motion: no snow")
	assert_false(calm.visible)
