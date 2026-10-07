extends GutTest
## Slippery ground (frozen pond, IceConfig, GroundGrip): on an ArenaData.slippery floor walking
## eases toward the stick at ice_ground_acceleration and slides (hitstun, knockdown, guard push)
## lose ice_slide_friction of their speed per tick; every other arena keeps the snap exactly.

const FAR_AWAY := Vector3(0, 0, 8)


func _world(slippery: bool) -> World:
	var c := GameConfig.new()
	var a := ArenaCatalog.build("lakeside_camp", c)
	a.slippery = slippery
	var w := World.new(c, 1, 2, a)
	w.fighters[1].pos = FAR_AWAY  # out of the walking lane
	return w


func _walk(w: World, mx: float, ticks: int) -> void:
	for i: int in ticks:
		var inputs: Array[InputFrame] = [InputFrame.make(mx, 0.0), InputFrame.neutral()]
		w.tick(inputs)


func _speed(w: World) -> float:
	return Vector2(w.fighters[0].vel.x, w.fighters[0].vel.z).length()


func test_ice_defaults_are_a_sim_group() -> void:
	var c := GameConfig.new()
	assert_eq(c.ice_ground_acceleration, 14.0)
	assert_eq(c.ice_slide_friction, 0.95)
	assert_true(GameConfig.SIM_GROUPS.has("Ice"), "ice changes replays")
	var other := GameConfig.new()
	other.ice_slide_friction = 0.9
	assert_ne(c.fingerprint(), other.fingerprint())


func test_normal_ground_still_snaps_to_the_stick() -> void:
	var w := _world(false)
	_walk(w, 1.0, 1)
	var full := w.config.move_speed
	assert_eq(w.fighters[0].vel.x, full, "full speed on the first tick")
	_walk(w, 0.0, 1)
	assert_eq(_speed(w), 0.0, "stops dead")


func test_ice_speeds_up_and_slows_down_gradually() -> void:
	var w := _world(true)
	var step := w.config.ice_ground_acceleration * SimTime.TICK_DT
	_walk(w, 1.0, 1)
	assert_almost_eq(w.fighters[0].vel.x, step, 0.0001, "one tick of acceleration")
	_walk(w, 1.0, 120)
	assert_almost_eq(_speed(w), w.config.move_speed, 0.0001, "reaches full speed")
	_walk(w, 0.0, 1)
	assert_almost_eq(_speed(w), w.config.move_speed - step, 0.0001, "keeps sliding after letting go")
	_walk(w, 0.0, 120)
	assert_eq(_speed(w), 0.0, "comes to rest")


func test_knockback_slides_farther_on_ice() -> void:
	var slid := []
	for slippery: bool in [false, true]:
		var w := _world(slippery)
		var f := w.fighters[0]
		f.set_state(Fighter.State.HITSTUN)
		f.hitstun_ticks = 30
		f.vel = Vector3(8.0, 0.0, 0.0)
		var from := f.pos.x
		_walk(w, 0.0, 30)
		slid.append(f.pos.x - from)
	assert_gt(slid[1], slid[0] * 2.0, "the ice slide is much longer")


func test_copy_keeps_slippery() -> void:
	var a := ArenaData.new()
	assert_false(a.slippery, "plain floors grip")
	a.slippery = true
	assert_true(a.copy().slippery)


func test_bots_look_a_skid_further_ahead_on_ice() -> void:
	var c := GameConfig.new()
	var nav := BotNav.new(c)
	var ice := ArenaData.new()
	ice.slippery = true
	assert_eq(nav.lookahead(ArenaData.new()), c.bot_ground_lookahead, "grippy floors: unchanged")
	var skid := c.move_speed * c.move_speed / (2.0 * c.ice_ground_acceleration)
	assert_almost_eq(nav.lookahead(ice), c.bot_ground_lookahead + skid, 0.0001)
