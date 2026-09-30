extends GutTest
## Phase 5 T8 style gear pieces without a dressed fighter: the look table (StyleGearCatalog)
## and the animator's idle clip swap used by StyleGear.


func _fighter(slot: int) -> FighterView:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(slot, GameConfig.new())
	return v


func test_gear_kind_follows_the_style() -> void:
	assert_eq(StyleGearCatalog.look_for("barbarian", StyleCatalog.BOXER)["gear"], StyleGearCatalog.Gear.GLOVES)
	assert_eq(StyleGearCatalog.look_for("rogue", StyleCatalog.BOXER)["gear"], StyleGearCatalog.Gear.GLOVES)
	assert_eq(StyleGearCatalog.look_for("knight", StyleCatalog.WEAPON)["gear"], StyleGearCatalog.Gear.SWORD)
	assert_eq(StyleGearCatalog.look_for("mage", StyleCatalog.RANGED)["gear"], StyleGearCatalog.Gear.STAFF)


func test_barbarian_gloves_are_bigger_than_rogue_gloves() -> void:
	var big := float(StyleGearCatalog.look_for("barbarian", StyleCatalog.BOXER)["glove_radius"])
	var small := float(StyleGearCatalog.look_for("rogue", StyleCatalog.BOXER)["glove_radius"])
	assert_gt(big, small)


func test_classic_and_unknown_characters_have_no_look() -> void:
	assert_true(StyleGearCatalog.look_for(CharacterData.DEFAULT, StyleCatalog.CLASSIC).is_empty())
	assert_true(StyleGearCatalog.look_for("pirate", StyleCatalog.BOXER).is_empty())


func test_animator_clip_swap_skips_timed_states_and_resets() -> void:
	var v := _fighter(1)
	var anim := v.animator()
	assert_false(anim.set_clip(AnimMap.Anim.LIGHT, "Unarmed_Pose"), "timed swings keep their clip")
	assert_false(anim.set_clip(AnimMap.Anim.IDLE, "No_Such_Clip"))
	assert_true(anim.set_clip(AnimMap.Anim.IDLE, "Unarmed_Pose"))
	var node := anim.state_machine().get_node(AnimMap.anim_name(AnimMap.Anim.IDLE)) as AnimationNodeAnimation
	assert_eq(String(node.animation), "Unarmed_Pose")
	anim.reset_clip(AnimMap.Anim.IDLE)
	assert_eq(anim.clip_for(AnimMap.Anim.IDLE), "Idle")
	assert_eq(String(node.animation), "Idle")
