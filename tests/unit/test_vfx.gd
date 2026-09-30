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
