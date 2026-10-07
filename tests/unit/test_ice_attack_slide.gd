extends GutTest
## next-polish 2: on ice an attack rides the slide — a light, a heavy charge and its swing keep the
## running speed, losing ice_slide_friction of it per tick, instead of stopping dead. A guard
## still plants the feet (the way to stop on ice). Grippy floors stop exactly as before.

const FAR_AWAY := Vector3(0, 0, 8)


func _world(slippery: bool) -> World:
	var c := GameConfig.new()
	var a := ArenaCatalog.build("lakeside_camp", c)
	a.slippery = slippery
	var w := World.new(c, 1, 2, a)
	w.fighters[1].pos = FAR_AWAY
	w.fighters[0].pos = Vector3(-6, 0, 0)
	return w


func _tick(w: World, input: InputFrame, ticks: int = 1) -> void:
	for i: int in ticks:
		var inputs: Array[InputFrame] = [input, InputFrame.neutral()]
		w.tick(inputs)


func _run_up(w: World) -> void:
	_tick(w, InputFrame.make(1.0, 0.0), 60)  # full speed on ice too


func test_a_light_attack_on_ice_keeps_sliding() -> void:
	var w := _world(true)
	_run_up(w)
	var before := w.fighters[0].vel.x
	_tick(w, InputFrame.make(0, 0, false, true))
	assert_eq(w.fighters[0].state, Fighter.State.ATTACK)
	assert_almost_eq(w.fighters[0].vel.x, before * w.config.ice_slide_friction, 0.01, "rides the slide")
	var x := w.fighters[0].pos.x
	_tick(w, InputFrame.neutral(), 10)
	assert_gt(w.fighters[0].pos.x, x + 0.5, "still gliding while it swings (a dead stop moves 0)")


func test_a_heavy_charge_on_ice_slides_too() -> void:
	var w := _world(true)
	_run_up(w)
	_tick(w, InputFrame.make(0, 0, false, false, true), 3)
	assert_eq(w.fighters[0].state, Fighter.State.CHARGE)
	assert_gt(w.fighters[0].vel.x, 1.0)


func test_a_guard_on_ice_still_plants_the_feet() -> void:
	var w := _world(true)
	_run_up(w)
	_tick(w, InputFrame.make(0, 0, false, false, false, true))
	assert_eq(w.fighters[0].state, Fighter.State.GUARD)
	assert_eq(w.fighters[0].vel.x, 0.0)


func test_grippy_floors_stop_an_attack_dead() -> void:
	var w := _world(false)
	_run_up(w)
	_tick(w, InputFrame.make(0, 0, false, true))
	assert_eq(w.fighters[0].vel.x, 0.0)
	assert_false(is_nan(w.fighters[0].vel.x) or signf(w.fighters[0].vel.x) < 0.0)
