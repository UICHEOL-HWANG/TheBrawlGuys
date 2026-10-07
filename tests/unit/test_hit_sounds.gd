extends GutTest
## Weapon hit sounds (design.md DS-SFX-01): what the attacker hits with decides the sound.


func _hit(kind: int, knockback: float) -> Dictionary:
	return {"type": "hit", "attacker": 0, "target": 1, "knockback": knockback, "pos": Vector3.ZERO,
			"attack_kind": kind}


func test_style_picks_the_weapon_family() -> void:
	var c := GameConfig.new()
	var soft := 2.0
	var hard := c.spark_large_threshold + 4.0
	var light := AttackSet.Kind.LIGHT_1
	assert_eq(HitSounds.for_hit(_hit(light, soft), StyleCatalog.CLASSIC, c)["name"], "hit_light")
	assert_eq(HitSounds.for_hit(_hit(light, hard), StyleCatalog.BOXER, c)["name"], "hit_heavy")
	assert_eq(HitSounds.for_hit(_hit(light, soft), StyleCatalog.WEAPON, c)["name"], "hit_sword_light")
	assert_eq(HitSounds.for_hit(_hit(AttackSet.Kind.SPECIAL, hard), StyleCatalog.WEAPON, c)["name"], "hit_sword_heavy")
	assert_eq(HitSounds.for_hit(_hit(light, soft), StyleCatalog.RANGED, c)["name"], "hit_magic_light")
	assert_eq(HitSounds.for_hit(_hit(AttackSet.Kind.HEAVY, hard), StyleCatalog.RANGED, c)["name"], "hit_magic_heavy")


func test_items_override_the_style() -> void:
	var c := GameConfig.new()
	for pair: Array in [[AttackSet.Kind.BAT, "hit_bat"], [AttackSet.Kind.ROCK, "hit_rock"],
			[AttackSet.Kind.GLOVE, "hit_feather"], [AttackSet.Kind.HAMMER, "squeak"],
			[AttackSet.Kind.THROW, "toss"], [AttackSet.Kind.BOMB, "hit_heavy"]]:
		assert_eq(HitSounds.for_hit(_hit(int(pair[0]), 2.0), StyleCatalog.WEAPON, c)["name"], pair[1], str(pair[0]))


func test_pitch_bends_with_knockback_but_the_hammer_does_not() -> void:
	var c := GameConfig.new()
	var light := AttackSet.Kind.LIGHT_1
	var soft := HitSounds.for_hit(_hit(light, 2.0), StyleCatalog.WEAPON, c)
	var hard := HitSounds.for_hit(_hit(light, c.spark_large_threshold + 4.0), StyleCatalog.WEAPON, c)
	assert_lt(float(hard["pitch"]), float(soft["pitch"]), "bigger knockback sounds lower")
	assert_eq(float(HitSounds.for_hit(_hit(AttackSet.Kind.HAMMER, 9.0), "", c)["pitch"]), 1.0)


func test_unknown_or_missing_kind_falls_back_to_fists() -> void:
	var c := GameConfig.new()
	var e := {"type": "hit", "knockback": 2.0, "pos": Vector3.ZERO}
	assert_eq(HitSounds.for_hit(e, "", c)["name"], "hit_light")


func test_director_routes_hits_by_the_attackers_style() -> void:
	var c := GameConfig.new()
	var fighters := [{"id": 0, "style": StyleCatalog.WEAPON}, {"id": 1, "style": StyleCatalog.RANGED}]
	assert_eq(SfxDirector.style_of(0, fighters), StyleCatalog.WEAPON)
	assert_eq(SfxDirector.style_of(1, fighters), StyleCatalog.RANGED)
	assert_eq(SfxDirector.style_of(7, fighters), "", "unknown attacker (an item with no owner)")
	var e := _hit(AttackSet.Kind.LIGHT_1, 2.0)
	assert_eq(SfxDirector.sound_for(e, c, false, StyleCatalog.WEAPON)["name"], "hit_sword_light")


func test_every_hit_sound_is_baked() -> void:
	for name: String in HitSounds.NAMES:
		assert_true(ResourceLoader.exists(SfxRecipes.stream_path(name)),
				"%s baked (run scripts/music/hits.py)" % name)
	assert_eq(SfxRecipes.stream_path("hit_sword_light"), "res://assets/sfx/hit_sword_light.wav")
	assert_eq(SfxRecipes.stream_path("jump"), "res://assets/sfx/jump.wav")


## The web build turns every sound into a Web Audio sample; an .ogg would first be decoded on the
## main thread at its first play, a .wav is free. No sound effect ships as .ogg.
func test_every_sound_effect_is_a_wav_sample() -> void:
	for name: String in SfxDirector.sound_names():
		var stream := load(SfxRecipes.stream_path(name))
		assert_true(stream is AudioStreamWAV, "%s is an AudioStreamWAV" % name)
		assert_false(FileAccess.file_exists("res://assets/sfx/%s.ogg" % name), "%s has no .ogg" % name)


func test_sound_names_list_each_sound_once() -> void:
	var names := SfxDirector.sound_names()
	for name: String in HitSounds.NAMES + SfxRecipes.RECIPES.keys():
		assert_eq(names.count(name), 1, name)
