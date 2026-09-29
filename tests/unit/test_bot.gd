extends GutTest


func _view(me_pos: Vector3, foe_pos: Vector3, me_on_ground: bool = true, jumps: int = 2) -> Dictionary:
	return {
		"arena_radius": 10.0,
		"fighters": [
			{"id": 0, "pos": foe_pos, "facing": Vector3(1, 0, 0), "state": Fighter.State.IDLE, "on_ground": true, "jumps_left": 2},
			{"id": 1, "pos": me_pos, "facing": Vector3(-1, 0, 0), "state": Fighter.State.IDLE, "on_ground": me_on_ground, "jumps_left": jumps},
		],
	}


func test_approaches_the_opponent() -> void:
	var bot := BotController.new(1, GameConfig.new())
	var f := bot.sample(_view(Vector3(5, 0, 0), Vector3(-2, 0, 0)))
	assert_lt(f.move_x, 0.0)
	assert_false(f.light)


func test_attacks_in_range_then_waits_for_cooldown() -> void:
	var c := GameConfig.new()
	var bot := BotController.new(1, c)
	var v := _view(Vector3(1.0, 0, 0), Vector3(0, 0, 0))
	assert_true(bot.sample(v).light, "in range and ready")
	var waited := 0
	for i: int in 1000:
		if bot.sample(v).light:
			break
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
