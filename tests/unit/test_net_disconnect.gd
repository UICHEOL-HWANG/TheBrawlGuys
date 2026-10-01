extends GutTest
## Leaving and dropping out of an online match (Phase 6 netcode): a dropped player's slot waits
## net_disconnect_grace for a reconnect, then a bot takes it; BYE hands it over at once; the host
## going away ends the match for its clients.

const NetRig := preload("res://tests/unit/support/net_rig.gd")
const GRACE_S := 0.5


func _config() -> GameConfig:
	var config := (load("res://src/config/default_config.tres") as GameConfig).duplicate() as GameConfig
	config.net_disconnect_grace = GRACE_S
	return config


func _rig(remotes: int = 1) -> NetRig:
	var rig := NetRig.new(_config(), 1 + remotes, remotes)
	rig.connect_all()
	return rig


func test_dropped_slot_becomes_a_bot_after_the_grace_period() -> void:
	var rig := _rig()
	watch_signals(rig.host)
	for t: int in 10:
		rig.tick()
	rig.hub.disconnect_peer(rig.client_ts[0].local_id())
	assert_eq(rig.host.stats.disconnects, 1)
	for t: int in 20:  # ~0.33 s
		rig.tick()
	assert_false(rig.host.is_bot(1), "still waiting inside the grace period")
	var start := rig.host_world.fighters[1].pos
	for t: int in 30:
		rig.tick()
	assert_true(rig.host.is_bot(1), "a bot took the slot")
	assert_signal_emitted_with_parameters(rig.host, "slot_botted", [1, HostSession.REASON_TIMEOUT])
	for t: int in 60:
		rig.tick()
	assert_ne(rig.host_world.fighters[1].pos, start, "the bot plays the slot")


func test_bye_hands_the_slot_to_a_bot_at_once() -> void:
	var rig := _rig()
	watch_signals(rig.host)
	rig.clients[0].leave()
	rig.tick()
	assert_true(rig.host.is_bot(1))
	assert_signal_emitted_with_parameters(rig.host, "slot_botted", [1, HostSession.REASON_LEFT])


func test_reconnect_inside_the_grace_period_takes_the_slot_back() -> void:
	var rig := _rig()
	for t: int in 10:
		rig.tick()
	rig.hub.disconnect_peer(rig.client_ts[0].local_id())
	rig.tick()
	var t2 := rig.hub.join()
	var again := ClientSession.new(t2, rig.config, rig.now_ms)
	for t: int in 3:
		rig.host.poll()
		again.poll(null)
	assert_eq(again.slot, 1, "the free slot is offered again")
	assert_true(again.running, "the match is already running: START follows WELCOME")
	for t: int in 60:
		rig.tick()
	assert_false(rig.host.is_bot(1), "no bot after a reconnect")
	assert_true(rig.host.roster.at(1).connected)


func test_room_full_gets_bye() -> void:
	var rig := _rig()
	var extra := rig.hub.join()
	var late := ClientSession.new(extra, rig.config, rig.now_ms)
	for t: int in 3:
		rig.host.poll()
		late.poll(null)
	assert_true(late.gone, "no free slot: the host says BYE")
	assert_eq(late.slot, -1)


func test_host_leaving_ends_the_match_for_clients() -> void:
	var rig := _rig(2)
	for c: ClientSession in rig.clients:
		watch_signals(c)
	rig.host.close()
	rig.poll_clients()
	for c: ClientSession in rig.clients:
		assert_signal_emitted(c, "host_left")
		assert_true(c.gone)


func test_host_transport_drop_ends_the_match_for_clients() -> void:
	var rig := _rig()
	watch_signals(rig.clients[0])
	rig.hub.disconnect_peer(LoopbackHub.HOST_ID)
	assert_signal_emitted(rig.clients[0], "host_left")
	assert_eq(rig.clients[0].stats.disconnects, 1)


func test_never_joined_slot_turns_bot_after_grace() -> void:
	var rig := NetRig.new(_config(), 3, 1)
	rig.setup.slots[2] = MatchSetup.slot_entry(2, MatchSetup.CONTROLLER_REMOTE, MatchSetup.INPUT_KEYBOARD)
	rig.host = HostSession.new(rig.host_t, rig.setup, rig.config, rig.now_ms)
	rig.connect_all()
	assert_false(rig.host.is_bot(2))
	for t: int in 40:
		rig.tick()
	assert_true(rig.host.is_bot(2), "nobody came for slot 2")
	assert_false(rig.host.is_bot(1))
