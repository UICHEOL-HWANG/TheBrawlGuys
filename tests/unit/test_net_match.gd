extends GutTest
## NetMatch scenes (Phase 6 netcode): a host and a client match scene over a 0 ms loopback run the
## normal match loop — the client boots from WELCOME, starts on START and predicts its own slot.


func _online_setup() -> MatchSetup:
	var setup := MatchSetup.vs_bots(3, 3)
	setup.mode = MatchSetup.MODE_ONLINE
	setup.slots[1] = MatchSetup.slot_entry(1, MatchSetup.CONTROLLER_REMOTE, MatchSetup.INPUT_KEYBOARD)
	return setup


func test_host_and_client_scenes_play_one_match() -> void:
	var hub := LoopbackHub.new()
	var host := NetMatch.new()
	host.host_match(hub.host(), _online_setup())
	add_child_autofree(host)
	var client := NetMatch.new()
	client.join_match(hub.join())
	add_child_autofree(client)
	await wait_seconds(0.6)
	assert_true(host.is_host())
	assert_true(host.host_session().roster.at(1).connected, "the client joined slot 1")
	assert_true(host.host_session().is_bot(2), "slot 2 is the host's bot")
	var session := client.client_session()
	assert_true(session.running, "START arrived")
	assert_eq(session.slot, 1)
	var w: World = client.get_world()
	assert_not_null(w, "the client built its World copy from WELCOME")
	assert_eq(w.fighters.size(), 3)
	assert_gt(w.tick_count, 10, "the client ticks")
	assert_gt(host.get_world().tick_count, 10, "the host ticks")
	assert_eq(session.setup.local_slot(), 1)
	assert_true(client.net_stats().has("corrections"))
	assert_eq(host.net_stats()["net_host"], true)
	assert_eq(client.get_telemetry().is_active(), true, "client match tracking runs")
	assert_eq(client.get_telemetry().match_id(), host.get_telemetry().match_id(), "one match id for all peers")
	assert_eq(client.get_telemetry().match_id(), host.host_session().match_id)
	assert_null(client._tracking._recorder._client, "clients never upload Supabase rows")


func test_client_hears_when_the_host_leaves() -> void:
	var hub := LoopbackHub.new()
	var host := NetMatch.new()
	host.host_match(hub.host(), _online_setup())
	add_child(host)
	var client := NetMatch.new()
	client.join_match(hub.join())
	add_child_autofree(client)
	watch_signals(client)
	await wait_seconds(0.3)
	host.queue_free()
	await wait_seconds(0.2)
	assert_signal_emitted_with_parameters(client, "connection_lost", [NetMatch.LOST_HOST_LEFT])
