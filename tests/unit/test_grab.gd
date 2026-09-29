extends GutTest
## Grab -> hold -> throw (context E5).


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


func _grab(mx: float = 0.0, mz: float = 0.0) -> InputFrame:
	return InputFrame.make(mx, mz, false, false, false, false, true)


## P2 stands 1.0 m in front of P1; P1 grabs and the hold is established.
func _holding_world(p2_input: InputFrame = null) -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	var p2 := p2_input if p2_input != null else InputFrame.neutral()
	w.tick(_inputs(_grab(), p2))
	for i: int in w.config.grab_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral(), p2))
	return w


func test_grab_press_starts_a_grab_attempt_on_the_ground() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_grab()))
	assert_eq(w.fighters[0].state, Fighter.State.ATTACK)
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.GRAB)


func test_no_grab_in_the_air() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	w.tick(_inputs(_grab()))
	assert_eq(w.fighters[0].state, Fighter.State.AIR)


func test_whiffed_grab_recovers_to_idle() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_grab()))
	var c := w.config
	for i: int in c.grab_startup_ticks + c.grab_active_ticks + c.grab_recovery_ticks:
		w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].state, Fighter.State.IDLE)


func test_grab_connects_into_hold() -> void:
	var w := _holding_world()
	var holder := w.fighters[0]
	var held := w.fighters[1]
	assert_eq(holder.state, Fighter.State.HOLDING)
	assert_eq(held.state, Fighter.State.HELD)
	assert_eq(holder.partner_id, 1)
	assert_eq(held.partner_id, 0)
	assert_eq(held.damage, 0.0, "the grab itself deals no damage")


func test_grab_ignores_guard() -> void:
	var w := _holding_world(InputFrame.make(0, 0, false, false, false, true))
	assert_eq(w.fighters[1].state, Fighter.State.HELD)


func test_holder_turns_and_carries_the_held_fighter() -> void:
	var w := _holding_world()
	w.tick(_inputs(InputFrame.make(0, 1)))
	var holder := w.fighters[0]
	var held := w.fighters[1]
	assert_eq(holder.facing, Vector3(0, 0, 1))
	assert_true(held.pos.is_equal_approx(holder.pos + Vector3(0, 0, w.config.grab_hold_distance)))
	assert_eq(held.state, Fighter.State.HELD)


func test_second_grab_press_throws_in_the_input_direction() -> void:
	var w := _holding_world()
	w.tick(_inputs(_grab(0, -1)))
	var holder := w.fighters[0]
	var held := w.fighters[1]
	assert_eq(held.state, Fighter.State.HITSTUN)
	assert_eq(held.damage, w.config.throw_damage)
	assert_eq(holder.partner_id, Fighter.NONE)
	assert_eq(held.partner_id, Fighter.NONE)
	assert_eq(holder.state, Fighter.State.IDLE)
	var thrown := false
	for e: Dictionary in w.state_view()["events"]:
		if e["type"] == "hit" and e["attack_kind"] == AttackSet.Kind.THROW:
			thrown = true
	assert_true(thrown)
	for i: int in SimTime.to_ticks(w.config.hitstop_heavy) + 1:
		w.tick(_inputs(InputFrame.neutral()))
	assert_lt(held.vel.z, 0.0, "thrown toward -z (the input at the throw)")


func test_hold_ends_by_itself() -> void:
	var w := _holding_world()
	var released := false
	for i: int in SimTime.to_ticks(w.config.grab_hold_max_time):
		w.tick(_inputs(InputFrame.neutral()))
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "grab_release":
				released = true
	assert_true(released)
	assert_eq(w.fighters[0].state, Fighter.State.IDLE)
	assert_eq(w.fighters[1].state, Fighter.State.IDLE)


func test_cleanup_frees_the_partner_of_a_hit_holder() -> void:
	var w := _holding_world()
	w.fighters[0].set_state(Fighter.State.HITSTUN)
	Grab.cleanup(w.fighters)
	assert_eq(w.fighters[1].state, Fighter.State.IDLE)
	assert_eq(w.fighters[1].partner_id, Fighter.NONE)
	assert_eq(w.fighters[0].partner_id, Fighter.NONE)


func test_holder_ring_out_frees_the_held_fighter() -> void:
	var w := _holding_world()
	w.fighters[0].pos = Vector3(0, w.config.kill_y - 1, 0)
	w.tick(_inputs(InputFrame.neutral()))
	assert_ne(w.fighters[1].state, Fighter.State.HELD)
	assert_eq(w.fighters[1].partner_id, Fighter.NONE)


func test_invulnerable_fighter_cannot_be_grabbed() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[1].invuln_ticks = 100
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.tick(_inputs(_grab()))
	for i: int in w.config.grab_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral()))
	assert_ne(w.fighters[1].state, Fighter.State.HELD)
