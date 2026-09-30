extends GutTest
## Phase 5 T1/T2 (PRD-ARCH-03, PRD-STYLE-01~03): styles build their attack table and movement
## from GameConfig, characters map to style + special, StyleBook gives each fighter its kit.

const K := AttackSet.Kind


func _style(id: String) -> StyleData:
	return StyleCatalog.build(id, GameConfig.new())


func test_classic_style_is_the_plain_config_table() -> void:
	var c := GameConfig.new()
	var s := StyleCatalog.build(StyleCatalog.CLASSIC, c)
	var base := AttackSet.from_config(c)
	for kind: int in [K.LIGHT_1, K.LIGHT_3, K.HEAVY, K.GRAB, K.THROW]:
		assert_eq(s.attacks.get_attack(kind).damage, base.get_attack(kind).damage)
		assert_eq(s.attacks.get_attack(kind).total_ticks(), base.get_attack(kind).total_ticks())
	assert_eq(s.move_speed, c.move_speed)
	assert_eq(s.jump_velocity, c.jump_velocity)
	assert_eq(s.knockback_taken, 1.0)


func test_boxer_is_fast_with_short_reach() -> void:
	var boxer := _style(StyleCatalog.BOXER)
	var classic := _style(StyleCatalog.CLASSIC)
	for kind: int in [K.LIGHT_1, K.LIGHT_2, K.LIGHT_3]:
		assert_lt(boxer.attacks.get_attack(kind).total_ticks(), classic.attacks.get_attack(kind).total_ticks())
		assert_lt(boxer.attacks.get_attack(kind).hitbox_forward, classic.attacks.get_attack(kind).hitbox_forward)
	assert_gt(boxer.move_speed, classic.move_speed)


func test_weapon_is_slow_wide_and_hits_hard() -> void:
	var weapon := _style(StyleCatalog.WEAPON)
	var boxer := _style(StyleCatalog.BOXER)
	for kind: int in [K.LIGHT_3, K.HEAVY]:
		var w := weapon.attacks.get_attack(kind)
		var b := boxer.attacks.get_attack(kind)
		assert_gt(w.startup_ticks, b.startup_ticks, "slower")
		assert_gt(w.hitbox_forward, b.hitbox_forward, "longer")
		assert_gt(w.hitbox_half.x, b.hitbox_half.x, "wider")
		assert_gt(w.base_knockback, b.base_knockback, "bigger knockback")
	assert_lt(weapon.move_speed, boxer.move_speed)
	assert_lt(weapon.knockback_taken, 1.0, "heavier body")


func test_ranged_fires_projectiles_and_is_weak_up_close() -> void:
	var ranged := _style(StyleCatalog.RANGED)
	var classic := _style(StyleCatalog.CLASSIC)
	for kind: int in [K.LIGHT_1, K.LIGHT_2, K.LIGHT_3]:
		assert_eq(ranged.attacks.get_attack(kind).projectile_kind, Projectile.Kind.BOLT)
		assert_gt(ranged.attacks.get_attack(kind).projectile_ticks, 0)
	assert_eq(ranged.attacks.get_attack(K.HEAVY).projectile_kind, Projectile.Kind.HEAVY_BOLT)
	assert_eq(ranged.attacks.get_attack(K.LIGHT_1).min_hitstun_ticks, GameConfig.new().bolt_hitstun_ticks)
	assert_lt(ranged.attacks.get_attack(K.THROW).damage, classic.attacks.get_attack(K.THROW).damage)
	assert_eq(classic.attacks.get_attack(K.LIGHT_1).projectile_kind, AttackData.MELEE)


func test_styles_follow_config_live() -> void:
	var c := GameConfig.new()
	c.boxer_move_speed = 9.0
	c.bolt_speed = 20.0
	assert_eq(StyleCatalog.build(StyleCatalog.BOXER, c).move_speed, 9.0)
	var bolt := StyleCatalog.build(StyleCatalog.RANGED, c).attacks.get_attack(K.LIGHT_1)
	assert_eq(bolt.projectile_speed, 20.0)


func test_characters_map_to_style_and_special() -> void:
	assert_eq(CharacterData.style_of(CharacterData.BARBARIAN), StyleCatalog.BOXER)
	assert_eq(CharacterData.style_of(CharacterData.ROGUE), StyleCatalog.BOXER)
	assert_eq(CharacterData.style_of(CharacterData.KNIGHT), StyleCatalog.WEAPON)
	assert_eq(CharacterData.style_of(CharacterData.MAGE), StyleCatalog.RANGED)
	assert_eq(CharacterData.special_of(CharacterData.BARBARIAN), SpecialCatalog.GROUND_SLAM)
	assert_eq(CharacterData.special_of(CharacterData.ROGUE), SpecialCatalog.DASH_RUSH)
	assert_eq(CharacterData.special_of(CharacterData.KNIGHT), SpecialCatalog.SPIN_SLASH)
	assert_eq(CharacterData.special_of(CharacterData.MAGE), SpecialCatalog.BIG_FIREBALL)
	assert_eq(CharacterData.style_of(CharacterData.DEFAULT), StyleCatalog.CLASSIC)
	assert_eq(CharacterData.special_of(CharacterData.DEFAULT), "")


func test_resolve_accepts_render_names_and_falls_back() -> void:
	assert_eq(CharacterData.resolve("Knight"), CharacterData.KNIGHT)
	assert_eq(CharacterData.resolve(""), CharacterData.DEFAULT)
	assert_eq(CharacterData.resolve("Dragon"), CharacterData.DEFAULT)


func test_style_book_gives_each_fighter_its_kit() -> void:
	var c := GameConfig.new()
	var chars: Array[String] = [CharacterData.MAGE, CharacterData.DEFAULT, CharacterData.KNIGHT]
	var w := World.new(c, 1, 3, null, chars)
	var book := StyleBook.build(w.fighters, c)
	assert_eq(book.kit(0).style.id, StyleCatalog.RANGED)
	assert_eq(book.kit(1).style.id, StyleCatalog.CLASSIC)
	assert_eq(book.kit(2).special, SpecialCatalog.SPIN_SLASH)
	var spin := book.attacks(2).get_attack(K.SPECIAL)
	assert_eq(spin.damage, c.spin_damage, "SPECIAL entry is the character's special")
	assert_eq(book.kit(1).special, "")


func test_knockback_taken_depends_on_the_target_style() -> void:
	var c := GameConfig.new()
	var a := AttackData.light_from(c)
	var knight := Fighter.new()
	knight.character = CharacterData.KNIGHT
	var mage := Fighter.new()
	mage.character = CharacterData.MAGE
	var kn := Combat.apply_hit(knight, a, Vector3.RIGHT, 1.0, c, Vector3.ZERO, 5)
	var mg := Combat.apply_hit(mage, a, Vector3.RIGHT, 1.0, c, Vector3.ZERO, 5)
	assert_lt(float(kn["knockback"]), float(mg["knockback"]))
	assert_eq(kn["damage"], a.damage, "hit events carry the damage dealt")


func test_run_speed_comes_from_the_style() -> void:
	var chars: Array[String] = [CharacterData.ROGUE, CharacterData.KNIGHT]
	var w := World.new(GameConfig.new(), 1, 2, null, chars)
	w.fighters[0].pos = Vector3(0, 0, -3)
	w.fighters[1].pos = Vector3(0, 0, 3)
	var start_x: Array[float] = [w.fighters[0].pos.x, w.fighters[1].pos.x]
	for i: int in 30:
		var inputs: Array[InputFrame] = [InputFrame.make(1, 0), InputFrame.make(1, 0)]
		w.tick(inputs)
	var rogue_run := w.fighters[0].pos.x - start_x[0]
	var knight_run := w.fighters[1].pos.x - start_x[1]
	assert_gt(rogue_run, knight_run, "the boxer outruns the weapon fighter")


func test_style_groups_are_sim_values_and_on_the_debug_panel() -> void:
	var specs := ConfigSchema.sliders_for(GameConfig.new())
	var groups := {}
	for s: Dictionary in specs:
		groups[s["name"]] = s["group"]
	assert_eq(groups.get("boxer_move_speed"), "StyleBoxer")
	assert_eq(groups.get("weapon_reach_mul"), "StyleWeapon")
	assert_eq(groups.get("bolt_speed"), "StyleRanged")
	assert_eq(groups.get("slam_radius"), "SpecialSlam")
	assert_eq(groups.get("bot_ranged_keep_distance"), "BotStyle")
	var a := GameConfig.new()
	var b := GameConfig.new()
	b.weapon_reach_mul = 1.7
	assert_ne(a.fingerprint(), b.fingerprint(), "style numbers change replays")
	b = GameConfig.new()
	b.bot_ranged_keep_distance = 5.0
	assert_eq(a.fingerprint(), b.fingerprint(), "bot tuning does not")
