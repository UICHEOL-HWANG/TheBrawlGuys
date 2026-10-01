extends GutTest
## Knockdown, getup, tech and DI state (combat-depth C) survives World snapshots (v9): restoring
## mid-flight, mid-knockdown or mid-getup continues exactly like the uninterrupted run.

const K := preload("res://tests/unit/support/knockdown_case.gd")
const FIELDS: Array[String] = ["tumble", "di_pending", "tech_clock", "getup_kind", "getup_ticks", "getup_dir"]


## P2 holds a DI stick, taps guard early (a missed tech, locked out), lies, then rolls up.
func _script(t: int) -> InputFrame:
	if t < 60:
		return InputFrame.make(0.0, 0.6, false, false, false, t == 20)
	if t < 100:
		return InputFrame.neutral()
	return InputFrame.make(-1.0, 0.0)


func _run(w: World, from: int, ticks: int) -> Array[int]:
	var seq: Array[int] = []
	for i: int in ticks:
		K.step(w, _script(from + i))
		seq.append(w.state_hash())
	return seq


func test_snapshot_version_is_9() -> void:
	assert_eq(WorldCodec.VERSION, 9)


func test_fighter_data_has_every_knockdown_field() -> void:
	var d := Fighter.new().to_data()
	for key: String in FIELDS:
		assert_true(d.has(key), key)
	assert_not_null(Fighter.from_data(d))


func test_restore_mid_flight_knockdown_and_getup_continues_identically() -> void:
	var land := K.landing_tick()
	var saw := {}
	for split: int in [4, 30, land + 3, 100 + 2]:
		var straight := K.launched()
		_run(straight, 0, split)
		saw[straight.fighters[K.VICTIM].state] = true
		var snap := straight.snapshot()
		var rest := _run(straight, split, 140 - split)
		var resumed := K.launched()
		assert_true(resumed.restore(snap), "restore at %d" % split)
		assert_eq(_run(resumed, split, 140 - split), rest, "same run after a restore at %d" % split)
	assert_true(saw.has(Fighter.State.KNOCKDOWN), "a split lands while lying")
	assert_true(saw.has(Fighter.State.GETUP), "a split lands while getting up")


func test_unknown_getup_kind_is_rejected() -> void:
	var w := K.knocked_down()
	var s: Dictionary = bytes_to_var(w.snapshot())
	s["fighters"][K.VICTIM]["getup_kind"] = 99
	assert_false(K.launched().restore(var_to_bytes(s)))
	assert_push_error("inconsistent fighter")
