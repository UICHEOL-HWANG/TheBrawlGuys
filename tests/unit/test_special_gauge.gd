extends GutTest
## Phase 5 T3 (PRD §6.2.1): the special gauge fills from damage dealt and taken (hits, guarded
## hits, gimmick damage), caps at MAX with one gauge_full, and a special never refills its user.


func test_gauge_fills_from_dealing_and_taking_damage() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var hit: Array[Dictionary] = [{"type": "hit", "attacker": 0, "target": 1, "damage": 10.0, "attack_kind": 0}]
	SpecialGauge.apply(w.fighters, hit, c)
	assert_almost_eq(w.fighters[0].gauge, 10.0 * c.special_gauge_per_damage_dealt, 0.0001)
	assert_almost_eq(w.fighters[1].gauge, 10.0 * c.special_gauge_per_damage_taken, 0.0001)
	var burn: Array[Dictionary] = [{"type": "gimmick_damage", "target": 0, "amount": 4.0}]
	SpecialGauge.apply(w.fighters, burn, c)
	assert_almost_eq(w.fighters[0].gauge, 10.0 * c.special_gauge_per_damage_dealt + 4.0 * c.special_gauge_per_damage_taken, 0.0001)


func test_gauge_caps_and_reports_full_once() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var big: Array[Dictionary] = [{"type": "hit", "attacker": 0, "target": 1, "damage": 500.0, "attack_kind": 0}]
	var first := SpecialGauge.apply(w.fighters, big, c)
	assert_eq(w.fighters[0].gauge, SpecialGauge.MAX)
	assert_eq(first.filter(func(e: Dictionary) -> bool: return e["fighter"] == 0).size(), 1)
	var again := SpecialGauge.apply(w.fighters, big, c)
	assert_true(again.is_empty(), "already full: no second gauge_full")


func test_special_hits_do_not_refill_their_user() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var sp: Array[Dictionary] = [{"type": "hit", "attacker": 0, "target": 1, "damage": 20.0,
			"attack_kind": AttackSet.Kind.SPECIAL}]
	SpecialGauge.apply(w.fighters, sp, c)
	assert_eq(w.fighters[0].gauge, 0.0)
	assert_gt(w.fighters[1].gauge, 0.0)


func test_self_hits_only_count_as_taken() -> void:
	var c := GameConfig.new()
	var w := World.new(c, 1)
	var bomb: Array[Dictionary] = [{"type": "hit", "attacker": 0, "target": 0, "damage": 10.0, "attack_kind": 8}]
	SpecialGauge.apply(w.fighters, bomb, c)
	assert_almost_eq(w.fighters[0].gauge, 10.0 * c.special_gauge_per_damage_taken, 0.0001)


func test_snapshot_with_a_bad_projectile_owner_is_rejected() -> void:
	var chars: Array[String] = [CharacterData.MAGE]
	var w := World.new(GameConfig.new(), 1, 2, null, chars)
	var s: Dictionary = bytes_to_var(w.snapshot())
	var p := Projectile.new()
	p.owner_id = 9
	(s["projectiles"] as Dictionary)["list"] = [p.to_data()]
	assert_false(w.restore(var_to_bytes(s)))
	assert_push_error("inconsistent fighter or projectile data")
