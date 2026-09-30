extends GutTest
## Phase 5 T3 (PRD §6.2.1, PRD-STYLE-04): the gauge fills from dealing and taking damage, a full
## gauge plus heavy+guard on the same tick starts the character's special once, and each of the
## four specials hits the way it is described. Deterministic and in snapshots.


static func _xc() -> InputFrame:
	return InputFrame.make(0, 0, false, false, true, true)


## Slot 0 plays `character` at the origin facing +x with a full gauge; classic dummies stand at
## the given positions (slots 1..n).
func _world(character: String, dummies: Array[Vector3]) -> World:
	var chars: Array[String] = [character]
	var w := World.new(GameConfig.new(), 1, 1 + dummies.size(), null, chars)
	w.fighters[0].pos = Vector3.ZERO
	w.fighters[0].facing = Vector3(1, 0, 0)
	w.fighters[0].gauge = SpecialGauge.MAX
	for i: int in dummies.size():
		w.fighters[i + 1].pos = dummies[i]
	return w


## Presses X+C on the first tick, then idles; returns every event of `ticks` ticks.
func _fire(w: World, ticks: int = 90) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	for i: int in ticks:
		var inputs: Array[InputFrame] = []
		for f: Fighter in w.fighters:
			inputs.append(_xc() if i == 0 and f.id == 0 else InputFrame.neutral())
		w.tick(inputs)
		seen.append_array(w.state_view()["events"])
	return seen


func _of(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type)


func _targets(events: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	for e: Dictionary in _of(events, "special_hit"):
		if not out.has(int(e["target"])):
			out.append(int(e["target"]))
	out.sort()
	return out


func test_real_hits_fill_the_gauge_in_a_world() -> void:
	var w := _world(CharacterData.BARBARIAN, [Vector3(1.0, 0, 0)] as Array[Vector3])
	w.fighters[0].gauge = 0.0
	for i: int in 20:
		w.tick([InputFrame.make(0, 0, false, i == 0), InputFrame.neutral()] as Array[InputFrame])
	assert_gt(w.fighters[0].gauge, 0.0)
	assert_gt(w.fighters[1].gauge, 0.0)
	assert_eq(w.state_view()["fighters"][0]["gauge"], w.fighters[0].gauge)


func test_full_gauge_and_x_plus_c_starts_the_special_once() -> void:
	var w := _world(CharacterData.BARBARIAN, [Vector3(6, 0, 0)] as Array[Vector3])
	w.tick([_xc(), InputFrame.neutral()] as Array[InputFrame])
	var starts := _of(w.state_view()["events"], "special_start")
	assert_eq(starts.size(), 1)
	assert_eq(starts[0]["fighter"], 0)
	assert_eq(starts[0]["character"], CharacterData.BARBARIAN)
	var f := w.fighters[0]
	assert_eq(f.state, Fighter.State.SPECIAL)
	assert_eq(f.attack_kind, AttackSet.Kind.SPECIAL)
	assert_eq(f.gauge, 0.0, "the gauge empties")
	assert_gt(f.invuln_ticks, 0, "invulnerable during the startup")
	w.tick([_xc(), InputFrame.neutral()] as Array[InputFrame])
	assert_true(_of(w.state_view()["events"], "special_start").is_empty(), "no second start")


func test_no_special_without_a_full_gauge_or_a_character() -> void:
	var w := _world(CharacterData.KNIGHT, [Vector3(6, 0, 0)] as Array[Vector3])
	w.fighters[0].gauge = SpecialGauge.MAX - 1.0
	w.tick([_xc(), InputFrame.neutral()] as Array[InputFrame])
	assert_eq(w.fighters[0].state, Fighter.State.GUARD, "X+C without a full gauge is a guard")
	var classic := _world(CharacterData.DEFAULT, [Vector3(6, 0, 0)] as Array[Vector3])
	classic.tick([_xc(), InputFrame.neutral()] as Array[InputFrame])
	assert_eq(classic.fighters[0].state, Fighter.State.GUARD, "the classic fighter has no special")


func test_x_plus_c_from_guard_starts_the_special() -> void:
	var w := _world(CharacterData.KNIGHT, [Vector3(6, 0, 0)] as Array[Vector3])
	w.tick([InputFrame.make(0, 0, false, false, false, true), InputFrame.neutral()] as Array[InputFrame])
	assert_eq(w.fighters[0].state, Fighter.State.GUARD)
	w.tick([_xc(), InputFrame.neutral()] as Array[InputFrame])
	assert_eq(w.fighters[0].state, Fighter.State.SPECIAL)


func test_ground_slam_launches_everyone_around_up_and_away() -> void:
	var w := _world(CharacterData.BARBARIAN, [Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 6)] as Array[Vector3])
	var events := _fire(w, w.config.slam_startup_ticks + w.config.slam_active_ticks + 2)
	assert_eq(_targets(events), [1, 2] as Array[int], "both close foes, not the far one")
	assert_gt(w.fighters[1].vel.x, 0.0, "pushed away (+x)")
	assert_lt(w.fighters[2].vel.x, 0.0, "pushed away (-x)")
	assert_gt(w.fighters[1].vel.y, 0.0, "launched up")


func test_dash_rush_carries_a_foe_with_several_hits_then_launches() -> void:
	var w := _world(CharacterData.ROGUE, [Vector3(2.5, 0, 0)] as Array[Vector3])
	var events := _fire(w)
	var hits := _of(events, "special_hit")
	assert_gte(hits.size(), 3, "a multi-hit rush")
	var last := float(hits[-1]["knockback"])
	assert_gt(last, float(hits[0]["knockback"]), "the last hit is the launcher")
	assert_gt(w.fighters[0].pos.x, 2.0, "the Rogue dashed forward")


func test_spin_slash_hits_all_around_low_and_hard() -> void:
	var w := _world(CharacterData.KNIGHT, [Vector3(1.8, 0, 0), Vector3(0, 0, -1.8)] as Array[Vector3])
	var events := _fire(w, w.config.spin_startup_ticks + 3)
	assert_eq(_targets(events), [1, 2] as Array[int])
	var v := w.fighters[1].vel
	assert_gt(Vector2(v.x, v.z).length(), v.y, "launch is mostly horizontal")


func test_big_fireball_flies_and_explodes_on_contact() -> void:
	var w := _world(CharacterData.MAGE, [Vector3(6, 0, 0), Vector3(6.5, 0, 1.2)] as Array[Vector3])
	var events := _fire(w, 120)
	var spawns := _of(events, "projectile_spawn")
	assert_eq(spawns.size(), 1)
	assert_eq(spawns[0]["kind"], Projectile.Kind.FIREBALL)
	assert_eq(_of(events, "projectile_hit").size(), 1)
	assert_eq(_targets(events), [1, 2] as Array[int], "the blast catches the neighbour too")
	assert_eq(w.fighters[0].damage, 0.0, "never burns the Mage")


func test_big_fireball_explodes_at_the_end_of_its_range() -> void:
	var w := _world(CharacterData.MAGE, [Vector3(0, 0, 8)] as Array[Vector3])
	var events := _fire(w, 150)
	assert_eq(_of(events, "projectile_expire").size(), 1)
	assert_true(_of(events, "special_hit").is_empty())


func test_invulnerable_during_the_startup() -> void:
	var w := _world(CharacterData.BARBARIAN, [Vector3(1.0, 0, 0)] as Array[Vector3])
	w.fighters[1].facing = Vector3(-1, 0, 0)
	var seen: Array[Dictionary] = []
	for i: int in w.config.special_invuln_ticks:
		w.tick([_xc() if i == 0 else InputFrame.neutral(), InputFrame.make(0, 0, false, i == 0)] as Array[InputFrame])
		seen.append_array(w.state_view()["events"])
	assert_true(_of(seen, "hit").filter(func(e: Dictionary) -> bool: return e["target"] == 0).is_empty())


func test_specials_survive_snapshot_restore() -> void:
	var w := _world(CharacterData.ROGUE, [Vector3(2.5, 0, 0)] as Array[Vector3])
	_fire(w, 14)
	var snap := w.snapshot()
	var straight: Array[int] = []
	for i: int in 60:
		w.tick([InputFrame.neutral(), InputFrame.neutral()] as Array[InputFrame])
		straight.append(w.state_hash())
	var chars: Array[String] = [CharacterData.ROGUE]
	var r := World.new(GameConfig.new(), 1, 2, null, chars)
	assert_true(r.restore(snap))
	assert_eq(r.fighters[0].character, CharacterData.ROGUE)
	var resumed: Array[int] = []
	for i: int in 60:
		r.tick([InputFrame.neutral(), InputFrame.neutral()] as Array[InputFrame])
		resumed.append(r.state_hash())
	assert_eq(resumed, straight)


func test_state_view_exposes_character_style_special_and_gauge() -> void:
	var w := _world(CharacterData.MAGE, [Vector3(4, 0, 0)] as Array[Vector3])
	var v: Dictionary = w.state_view()["fighters"][0]
	assert_eq(v["character"], CharacterData.MAGE)
	assert_eq(v["style"], StyleCatalog.RANGED)
	assert_eq(v["special"], SpecialCatalog.BIG_FIREBALL)
	assert_eq(v["gauge"], SpecialGauge.MAX)
	var dummy: Dictionary = w.state_view()["fighters"][1]
	assert_eq(dummy["character"], "")
	assert_eq(dummy["style"], StyleCatalog.CLASSIC)
	assert_true(w.state_view().has("projectiles"))


func test_mirrored_specials_both_land_whatever_the_ids() -> void:
	var chars: Array[String] = [CharacterData.BARBARIAN, CharacterData.BARBARIAN]
	var w := World.new(GameConfig.new(), 1, 2, null, chars)
	w.fighters[0].pos = Vector3(-1, 0, 0)
	w.fighters[1].pos = Vector3(1, 0, 0)
	for f: Fighter in w.fighters:
		f.gauge = SpecialGauge.MAX
	var seen: Array[Dictionary] = []
	for i: int in w.config.slam_startup_ticks + 3:
		w.tick([_xc() if i == 0 else InputFrame.neutral(), _xc() if i == 0 else InputFrame.neutral()] as Array[InputFrame])
		seen.append_array(w.state_view()["events"])
	var attackers := _of(seen, "special_hit").map(func(e: Dictionary) -> int: return int(e["attacker"]))
	assert_true(attackers.has(0) and attackers.has(1), "both slams land on the same tick")
