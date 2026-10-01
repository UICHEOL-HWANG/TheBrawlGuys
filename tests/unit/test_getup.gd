extends GutTest
## Getting up from a knockdown (combat-depth C). Options open after knockdown_min_ticks of lying:
## jump or guard with a neutral stick stands up, a direction rolls away (intangible), light swings
## a getup attack around the fighter (intangible startup). Lying knockdown_ticks stands up by
## itself. Each start emits "getup" {fighter, kind}; GETUP ends back in IDLE.

const K := preload("res://tests/unit/support/knockdown_case.gd")


## Lies with `press` from the first tick on; returns the getup event seen and the lie length.
func _getup_with(w: World, press: InputFrame, max_ticks: int = 200) -> Dictionary:
	var f := w.fighters[K.VICTIM]
	var lie := 0
	for i: int in max_ticks:
		var from := f.pos
		K.step(w, press)
		var ups := K.events_of(w, "getup")
		if not ups.is_empty():
			return {"event": ups[0], "lie": lie, "from": from}
		assert_eq(f.state, Fighter.State.KNOCKDOWN, "still lying at %d" % i)
		lie += 1
	return {}


func test_options_wait_for_the_minimum_lie_time() -> void:
	var w := K.knocked_down()
	var r := _getup_with(w, InputFrame.make(0, 0, false, true))
	assert_eq(r["event"]["kind"], "attack")
	assert_eq(r["lie"], w.config.knockdown_min_ticks - 1, "the first allowed tick")


func test_lying_still_stands_up_by_itself() -> void:
	var w := K.knocked_down()
	var r := _getup_with(w, InputFrame.neutral())
	assert_eq(r["event"]["kind"], "stand")
	assert_eq(r["event"]["fighter"], K.VICTIM)
	assert_eq(r["lie"], w.config.knockdown_ticks - 1)
	var f := w.fighters[K.VICTIM]
	assert_eq(f.state, Fighter.State.GETUP)
	assert_true(f.untouchable(), "getting up is intangible")
	for i: int in w.config.getup_stand_ticks:
		K.step(w, InputFrame.neutral())
	assert_eq(f.state, Fighter.State.IDLE)
	assert_false(f.intangible)


func test_jump_or_guard_stands_up_early() -> void:
	for press: InputFrame in [InputFrame.make(0, 0, true), InputFrame.make(0, 0, false, false, false, true)]:
		var w := K.knocked_down()
		var r := _getup_with(w, press)
		assert_eq(r["event"]["kind"], "stand")
		assert_eq(r["lie"], w.config.knockdown_min_ticks - 1)


func test_direction_rolls_away_intangibly() -> void:
	var w := K.knocked_down()
	var f := w.fighters[K.VICTIM]
	var r := _getup_with(w, InputFrame.make(0, 1))
	assert_eq(r["event"]["kind"], "roll")
	assert_true(f.untouchable())
	var from: Vector3 = r["from"]
	var c := w.config
	for i: int in c.getup_roll_move_ticks + c.getup_roll_recovery_ticks:
		K.step(w, InputFrame.neutral())
	assert_almost_eq(f.pos.z - from.z, c.getup_roll_distance, 0.01)
	assert_eq(f.state, Fighter.State.IDLE)


func test_getup_attack_hits_a_foe_beside_it() -> void:
	var w := K.knocked_down()
	var f := w.fighters[K.VICTIM]
	var foe := w.fighters[0]
	for i: int in w.config.knockdown_min_ticks - 1:
		K.step(w, InputFrame.neutral())
	foe.pos = f.pos + Vector3(0, 0, -1.0)
	K.step(w, InputFrame.make(0, 0, false, true))
	assert_eq(f.state, Fighter.State.GETUP)
	var hits: Array[Dictionary] = []
	for i: int in w.config.getup_attack_startup_ticks + w.config.getup_attack_active_ticks:
		var t := f.getup_ticks  # (the hit's hitstop pauses the clock)
		assert_eq(f.intangible, t <= w.config.getup_attack_startup_ticks + 1, "intangible through the first active tick, %d" % t)
		K.step(w, InputFrame.neutral())
		hits.append_array(K.events_of(w, "hit"))
	assert_eq(hits.size(), 1, "one hit per getup attack")
	assert_eq(hits[0]["target"], 0)
	assert_eq(hits[0]["attacker"], K.VICTIM)
	assert_gt(foe.damage, 0.0)
