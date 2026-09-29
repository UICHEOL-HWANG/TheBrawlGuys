extends GutTest
## Item boxes (context E6, E8). PHASES test: same seed -> same drop positions and times.

const LONG_RUN := 3000


func _idle(w: World, ticks: int) -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []
	var none: Array[InputFrame] = []
	for i: int in ticks:
		w.tick(none)
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "item_spawn":
				var s := e.duplicate()
				s["tick"] = w.tick_count
				spawns.append(s)
	return spawns


func test_same_seed_same_drops() -> void:
	var a := _idle(World.new(GameConfig.new(), 11), LONG_RUN)
	var b := _idle(World.new(GameConfig.new(), 11), LONG_RUN)
	assert_gt(a.size(), 1, "several boxes fall in 50 s")
	assert_eq(a, b)


func test_other_seed_other_drops() -> void:
	assert_ne(_idle(World.new(GameConfig.new(), 11), LONG_RUN), _idle(World.new(GameConfig.new(), 12), LONG_RUN))


func test_first_drop_inside_the_spawn_window_and_area() -> void:
	var c := GameConfig.new()
	var spawns := _idle(World.new(c, 3), SimTime.to_ticks(c.item_spawn_max_time) + 2)
	assert_eq(spawns.size(), 1)
	var s := spawns[0]
	assert_between(int(s["tick"]), SimTime.to_ticks(c.item_spawn_min_time), SimTime.to_ticks(c.item_spawn_max_time) + 1)
	var p: Vector3 = s["pos"]
	assert_almost_eq(p.y, c.item_drop_height, 0.0001)
	assert_lte(Vector2(p.x, p.z).length(), c.arena_radius * c.item_spawn_radius_ratio + 0.0001)
	assert_between(int(s["kind"]), 0, Item.KIND_COUNT - 1)


func test_field_never_exceeds_the_cap() -> void:
	var c := GameConfig.new()
	c.item_max_on_field = 1
	var w := World.new(c, 5)
	var none: Array[InputFrame] = []
	for i: int in LONG_RUN:
		w.tick(none)
		assert_lte(w.items.items.size(), 1)


func test_box_falls_for_about_a_second_then_lands() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var it := w.items.add(Item.Kind.ROCK, Vector3(2, c.item_drop_height, 0), Item.State.FALLING, c)
	var landed_at := -1
	var none: Array[InputFrame] = []
	for i: int in 120:
		w.tick(none)
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "item_land" and int(e["id"]) == it.id:
				landed_at = i + 1
	assert_between(landed_at, 55, 65, "12 m at -25 m/s^2 is about 0.98 s")
	assert_eq(it.state, Item.State.GROUND)
	assert_eq(it.pos, Vector3(2, 0, 0))
	assert_true(it.is_pickable())


func test_bat_starts_with_full_uses() -> void:
	var c := GameConfig.new()
	var field := ItemField.new()
	assert_eq(field.add(Item.Kind.BAT, Vector3.ZERO, Item.State.GROUND, c).uses, c.bat_uses)
	assert_eq(field.add(Item.Kind.ROCK, Vector3.ZERO, Item.State.GROUND, c).id, 1, "ids increase")


func test_item_data_round_trip_and_validation() -> void:
	var c := GameConfig.new()
	var field := ItemField.new()
	var it := field.add(Item.Kind.BOMB, Vector3(1, 2, 3), Item.State.THROWN, c)
	it.vel = Vector3(4, 5, 6)
	it.fuse_ticks = 30
	it.owner_id = 1
	var copy := Item.from_data(it.to_data())
	assert_eq(copy.to_data(), it.to_data())
	var bad := it.to_data()
	bad["fuse_ticks"] = "soon"
	assert_null(Item.from_data(bad))
	var restored := ItemField.from_data(field.to_data())
	assert_eq(restored.to_data(), field.to_data())


func test_restore_mid_run_continues_identically() -> void:
	var c := GameConfig.new()
	var a := World.new(c, 9)
	_idle(a, 1000)
	var snap := a.snapshot()
	var b := World.new(c, 9)
	assert_true(b.restore(snap))
	assert_eq(_idle(a, 1500), _idle(b, 1500), "item field and spawn schedule are part of the snapshot")


func test_state_view_items_are_copies() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var it := w.items.add(Item.Kind.BAT, Vector3(1, 0, 1), Item.State.GROUND, c)
	var view: Array = w.state_view()["items"]
	it.pos = Vector3(9, 9, 9)
	assert_eq((view[0] as Dictionary)["pos"], Vector3(1, 0, 1))
	assert_eq((view[0] as Dictionary)["kind"], Item.Kind.BAT)
	assert_false((view[0] as Dictionary).has("vel"), "views carry what renderers need")
