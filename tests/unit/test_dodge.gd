extends GutTest
## Dodges (combat-depth A): guard pressed with a move input rolls on the ground, guard pressed in
## the air air-dodges once per airtime; both are intangible for a window. Only the press tick
## decides, and the heavy+guard chord stays a special / guard.


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


func _guard(mx: float = 0.0, mz: float = 0.0) -> InputFrame:
	return InputFrame.make(mx, mz, false, false, false, true)


## P1 at the arena centre, P2 far away.
func _world() -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[0].pos = Vector3.ZERO
	w.fighters[1].pos = Vector3(0, 0, 8)
	return w


func _events_of(w: World, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in w.state_view()["events"]:
		if e["type"] == type:
			out.append(e)
	return out


func _roll_total(c: GameConfig) -> int:
	return c.roll_move_ticks + c.roll_recovery_ticks


func test_guard_press_with_a_move_input_rolls() -> void:
	var w := _world()
	w.tick(_inputs(_guard(1.0)))
	var f := w.fighters[0]
	assert_eq(f.state, Fighter.State.DODGE)
	var dodges := _events_of(w, "dodge")
	assert_eq(dodges.size(), 1)
	assert_eq(dodges[0]["fighter"], 0)
	assert_eq(dodges[0]["kind"], "roll")
	assert_eq(dodges[0]["dir"], Vector3(1, 0, 0))


func test_roll_covers_its_distance_then_recovers_to_idle() -> void:
	var w := _world()
	var c := w.config
	w.tick(_inputs(_guard(1.0)))
	for i: int in c.roll_move_ticks - 1:
		w.tick(_inputs(InputFrame.neutral()))
	assert_almost_eq(w.fighters[0].pos.x, c.roll_distance, 0.01, "the full distance over the move ticks")
	for i: int in c.roll_recovery_ticks + 1:
		assert_eq(w.fighters[0].state, Fighter.State.DODGE, "still recovering")
		w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].state, Fighter.State.IDLE)
	assert_almost_eq(w.fighters[0].pos.x, c.roll_distance, 0.01, "no movement during recovery")


func test_roll_is_intangible_only_inside_its_window() -> void:
	var w := _world()
	var c := w.config
	w.tick(_inputs(_guard(0.0, 1.0)))
	var seen: Array[bool] = [w.fighters[0].intangible]
	for i: int in _roll_total(c) - 1:
		w.tick(_inputs(InputFrame.neutral()))
		seen.append(w.fighters[0].intangible)
	for t: int in seen.size():
		var inside := t >= c.roll_intangible_start and t < c.roll_intangible_start + c.roll_intangible_ticks
		assert_eq(seen[t], inside, "tick %d of the roll" % t)
	assert_true(w.state_view()["fighters"][0].has("is_dodging"))


func test_neutral_guard_press_still_guards() -> void:
	var w := _world()
	w.tick(_inputs(_guard()))
	assert_eq(w.fighters[0].state, Fighter.State.GUARD)
	assert_true(_events_of(w, "dodge").is_empty())


func test_holding_guard_then_tilting_keeps_guarding() -> void:
	var w := _world()
	w.tick(_inputs(_guard()))
	for i: int in 5:
		w.tick(_inputs(_guard(1.0)))
	assert_eq(w.fighters[0].state, Fighter.State.GUARD)


func test_guard_held_through_an_attack_guards_instead_of_rolling() -> void:
	var w := _world()
	var c := w.config
	w.tick(_inputs(InputFrame.make(0, 0, false, true)))
	for i: int in c.light_startup_ticks + c.light_active_ticks + c.light_recovery_ticks + 1:
		w.tick(_inputs(_guard(1.0)))
	assert_eq(w.fighters[0].state, Fighter.State.GUARD, "the press happened while attacking")


func test_hits_and_grabs_pass_through_an_intangible_fighter() -> void:
	var w := _world()
	var c := w.config
	var book := StyleBook.build(w.fighters, c)
	var attacker := w.fighters[1]
	attacker.pos = Vector3(-1.0, 0, 0)
	attacker.facing = Vector3(1, 0, 0)
	Actions.start_attack(attacker, AttackSet.Kind.LIGHT_1)
	attacker.attack_ticks = c.light_startup_ticks + 1
	w.fighters[0].intangible = true
	assert_true(Combat.resolve(w.fighters, book, c).is_empty(), "the hit passes through")
	Actions.start_attack(attacker, AttackSet.Kind.GRAB)
	attacker.attack_ticks = c.grab_startup_ticks + 1
	assert_true(Grab.resolve(w.fighters, book, c).is_empty(), "the grab passes through")
	w.fighters[0].intangible = false
	assert_eq(Grab.resolve(w.fighters, book, c).size(), 1, "tangible again: grabbed")


func test_rolls_in_a_row_add_recovery() -> void:
	var w := _world()
	var c := w.config
	w.tick(_inputs(_guard(1.0)))
	var first := w.fighters[0].dodge_total
	for i: int in first:
		w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[0].state, Fighter.State.IDLE)
	w.tick(_inputs(_guard(-1.0)))
	assert_eq(w.fighters[0].state, Fighter.State.DODGE)
	assert_eq(w.fighters[0].dodge_total, first + c.roll_spam_recovery_ticks, "the repeat is punished")


func test_air_dodge_once_per_airtime() -> void:
	var w := _world()
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	for i: int in 10:
		w.tick(_inputs(InputFrame.neutral()))
	w.tick(_inputs(_guard(1.0)))
	assert_eq(w.fighters[0].state, Fighter.State.DODGE)
	assert_eq(_events_of(w, "dodge")[0]["kind"], "air")
	assert_almost_eq(w.fighters[0].vel.y, 0.0, 0.5, "a hovering burst")
	while w.fighters[0].state == Fighter.State.DODGE:
		w.tick(_inputs(InputFrame.neutral()))
	assert_false(w.fighters[0].on_ground, "still airborne after the dodge")
	w.tick(_inputs(_guard(-1.0)))
	assert_ne(w.fighters[0].state, Fighter.State.DODGE, "one air dodge per airtime")
	for i: int in 120:
		w.tick(_inputs(InputFrame.neutral()))
	assert_true(w.fighters[0].on_ground)
	w.tick(_inputs(InputFrame.make(0, 0, true)))
	w.tick(_inputs(_guard()))
	assert_eq(w.fighters[0].state, Fighter.State.DODGE, "landing resets the air dodge")
	assert_almost_eq(Vector2(w.fighters[0].vel.x, w.fighters[0].vel.z).length(), 0.0, 0.0001, "neutral = in place")


func test_the_special_chord_beats_the_roll() -> void:
	var chars: Array[String] = [CharacterData.KNIGHT]
	var w := World.new(GameConfig.new(), 1, 2, null, chars)
	w.fighters[0].pos = Vector3.ZERO
	w.fighters[1].pos = Vector3(0, 0, 8)
	w.fighters[0].gauge = SpecialGauge.MAX
	w.tick(_inputs(InputFrame.make(1, 0, false, false, true, true)))
	assert_eq(w.fighters[0].state, Fighter.State.SPECIAL)
	var empty := _world()
	empty.tick(_inputs(InputFrame.make(1, 0, false, false, true, true)))
	assert_eq(empty.fighters[0].state, Fighter.State.GUARD, "no gauge: the chord is still a guard")
