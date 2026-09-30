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
