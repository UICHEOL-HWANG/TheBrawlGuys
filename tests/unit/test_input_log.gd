extends GutTest
## Replay-grade input log (platform A7, docs/analytics-strategy.md §1): every slot's InputFrame per
## tick, run-length encoded, packed into a versioned binary, gzip + base64 for PostgREST. Decoding
## must restore the exact frames, and a World fed the decoded frames must end on the same hash.

const SEED := 9
const PLAYERS := 2
const TICKS := 900


static func _frame(t: int, slot: int) -> InputFrame:
	var mx := -1.0 if floori(t / 90.0) % 2 == 0 else 0.37
	var mz := 0.0 if slot == 0 else -0.5
	return InputFrame.make(mx, mz, t % 50 == 0, t % 17 == 3 + slot, t % 200 > 180, t % 140 > 120, t % 97 == 40)


func test_codec_round_trips_every_field() -> void:
	var f := InputFrame.make(-1.0, 0.37, true, false, true, false, true)
	var back := InputCodec.unpack(InputCodec.pack(f))
	assert_eq(back.move_x, f.move_x)
	assert_eq(back.move_z, f.move_z)
	assert_eq([back.jump, back.light, back.heavy, back.guard, back.grab], [true, false, true, false, true])
	assert_eq(InputCodec.pack(InputFrame.neutral()), InputCodec.NEUTRAL)


func test_codec_is_exact_for_every_quantized_axis_value() -> void:
	for k: int in range(-InputFrame.MOVE_STEPS, InputFrame.MOVE_STEPS + 1):
		var f := InputFrame.make(float(k) / InputFrame.MOVE_STEPS, 0.0)
		assert_eq(InputCodec.unpack(InputCodec.pack(f)).move_x, f.move_x, "axis step %d" % k)


func test_track_stores_only_changes() -> void:
	var track := InputTrack.new()
	for t: int in 100:
		track.record(InputFrame.make(1.0 if t >= 40 else 0.0, 0.0))
	assert_eq(track.frame_count(), 100)
	assert_eq(track.run_count(), 2, "one run for idle, one for walking")
	assert_eq(track.code_at(39), InputCodec.NEUTRAL)
	assert_eq(InputCodec.unpack(track.code_at(40)).move_x, 1.0)


func test_track_bytes_round_trip() -> void:
	var track := InputTrack.new()
	for t: int in TICKS:
		track.record(_frame(t, 1))
	var back := InputTrack.from_bytes(track.to_bytes())
	assert_not_null(back)
	assert_eq(back.frame_count(), TICKS)
	assert_eq(back.codes(), track.codes())


func test_corrupt_bytes_are_rejected() -> void:
	var track := InputTrack.new()
	track.record(_frame(0, 0))
	var bytes := track.to_bytes()
	bytes[0] = 0
	assert_null(InputTrack.from_bytes(bytes), "bad magic")
	assert_null(InputTrack.from_bytes(PackedByteArray([1, 2, 3])), "too short")
	assert_eq(InputBlob.decode("not base64 at all!").size(), 0, "not a blob")


func test_log_rows_decode_to_the_same_frames() -> void:
	var log := _recorded_log()
	var rows := log.rows("m-1")
	assert_eq(rows.size(), PLAYERS)
	for r: Dictionary in rows:
		assert_eq(r["match_id"], "m-1")
		assert_eq(r["encoding"], InputBlob.ENCODING)
		assert_eq(r["frame_count"], TICKS)
		assert_true(JsonSafe.is_safe(r))
	var back := InputLog.from_rows(rows)
	assert_not_null(back)
	assert_eq(back.frame_count(), TICKS)
	for slot: int in PLAYERS:
		assert_eq(back.track(slot).codes(), log.track(slot).codes(), "slot %d frames" % slot)


func test_rows_with_a_wrong_encoding_are_rejected() -> void:
	var rows := _recorded_log().rows("m-1")
	rows[1]["encoding"] = "zip"
	assert_null(InputLog.from_rows(rows))


func test_missing_slot_inputs_are_recorded_as_neutral() -> void:
	var log := InputLog.new(3)
	var two: Array[InputFrame] = [InputFrame.make(1.0, 0.0), InputFrame.make(-1.0, 0.0)]
	log.record(two)
	assert_eq(log.track(2).code_at(0), InputCodec.NEUTRAL, "World treats a missing input as neutral")


func test_replaying_decoded_inputs_reproduces_the_final_state_hash() -> void:
	var config := GameConfig.new()
	var original := World.new(config, SEED, PLAYERS)
	var log := InputLog.new(PLAYERS)
	for t: int in TICKS:
		var inputs: Array[InputFrame] = [_frame(t, 0), _frame(t, 1)]
		log.record(inputs)
		original.tick(inputs)
	var decoded := InputLog.from_rows(log.rows("m"))
	var replay := World.new(config, SEED, PLAYERS)
	for t: int in decoded.frame_count():
		replay.tick(decoded.inputs_at(t))
	assert_eq(replay.tick_count, original.tick_count)
	assert_eq(replay.state_hash(), original.state_hash())


func _recorded_log() -> InputLog:
	var log := InputLog.new(PLAYERS)
	for t: int in TICKS:
		var inputs: Array[InputFrame] = [_frame(t, 0), _frame(t, 1)]
		log.record(inputs)
	return log
