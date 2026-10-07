extends GutTest
## Melee swing view events (whoosh cue): read from attack ticks, once per swing, never for casts.


func _v(style: String, kind: int, ticks: int, state: int = Fighter.State.ATTACK) -> Dictionary:
	return {"id": 0, "spawn_id": 0, "pos": Vector3.ZERO, "on_ground": true, "state": state,
			"style": style, "attack_kind": kind, "attack_ticks": ticks}


## Every tick a swing of style/kind whooshes on, from its first tick through `ticks` ticks.
func _run(style: String, kind: int, ticks: int, c: GameConfig) -> Array[int]:
	var at: Array[int] = []
	var prev := _v(style, kind, 0, Fighter.State.IDLE)
	for t: int in range(0, ticks + 1):
		var curr := _v(style, kind, t)
		for e: Dictionary in ViewEvents.detect([prev], [curr], c):
			if e["type"] == "swing":
				at.append(t)
		prev = curr
	return at


func test_a_swing_whooshes_once_just_before_it_strikes() -> void:
	var c := GameConfig.new()
	var at := _run(StyleCatalog.CLASSIC, AttackSet.Kind.LIGHT_1, 20, c)
	assert_eq(at.size(), 1, "one whoosh per swing")
	assert_eq(at[0], SwingEvents.fire_tick(StyleCatalog.CLASSIC, AttackSet.Kind.LIGHT_1, c))
	assert_gt(SwingEvents.fire_tick(StyleCatalog.CLASSIC, AttackSet.Kind.HEAVY, c), at[0],
			"the heavy winds up longer")


func test_the_event_says_who_swung_what() -> void:
	var c := GameConfig.new()
	var t := SwingEvents.fire_tick(StyleCatalog.WEAPON, AttackSet.Kind.HEAVY, c)
	var e := ViewEvents.detect([_v(StyleCatalog.WEAPON, AttackSet.Kind.HEAVY, t - 1)],
			[_v(StyleCatalog.WEAPON, AttackSet.Kind.HEAVY, t)], c)
	assert_eq(e.size(), 1)
	assert_eq(e[0]["type"], "swing")
	assert_eq(e[0]["style"], StyleCatalog.WEAPON)
	assert_eq(int(e[0]["kind"]), AttackSet.Kind.HEAVY)
	assert_eq(int(e[0]["id"]), 0)


func test_hitstop_and_skipped_ticks_are_handled() -> void:
	var c := GameConfig.new()
	var t := SwingEvents.fire_tick(StyleCatalog.CLASSIC, AttackSet.Kind.LIGHT_1, c)
	var frozen := _v(StyleCatalog.CLASSIC, AttackSet.Kind.LIGHT_1, t)
	assert_true(SwingEvents.detect(frozen, frozen, c).is_empty(), "a frozen tick does not whoosh again")
	var before := _v(StyleCatalog.CLASSIC, AttackSet.Kind.LIGHT_1, t - 1)
	var after := _v(StyleCatalog.CLASSIC, AttackSet.Kind.LIGHT_1, t + 2)
	assert_false(SwingEvents.detect(before, after, c).is_empty(), "an interpolated view that skips ticks still whooshes")


func test_casts_are_silent_but_items_swing() -> void:
	var c := GameConfig.new()
	assert_eq(_run(StyleCatalog.RANGED, AttackSet.Kind.LIGHT_1, 20, c).size(), 0, "a bolt cast")
	assert_eq(_run(StyleCatalog.RANGED, AttackSet.Kind.HEAVY, 30, c).size(), 0)
	assert_eq(_run(StyleCatalog.RANGED, AttackSet.Kind.BAT, 20, c).size(), 1, "the mage swings a bat")
	assert_eq(_run(StyleCatalog.CLASSIC, AttackSet.Kind.HAMMER, 20, c).size(), 1)
	assert_eq(_run(StyleCatalog.CLASSIC, AttackSet.Kind.GRAB, 20, c).size(), 0, "a grab is not a swing")
	assert_eq(_run(StyleCatalog.CLASSIC, AttackSet.Kind.ROCK, 20, c).size(), 0, "a throw is not a swing")


func test_a_combo_chain_whooshes_each_hit() -> void:
	var c := GameConfig.new()
	var t2 := SwingEvents.fire_tick(StyleCatalog.BOXER, AttackSet.Kind.LIGHT_2, c)
	var end1 := _v(StyleCatalog.BOXER, AttackSet.Kind.LIGHT_1, 12)
	var e := SwingEvents.detect(end1, _v(StyleCatalog.BOXER, AttackSet.Kind.LIGHT_2, t2), c)
	assert_false(e.is_empty(), "the next combo hit is a new swing")
