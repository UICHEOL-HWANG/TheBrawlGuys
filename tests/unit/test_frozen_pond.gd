extends GutTest
## Frozen pond (얼음 연못, PRD §6.1): an ice disc over cold water. Solid ice (an outer ring plus a
## grid of slabs) leaves four holes that only the breakable ice patches cover; everything below
## the water line rings out as "water"; the floor is slippery.

const SAMPLE_STEP := 0.5


func _arena() -> ArenaData:
	return ArenaCatalog.build(FrozenPondArena.ID, GameConfig.new())


func _patches(a: ArenaData) -> Array[BreakablePlatform]:
	var out: Array[BreakablePlatform] = []
	for g: Gimmick in a.gimmicks:
		if g is BreakablePlatform:
			out.append(g as BreakablePlatform)
	return out


## Grid points on the ice disc, kept a little off the outer edge.
func _disc_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var r := FrozenPondArena.ICE_RADIUS - SAMPLE_STEP
	var x := -r
	while x <= r:
		var z := -r
		while z <= r:
			if Vector2(x, z).length() <= r:
				out.append(Vector3(x, 0, z))
			z += SAMPLE_STEP
		x += SAMPLE_STEP
	return out


func test_frozen_pond_is_a_selectable_slippery_stage() -> void:
	assert_true(ArenaCatalog.stage_ids().has("frozen_pond"))
	assert_eq(ArenaCatalog.stage_ids()[-1], "frozen_pond", "appended after the Phase 4 stages")
	var a := _arena()
	assert_eq(a.id, "frozen_pond")
	assert_eq(a.theme_id, "frozen_pond")
	assert_true(a.slippery, "ice")


func test_whole_disc_is_ice_while_every_patch_holds() -> void:
	var a := _arena()
	for p: Vector3 in _disc_points():
		assert_true(ArenaFloor.over_floor(a, p), "%s is on the ice" % p)


func test_broken_patches_open_holes_only_where_they_were() -> void:
	var a := _arena()
	var patches := _patches(a)
	assert_eq(patches.size(), FrozenPondArena.PATCH_CENTERS.size())
	for g: BreakablePlatform in patches:
		a.floor_active[g.floor_index] = false
	var holes := 0
	for p: Vector3 in _disc_points():
		var in_patch := false
		for g: BreakablePlatform in patches:
			in_patch = in_patch or g.area.contains_xz(p)
		if not in_patch:
			assert_true(ArenaFloor.over_floor(a, p), "%s stays solid" % p)
		elif not ArenaFloor.over_floor(a, p):
			holes += 1
	assert_gt(holes, 0)
	for g: BreakablePlatform in patches:
		assert_false(ArenaFloor.over_floor(a, g.area.center), "patch %d opens a hole" % g.id)
		assert_lt(g.area.bound_radius(), FrozenPondArena.ICE_RADIUS, "holes lie inside the ice")


func test_spawns_stand_on_solid_ice_clear_of_the_patches() -> void:
	var a := _arena()
	for g: BreakablePlatform in _patches(a):
		a.floor_active[g.floor_index] = false
	assert_eq(a.spawn_points.size(), 4)
	for s: Vector3 in a.spawn_points:
		assert_true(ArenaFloor.supports(a, s), "%s is solid ice" % s)
		for g: BreakablePlatform in _patches(a):
			assert_lt(g.area.edge_distance(s), -1.0, "%s keeps clear of patch %d" % [s, g.id])


func test_water_all_around_rings_out() -> void:
	var a := _arena()
	assert_eq(a.ringout_zones.size(), 1)
	var water := a.ringout_zones[0]
	assert_eq(water.tag, "water")
	assert_eq(water.center.y, FrozenPondArena.WATER_LINE)
	var below := Vector3(FrozenPondArena.ICE_RADIUS + 1.0, FrozenPondArena.WATER_LINE - 0.1, 0)
	assert_eq(ArenaFloor.out_zone(a, below), "water")


func test_patches_break_into_holes_in_a_match() -> void:
	var c := GameConfig.new()
	c.platform_break_start_time = 0.5
	c.platform_warn_time = 0.1
	var w := World.new(c, 1, 2, ArenaCatalog.build(FrozenPondArena.ID, c))
	var first: BreakablePlatform = null
	for g: BreakablePlatform in _patches(w.arena):
		if g.order == 0:
			first = g
	w.fighters[0].pos = first.area.center
	var outs := []
	for i: int in SimTime.to_ticks(2.0):
		var inputs: Array[InputFrame] = [InputFrame.neutral(), InputFrame.neutral()]
		w.tick(inputs)
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "ringout" and int(e["id"]) == 0:
				outs.append(e)
	assert_false(w.arena.floor_active[first.floor_index], "the patch broke")
	assert_eq(outs.size(), 1, "the fighter on it fell through")
	assert_eq(outs[0]["zone"], "water")


func test_bots_treat_slab_seams_as_safe_but_hole_edges_as_edges() -> void:
	var a := _arena()
	var ratio := GameConfig.new().bot_edge_ratio
	var junction := Vector3(FrozenPondArena.CORE_HALF, 0, FrozenPondArena.CORE_HALF)
	assert_eq(ArenaFloor.safe_point(a, junction, ratio), junction, "where four slabs meet is solid footing")
	var seam := Vector3(FrozenPondArena.ICE_INNER, 0, FrozenPondArena.ICE_INNER * 0.3)
	assert_eq(ArenaFloor.safe_point(a, seam, ratio), seam, "the slab grid meets the ring seamlessly")
	for g: BreakablePlatform in _patches(a):
		a.floor_active[g.floor_index] = false
	assert_ne(ArenaFloor.safe_point(a, junction, ratio), junction, "next to open holes it backs off")
