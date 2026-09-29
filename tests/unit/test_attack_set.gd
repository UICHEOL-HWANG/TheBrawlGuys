extends GutTest


func test_light_3_is_the_phase_1_light_attack() -> void:
	var c := GameConfig.new()
	var finisher := AttackSet.from_config(c).get_attack(AttackSet.Kind.LIGHT_3)
	var phase1 := AttackData.light_from(c)
	assert_eq(finisher.damage, phase1.damage)
	assert_eq(finisher.base_knockback, phase1.base_knockback)
	assert_eq(finisher.knockback_scaling, phase1.knockback_scaling)
	assert_eq(finisher.launch_angle_y, phase1.launch_angle_y)
	assert_eq(finisher.min_hitstun_ticks, 0)


func test_link_hits_are_small_flat_and_hold_hitstun() -> void:
	var c := GameConfig.new()
	var s := AttackSet.from_config(c)
	for kind: int in [AttackSet.Kind.LIGHT_1, AttackSet.Kind.LIGHT_2]:
		var a := s.get_attack(kind)
		assert_eq(a.damage, c.light_link_damage)
		assert_eq(a.base_knockback, c.light_link_base_knockback)
		assert_eq(a.knockback_scaling, 0.0, "link knockback must not grow with damage")
		assert_eq(a.launch_angle_y, c.light_link_launch_angle_y)
		assert_eq(a.min_hitstun_ticks, c.light_link_hitstun_ticks)
		assert_eq(a.total_ticks(), c.light_startup_ticks + c.light_active_ticks + c.light_recovery_ticks)


func test_heavy_bat_and_projectiles_from_config() -> void:
	var c := GameConfig.new()
	var s := AttackSet.from_config(c)
	var heavy := s.get_attack(AttackSet.Kind.HEAVY)
	assert_eq(heavy.damage, 12.0)
	assert_eq(heavy.base_knockback, 6.0)
	assert_eq(heavy.knockback_scaling, 0.12)
	assert_eq(heavy.hitstop_ticks, SimTime.to_ticks(c.hitstop_heavy))
	assert_eq(heavy.total_ticks(), c.heavy_startup_ticks + c.heavy_active_ticks + c.heavy_recovery_ticks)
	var bat := s.get_attack(AttackSet.Kind.BAT)
	assert_eq(bat.damage, c.bat_damage)
	assert_eq(bat.hitbox_forward, c.bat_hitbox_forward)
	assert_eq(s.get_attack(AttackSet.Kind.ROCK).damage, c.rock_damage)
	assert_eq(s.get_attack(AttackSet.Kind.BOMB).base_knockback, c.bomb_base_knockback)
	assert_eq(s.get_attack(AttackSet.Kind.THROW).knockback_scaling, c.throw_knockback_scaling)


func test_grab_box_deals_no_damage() -> void:
	var c := GameConfig.new()
	var grab := AttackSet.from_config(c).get_attack(AttackSet.Kind.GRAB)
	assert_eq(grab.damage, 0.0)
	assert_eq(grab.startup_ticks, c.grab_startup_ticks)
	assert_eq(grab.hitbox_forward, c.grab_forward)


func test_only_first_two_light_hits_chain() -> void:
	assert_true(AttackSet.is_light_chainable(AttackSet.Kind.LIGHT_1))
	assert_true(AttackSet.is_light_chainable(AttackSet.Kind.LIGHT_2))
	for kind: int in [AttackSet.Kind.LIGHT_3, AttackSet.Kind.HEAVY, AttackSet.Kind.BAT, AttackSet.Kind.GRAB]:
		assert_false(AttackSet.is_light_chainable(kind))


func test_table_follows_config_changes() -> void:
	var c := GameConfig.new()
	c.heavy_damage = 20.0
	assert_eq(AttackSet.from_config(c).get_attack(AttackSet.Kind.HEAVY).damage, 20.0)
