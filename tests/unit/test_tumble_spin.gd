extends GutTest
## TumbleSpin (polish-pass 7): a tumbling launch flips the drawn body backward about its
## middle, freezes with hitstop and stands upright again after a landing or a respawn.


func test_a_tumbling_launch_flips_backward_and_lands_upright() -> void:
	var angle := 0.0
	for i: int in 10:
		angle = TumbleSpin.step(angle, true, 1.0 / 60.0)
	assert_lt(angle, -0.5, "head over heels, backward")
	for i: int in 30:
		angle = TumbleSpin.step(angle, false, 1.0 / 60.0)
	assert_almost_eq(wrapf(angle, -PI, PI), 0.0, 0.0001, "upright again once the tumble ends")


func test_the_tumble_turns_about_the_body_center() -> void:
	var model := CharacterModel.new()
	add_child_autofree(model)
	if not model.setup(CharacterCatalog.CHARACTERS[0], GameConfig.new()):
		pending("no KayKit model")
		return
	var center := model.body_center()
	model.set_tumble(PI)
	assert_true(model.body_center().is_equal_approx(center), "spins in place, not around the feet")
	model.set_tumble(0.0)
	assert_almost_eq(model.foot_y(), 0.0, 0.01, "feet back on the ground")


func test_only_an_airborne_tumble_spins() -> void:
	assert_true(TumbleSpin.spinning({"state": Fighter.State.HITSTUN, "on_ground": false, "tumbling": true}))
	assert_true(TumbleSpin.spinning({"state": Fighter.State.AIR, "on_ground": false, "tumbling": true}))
	assert_false(TumbleSpin.spinning({"state": Fighter.State.HITSTUN, "on_ground": false, "tumbling": false}))
	assert_false(TumbleSpin.spinning({"state": Fighter.State.KNOCKDOWN, "on_ground": true, "tumbling": true}))


func test_hitstop_freezes_the_flip_and_a_respawn_stands_upright() -> void:
	var model := CharacterModel.new()
	add_child_autofree(model)
	if not model.setup(CharacterCatalog.CHARACTERS[0], GameConfig.new()):
		pending("no KayKit model")
		return
	var flying := {"state": Fighter.State.HITSTUN, "on_ground": false, "tumbling": true, "spawn_id": 0, "hitstop_ticks": 0}
	for i: int in 5:
		model.follow_tumble(flying, 1.0 / 60.0)
	var mid := model.body_center()
	var turned := (model.get_child(0) as Node3D).transform
	flying["hitstop_ticks"] = 4
	model.follow_tumble(flying, 1.0 / 60.0)
	assert_true((model.get_child(0) as Node3D).transform.is_equal_approx(turned), "frozen on the impact")
	model.follow_tumble({"state": Fighter.State.IDLE, "on_ground": true, "spawn_id": 1}, 1.0 / 60.0)
	assert_almost_eq(model.foot_y(), 0.0, 0.01, "respawned standing")
	# merged bounds of turned meshes widen a little; a spin about the feet would move it ~0.7 m
	assert_lt(model.body_center().distance_to(mid), 0.15, "spun about the middle, not the feet")
