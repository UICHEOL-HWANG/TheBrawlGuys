extends GutTest
## Defense state (combat-depth A) survives World snapshots: a restore mid-roll or mid-guard-break
## continues exactly like the uninterrupted run, and the fighter data carries every new field.

const FIELDS: Array[String] = [
	"guard_prev", "guard_press_age", "guard_hp", "guard_idle_ticks", "guard_break_left", "perfect_by",
	"dodge_kind", "dodge_ticks", "dodge_total", "dodge_dir", "intangible", "air_dodge_used",
	"roll_streak", "roll_recent",
]


func _inputs(p1: InputFrame, p2: InputFrame = null) -> Array[InputFrame]:
	var a: Array[InputFrame] = [p1, p2 if p2 != null else InputFrame.neutral()]
	return a


## P1 rolls twice (a spam penalty), P2 guards until its low meter breaks.
func _script(t: int) -> Array[InputFrame]:
	var p1 := InputFrame.make(1.0 if t < 40 else -1.0, 0, false, false, false, t == 0 or t == 30)
	var p2 := InputFrame.make(0, 0, false, false, false, t >= 5 and t < 60)
	return _inputs(p1, p2)


func _world() -> World:
	var w := World.new(GameConfig.new(), 3)
	w.fighters[0].pos = Vector3(-3, 0, 0)
	w.fighters[1].pos = Vector3(3, 0, 0)
	w.fighters[1].guard_hp = 4.0
	return w


func _run(w: World, ticks: int) -> Array[int]:
	var seq: Array[int] = []
	for i: int in ticks:
		w.tick(_script(w.tick_count))
		seq.append(w.state_hash())
	return seq


func test_fighter_data_has_every_defense_field() -> void:
	var d := Fighter.new().to_data()
	for key: String in FIELDS:
		assert_true(d.has(key), key)
	assert_not_null(Fighter.from_data(d))


func test_restore_mid_roll_and_break_continues_identically() -> void:
	for split: int in [8, 36, 45]:
		var straight := _world()
		_run(straight, split)
		var snap := straight.snapshot()
		var saved: Array = bytes_to_var(snap)["fighters"]
		var rest := _run(straight, 90 - split)
		var resumed := _world()
		assert_true(resumed.restore(snap), "restore at %d" % split)
		for i: int in resumed.fighters.size():
			var d := resumed.fighters[i].to_data()
			for key: String in FIELDS:
				assert_eq(d[key], saved[i][key], "%s of fighter %d at %d" % [key, i, split])
		assert_eq(_run(resumed, 90 - split), rest, "split at %d" % split)


func test_the_script_rolls_and_breaks() -> void:
	var w := _world()
	var seen := {}
	for i: int in 90:
		w.tick(_script(w.tick_count))
		for e: Dictionary in w.state_view()["events"]:
			seen[e["type"]] = true
	assert_true(seen.has("dodge"))
	assert_true(seen.has("guard_break"))


func test_out_of_range_defense_values_are_rejected() -> void:
	var w := _world()
	var bad := {"guard_hp": GuardMeter.MAX + 1.0, "dodge_kind": 9, "perfect_by": 7}
	for key: String in bad:
		var s: Dictionary = bytes_to_var(w.snapshot())
		s["fighters"][0][key] = bad[key]
		assert_false(World.new(GameConfig.new(), 3).restore(var_to_bytes(s)), key)
		assert_push_error("inconsistent fighter or projectile data")
