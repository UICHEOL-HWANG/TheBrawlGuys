extends GutTest
## Render-side events from view differences (context F8): no sim events are added.


func _f(id: int, pos: Vector3, on_ground: bool, state: int = Fighter.State.IDLE, spawn_id: int = 0) -> Dictionary:
	return {"id": id, "pos": pos, "on_ground": on_ground, "state": state, "spawn_id": spawn_id}


func test_landing_intensity_follows_fall_speed() -> void:
	var c := GameConfig.new()
	var drop := c.dust_full_fall_speed * SimTime.TICK_DT
	var e := ViewEvents.detect([_f(0, Vector3(0, drop, 0), false)], [_f(0, Vector3.ZERO, true)], c)
	assert_eq(e.size(), 1)
	assert_eq(e[0]["type"], "landed")
	assert_almost_eq(float(e[0]["intensity"]), 1.0, 0.001)


func test_soft_landing_makes_no_dust() -> void:
	var c := GameConfig.new()
	var drop := c.dust_min_fall_speed * 0.5 * SimTime.TICK_DT
	assert_eq(ViewEvents.detect([_f(0, Vector3(0, drop, 0), false)], [_f(0, Vector3.ZERO, true)], c).size(), 0)


func test_respawn_is_a_spawn_id_change() -> void:
	var e := ViewEvents.detect([_f(0, Vector3(0, -9, 0), false, Fighter.State.AIR, 1)],
			[_f(0, Vector3(0, 6, 0), false, Fighter.State.AIR, 2)], GameConfig.new())
	assert_eq(e.size(), 1)
	assert_eq(e[0]["type"], "respawned")
	assert_eq(e[0]["pos"], Vector3(0, 6, 0))


func test_fast_launch_leaves_a_trail() -> void:
	var c := GameConfig.new()
	var step := c.trail_speed_full * SimTime.TICK_DT
	var e := ViewEvents.detect([_f(1, Vector3.ZERO, false, Fighter.State.HITSTUN)],
			[_f(1, Vector3(step, 0, 0), false, Fighter.State.HITSTUN)], c)
	assert_eq(e.size(), 1)
	assert_eq(e[0]["type"], "trail")
	assert_almost_eq(float(e[0]["intensity"]), 1.0, 0.001)


func test_running_is_not_a_trail() -> void:
	var c := GameConfig.new()
	var step := c.trail_speed_full * SimTime.TICK_DT
	var e := ViewEvents.detect([_f(1, Vector3.ZERO, true, Fighter.State.MOVE)],
			[_f(1, Vector3(step, 0, 0), true, Fighter.State.MOVE)], c)
	assert_eq(e.size(), 0, "trails are for launched fighters only")


func test_intensity_ramps() -> void:
	var c := GameConfig.new()
	assert_eq(ViewEvents.trail_intensity(c.trail_speed_threshold - 0.1, c), 0.0)
	assert_eq(ViewEvents.trail_intensity(c.trail_speed_full + 5.0, c), 1.0)
	var mid := (c.trail_speed_threshold + c.trail_speed_full) * 0.5
	assert_almost_eq(ViewEvents.trail_intensity(mid, c), 0.5, 0.001)


func test_takeoff_is_a_jump() -> void:
	var e := ViewEvents.detect([_f(0, Vector3.ZERO, true)], [_f(0, Vector3(0, 0.15, 0), false, Fighter.State.AIR)], GameConfig.new())
	assert_eq(e.size(), 1)
	assert_eq(e[0]["type"], "jumped")


func test_walking_off_an_edge_is_not_a_jump() -> void:
	var e := ViewEvents.detect([_f(0, Vector3.ZERO, true)], [_f(0, Vector3(0, -0.01, 0), false, Fighter.State.AIR)], GameConfig.new())
	assert_eq(e.size(), 0)
