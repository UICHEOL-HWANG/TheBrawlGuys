extends GutTest
## Arena rendering (Phase 4 T6, PRD §6.1, DS-VIS-04): every arena builds its floors, water and
## gimmick views from the sim's ArenaData and follows the per-tick arena state.


func _view(id: String) -> ArenaView:
	var v := ArenaView.new()
	add_child_autofree(v)
	v.setup(GameConfig.new(), id)
	return v


func test_every_arena_builds_its_floors_and_gimmicks() -> void:
	var c := GameConfig.new()
	for id: String in ArenaCatalog.ids():
		var v := _view(id)
		var data := ArenaCatalog.build(id, c)
		assert_eq(v.arena_id(), id)
		assert_eq(v.gimmick_views().size(), data.gimmicks.size(), "%s: one view per gimmick" % id)
		var owned := 0
		for gv: GimmickView in v.gimmick_views():
			if gv.owned_floor() >= 0:
				owned += 1
		assert_eq(v.drawn_floor_count() + owned, data.floors.size(), "%s: every floor is drawn once" % id)


func test_gimmick_kinds_get_their_views() -> void:
	assert_true(_view("lakeside_camp").gimmick_view(0) is CampfireView)
	assert_true(_view("log_bridge").gimmick_view(0) is PlankView)
	assert_true(_view("mushroom_forest").gimmick_view(0) is MushroomPadView)
	assert_true(_view("foggy_forest").gimmick_view(0) is FogView)


func test_ring_out_zones_are_drawn_as_water() -> void:
	for id: String in ["lakeside_camp", "log_bridge"]:
		var found := false
		for c: Node in _view(id).get_children():
			if c is WaterView:
				found = true
				assert_gt((c as WaterView).glint_count(), 0, "%s water sparkles" % id)
		assert_true(found, "%s has water under its ring-out zone" % id)
	for c: Node in _view("classic").get_children():
		assert_false(c is WaterView, "classic has no ring-out zone")


func test_campfire_marks_its_burn_radius() -> void:
	var campfire := _view("lakeside_camp").gimmick_view(0) as CampfireView
	assert_almost_eq(campfire.ring_radius(), LakesideCampArena.CAMPFIRE_RADIUS, 0.001)
	assert_gt(campfire.ember_count(), 0, "embers rise from the fire")


func test_planks_crack_fall_and_come_back_with_the_sim() -> void:
	var c := GameConfig.new()
	var v := _view("log_bridge")
	var w := World.new(c, 1, 2, ArenaCatalog.build("log_bridge", c))
	var first := -1
	for g: Gimmick in w.arena.gimmicks:
		if (g as BreakablePlatform).order == 0:
			first = g.id
	var plank := v.gimmick_view(first) as PlankView
	var warn_start := SimTime.to_ticks(c.platform_break_start_time)
	_run(w, v, warn_start + SimTime.to_ticks(c.platform_warn_time) / 2)
	assert_gt(plank.stage(), 0, "cracks show during the warning")
	_run(w, v, SimTime.to_ticks(c.platform_warn_time))
	assert_eq(plank.stage(), PlankView.MAX_STAGE)
	await wait_seconds(PlankView.FALL_TIME + 0.2)
	assert_false(plank.deck_visible(), "the broken plank dropped into the water")
	_run(w, v, SimTime.to_ticks(c.platform_respawn_time))
	assert_true(plank.deck_visible(), "restored with the sim")
	assert_eq(plank.stage(), 0)


func _run(w: World, v: ArenaView, ticks: int) -> void:
	var idle: Array[InputFrame] = [InputFrame.new(), InputFrame.new()]
	for i: int in ticks:
		w.tick(idle)
	v.sync(w.state_view(), w.tick_count, 1.0 / 60.0)


func test_crack_stage_grows_with_hits_then_the_warning() -> void:
	assert_eq(PlankView.crack_stage({"hits": 0}, 90, 6), 0)
	assert_eq(PlankView.crack_stage({"hits": 2}, 90, 6), 1, "hits taken on it show a first crack")
	assert_eq(PlankView.crack_stage({"cracking": true, "ticks_left": 89}, 90, 6), 1)
	assert_eq(PlankView.crack_stage({"cracking": true, "ticks_left": 5}, 90, 6), PlankView.MAX_STAGE)
	assert_eq(PlankView.crack_stage({"broken": true}, 90, 6), PlankView.MAX_STAGE)


func test_mushroom_squashes_on_its_own_bounce() -> void:
	var v := _view("mushroom_forest")
	var pad := v.gimmick_view(1) as MushroomPadView
	var other := v.gimmick_view(0) as MushroomPadView
	v.on_events([{"type": "bounce", "fighter": 0, "pad": 1, "pos": Vector3.ZERO}])
	assert_true(pad.squashing())
	assert_false(other.squashing(), "only the pad that was bounced on")
	var view := {"arena_floors": [true], "gimmicks": [{"kind": "bounce_pad", "id": 1}]}
	v.sync(view, 1, 0.02)
	assert_lt(pad.cap_scale().y, 0.8, "squashed flat right after the bounce")
	v.sync(view, 2, MushroomPadView.SQUASH_TIME)
	assert_false(pad.squashing(), "springs back")


func test_classic_follows_the_radius_slider() -> void:
	var c := GameConfig.new()
	var v := ArenaView.new()
	add_child_autofree(v)
	v.setup(c)
	c.arena_radius = 7.0
	c.emit_changed()
	assert_almost_eq(v.arena().view_radius(), 7.0, 0.001)


func test_match_camera_frames_the_arena_in_the_view() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1, 2, ArenaCatalog.build("log_bridge", c))
	var pts := CameraFraming.match_targets(w.state_view(), c)
	var reach := 0.0
	for i: int in 4:
		reach = maxf(reach, pts[i].length())
	assert_almost_eq(reach, w.arena.view_radius() * c.cam_arena_share, 0.001, "the long bridge widens the anchors")
	var legacy := CameraFraming.match_targets({"fighters": []}, c)
	assert_almost_eq(legacy[1].x, c.arena_radius * c.cam_arena_share, 0.001, "views without a radius use the config")


func test_water_ring_outs_splash() -> void:
	assert_true(DecorView.is_water_ringout({"zone": "lake", "pos": Vector3(-50, -1, 0)}, 10.0))
	assert_true(DecorView.is_water_ringout({"zone": "water", "pos": Vector3(0, -1, 0)}, 10.0))
	assert_false(DecorView.is_water_ringout({"zone": "kill_y", "pos": Vector3(-30, -9, 0)}, 10.0))
	assert_true(DecorView.is_water_ringout({"zone": "blast", "pos": Vector3(24, -1, 0)}, 10.0), "over the meadow lake")
