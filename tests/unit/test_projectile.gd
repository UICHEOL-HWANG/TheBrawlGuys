extends GutTest
## Phase 5 T2 (PRD-STYLE-03): ranged projectiles spawn on the first active tick, fly, hit the
## first fighter capsule (never the owner), are blocked by guard, expire, and survive snapshots.

const K := AttackSet.Kind


## A Mage (slot 0) at x = -2 facing +x and a classic dummy (slot 1) at x = dummy_x.
func _world(dummy_x: float = 2.0) -> World:
	var chars: Array[String] = [CharacterData.MAGE, CharacterData.DEFAULT]
	var w := World.new(GameConfig.new(), 1, 2, null, chars)
	w.fighters[0].pos = Vector3(-2, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[1].pos = Vector3(dummy_x, 0, 0)
	w.fighters[1].facing = Vector3(-1, 0, 0)
	return w


## Ticks with the given inputs for `ticks` ticks (p0 on the first tick only), returning all events.
func _run(w: World, ticks: int, p0_first: InputFrame, p1: InputFrame = null) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	for i: int in ticks:
		var inputs: Array[InputFrame] = [p0_first if i == 0 else InputFrame.neutral(),
				p1 if p1 != null else InputFrame.neutral()]
		w.tick(inputs)
		seen.append_array(w.state_view()["events"])
	return seen


func _of(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type)


func test_light_fires_a_bolt_on_the_first_active_tick() -> void:
	var w := _world()
	var c := w.config
	var events := _run(w, c.bolt_startup_ticks + 2, InputFrame.make(0, 0, false, true))
	var spawns := _of(events, "projectile_spawn")
	assert_eq(spawns.size(), 1, "one bolt per press")
	assert_eq(spawns[0]["owner"], 0)
	assert_eq(spawns[0]["kind"], Projectile.Kind.BOLT)
	var views: Array = w.state_view()["projectiles"]
	assert_eq(views.size(), 1)
	assert_gt((views[0]["vel"] as Vector3).x, 0.0, "flies along the facing")


func test_bolt_hits_the_dummy_not_the_owner() -> void:
	var w := _world()
	var events := _run(w, 40, InputFrame.make(0, 0, false, true))
	var hits := _of(events, "projectile_hit")
	assert_eq(hits.size(), 1)
	assert_eq(hits[0]["target"], 1)
	var melee := _of(events, "hit")
	assert_eq(melee.size(), 1)
	assert_eq(melee[0]["attacker"], 0)
	assert_eq(melee[0]["attack_kind"], K.LIGHT_1)
	assert_gt(w.fighters[1].damage, 0.0)
	assert_eq(w.fighters[0].damage, 0.0)
	assert_eq((w.state_view()["projectiles"] as Array).size(), 0, "a hit consumes the bolt")


func test_guard_blocks_a_bolt() -> void:
	var w := _world()
	var events := _run(w, 40, InputFrame.make(0, 0, false, true), InputFrame.make(0, 0, false, false, false, true))
	assert_eq(_of(events, "guard_hit").size(), 1)
	assert_eq(_of(events, "hit").size(), 0)
	assert_eq(w.fighters[1].state, Fighter.State.GUARD)


func test_bolt_expires_at_the_end_of_its_range() -> void:
	var w := _world(9.0)
	w.fighters[1].pos = Vector3(-2, 0, 6)  # out of the bolt's path
	var events := _run(w, 60, InputFrame.make(0, 0, false, true))
	assert_eq(_of(events, "projectile_expire").size(), 1)
	assert_eq(_of(events, "projectile_hit").size(), 0)
	var expire := _of(events, "projectile_expire")[0]
	var flown := (expire["pos"] as Vector3).x - (-2.0)
	assert_almost_eq(flown, w.config.bolt_range, 0.8, "flies about bolt_range")


func test_heavy_fires_a_heavy_bolt_after_the_charge() -> void:
	var w := _world()
	var events: Array[Dictionary] = []
	for i: int in 50:
		var inputs: Array[InputFrame] = [InputFrame.make(0, 0, false, false, i < 10), InputFrame.neutral()]
		w.tick(inputs)
		events.append_array(w.state_view()["events"])
	var spawns := _of(events, "projectile_spawn")
	assert_eq(spawns.size(), 1)
	assert_eq(spawns[0]["kind"], Projectile.Kind.HEAVY_BOLT)
	assert_eq(_of(events, "hit")[0]["attack_kind"], K.HEAVY)


func test_frozen_fighters_do_not_fire() -> void:
	var w := _world()
	var f := w.fighters[0]
	Actions.start_attack(f, K.LIGHT_1)
	var book := StyleBook.build(w.fighters, w.config)
	f.attack_ticks = book.attacks(0).get_attack(K.LIGHT_1).startup_ticks + 1
	var none: Array[Fighter] = []
	assert_true(ProjectileMotion.fire(none, book, w.projectiles, w.config).is_empty())
	var moving: Array[Fighter] = [f]
	assert_eq(ProjectileMotion.fire(moving, book, w.projectiles, w.config).size(), 1)


func test_projectiles_survive_snapshot_restore() -> void:
	var w := _world(6.0)
	_run(w, w.config.bolt_startup_ticks + 3, InputFrame.make(0, 0, false, true))
	assert_eq((w.state_view()["projectiles"] as Array).size(), 1, "a bolt is in flight")
	var snap := w.snapshot()
	var straight: Array[int] = []
	for i: int in 30:
		w.tick([InputFrame.neutral(), InputFrame.neutral()] as Array[InputFrame])
		straight.append(w.state_hash())
	var chars: Array[String] = [CharacterData.MAGE, CharacterData.DEFAULT]
	var r := World.new(GameConfig.new(), 1, 2, null, chars)
	assert_true(r.restore(snap))
	var resumed: Array[int] = []
	for i: int in 30:
		r.tick([InputFrame.neutral(), InputFrame.neutral()] as Array[InputFrame])
		resumed.append(r.state_hash())
	assert_eq(resumed, straight)
