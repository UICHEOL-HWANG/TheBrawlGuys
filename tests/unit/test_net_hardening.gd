extends GutTest
## Netcode review fixes (Phase 6): input backlogs drain without losing presses, hostile bytes are
## made valid, events are filtered and capped, debug lag never swallows the last message.

const JUMP := InputCodec.JUMP << 16


func _code(jump: bool = false) -> int:
	return InputCodec.pack(InputFrame.make(0.5, 0.0, jump))


func test_backlog_drains_two_per_tick_keeping_presses() -> void:
	var r := NetRemoteSlot.new(1, 30)
	r.bind(2)
	var codes := PackedInt32Array()
	for s: int in range(8, 0, -1):  # seqs 8..1, newest first; seq 1 jumps
		codes.append(_code(s == 1))
	r.receive(8, codes)
	var first := r.next_code()
	assert_eq(r.applied_seq, 2, "two inputs applied while the backlog is above DRAIN_ABOVE")
	assert_ne(first & JUMP, 0, "the folded seq 1 jump survives")
	while r.queued() > 0:
		r.next_code()
	assert_eq(r.applied_seq, 8)
	assert_gt(r.merged, 0)


func test_overflow_hands_presses_on() -> void:
	var r := NetRemoteSlot.new(1, 3)
	r.bind(2)
	r.receive(5, PackedInt32Array([_code(), _code(), _code(), _code(), _code(true)]))  # seq 1 jumps
	assert_eq(r.queued(), 3)
	var oldest := r.next_code()
	assert_ne(oldest & JUMP, 0, "the dropped jump moved into the oldest kept input")


func test_starving_is_counted_only_while_connected() -> void:
	var r := NetRemoteSlot.new(1, 6)
	r.next_code()
	assert_eq(r.starved, 0)
	r.bind(2)
	r.next_code()
	assert_eq(r.starved, 1)


func test_hostile_input_bytes_are_clamped() -> void:
	var bytes := PackedByteArray([NetProtocol.VERSION, NetProtocol.Type.INPUTS, 1, 0, 0, 0, 1, 255, 255, 255])
	var msg := NetProtocol.decode(bytes)
	var code := (msg["codes"] as PackedInt32Array)[0]
	var f := InputCodec.unpack(code)
	assert_eq(f.move_x, 1.0, "axis byte 255 is clamped to +1")
	assert_eq(f.move_z, 1.0)
	assert_true(f.jump and f.light and f.heavy and f.guard and f.grab)
	assert_eq(InputCodec.buttons(code) & ~NetReader.BUTTON_BITS, 0, "no stray bits")


func test_events_keep_dictionaries_only_and_are_capped() -> void:
	var list: Array = [1, "x", {"type": "hit"}, [1, 2]]
	for i: int in NetProtocol.MAX_EVENTS + 10:
		list.append({"type": "pos", "i": i})
	var msg := NetProtocol.decode(NetProtocol.events(1, list))
	var events: Array = msg["events"]
	assert_eq(events.size(), NetProtocol.MAX_EVENTS)
	assert_true(events.all(func(e: Variant) -> bool: return e is Dictionary))


func test_huge_acks_stay_positive() -> void:
	var w := MatchSetup.vs_bots(2, 1).build_world(load("res://src/config/default_config.tres") as GameConfig)
	var bytes := NetProtocol.snapshot(1, PackedInt32Array([-1, 5]), PackedInt32Array([0, 0]), w.snapshot())
	var msg := NetProtocol.decode(bytes)
	assert_eq((msg["acks"] as PackedInt32Array)[0], NetProtocol.MAX_SEQ, "u32 0xFFFFFFFF clamps, never negative")


func test_lagged_flush_all_sends_held_messages() -> void:
	var hub := LoopbackHub.new()
	var host := hub.host()
	var config := (load("res://src/config/default_config.tres") as GameConfig).duplicate() as GameConfig
	config.net_sim_latency_ms = 200.0
	var lagged := LaggedTransport.new(hub.join(), config, func() -> int: return 0)
	lagged.send(1, NetTransport.CHANNEL_RELIABLE, NetProtocol.bye())
	assert_eq(host.poll().size(), 0)
	lagged.flush_all()
	assert_eq(host.poll().size(), 1, "BYE goes out when the scene leaves")
