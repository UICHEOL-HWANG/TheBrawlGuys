extends GutTest
## Arena gimmicks (Phase 4 T2, PRD-ARENA-01~04): burn zone, breakable platform, bounce pad, fog cycle.


func _neutral(count: int = 2) -> Array[InputFrame]:
	var a: Array[InputFrame] = []
	for i: int in count:
		a.append(InputFrame.neutral())
	return a


func _world(id: String, config: GameConfig = null) -> World:
	var c := config if config != null else GameConfig.new()
	return World.new(c, 1, 2, ArenaCatalog.build(id, c))


func _gimmick(w: World, kind: String) -> Gimmick:
	for g: Gimmick in w.arena.gimmicks:
		if g.kind() == kind:
			return g
	return null


## Ticks the world and returns every event of `type` with the tick it happened on ("at").
func _collect(w: World, ticks: int, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in ticks:
		w.tick(_neutral(w.fighters.size()))
		for e: Dictionary in w.state_view()["events"]:
			if e["type"] == type:
				var copy := e.duplicate()
				copy["at"] = w.tick_count - 1
				out.append(copy)
	return out


func test_campfire_burns_on_touch_then_every_interval() -> void:
	var c := GameConfig.new()
	var w := _world("lakeside_camp", c)
	var fire := _gimmick(w, "burn_zone")
	assert_not_null(fire)
	w.fighters[0].pos = fire.area.center
	var burns := _collect(w, SimTime.to_ticks(c.burn_interval) * 2 + 1, "gimmick_damage")
	assert_eq(burns.size(), 3, "on touch, then twice more at the interval")
	assert_eq(burns[0]["kind"], "burn")
	assert_eq(burns[0]["target"], 0)
	assert_almost_eq(float(burns[0]["amount"]), c.burn_damage, 0.0001)
	assert_eq(int(burns[1]["at"]) - int(burns[0]["at"]), SimTime.to_ticks(c.burn_interval))
	assert_almost_eq(w.fighters[0].damage, c.burn_damage * 3.0, 0.0001)
	assert_true(w.state_view()["fighters"][0]["burning"])


func test_burning_lasts_after_leaving_the_fire_then_stops() -> void:
	var c := GameConfig.new()
	var w := _world("lakeside_camp", c)
	w.fighters[0].pos = _gimmick(w, "burn_zone").area.center
	w.tick(_neutral())
	w.fighters[0].pos = Vector3(0, 0, 0)
	var later := _collect(w, SimTime.to_ticks(c.burn_duration) + 60, "gimmick_damage")
	var expected := floori(float(SimTime.to_ticks(c.burn_duration) - 1) / SimTime.to_ticks(c.burn_interval))
	assert_eq(later.size(), expected, "keeps burning for burn_duration only")
	assert_false(w.state_view()["fighters"][0]["burning"])


func test_invulnerable_fighter_does_not_catch_fire() -> void:
	var w := _world("lakeside_camp")
	w.fighters[0].pos = _gimmick(w, "burn_zone").area.center
	w.fighters[0].invuln_ticks = 100
	assert_eq(_collect(w, 10, "gimmick_damage").size(), 0)


func test_respawn_puts_the_fire_out() -> void:
	var c := GameConfig.new()
	var f := Rules.spawn_fighter(0, 2, c)
	f.burn_ticks = 50
	Rules.respawn(f, 2, c)
	assert_eq(f.burn_ticks, 0)


func _first_platform(w: World) -> BreakablePlatform:
	for g: Gimmick in w.arena.gimmicks:
		if g is BreakablePlatform and (g as BreakablePlatform).order == 0:
			return g
	return null


func test_bridge_segment_breaks_on_schedule_and_comes_back() -> void:
	var c := GameConfig.new()
	c.platform_break_start_time = 1.0
	c.platform_warn_time = 0.5
	c.platform_respawn_time = 1.0
	var w := _world("log_bridge", c)
	var p := _first_platform(w)
	assert_not_null(p)
	var breaks := _collect(w, SimTime.to_ticks(1.5) + 1, "platform_break")
	assert_eq(breaks.size(), 1)
	assert_eq(int(breaks[0]["id"]), p.id)
	assert_eq(int(breaks[0]["at"]), SimTime.to_ticks(1.0) + SimTime.to_ticks(0.5) - 1)
	assert_false(w.arena.floor_active[p.floor_index], "the segment is gone")
	var restores := _collect(w, SimTime.to_ticks(1.0) + 1, "platform_restore")
	assert_eq(restores.size(), 1)
	assert_true(w.arena.floor_active[p.floor_index])


func test_fighter_on_a_broken_segment_falls() -> void:
	var c := GameConfig.new()
	c.platform_break_start_time = 0.5
	c.platform_warn_time = 0.1
	var w := _world("log_bridge", c)
	var p := _first_platform(w)
	w.fighters[0].pos = p.area.center
	var breaks := _collect(w, SimTime.to_ticks(0.5) + SimTime.to_ticks(0.1) + 4, "platform_break")
	assert_eq(breaks.size(), 1)
	assert_false(w.fighters[0].on_ground)
	assert_lt(w.fighters[0].pos.y, 0.0)


func test_hits_on_a_segment_crack_it_early() -> void:
	var c := GameConfig.new()
	c.platform_hits_to_break = 2
	var w := _world("log_bridge", c)
	var p := _first_platform(w)
	var victim := w.fighters[1]
	victim.pos = p.area.center
	var hit := {"type": "hit", "attacker": 0, "target": 1, "pos": victim.pos}
	var ctx := GimmickContext.new(w.fighters, w.arena, c, 5, [hit, hit])
	p.step(ctx)
	assert_eq(p.state, BreakablePlatform.State.CRACKING, "two hits reach platform_hits_to_break")
	assert_eq(p.timer, SimTime.to_ticks(c.platform_warn_time))


func test_mushroom_bounces_a_landing_fighter() -> void:
	var c := GameConfig.new()
	var w := _world("mushroom_forest", c)
	var pad := _gimmick(w, "bounce_pad")
	assert_not_null(pad)
	var f := w.fighters[0]
	f.pos = pad.area.center + Vector3.UP * 0.5
	f.on_ground = false
	f.set_state(Fighter.State.AIR)
	var bounces := _collect(w, 20, "bounce")
	assert_gt(bounces.size(), 0)
	assert_eq(int(bounces[0]["fighter"]), 0)
	assert_eq(int(bounces[0]["pad"]), pad.id)
	assert_false(f.on_ground)
	assert_gt(f.pos.y, 0.0)
	f.pos = pad.area.center
	f.on_ground = true
	f.vel = Vector3.ZERO
	w.tick(_neutral())
	assert_almost_eq(f.vel.y, c.bounce_speed, 0.0001, "launch speed from config")


func test_fog_cycles_on_the_tick_clock() -> void:
	var c := GameConfig.new()
	c.fog_first_time = 1.0
	c.fog_duration = 0.5
	c.fog_period = 2.0
	var w := _world("foggy_forest", c)
	var starts := _collect(w, SimTime.to_ticks(3.2), "fog_start")
	assert_eq(starts.size(), 2)
	assert_eq(int(starts[0]["at"]), SimTime.to_ticks(1.0))
	assert_eq(int(starts[1]["at"]), SimTime.to_ticks(3.0))
	var w2 := _world("foggy_forest", c)
	var ends := _collect(w2, SimTime.to_ticks(2.0), "fog_end")
	assert_eq(ends.size(), 1)
	assert_eq(int(ends[0]["at"]), SimTime.to_ticks(1.5))


func test_fog_state_is_in_the_view() -> void:
	var c := GameConfig.new()
	c.fog_first_time = 0.1
	var w := _world("foggy_forest", c)
	_collect(w, 10, "fog_start")
	var fog: Dictionary = (w.state_view()["gimmicks"] as Array)[0]
	assert_eq(fog["kind"], "fog")
	assert_true(fog["active"])


func test_lake_rings_out_at_the_water_line() -> void:
	var w := _world("lakeside_camp")
	var lake: ArenaShape = w.arena.ringout_zones[0]
	var f := w.fighters[0]
	f.pos = Vector3(lake.center.x, lake.center.y - 0.1, lake.center.z)
	f.on_ground = false
	var outs := _collect(w, 1, "ringout")
	assert_eq(outs.size(), 1)
	assert_eq(outs[0]["zone"], "lake")


func test_gimmick_state_survives_snapshot() -> void:
	var c := GameConfig.new()
	c.platform_break_start_time = 0.5
	c.fog_first_time = 0.5
	for id: String in ArenaCatalog.stage_ids():
		var a := _world(id, c)
		_collect(a, 40, "none")
		var snap := a.snapshot()
		var b := _world(id, c)
		assert_true(b.restore(snap), id)
		_collect(a, 200, "none")
		_collect(b, 200, "none")
		assert_eq(b.state_hash(), a.state_hash(), "%s continues identically" % id)
