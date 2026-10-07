extends GutTest
## SwingClips (combat-motion A1): each style swings its own way and the light combo varies.

const K := AttackSet.Kind


func _clip(style: String, kind: int, special: String = "") -> String:
	return String(SwingClips.pick(style, kind, special).get("clip", ""))


func test_light_combo_is_three_different_motions() -> void:
	for style: String in [StyleCatalog.CLASSIC, StyleCatalog.BOXER, StyleCatalog.WEAPON]:
		var plans := [SwingClips.pick(style, K.LIGHT_1, ""), SwingClips.pick(style, K.LIGHT_2, ""),
				SwingClips.pick(style, K.LIGHT_3, "")]
		assert_ne(plans[0], plans[1], style)
		assert_ne(plans[1], plans[2], style)


func test_the_knight_swings_his_sword_instead_of_punching_and_kicking() -> void:
	for kind: int in [K.LIGHT_1, K.LIGHT_2, K.LIGHT_3, K.HEAVY]:
		var clip := _clip(StyleCatalog.WEAPON, kind)
		assert_true(clip.contains("Melee_Attack") and not clip.begins_with("Unarmed"), "%d: %s" % [kind, clip])


func test_the_mage_casts() -> void:
	for kind: int in [K.LIGHT_1, K.LIGHT_2, K.LIGHT_3]:
		assert_true(_clip(StyleCatalog.RANGED, kind).begins_with("Spellcast"), str(kind))
	assert_ne(_clip(StyleCatalog.RANGED, K.HEAVY), "Unarmed_Melee_Attack_Kick")


func test_grab_reaches_with_both_hands() -> void:
	assert_eq(_clip(StyleCatalog.CLASSIC, K.GRAB), "Dualwield_Melee_Attack_Stab")
	assert_eq(_clip(StyleCatalog.WEAPON, K.GRAB), "Dualwield_Melee_Attack_Stab", "every style grabs alike")


func test_specials_with_a_release_have_a_plan() -> void:
	assert_false(SwingClips.pick("", K.SPECIAL, SpecialCatalog.BIG_FIREBALL).is_empty())
	assert_false(SwingClips.pick("", K.SPECIAL, SpecialCatalog.GROUND_SLAM).is_empty())
	assert_true(SwingClips.pick("", K.SPECIAL, SpecialCatalog.SPIN_SLASH).is_empty(), "spins loop")


func test_unknown_kind_has_no_plan() -> void:
	assert_true(SwingClips.pick(StyleCatalog.CLASSIC, K.ROCK, "").is_empty())


func test_every_plan_is_ordered_and_ships_in_the_kaykit_pack() -> void:
	var player := _kaykit_player()
	for plan: Dictionary in SwingClips.all_plans():
		assert_true(float(plan["start"]) <= float(plan["contact"]), str(plan))
		assert_true(float(plan["contact"]) < float(plan["end"]), str(plan))
		if player != null:
			assert_true(player.has_animation(String(plan["clip"])), String(plan["clip"]))
			assert_true(float(plan["end"]) <= player.get_animation(String(plan["clip"])).length, str(plan))


func test_poses_ship_in_the_kaykit_pack() -> void:
	var player := _kaykit_player()
	if player == null:
		pending("no KayKit model")
		return
	for anim: int in SwingClips.POSES:
		var pose: Dictionary = SwingClips.POSES[anim]
		assert_true(player.has_animation(String(pose["clip"])), String(pose["clip"]))


func _kaykit_player() -> AnimationPlayer:
	var path := "res://assets/characters/kaykit/Knight.glb"
	if not ResourceLoader.exists(path):
		return null
	var root := (load(path) as PackedScene).instantiate()
	autofree(root)
	return root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
