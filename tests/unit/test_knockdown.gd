extends GutTest
## Knockdown (combat-depth C): a fighter launched hard enough to tumble (knockback at least
## knockdown_min_knockback) lands lying down (KNOCKDOWN) instead of on its feet. It can still be
## hit, for knockdown_hit_knockback_mul of the knockback and without being knocked down again.

const K := preload("res://tests/unit/support/knockdown_case.gd")


func _neutral(_t: int) -> InputFrame:
	return InputFrame.neutral()


func test_strong_launch_lands_in_knockdown_with_an_event() -> void:
	var w := K.launched()
	assert_true(w.fighters[K.VICTIM].tumble, "a strong launch tumbles")
	K.until_landed(w, _neutral)
	var f := w.fighters[K.VICTIM]
	assert_eq(f.state, Fighter.State.KNOCKDOWN)
	var downs := K.events_of(w, "knockdown")
	assert_eq(downs.size(), 1)
	assert_eq(downs[0]["fighter"], K.VICTIM)
	assert_eq(downs[0]["pos"], f.pos)
	assert_false(f.untouchable(), "lying fighters can be hit")
	assert_true(w.state_view()["fighters"][K.VICTIM]["knocked_down"])


func test_weak_hit_never_knocks_down() -> void:
	var w := World.new(GameConfig.new(), 1)
	var t := w.fighters[1]
	var weak := AttackData.make(0.0, 2.0, 0.0, 1.0, 0, 1, 0, w.config.hitstop_light)
	Combat.apply_hit(t, weak, Vector3(1, 0, 0), 1.0, w.config, t.pos, 0)
	assert_false(t.tumble)
	K.until_landed(w, _neutral)
	for i: int in 60:
		assert_ne(t.state, Fighter.State.KNOCKDOWN)
		K.step(w, InputFrame.neutral())


func test_jumping_out_of_tumble_lands_on_its_feet() -> void:
	var w := K.launched()
	var f := w.fighters[K.VICTIM]
	var jumped := [false]
	K.until_landed(w, func(_t: int) -> InputFrame:
		var press: bool = f.state == Fighter.State.AIR and not jumped[0]
		if press:
			jumped[0] = true
		return InputFrame.make(0, 0, press))
	assert_true(jumped[0], "hitstun ended in the air")
	assert_ne(f.state, Fighter.State.KNOCKDOWN, "acting out of tumble cancels the knockdown")


func test_hits_on_a_lying_fighter_push_less_and_do_not_knock_down_again() -> void:
	var c := GameConfig.new()
	var standing := World.new(c, 1)
	var hit := K.strong_hit(c)
	var e_stand := Combat.apply_hit(standing.fighters[1], hit, Vector3(1, 0, 0), 1.0, c, Vector3.ZERO, 0)
	var w := K.knocked_down(c)
	var f := w.fighters[K.VICTIM]
	var e_down := Combat.apply_hit(f, hit, Vector3(1, 0, 0), 1.0, c, f.pos, 0)
	assert_almost_eq(float(e_down["knockback"]), float(e_stand["knockback"]) * c.knockdown_hit_knockback_mul, 0.001)
	assert_eq(f.state, Fighter.State.HITSTUN)
	assert_false(f.tumble, "no knockdown lock")
	K.until_landed(w, _neutral)
	for i: int in 40:
		assert_ne(f.state, Fighter.State.KNOCKDOWN)
		K.step(w, InputFrame.neutral())


func test_falling_off_while_lying_becomes_airborne() -> void:
	var w := K.knocked_down()
	var f := w.fighters[K.VICTIM]
	f.on_ground = false
	f.pos.y = 2.0
	K.step(w, InputFrame.neutral())
	assert_eq(f.state, Fighter.State.AIR)
