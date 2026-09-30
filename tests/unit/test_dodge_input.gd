extends GutTest
## Dodge input edge cases (defense review): a special chord pressed guard-first cancels the
## fresh roll, a roll pressed while unable to act is buffered to the first actionable tick, and
## a dodge's intangibility also keeps a fighter from catching fire.


func _inputs(p1: InputFrame) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, InputFrame.neutral()]
	return a


func _guard(mx: float = 0.0, mz: float = 0.0) -> InputFrame:
	return InputFrame.make(mx, mz, false, false, false, true)


## P1 at the arena centre, P2 far away; P1 plays `character` with a full gauge when given.
func _world(character: String = "") -> World:
	var chars: Array[String] = [character]
	var w := World.new(GameConfig.new(), 1, 2, null, chars)
	w.fighters[0].pos = Vector3.ZERO
	w.fighters[1].pos = Vector3(0, 0, 8)
	if not character.is_empty():
		w.fighters[0].gauge = SpecialGauge.MAX
	return w


func test_guard_then_heavy_cancels_the_fresh_roll_into_the_special() -> void:
	var w := _world(CharacterData.KNIGHT)
	w.tick(_inputs(_guard(1.0)))
	assert_eq(w.fighters[0].state, Fighter.State.DODGE, "guard landed first: a roll starts")
	w.tick(_inputs(InputFrame.make(1, 0, false, false, true, true)))
	var f := w.fighters[0]
	assert_eq(f.state, Fighter.State.SPECIAL, "the chord completes: special")
	assert_eq(f.dodge_kind, Dodge.Kind.NONE, "the roll is cancelled")
	assert_false(f.intangible)
	assert_eq(f.facing, Vector3(1, 0, 0), "aimed with the move stick")


func test_heavy_then_guard_still_gives_the_special() -> void:
	var w := _world(CharacterData.KNIGHT)
	w.tick(_inputs(InputFrame.make(1, 0, false, false, true)))
	w.tick(_inputs(InputFrame.make(1, 0, false, false, true, true)))
	assert_eq(w.fighters[0].state, Fighter.State.SPECIAL)


func test_a_roll_past_the_cancel_window_stays_a_roll() -> void:
	var w := _world(CharacterData.KNIGHT)
	w.tick(_inputs(_guard(1.0)))
	for i: int in w.config.special_cancel_window + 1:
		w.tick(_inputs(_guard(1.0)))
	w.tick(_inputs(InputFrame.make(1, 0, false, false, true, true)))
	assert_eq(w.fighters[0].state, Fighter.State.DODGE)
	assert_eq(w.fighters[0].gauge, SpecialGauge.MAX, "the gauge is kept")


func test_roll_pressed_in_hitstun_starts_on_the_first_actionable_tick() -> void:
	var w := _world()
	var f := w.fighters[0]
	f.set_state(Fighter.State.HITSTUN)
	f.hitstun_ticks = 3
	for i: int in 3:
		w.tick(_inputs(_guard(1.0)))
	assert_eq(f.state, Fighter.State.IDLE, "hitstun just ended")
	w.tick(_inputs(_guard(1.0)))
	assert_eq(f.state, Fighter.State.DODGE, "the buffered press rolls")


func test_roll_pressed_in_hitstop_starts_after_the_freeze() -> void:
	var w := _world()
	var f := w.fighters[0]
	f.hitstop_ticks = 4
	for i: int in 5:
		w.tick(_inputs(_guard(0.0, 1.0)))
	assert_eq(f.state, Fighter.State.DODGE)
	assert_eq(f.dodge_dir, Vector3(0, 0, 1))


func test_buffered_roll_needs_guard_and_direction_still_held() -> void:
	var neutral := _world()
	neutral.fighters[0].hitstop_ticks = 3
	neutral.tick(_inputs(_guard(1.0)))
	for i: int in 3:
		neutral.tick(_inputs(_guard()))
	assert_eq(neutral.fighters[0].state, Fighter.State.GUARD, "stick back to neutral: a guard")
	var released := _world()
	released.fighters[0].hitstop_ticks = 3
	released.tick(_inputs(_guard(1.0)))
	for i: int in 3:
		released.tick(_inputs(InputFrame.make(1, 0)))
	assert_eq(released.fighters[0].state, Fighter.State.MOVE, "guard let go: no roll")


func test_an_old_press_is_not_buffered() -> void:
	var w := _world()
	var f := w.fighters[0]
	f.hitstop_ticks = w.config.roll_buffer_ticks + 2
	for i: int in f.hitstop_ticks + 1:
		w.tick(_inputs(_guard(1.0)))
	assert_eq(f.state, Fighter.State.GUARD)


func test_an_intangible_fighter_does_not_catch_fire() -> void:
	var c := GameConfig.new()
	var f := Fighter.new()
	f.intangible = true
	assert_true(Burning.ignite(f, c).is_empty())
	assert_eq(f.burn_ticks, 0)
	f.intangible = false
	assert_false(Burning.ignite(f, c).is_empty(), "tangible: it burns")
