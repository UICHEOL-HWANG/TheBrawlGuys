extends GutTest


func _neutral() -> Array[InputFrame]:
	var a: Array[InputFrame] = [InputFrame.neutral(), InputFrame.neutral()]
	return a


func test_falling_below_kill_y_costs_a_stock_and_respawns_invulnerable() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var f := w.fighters[1]
	f.damage = 80.0
	f.pos = Vector3(3, c.kill_y - 0.5, 0)
	f.on_ground = false
	w.tick(_neutral())
	assert_eq(f.stocks, c.stocks - 1)
	assert_eq(f.damage, 0.0)
	assert_eq(f.spawn_id, 1)
	assert_eq(f.invuln_ticks, SimTime.to_ticks(c.respawn_invuln))
	assert_almost_eq(f.pos.y, c.respawn_height, 0.0001)
	assert_eq(f.state, Fighter.State.AIR)
	var events: Array = w.state_view()["events"]
	assert_eq((events[0] as Dictionary)["type"], "ringout")
	assert_eq((events[0] as Dictionary)["stocks_left"], c.stocks - 1)


func test_leaving_blast_zone_horizontally_rings_out() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[0].pos = Vector3(c.arena_radius + c.blast_margin + 0.5, 2, 0)
	w.fighters[0].on_ground = false
	w.tick(_neutral())
	assert_eq(w.fighters[0].stocks, c.stocks - 1)


func test_respawn_invulnerability_counts_down_and_blocks_hits() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[1].pos = Vector3(0, c.kill_y - 1, 0)
	w.tick(_neutral())
	var invuln := w.fighters[1].invuln_ticks
	w.tick(_neutral())
	assert_eq(w.fighters[1].invuln_ticks, invuln - 1)
	# a hit attempt during invulnerability does nothing
	var attacker := w.fighters[0]
	attacker.pos = w.fighters[1].pos - Vector3(1.0, 0, 0)
	attacker.facing = Vector3(1, 0, 0)
	var a: Array[InputFrame] = [InputFrame.make(0, 0, false, true), InputFrame.neutral()]
	w.tick(a)
	for i: int in c.light_startup_ticks + 1:
		w.tick(_neutral())
	assert_eq(w.fighters[1].damage, 0.0)


func test_last_stock_lost_means_ko_and_winner() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[1].stocks = 1
	w.fighters[1].pos = Vector3(0, c.kill_y - 1, 0)
	w.tick(_neutral())
	assert_eq(w.fighters[1].state, Fighter.State.KO)
	assert_false(w.fighters[1].is_alive())
	assert_true(w.match_over)
	assert_eq(w.winner_id, 0)
	var view := w.state_view()
	assert_true(view["match_over"])
	assert_eq(view["winner"], 0)


func test_simultaneous_last_stocks_is_a_draw() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	for f: Fighter in w.fighters:
		f.stocks = 1
		f.pos = Vector3(f.pos.x, c.kill_y - 1, 0)
	w.tick(_neutral())
	assert_true(w.match_over)
	assert_eq(w.winner_id, Rules.DRAW)


func test_winner_rule() -> void:
	var a := Fighter.new()
	var b := Fighter.new()
	b.id = 1
	var fighters: Array[Fighter] = [a, b]
	assert_eq(Rules.winner(fighters), Rules.ONGOING)
	b.set_state(Fighter.State.KO)
	assert_eq(Rules.winner(fighters), 0)


func test_after_match_over_the_world_stops_simulating() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	w.fighters[1].stocks = 1
	w.fighters[1].pos = Vector3(0, c.kill_y - 1, 0)
	w.tick(_neutral())
	var frozen := w.fighters[0].pos
	var a: Array[InputFrame] = [InputFrame.make(1, 0), InputFrame.neutral()]
	w.tick(a)
	assert_eq(w.fighters[0].pos, frozen)
	assert_eq(w.tick_count, 2)
