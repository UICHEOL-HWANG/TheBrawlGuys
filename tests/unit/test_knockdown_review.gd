extends GutTest
## Combat-depth C review fixes: no grabbing a lying fighter (grab / throw / knockdown loop), a
## weak hit keeps an earlier tumble, a dropped tumble disarms its tech (lockout kept), the getup
## attack stays intangible through its first active tick, a hold clears a getup, and snapshots
## reject impossible getup / tech values.

const K := preload("res://tests/unit/support/knockdown_case.gd")


## P1 grabs from beside fighter `target` (facing it) and the grab box is live now.
func _grab_at(w: World, target: Fighter) -> Array[Dictionary]:
	var holder := w.fighters[0]
	holder.pos = target.pos + Vector3(-0.9, 0, 0)
	holder.facing = Vector3(1, 0, 0)
	holder.on_ground = true
	Actions.start_attack(holder, AttackSet.Kind.GRAB)
	holder.attack_ticks = w.config.grab_startup_ticks + 1
	return Grab.resolve(w.fighters, StyleBook.build(w.fighters, w.config), w.config)


func test_a_lying_fighter_cannot_be_grabbed() -> void:
	var w := K.knocked_down()
	var f := w.fighters[K.VICTIM]
	assert_eq(f.state, Fighter.State.KNOCKDOWN)
	assert_true(_grab_at(w, f).is_empty(), "no grab on a lying fighter")
	assert_eq(f.state, Fighter.State.KNOCKDOWN)


func test_a_hold_clears_a_getup() -> void:
	var w := World.new(GameConfig.new(), 1)
	var f := w.fighters[1]
	f.pos = Vector3(2, 0, 0)
	Getup.start(f, Getup.Kind.ROLL, Vector3(0, 0, 1), w.config)
	f.getup_ticks = w.config.getup_roll_move_ticks + 1
	f.intangible = false
	assert_eq(_grab_at(w, f).size(), 1, "a getup past its intangible frames can be grabbed")
	assert_eq(f.state, Fighter.State.HELD)
	assert_eq(f.getup_kind, Getup.Kind.NONE)
	assert_eq(f.getup_ticks, 0)


func test_a_weak_hit_keeps_an_earlier_tumble() -> void:
	var w := K.launched()
	var f := w.fighters[K.VICTIM]
	assert_true(f.tumble)
	var weak := AttackData.make(0.0, 1.0, 0.0, 1.0, 0, 1, 0, w.config.hitstop_light)
	Combat.apply_hit(f, weak, Vector3(1, 0, 0), 1.0, w.config, f.pos, 0)
	assert_true(f.tumble, "still lands lying (or techs)")


func test_a_dropped_tumble_disarms_the_tech_but_keeps_the_lockout() -> void:
	var c := GameConfig.new()
	var f := Fighter.new()
	f.tumble = true
	f.guard_press_age = 0
	var fighters: Array[Fighter] = [f]
	Tech.track(fighters, c)
	assert_true(Tech.armed(f, c))
	f.guard_press_age = 1
	f.tumble = false  # jumped out of the tumble
	Tech.track(fighters, c)
	assert_false(Tech.armed(f, c), "a later tumble cannot use this press")
	assert_gt(f.tech_clock, 0, "presses stay locked out")
	f.tumble = true
	f.guard_press_age = 0
	Tech.track(fighters, c)
	assert_false(Tech.armed(f, c), "a fresh press inside the lockout still does nothing")


func test_getup_attack_is_intangible_through_its_first_active_tick() -> void:
	var c := GameConfig.new()
	var f := Fighter.new()
	f.on_ground = true
	Getup.start(f, Getup.Kind.ATTACK, Vector3.ZERO, c)
	var attack := Getup.attack_of(c)
	while not attack.is_active(f.getup_ticks):
		assert_true(f.intangible, "startup tick %d" % f.getup_ticks)
		Getup.step(f, c)
	assert_true(f.intangible, "the first active tick (%d) cannot be traded" % f.getup_ticks)
	Getup.step(f, c)
	assert_false(f.intangible)


func _rejects(edit: Callable) -> void:
	var w := K.knocked_down()
	var s: Dictionary = bytes_to_var(w.snapshot())
	edit.call(s["fighters"][K.VICTIM])
	assert_false(K.launched().restore(var_to_bytes(s)))
	assert_push_error("inconsistent fighter")


func test_snapshot_rejects_impossible_getup_and_tech_values() -> void:
	_rejects(func(d: Dictionary) -> void: d["getup_ticks"] = -1)
	_rejects(func(d: Dictionary) -> void: d["tech_clock"] = 100000)
	_rejects(func(d: Dictionary) -> void:
		d["state"] = Fighter.State.GETUP
		d["getup_kind"] = Getup.Kind.NONE)
