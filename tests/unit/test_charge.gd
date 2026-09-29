extends GutTest
## Heavy attack charge (context E3). PHASES test: 0 / 0.5 / 1.0 / 1.5 s -> 1.0 / 1.3 / 1.6 / 1.6.


func _inputs(p1: InputFrame) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, InputFrame.neutral()]
	return a


func _heavy() -> InputFrame:
	return InputFrame.make(0, 0, false, false, true)


func test_charge_multiplier_curve() -> void:
	var c := GameConfig.new()
	assert_almost_eq(Actions.charge_mul(SimTime.to_ticks(0.0), c), 1.0, 0.0001)
	assert_almost_eq(Actions.charge_mul(SimTime.to_ticks(0.5), c), 1.3, 0.0001)
	assert_almost_eq(Actions.charge_mul(SimTime.to_ticks(1.0), c), 1.6, 0.0001)
	assert_almost_eq(Actions.charge_mul(SimTime.to_ticks(1.5), c), 1.6, 0.0001, "capped at the max charge")


func test_holding_heavy_charges_in_place() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_heavy()))
	var f := w.fighters[0]
	assert_eq(f.state, Fighter.State.CHARGE)
	var start := f.pos
	for i: int in 20:
		w.tick(_inputs(InputFrame.make(1, 0, false, false, true)))
	assert_eq(f.state, Fighter.State.CHARGE)
	assert_eq(f.charge_ticks, 20)
	assert_eq(f.pos, start, "charging on the ground does not move, even with a move input")


func test_charge_ticks_cap_at_max_time() -> void:
	var w := World.new(GameConfig.new(), 1)
	for i: int in 200:
		w.tick(_inputs(_heavy()))
	assert_eq(w.fighters[0].charge_ticks, SimTime.to_ticks(w.config.heavy_charge_max_time))


func test_release_fires_heavy_with_the_charge_multiplier() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_heavy()))
	for i: int in 30:
		w.tick(_inputs(_heavy()))
	w.tick(_inputs(InputFrame.neutral()))
	var f := w.fighters[0]
	assert_eq(f.state, Fighter.State.ATTACK)
	assert_eq(f.attack_kind, AttackSet.Kind.HEAVY)
	assert_almost_eq(f.charge_mul, 1.3, 0.0001)


func test_one_tick_tap_is_an_uncharged_heavy() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(_heavy()))
	w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.HEAVY)
	assert_eq(w.fighters[0].charge_mul, 1.0)


func test_heavy_takes_priority_over_light() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.tick(_inputs(InputFrame.make(0, 0, false, true, true)))
	assert_eq(w.fighters[0].state, Fighter.State.CHARGE)


func test_charged_heavy_scales_damage_and_knockback() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.tick(_inputs(_heavy()))
	for i: int in 30:
		w.tick(_inputs(_heavy()))
	w.tick(_inputs(InputFrame.neutral()))
	var hit: Dictionary = {}
	for i: int in c.heavy_startup_ticks + 2:
		w.tick(_inputs(InputFrame.neutral()))
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "hit":
				hit = e
	assert_false(hit.is_empty(), "the heavy lands after its startup")
	var heavy := AttackSet.from_config(c).get_attack(AttackSet.Kind.HEAVY)
	var dmg := c.heavy_damage * 1.3
	assert_almost_eq(w.fighters[1].damage, dmg, 0.0001)
	assert_almost_eq(hit["power"], 1.3, 0.0001)
	assert_almost_eq(hit["knockback"], Combat.knockback(heavy, dmg, c) * 1.3, 0.0001)
