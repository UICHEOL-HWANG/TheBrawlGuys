extends GutTest


func _inputs() -> Array[InputFrame]:
	var a: Array[InputFrame] = [InputFrame.neutral(), InputFrame.neutral()]
	return a


func test_tick_advances_counter() -> void:
	var w := World.new(GameConfig.new(), 1)
	for i: int in 10:
		w.tick(_inputs())
	assert_eq(w.tick_count, 10)
	assert_eq(w.state_view()["tick"], 10)


func test_same_seed_gives_same_random_sequence() -> void:
	var a := World.new(GameConfig.new(), 42)
	var b := World.new(GameConfig.new(), 42)
	for i: int in 5:
		assert_eq(a.rand_int(0, 1000), b.rand_int(0, 1000))


func test_snapshot_restore_round_trip() -> void:
	var w := World.new(GameConfig.new(), 7)
	for i: int in 30:
		w.tick(_inputs())
	w.rand_int(0, 100)
	var snap := w.snapshot()
	var hash_before := w.state_hash()
	var draws_before: Array[int] = [w.rand_int(0, 1000), w.rand_int(0, 1000)]
	for i: int in 5:
		w.tick(_inputs())

	assert_true(w.restore(snap))
	assert_eq(w.tick_count, 30)
	assert_eq(w.state_hash(), hash_before)
	var draws_after: Array[int] = [w.rand_int(0, 1000), w.rand_int(0, 1000)]
	assert_eq(draws_after, draws_before, "RNG state restored")


func test_restore_rejects_garbage() -> void:
	var w := World.new(GameConfig.new(), 1)
	assert_false(w.restore(PackedByteArray([1, 2, 3])))
	assert_push_error("incompatible snapshot")
	assert_eq(w.tick_count, 0, "state untouched on failed restore")


func test_restore_rejects_incomplete_snapshot() -> void:
	var w := World.new(GameConfig.new(), 1)
	# Well-formed version but missing required keys
	var incomplete := var_to_bytes({"v": World.SNAPSHOT_VERSION, "tick": 5})
	assert_false(w.restore(incomplete))
	assert_push_error("incomplete snapshot")
	assert_eq(w.tick_count, 0, "state untouched on failed restore")


func test_state_view_is_a_value_snapshot() -> void:
	var w := World.new(GameConfig.new(), 1)
	var old_view := w.state_view()
	w.tick(_inputs())
	var new_view := w.state_view()
	assert_eq(old_view["tick"], 0, "old view unchanged by later ticks")
	assert_eq(new_view["tick"], 1)
	assert_ne(old_view["tick"], new_view["tick"])


func test_restore_rejects_long_junk_bytes() -> void:
	# NIL type header + trailing junk: > 4 bytes, decodes to null without engine errors.
	var w := World.new(GameConfig.new(), 1)
	assert_false(w.restore(PackedByteArray([0, 0, 0, 0, 9, 8, 7, 6, 5, 4])))
	assert_push_error("incompatible snapshot")
	assert_eq(w.tick_count, 0, "state untouched on failed restore")


func test_restore_rejects_non_dictionary_payload() -> void:
	var w := World.new(GameConfig.new(), 1)
	assert_false(w.restore(var_to_bytes(5)))
	assert_push_error("incompatible snapshot")
	assert_eq(w.tick_count, 0, "state untouched on failed restore")


func test_restore_rejects_wrong_version() -> void:
	var w := World.new(GameConfig.new(), 1)
	var bad := var_to_bytes({"v": World.SNAPSHOT_VERSION + 1, "tick": 5, "rng_seed": 1, "rng_state": 1})
	assert_false(w.restore(bad))
	assert_push_error("incompatible snapshot")
	assert_eq(w.tick_count, 0, "state untouched on failed restore")
