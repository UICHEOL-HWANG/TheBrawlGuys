extends GutTest
## Picking up, using, throwing and dropping items (context E6, E7).
## PHASES test: a bat disappears after 5 uses.


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


func _grab() -> InputFrame:
	return InputFrame.make(0, 0, false, false, false, false, true)


func _light() -> InputFrame:
	return InputFrame.make(0, 0, false, true)


func _world() -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[1].pos = Vector3(0, 0, 8)  # out of the way
	return w


func _events_of(w: World, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in w.state_view()["events"]:
		if e["type"] == type:
			out.append(e)
	return out


func test_grab_near_an_item_picks_it_up() -> void:
	var w := _world()
	var it := w.items.add(Item.Kind.ROCK, w.fighters[0].pos + Vector3(0.5, 0, 0), Item.State.GROUND, w.config)
	w.tick(_inputs(_grab()))
	var f := w.fighters[0]
	assert_eq(f.item_kind, Item.Kind.ROCK)
	assert_eq(w.items.items.size(), 0)
	assert_eq(_events_of(w, "item_pickup").size(), 1)
	assert_eq(_events_of(w, "item_pickup")[0]["id"], it.id)
	assert_ne(f.state, Fighter.State.ATTACK, "the grab press was spent on the pickup, not a grab attempt")


func test_grab_with_no_item_in_reach_is_a_grab_attempt() -> void:
	var w := _world()
	w.items.add(Item.Kind.ROCK, w.fighters[0].pos + Vector3(3, 0, 0), Item.State.GROUND, w.config)
	w.tick(_inputs(_grab()))
	assert_eq(w.fighters[0].item_kind, Fighter.NONE)
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.GRAB)


func test_nearest_item_wins_and_lit_bombs_are_not_pickable() -> void:
	var w := _world()
	var c := w.config
	var p := w.fighters[0].pos
	var lit := w.items.add(Item.Kind.BOMB, p + Vector3(0.2, 0, 0), Item.State.GROUND, c)
	lit.fuse_ticks = 60
	w.items.add(Item.Kind.BAT, p + Vector3(0.9, 0, 0), Item.State.GROUND, c)
	w.items.add(Item.Kind.ROCK, p + Vector3(0.5, 0, 0), Item.State.GROUND, c)
	w.tick(_inputs(_grab()))
	assert_eq(w.fighters[0].item_kind, Item.Kind.ROCK)


func test_bat_breaks_after_five_swings() -> void:
	var w := _world()
	var c := w.config
	w.fighters[0].item_kind = Item.Kind.BAT
	w.fighters[0].item_uses = c.bat_uses
	var swing := c.bat_startup_ticks + c.bat_active_ticks + c.bat_recovery_ticks
	for n: int in c.bat_uses:
		w.tick(_inputs(_light()))
		assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.BAT, "swing %d" % (n + 1))
		for i: int in swing:
			w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].item_kind, Fighter.NONE, "the fifth swing used the bat up")
	w.tick(_inputs(_light()))
	assert_eq(w.fighters[0].attack_kind, AttackSet.Kind.LIGHT_1, "back to bare hands")


func test_bat_swing_hits_with_bat_numbers() -> void:
	var w := _world()
	var c := w.config
	w.fighters[0].item_kind = Item.Kind.BAT
	w.fighters[0].item_uses = c.bat_uses
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.tick(_inputs(_light()))
	for i: int in c.bat_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[1].damage, c.bat_damage)


func test_grab_throws_a_rock_that_hits_the_first_fighter() -> void:
	var w := _world()
	var c := w.config
	w.fighters[0].item_kind = Item.Kind.ROCK
	w.fighters[0].item_uses = 1
	w.fighters[1].pos = w.fighters[0].pos + Vector3(3, 0, 0)
	w.tick(_inputs(_grab()))
	assert_eq(w.fighters[0].item_kind, Fighter.NONE)
	assert_eq(_events_of(w, "item_throw").size(), 1)
	var thrown := w.items.items[0]
	assert_eq(thrown.state, Item.State.THROWN)
	assert_eq(thrown.owner_id, 0)
	assert_gt(thrown.vel.x, 0.0)
	var hit: Dictionary = {}
	for i: int in 60:
		w.tick(_inputs(InputFrame.neutral()))
		for e: Dictionary in _events_of(w, "hit"):
			hit = e
		if not hit.is_empty():
			break
	assert_false(hit.is_empty(), "the rock reaches the fighter 3 m ahead")
	assert_eq(hit["attack_kind"], AttackSet.Kind.ROCK)
	assert_eq(hit["attacker"], 0)
	var t := w.fighters[1]
	assert_gt(t.vel.y, 0.0, "launched upward")
	assert_almost_eq(t.vel.y / Vector2(t.vel.x, t.vel.z).length(), c.rock_launch_angle_y, 0.01)
	assert_eq(w.fighters[1].damage, c.rock_damage)
	assert_eq(w.items.items.size(), 0, "a rock is gone after its hit")


func test_light_with_a_rock_also_throws() -> void:
	var w := _world()
	w.fighters[0].item_kind = Item.Kind.ROCK
	w.fighters[0].item_uses = 1
	w.tick(_inputs(_light()))
	assert_eq(_events_of(w, "item_throw").size(), 1)
	assert_ne(w.fighters[0].state, Fighter.State.ATTACK, "the light press was spent on the throw")


func test_throw_follows_the_move_input() -> void:
	var w := _world()
	w.fighters[0].item_kind = Item.Kind.ROCK
	w.tick(_inputs(InputFrame.make(0, -1, false, false, false, false, true)))
	assert_lt(w.items.items[0].vel.z, 0.0)
	assert_eq(w.fighters[0].facing, Vector3(0, 0, -1))


func test_missed_rock_breaks_on_the_ground() -> void:
	var w := _world()
	w.fighters[0].item_kind = Item.Kind.ROCK
	w.tick(_inputs(_grab()))
	var broke := false
	for i: int in 90:
		w.tick(_inputs(InputFrame.neutral()))
		if not _events_of(w, "item_break").is_empty():
			broke = true
	assert_true(broke)
	assert_eq(w.items.items.size(), 0)


func test_thrown_bomb_lands_and_stays() -> void:
	var w := _world()
	w.fighters[0].item_kind = Item.Kind.BOMB
	w.tick(_inputs(_grab()))
	for i: int in 40:
		w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.items.items.size(), 1)
	assert_eq(w.items.items[0].state, Item.State.GROUND)
	assert_gt(w.items.items[0].fuse_ticks, 0, "lit on throw")
	assert_false(w.items.items[0].is_pickable())


func test_getting_hit_drops_the_item() -> void:
	var w := _world()
	var c := w.config
	w.fighters[0].item_kind = Item.Kind.ROCK
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[1].facing = Vector3(-1, 0, 0)
	w.tick(_inputs(InputFrame.neutral(), _light()))
	for i: int in c.light_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].state, Fighter.State.HITSTUN)
	assert_eq(w.fighters[0].item_kind, Fighter.NONE)
	assert_eq(w.items.items.size(), 1)
	assert_eq(w.items.items[0].state, Item.State.FALLING)
	assert_eq(w.items.items[0].kind, Item.Kind.ROCK)


func test_ring_out_loses_the_item() -> void:
	var w := _world()
	w.fighters[0].item_kind = Item.Kind.BAT
	w.fighters[0].item_uses = 3
	w.fighters[0].pos = Vector3(0, w.config.kill_y - 1, 0)
	w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].item_kind, Fighter.NONE)
	assert_eq(w.fighters[0].item_uses, 0)
	assert_eq(w.items.items.size(), 0)
