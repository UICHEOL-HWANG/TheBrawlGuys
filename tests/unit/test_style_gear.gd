extends GutTest
## Phase 5 T8 (design.md DS-VIS-02, direction A): each fighting style reads from its gear.
## Gear follows the sim view's character/style, never the slot; it hides while the hand holds an
## item and the classic fighter keeps the default look.

const CHARACTERS: Array[String] = ["knight", "barbarian", "mage", "rogue"]  # = slot models 0..3


func _views(characters: Array[String] = CHARACTERS) -> Array:
	return World.new(GameConfig.new(), 0, 4, null, characters).state_view()["fighters"]


func _fighter(slot: int) -> FighterView:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(slot, GameConfig.new())
	return v


func _show(v: FighterView, view: Dictionary) -> void:
	v.apply(view, view, 1.0, 0)


func _mesh(v: FighterView, mesh_name: String) -> MeshInstance3D:
	var found := v.model().find_children(mesh_name, "MeshInstance3D", true, false)
	return found[0] as MeshInstance3D if not found.is_empty() else null


func _held(view: Dictionary, kind: int) -> Dictionary:
	var out := view.duplicate()
	out["item_kind"] = kind
	out["item_uses"] = 1
	return out


func test_knight_wears_the_sword_and_helmet_tilted_back() -> void:
	var v := _fighter(0)
	var rest := _mesh(v, "2H_Sword").transform
	_show(v, _views()[0])
	assert_eq(v.gear().worn(), "knight")
	assert_true(_mesh(v, "2H_Sword").visible)
	assert_true(_mesh(v, "Knight_Helmet").visible)
	assert_ne(_mesh(v, "2H_Sword").transform.basis, rest.basis, "tilted back")
	assert_eq(v.animator().clip_for(AnimMap.Anim.IDLE), "2H_Melee_Idle")


func test_the_sword_straightens_in_the_hand_while_swinging() -> void:
	var v := _fighter(0)
	var rest := _mesh(v, "2H_Sword").transform
	var idle: Dictionary = _views()[0]
	_show(v, idle)
	var tilted := _mesh(v, "2H_Sword").transform
	var swing := idle.duplicate()
	swing["state"] = Fighter.State.ATTACK
	for i: int in StyleGear.UNTILT_FRAMES:
		_show(v, swing)
	var straight := _mesh(v, "2H_Sword").transform
	assert_true(straight.basis.orthonormalized().is_equal_approx(rest.basis.orthonormalized()),
			"the blade follows the hand, no idle tilt")
	for i: int in StyleGear.UNTILT_FRAMES:
		_show(v, idle)
	assert_true(_mesh(v, "2H_Sword").transform.is_equal_approx(tilted), "back to the ready tilt")


func test_mage_wears_the_staff_with_an_orb_and_hat() -> void:
	var v := _fighter(2)
	_show(v, _views()[2])
	var staff := _mesh(v, "2H_Staff")
	assert_true(staff.visible)
	assert_eq(staff.get_child_count(), 1, "fire orb on the staff head")
	assert_true(_mesh(v, "Mage_Hat").visible)


func test_boxers_wear_gloves_on_both_hands_and_guard_idle() -> void:
	var v := _fighter(1)
	_show(v, _views()[1])
	assert_eq(v.gear().worn(), "barbarian")
	assert_eq(v.gear().hand_gear().size(), 2)
	for glove: Node3D in v.gear().hand_gear():
		assert_true(glove.is_visible_in_tree())
	assert_true(_mesh(v, "Barbarian_Hat").visible)
	assert_eq(v.animator().clip_for(AnimMap.Anim.IDLE), "Unarmed_Pose")


func test_gear_hides_while_holding_an_item_and_comes_back() -> void:
	var v := _fighter(0)
	var view: Dictionary = _views()[0]
	_show(v, view)
	_show(v, _held(view, Item.Kind.BAT))
	assert_false(_mesh(v, "2H_Sword").visible, "the hand slot is shared with the item")
	assert_true(_mesh(v, "Knight_Helmet").visible, "headgear stays")
	assert_true(v.held_visible())
	_show(v, view)
	assert_true(_mesh(v, "2H_Sword").visible)


func test_gloves_hide_while_holding_an_item() -> void:
	var v := _fighter(3)
	var view: Dictionary = _views()[3]
	_show(v, _held(view, Item.Kind.ROCK))
	for glove: Node3D in v.gear().hand_gear():
		assert_false(glove.visible)
	_show(v, view)
	for glove: Node3D in v.gear().hand_gear():
		assert_true(glove.visible)


func test_classic_fighter_keeps_the_default_look() -> void:
	var classic: Array[String] = []
	var v := _fighter(0)
	_show(v, _views(classic)[0])
	assert_eq(v.gear().worn(), "")
	assert_false(_mesh(v, "2H_Sword").visible)
	assert_false(_mesh(v, "Knight_Helmet").visible)
	assert_eq(v.animator().clip_for(AnimMap.Anim.IDLE), "Idle")


func test_gear_is_keyed_by_character_not_slot() -> void:
	# slot 0 draws the Knight model; a Mage in that slot must not get a staff or the knight kit
	var swapped: Array[String] = ["mage", "barbarian", "knight", "rogue"]
	var v := _fighter(0)
	_show(v, _views(swapped)[0])
	assert_eq(v.gear().worn(), "")
	assert_false(_mesh(v, "2H_Sword").visible)
	assert_eq(v.animator().clip_for(AnimMap.Anim.IDLE), "Idle")


func test_undress_restores_the_default_look() -> void:
	var v := _fighter(1)
	_show(v, _views()[1])
	var classic: Array[String] = []
	_show(v, _views(classic)[1])
	assert_eq(v.gear().worn(), "")
	assert_eq(v.gear().hand_gear().size(), 0)
	assert_false(_mesh(v, "Barbarian_Hat").visible)
	assert_eq(v.animator().clip_for(AnimMap.Anim.IDLE), "Idle")


func test_fighter_without_a_model_ignores_gear() -> void:
	var gear := StyleGear.new(null, null)
	gear.follow(_views()[0])
	assert_eq(gear.worn(), "")


func test_redress_keeps_the_accessory_texture() -> void:
	var v := _fighter(0)
	var views := _views()
	var classic: Array[String] = []
	_show(v, views[0])
	_show(v, _views(classic)[0])
	_show(v, views[0])
	var mat := _mesh(v, "Knight_Helmet").get_surface_override_material(0) as ShaderMaterial
	assert_true(bool(mat.get_shader_parameter("use_texture")), "not a white helmet on re-dress")


func test_undress_puts_the_sword_back_and_drops_the_orb() -> void:
	var knight := _fighter(0)
	var rest := _mesh(knight, "2H_Sword").transform
	var mage := _fighter(2)
	var classic: Array[String] = []
	_show(knight, _views()[0])
	_show(knight, _views(classic)[0])
	assert_eq(_mesh(knight, "2H_Sword").transform, rest)
	_show(mage, _views()[2])
	_show(mage, _views(classic)[2])
	assert_eq(_mesh(mage, "2H_Staff").get_child_count(), 0)


func test_style_change_on_the_same_character_redresses() -> void:
	var v := _fighter(0)
	var view: Dictionary = _views()[0].duplicate()
	_show(v, view)
	view["style"] = StyleCatalog.BOXER
	_show(v, view)
	assert_false(_mesh(v, "2H_Sword").visible)
	assert_eq(v.gear().hand_gear().size(), 2, "gloves")
	view["style"] = StyleCatalog.CLASSIC
	_show(v, view)
	assert_eq(v.gear().worn(), "")
	assert_eq(v.gear().hand_gear().size(), 0)


func test_staff_hides_while_held_and_undress_while_busy_redresses_clean() -> void:
	var v := _fighter(2)
	var view: Dictionary = _views()[2]
	_show(v, _held(view, Item.Kind.BOMB))
	assert_false(_mesh(v, "2H_Staff").is_visible_in_tree())
	var classic: Array[String] = []
	_show(v, _held(_views(classic)[2], Item.Kind.BOMB))
	_show(v, view)
	assert_true(_mesh(v, "2H_Staff").is_visible_in_tree())


func test_orb_keeps_its_size_in_metres() -> void:
	var v := _fighter(2)
	_show(v, _views()[2])
	var orb := _mesh(v, "2H_Staff").get_child(0) as Node3D
	assert_almost_eq(orb.global_transform.basis.get_scale().x, 1.0, 0.05)
