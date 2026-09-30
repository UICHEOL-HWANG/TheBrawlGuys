extends GutTest
## Hit impact tiers and sizes (design.md DS-VFX-01 v2, DS-VFX-07).


func test_tier_follows_knockback_thresholds() -> void:
	var c := GameConfig.new()
	assert_eq(ImpactTier.of(0.0, c), ImpactTier.Tier.LIGHT)
	assert_eq(ImpactTier.of(c.impact_medium_threshold - 0.01, c), ImpactTier.Tier.LIGHT)
	assert_eq(ImpactTier.of(c.impact_medium_threshold, c), ImpactTier.Tier.MEDIUM)
	assert_eq(ImpactTier.of(c.spark_large_threshold - 0.01, c), ImpactTier.Tier.MEDIUM)
	assert_eq(ImpactTier.of(c.spark_large_threshold, c), ImpactTier.Tier.HEAVY)


func test_default_attacks_land_in_distinct_tiers() -> void:
	var c := GameConfig.new()
	var set := AttackSet.from_config(c)
	var link := Combat.knockback(set.get_attack(AttackSet.Kind.LIGHT_1), c.light_link_damage, c)
	var heavy := Combat.knockback(set.get_attack(AttackSet.Kind.HEAVY), c.heavy_damage, c)
	assert_eq(ImpactTier.of(link, c), ImpactTier.Tier.LIGHT, "a combo link is a light hit")
	assert_eq(ImpactTier.of(heavy, c), ImpactTier.Tier.HEAVY, "a fresh heavy is a heavy hit")


func test_sizes_grow_with_the_tier() -> void:
	var tiers := [ImpactTier.Tier.LIGHT, ImpactTier.Tier.MEDIUM, ImpactTier.Tier.HEAVY]
	for i: int in range(1, tiers.size()):
		assert_gt(ImpactTier.burst_radius(tiers[i]), ImpactTier.burst_radius(tiers[i - 1]))
		assert_gt(ImpactTier.popup_scale(tiers[i]), ImpactTier.popup_scale(tiers[i - 1]))
		assert_true(ImpactTier.star_points(tiers[i]) >= ImpactTier.star_points(tiers[i - 1]))


func test_only_heavy_hits_get_speed_lines_and_fewer_on_low_quality() -> void:
	assert_eq(ImpactTier.speed_lines(ImpactTier.Tier.LIGHT, 1.0), 0)
	assert_eq(ImpactTier.speed_lines(ImpactTier.Tier.MEDIUM, 1.0), 0)
	var full := ImpactTier.speed_lines(ImpactTier.Tier.HEAVY, 1.0)
	var low := ImpactTier.speed_lines(ImpactTier.Tier.HEAVY, 0.5)
	assert_gt(full, 0)
	assert_gt(low, 0)
	assert_lt(low, full)


func test_pool_cap_shrinks_on_low_quality() -> void:
	assert_lt(ImpactTier.pool_cap(0.5), ImpactTier.pool_cap(1.0))
	assert_gt(ImpactTier.pool_cap(0.0), 0, "always at least one effect")


func test_popup_text_shows_the_percent_dealt() -> void:
	assert_eq(ImpactTier.popup_text(12.0), "+12%")
	assert_eq(ImpactTier.popup_text(3.4), "+3%")
	assert_eq(ImpactTier.popup_text(19.2), "+19%")
	assert_eq(ImpactTier.popup_text(0.8), "+0.8%", "chip damage keeps its decimal")


func test_melee_direction_points_from_attacker_to_target() -> void:
	var d := ImpactTier.hit_direction(Vector3(2, 0, 0), Vector3(3, 1, 0), Vector3(0, 0, 0), true)
	assert_almost_eq(d.x, 1.0, 0.0001)
	assert_almost_eq(d.y, 0.0, 0.0001, "flat")


func test_ranged_direction_points_from_hit_point_to_target() -> void:
	var d := ImpactTier.hit_direction(Vector3(0, 0, 2), Vector3(0, 1, 0), Vector3(9, 0, 9), false)
	assert_almost_eq(d.z, 1.0, 0.0001)
	assert_almost_eq(d.length(), 1.0, 0.0001)


func test_throw_at_the_target_position_reads_from_the_thrower() -> void:
	var d := ImpactTier.hit_direction(Vector3(0, 0, 0), Vector3(0, 0, 0), Vector3(0, 0, 3), false)
	assert_almost_eq(d.z, -1.0, 0.0001)


func test_degenerate_direction_is_still_a_unit_vector() -> void:
	var d := ImpactTier.hit_direction(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, true)
	assert_almost_eq(d.length(), 1.0, 0.0001)
