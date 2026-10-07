extends GutTest
## Arena look (Phase 4 T6): per-arena themes (DS-THM-02), the fog with silhouettes above it
## (DS-VIS-03), burning fighters (DS-VIS-04), decor that never hides the arena core from the
## match camera (GD-CAM-01) and the backdrop cycling through the arenas.


func _stage(id: String, players: int = 2) -> MatchStage:
	var s := MatchStage.new()
	add_child_autofree(s)
	s.setup(GameConfig.new(), 3, players, id)
	return s


func test_each_stage_has_its_own_theme() -> void:
	var classic := ArenaTheme.for_id("classic")
	assert_eq(classic.floor_top, DS.GRASS, "classic keeps reference A")
	assert_eq(ArenaTheme.for_id("log_bridge").floor_top, DS.BARK, "bark logs")
	assert_eq(ArenaTheme.for_id("mushroom_forest").sun_color, DS.SUN_GOLD, "golden late afternoon")
	assert_eq(ArenaTheme.for_id("foggy_forest").sun_color, DS.SUN_COOL, "cold morning")
	assert_gt(ArenaTheme.for_id("foggy_forest").fog_density, 0.0, "a light mist even between fogs")
	assert_eq(ArenaTheme.for_id("frozen_pond").floor_top, DS.ICE, "snow-white ice")
	assert_eq(ArenaTheme.for_id("nope").floor_top, DS.GRASS, "unknown ids fall back to classic")


func test_the_environment_takes_the_arena_theme() -> void:
	var s := _stage("mushroom_forest")
	var env := s.environment_rig()
	assert_eq(env.environment().background_color, DS.SKY_GOLD)
	assert_eq(env.sun().light_color, DS.SUN_GOLD)
	s.set_arena("classic")
	assert_eq(env.environment().background_color, DS.SKY, "switching arenas re-themes")
	assert_false(env.environment().fog_enabled, "classic has no fog")


func test_fog_rolls_in_and_fighters_stay_visible_above_it() -> void:
	var s := _stage("foggy_forest")
	var fog := s.arena_view().gimmick_view(0) as FogView
	var fighters: Array = []
	for i: int in 2:
		fighters.append({"state": Fighter.State.IDLE, "pos": Vector3(i, 0, 0), "facing": Vector3.BACK,
			"spawn_id": 0, "invuln_ticks": 0, "on_ground": true, "attack_kind": -1, "charge_ticks": 0,
			"hitstop_ticks": 0, "item_kind": Fighter.NONE, "item_uses": 0})
	var view := {"tick": 1, "fighters": fighters, "items": [], "arena_floors": [true],
		"gimmicks": [{"kind": "fog", "id": 0, "active": true}]}
	var base_density := s.environment_rig().environment().fog_density
	for i: int in 90:
		s.draw(view, view, 1.0, 1.0 / 60.0)
	assert_almost_eq(fog.fog_amount(), 1.0, 0.001, "fully in after the fade")
	assert_true(fog.mist_visible())
	assert_gt(s.environment_rig().environment().fog_density, base_density, "distance fog thickens")
	for h: FighterHazards in s.hazards():
		assert_true(h.silhouette().visible, "silhouette shows while foggy")
		assert_true(h.silhouette().draws_over_fog(), "drawn on top, ignoring fog")
	view["gimmicks"] = [{"kind": "fog", "id": 0, "active": false}]
	for i: int in 90:
		s.draw(view, view, 1.0, 1.0 / 60.0)
	assert_almost_eq(fog.fog_amount(), 0.0, 0.001)
	assert_false(s.hazards()[0].silhouette().visible)


func test_burning_fighters_show_flames() -> void:
	var h := FighterHazards.new()
	add_child_autofree(h)
	h.setup(0, GameConfig.new())
	h.apply({"state": Fighter.State.IDLE, "burning": true}, Vector3.ZERO, 0.0)
	assert_true(h.burning())
	h.apply({"state": Fighter.State.IDLE, "burning": false}, Vector3.ZERO, 0.0)
	assert_false(h.burning())
	h.apply({"state": Fighter.State.KO, "burning": true}, Vector3.ZERO, 1.0)
	assert_false(h.burning(), "nothing while KO")
	assert_false(h.silhouette().visible)


func test_decor_never_hides_the_arena_core_from_the_match_camera() -> void:
	var c := GameConfig.new()
	for id: String in ArenaCatalog.ids():
		var arena := ArenaCatalog.build(id, c)
		var decor := DecorView.new()
		add_child_autofree(decor)
		decor.setup(c, 5, arena)
		var poses := DecorOcclusion.match_poses(c, arena)
		var pieces := decor.occluders()
		assert_gt(pieces.size(), 0, "%s has decor" % id)
		for o: Dictionary in pieces:
			var at: Vector3 = o["pos"]
			assert_false(DecorOcclusion.blocks_any(poses, at, o["radius"], o["height"]),
					"%s: decor at %s blocks the camera" % [id, at])
			assert_false(ArenaFloor.over_floor(arena, at), "%s: decor at %s stands outside the arena" % [id, at])


func test_occlusion_math_catches_a_blocker() -> void:
	var c := GameConfig.new()
	var poses := DecorOcclusion.match_poses(c, ArenaCatalog.default(c))
	var eye: Vector3 = poses[0]["eye"]
	var between := eye.lerp(Vector3.ZERO, 0.5)
	assert_true(DecorOcclusion.blocks_any(poses, Vector3(between.x, 0, between.z), 2.0, eye.y), "a tower between camera and arena")
	assert_false(DecorOcclusion.blocks_any(poses, Vector3(0, -1, -40), 2.0, 5.0), "a tree far behind the arena")


func test_backdrop_cycles_the_arenas() -> void:
	assert_eq(BackdropMatch.arena_for(0), ArenaCatalog.DEFAULT_ID, "starts on the classic meadow")
	var seen := {}
	for i: int in BackdropMatch.ARENA_CYCLE.size():
		seen[BackdropMatch.arena_for(i)] = true
	for id: String in ArenaCatalog.ids():
		assert_true(seen.has(id), "%s shows up in the menus" % id)
	var s := _stage("classic", 4)
	s.set_arena("lakeside_camp")
	assert_eq(s.arena_view().arena_id(), "lakeside_camp")
	assert_true(s.decor().dressing() is LakesideCampView)
