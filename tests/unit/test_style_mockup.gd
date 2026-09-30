extends GutTest
## Phase 5 T8 gate mockups (StyleMockup, src/debug/silhouette): each direction dresses a real
## FighterView, and a fresh FighterView keeps the default look (the mockups never leak into it).


func _view(slot: int) -> FighterView:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(slot, GameConfig.new())
	return v


func _character(slot: int) -> String:
	return String(CharacterCatalog.for_player(slot)["name"])


func _mesh(v: FighterView, mesh_name: String) -> MeshInstance3D:
	var found := v.model().find_children(mesh_name, "MeshInstance3D", true, false)
	return found[0] as MeshInstance3D if not found.is_empty() else null


func test_lineup_is_boxing_boxing_weapon_ranged() -> void:
	var styles: Array[int] = []
	for slot: int in StyleMockup.LINEUP:
		styles.append(StyleMockup.style_of(_character(slot)))
	assert_eq(styles, [StyleMockup.Style.BOXING, StyleMockup.Style.BOXING,
		StyleMockup.Style.WEAPON, StyleMockup.Style.RANGED])


func test_gear_reveals_the_knight_sword_and_raises_it() -> void:
	var v := _view(0)
	var clip := StyleMockup.apply(StyleMockup.Direction.A, v, "Knight")
	assert_true(_mesh(v, "2H_Sword").visible)
	assert_true(_mesh(v, "Knight_Helmet").visible)
	assert_eq(clip, "2H_Melee_Idle")


func test_gear_puts_gloves_on_both_boxing_hands() -> void:
	var v := _view(1)
	var before := {}
	for bone: String in MockupGear.HANDS:
		before[bone] = StyleMockup.bone_slot(v.model(), bone).get_child_count()
	StyleMockup.apply(StyleMockup.Direction.A, v, "Barbarian")
	for bone: String in MockupGear.HANDS:
		assert_eq(StyleMockup.bone_slot(v.model(), bone).get_child_count(), int(before[bone]) + 1, bone)


func test_trim_uses_one_accent_token_per_style() -> void:
	assert_eq(MockupTrim.accent(StyleMockup.Style.BOXING), DS.FIRE)
	assert_eq(MockupTrim.accent(StyleMockup.Style.WEAPON), DS.PETAL_BLUE)
	assert_eq(MockupTrim.accent(StyleMockup.Style.RANGED), DS.BERRY)
	var v := _view(2)
	var before := StyleMockup.bone_slot(v.model(), "head").get_child_count()
	StyleMockup.apply(StyleMockup.Direction.B, v, "Mage")
	assert_eq(StyleMockup.bone_slot(v.model(), "head").get_child_count(), before + 1, "circlet")


func test_stance_clips_differ_per_style_and_exist() -> void:
	var clips := {}
	for slot: int in [1, 0, 2]:
		var v := _view(slot)
		var count := v.get_child_count()
		var clip := StyleMockup.apply(StyleMockup.Direction.C, v, _character(slot))
		assert_true(v.model().animation_player().has_animation(clip), clip)
		assert_eq(v.get_child_count(), count + 1, "floating style icon")
		clips[clip] = true
	assert_eq(clips.size(), 3, "boxing, weapon and ranged idle apart")


func test_silhouette_flattens_every_mesh() -> void:
	var v := _view(3)
	StyleMockup.apply(StyleMockup.Direction.A, v, "Rogue")
	StyleMockup.silhouette(v, DS.CANOPY_DEEP)
	for node: Node in v.find_children("*", "MeshInstance3D", true, false):
		var mat := (node as MeshInstance3D).material_override as StandardMaterial3D
		assert_not_null(mat, String(node.name))
		assert_eq(mat.albedo_color, DS.CANOPY_DEEP)


func test_default_fighter_keeps_accessories_hidden() -> void:
	StyleMockup.apply(StyleMockup.Direction.A, _view(0), "Knight")
	var fresh := _view(0)
	assert_false(_mesh(fresh, "2H_Sword").visible, "mockups never change the default look")
	assert_false(_mesh(fresh, "Knight_Helmet").visible)
