extends GutTest
## Phase 3 carry-over: two attacks landing on the same tick both hit (no fighter-id order bias).


func _inputs(p0: InputFrame, p1: InputFrame) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p0, p1]
	return a


## Two fighters `gap` apart facing each other.
func _face_off(gap: float) -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[0].pos = Vector3(-gap * 0.5, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[1].pos = Vector3(gap * 0.5, 0, 0)
	w.fighters[1].facing = Vector3(-1, 0, 0)
	return w


func _both_press_light_then_wait(w: World, ticks: int) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var light := InputFrame.make(0, 0, false, true)
	w.tick(_inputs(light, light))
	for i: int in ticks:
		w.tick(_inputs(InputFrame.neutral(), InputFrame.neutral()))
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == "hit":
				hits.append(e)
	return hits


func test_same_tick_lights_hit_both_fighters() -> void:
	var w := _face_off(1.2)
	var hits := _both_press_light_then_wait(w, 10)
	assert_eq(hits.size(), 2, "a trade: both hits land")
	assert_eq(w.fighters[0].damage, w.config.light_link_damage)
	assert_eq(w.fighters[1].damage, w.config.light_link_damage)
	assert_eq(w.fighters[0].state, Fighter.State.HITSTUN)
	assert_eq(w.fighters[1].state, Fighter.State.HITSTUN)


func test_trade_does_not_depend_on_fighter_ids() -> void:
	var a := _face_off(1.2)
	_both_press_light_then_wait(a, 10)
	var b := _face_off(1.2)
	b.fighters[0].pos = Vector3(0.6, 0, 0)
	b.fighters[0].facing = Vector3(-1, 0, 0)
	b.fighters[1].pos = Vector3(-0.6, 0, 0)
	b.fighters[1].facing = Vector3(1, 0, 0)
	_both_press_light_then_wait(b, 10)
	assert_eq(a.fighters[0].damage, b.fighters[1].damage)
	assert_eq(a.fighters[1].damage, b.fighters[0].damage)


func test_trade_freezes_do_not_depend_on_fighter_ids() -> void:
	# light (short hitstop) vs heavy (long hitstop) landing on the same tick, both id orders
	var freezes: Array[Vector2i] = []
	for heavy_id: int in [0, 1]:
		var w := _face_off(1.2)
		var attacks := AttackSet.from_config(w.config)
		for f: Fighter in w.fighters:
			var kind := AttackSet.Kind.HEAVY if f.id == heavy_id else AttackSet.Kind.LIGHT_1
			Actions.start_attack(f, kind)
			f.attack_ticks = attacks.get_attack(kind).startup_ticks + 1
		Combat.resolve(w.fighters, attacks, w.config)
		var light_id := 1 - heavy_id
		freezes.append(Vector2i(w.fighters[heavy_id].hitstop_ticks, w.fighters[light_id].hitstop_ticks))
	assert_eq(freezes[0], freezes[1], "same freezes whichever fighter swings the heavy")
	var heavy_stop := SimTime.to_ticks(GameConfig.new().hitstop_heavy)
	assert_eq(freezes[0], Vector2i(heavy_stop, heavy_stop), "both frozen by the longer hit")


func test_bots_stagger_their_swing_range_by_id() -> void:
	var c := GameConfig.new()
	assert_gt(BotController.attack_range(0, c), BotController.attack_range(1, c),
			"mirrored bots would otherwise trade light hits forever now that trades are fair")
