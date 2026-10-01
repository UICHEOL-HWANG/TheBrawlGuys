extends GutTest
## Host + clients over a 0 ms loopback (Phase 6 netcode): every client's World copy matches the
## host after each snapshot, and the host matches a local World fed the same inputs. Also the
## snapshot byte budget for four players.

const NetRig := preload("res://tests/unit/support/net_rig.gd")
const TICKS := 300
## Compressed SNAPSHOT message budget per send for a 4-player match (30 Hz -> ~60 KB/s worst case).
const SNAPSHOT_BUDGET_BYTES := 2000


func _config(snapshot_hz: int = 60) -> GameConfig:
	var c := (load("res://src/config/default_config.tres") as GameConfig).duplicate() as GameConfig
	c.net_snapshot_hz = snapshot_hz
	return c


func test_clients_match_the_host_every_snapshot_at_zero_latency() -> void:
	var rig := NetRig.new(_config(), 3, 2)
	rig.connect_all()
	assert_true(rig.clients[0].running and rig.clients[1].running, "both clients started")
	assert_eq([rig.clients[0].slot, rig.clients[1].slot], [1, 2])
	var mismatches := 0
	var checked := 0
	for t: int in TICKS:
		rig.tick(NetRig.scripted(t, 0), [NetRig.scripted(t, 1), NetRig.scripted(t, 2)])
		rig.poll_clients()
		for w: World in rig.client_worlds:
			checked += 1
			if w.state_hash() != rig.host_hashes.get(w.tick_count):
				mismatches += 1
	assert_eq(mismatches, 0, "client copies equal the host after every snapshot (%d checks)" % checked)
	assert_eq(rig.replay_reference().state_hash(), rig.host_world.state_hash(),
			"the host equals a local World fed the same inputs")
	for i: int in 2:
		assert_eq(rig.client_worlds[i].state_hash(), rig.host_world.state_hash(), "client %d final state" % i)
		assert_eq(rig.clients[i].prediction.pending_count(), 0, "every input acked")
		assert_eq(rig.host.roster.at(i + 1).applied_seq, rig.clients[i].prediction.seq(), "no input lost")


func test_scripted_inputs_really_move_fighters() -> void:
	var rig := NetRig.new(_config(), 3, 2)
	rig.connect_all()
	var start := rig.host_world.fighters[2].pos
	for t: int in 60:
		rig.tick(NetRig.scripted(t, 0), [NetRig.scripted(t, 1), NetRig.scripted(t, 2)])
	assert_gt(rig.host_world.fighters[2].pos.distance_to(start), 1.0, "the remote player's inputs reach the host")


func test_bot_slots_are_played_by_the_host() -> void:
	var rig := NetRig.new(_config(), 3, 1)
	rig.connect_all()
	assert_true(rig.host.is_bot(2))
	var start := rig.host_world.fighters[2].pos
	for t: int in 90:
		rig.tick()
	assert_ne(rig.host_world.fighters[2].pos, start, "the bot moved")


func test_events_and_end_reach_the_client() -> void:
	var rig := NetRig.new(_config(30), 2, 1)
	rig.connect_all()
	var client := rig.clients[0]
	watch_signals(client)
	rig.host_world.fighters[1].stocks = 1
	rig.host_world.fighters[1].pos = Vector3(0, rig.config.kill_y - 1, 0)
	var seen: Array = []
	for t: int in 10:
		rig.tick()
		rig.poll_clients()
		seen.append_array(client.view(rig.client_worlds[0])["events"])
	assert_true(rig.host_world.match_over)
	assert_signal_emitted_with_parameters(client, "ended", [0])
	assert_true(seen.any(func(e: Dictionary) -> bool: return String(e.get("type", "")) == "ringout"),
			"the host's ring-out event was delivered")
	var view := client.view(rig.client_worlds[0])
	assert_true(bool(view["match_over"]), "the drawn view shows the result")


func test_snapshot_size_for_four_players() -> void:
	var config := _config(30)
	var setup := MatchSetup.all_bots(4, 5)
	setup.set_rule(MatchRules.TIMED)
	var world := setup.build_world(config)
	var bots: Array[BotController] = []
	for i: int in 4:
		bots.append(BotController.new(i, config))
	var largest := 0
	var raw_largest := 0
	for t: int in 600:
		var view := world.state_view()
		var inputs: Array[InputFrame] = []
		for b: BotController in bots:
			inputs.append(b.sample(view))
		world.tick(inputs)
		if t % 2 == 0:
			var raw := world.snapshot()
			var msg := NetProtocol.snapshot(world.tick_count, PackedInt32Array([0, 1, 2, 3]),
					PackedInt32Array([0, 0, 0, 0]), raw)
			raw_largest = maxi(raw_largest, raw.size())
			largest = maxi(largest, msg.size())
	var inputs_msg := NetProtocol.inputs(100, PackedInt32Array([1, 2, 3, 4, 5, 6, 7, 8]))
	gut.p("4-player snapshot: raw WorldCodec %d B, SNAPSHOT message (zstd) %d B, at 30 Hz %.1f KB/s per client; INPUTS (8 redundant) %d B"
			% [raw_largest, largest, largest * 30 / 1024.0, inputs_msg.size()])
	assert_lt(largest, SNAPSHOT_BUDGET_BYTES, "4-player snapshot fits the budget")
	assert_lt(inputs_msg.size(), 40)


## PHASES 6a: reconciliation cost (restore + 15 re-simulated ticks, 4 fighters) against PRD §5.6.
func test_reconcile_cost_is_reported() -> void:
	var config := _config(30)
	var setup := MatchSetup.all_bots(4, 9)
	var host := setup.build_world(config)
	var client := setup.build_world(config)
	var prediction := NetPrediction.new(1, 4, config)
	var frame: Array[InputFrame] = [InputFrame.make(1, 0), InputFrame.make(0, 1), InputFrame.make(-1, 0),
		InputFrame.make(0, -1)]
	for t: int in 120:
		host.tick(frame)
	var snap := {"world": host.snapshot(), "acks": PackedInt32Array([0, 0, 0, 0]),
		"codes": PackedInt32Array([0, 0, 0, 0])}
	for i: int in config.net_max_resim_ticks:
		prediction.next(InputFrame.make(0.5, 0.5))
	var runs := 10
	var started := Time.get_ticks_usec()
	for i: int in runs:
		prediction.reconcile(client, snap)
	var avg_ms := (Time.get_ticks_usec() - started) / 1000.0 / runs
	gut.p("reconcile (restore + %d ticks, 4 fighters): %.2f ms" % [config.net_max_resim_ticks, avg_ms])
	assert_eq(client.tick_count, host.tick_count + config.net_max_resim_ticks)
	assert_lt(avg_ms, 50.0, "sanity bound (headless desktop)")
