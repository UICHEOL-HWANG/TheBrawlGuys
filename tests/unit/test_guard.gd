extends GutTest
## Guard (context E4). PHASES test: a guarded hit deals 20% damage and 0 knockback.


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


func _guard(mx: float = 0.0) -> InputFrame:
	return InputFrame.make(mx, 0, false, false, false, true)


## P2 guards 1.0 m in front of P1.
func _guarding_world(config: GameConfig = null) -> World:
	var w := World.new(config if config != null else GameConfig.new(), 1)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.tick(_inputs(InputFrame.neutral(), _guard()))
	return w


## P1 presses `press` once; both sides keep their inputs until the swing's startup has passed.
func _swing(w: World, press: InputFrame, ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	w.tick(_inputs(press, _guard()))
	for i: int in ticks:
		w.tick(_inputs(InputFrame.neutral(), _guard()))
		for e: Dictionary in w.state_view()["events"]:
			events.append(e)
	return events


func test_guard_holds_in_place() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_guard()))
	var start := w.fighters[0].pos
	for i: int in 10:
		w.tick(_inputs(_guard(1.0)))
	assert_eq(w.fighters[0].state, Fighter.State.GUARD)
	assert_eq(w.fighters[0].pos, start, "no movement while guarding")


func test_release_returns_to_idle() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_guard()))
	w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].state, Fighter.State.IDLE)


func test_no_guard_in_the_air() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	w.tick(_inputs(_guard()))
	assert_eq(w.fighters[0].state, Fighter.State.AIR)


func test_guard_beats_heavy_and_light_priority() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(InputFrame.make(0, 0, false, true, true, true)))
	assert_eq(w.fighters[0].state, Fighter.State.GUARD)


func test_guarded_hit_deals_20_percent_and_no_knockback() -> void:
	var w := _guarding_world()
	var events := _swing(w, InputFrame.make(0, 0, false, true), w.config.light_startup_ticks + 1)
	var target := w.fighters[1]
	assert_almost_eq(target.damage, w.config.light_link_damage * 0.2, 0.0001)
	assert_eq(target.state, Fighter.State.GUARD, "no hitstun through a guard")
	assert_eq(Vector2(target.vel.x, target.vel.z), Vector2.ZERO)
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "guard_hit")
	assert_eq(events[0]["knockback"], 0.0)


func test_guarded_hit_still_hitstops_both() -> void:
	var w := _guarding_world()
	w.tick(_inputs(InputFrame.make(0, 0, false, true), _guard()))
	for i: int in w.config.light_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral(), _guard()))
	var stop := SimTime.to_ticks(w.config.hitstop_light)
	assert_eq(w.fighters[0].hitstop_ticks, stop)
	assert_eq(w.fighters[1].hitstop_ticks, stop)


func test_guarded_heavy_uses_guard_damage_mul() -> void:
	var w := _guarding_world()
	_swing(w, InputFrame.make(0, 0, false, false, true), 1)
	_swing(w, InputFrame.neutral(), w.config.heavy_startup_ticks + 1)
	assert_almost_eq(w.fighters[1].damage, w.config.heavy_damage * 0.2, 0.0001)


func test_guard_knockback_mul_pushes_back_without_breaking_guard() -> void:
	var c := GameConfig.new()
	c.guard_knockback_mul = 0.5
	var w := _guarding_world(c)
	_swing(w, InputFrame.make(0, 0, false, true), c.light_startup_ticks + 1 + SimTime.to_ticks(c.hitstop_light) + 10)
	assert_eq(w.fighters[1].state, Fighter.State.GUARD)
	assert_gt(w.fighters[1].pos.x, w.fighters[0].pos.x + 1.0, "pushed away along the attacker's facing")


func test_apply_hit_uses_the_given_direction() -> void:
	var c := GameConfig.new()
	var target := Fighter.new()
	var rock := AttackSet.from_config(c).get_attack(AttackSet.Kind.ROCK)
	var e := Combat.apply_hit(target, rock, Vector3(0, 0, -1), 1.0, c, Vector3.ZERO, 3)
	assert_eq(e["type"], "hit")
	assert_eq(e["attacker"], 3)
	assert_lt(target.vel.z, 0.0)
	assert_almost_eq(target.vel.x, 0.0, 0.0001)
	assert_eq(target.state, Fighter.State.HITSTUN)
