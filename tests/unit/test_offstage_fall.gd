extends GutTest
## arena-ringout A2: a body that has dropped past the floor lip leans into its fall and flails,
## and is drawn on the meadow instead of sinking into it (OffstageFall, FallPose).

const DT := 1.0 / 60.0


func _view(y: float, state: int = Fighter.State.AIR, on_ground: bool = false, tumbling: bool = false) -> Dictionary:
	return {"pos": Vector3(12, y, 0), "state": state, "on_ground": on_ground, "tumbling": tumbling,
		"hitstop_ticks": 0, "spawn_id": 1}


func test_only_a_body_below_the_lip_is_falling_off() -> void:
	assert_false(OffstageFall.falling(_view(0.5)), "a jump above the floor is not a fall off")
	assert_false(OffstageFall.falling(_view(-0.1)), "just under the lip may still land")
	assert_true(OffstageFall.falling(_view(-0.6)))
	assert_false(OffstageFall.falling(_view(-0.6, Fighter.State.IDLE, true)), "standing is not falling")
	assert_false(OffstageFall.falling(_view(-0.6, Fighter.State.HITSTUN, false, true)), "a tumble spins instead")
	assert_false(OffstageFall.falling(_view(-0.6, Fighter.State.KO)))


func test_a_walk_off_leans_forward_a_hit_leans_back() -> void:
	var fwd := 0.0
	var back := 0.0
	for i: int in 60:
		fwd = OffstageFall.lean(fwd, _view(-1.0), DT)
		back = OffstageFall.lean(back, _view(-1.0, Fighter.State.HITSTUN), DT)
	assert_almost_eq(fwd, OffstageFall.LEAN, 0.001, "head first over the edge")
	assert_almost_eq(back, -OffstageFall.LEAN, 0.001, "knocked off: falls backward")


func test_the_lean_eases_in_and_rights_itself_after() -> void:
	var a := OffstageFall.lean(0.0, _view(-1.0), DT)
	assert_between(a, 0.0001, OffstageFall.LEAN * 0.5, "eases in, no pop")
	for i: int in 60:
		a = OffstageFall.lean(a, _view(-1.0), DT)
	for i: int in 60:
		a = OffstageFall.lean(a, _view(0.0, Fighter.State.IDLE, true), DT)
	assert_eq(a, 0.0, "back upright once it is not falling off")


func test_hitstop_freezes_the_lean() -> void:
	var v := _view(-1.0)
	v["hitstop_ticks"] = 3
	assert_eq(OffstageFall.lean(0.2, v, DT), 0.2)


func test_flail_only_while_leaning() -> void:
	assert_eq(OffstageFall.flail(0.0, 1.3), 0.0)
	var most := 0.0
	for i: int in 60:
		most = maxf(most, absf(OffstageFall.flail(OffstageFall.LEAN, i * DT)))
	assert_almost_eq(most, OffstageFall.FLAIL, OffstageFall.FLAIL * 0.1)


func test_the_view_is_held_on_the_meadow_and_leans() -> void:
	var c := GameConfig.new()
	var view := FighterView.new()
	add_child_autofree(view)
	view.setup(0, c, "barbarian")
	var pose := FallPose.new()
	view.position = Vector3(12, -1.6, 0)
	for i: int in 30:
		pose.follow(view, _view(-1.6), DT)
	assert_eq(view.position.y, DecorView.GROUND_Y, "drawn on the meadow, not in it")
	assert_gt(pose.lean(), 0.5, "leaning into the fall")
	assert_almost_eq(view.model().rotation.x, pose.lean(), 0.001, "the model tips over its feet")


func test_a_respawn_starts_upright() -> void:
	var c := GameConfig.new()
	var view := FighterView.new()
	add_child_autofree(view)
	view.setup(0, c, "barbarian")
	var pose := FallPose.new()
	for i: int in 30:
		pose.follow(view, _view(-1.0), DT)
	var back := _view(5.0)
	back["spawn_id"] = 2
	pose.follow(view, back, DT)
	assert_eq(pose.lean(), 0.0)


func test_a_tumble_takes_over_and_the_lean_rights_itself() -> void:
	var a := OffstageFall.LEAN
	for i: int in 30:
		a = OffstageFall.lean(a, _view(-1.0, Fighter.State.HITSTUN, false, true), DT)
	assert_eq(a, 0.0, "the tumble spin owns a tumbling body")


func test_hitstop_freezes_the_flail() -> void:
	var c := GameConfig.new()
	var view := FighterView.new()
	add_child_autofree(view)
	view.setup(0, c, "barbarian")
	var pose := FallPose.new()
	for i: int in 20:
		pose.follow(view, _view(-1.0), DT)
	var frozen := _view(-1.0)
	frozen["hitstop_ticks"] = 4
	var roll := view.model().rotation.z
	for i: int in 5:
		pose.follow(view, frozen, DT)
	assert_almost_eq(view.model().rotation.z, roll, 0.0001)


func test_the_ringout_comes_before_the_body_sinks_out_of_sight() -> void:
	var c := GameConfig.new()
	assert_lt(c.kill_y, DecorView.GROUND_Y, "below the meadow surface")
	var deepest_jump := 0.0
	for v: float in [c.jump_velocity, c.boxer_jump_velocity, c.weapon_jump_velocity, c.ranged_jump_velocity]:
		deepest_jump = maxf(deepest_jump, v * v / (-2.0 * c.gravity))
	assert_lt(c.kill_y, -deepest_jump, "every height a jump can still recover from stays in play")
