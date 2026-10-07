extends GutTest


func _inputs(p1: InputFrame) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, InputFrame.neutral()]
	return a


func _run(w: World, p1: InputFrame, ticks: int) -> void:
	for i: int in ticks:
		w.tick(_inputs(p1))


func test_spawns_two_fighters_facing_each_other() -> void:
	var w := World.new(GameConfig.new(), 1)
	assert_eq(w.fighters.size(), 2)
	assert_almost_eq(w.fighters[0].pos.x, -5.0, 0.0001)
	assert_almost_eq(w.fighters[1].pos.x, 5.0, 0.0001)
	assert_almost_eq(w.fighters[0].facing.x, 1.0, 0.0001)
	assert_almost_eq(w.fighters[1].facing.x, -1.0, 0.0001)
	assert_eq(w.fighters[0].stocks, 3)


func test_walks_at_move_speed_and_turns() -> void:
	var w := World.new(GameConfig.new(), 1)
	_run(w, InputFrame.make(0.0, 1.0), 60)
	var f := w.fighters[0]
	assert_almost_eq(f.pos.z, 6.0, 0.01, "move_speed 6 for one second")
	assert_eq(f.pos.y, 0.0)
	assert_true(f.on_ground)
	assert_almost_eq(f.facing.z, 1.0, 0.0001)
	assert_eq(f.state, Fighter.State.MOVE)


func test_jump_rises_lands_and_restores_jumps() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	assert_gt(w.fighters[0].pos.y, 0.0)
	assert_eq(w.fighters[0].jumps_left, c.max_jumps - 1)
	var peak := 0.0
	for i: int in 90:
		w.tick(_inputs(InputFrame.neutral()))
		peak = maxf(peak, w.fighters[0].pos.y)
	# v^2 / 2g = 81 / 50 = 1.62 (discrete integration lands slightly under)
	assert_almost_eq(peak, 1.62, 0.1)
	assert_true(w.fighters[0].on_ground)
	assert_eq(w.fighters[0].jumps_left, c.max_jumps)
	assert_eq(w.fighters[0].state, Fighter.State.IDLE)


func test_double_jump_once_then_no_more() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	_run(w, InputFrame.neutral(), 10)
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	assert_eq(w.fighters[0].jumps_left, 0)
	assert_gt(w.fighters[0].vel.y, 8.0, "second jump resets vertical speed")
	_run(w, InputFrame.neutral(), 5)
	var vy_before := w.fighters[0].vel.y
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	assert_lt(w.fighters[0].vel.y, vy_before, "third press does nothing; gravity keeps pulling")


func test_walking_off_the_edge_falls() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[0].pos = Vector3(-c.arena_radius + 0.2, 0, 0)
	_run(w, InputFrame.make(-1.0, 0.0), 20)  # off the edge and falling, not yet out at kill_y
	var f := w.fighters[0]
	assert_lt(f.pos.y, 0.0)
	assert_false(f.on_ground)
	assert_eq(f.state, Fighter.State.AIR)
	assert_true(f.jumps_left <= c.max_jumps - 1, "walking off costs the ground jump")


func test_airborne_momentum_is_kept_without_input() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var f := w.fighters[0]
	f.pos = Vector3(0, 3, 0)
	f.vel = Vector3(7, 0, 0)
	f.on_ground = false
	f.set_state(Fighter.State.AIR)
	w.tick(_inputs(InputFrame.neutral()))
	assert_almost_eq(f.vel.x, 7.0 - c.air_drag * SimTime.TICK_DT, 0.0001, "only light drag, no snap to zero")


func test_below_floor_does_not_snap_back_up() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[0].pos = Vector3(0, -1.0, 0)
	w.fighters[0].on_ground = false
	w.fighters[0].set_state(Fighter.State.AIR)
	w.tick(_inputs(InputFrame.neutral()))
	assert_lt(w.fighters[0].pos.y, -1.0, "under the floor keeps falling")


func test_overlapping_fighters_are_pushed_apart() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[0].pos = Vector3(0, 0, 0)
	w.fighters[1].pos = Vector3(0.3, 0, 0)
	w.tick(_inputs(InputFrame.neutral()))
	var d := Vector2(w.fighters[1].pos.x - w.fighters[0].pos.x, w.fighters[1].pos.z - w.fighters[0].pos.z).length()
	assert_almost_eq(d, c.fighter_radius * 2.0, 0.001)


func test_state_view_lists_fighters_as_values() -> void:
	var w := World.new(GameConfig.new(), 1)
	var view := w.state_view()
	var fighters: Array = view["fighters"]
	assert_eq(fighters.size(), 2)
	assert_eq(view["arena_radius"], 10.0)
	assert_false(view["match_over"])
	w.fighters[0].pos = Vector3(3, 3, 3)
	assert_almost_eq((fighters[0] as Dictionary)["pos"].x, -5.0, 0.0001)


func test_snapshot_restore_mid_movement_continues_identically() -> void:
	var a := World.new(GameConfig.new(), 5)
	_run(a, InputFrame.make(0.5, 0.5, true), 20)
	var snap := a.snapshot()
	var b := World.new(a.config, 5)
	assert_true(b.restore(snap))
	for i: int in 30:
		var input := InputFrame.make(-0.2, 1.0, i == 7)
		a.tick(_inputs(input))
		b.tick(_inputs(input))
	assert_eq(b.state_hash(), a.state_hash())


func test_restore_rejects_config_mismatch() -> void:
	var a := World.new(GameConfig.new(), 1)
	var snap := a.snapshot()
	var other := GameConfig.new()
	other.move_speed = 7.0
	var b := World.new(other, 1)
	assert_false(b.restore(snap))
	assert_push_error("config mismatch")


func test_hash_changes_when_config_changes() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var before := w.state_hash()
	c.light_damage = 6.0
	assert_ne(w.state_hash(), before, "config is a tracked sim input (D1)")
