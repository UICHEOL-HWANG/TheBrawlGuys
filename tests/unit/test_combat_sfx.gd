extends GutTest
## Combat sounds that used to be silent (design.md DS-SFX-01): magic zaps and the fireball roar,
## their pops and booms, the special's power-up sting, grabs, the toss and melee swing whooshes.


func _proj(type: String, kind: int) -> Dictionary:
	return {"type": type, "id": 3, "owner": 0, "kind": kind, "pos": Vector3.ZERO}


func _name(e: Dictionary) -> String:
	return String(SfxDirector.sound_for(e, GameConfig.new()).get("name", ""))


func test_projectile_launches_zap_or_roar() -> void:
	assert_eq(_name(_proj("projectile_spawn", Projectile.Kind.BOLT)), "zap_bolt")
	assert_eq(_name(_proj("projectile_spawn", Projectile.Kind.HEAVY_BOLT)), "zap_heavy")
	assert_eq(_name(_proj("projectile_spawn", Projectile.Kind.FIREBALL)), "fireball_launch")


func test_projectile_ends_pop_or_boom() -> void:
	for type: String in ["projectile_hit", "projectile_expire"]:
		assert_eq(_name(_proj(type, Projectile.Kind.BOLT)), "bolt_pop", type)
		assert_eq(_name(_proj(type, Projectile.Kind.HEAVY_BOLT)), "bolt_pop", type)
		assert_eq(_name(_proj(type, Projectile.Kind.FIREBALL)), "fireball_boom", type)
	var c := GameConfig.new()
	var hit := SfxDirector.sound_for(_proj("projectile_hit", Projectile.Kind.BOLT), c)
	var fizzle := SfxDirector.sound_for(_proj("projectile_expire", Projectile.Kind.BOLT), c)
	assert_lt(float(fizzle["volume_db"]), float(hit["volume_db"]), "a bolt fading out is quieter than one landing")
	var heavy := SfxDirector.sound_for(_proj("projectile_hit", Projectile.Kind.HEAVY_BOLT), c)
	assert_lt(float(heavy["pitch"]), float(hit["pitch"]), "the heavy bolt pops lower")


func test_each_special_charges_at_its_own_pitch() -> void:
	var c := GameConfig.new()
	var pitches: Array[float] = []
	for special: String in SpecialCatalog.IDS:
		var s := SfxDirector.sound_for({"type": "special_start", "fighter": 0, "special": special,
				"pos": Vector3.ZERO}, c)
		assert_eq(s["name"], "special_charge", special)
		assert_false(pitches.has(float(s["pitch"])), "%s has its own color" % special)
		pitches.append(float(s["pitch"]))
	assert_eq(_name({"type": "special_start", "special": "", "pos": Vector3.ZERO}), "special_charge")


func test_grabs_and_the_toss() -> void:
	assert_eq(_name({"type": "grab", "attacker": 0, "target": 1, "pos": Vector3.ZERO}), "grab")
	assert_eq(_name({"type": "grab_release", "attacker": 0, "target": 1, "pos": Vector3.ZERO}), "grab_release")
	var toss := {"type": "hit", "attacker": 0, "target": 1, "knockback": 9.0, "pos": Vector3.ZERO,
			"attack_kind": AttackSet.Kind.THROW}
	assert_eq(_name(toss), "toss", "a throw is a toss, not a punch")


func _swing(style: String, kind: int) -> Dictionary:
	return {"type": "swing", "id": 0, "pos": Vector3.ZERO, "style": style, "kind": kind}


func test_swings_whoosh_by_weapon() -> void:
	var c := GameConfig.new()
	assert_eq(_name(_swing(StyleCatalog.WEAPON, AttackSet.Kind.LIGHT_1)), "swing_blade")
	assert_eq(_name(_swing(StyleCatalog.CLASSIC, AttackSet.Kind.LIGHT_1)), "swing_air")
	assert_eq(_name(_swing(StyleCatalog.BOXER, AttackSet.Kind.HEAVY)), "swing_air")
	assert_eq(_name(_swing(StyleCatalog.CLASSIC, AttackSet.Kind.BAT)), "swing_blade", "the bat swishes")
	assert_eq(_name(_swing(StyleCatalog.RANGED, AttackSet.Kind.HAMMER)), "swing_blade", "items whoosh for the mage too")
	assert_eq(_name(_swing(StyleCatalog.RANGED, AttackSet.Kind.LIGHT_1)), "", "a cast: the zap covers it")
	var light := SfxDirector.sound_for(_swing(StyleCatalog.WEAPON, AttackSet.Kind.LIGHT_1), c)
	var heavy := SfxDirector.sound_for(_swing(StyleCatalog.WEAPON, AttackSet.Kind.HEAVY), c)
	assert_lt(float(heavy["pitch"]), float(light["pitch"]), "the heavy swing is lower")


func test_every_combat_recipe_is_audible_and_baked() -> void:
	for name: String in CombatSfxRecipes.RECIPES:
		var s := SfxMix.render(CombatSfxRecipes.RECIPES[name])
		assert_gt(SfxSynth.peak(s), 0.05, "%s is audible" % name)
		assert_lte(SfxSynth.peak(s), 1.0, "%s does not clip" % name)
		assert_lt(s.size(), SfxSynth.SAMPLE_RATE, "%s is under a second" % name)
		assert_true(ResourceLoader.exists(SfxRecipes.path(name)), "%s baked (run scripts/bake_sfx.gd)" % name)
	assert_eq(SfxRecipes.all().size(), SfxRecipes.RECIPES.size() + CombatSfxRecipes.RECIPES.size(),
			"no combat sound shadows a base recipe")


func test_layers_mix_with_a_delay() -> void:
	var tone := {"wave": "sine", "freq_start": 440.0, "freq_end": 440.0, "attack": 0.001, "sustain": 0.01, "decay": 0.01}
	var plain := SfxMix.render(tone)
	var late := SfxMix.render({"volume": 0.5, "layers": [tone.merged({"delay": 0.1})]})
	assert_eq(plain.size(), SfxSynth.render(tone).size(), "a flat recipe renders as before")
	assert_gt(late.size(), plain.size(), "the delay pads the start")
	assert_almost_eq(SfxSynth.peak(late), 0.5, 0.001, "normalized to the recipe volume")
	assert_eq(late[0], 0.0, "silent before the delayed layer")


func test_limiter_spaces_repeats_and_caps_voices() -> void:
	var lim := SfxLimiter.new()
	assert_true(lim.allow("zap_bolt", "zap_bolt", 1000, 0))
	assert_false(lim.allow("zap_bolt", "zap_bolt", 1010, 0), "too soon after the last one")
	assert_true(lim.allow("zap_bolt", "zap_bolt", 1000 + SfxLimiter.gap_ms("zap_bolt"), 0))
	assert_false(lim.allow("zap_bolt", "zap_bolt", 5000, SfxLimiter.max_voices("zap_bolt")), "voice cap")
	assert_true(lim.allow("hit_light", "hit_light", 1000, 99), "unlisted sounds are not limited")
	assert_true(lim.allow("swing_air", "swing_air:1", 1000, 0))
	assert_true(lim.allow("swing_air", "swing_air:2", 1001, 0), "each fighter's swings are spaced on their own")
	assert_false(lim.allow("swing_air", "swing_air:1", 1002, 0))


func test_director_drops_a_bolt_storm_into_a_few_voices() -> void:
	var d := SfxDirector.new()
	add_child_autofree(d)
	d.setup(GameConfig.new())
	var storm: Array = []
	for i: int in 8:
		storm.append(_proj("projectile_spawn", Projectile.Kind.BOLT))
	d.on_events(storm)
	assert_eq(d.next_voice(), 1, "eight bolts in one frame sound once")
