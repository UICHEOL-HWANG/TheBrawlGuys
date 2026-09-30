extends GutTest
## Sim state -> animation state, 1:1 and read-only (design.md GD-ANIM-01).


func _v(state: int, on_ground: bool = true, attack_kind: int = 0) -> Dictionary:
	return {"state": state, "on_ground": on_ground, "attack_kind": attack_kind, "item_kind": Fighter.NONE,
		"charge_ticks": 0, "hitstop_ticks": 0}


func test_ground_and_air_movement() -> void:
	assert_eq(AnimMap.anim_for(_v(Fighter.State.IDLE)), AnimMap.Anim.IDLE)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.MOVE)), AnimMap.Anim.RUN)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.AIR, false)), AnimMap.Anim.JUMP)


func test_attacks_by_kind() -> void:
	for kind: int in [AttackSet.Kind.LIGHT_1, AttackSet.Kind.LIGHT_2, AttackSet.Kind.LIGHT_3]:
		assert_eq(AnimMap.anim_for(_v(Fighter.State.ATTACK, true, kind)), AnimMap.Anim.LIGHT)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.ATTACK, true, AttackSet.Kind.HEAVY)), AnimMap.Anim.HEAVY)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.ATTACK, true, AttackSet.Kind.BAT)), AnimMap.Anim.BAT)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.ATTACK, true, AttackSet.Kind.GRAB)), AnimMap.Anim.GRAB)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.CHARGE)), AnimMap.Anim.CHARGE)


func test_hurt_and_special_states() -> void:
	assert_eq(AnimMap.anim_for(_v(Fighter.State.HITSTUN, true)), AnimMap.Anim.HIT)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.HITSTUN, false)), AnimMap.Anim.LAUNCHED, "airborne hitstun is a launch")
	assert_eq(AnimMap.anim_for(_v(Fighter.State.GUARD)), AnimMap.Anim.GUARD)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.HOLDING)), AnimMap.Anim.HOLD)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.HELD)), AnimMap.Anim.HELD)
	assert_eq(AnimMap.anim_for(_v(Fighter.State.KO)), AnimMap.Anim.KO)


func test_every_fighter_state_maps() -> void:
	for s: int in Fighter.State.values():
		var a := AnimMap.anim_for(_v(s))
		assert_true(AnimMap.Anim.values().has(a), "state %d maps to a real anim" % s)


func test_names_and_timing() -> void:
	assert_eq(AnimMap.anim_name(AnimMap.Anim.LAUNCHED), "LAUNCHED")
	for a: int in [AnimMap.Anim.LIGHT, AnimMap.Anim.HEAVY, AnimMap.Anim.BAT, AnimMap.Anim.GRAB]:
		assert_true(AnimMap.is_timed(a))
	assert_false(AnimMap.is_timed(AnimMap.Anim.RUN))
