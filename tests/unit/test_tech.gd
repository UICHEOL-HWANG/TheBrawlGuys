extends GutTest
## Tech (combat-depth C): guard pressed while tumbling arms a tech for tech_window_ticks. Landing
## inside that window skips the knockdown: a tech in place (neutral stick) or a tech roll (a
## direction held), both briefly intangible, with a "tech" {fighter, kind} event. Every press
## locks further presses for tech_window_ticks + tech_lockout_ticks (no mashing). A tumbling
## fighter's guard press never air-dodges.

const K := preload("res://tests/unit/support/knockdown_case.gd")


## P2 taps guard on each tick in `presses` (ticks since the launch) and holds `stick` throughout.
func _run(presses: Array[int], stick: Vector2 = Vector2.ZERO) -> World:
	var w := K.launched()
	K.until_landed(w, func(t: int) -> InputFrame:
		return InputFrame.make(stick.x, stick.y, false, false, false, presses.has(t)))
	return w


func _landing() -> int:
	return K.landing_tick()


func _window() -> int:
	return GameConfig.new().tech_window_ticks


func test_guard_just_before_landing_techs_in_place() -> void:
	var w := _run([_landing() - 3])
	var f := w.fighters[K.VICTIM]
	assert_eq(f.state, Fighter.State.GETUP)
	assert_true(f.untouchable(), "a tech is briefly intangible")
	var techs := K.events_of(w, "tech")
	assert_eq(techs.size(), 1)
	assert_eq(techs[0]["fighter"], K.VICTIM)
	assert_eq(techs[0]["kind"], "place")
	assert_true(K.events_of(w, "knockdown").is_empty())
	for i: int in w.config.tech_ticks:
		K.step(w, InputFrame.neutral())
	assert_eq(f.state, Fighter.State.IDLE)


func test_a_held_direction_tech_rolls() -> void:
	var w := _run([_landing() - 3], Vector2(0, 1))
	var f := w.fighters[K.VICTIM]
	assert_eq(K.events_of(w, "tech")[0]["kind"], "roll")
	var z := f.pos.z
	for i: int in 6:
		K.step(w, InputFrame.neutral())
	assert_gt(f.pos.z, z, "rolls along the stick")


func test_the_landing_tick_itself_still_techs() -> void:
	var w := _run([_landing() - 1])
	assert_eq(w.fighters[K.VICTIM].state, Fighter.State.GETUP)


func test_a_press_outside_the_window_is_a_knockdown() -> void:
	var w := _run([_landing() - 1 - _window()])
	assert_eq(w.fighters[K.VICTIM].state, Fighter.State.KNOCKDOWN)


func test_a_missed_press_locks_out_the_next_one() -> void:
	var land := _landing()
	var w := _run([land - _window() - 10, land - 3])
	assert_eq(w.fighters[K.VICTIM].state, Fighter.State.KNOCKDOWN, "mashing does not tech")


func test_the_lockout_runs_out() -> void:
	var c := GameConfig.new()
	var land := _landing()
	var early := land - c.tech_window_ticks - c.tech_lockout_ticks - 6
	assert_true(early >= 0, "the flight is long enough for this test")
	var w := _run([early, land - 3])
	assert_eq(w.fighters[K.VICTIM].state, Fighter.State.GETUP)


func test_tumbling_guard_press_does_not_air_dodge() -> void:
	var w := K.launched()
	var f := w.fighters[K.VICTIM]
	K.until_landed(w, func(_t: int) -> InputFrame:
		var press := f.state == Fighter.State.AIR and not f.guard_prev
		return InputFrame.make(1, 0, false, false, false, press))
	assert_ne(f.state, Fighter.State.DODGE)
	assert_eq(f.dodge_kind, Dodge.Kind.NONE)
