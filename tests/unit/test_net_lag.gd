extends GutTest
## A client 100 ms away (one way) with jitter and 5% loss on the fast channel (Phase 6 netcode):
## its own fighter answers input the same tick (prediction), and once inputs settle its copy agrees
## with the host again (reconciliation after snapshots).

const NetRig := preload("res://tests/unit/support/net_rig.gd")
const LATENCY_MS := 100.0
const JITTER_MS := 10.0
const LOSS_PCT := 5.0
const MOVE_TICKS := 40
const SETTLE_TICKS := 120


func _rig() -> NetRig:
	var config := (load("res://src/config/default_config.tres") as GameConfig).duplicate() as GameConfig
	var rig := NetRig.new(config, 2, 1, LATENCY_MS, JITTER_MS, LOSS_PCT)
	rig.connect_all()
	return rig


func test_own_fighter_moves_the_same_tick_as_the_input() -> void:
	var rig := _rig()
	for t: int in 30:
		rig.tick()
	var world: World = rig.client_worlds[0]
	var unresponsive := 0
	for t: int in MOVE_TICKS:
		rig.poll_clients()
		var before := world.fighters[1].pos.x
		rig.tick(InputFrame.neutral(), [InputFrame.make(1.0, 0.0)])
		if world.fighters[1].pos.x <= before:
			unresponsive += 1
	assert_eq(unresponsive, 0, "every held-right tick moved the own fighter right at once")
	assert_gt(rig.host.stats.rtt_percentile(0.5), 150.0, "the host sees the ~200 ms round trip")


func test_client_converges_after_snapshots() -> void:
	var rig := _rig()
	for t: int in 30:
		rig.tick()
	for t: int in MOVE_TICKS:
		rig.tick(InputFrame.make(-1.0, 0.0), [InputFrame.make(1.0, 0.3, t % 15 == 0)])
	var corrections_after_moves := rig.clients[0].stats.corrections
	var predicted: Dictionary = {}
	for t: int in SETTLE_TICKS:
		rig.tick()
		var w: World = rig.client_worlds[0]
		if t > SETTLE_TICKS / 2:
			predicted[w.tick_count] = w.fighters[1].pos
	var compared := 0
	for tick: int in predicted:
		if rig.host_positions.has(tick):
			compared += 1
			assert_almost_eq((predicted[tick] as Vector3).distance_to(rig.host_positions[tick][1]), 0.0, 0.001,
					"predicted own position at tick %d equals the host's" % tick)
	assert_gt(compared, 10, "enough ticks compared")
	assert_eq(rig.clients[0].stats.corrections, corrections_after_moves, "no corrections once inputs settle")
	assert_gt(rig.clients[0].stats.rtt_percentile(0.5), 150.0, "PING/PONG measures the round trip")
	gut.p("100 ms / 5%% loss: corrections while moving %d, client rtt p50 %s ms"
			% [corrections_after_moves, str(rig.clients[0].stats.rtt_percentile(0.5))])


func test_remote_fighters_are_drawn_from_interpolated_snapshots() -> void:
	var rig := _rig()
	for t: int in 90:
		rig.tick(InputFrame.make(1.0, 0.0))
	var client := rig.clients[0]
	var view := client.view(rig.client_worlds[0])
	var drawn_tick := client.interpolation.render_tick()
	assert_lt(drawn_tick, float(rig.host_world.tick_count), "others are drawn in the past")
	var host_x: float = (rig.host_positions[int(drawn_tick)][0] as Vector3).x
	assert_almost_eq((view["fighters"][0]["pos"] as Vector3).x, host_x, 0.2, "near the host's position then")
	assert_eq(view["fighters"][1], rig.client_worlds[0].state_view()["fighters"][1], "own fighter is the predicted one")


func test_a_host_side_divergence_counts_as_a_correction_and_is_fixed() -> void:
	var rig := _rig()
	for t: int in 60:
		rig.tick()
	var before := rig.clients[0].stats.corrections
	rig.host_world.fighters[1].pos += Vector3(1.0, 0.0, 0.0)  # the host disagrees with the prediction
	for t: int in 30:
		rig.tick()
	assert_eq(rig.clients[0].stats.corrections, before + 1, "one correction")
	var w: World = rig.client_worlds[0]
	assert_almost_eq(w.fighters[1].pos.distance_to(rig.host_world.fighters[1].pos), 0.0, 0.001,
			"the client snapped to the host's position")
