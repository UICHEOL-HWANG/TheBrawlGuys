extends GutTest
## Light combo (context E1, E2): link, link, finisher; a press inside the buffer chains.


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


func _light() -> InputFrame:
	return InputFrame.make(0, 0, false, true)


## P2 stands 1.0 m in front of P1, inside the light hitbox.
func _adjacent_world() -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	return w


func _total(c: GameConfig) -> int:
	return c.light_startup_ticks + c.light_active_ticks + c.light_recovery_ticks


## Ticks P1 through its current attack (no target nearby, so no hitstop) pressing light exactly
## when `remaining` ticks of the attack are left, then idles until the attack would end.
func _press_with_remaining(w: World, remaining: int) -> void:
	var total := _total(w.config)
	for t: int in range(1, total + 1):
		var left := total - t
		w.tick(_inputs(_light() if left == remaining else InputFrame.neutral()))


func test_single_press_is_one_link_hit() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_light()))
	assert_eq(w.fighters[0].state, Fighter.State.ATTACK)
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.LIGHT_1)


func test_press_inside_buffer_chains_second_hit() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_light()))
	_press_with_remaining(w, w.config.combo_buffer_ticks)
	assert_eq(w.fighters[0].state, Fighter.State.ATTACK)
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.LIGHT_2, "a press with exactly buffer ticks left chains")
	assert_eq(w.fighters[0].attack_ticks, 0, "the next hit starts on the tick the first one ends")


func test_press_outside_buffer_is_dropped() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_light()))
	_press_with_remaining(w, w.config.combo_buffer_ticks + 1)
	assert_eq(w.fighters[0].state, Fighter.State.IDLE, "an early press does not queue the next hit")


func test_third_hit_does_not_chain_further() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_light()))
	_press_with_remaining(w, 0)
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.LIGHT_2)
	_press_with_remaining(w, 0)
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.LIGHT_3)
	_press_with_remaining(w, 0)
	assert_eq(w.fighters[0].state, Fighter.State.IDLE, "after the finisher the combo resets")


func test_link_hit_keeps_target_close_and_stunned() -> void:
	var w := _adjacent_world()
	w.tick(_inputs(_light()))
	for i: int in w.config.light_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral()))
	var target := w.fighters[1]
	assert_eq(target.state, Fighter.State.HITSTUN)
	assert_eq(target.damage, w.config.light_link_damage)
	assert_gte(target.hitstun_ticks, w.config.light_link_hitstun_ticks, "hitstun floor from the link hit")
	assert_eq(target.vel.y, 0.0, "link hits are flat (launch angle 0)")


func test_full_combo_lands_three_hits() -> void:
	var w := _adjacent_world()
	var hits := 0
	for t: int in 120:
		var attacker := w.fighters[0]
		var mashing := t == 0 or (attacker.state == Fighter.State.ATTACK and AttackSet.is_light_chainable(attacker.attack_kind))
		w.tick(_inputs(_light() if mashing else InputFrame.neutral()))
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "hit":
				hits += 1
	var c := w.config
	assert_eq(hits, 3, "link, link, finisher all connect from 0%")
	assert_eq(w.fighters[1].damage, c.light_link_damage * 2.0 + c.light_damage)
