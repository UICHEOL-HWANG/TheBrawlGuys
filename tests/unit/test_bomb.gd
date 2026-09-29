extends GutTest
## Bombs (context E7). PHASES test: explodes 120 ticks after the throw and hits only inside its radius.


func _neutral() -> Array[InputFrame]:
	var a: Array[InputFrame] = [InputFrame.neutral(), InputFrame.neutral()]
	return a


func _explosions(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in w.state_view()["events"]:
		if e["type"] == "explosion":
			out.append(e)
	return out


## A lit bomb on the ground at the arena center that explodes on the next tick.
func _armed_world() -> World:
	var w := World.new(GameConfig.new(), 1)
	var bomb := w.items.add(Item.Kind.BOMB, Vector3.ZERO, Item.State.GROUND, w.config)
	bomb.fuse_ticks = 1
	return w


func test_thrown_bomb_explodes_on_the_120th_tick() -> void:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[0].item_kind = Item.Kind.BOMB
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[1].pos = Vector3(0, 0, 8)
	var throw: Array[InputFrame] = [InputFrame.make(0, 0, false, false, false, false, true), InputFrame.neutral()]
	w.tick(throw)
	var exploded_at := -1
	if not _explosions(w).is_empty():
		exploded_at = 1
	for t: int in range(2, 200):
		w.tick(_neutral())
		if exploded_at < 0 and not _explosions(w).is_empty():
			exploded_at = t
	assert_eq(exploded_at, 120, "the throw tick is tick 1")
	assert_eq(SimTime.to_ticks(w.config.bomb_fuse_time), 120)


func test_explosion_hits_only_inside_the_radius() -> void:
	var w := _armed_world()
	var c := w.config
	w.fighters[0].pos = Vector3(1.5, 0, 0)
	w.fighters[1].pos = Vector3(c.bomb_radius + c.fighter_radius + 1.0, 0, 0)
	w.tick(_neutral())
	assert_eq(_explosions(w).size(), 1)
	assert_eq(w.fighters[0].damage, c.bomb_damage)
	assert_eq(w.fighters[0].state, Fighter.State.HITSTUN)
	assert_eq(w.fighters[1].damage, 0.0, "outside the blast")
	assert_eq(w.items.items.size(), 0, "the bomb is gone")


func test_blast_pushes_away_from_the_bomb() -> void:
	var w := _armed_world()
	w.fighters[0].pos = Vector3(-1.0, 0, 0)
	w.fighters[1].pos = Vector3(0, 0, 1.0)
	w.tick(_neutral())
	assert_lt(w.fighters[0].vel.x, 0.0)
	assert_gt(w.fighters[1].vel.z, 0.0)
	assert_gt(w.fighters[0].vel.y, 0.0, "launched upward")


func test_thrower_is_not_safe() -> void:
	var w := _armed_world()
	w.items.items[0].owner_id = 0
	w.fighters[0].pos = Vector3(1.0, 0, 0)
	w.tick(_neutral())
	assert_eq(w.fighters[0].damage, w.config.bomb_damage)


func test_guard_and_invulnerability_apply() -> void:
	var w := _armed_world()
	var c := w.config
	w.fighters[0].pos = Vector3(1.0, 0, 0)
	w.fighters[0].set_state(Fighter.State.GUARD)
	w.fighters[1].pos = Vector3(-1.0, 0, 0)
	w.fighters[1].invuln_ticks = 60
	var guard: Array[InputFrame] = [InputFrame.make(0, 0, false, false, false, true), InputFrame.neutral()]
	w.tick(guard)
	assert_almost_eq(w.fighters[0].damage, c.bomb_damage * c.guard_damage_mul, 0.0001)
	assert_eq(w.fighters[0].state, Fighter.State.GUARD)
	assert_eq(w.fighters[1].damage, 0.0)
