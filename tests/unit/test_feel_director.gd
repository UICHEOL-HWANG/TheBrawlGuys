extends GutTest


func test_reset_stops_the_shake() -> void:
	var c := GameConfig.new()
	var feel := FeelDirector.new()
	add_child_autofree(feel)
	feel.setup(c, null)
	feel.on_events([{"type": "ringout", "id": 1, "pos": Vector3.ZERO, "stocks_left": 2}])
	feel._process(1.0 / 60.0)
	assert_gt(feel.shake_amplitude(), 0.0)
	feel.reset()
	assert_eq(feel.shake_amplitude(), 0.0, "a restart starts calm")


func test_explosion_shakes_and_guard_hit_clangs() -> void:
	var c := GameConfig.new()
	var feel := FeelDirector.new()
	add_child_autofree(feel)
	feel.setup(c, null)
	var base := feel.get_child_count()  # trail, pooled bursts, damage numbers, screen flash
	feel.on_events([{"type": "guard_hit", "attacker": 0, "target": 1, "pos": Vector3(0, 1, 0), "knockback": 0.0, "hitstop_ticks": 4, "power": 1.0}])
	var bursts := feel.active_bursts()
	assert_eq(bursts.size(), 1, "a clang for a guarded hit")
	assert_false(bursts[0].star_visible(), "guard clang has no star")
	assert_eq(feel.popups().active_count(), 0, "no damage number on guard")
	assert_eq(feel.get_child_count(), base, "pooled: no node per hit")
	feel.on_events([{"type": "explosion", "id": 0, "pos": Vector3.ZERO, "radius": c.bomb_radius}])
	feel._process(1.0 / 60.0)
	assert_gt(feel.shake_amplitude(), 0.0)
	assert_eq(feel.get_child_count(), base + 1, "explosions keep the round puff")


func _fighters(damage: float) -> Array:
	return [{"id": 0, "pos": Vector3(0, 0, 0), "damage": 0.0}, {"id": 1, "pos": Vector3(1, 0, 0), "damage": damage}]


func _hit(kb: float, dealt: float) -> Dictionary:
	return {"type": "hit", "attacker": 0, "target": 1, "pos": Vector3(0.9, 0.9, 0), "damage": dealt,
			"knockback": kb, "hitstop_ticks": 6, "power": 1.0, "attack_kind": AttackSet.Kind.HEAVY}


func test_light_hit_shows_a_star_and_a_number_without_heavy_extras() -> void:
	var c := GameConfig.new()
	var feel := FeelDirector.new()
	add_child_autofree(feel)
	feel.setup(c, null)
	feel.on_events([_hit(1.0, 3.0)], _fighters(3.0))
	assert_eq(feel.active_bursts().size(), 1)
	assert_true(feel.active_bursts()[0].star_visible())
	assert_eq(feel.popups().active_count(), 1)
	assert_false(feel.screen_flash().showing(), "no flash on a light hit")


func test_heavy_hit_flashes_the_screen() -> void:
	var c := GameConfig.new()
	var feel := FeelDirector.new()
	add_child_autofree(feel)
	feel.setup(c, null)
	feel.on_events([_hit(c.spark_large_threshold + 1.0, 12.0)], _fighters(40.0))
	assert_true(feel.screen_flash().showing())


func test_reset_clears_running_hit_effects() -> void:
	var c := GameConfig.new()
	var feel := FeelDirector.new()
	add_child_autofree(feel)
	feel.setup(c, null)
	feel.on_events([_hit(c.spark_large_threshold + 1.0, 12.0)], _fighters(40.0))
	feel.reset()
	assert_eq(feel.active_bursts().size(), 0)
	assert_eq(feel.popups().active_count(), 0)
	assert_false(feel.screen_flash().showing())


func test_bursts_are_capped_by_the_pool() -> void:
	var c := GameConfig.new()
	var feel := FeelDirector.new()
	add_child_autofree(feel)
	feel.setup(c, null)
	var many: Array = []
	for i: int in 20:
		many.append(_hit(2.0, 3.0))
	feel.on_events(many, _fighters(3.0))
	assert_eq(feel.active_bursts().size(), ImpactTier.pool_cap(Quality.particle_scale(c)))


func test_perfect_guard_replaces_the_clang_with_a_bigger_star_flash() -> void:
	var feel := FeelDirector.new()
	add_child_autofree(feel)
	feel.setup(GameConfig.new(), null)
	feel.on_events([
		{"type": "guard_hit", "attacker": 0, "target": 1, "pos": Vector3(0, 1, 0), "knockback": 0.0, "hitstop_ticks": 4, "power": 1.0},
		{"type": "perfect_guard", "fighter": 1, "attacker": 0, "pos": Vector3.ZERO},
	])
	var bursts := feel.active_bursts()
	assert_eq(bursts.size(), 1, "one effect: no clang under the flash")
	assert_true(bursts[0].star_visible(), "a star flash, unlike the clang")
	assert_gt(bursts[0].radius(), ImpactBurst.CLANG_RADIUS)
	assert_gt(ImpactBurst.PERFECT_FADE, ImpactBurst.CLANG_FADE, "lingers longer than a clang")
