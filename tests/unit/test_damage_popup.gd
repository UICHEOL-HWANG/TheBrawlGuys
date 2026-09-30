extends GutTest
## Floating damage numbers above the victim (design.md DS-VFX-09).


func _popups(c: GameConfig) -> DamagePopup:
	var p := DamagePopup.new()
	add_child_autofree(p)
	p.setup(c)
	return p


func test_shows_the_dealt_percent_in_the_damage_ramp_color() -> void:
	var c := GameConfig.new()
	var p := _popups(c)
	var label := p.show_hit(Vector3(0, 1, 0), 12.0, 60.0, ImpactTier.Tier.HEAVY)
	assert_not_null(label)
	assert_eq(label.text, "+12%")
	var want := DamageColor.for_percent(60.0)
	assert_almost_eq(label.modulate.r, want.r, 0.001)
	assert_almost_eq(label.modulate.g, want.g, 0.001)
	assert_eq(p.active_count(), 1)


func test_heavy_numbers_are_bigger() -> void:
	var p := _popups(GameConfig.new())
	var light := p.show_hit(Vector3.ZERO, 3.0, 3.0, ImpactTier.Tier.LIGHT)
	var light_size := light.font_size
	var heavy := p.show_hit(Vector3.ZERO, 12.0, 15.0, ImpactTier.Tier.HEAVY)
	assert_gt(heavy.font_size, light_size)


func test_numbers_rise_fade_and_hide() -> void:
	var p := _popups(GameConfig.new())
	var label := p.show_hit(Vector3(0, 1, 0), 4.0, 4.0, ImpactTier.Tier.LIGHT)
	var y0 := label.position.y
	p.advance(DamagePopup.LIFETIME * 0.8)
	assert_gt(label.position.y, y0, "rises")
	assert_lt(label.modulate.a, 1.0, "fades")
	p.advance(DamagePopup.LIFETIME)
	assert_false(label.visible)
	assert_eq(p.active_count(), 0)


func test_pool_caps_simultaneous_numbers() -> void:
	var p := _popups(GameConfig.new())
	for i: int in 20:
		p.show_hit(Vector3.ZERO, 4.0, 4.0, ImpactTier.Tier.LIGHT)
	assert_true(p.active_count() <= ImpactTier.pool_cap(1.0))
	assert_eq(p.get_child_count(), p.capacity(), "labels are reused, not created per hit")


func test_setting_turns_numbers_off() -> void:
	var c := GameConfig.new()
	c.damage_popups = 0
	var p := _popups(c)
	assert_null(p.show_hit(Vector3.ZERO, 12.0, 12.0, ImpactTier.Tier.HEAVY))
	assert_eq(p.active_count(), 0)
