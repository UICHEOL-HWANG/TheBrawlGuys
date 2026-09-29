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
