extends GutTest
## Quality levels (context F7): LOW = 30 fps, no realtime shadow (blob shadows), half particles,
## no bloom; MEDIUM = 60 fps, shadows, no bloom; HIGH = everything.

var _saved_fps: int = 0


func before_each() -> void:
	_saved_fps = Engine.max_fps


func after_each() -> void:
	Engine.max_fps = _saved_fps


func test_platform_defaults() -> void:
	assert_eq(Quality.resolve(-1, "mobile"), Quality.Level.MEDIUM)
	assert_eq(Quality.resolve(-1, "web"), Quality.Level.LOW)
	assert_eq(Quality.resolve(-1, "desktop"), Quality.Level.HIGH)
	assert_eq(Quality.resolve(0, "desktop"), Quality.Level.LOW, "an explicit level wins")


func test_level_table() -> void:
	var low := Quality.settings(Quality.Level.LOW)
	assert_eq(low["max_fps"], 30)
	assert_false(low["shadows"])
	assert_true(low["blob_shadows"])
	assert_false(low["glow"])
	assert_eq(low["particle_scale"], 0.5)
	var mid := Quality.settings(Quality.Level.MEDIUM)
	assert_eq(mid["max_fps"], 60)
	assert_true(mid["shadows"])
	assert_false(mid["glow"])
	var high := Quality.settings(Quality.Level.HIGH)
	assert_true(high["shadows"] and high["glow"])
	assert_eq(high["particle_scale"], 1.0)


func test_environment_rig_applies_a_level() -> void:
	var rig := EnvironmentRig.new()
	add_child_autofree(rig)
	rig.setup()
	rig.apply_quality(Quality.Level.LOW)
	assert_false(rig.sun().shadow_enabled)
	assert_false(rig.environment().glow_enabled)
	assert_eq(Engine.max_fps, 30)
	rig.apply_quality(Quality.Level.HIGH)
	assert_true(rig.sun().shadow_enabled)
	assert_true(rig.environment().glow_enabled)
	assert_eq(Engine.max_fps, 60)


func test_blob_shadow_stays_on_the_ground() -> void:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(0, GameConfig.new())
	v.set_blob_shadow(true)
	assert_true(v.blob_visible())
	var d := {"id": 0, "spawn_id": 0, "pos": Vector3(1, 3, 2), "facing": Vector3(0, 0, 1),
		"state": Fighter.State.AIR, "on_ground": false, "attack_kind": 0, "invuln_ticks": 0,
		"item_kind": Fighter.NONE, "item_uses": 0, "charge_ticks": 0, "hitstop_ticks": 0}
	v.apply(d, d, 1.0, 0)
	var blob := v.blob()
	assert_almost_eq(blob.global_position.y, BlobShadow.LIFT, 0.001, "shadow sits on the floor while jumping")
	v.set_blob_shadow(false)
	assert_false(v.blob_visible())


func test_quality_group_is_presentation_only() -> void:
	var a := GameConfig.new()
	var b := GameConfig.new()
	b.quality_level = 0
	assert_eq(a.fingerprint(), b.fingerprint())


func test_environment_energies_pick_by_renderer_and_glow() -> void:
	var desktop_glow := EnvironmentRig.energies(false, true)
	var desktop_plain := EnvironmentRig.energies(false, false)
	assert_eq(desktop_glow["sun"], EnvironmentRig.SUN_ENERGY)
	assert_eq(desktop_plain["sun"], EnvironmentRig.SUN_ENERGY, "desktop ignores glow")
	assert_eq(desktop_plain["ambient"], EnvironmentRig.AMBIENT_ENERGY)
	var compat_glow := EnvironmentRig.energies(true, true)
	assert_eq(compat_glow["sun"], EnvironmentRig.SUN_ENERGY_COMPAT)
	assert_eq(compat_glow["ambient"], EnvironmentRig.AMBIENT_ENERGY_COMPAT)
	assert_eq(compat_glow["glow"], EnvironmentRig.GLOW_INTENSITY_COMPAT)
	var compat_plain := EnvironmentRig.energies(true, false)
	assert_eq(compat_plain["sun"], EnvironmentRig.SUN_ENERGY_COMPAT_NO_GLOW)
	assert_eq(compat_plain["ambient"], EnvironmentRig.AMBIENT_ENERGY_COMPAT_NO_GLOW)
	assert_gt(compat_plain["sun"] + compat_plain["ambient"], compat_glow["sun"] + compat_glow["ambient"],
		"without bloom the compat light must be brighter to keep the DS tone")


func test_apply_quality_updates_light_energies() -> void:
	var rig := EnvironmentRig.new()
	add_child_autofree(rig)
	rig.setup()
	var is_compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	rig.apply_quality(Quality.Level.LOW)
	assert_almost_eq(rig.sun().light_energy, float(EnvironmentRig.energies(is_compat, false)["sun"]), 0.0001)
	rig.apply_quality(Quality.Level.HIGH)
	assert_almost_eq(rig.sun().light_energy, float(EnvironmentRig.energies(is_compat, true)["sun"]), 0.0001)
	assert_almost_eq(rig.environment().ambient_light_energy, float(EnvironmentRig.energies(is_compat, true)["ambient"]), 0.0001)
