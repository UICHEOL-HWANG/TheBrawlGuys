extends GutTest


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


## P2 stands 1.0 m in front of P1 (inside the light hitbox).
func _adjacent_world(config: GameConfig = null) -> World:
	var w := World.new(config if config != null else GameConfig.new(), 1)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	return w


## Presses light on the first tick, then idles until the hit lands (startup + 2 ticks).
func _swing_until_hit(w: World) -> void:
	w.tick(_inputs(InputFrame.make(0, 0, false, true)))
	for i: int in w.config.light_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral()))


func test_knockback_formula_at_0_50_150_percent() -> void:
	var c := GameConfig.new()
	c.global_knockback_mul = 1.0  # formula check is independent of the tuned default
	var a := AttackData.light_from(c)
	assert_almost_eq(Combat.knockback(a, 0.0, c), 3.0, 0.0001)
	assert_almost_eq(Combat.knockback(a, 50.0, c), 5.5, 0.0001)
	assert_almost_eq(Combat.knockback(a, 150.0, c), 10.5, 0.0001)
	c.global_knockback_mul = 2.0
	assert_almost_eq(Combat.knockback(a, 150.0, c), 21.0, 0.0001)


func test_hitstun_scales_with_knockback() -> void:
	var c := GameConfig.new()
	assert_eq(Combat.hitstun_ticks(10.5, c), 25, "10.5 * 0.04 s = 0.42 s = 25.2 ticks")
	assert_eq(Combat.hitstun_ticks(0.0, c), 0)


func test_launch_velocity_direction_and_speed() -> void:
	var a := AttackData.light_from(GameConfig.new())
	var v := Combat.launch_velocity(Vector3(1, 0, 0), a, 10.0)
	assert_almost_eq(v.length(), 10.0, 0.0001)
	assert_almost_eq(v.y / v.x, a.launch_angle_y, 0.0001)
	assert_eq(v.z, 0.0)


func test_first_light_is_a_link_hit_after_startup() -> void:
	var w := _adjacent_world()
	_swing_until_hit(w)
	var target := w.fighters[1]
	var link := AttackSet.from_config(w.config).get_attack(AttackSet.Kind.LIGHT_1)
	assert_eq(target.damage, w.config.light_link_damage)
	assert_eq(target.state, Fighter.State.HITSTUN)
	var events: Array = w.state_view()["events"]
	assert_eq(events.size(), 1)
	var e: Dictionary = events[0]
	assert_eq(e["type"], "hit")
	assert_eq(e["attacker"], 0)
	assert_eq(e["target"], 1)
	assert_eq(e["attack_kind"], AttackSet.Kind.LIGHT_1)
	assert_almost_eq(e["knockback"], Combat.knockback(link, w.config.light_link_damage, w.config), 0.0001)


func test_hitstop_freezes_both_then_target_flies() -> void:
	var w := _adjacent_world()
	_swing_until_hit(w)
	var stop := AttackData.light_from(w.config).hitstop_ticks
	assert_eq(w.fighters[0].hitstop_ticks, stop)
	assert_eq(w.fighters[1].hitstop_ticks, stop)
	var p1_at_hit := w.fighters[0].pos
	var p2_at_hit := w.fighters[1].pos
	for i: int in stop:
		w.tick(_inputs(InputFrame.make(1, 0), InputFrame.make(-1, 0)))
	assert_eq(w.fighters[0].pos, p1_at_hit, "attacker frozen during hitstop")
	assert_eq(w.fighters[1].pos, p2_at_hit, "target frozen during hitstop")
	w.tick(_inputs(InputFrame.neutral()))
	assert_gt(w.fighters[1].pos.x, p2_at_hit.x, "knocked away along attacker facing")


func test_hitstun_ignores_movement_input() -> void:
	var w := _adjacent_world()
	_swing_until_hit(w)
	var stop := AttackData.light_from(w.config).hitstop_ticks
	for i: int in stop + 3:
		w.tick(_inputs(InputFrame.neutral(), InputFrame.make(-1, 0)))
	assert_eq(w.fighters[1].state, Fighter.State.HITSTUN)
	assert_gt(w.fighters[1].vel.x, 0.0, "input -x does not override knockback")


func test_one_hit_per_swing() -> void:
	var w := _adjacent_world()
	_swing_until_hit(w)
	for i: int in 20:
		w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[1].damage, w.config.light_link_damage)


func test_invulnerable_target_is_not_hit() -> void:
	var w := _adjacent_world()
	w.fighters[1].invuln_ticks = 100
	_swing_until_hit(w)
	assert_eq(w.fighters[1].damage, 0.0)
	assert_eq((w.state_view()["events"] as Array).size(), 0)


func test_facing_away_misses() -> void:
	var w := _adjacent_world()
	w.fighters[0].facing = Vector3(-1, 0, 0)
	_swing_until_hit(w)
	assert_eq(w.fighters[1].damage, 0.0)


func test_attack_returns_to_idle_after_total_ticks() -> void:
	var w := World.new(GameConfig.new(), 1)
	var total := AttackData.light_from(w.config).total_ticks()
	var a: Array[InputFrame] = [InputFrame.make(0, 0, false, true), InputFrame.neutral()]
	w.tick(a)
	assert_eq(w.fighters[0].state, Fighter.State.ATTACK)
	var idle: Array[InputFrame] = [InputFrame.neutral(), InputFrame.neutral()]
	for i: int in total:
		w.tick(idle)
	assert_eq(w.fighters[0].state, Fighter.State.IDLE, "attack ends after startup + active + recovery")
