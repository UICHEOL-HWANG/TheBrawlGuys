extends GutTest


func _view(me_pos: Vector3, foe_pos: Vector3, me_on_ground: bool = true, jumps: int = 2) -> Dictionary:
	return {
		"arena_radius": 10.0,
		"items": [],
		"fighters": [
			{"id": 0, "pos": foe_pos, "facing": Vector3(1, 0, 0), "state": Fighter.State.IDLE, "on_ground": true,
				"jumps_left": 2, "item_kind": Fighter.NONE, "invuln_ticks": 0},
			{"id": 1, "pos": me_pos, "facing": Vector3(-1, 0, 0), "state": Fighter.State.IDLE, "on_ground": me_on_ground,
				"jumps_left": jumps, "item_kind": Fighter.NONE, "invuln_ticks": 0},
		],
	}


func _me(v: Dictionary) -> Dictionary:
	return v["fighters"][1]


func _foe(v: Dictionary) -> Dictionary:
	return v["fighters"][0]


func test_approaches_the_opponent() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var f := bot.sample(_view(Vector3(5, 0, 0), Vector3(-2, 0, 0)))
	assert_lt(f.move_x, 0.0)
	assert_false(f.light)


func test_attacks_in_range_mashes_the_combo_then_waits() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(1.0, 0, 0), Vector3(0, 0, 0))
	assert_true(bot.sample(v).light, "in range and ready")
	var mash := 0
	while bot.sample(v).light:
		mash += 1
	assert_eq(mash, BotController.combo_mash_ticks(c), "keeps pressing through the combo buffer windows")
	var waited := mash + 1
	while not bot.sample(v).light:
		waited += 1
	# cooldown N set on the attack sample, decremented at the start of each later sample
	assert_eq(waited, c.bot_attack_cooldown_ticks - 1)


func test_returns_to_center_near_the_edge() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var f := bot.sample(_view(Vector3(9.0, 0, 0), Vector3(9.5, 0, 1.0)))
	assert_lt(f.move_x, 0.0, "moves toward center even though the foe is right there")
	assert_false(f.light)


func test_recovers_with_jump_when_falling_off_stage() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var f := bot.sample(_view(Vector3(11.0, -0.5, 0), Vector3(0, 0, 0), false, 1))
	assert_lt(f.move_x, 0.0)
	assert_true(f.jump)
	var no_jumps := bot.sample(_view(Vector3(11.0, -0.5, 0), Vector3(0, 0, 0), false, 0))
	assert_false(no_jumps.jump)


func test_ko_bot_does_nothing() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var v := _view(Vector3(1, 0, 0), Vector3(0, 0, 0))
	(v["fighters"][1] as Dictionary)["state"] = Fighter.State.KO
	var f := bot.sample(v)
	assert_eq(f.move_x, 0.0)
	assert_false(f.light or f.jump)


func test_bot_drives_a_real_world_into_combat() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var bot := BotController.new(1, c)
	var hit := false
	for i: int in 300:
		var inputs: Array[InputFrame] = [InputFrame.neutral(), bot.sample(w.state_view())]
		w.tick(inputs)
		if w.fighters[0].damage > 0.0:
			hit = true
			break
	assert_true(hit, "bot walks over and lands a light attack on an idle player")


func test_guards_every_other_attack_that_starts_in_range() -> void:
	var c := GameConfig.new()
	c.bot_perfect_guard_chance = 1.0  # every guard turn reacts in time (see test_bot_getup)
	var bot := BotController.new(1, c)
	var v := _view(Vector3(1.5, 0, 0), Vector3(0, 0, 0))
	bot.sample(v)  # the bot swings first and starts its cooldown; ignore
	var calm := _view(Vector3(3.0, 0, 0), Vector3(0, 0, 0))
	for i: int in BotController.combo_mash_ticks(c) + 1:
		bot.sample(calm)
	var attacking := _view(Vector3(1.5, 0, 0), Vector3(0, 0, 0))
	_foe(attacking)["state"] = Fighter.State.ATTACK
	for i: int in c.bot_guard_react_ticks:
		bot.sample(attacking)
	assert_true(bot.sample(attacking).guard, "first threat: guard (after the reaction delay)")
	for i: int in c.bot_guard_ticks:
		bot.sample(calm)
	for i: int in c.bot_guard_react_ticks:
		bot.sample(attacking)
	assert_false(bot.sample(attacking).guard, "second threat: no guard (every other)")


func test_walks_to_a_nearby_item_and_picks_it_up() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(0, 0, 0), Vector3(-6, 0, 0))
	v["items"] = [{"id": 0, "kind": Item.Kind.BAT, "state": Item.State.GROUND, "pos": Vector3(4, 0, 0), "uses": 5, "fuse_ticks": Item.UNLIT}]
	var f := bot.sample(v)
	assert_gt(f.move_x, 0.9, "heads for the item, not the foe")
	_me(v)["pos"] = Vector3(3.5, 0, 0)
	assert_true(bot.sample(v).grab, "grabs to pick it up when in reach")


## Both bots pressing grab at one item: the lower id picks it up and the other's press becomes a
## grab attack on it (a slot bias in the balance sim), so neither contests an item the foe is at.
func test_does_not_press_grab_for_an_item_the_foe_can_also_reach() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(0, 0, 0), Vector3(0.8, 0, 0))
	v["items"] = [{"id": 0, "kind": Item.Kind.BAT, "state": Item.State.GROUND, "pos": Vector3(0.4, 0, 0), "uses": 5, "fuse_ticks": Item.UNLIT}]
	assert_false(bot.sample(v).grab, "the foe stands at the item too: fight instead")


func test_ignores_lit_bombs_and_far_items() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(0, 0, 0), Vector3(-6, 0, 0))
	v["items"] = [
		{"id": 0, "kind": Item.Kind.BOMB, "state": Item.State.GROUND, "pos": Vector3(2, 0, 0), "uses": 1, "fuse_ticks": 40},
		{"id": 1, "kind": Item.Kind.ROCK, "state": Item.State.GROUND, "pos": Vector3(0, 0, c.bot_item_seek_range + 1.0), "uses": 1, "fuse_ticks": Item.UNLIT},
	]
	assert_lt(bot.sample(v).move_x, 0.0, "goes for the foe instead")


func test_throws_a_rock_when_the_foe_is_in_range() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(0, 0, 0), Vector3(-4, 0, 0))
	_me(v)["item_kind"] = Item.Kind.ROCK
	var f := bot.sample(v)
	assert_true(f.grab)
	assert_lt(f.move_x, 0.0, "aims at the foe")


func test_swings_a_bat_without_mashing() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(1.0, 0, 0), Vector3(0, 0, 0))
	_me(v)["item_kind"] = Item.Kind.BAT
	assert_true(bot.sample(v).light)
	assert_false(bot.sample(v).light, "one swing per cooldown with a bat")


func test_grabs_a_guarding_foe() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var v := _view(Vector3(1.0, 0, 0), Vector3(0, 0, 0))
	_foe(v)["state"] = Fighter.State.GUARD
	assert_true(bot.sample(v).grab)


func test_throws_a_held_foe_away_from_the_center() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var v := _view(Vector3(3, 0, 0), Vector3(4, 0, 0))
	_me(v)["state"] = Fighter.State.HOLDING
	var f := bot.sample(v)
	assert_true(f.grab)
	assert_gt(f.move_x, 0.9, "outward from the center")


func _falling_box(pos: Vector3) -> Dictionary:
	return {"id": 0, "kind": Item.Kind.ROCK, "state": Item.State.FALLING, "pos": pos, "uses": 1, "fuse_ticks": Item.UNLIT}


func test_races_toward_a_falling_box_landing_spot() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var v := _view(Vector3(0, 0, 0), Vector3(-6, 0, 0))
	v["items"] = [_falling_box(Vector3(4, 5.0, 0))]
	assert_gt(bot.sample(v).move_x, 0.9, "heads for the landing spot while the box is still falling")


func test_ignores_a_falling_item_landing_beyond_the_edge_ratio() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(6, 0, 0), Vector3(-6, 0, 0))
	var beyond := 10.0 * c.bot_edge_ratio + 0.5
	v["items"] = [_falling_box(Vector3(beyond, 5.0, 0))]
	assert_lt(bot.sample(v).move_x, 0.0, "goes for the foe, not the void")


func test_does_not_press_grab_in_reach_of_a_falling_box() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var v := _view(Vector3(0, 0, 0), Vector3(-6, 0, 0))
	v["items"] = [_falling_box(Vector3(0.5, 5.0, 0))]
	var f := bot.sample(v)
	assert_false(f.grab, "a grab press here would start a grab attack")
	assert_eq(f.move_x, 0.0, "stands still under the box")
	assert_eq(f.move_z, 0.0)


func test_guard_tracking_survives_edge_and_recovery_ticks() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var edge := _view(Vector3(9.0, 0, 0), Vector3(9.0, 0, 1.0))
	_foe(edge)["state"] = Fighter.State.ATTACK
	bot.sample(edge)  # threat #1 starts on the edge tick (early return) and must be counted
	var calm := _view(Vector3(9.0, 0, 0), Vector3(9.0, 0, 8.0))
	for i: int in c.bot_guard_react_ticks + c.bot_guard_ticks + 1:
		bot.sample(calm)
	var center := _view(Vector3(1.5, 0, 0), Vector3(0, 0, 0))
	_foe(center)["state"] = Fighter.State.ATTACK
	assert_false(bot.sample(center).guard, "threat #2 is the un-guarded one")


func _bridge_view(me_pos: Vector3, foe_pos: Vector3) -> Dictionary:
	var v := _view(me_pos, foe_pos)
	v["arena"] = "log_bridge"
	return v


func test_bridge_edge_steps_back_toward_the_middle() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var f := bot.sample(_bridge_view(Vector3(3, 0, 2.05), Vector3(3, 0, -8)))
	assert_lt(f.move_z, 0.0, "the outer plank edge is an edge, not the arena radius")
	assert_false(f.light)


func test_bridge_does_not_walk_off_the_end_toward_a_foe() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var f := bot.sample(_bridge_view(Vector3(11.6, 0, 0), Vector3(15, 0, 0)))
	assert_true(f.move_x <= 0.0, "no floor ahead: stay")


func test_bridge_avoids_a_broken_plank() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var v := _bridge_view(Vector3(-9, 0, -0.5), Vector3(-9, 0, -3.0))
	var floors: Array[bool] = []
	floors.resize(9)
	floors.fill(true)
	floors[1] = false  # the -z plank under x = -9
	v["arena_floors"] = floors
	assert_true(bot.sample(v).move_z >= 0.0, "does not step onto the gap")


func test_throws_off_the_bridge_not_across_the_plank_seam() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var v := _bridge_view(Vector3(3, 0, 1.2), Vector3(3, 0, 2.15))
	_me(v)["state"] = Fighter.State.HOLDING
	var f := bot.sample(v)
	assert_true(f.grab)
	assert_gt(f.move_z, 0.9, "the plank's inner edge touches the spine; the water is the other way")


func test_slides_along_the_spine_instead_of_stalling_at_a_gap() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var v := _bridge_view(Vector3(0, 0, -0.6), Vector3(4, 0, -3.0))
	var floors: Array[bool] = []
	floors.resize(9)
	floors.fill(true)
	for i: int in [1, 2, 3, 4]:
		floors[i] = false  # every -z plank is gone
	v["arena_floors"] = floors
	var f := bot.sample(v)
	assert_gt(f.move_x, 0.9, "keeps closing in along the spine")
	assert_eq(f.move_z, 0.0)


func test_recovers_toward_the_bridge_when_falling_beside_it() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var v := _bridge_view(Vector3(0, -0.3, 3.0), Vector3(-5, 0, 0))
	_me(v)["on_ground"] = false
	var f := bot.sample(v)
	assert_lt(f.move_z, 0.0)
	assert_true(f.jump)
