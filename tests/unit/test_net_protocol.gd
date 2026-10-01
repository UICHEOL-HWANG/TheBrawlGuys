extends GutTest
## NetProtocol / SetupCodec round trips and hostile input (Phase 6 netcode).

const T := NetProtocol.Type


func _config() -> GameConfig:
	return load("res://src/config/default_config.tres") as GameConfig


func test_simple_messages_round_trip() -> void:
	assert_eq(NetProtocol.decode(NetProtocol.hello())["type"], T.HELLO)
	assert_eq(NetProtocol.decode(NetProtocol.bye())["type"], T.BYE)
	assert_eq(NetProtocol.decode(NetProtocol.start(1234))["tick"], 1234)
	assert_eq(NetProtocol.decode(NetProtocol.end(-1))["winner"], -1)
	assert_eq(NetProtocol.decode(NetProtocol.end(3))["winner"], 3)
	assert_eq(NetProtocol.decode(NetProtocol.ping(99999))["ms"], 99999)
	assert_eq(NetProtocol.decode(NetProtocol.pong(7))["type"], T.PONG)


func test_inputs_round_trip_bit_exact() -> void:
	var frames := [InputFrame.make(1.0, -0.5, true), InputFrame.make(-0.3, 0.0, false, true, true, true, true),
		InputFrame.neutral()]
	var codes := PackedInt32Array()
	for f: InputFrame in frames:
		codes.append(InputCodec.pack(f))
	var msg := NetProtocol.decode(NetProtocol.inputs(500, codes))
	assert_eq(msg["type"], T.INPUTS)
	assert_eq(msg["seq"], 500)
	assert_eq(msg["codes"], codes)
	var back := InputCodec.unpack((msg["codes"] as PackedInt32Array)[1])
	assert_eq(back.move_x, (frames[1] as InputFrame).move_x)
	assert_true(back.grab and back.guard and back.heavy and back.light)


func test_inputs_carry_at_most_max_inputs() -> void:
	var codes := PackedInt32Array()
	codes.resize(NetProtocol.MAX_INPUTS + 10)
	var msg := NetProtocol.decode(NetProtocol.inputs(1, codes))
	assert_eq((msg["codes"] as PackedInt32Array).size(), NetProtocol.MAX_INPUTS)


func test_snapshot_round_trip_restores_the_world() -> void:
	var setup := MatchSetup.vs_bots(4, 3)
	var w := setup.build_world(_config())
	var frame: Array[InputFrame] = [InputFrame.make(1, 0), InputFrame.make(0, 1, true), InputFrame.neutral(),
		InputFrame.make(-1, 0)]
	for i: int in 30:
		w.tick(frame)
	var acks := PackedInt32Array([0, 12, 13, 0])
	var codes := PackedInt32Array([1, 2, 3, InputCodec.NEUTRAL])
	var msg := NetProtocol.decode(NetProtocol.snapshot(w.tick_count, acks, codes, w.snapshot()))
	assert_eq(msg["type"], T.SNAPSHOT)
	assert_eq(msg["tick"], 30)
	assert_eq(msg["acks"], acks)
	assert_eq(msg["codes"], codes)
	var copy := setup.build_world(_config())
	assert_true(copy.restore(msg["world"]))
	assert_eq(copy.state_hash(), w.state_hash())


func test_events_and_welcome_round_trip() -> void:
	var events := [{"type": "hit", "target": 1, "pos": Vector3(1, 2, 3)}]
	var msg := NetProtocol.decode(NetProtocol.events(77, events))
	assert_eq(msg["tick"], 77)
	assert_eq(msg["events"], events)
	var setup := MatchSetup.vs_bots(3, 42)
	setup.slots[1] = MatchSetup.slot_entry(1, MatchSetup.CONTROLLER_REMOTE, MatchSetup.INPUT_KEYBOARD)
	var welcome := NetProtocol.decode(NetProtocol.welcome(1, SetupCodec.to_dict(setup)))
	assert_eq(welcome["slot"], 1)
	var back := SetupCodec.from_dict(welcome["setup"])
	assert_not_null(back)
	assert_eq(back.seed, 42)
	assert_eq(back.slots[1]["controller"], MatchSetup.CONTROLLER_REMOTE)


func test_broken_messages_decode_to_empty() -> void:
	var good := NetProtocol.inputs(5, PackedInt32Array([1, 2, 3]))
	assert_eq(NetProtocol.decode(good.slice(0, good.size() - 1)), {}, "truncated")
	var extra := good.duplicate()
	extra.append(0)
	assert_eq(NetProtocol.decode(extra), {}, "trailing bytes")
	var wrong_version := good.duplicate()
	wrong_version[0] = NetProtocol.VERSION + 1
	assert_eq(NetProtocol.decode(wrong_version), {}, "other version")
	assert_eq(NetProtocol.decode(PackedByteArray([NetProtocol.VERSION, 200])), {}, "unknown type")
	assert_eq(NetProtocol.decode(PackedByteArray()), {}, "empty")
	var huge := PackedByteArray([NetProtocol.VERSION, T.EVENTS, 0, 0, 0, 0, 255, 255, 255, 127])
	assert_eq(NetProtocol.decode(huge), {}, "oversized blob length")


func test_setup_codec_rejects_bad_setups() -> void:
	var d := SetupCodec.to_dict(MatchSetup.vs_bots(2, 1))
	assert_null(SetupCodec.from_dict(d.merged({"seed": "x"}, true)))
	assert_null(SetupCodec.from_dict(d.merged({"arena": "nowhere"}, true)))
	assert_null(SetupCodec.from_dict(d.merged({"slots": [{"slot": 0}]}, true)))
	assert_null(SetupCodec.from_dict(d.merged({"slots": [1, 2, 3, 4, 5]}, true)))


func test_for_client_relabels_the_line_up() -> void:
	var setup := MatchSetup.vs_bots(4, 1)
	setup.slots[1] = MatchSetup.slot_entry(1, MatchSetup.CONTROLLER_REMOTE, MatchSetup.INPUT_KEYBOARD)
	setup.slots[2] = MatchSetup.slot_entry(2, MatchSetup.CONTROLLER_REMOTE, MatchSetup.INPUT_KEYBOARD)
	var c := SetupCodec.for_client(setup, 2)
	assert_eq(c.local_slots(), [2] as Array[int])
	assert_eq(c.slots[0]["controller"], MatchSetup.CONTROLLER_REMOTE, "the host is remote to a client")
	assert_eq(c.slots[1]["controller"], MatchSetup.CONTROLLER_REMOTE)
	assert_eq(c.bot_slots(), [3] as Array[int])
	assert_eq(setup.local_slot(), 0, "the original is untouched")


func test_held_only_keeps_held_buttons_and_movement() -> void:
	var code := InputCodec.pack(InputFrame.make(0.5, -1, true, true, true, true, true))
	var held := InputCodec.unpack(NetInputRepeat.held_only(code))
	assert_eq(held.move_x, InputFrame.quantize_axis(0.5))
	assert_true(held.heavy and held.guard)
	assert_false(held.jump or held.light or held.grab)
