extends GutTest
## What the grab button does right now (DS-CMP-04 highlight, PRD §3.3).


func _world() -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[1].pos = Vector3(0, 0, 8)
	return w


func _eval(w: World) -> int:
	return int(GrabContext.evaluate(w.state_view(), 0, w.config)["kind"])


func test_nothing_nearby_is_none() -> void:
	assert_eq(_eval(_world()), GrabContext.Kind.NONE)


func test_item_in_reach() -> void:
	var w := _world()
	var it := w.items.add(Item.Kind.BAT, w.fighters[0].pos + Vector3(0.8, 0, 0), Item.State.GROUND, w.config)
	var r := GrabContext.evaluate(w.state_view(), 0, w.config)
	assert_eq(int(r["kind"]), GrabContext.Kind.ITEM)
	assert_eq(r["pos"], it.pos)


func test_lit_bomb_and_falling_box_do_not_count() -> void:
	var w := _world()
	var bomb := w.items.add(Item.Kind.BOMB, w.fighters[0].pos + Vector3(0.5, 0, 0), Item.State.GROUND, w.config)
	bomb.fuse_ticks = 30
	w.items.add(Item.Kind.ROCK, w.fighters[0].pos + Vector3(0, 3, 0), Item.State.FALLING, w.config)
	assert_eq(_eval(w), GrabContext.Kind.NONE)


func test_fighter_in_reach() -> void:
	var w := _world()
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	assert_eq(_eval(w), GrabContext.Kind.FIGHTER)


func test_invulnerable_or_ko_fighter_does_not_count() -> void:
	var w := _world()
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[1].invuln_ticks = 10
	assert_eq(_eval(w), GrabContext.Kind.NONE)


func test_carrying_an_item_means_throw() -> void:
	var w := _world()
	w.fighters[0].item_kind = Item.Kind.ROCK
	assert_eq(_eval(w), GrabContext.Kind.THROW)


func test_holding_a_fighter_means_throw() -> void:
	var w := _world()
	w.fighters[0].set_state(Fighter.State.HOLDING)
	assert_eq(_eval(w), GrabContext.Kind.THROW)


func test_busy_or_airborne_is_none() -> void:
	var w := _world()
	w.items.add(Item.Kind.BAT, w.fighters[0].pos + Vector3(0.5, 0, 0), Item.State.GROUND, w.config)
	w.fighters[0].set_state(Fighter.State.HITSTUN)
	assert_eq(_eval(w), GrabContext.Kind.NONE)
	w.fighters[0].set_state(Fighter.State.AIR)
	w.fighters[0].on_ground = false
	assert_eq(_eval(w), GrabContext.Kind.NONE, "pickups and grabs need the ground")


func test_fighter_behind_is_none() -> void:
	var w := _world()
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(-1.0, 0, 0)
	assert_eq(_eval(w), GrabContext.Kind.NONE, "the grab box is in front of the fighter")
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	assert_eq(_eval(w), GrabContext.Kind.FIGHTER)


func test_fighter_beside_and_out_of_the_box_is_none() -> void:
	var w := _world()
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(0.0, 0, w.config.grab_half_width + w.config.fighter_radius + 0.3)
	assert_eq(_eval(w), GrabContext.Kind.NONE)


func test_nearest_of_two_items_wins() -> void:
	var w := _world()
	var p := w.fighters[0].pos
	w.items.add(Item.Kind.BAT, p + Vector3(0.9, 0, 0), Item.State.GROUND, w.config)
	var near := w.items.add(Item.Kind.ROCK, p + Vector3(0, 0, 0.4), Item.State.GROUND, w.config)
	assert_eq(GrabContext.evaluate(w.state_view(), 0, w.config)["pos"], near.pos)


func test_item_exactly_at_the_pickup_radius_counts_and_just_beyond_does_not() -> void:
	var w := _world()
	w.config.item_pickup_radius = 1.5  # exactly representable, so the boundary distance is exact
	var r := w.config.item_pickup_radius
	w.fighters[0].pos = Vector3.ZERO
	w.items.add(Item.Kind.BAT, w.fighters[0].pos + Vector3(r, 0, 0), Item.State.GROUND, w.config)
	assert_eq(_eval(w), GrabContext.Kind.ITEM, "exactly at the radius")
	w.items.items[0].pos = w.fighters[0].pos + Vector3(r + 0.05, 0, 0)
	assert_eq(_eval(w), GrabContext.Kind.NONE, "just beyond")


func test_hitstop_is_none() -> void:
	var w := _world()
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[1].pos = w.fighters[0].pos + Vector3(1.0, 0, 0)
	w.fighters[0].hitstop_ticks = 3
	assert_eq(_eval(w), GrabContext.Kind.NONE, "the press is swallowed during hitstop")
