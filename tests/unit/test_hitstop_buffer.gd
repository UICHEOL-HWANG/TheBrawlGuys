extends GutTest
## Phase 3 carry-over: hitstop swallowed presses. A light / jump / grab press made while the
## fighter is frozen in hitstop must act on the first tick after the freeze, exactly once.


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


## P1 lands its first light hit on P2 standing 1 m in front; returns the world right after the hit.
func _hit_world() -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.tick(_inputs(InputFrame.make(0, 0, false, true)))
	for i: int in w.config.light_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral()))
	assert_gt(w.fighters[0].hitstop_ticks, 1, "attacker frozen by its hit")
	return w


func test_light_pressed_during_hitstop_still_chains_the_combo() -> void:
	var w := _hit_world()
	w.tick(_inputs(InputFrame.make(0, 0, false, true)))  # one-tick press inside the freeze
	var kinds := {}
	for i: int in 30:
		w.tick(_inputs(InputFrame.neutral()))
		if w.fighters[0].state == Fighter.State.ATTACK:
			kinds[w.fighters[0].attack_kind] = true
	assert_true(kinds.has(AttackSet.Kind.LIGHT_2), "the buffered press queues hit 2")


func test_buffered_press_is_used_once() -> void:
	var w := _hit_world()
	w.tick(_inputs(InputFrame.make(0, 0, true)))  # jump pressed inside the freeze
	while w.fighters[0].hitstop_ticks > 0:
		w.tick(_inputs(InputFrame.neutral()))
	assert_ne(w.fighters[0].held_presses, 0, "kept until the freeze ends")
	w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].held_presses, 0, "replayed on the first free tick")


func test_no_press_during_hitstop_changes_nothing() -> void:
	var w := _hit_world()
	for i: int in 10:
		w.tick(_inputs(InputFrame.neutral()))
		assert_eq(w.fighters[0].held_presses, 0)
