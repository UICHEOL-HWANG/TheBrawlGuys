extends GutTest
## DI (combat-depth C): the stick held when a launch's hitstop ends rotates the horizontal launch
## direction toward the stick's perpendicular side, by up to di_max_deg, in proportion to the
## perpendicular share of the stick. Speed is kept; parallel or neutral sticks change nothing.


func _cfg() -> GameConfig:
	return GameConfig.new()


func _flat_angle_deg(v: Vector3) -> float:
	return rad_to_deg(atan2(v.z, v.x))


func test_neutral_stick_changes_nothing() -> void:
	var v := Vector3(8, 4, 0)
	assert_eq(LaunchInfluence.rotate(v, Vector2.ZERO, _cfg()), v)


func test_parallel_stick_changes_nothing() -> void:
	var v := Vector3(8, 4, 0)
	assert_eq(LaunchInfluence.rotate(v, Vector2(1, 0), _cfg()), v, "with the launch")
	assert_eq(LaunchInfluence.rotate(v, Vector2(-1, 0), _cfg()), v, "against the launch")


func test_perpendicular_stick_rotates_by_the_max() -> void:
	var c := _cfg()
	var out := LaunchInfluence.rotate(Vector3(8, 4, 0), Vector2(0, 1), c)
	assert_almost_eq(_flat_angle_deg(out), c.di_max_deg, 0.01, "turned toward +z")
	assert_almost_eq(Vector2(out.x, out.z).length(), 8.0, 0.001, "horizontal speed kept")
	assert_eq(out.y, 4.0, "vertical speed kept")
	var other := LaunchInfluence.rotate(Vector3(8, 4, 0), Vector2(0, -1), c)
	assert_almost_eq(_flat_angle_deg(other), -c.di_max_deg, 0.01, "the other side turns the other way")


func test_rotation_follows_the_perpendicular_share() -> void:
	var c := _cfg()
	var out := LaunchInfluence.rotate(Vector3(0, 2, 6), Vector2(-1, 0) * 0.5, c)
	# launch along +z, stick half toward -x: half the max, turned toward -x
	assert_almost_eq(rad_to_deg(atan2(out.x, out.z)), -c.di_max_deg * 0.5, 0.01)
	var diag := Vector2(1, 1).normalized()
	var d := LaunchInfluence.rotate(Vector3(5, 0, 0), diag, c)
	assert_almost_eq(_flat_angle_deg(d), c.di_max_deg * diag.y, 0.01)


func test_straight_up_launch_is_untouched() -> void:
	var v := Vector3(0, 9, 0)
	assert_eq(LaunchInfluence.rotate(v, Vector2(0, 1), _cfg()), v)


func test_stick_held_through_hitstop_bends_a_real_launch() -> void:
	var straight := _launched_x(Vector2.ZERO)
	var bent := _launched_x(Vector2(0, 1))
	assert_almost_eq(straight.z, 0.0, 0.0001, "no DI: straight along +x")
	assert_gt(bent.z, 0.0, "DI toward +z bends the flight")
	assert_almost_eq(Vector2(bent.x, bent.z).length(), Vector2(straight.x, straight.z).length(), 0.001)


## P2 is launched along +x by a heavy hit while holding `stick`; returns its velocity on the first
## tick after the hitstop.
func _launched_x(stick: Vector2) -> Vector3:
	var w := World.new(GameConfig.new(), 1)
	var t := w.fighters[1]
	t.pos = Vector3(0, 0, 0)
	w.fighters[0].pos = Vector3(-6, 0, 0)
	var attack := AttackData.make(12.0, 8.0, 0.1, 0.7, 0, 1, 0, w.config.hitstop_heavy)
	Combat.apply_hit(t, attack, Vector3(1, 0, 0), 1.0, w.config, t.pos, 0)
	var hold := InputFrame.make(stick.x, stick.y)
	for i: int in attack.hitstop_ticks + 1:
		w.tick([InputFrame.neutral(), hold] as Array[InputFrame])
	return t.vel
