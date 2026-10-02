extends GutTest
## Hammer, feather glove and banana peel (PRD-ITEM-05..07): the extended spawn pool keeps the
## classic draw, the hammer pops foes straight up, the glove makes a foe light (more knockback
## taken) for a while, and a thrown banana lies as a trap that knocks down whoever steps on it.


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


func _light() -> InputFrame:
	return InputFrame.make(0, 0, false, true)


func _world() -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[1].pos = Vector3(0, 0, 8)
	return w


func _events_of(w: World, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in w.state_view()["events"]:
		if e["type"] == type:
			out.append(e)
	return out


func _run(w: World, ticks: int, p1: InputFrame = null) -> void:
	for i: int in ticks:
		w.tick(_inputs(p1 if p1 != null else InputFrame.neutral()))


func _spawned_kinds(config: GameConfig) -> Array[int]:
	var field := ItemField.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var arena := ArenaCatalog.default(config)
	var kinds: Array[int] = []
	for t: int in 40000:
		for e: Dictionary in field.spawn_step(t, rng, config, arena.item_area):
			kinds.append(int(e["kind"]))
		field.items.clear()
	return kinds


func test_the_classic_pool_draws_the_same_kinds_as_before() -> void:
	var classic := GameConfig.new()
	assert_false(classic.item_pool_extended, "script default stays classic (replays)")
	var kinds := _spawned_kinds(classic)
	assert_gt(kinds.size(), 50)
	for k: int in kinds:
		assert_lt(k, Item.CLASSIC_KIND_COUNT)


func test_the_extended_pool_spawns_every_kind_on_the_same_schedule() -> void:
	var extended := GameConfig.new()
	extended.item_pool_extended = true
	var kinds := _spawned_kinds(extended)
	for k: int in Item.KIND_COUNT:
		assert_has(kinds, k, "kind %d spawns" % k)
	assert_eq(kinds.size(), _spawned_kinds(GameConfig.new()).size(), "same draws, same drop times")


func test_the_game_config_uses_the_extended_pool() -> void:
	var game := load("res://src/config/default_config.tres") as GameConfig
	assert_true(game.item_pool_extended)


func test_melee_items_get_their_uses() -> void:
	var w := _world()
	var c := w.config
	assert_eq(w.items.add(Item.Kind.HAMMER, Vector3.ZERO, Item.State.GROUND, c).uses, c.hammer_uses)
	assert_eq(w.items.add(Item.Kind.GLOVE, Vector3.ZERO, Item.State.GROUND, c).uses, c.glove_uses)
	assert_eq(w.items.add(Item.Kind.BANANA, Vector3.ZERO, Item.State.GROUND, c).uses, 1)


func test_the_hammer_swings_and_pops_the_foe_straight_up() -> void:
	var w := _world()
	var c := w.config
	var f := w.fighters[0]
	f.item_kind = Item.Kind.HAMMER
	f.item_uses = c.hammer_uses
	w.fighters[1].pos = f.pos + Vector3(1.0, 0, 0)
	w.fighters[1].damage = 60.0
	w.tick(_inputs(_light()))
	assert_eq(f.attack_kind, AttackSet.Kind.HAMMER)
	assert_eq(f.item_uses, c.hammer_uses - 1)
	var hit := false
	for i: int in 30:
		w.tick(_inputs(InputFrame.neutral()))
		if not _events_of(w, "hit").is_empty():
			hit = true
			break
	assert_true(hit, "the swing connects")
	_run(w, SimTime.to_ticks(c.hitstop_heavy) + 2)  # the launch starts when hitstop ends
	var v := w.fighters[1].vel
	assert_gt(v.y, Vector2(v.x, v.z).length() * 3.0, "mostly up")


func test_the_glove_makes_the_foe_light_and_lighter_foes_fly_farther() -> void:
	var c := GameConfig.new()
	var normal := Fighter.new()
	var light := Fighter.new()
	light.light_ticks = 10
	var attack := AttackSet.from_config(c).get_attack(AttackSet.Kind.HEAVY)
	var e1 := Combat.apply_hit(normal, attack, Vector3.RIGHT, 1.0, c, Vector3.ZERO, 0)
	var e2 := Combat.apply_hit(light, attack, Vector3.RIGHT, 1.0, c, Vector3.ZERO, 0)
	assert_almost_eq(float(e2["knockback"]), float(e1["knockback"]) * c.glove_light_knockback_mul, 0.001)


func test_a_glove_hit_sets_light_which_wears_off_and_clears_on_respawn() -> void:
	var w := _world()
	var c := w.config
	var f := w.fighters[0]
	f.item_kind = Item.Kind.GLOVE
	f.item_uses = c.glove_uses
	w.fighters[1].pos = f.pos + Vector3(0.9, 0, 0)
	w.tick(_inputs(_light()))
	assert_eq(f.attack_kind, AttackSet.Kind.GLOVE)
	for i: int in 20:
		w.tick(_inputs(InputFrame.neutral()))
	var foe := w.fighters[1]
	assert_gt(foe.light_ticks, 0, "the glove hit made it light")
	assert_true(bool(w.state_view()["fighters"][1]["light"]), "the view shows it")
	_run(w, SimTime.to_ticks(c.glove_light_time) + 5)
	assert_eq(foe.light_ticks, 0, "wears off")
	foe.light_ticks = 99
	Rules.respawn(foe, 2, c, w.arena)
	assert_eq(foe.light_ticks, 0)


func test_a_thrown_banana_flies_through_fighters_and_lies_as_a_trap() -> void:
	var w := _world()
	var c := w.config
	var f := w.fighters[0]
	f.item_kind = Item.Kind.BANANA
	f.item_uses = 1
	w.fighters[1].pos = f.pos + Vector3(1.4, 0, 0)
	w.tick(_inputs(_light()))
	assert_eq(f.item_kind, Fighter.NONE, "thrown with light")
	var landed := false
	for i: int in 120:
		w.tick(_inputs(InputFrame.neutral()))
		assert_true(_events_of(w, "hit").is_empty(), "no projectile hit")
		if not _events_of(w, "item_land").is_empty():
			landed = true
			break
	assert_true(landed)
	var trap := w.items.items[0]
	assert_eq(trap.kind, Item.Kind.BANANA)
	assert_false(trap.is_pickable(), "a laid banana is a trap, not a pickup")
	assert_true(trap.is_trap())


func test_stepping_on_a_trap_slips_into_a_knockdown() -> void:
	var w := _world()
	var c := w.config
	var victim := w.fighters[1]
	victim.pos = Vector3(3, 0, 0)
	var trap := w.items.add(Item.Kind.BANANA, victim.pos, Item.State.GROUND, c)
	trap.owner_id = 0
	trap.fuse_ticks = 0
	w.tick(_inputs(InputFrame.neutral()))
	assert_eq(_events_of(w, "slip").size(), 1)
	assert_eq(_events_of(w, "slip")[0]["victim"], 1)
	assert_eq(_events_of(w, "slip")[0]["owner"], 0)
	assert_eq(victim.state, Fighter.State.KNOCKDOWN)
	assert_eq(w.items.items.size(), 0, "the peel is used up")


func test_the_thrower_is_safe_on_a_fresh_trap_then_slips_too() -> void:
	var w := _world()
	var c := w.config
	var owner := w.fighters[0]
	var trap := w.items.add(Item.Kind.BANANA, owner.pos, Item.State.GROUND, c)
	trap.owner_id = 0
	trap.fuse_ticks = SimTime.to_ticks(c.banana_grace_time)
	w.tick(_inputs(InputFrame.neutral()))
	assert_true(_events_of(w, "slip").is_empty(), "grace for the thrower")
	_run(w, SimTime.to_ticks(c.banana_grace_time) + 1)
	assert_eq(owner.state, Fighter.State.KNOCKDOWN, "then it is anyone's banana")


func test_airborne_fighters_pass_over_a_trap() -> void:
	var w := _world()
	var c := w.config
	var f := w.fighters[1]
	f.pos = Vector3(3, 2, 0)
	f.on_ground = false
	var trap := w.items.add(Item.Kind.BANANA, Vector3(3, 0, 0), Item.State.GROUND, c)
	trap.fuse_ticks = 0
	w.tick(_inputs(InputFrame.neutral()))
	assert_true(_events_of(w, "slip").is_empty())


func test_snapshots_keep_light_and_traps() -> void:
	var w := _world()
	w.fighters[1].light_ticks = 33
	var trap := w.items.add(Item.Kind.BANANA, Vector3(5, 0, 5), Item.State.GROUND, w.config)
	trap.fuse_ticks = 0
	var copy := World.new(GameConfig.new(), 1)
	assert_true(copy.restore(w.snapshot()))
	assert_eq(copy.fighters[1].light_ticks, 33)
	assert_true(copy.items.items[0].is_trap())


func test_laid_traps_do_not_count_toward_the_drop_cap() -> void:
	var c := GameConfig.new()
	var field := ItemField.new()
	for i: int in c.item_max_on_field:
		var t := field.add(Item.Kind.BANANA, Vector3(9, 0, i), Item.State.GROUND, c)
		t.fuse_ticks = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var area := ArenaCatalog.default(c).item_area
	var spawned := 0
	for t: int in SimTime.to_ticks(c.item_spawn_max_time) * 3:
		spawned += field.spawn_step(t, rng, c, area).size()
	assert_gt(spawned, 0, "boxes still drop while old peels lie around")


func test_allies_do_not_slip_on_a_teammates_peel() -> void:
	var w := _world()
	var c := w.config
	var ally := w.fighters[1]
	ally.ally_mask = 1 << 0
	ally.pos = Vector3(3, 0, 0)
	var trap := w.items.add(Item.Kind.BANANA, ally.pos, Item.State.GROUND, c)
	trap.owner_id = 0
	trap.fuse_ticks = 0
	w.tick(_inputs(InputFrame.neutral()))
	assert_true(_events_of(w, "slip").is_empty())


func test_a_fighter_in_hitstun_does_not_slip_out_of_a_combo() -> void:
	var w := _world()
	var c := w.config
	var f := w.fighters[1]
	f.pos = Vector3(3, 0, 0)
	f.set_state(Fighter.State.HITSTUN)
	f.hitstun_ticks = 20
	var trap := w.items.add(Item.Kind.BANANA, f.pos, Item.State.GROUND, c)
	trap.fuse_ticks = 0
	w.tick(_inputs(InputFrame.neutral()))
	assert_true(_events_of(w, "slip").is_empty())


func test_slipping_drops_the_held_item() -> void:
	var w := _world()
	var c := w.config
	var f := w.fighters[1]
	f.pos = Vector3(3, 0, 0)
	f.item_kind = Item.Kind.HAMMER
	f.item_uses = 2
	var trap := w.items.add(Item.Kind.BANANA, f.pos, Item.State.GROUND, c)
	trap.owner_id = 0
	trap.fuse_ticks = 0
	w.tick(_inputs(InputFrame.neutral()))
	assert_eq(f.item_kind, Fighter.NONE)
	assert_eq(_events_of(w, "item_drop").size(), 1)
	assert_eq(w.items.items[0].kind, Item.Kind.HAMMER)
	assert_eq(w.items.items[0].uses, 2, "the swings left go with it")
