extends GutTest
## Menu backdrop orbit diorama (platform B2, design.md DS-LAY-03): four bots brawl on the real
## sim, matches restart by themselves, the camera orbits the whole arena, no telemetry.


func test_orbit_pose_matches_the_match_camera_at_yaw_zero() -> void:
	var t := OrbitCamera.pose(0.0, 60.0, Vector3.ZERO, 20.0)
	var p := deg_to_rad(60.0)
	assert_almost_eq(t.origin, Vector3(0, sin(p), cos(p)) * 20.0, Vector3.ONE * 0.001)
	assert_almost_eq(-t.basis.z, (Vector3.ZERO - t.origin).normalized(), Vector3.ONE * 0.001, "looks at the center")


func test_orbit_pose_rotates_around_the_arena() -> void:
	var a := OrbitCamera.pose(0.0, 60.0, Vector3(0, 0, 1), 20.0)
	var b := OrbitCamera.pose(PI * 0.5, 60.0, Vector3(0, 0, 1), 20.0)
	assert_almost_eq(Vector2(a.origin.x, a.origin.z).length(), Vector2(b.origin.x, b.origin.z).length(), 0.001,
			"same distance from the arena axis at every yaw")
	assert_almost_eq(a.origin.y, b.origin.y, 0.001, "same height")
	assert_gt(absf(b.origin.x), 1.0, "a quarter turn moves the camera to the side")


func test_orbit_frames_the_arena_core_closer_than_the_whole_arena() -> void:
	var cfg := GameConfig.new()
	var core := OrbitCamera.frame(cfg, 16.0 / 9.0)
	cfg.menu_orbit_arena_share = 1.0
	var whole := OrbitCamera.frame(cfg, 16.0 / 9.0)
	assert_gt(float(whole["distance"]), float(core["distance"]), "the core framing is closer")
	assert_lt(cfg.menu_orbit_pitch, cfg.cam_pitch, "lower than the match camera so fighters read")


func test_lens_offset_moves_the_look_at_point_on_screen() -> void:
	assert_eq(OrbitCamera.lens_offset(Vector2.ZERO, 20.0, 40.0, 16.0 / 9.0), Vector2.ZERO)
	var t := tan(deg_to_rad(20.0))
	var off := OrbitCamera.lens_offset(Vector2(0.5, -0.25), 20.0, 40.0, 2.0)
	assert_almost_eq(off.x, -0.5 * 20.0 * t * 2.0, 0.0001, "right on screen = camera shifted left")
	assert_almost_eq(off.y, 0.25 * 20.0 * t, 0.0001, "low on screen = camera shifted up")


func test_fight_center_follows_the_fighters_in_play() -> void:
	var cfg := GameConfig.new()
	var m := BackdropMatch.new(cfg, 1)
	for f: Fighter in m.world.fighters:
		f.pos = Vector3(2.0, 1.0, 0.0)
	m.advance(1.0 / 60.0)
	var c := m.fight_center(100.0)
	assert_almost_eq(c.y, 0.0, 0.0001, "on the ground")
	assert_gt(c.x, 1.0)
	assert_almost_eq(m.fight_center(0.5).length(), 0.5, 0.001, "kept near the arena center")


func test_backdrop_match_runs_four_bots_and_restarts() -> void:
	var cfg := GameConfig.new()
	var m := BackdropMatch.new(cfg, 1)
	assert_eq(m.world.fighters.size(), BackdropMatch.PLAYERS)
	for i: int in 30:
		m.advance(1.0 / 60.0)
	var moved := 0
	for i: int in BackdropMatch.PLAYERS:
		if m.world.fighters[i].pos != Rules.spawn_point(i, BackdropMatch.PLAYERS, cfg):
			moved += 1
	assert_eq(moved, BackdropMatch.PLAYERS, "every fighter is a bot")
	var first := m.world
	for f: Fighter in first.fighters.slice(1):
		f.stocks = 1
		f.pos = Vector3(0, cfg.kill_y - 1, 0)
	m.advance(1.0 / 60.0)
	assert_true(bool(m.curr_state["match_over"]))
	for i: int in int(BackdropMatch.RESTART_DELAY_S * 60.0) + 5:
		m.advance(1.0 / 60.0)
	assert_ne(m.world, first, "a new match started")
	assert_eq(m.matches_started(), 2)


func test_backdrop_scene_orbits_and_draws() -> void:
	var b := (load("res://src/app/menu_backdrop/menu_backdrop.tscn") as PackedScene).instantiate() as MenuBackdrop
	add_child_autofree(b)
	var yaw_before := b.camera().yaw()
	await wait_seconds(0.3)
	assert_gt(b.camera().yaw(), yaw_before, "the camera turns")
	assert_gt(b.world().tick_count, 0, "the brawl runs")
	assert_eq(b.find_children("*", "Hud", true, false).size(), 0, "no HUD in the backdrop")
	assert_true(b.is_playing_menu_music())
	for v: FighterView in b.stage().views():
		assert_false(v.identity_visible(), "no P1-P4 rings or labels in menus")
	b.set_focus(Vector2(0.0, -0.3))
	await wait_seconds(0.5)
	assert_almost_eq(b.camera().focus().y, -0.3, 0.05, "the fight slides into the free area")


func test_backdrop_is_hazed_and_reveals_from_full_haze() -> void:
	var b := (load("res://src/app/menu_backdrop/menu_backdrop.tscn") as PackedScene).instantiate() as MenuBackdrop
	add_child_autofree(b)
	await wait_process_frames(1)
	var env := b.stage().environment_rig().environment()
	assert_true(env.fog_enabled, "sage-gray depth fog")
	assert_eq(env.fog_light_color, DS.HAZE)
	assert_almost_eq(b.haze().amount(), DS.HAZE_AMOUNT, 0.001)
	b.reveal()
	assert_almost_eq(b.haze().amount(), 1.0, 0.001, "starts fully hazed")
	await wait_seconds(UiMotion.duration(UiMotion.Token.CALM) + 0.2)
	assert_almost_eq(b.haze().amount(), DS.HAZE_AMOUNT, 0.01)
