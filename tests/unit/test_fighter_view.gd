extends GutTest


func _view(pos: Vector3, spawn_id: int) -> Dictionary:
	return {"pos": pos, "spawn_id": spawn_id}


func test_interpolates_between_ticks() -> void:
	var p := FighterView.interpolate(_view(Vector3(0, 0, 0), 0), _view(Vector3(2, 4, 0), 0), 0.25)
	assert_eq(p, Vector3(0.5, 1.0, 0))


func test_snaps_after_respawn() -> void:
	var p := FighterView.interpolate(_view(Vector3(20, -8, 0), 0), _view(Vector3(-5, 6, 0), 1), 0.5)
	assert_eq(p, Vector3(-5, 6, 0), "no sliding across the map on respawn")


func test_snaps_without_previous_state() -> void:
	assert_eq(FighterView.interpolate({}, _view(Vector3(1, 2, 3), 0), 0.5), Vector3(1, 2, 3))


func test_visible_when_not_invulnerable() -> void:
	var c := GameConfig.new()
	for t: int in 10:
		assert_true(FighterView.blink_visible(0, t, c))


func test_blinks_at_blink_hz_then_faster_at_the_end() -> void:
	var c := GameConfig.new()
	# 10 Hz -> toggles every 60 / (2 * 10) = 3 ticks
	var long_invuln := SimTime.to_ticks(c.respawn_invuln)
	var pattern: Array[bool] = []
	for t: int in 6:
		pattern.append(FighterView.blink_visible(long_invuln, t, c))
	assert_eq(pattern, [true, true, true, false, false, false] as Array[bool])
	# last 0.5 s uses blink_hz_end (20 Hz) -> toggles every 1.5 ticks
	var toggles := 0
	var last := FighterView.blink_visible(10, 0, c)
	for t: int in range(1, 12):
		var now := FighterView.blink_visible(10, t, c)
		if now != last:
			toggles += 1
		last = now
	assert_gt(toggles, 5, "faster blinking in the final half second")


func _fighter_view_data(item_kind: int, uses: int) -> Dictionary:
	return {
		"id": 0, "spawn_id": 0, "pos": Vector3.ZERO, "facing": Vector3(0, 0, 1),
		"state": Fighter.State.IDLE, "invuln_ticks": 0, "item_kind": item_kind, "item_uses": uses,
	}


func test_held_bat_shows_with_use_dots() -> void:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(0, GameConfig.new())
	var d := _fighter_view_data(Item.Kind.BAT, 3)
	v.apply(d, d, 1.0, 0)
	assert_true(v.held_visible())
	assert_eq(v.dots_shown(), 3)
	var rock := _fighter_view_data(Item.Kind.ROCK, 1)
	v.apply(rock, rock, 1.0, 1)
	assert_true(v.held_visible())
	assert_eq(v.dots_shown(), 0, "use dots are for bats only")
	var none := _fighter_view_data(Fighter.NONE, 0)
	v.apply(none, none, 1.0, 2)
	assert_false(v.held_visible())


func test_carried_item_rides_on_the_hand_slot() -> void:
	var v := FighterView.new()
	add_child_autofree(v)
	var c := GameConfig.new()
	v.setup(0, c)
	assert_not_null(v.model(), "the KayKit model loads in tests")
	var held := v.held_item()
	assert_true(held.get_parent() is BoneAttachment3D, "parented to the hand bone")
	assert_eq((held.get_parent() as BoneAttachment3D).bone_name, CharacterModel.HAND_BONE)
	var world_scale := held.global_transform.basis.get_scale().x
	assert_almost_eq(world_scale, HeldItem.HELD_SCALE, 0.05, "the model's fit scale is undone")
	var bat := _fighter_view_data(Item.Kind.BAT, 1)
	v.apply(bat, bat, 1.0, 0)
	assert_true(held.model() is BatModel)
	assert_eq((held.model() as BatModel).cracks_shown(), BatModel.MAX_CRACKS, "last swing: fully cracked")
	assert_eq(held.model().transform, BatModel.HOLD, "gripped at the tape")
	var bomb := _fighter_view_data(Item.Kind.BOMB, 1)
	v.apply(bomb, bomb, 1.0, 1)
	assert_true(held.model() is BombModel, "a new kind swaps the model")


func test_guard_bubble_follows_the_guard_state() -> void:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(0, GameConfig.new())
	var guard := _fighter_view_data(Fighter.NONE, 0)
	guard["state"] = Fighter.State.GUARD
	v.apply(guard, guard, 1.0, 0)
	assert_true(v.bubble_visible())
	v.wobble()
	var idle := _fighter_view_data(Fighter.NONE, 0)
	v.apply(idle, idle, 1.0, 1)
	assert_false(v.bubble_visible())


func test_fighter_view_draws_the_catalog_character() -> void:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(2, GameConfig.new())
	assert_not_null(v.model(), "slot 2 uses a KayKit character")
	var d := _fighter_view_data(Fighter.NONE, 0)
	d["invuln_ticks"] = 60
	var seen := {}
	for t: int in 30:
		v.apply(d, d, 1.0, t)
		seen[v.model().visible] = true
	assert_eq(seen.size(), 2, "the model blinks while invulnerable")


func test_the_chosen_character_picks_the_model_and_the_slot_picks_the_ring() -> void:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(1, GameConfig.new(), CharacterData.MAGE)
	assert_not_null(v.model())
	assert_eq(v.identity().ring_shape(), PlayerStyle.Shape.TRIANGLE, "P2's ring is a triangle")
	assert_eq(v.identity().label().text, "P2")
	var mage := v.model().find_children("*", "MeshInstance3D", true, false).map(func(n: Node) -> String: return n.name)
	assert_has(mage, "Mage_Body", "P2 plays the Mage model, not the slot's Knight/Barbarian")
	v.set_identity_visible(false)
	assert_false(v.identity().ring().visible)


func test_team_color_tints_the_ring_and_keeps_the_shape() -> void:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(2, GameConfig.new())
	v.identity().set_team_color(PlayerStyle.team_color(0))
	var mat := v.identity().ring().material_override as ShaderMaterial
	assert_eq(mat.get_shader_parameter("albedo"), DS.TEAM_1, "P3 on team 1: blue ring")
	assert_eq(v.identity().ring_shape(), PlayerStyle.Shape.SQUARE, "still P3's square")
	assert_eq(v.identity().label().outline_modulate, DS.TEAM_1)
	v.identity().set_team_color(null)
	mat = v.identity().ring().material_override as ShaderMaterial
	assert_eq(mat.get_shader_parameter("albedo"), DS.P3, "no team: the player color again")
