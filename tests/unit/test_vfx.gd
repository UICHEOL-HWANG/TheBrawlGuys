extends GutTest
## VFX nodes spawn, scale with intensity and free themselves.


func test_dust_puff_frees_itself() -> void:
	var d := DustPuff.new()
	add_child(d)
	d.play(Vector3.ZERO, 1.0, 1.0)
	assert_gt(d.get_child_count(), 0)
	await wait_seconds(DustPuff.LIFETIME + 0.2)
	assert_false(is_instance_valid(d), "dust puff frees itself")


func test_dust_count_scales_with_intensity_and_quality() -> void:
	var big := DustPuff.new()
	add_child_autofree(big)
	big.play(Vector3.ZERO, 1.0, 1.0)
	var small := DustPuff.new()
	add_child_autofree(small)
	small.play(Vector3.ZERO, 1.0, 0.5)
	assert_gt(big.get_child_count(), small.get_child_count(), "LOW quality spawns fewer puffs")


func test_trail_samples_fade_out() -> void:
	var t := KnockbackTrail.new()
	add_child_autofree(t)
	t.add_sample(Vector3.ZERO, 1.0, DS.P1, 1.0)
	assert_gt(t.get_child_count(), 0)
	await wait_seconds(KnockbackTrail.SAMPLE_LIFETIME + 0.2)
	assert_eq(t.get_child_count(), 0, "samples free themselves")


func test_lake_check_matches_the_decor_layout() -> void:
	var r := 10.0
	assert_true(DecorView.is_over_lake(Vector3(r + DecorView.LAKE_OFFSET, -5, 0), r))
	assert_false(DecorView.is_over_lake(Vector3(-(r + DecorView.LAKE_OFFSET), -5, 0), r))


func test_ringout_burst_both_kinds_free_themselves() -> void:
	for splash: bool in [true, false]:
		var b := RingoutBurst.new()
		add_child(b)
		b.play(Vector3.ZERO, splash, DS.P2, 1.0)
		assert_gt(b.get_child_count(), 0)
		await wait_seconds(RingoutBurst.LIFETIME + 0.2)
		assert_false(is_instance_valid(b))


func test_respawn_beam_frees_itself() -> void:
	var beam := RespawnBeam.new()
	add_child(beam)
	beam.play(Vector3(0, 6, 0))
	await wait_seconds(RespawnBeam.LIFETIME + 0.2)
	assert_false(is_instance_valid(beam))


func test_charge_glow_scales_with_charge() -> void:
	var g := ChargeGlow.new()
	add_child_autofree(g)
	g.set_charge(0.0)
	assert_false(g.visible)
	g.set_charge(0.5)
	var half := g.base_scale()
	g.set_charge(1.0)
	assert_true(g.visible)
	assert_gt(g.base_scale(), half)


func test_camera_punch_decays() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.setup(GameConfig.new())
	rig.punch(1.0)
	assert_gt(rig.punch_offset(), 0.0)
	for i: int in 120:
		rig.follow(PackedVector3Array([Vector3.ZERO]), 1.0 / 60.0)
	assert_almost_eq(rig.punch_offset(), 0.0, 0.01, "punch settles back")
