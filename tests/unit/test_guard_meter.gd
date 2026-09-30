extends GutTest
## Guard durability and perfect guard (combat-depth A): the meter drains while guarding and by
## blocked damage, refills after a delay, breaks at 0 (pop up + stun), and a guard pressed just
## before the hit blocks everything and staggers the attacker.


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


func _guard() -> InputFrame:
	return InputFrame.make(0, 0, false, false, false, true)


func _light() -> InputFrame:
	return InputFrame.make(0, 0, false, true)


## P2 stands 1.0 m in front of P1 (facing it) and has held guard for `held` ticks.
func _world(held: int) -> World:
	var w := World.new(GameConfig.new(), 1)
	w.fighters[0].pos = Vector3.ZERO
	w.fighters[1].pos = Vector3(1.0, 0, 0)
	w.fighters[0].facing = Vector3(1, 0, 0)
	for i: int in held:
		w.tick(_inputs(InputFrame.neutral(), _guard()))
	return w


## P1 swings a light hit at the guarding P2; returns every event until the hit has landed.
func _swing(w: World) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	w.tick(_inputs(_light(), _guard()))
	events.append_array(w.state_view()["events"])
	for i: int in w.config.light_startup_ticks + 1:
		w.tick(_inputs(InputFrame.neutral(), _guard()))
		events.append_array(w.state_view()["events"])
	return events


func _of(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type)


func test_meter_starts_full_and_drains_while_held() -> void:
	assert_eq(_world(0).fighters[1].guard_hp, GuardMeter.MAX)
	var w := _world(30)
	assert_almost_eq(w.fighters[1].guard_hp, GuardMeter.MAX - 30 * w.config.guard_hold_drain, 0.001)
	var ratio := float(w.state_view()["fighters"][1]["guard_hp_ratio"])
	assert_almost_eq(ratio, w.fighters[1].guard_hp / GuardMeter.MAX, 0.0001)


func test_blocked_damage_drains_the_meter_and_keeps_the_event_shape() -> void:
	var w := _world(20)
	var before := w.fighters[1].guard_hp
	var guarded := _of(_swing(w), "guard_hit")
	assert_eq(guarded.size(), 1)
	assert_eq(guarded[0].keys(), ["type", "attacker", "target", "pos", "damage", "knockback", "hitstop_ticks",
			"power", "attack_kind"], "guard_hit shape unchanged")
	var lost := before - w.fighters[1].guard_hp
	var blocked := w.config.light_link_damage * w.config.guard_block_mul
	assert_gt(lost, blocked, "the blocked damage plus the hold drain")
	assert_lt(lost, blocked + 10 * w.config.guard_hold_drain)
	assert_almost_eq(w.fighters[1].damage, w.config.light_link_damage * w.config.guard_damage_mul, 0.0001)


func test_meter_refills_after_the_delay() -> void:
	var w := _world(30)
	var low := w.fighters[1].guard_hp
	for i: int in w.config.guard_regen_delay_ticks:
		w.tick(_inputs(InputFrame.neutral()))
	assert_almost_eq(w.fighters[1].guard_hp, low, 0.001, "no refill during the delay")
	for i: int in 10:
		w.tick(_inputs(InputFrame.neutral()))
	assert_gt(w.fighters[1].guard_hp, low)
	for i: int in 600:
		w.tick(_inputs(InputFrame.neutral()))
	assert_eq(w.fighters[1].guard_hp, GuardMeter.MAX, "capped at full")


func test_empty_meter_breaks_the_guard() -> void:
	var w := _world(20)
	w.fighters[1].guard_hp = 1.0
	var breaks := _of(_swing(w), "guard_break")
	assert_eq(breaks.size(), 1)
	assert_eq(breaks[0]["fighter"], 1)
	assert_true(breaks[0].has("pos"))
	var f := w.fighters[1]
	assert_eq(f.state, Fighter.State.HITSTUN, "stunned")
	assert_gt(f.vel.y, 0.0, "pops up")
	assert_true(bool(w.state_view()["fighters"][1]["guard_broken"]))
	assert_almost_eq(f.guard_hp, w.config.guard_break_refill, 0.001)
	for i: int in w.config.guard_break_stun_ticks - 20:
		w.tick(_inputs(InputFrame.neutral(), _guard()))
	assert_eq(f.state, Fighter.State.HITSTUN, "cannot act or guard while stunned")


func test_hits_on_a_broken_guard_deal_full_damage() -> void:
	var w := _world(20)
	w.fighters[1].guard_hp = 0.05
	w.tick(_inputs(InputFrame.neutral(), _guard()))
	assert_eq(w.fighters[1].state, Fighter.State.HITSTUN, "the hold drain alone breaks it")
	for i: int in 40:
		w.tick(_inputs(InputFrame.neutral(), _guard()))
	w.fighters[1].pos = Vector3(1.0, 0, 0)
	var before := w.fighters[1].damage
	assert_eq(_of(_swing(w), "hit").size(), 1)
	assert_almost_eq(w.fighters[1].damage - before, w.config.light_link_damage, 0.0001)


func test_perfect_guard_blocks_everything_and_staggers_the_attacker() -> void:
	var w := _world(0)
	var c := w.config
	# P2 presses guard only once P1's swing is about to become active
	w.tick(_inputs(_light()))
	for i: int in c.light_startup_ticks - 1:
		w.tick(_inputs(InputFrame.neutral()))
	var events: Array[Dictionary] = []
	for i: int in 3:
		w.tick(_inputs(InputFrame.neutral(), _guard()))
		events.append_array(w.state_view()["events"])
	var perfect := _of(events, "perfect_guard")
	assert_eq(perfect.size(), 1)
	assert_eq(perfect[0]["fighter"], 1)
	assert_eq(perfect[0]["attacker"], 0)
	assert_true(perfect[0].has("pos"))
	assert_eq(w.fighters[1].damage, 0.0, "no chip damage")
	assert_gt(w.fighters[1].guard_hp, GuardMeter.MAX - 1.0, "no guard points lost to the hit")
	assert_gt(w.fighters[0].hitstop_ticks, SimTime.to_ticks(c.hitstop_light), "the attacker is staggered")


func test_a_late_guard_is_not_perfect() -> void:
	var w := _world(GameConfig.new().perfect_guard_ticks + 1)
	var events := _swing(w)
	assert_true(_of(events, "perfect_guard").is_empty())
	assert_gt(w.fighters[1].damage, 0.0)
