extends GutTest

const DEFAULT_PATH := "res://src/config/default_config.tres"


func test_defaults_match_prd_section_4_5() -> void:
	var c := GameConfig.new()
	assert_eq(c.move_speed, 6.0)
	assert_eq(c.jump_velocity, 9.0)
	assert_eq(c.gravity, -25.0)
	assert_eq(c.arena_radius, 10.0)
	assert_eq(c.kill_y, -8.0)
	assert_eq(c.hitstun_factor, 0.04)
	assert_eq(c.hitstop_light, 0.06)
	assert_eq(c.hitstop_heavy, 0.1)
	assert_eq(c.guard_damage_mul, 0.2)
	assert_eq(c.guard_knockback_mul, 0.0)
	assert_eq(c.touch_hold_threshold, 0.15)


func test_camera_defaults_match_gd_cam_01() -> void:
	var c := GameConfig.new()
	assert_eq(c.cam_pitch, 42.0)


func test_default_resource_loads_as_game_config() -> void:
	var res := load(DEFAULT_PATH)
	assert_true(res is GameConfig, "default_config.tres must be a GameConfig")


func test_global_knockback_default() -> void:
	assert_eq(GameConfig.new().global_knockback_mul, 1.7)


func test_phase1_defaults_match_prd() -> void:
	var c := GameConfig.new()
	assert_eq(c.stocks, 3)
	assert_eq(c.respawn_invuln, 2.0)
	assert_eq(c.max_jumps, 2)
	assert_eq(c.light_damage, 4.0)
	assert_eq(c.light_base_knockback, 3.0)
	assert_eq(c.light_knockback_scaling, 0.05)
	assert_eq(c.cam_zoom_max, 70.0)


func test_fingerprint_changes_with_values() -> void:
	var a := GameConfig.new()
	var b := GameConfig.new()
	assert_eq(a.fingerprint(), b.fingerprint(), "same values -> same fingerprint")
	b.light_damage = 5.0
	assert_ne(a.fingerprint(), b.fingerprint(), "changed value -> different fingerprint")


func test_phase2_defaults_match_prd_4_5() -> void:
	var c := GameConfig.new()
	assert_eq(c.heavy_damage, 12.0)
	assert_eq(c.heavy_base_knockback, 6.0)
	assert_eq(c.heavy_knockback_scaling, 0.12)
	assert_eq(c.heavy_charge_max_time, 1.0)
	assert_eq(c.heavy_charge_max_mul, 1.6)
	assert_eq(c.bomb_fuse_time, 2.0)
	assert_eq(c.bat_uses, 5)
	assert_eq(c.item_spawn_min_time, 10.0)
	assert_eq(c.item_spawn_max_time, 15.0)


func test_item_spawn_window_is_ordered() -> void:
	var c := GameConfig.new()
	assert_lt(c.item_spawn_min_time, c.item_spawn_max_time)
	assert_eq(SimTime.to_ticks(c.bomb_fuse_time), 120, "PHASES test: bomb explodes 120 ticks after the throw")


func test_fingerprint_ignores_presentation_groups() -> void:
	var a := GameConfig.new()
	var b := GameConfig.new()
	b.cam_pitch = 45.0
	b.touch_layout = 2
	b.shake_max = 0.1
	b.bot_attack_range = 3.0
	b.max_ticks_per_frame = 2
	assert_eq(a.fingerprint(), b.fingerprint(), "camera/touch/feel/bot/loop never change a replay")


func test_fingerprint_follows_sim_groups() -> void:
	for name: String in ["move_speed", "fighter_radius", "arena_radius", "stocks", "global_knockback_mul",
			"light_damage", "combo_buffer_ticks", "heavy_damage", "grab_hold_max_time", "bomb_radius"]:
		var a := GameConfig.new()
		var b := GameConfig.new()
		var v: Variant = b.get(name)
		b.set(name, v + 1 if typeof(v) == TYPE_INT else float(v) + 0.5)
		assert_ne(a.fingerprint(), b.fingerprint(), "%s is a sim value" % name)


func test_every_group_is_classified() -> void:
	for group: String in GameConfig.group_names():
		assert_true(GameConfig.SIM_GROUPS.has(group) or GameConfig.NON_SIM_GROUPS.has(group),
				"GameConfig group %s must be listed in SIM_GROUPS or NON_SIM_GROUPS" % group)
	for group: String in GameConfig.SIM_GROUPS:
		assert_false(GameConfig.NON_SIM_GROUPS.has(group), "%s listed twice" % group)
