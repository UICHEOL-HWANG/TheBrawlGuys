extends GutTest


func _sample() -> Fighter:
	var f := Fighter.new()
	f.id = 1
	f.spawn_id = 2
	f.pos = Vector3(1, 2, 3)
	f.vel = Vector3(-1, 0, 4)
	f.facing = Vector3(1, 0, 0)
	f.set_state(Fighter.State.HITSTUN)
	f.damage = 42.5
	f.stocks = 2
	f.jumps_left = 1
	f.on_ground = false
	f.hitstun_ticks = 7
	f.hit_ids.assign([0, 3])
	f.attack_kind = AttackSet.Kind.HEAVY
	f.combo_queued = true
	f.charge_ticks = 12
	f.charge_mul = 1.3
	f.grab_ticks = 40
	f.partner_id = 0
	f.item_kind = 1
	f.item_uses = 3
	return f


func test_sim_time_to_ticks() -> void:
	assert_eq(SimTime.TICK_RATE, 60)
	assert_eq(SimTime.to_ticks(0.06), 4, "3.6 rounds to 4")
	assert_eq(SimTime.to_ticks(2.0), 120)
	assert_eq(SimTime.to_ticks(-1.0), 0)


func test_fixed_ticker_uses_sim_time() -> void:
	assert_eq(FixedTicker.TICK_RATE, SimTime.TICK_RATE)


func test_light_attack_from_config() -> void:
	var c := GameConfig.new()
	var a := AttackData.light_from(c)
	assert_eq(a.damage, 4.0)
	assert_eq(a.base_knockback, 3.0)
	assert_eq(a.knockback_scaling, 0.05)
	assert_eq(a.hitstop_ticks, SimTime.to_ticks(c.hitstop_light))
	assert_eq(a.hitbox_half, Vector3(c.light_hitbox_half_width, c.light_hitbox_half_height, c.light_hitbox_half_width))
	assert_eq(a.total_ticks(), c.light_startup_ticks + c.light_active_ticks + c.light_recovery_ticks)


func test_attack_active_window() -> void:
	var a := AttackData.new()
	a.startup_ticks = 3
	a.active_ticks = 2
	assert_false(a.is_active(3))
	assert_true(a.is_active(4))
	assert_true(a.is_active(5))
	assert_false(a.is_active(6))


func test_set_state_resets_ticks_only_on_change() -> void:
	var f := Fighter.new()
	f.state_ticks = 9
	f.set_state(Fighter.State.IDLE)
	assert_eq(f.state_ticks, 9, "same state keeps the counter")
	f.set_state(Fighter.State.AIR)
	assert_eq(f.state_ticks, 0)


func test_can_act_and_alive() -> void:
	var f := Fighter.new()
	for s: int in [Fighter.State.IDLE, Fighter.State.MOVE, Fighter.State.AIR]:
		f.set_state(s)
		assert_true(f.can_act())
	for s: int in [Fighter.State.ATTACK, Fighter.State.HITSTUN, Fighter.State.KO]:
		f.set_state(s)
		assert_false(f.can_act())
	assert_false(f.is_alive())


func test_data_round_trip() -> void:
	var f := _sample()
	var g := Fighter.from_data(f.to_data())
	assert_not_null(g)
	assert_eq(g.to_data(), f.to_data())


func test_from_data_rejects_missing_or_mistyped() -> void:
	var d := _sample().to_data()
	var missing := d.duplicate(true)
	missing.erase("stocks")
	assert_null(Fighter.from_data(missing))
	var mistyped := d.duplicate(true)
	mistyped["damage"] = "lots"
	assert_null(Fighter.from_data(mistyped))
	var bad_ids := d.duplicate(true)
	bad_ids["hit_ids"] = [0, "x"]
	assert_null(Fighter.from_data(bad_ids))


func test_to_view_is_a_copy() -> void:
	var f := _sample()
	var view := f.to_view()
	f.pos = Vector3(9, 9, 9)
	f.damage = 99.0
	assert_eq(view["pos"], Vector3(1, 2, 3))
	assert_eq(view["damage"], 42.5)
	assert_false(view.has("hit_ids"), "internal bookkeeping stays out of views")


func test_phase2_states_keep_phase1_values() -> void:
	assert_eq(Fighter.State.KO, 5, "HUD/bot/views compare against KO; its value must not move")
	assert_eq(Fighter.State.CHARGE, 6)
	assert_eq(Fighter.State.GUARD, 7)
	assert_eq(Fighter.State.HOLDING, 8)
	assert_eq(Fighter.State.HELD, 9)


func test_new_states_cannot_act() -> void:
	var f := Fighter.new()
	for s: int in [Fighter.State.CHARGE, Fighter.State.GUARD, Fighter.State.HOLDING, Fighter.State.HELD]:
		f.set_state(s)
		assert_false(f.can_act(), "state %d" % s)
		assert_true(f.is_alive())


func test_phase2_fields_default_to_empty() -> void:
	var f := Fighter.new()
	assert_eq(f.partner_id, Fighter.NONE)
	assert_eq(f.item_kind, Fighter.NONE)
	assert_eq(f.item_uses, 0)
	assert_eq(f.charge_mul, 1.0)


func test_view_exposes_phase2_fields() -> void:
	var view := _sample().to_view()
	assert_eq(view["attack_kind"], AttackSet.Kind.HEAVY)
	assert_eq(view["charge_ticks"], 12)
	assert_eq(view["partner_id"], 0)
	assert_eq(view["item_kind"], 1)
	assert_eq(view["item_uses"], 3)
	assert_false(view.has("combo_queued"), "input bookkeeping stays out of views")
