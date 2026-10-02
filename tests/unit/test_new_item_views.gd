extends GutTest
## Drawing, sound and tracking of the hammer, feather glove and banana (PRD-ITEM-05..07).

const NEW_KINDS: Array[int] = [Item.Kind.HAMMER, Item.Kind.GLOVE, Item.Kind.BANANA]


func _model(kind: int) -> ItemModel:
	var m := ItemModels.create(kind)
	add_child_autofree(m)
	return m


func test_each_new_kind_has_its_own_readable_model() -> void:
	assert_true(_model(Item.Kind.HAMMER) is HammerModel)
	assert_true(_model(Item.Kind.GLOVE) is GloveModel)
	assert_true(_model(Item.Kind.BANANA) is BananaModel)
	for kind: int in NEW_KINDS:
		var b := _model(kind).bounds()
		assert_gt(b.size.length(), 0.3, "kind %d is big enough to read" % kind)
		assert_lt(b.size.length(), 1.6, "kind %d is not huge" % kind)
		assert_ne(ItemModels.hold_transform(kind), RockModel.HOLD, "kind %d has its own grip" % kind)


func test_a_laid_banana_shows_its_peel() -> void:
	var m := _model(Item.Kind.BANANA) as BananaModel
	m.show_state({"trap": false}, 0)
	assert_false(m.is_showing_trap())
	m.show_state({"trap": true}, 0)
	assert_true(m.is_showing_trap())


func test_swing_dots_follow_every_melee_item_and_stay_centered() -> void:
	var c := GameConfig.new()
	var dots := BatUseDots.new()
	add_child_autofree(dots)
	dots.setup(c)
	dots.show_uses(Item.Kind.GLOVE, 3)
	assert_eq(dots.shown(), 3)
	var xs: Array[float] = []
	for d: Node in dots.get_children():
		if (d as Node3D).visible:
			xs.append((d as Node3D).position.x)
	assert_almost_eq(xs[0] + xs[2], 0.0, 0.001, "centered over the head")
	dots.show_uses(Item.Kind.BANANA, 1)
	assert_eq(dots.shown(), 0, "throwables show no dots")


func test_a_light_fighter_shows_feathers() -> void:
	var h := FighterHazards.new()
	add_child_autofree(h)
	h.setup(0, GameConfig.new())
	h.apply({"state": Fighter.State.IDLE, "light": true}, Vector3.ZERO, 0.0)
	assert_true(h.light())
	h.apply({"state": Fighter.State.KO, "light": true}, Vector3.ZERO, 0.0)
	assert_false(h.light(), "not while KO")


func test_the_hammer_squeaks_and_a_slip_has_a_sound() -> void:
	var c := GameConfig.new()
	var hit := {"type": "hit", "knockback": 9.0, "attack_kind": AttackSet.Kind.HAMMER}
	assert_eq(SfxDirector.sound_for(hit, c)["name"], "squeak")
	assert_eq(SfxDirector.sound_for({"type": "slip"}, c)["name"], "slip")
	for name: String in ["squeak", "slip"]:
		assert_true(ResourceLoader.exists(SfxRecipes.path(name)), "%s is baked" % name)


func test_tracking_names_the_new_items() -> void:
	var sent: Array = []
	var emit := func(n: String, p: Dictionary) -> void: sent.append([n, p])
	var count := func(_s: int, _c: String) -> void: pass
	var t := ItemTelemetry.new()
	t.on_swing(0, AttackSet.Kind.HAMMER, emit, count)
	t.on_event({"type": "hit", "attacker": 0, "target": 1, "attack_kind": AttackSet.Kind.GLOVE}, emit, count)
	t.on_event({"type": "slip", "victim": 1, "owner": 0, "item_id": 4, "pos": Vector3.ZERO}, emit, count)
	assert_eq(sent[0][1]["item"], "hammer")
	assert_eq(sent[0][1]["action"], "swing")
	assert_eq(sent[1][1]["item"], "glove")
	assert_eq(sent[2][0], "item_hit")
	assert_eq(sent[2][1]["item"], "banana")
	assert_eq(sent[2][1]["target_slot"], 1)
