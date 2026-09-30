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


func test_explosion_shakes_and_guard_hit_puffs() -> void:
	var c := GameConfig.new()
	var feel := FeelDirector.new()
	add_child_autofree(feel)
	feel.setup(c, null)
	var base := feel.get_child_count()  # the persistent knockback trail node
	feel.on_events([{"type": "guard_hit", "attacker": 0, "target": 1, "pos": Vector3(0, 1, 0), "knockback": 0.0, "hitstop_ticks": 4, "power": 1.0}])
	assert_eq(feel.get_child_count(), base + 1, "a small puff for a guarded hit")
	feel.on_events([{"type": "explosion", "id": 0, "pos": Vector3.ZERO, "radius": c.bomb_radius}])
	feel._process(1.0 / 60.0)
	assert_gt(feel.shake_amplitude(), 0.0)
	assert_eq(feel.get_child_count(), base + 2)
