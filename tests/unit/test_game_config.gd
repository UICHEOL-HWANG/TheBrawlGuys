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
	assert_eq(c.cam_pitch, 60.0)


func test_default_resource_loads_as_game_config() -> void:
	var res := load(DEFAULT_PATH)
	assert_true(res is GameConfig, "default_config.tres must be a GameConfig")


func test_global_knockback_default() -> void:
	assert_eq(GameConfig.new().global_knockback_mul, 1.0)


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
