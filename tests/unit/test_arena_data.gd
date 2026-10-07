extends GutTest
## ArenaShape / ArenaData / ArenaFloor / ArenaCatalog (Phase 4 T1, PRD-ARCH-03).


func _neutral(count: int = 2) -> Array[InputFrame]:
	var a: Array[InputFrame] = []
	for i: int in count:
		a.append(InputFrame.neutral())
	return a


func test_circle_contains_and_edge_distance() -> void:
	var s := ArenaShape.circle(Vector3(1, 0, 0), 2.0)
	assert_true(s.contains_xz(Vector3(2.9, 5, 0)))
	assert_false(s.contains_xz(Vector3(3.1, 0, 0)))
	assert_almost_eq(s.edge_distance(Vector3(2.5, 0, 0)), 0.5, 0.0001)
	assert_almost_eq(s.edge_distance(Vector3(4.0, 0, 0)), -1.0, 0.0001)
	assert_almost_eq(s.extent(), 2.0, 0.0001)


func test_rotated_box_contains() -> void:
	# 4 x 1 box turned 90 degrees: long side along world z
	var s := ArenaShape.box(Vector3.ZERO, Vector2(4.0, 1.0), PI / 2.0)
	assert_true(s.contains_xz(Vector3(0, 0, 1.9)))
	assert_false(s.contains_xz(Vector3(1.9, 0, 0)))
	assert_almost_eq(s.edge_distance(Vector3(0, 0, 1.5)), 0.5, 0.0001)
	assert_almost_eq(s.extent(), 0.5, 0.0001)


func test_core_point_pulls_inside_by_the_margin() -> void:
	var c := ArenaShape.circle(Vector3.ZERO, 10.0)
	var p := c.core_point(Vector3(9.5, 0, 0), 2.0)
	assert_almost_eq(p.x, 8.0, 0.0001)
	var inside := c.core_point(Vector3(3, 0, 1), 2.0)
	assert_eq(inside, Vector3(3, 0, 1), "already safe: unchanged")
	var b := ArenaShape.box(Vector3(0, 0, 2), Vector2(6.0, 1.0))
	var q := b.core_point(Vector3(5, 0, 2.6), 0.2)
	assert_almost_eq(q.x, 2.8, 0.0001)
	assert_almost_eq(q.z, 2.3, 0.0001)


func test_outward_points_to_the_nearest_edge() -> void:
	var b := ArenaShape.box(Vector3.ZERO, Vector2(10.0, 2.0))
	var out := b.outward(Vector3(1, 0, 0.5))
	assert_almost_eq(out.y, 1.0, 0.0001, "narrow side is closer")
	var c := ArenaShape.circle(Vector3.ZERO, 5.0)
	assert_almost_eq(c.outward(Vector3(0, 0, -2)).y, -1.0, 0.0001)


func test_ground_top_lands_only_from_above() -> void:
	var a := ArenaData.new()
	a.add_floor(ArenaShape.circle(Vector3.ZERO, 10.0))
	a.add_floor(ArenaShape.box(Vector3(0, 2.0, 0), Vector2(2.0, 2.0)))
	assert_almost_eq(ArenaFloor.ground_top(a, Vector3(0, 1.9, 0), 2.03), 2.0, 0.0001, "onto the raised box")
	assert_almost_eq(ArenaFloor.ground_top(a, Vector3(0, -0.01, 0), 0.5), 0.0, 0.0001, "under the box: the floor")
	assert_eq(ArenaFloor.ground_top(a, Vector3(0, -0.2, 0), -0.1), ArenaFloor.NO_GROUND, "came from below")
	assert_eq(ArenaFloor.ground_top(a, Vector3(12, 0, 0), 0.0), ArenaFloor.NO_GROUND, "off the arena")


func test_inactive_floor_is_not_ground() -> void:
	var a := ArenaData.new()
	var i := a.add_floor(ArenaShape.box(Vector3.ZERO, Vector2(2.0, 2.0)))
	assert_true(ArenaFloor.over_floor(a, Vector3.ZERO))
	a.floor_active[i] = false
	assert_false(ArenaFloor.over_floor(a, Vector3.ZERO))
	assert_eq(ArenaFloor.ground_top(a, Vector3(0, -0.01, 0), 0.0), ArenaFloor.NO_GROUND)


func test_out_zone_reasons() -> void:
	var c := GameConfig.new()
	var a := ArenaCatalog.default(c)
	assert_eq(ArenaFloor.out_zone(a, Vector3.ZERO), "")
	assert_eq(ArenaFloor.out_zone(a, Vector3(0, c.kill_y - 0.1, 0)), "kill_y")
	assert_eq(ArenaFloor.out_zone(a, Vector3(c.arena_radius + c.blast_margin + 0.1, 3, 0)), "blast")
	assert_eq(ArenaFloor.out_zone(a, Vector3(c.arena_radius + c.blast_margin - 0.1, 3, 0)), "")
	a.ringout_zones.append(ArenaShape.circle(Vector3(15, -0.5, 0), 5.0, "lake"))
	assert_eq(ArenaFloor.out_zone(a, Vector3(14, -0.6, 0)), "lake")
	assert_eq(ArenaFloor.out_zone(a, Vector3(14, -0.4, 0)), "", "above the water line")


func test_default_arena_follows_the_config_radius() -> void:
	var c := GameConfig.new()
	var a := ArenaCatalog.default(c)
	assert_eq(a.id, ArenaCatalog.DEFAULT_ID)
	assert_true(ArenaFloor.over_floor(a, Vector3(9.9, 0, 0)))
	c.arena_radius = 14.0
	a.sync(c)
	assert_true(ArenaFloor.over_floor(a, Vector3(13.9, 0, 0)), "debug slider still moves the edge")
	assert_almost_eq(a.blast_radius, 14.0 + c.blast_margin, 0.0001)
	assert_almost_eq(a.spawn_point(0, 2).x, -7.0, 0.0001)


func test_default_spawn_matches_the_ring_formula() -> void:
	var c := GameConfig.new()
	var a := ArenaCatalog.default(c)
	for count: int in [2, 3, 4]:
		for i: int in count:
			var angle := PI + TAU * float(i) / float(count)
			var r := c.arena_radius * ArenaData.SPAWN_RADIUS_RATIO
			assert_eq(a.spawn_point(i, count), Vector3(cos(angle) * r, 0.0, sin(angle) * r))


func test_catalog_builds_every_arena_with_spawns_on_ground() -> void:
	var c := GameConfig.new()
	assert_eq(ArenaCatalog.stage_ids().size(), 5, "four Phase 4 stages and the frozen pond")
	for id: String in ArenaCatalog.ids():
		var a := ArenaCatalog.build(id, c)
		assert_not_null(a, id)
		assert_eq(a.id, id)
		assert_ne(a.theme_id, "", "%s has a theme id for render" % id)
		for i: int in 4:
			assert_true(ArenaFloor.over_floor(a, a.spawn_point(i, 4)), "%s spawn %d on ground" % [id, i])
			assert_eq(ArenaFloor.out_zone(a, a.spawn_point(i, 4)), "", "%s spawn %d inside bounds" % [id, i])


func test_catalog_rejects_unknown_ids() -> void:
	assert_null(ArenaCatalog.build("moon_base", GameConfig.new()))
	assert_push_error("unknown arena")


func test_copy_is_independent() -> void:
	var a := ArenaCatalog.build("log_bridge", GameConfig.new())
	var b := a.copy()
	b.floor_active[1] = false
	assert_true(a.floor_active[1])
	assert_eq(b.gimmicks.size(), a.gimmicks.size())
	assert_ne(b.gimmicks[0], a.gimmicks[0], "gimmicks are copied, not shared")


func test_world_defaults_to_the_classic_arena() -> void:
	var w := World.new(GameConfig.new(), 1)
	var view := w.state_view()
	assert_eq(view["arena"], ArenaCatalog.DEFAULT_ID)
	assert_eq(view["arena_radius"], 10.0)
	assert_eq((view["gimmicks"] as Array).size(), 0)


func test_world_uses_the_given_arena() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1, 4, ArenaCatalog.build("log_bridge", c))
	assert_eq(w.state_view()["arena"], "log_bridge")
	for f: Fighter in w.fighters:
		assert_true(ArenaFloor.over_floor(w.arena, f.pos))
	for i: int in 30:
		w.tick(_neutral(4))
	for f: Fighter in w.fighters:
		assert_true(f.on_ground, "fighters stand on the bridge")


func test_walking_off_the_bridge_side_falls_into_water() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1, 2, ArenaCatalog.build("log_bridge", c))
	var zones: Array[String] = []
	for i: int in 180:
		var walk := InputFrame.make(0, 1) if zones.is_empty() else InputFrame.neutral()
		var a: Array[InputFrame] = [walk, InputFrame.neutral()]
		w.tick(a)
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "ringout":
				zones.append(String(e["zone"]))
	assert_eq(zones.size(), 1, "one ring-out")
	assert_eq(zones[0] if zones.size() > 0 else "", "water")


func test_snapshot_carries_arena_state() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1, 2, ArenaCatalog.build("log_bridge", c))
	w.arena.floor_active[1] = false
	var snap := w.snapshot()
	var other := World.new(c, 9, 2, ArenaCatalog.build("log_bridge", c))
	assert_true(other.restore(snap))
	assert_false(other.arena.floor_active[1])
	assert_eq(other.state_hash(), w.state_hash())


func test_restore_rejects_another_arena() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1, 2, ArenaCatalog.build("log_bridge", c))
	var other := World.new(c, 1)
	assert_false(other.restore(w.snapshot()))
	assert_push_error("arena mismatch")


func test_safe_point_keeps_single_floor_edges_exact() -> void:
	var a := ArenaData.new()
	a.add_floor(ArenaShape.circle(Vector3.ZERO, 10.0))
	var near_edge := Vector3(9.5, 0, 0)
	assert_almost_eq(ArenaFloor.safe_point(a, near_edge, 0.8).x, 8.0, 0.0001, "one floor: per-floor rule")
	var b := ArenaData.new()
	b.add_floor(ArenaShape.box(Vector3(-2, 0, 0), Vector2(4, 4)))
	b.add_floor(ArenaShape.box(Vector3(2, 0, 0), Vector2(4, 4)))
	assert_eq(ArenaFloor.safe_point(b, Vector3(0, 0, 0.5), 0.8), Vector3(0, 0, 0.5), "a seam between floors is not an edge")
